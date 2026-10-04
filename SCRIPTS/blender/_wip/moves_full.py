"""
Move library for the long (30 s+) ability showcases.

Every move is a function  move(ctx, t0, **params) -> t_end  that keys its
own poses starting at frame t0 and flows out of whatever pose came before
(no forced return to stance between moves — that is what keeps 30 s of
choreography fluid instead of a list of clips).

World bookkeeping (Ctx):
  * root x/z/yaw — the HumanoidRootPart path (root motion, exported as
    data, NOT inside the KeyframeSequence)
  * hip_yaw / hip_pitch — accumulated LowerTorso Euler offsets after spins
    and flips, so the curves never unwind
  * blade_x / blade_y — accumulated EmberBlade twirl offsets
  * feet are stored in WORLD space (tl.feet_world = True): planted feet stay
    planted while the root travels; steps move them on an arc.

Arm targets: "space": "ut" = UpperTorso local (cuts, gestures — follows
torso twist/lean); default "root" = HumanoidRootPart space (floor contact).
"""

import math

from mathutils import Vector

import anim_engine as ae
from common import STANCE_ARMS, STANCE_BODY, STANCE_FEET

TRAIL_LEAD = 3


def edge_up(blade, motion):
    """Spine vector (hand +Y) opposite to the swing motion -> edge leads."""
    b = Vector(blade).normalized()
    m = Vector(motion)
    m = m - b * m.dot(b)
    if m.length < 1e-4:
        return (0.0, 1.0, 0.0)
    return tuple(-m.normalized())


class Ctx:
    def __init__(self, tl):
        self.tl = tl
        tl.feet_world = True
        self.x = 0.0
        self.z = 0.0
        self.yaw = 0.0
        self.hip_yaw = 0.0
        self.hip_pitch = 0.0
        self.blade_x = 0.0
        self.blade_y = 0.0

    # -- root -------------------------------------------------------------
    def fwd(self, d, lateral=0.0):
        y = math.radians(self.yaw)
        return (-math.sin(y) * d + math.cos(y) * lateral, -math.cos(y) * d - math.sin(y) * lateral)

    def root_key(self, f, mode="smooth"):
        self.tl.key(f, mode, root=dict(x=self.x, z=self.z, yaw=self.yaw))

    def travel(self, f0, f1, d=0.0, lateral=0.0, turn=0.0, mode="io2", end_mode="smooth"):
        self.root_key(f0, mode)
        dx, dz = self.fwd(d, lateral)
        self.x += dx
        self.z += dz
        self.yaw += turn
        self.root_key(f1, end_mode)

    # -- body ---------------------------------------------------------------
    def k(self, f, interp="smooth", lt=None, ut=None, head=None, blade=None, arms=None, feet=None,
          parts=None, overrides=None):
        p = dict(parts or {})
        if lt is not None:
            lt = list(lt) + [None] * (6 - len(lt))
            if lt[0] is not None:
                lt[0] += self.hip_pitch
            if lt[1] is not None:
                lt[1] += self.hip_yaw
            p["LowerTorso"] = tuple(lt)
        if ut is not None:
            p["UpperTorso"] = ut
        if head is not None:
            p["Head"] = head
        if blade is not None:
            b = list(blade)
            b[0] += self.blade_x
            b[1] += self.blade_y
            p["EmberBlade"] = tuple(b)
        self.tl.key(f, interp, parts=p, arms=arms, ik=feet, overrides=overrides)

    def spin_hips(self, f0, f1, deg, mode="io2"):
        c = self.tl.ch("LowerTorso.ry")
        base = self.tl.value("LowerTorso.ry", f0)
        c.add(f0, base, mode)
        c.add(f1, base + deg, "smooth")
        self.hip_yaw += deg

    def flip_hips(self, f0, f1, deg, mode="io2"):
        c = self.tl.ch("LowerTorso.rx")
        base = self.tl.value("LowerTorso.rx", f0)
        c.add(f0, base, mode)
        c.add(f1, base + deg, "smooth")
        self.hip_pitch += deg

    def twirl_blade(self, f0, f1, deg, axis="y", mode="io3"):
        ch = "EmberBlade.ry" if axis == "y" else "EmberBlade.rx"
        c = self.tl.ch(ch)
        base = self.tl.value(ch, f0)
        c.add(f0, base, mode)
        c.add(f1, base + deg, "smooth")
        if axis == "y":
            self.blade_y += deg
        else:
            self.blade_x += deg

    def marker(self, f, name, value=""):
        self.tl.marker(f, name, value)

    def world_foot(self, side, rel):
        """HRP-relative foot spec -> world spec using the CURRENT cursor root."""
        y = math.radians(self.yaw)
        x, z = rel.get("x", -0.5 if side == "L" else 0.5), rel.get("z", 0.0)
        wx = self.x + x * math.cos(y) + z * math.sin(y)
        wz = self.z - x * math.sin(y) + z * math.cos(y)
        out = dict(rel)
        out.update(x=wx, z=wz, yaw=rel.get("yaw", 0.0) + self.yaw, world=True)
        return out

    def foot_now(self, side, f):
        return {k: self.tl.value(f"IK.{side}.{k}", f) for k in ("x", "z", "yaw")}


# --------------------------------------------------------------------------
# Feet helpers (HRP-relative specs; converted to world at key time)
# --------------------------------------------------------------------------
def F(l=None, r=None, **common):
    out = {}
    for side, spec in (("L", l), ("R", r)):
        if spec is None:
            continue
        if spec == "pin":
            out[side] = {"pin": True, "w": 1.0}
            continue
        d = dict(STANCE_FEET[side])
        d.update(common)
        d.update(spec)
        out[side] = d
    return out


PIN = F(l="pin", r="pin")
STANCE_FEET_REL = F(l={}, r={})


def stance(ctx, f, interp="smooth", feet=True):
    body = dict(STANCE_BODY)
    ctx.k(f, interp, lt=body["LowerTorso"], ut=body["UpperTorso"], head=body["Head"],
          blade=(0.0, 0.0, 0.0), arms={k: dict(v) for k, v in STANCE_ARMS.items()},
          feet=STANCE_FEET_REL if feet else PIN)


# --------------------------------------------------------------------------
# Idle / transitions
# --------------------------------------------------------------------------
def breathe(ctx, t0, t1, depth=1.0, period=56):
    """Moving hold in stance: breathing, weight shift, eyes on target."""
    if t1 <= t0 + 8:
        return max(t0, t1)
    f = t0
    i = 0
    while f < t1:
        s = 1 if i % 2 == 0 else -1
        ctx.k(f, "sine_io",
              lt=(0.5 * s * depth, 10 + 2.0 * s * depth, 0.8 * s * depth, 0.0, -0.35 - 0.04 * depth * (1 + s), 0.0),
              ut=(-6 + 1.6 * s * depth, -14 - 1.0 * s * depth, 0.4 * s),
              head=(3 - 1.2 * s * depth, 5 + 1.5 * s * depth, 0.0), feet=PIN)
        f += period // 2
        i += 1
    return t1


def step(ctx, t0, dur=26, d=1.4, lateral=0.0, turn=0.0, lead="R", lift=0.35, lt=None, ut=None, head=None,
         end_feet=None):
    """Two-foot shuffle step: root travels, lead foot then trail foot land on
    their spots relative to the FINAL root (world-space arcs, no sliding)."""
    t1 = t0 + dur
    trail = "L" if lead == "R" else "R"
    start = {s_: ctx.foot_now(s_, t0) for s_ in ("L", "R")}
    ctx.k(t0, "smooth", feet={lead: {"pin": True, "w": 1.0}, trail: {"pin": True, "w": 1.0}})
    ctx.travel(t0, t1, d=d, lateral=lateral, turn=turn, mode="io2")
    end = end_feet or STANCE_FEET_REL
    for side, a, b, lf in ((lead, 0.05, 0.62, lift), (trail, 0.45, 1.0, lift * 0.8)):
        dst = ctx.world_foot(side, end[side])
        src = start[side]
        fa, fb = t0 + int(dur * a), t0 + int(dur * b)
        mid = dict(dst)
        mid.update(x=(src["x"] + dst["x"]) / 2, z=(src["z"] + dst["z"]) / 2, yaw=(src["yaw"] + dst["yaw"]) / 2,
                   lift=lf, pitch=-12)
        ctx.k(fa, "smooth", feet={side: {"pin": True, "w": 1.0}})
        ctx.k((fa + fb) // 2, "smooth", feet={side: mid})
        ctx.k(fb, "smooth", feet={side: {**dst, "lift": 0.0, "pitch": 0.0}})
    if lt is not None or ut is not None or head is not None:
        ctx.k(t0 + dur // 2, "smooth", lt=lt, ut=ut, head=head)
    return t1


def walk(ctx, t0, steps=3, stride=1.7, step_frames=30, r_arm=None, l_arm=None, sway=1.0):
    """Slow, heavy walk forward: alternating steps on world-space arcs,
    hip sway, chest counter-rotation, free arm swing, blade held low."""
    f = t0
    for i in range(steps):
        lead = "L" if i % 2 == 0 else "R"
        s_ = 1 if lead == "L" else -1
        src = ctx.foot_now(lead, f)
        ctx.k(f, "smooth", feet={"L": {"pin": True, "w": 1.0}, "R": {"pin": True, "w": 1.0}})
        ctx.travel(f, f + step_frames, d=stride, mode="linear" if 0 < i < steps - 1 else "io2")
        dst = ctx.world_foot(lead, {"x": -0.55 if lead == "L" else 0.55, "z": -0.15 if i == steps - 1 else -0.45,
                                    "yaw": 0.0, "lift": 0.0, "pitch": 0.0, "w": 1.0, "knee_out": 6.0})
        mid = dict(dst)
        mid.update(x=(src["x"] + dst["x"]) / 2, z=(src["z"] + dst["z"]) / 2, lift=0.4, pitch=-14)
        ctx.k(f + step_frames // 2, "smooth",
              lt=(-2, 6 * s_ * sway, 2 * s_ * sway, 0, -0.26, 0), ut=(-4, -6 * s_ * sway, -1.5 * s_ * sway),
              head=(2, 4 * s_ * sway, 0),
              feet={lead: mid},
              arms={"L": dict(l_arm) if l_arm else dict(grip=(-1.2, -0.8, -0.45 * s_), blade=(0.1, -0.4, -1.0),
                                                        up=(0, 1, 0)),
                    "R": dict(r_arm) if r_arm else dict(grip=(1.2, -0.95, -0.35), blade=(0.35, -0.3, -1.0),
                                                        up=(0, 1, 0))})
        ctx.k(f + step_frames, "smooth", lt=(0, 0, 0, 0, -0.36, 0), ut=(-5, 0, 0), head=(3, 0, 0),
              feet={lead: dst})
        f += step_frames
    return f


# --------------------------------------------------------------------------
# Sword moves
# --------------------------------------------------------------------------
CUTS = {
    # kind: (wind grip, wind blade, strike grip, strike blade, follow grip, follow blade,
    #        torso yaw wind/strike/follow, torso pitch wind/strike/follow)  — UT space
    "diag_a": ((1.3, 1.2, 0.35), (0.45, 0.7, 0.55), (0.55, 0.3, -1.25), (-0.35, -0.15, -1.0),
               (-0.1, -0.6, -0.95), (-0.75, -0.55, 0.35), (-34, 6, 40), (6, -14, -20)),
    "diag_b": ((-0.2, 1.05, -0.6), (-0.6, 0.75, 0.25), (0.8, 0.1, -1.25), (0.4, -0.2, -1.0),
               (1.45, -0.6, -0.3), (0.8, -0.5, 0.3), (34, -4, -40), (6, -12, -18)),
    "h_rl": ((1.5, 0.15, 0.45), (0.75, 0.05, 1.0), (0.3, 0.05, -1.45), (-0.25, 0.0, -1.0),
             (-0.1, -0.1, -0.85), (-1.0, 0.0, 0.3), (-45, 8, 55), (0, -6, -8)),
    "h_lr": ((-0.1, 0.0, -0.8), (-0.95, 0.05, 0.35), (0.9, 0.0, -1.3), (0.3, 0.0, -1.0),
             (1.55, -0.1, 0.2), (0.95, 0.1, 0.3), (36, -6, -42), (0, -6, -6)),
    "rise": ((-0.1, -0.7, -0.8), (-0.6, -0.45, -0.6), (0.9, 0.4, -1.2), (0.3, 0.6, -0.75),
             (1.3, 1.3, -0.2), (0.4, 0.9, 0.2), (26, -6, -30), (-18, 2, 14)),
    "down": ((0.7, 1.55, 0.45), (0.05, 0.45, 1.0), (0.45, 0.6, -1.35), (0.0, 0.2, -1.0),
             (0.4, -0.5, -1.2), (0.0, -0.6, -0.8), (-14, -2, 4), (12, -18, -28)),
    "thrust": ((1.3, -0.15, 0.6), (0.1, 0.1, -1.0), (0.35, 0.25, -1.6), (-0.05, 0.05, -1.0),
               (0.45, 0.2, -1.55), (-0.05, 0.0, -1.0), (-30, 18, 20), (2, -10, -10)),
}
LEFT_COUNTER = {
    "diag_a": ((-1.0, 0.2, -1.0), (-1.4, -0.4, 0.6)),
    "diag_b": ((-1.3, -0.3, 0.5), (-0.9, 0.0, -1.0)),
    "h_rl": ((-0.9, 0.0, -1.0), (-1.4, -0.3, 0.6)),
    "h_lr": ((-1.35, -0.2, 0.5), (-0.9, 0.1, -1.05)),
    "rise": ((-1.3, -0.4, 0.4), (-1.0, 0.4, -1.0)),
    "down": ((-0.9, 0.4, -1.1), (-1.3, -0.5, 0.6)),
    "thrust": ((-0.9, 0.3, -1.0), (-1.35, -0.2, 0.7)),
}


def _mx(v):
    return (-v[0], v[1], v[2])


def cut(ctx, t0, kind="diag_a", wind=14, travel=0.0, crouch=-0.6, settle=18, hit_marker="SLASH",
        trail=True, intensity=1.0, hand="R", hit_value=None, strike=3, follow=5):
    """Anticipation -> strike -> follow-through -> settle (flowing).
    hand="L" mirrors the cut onto the left arm (second blade)."""
    wg, wb, sg, sb, fg, fb, yaws, pitches = CUTS[kind]
    lw, lf = LEFT_COUNTER[kind]
    other = "L"
    if hand == "L":
        wg, wb, sg, sb, fg, fb = (_mx(v) for v in (wg, wb, sg, sb, fg, fb))
        lw, lf = _mx(lw), _mx(lf)
        yaws = tuple(-y for y in yaws)
        other = "R"
    tw = t0 + wind
    ts = tw + strike
    tf = ts + follow
    te = tf + settle
    if travel:
        step(ctx, t0 + max(0, wind - 12), dur=16, d=travel, lead="R", lift=0.3,
             end_feet=F(l=dict(x=-0.75, z=0.55, yaw=22), r=dict(x=0.62, z=-0.65, yaw=-8)))
    up_w = edge_up(wb, (Vector(sg) - Vector(wg)))
    up_s = edge_up(sb, (Vector(fg) - Vector(wg)))
    up_f = edge_up(fb, (Vector(fg) - Vector(sg)))
    ctx.k(tw, "in3",
          lt=(-4, yaws[0] * 0.35 + 10, 0, 0, crouch, 0), ut=(pitches[0], yaws[0] * 0.65, 0),
          head=(4, -yaws[0] * 0.5, 0),
          arms={hand: dict(grip=wg, blade=wb, up=up_w, space="ut"),
                other: dict(grip=lw, blade=(0.2 if other == "L" else -0.2, 0.15, -1.0) if not ctx.tl.dual else
                            ((0.3 if other == "R" else -0.3), -0.25, 1.0), up=(0, 1, 0), space="ut")})
    ctx.k(ts, "out3",
          lt=(-8, yaws[1] * 0.35 + 10, 0, 0, crouch - 0.12, -0.15 * intensity), ut=(pitches[1], yaws[1] * 0.65, 0),
          head=(8, -yaws[1] * 0.5, 0),
          arms={hand: dict(grip=sg, blade=sb, up=up_s, space="ut")})
    ctx.k(tf, "smooth",
          lt=(-9, yaws[2] * 0.35 + 10, 0, 0, crouch - 0.16, -0.1 * intensity), ut=(pitches[2], yaws[2] * 0.65, 0),
          head=(8, -yaws[2] * 0.45, 0),
          arms={hand: dict(grip=fg, blade=fb, up=up_f, space="ut"),
                other: dict(grip=lf, blade=(-0.2 if other == "L" else 0.2, -0.2, 1.0), up=(0, 1, 0), space="ut")})
    ctx.k(te, "smooth",
          lt=(-5, yaws[2] * 0.25 + 10, 0, 0, crouch + 0.1, 0), ut=(pitches[2] * 0.5, yaws[2] * 0.45, 0),
          head=(5, -yaws[2] * 0.3, 0))
    tag = "blade" if hand == "R" else "blade_l"
    if trail:
        ctx.marker(tw - TRAIL_LEAD, "TRAIL_START", tag)
        ctx.marker(tf + 4, "TRAIL_END", tag)
    ctx.marker(ts, hit_marker, hit_value if hit_value is not None else f"{kind}:{hand}")
    return te


def guard(ctx, f, interp="smooth", crouch=-0.45, feet=None):
    ctx.k(f, interp, lt=(0, 10, 0, 0, crouch, 0), ut=(-6, -12, 0), head=(3, 5, 0),
          arms={k: dict(v) for k, v in STANCE_ARMS.items()}, feet=feet)


def spin_cut(ctx, t0, hop=1.0, travel=1.5):
    """Airborne 360 spin with the blade held flat (full-circle sweep)."""
    tw = t0 + 12
    ctx.k(tw, "smooth", lt=(-10, 30, 0, 0, -0.95, 0), ut=(-10, -40, 0), head=(10, 30, 0),
          arms={"R": dict(grip=(1.55, -0.05, 0.35), blade=(0.85, 0.0, 0.75), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(-1.2, 0.3, -0.9), blade=(0.2, 0.1, -1.0), up=(0, 1, 0), space="ut")},
          feet=F(l=dict(x=-0.8, z=0.5, yaw=24), r=dict(x=0.65, z=-0.6, yaw=-8)))
    t_air = tw + 4
    t_land = tw + 26
    ctx.k(t_air, "smooth", feet={"L": {"w": 1.0}, "R": {"w": 1.0}})
    ctx.k(t_air + 4, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
          parts={"LeftUpperLeg": (55, 0, -6), "LeftLowerLeg": (-85, 0, 0), "LeftFoot": (-20, 0, 0),
                 "RightUpperLeg": (25, 0, 6), "RightLowerLeg": (-70, 0, 0), "RightFoot": (-25, 0, 0)})
    ctx.travel(t_air, t_land, d=travel, mode="io2")
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t_air, -0.7, "out2")
    ch.add(t_air + 11, -0.7 + hop * 1.7, "in2")
    ch.add(t_land, -0.9, "smooth")
    ctx.k(t_air + 11, "smooth", ut=(-4, 0, 0), head=(2, 0, 0),
          arms={"R": dict(grip=(1.6, 0.1, -0.35), blade=(0.9, 0.05, -0.4), up=(0, 1, 0), space="ut")})
    ctx.spin_hips(t_air, t_land - 2, 360, mode="io2")
    ctx.k(t_land - 3, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}})
    ctx.k(t_land, "out3", lt=(-12, None, 0, 0, None, 0), ut=(-12, -18, 0), head=(12, 16, 0),
          arms={"R": dict(grip=(1.5, -0.6, 0.2), blade=(0.85, -0.3, 0.4), up=(0, 1, 0), space="ut")},
          feet=F(l=dict(x=-0.85, z=0.55, yaw=24, w=1.0), r=dict(x=0.7, z=-0.7, yaw=-6, w=1.0)))
    ctx.marker(tw - 2, "TRAIL_START", "blade")
    ctx.marker(t_air + 9, "SPIN_SLASH", "spin")
    ctx.marker(t_land - 2, "TRAIL_END", "blade")
    ctx.marker(t_land, "LAND", "spin")
    return t_land + 16


def leap_cleave(ctx, t0, scale=1.0, travel=2.6, hold=20, impact_marker="IMPACT"):
    """The signature leaping cleave (validated in the 1.7 s version)."""
    def R(grip, blade, pole=None, up=None):
        from common import sag_spine
        return dict(grip=grip, blade=blade, up=up if up is not None else sag_spine(blade), pole=pole)

    T = lambda f: t0 + f  # noqa: E731
    ctx.k(T(10), "smooth", lt=(-8, 18, 0, 0, -0.85, 0.05), ut=(-20, -26, 2), head=(14, 14, 0),
          arms={"R": R((1.3, -1.35, 0.5), (0.35, -0.25, 1.0), pole=(1, -0.4, 0.2)),
                "L": dict(grip=(-0.8, -0.35, -1.05), blade=(0.15, 0.1, -1.0), up=(0, 1, 0), pole=(-0.7, -1, 0.3))},
          feet=PIN)
    ctx.k(T(16), "smooth", lt=(-2, 13, 0, 0, -0.72, 0.08), ut=(2, -22, 3), head=(4, 11, 0),
          arms={"R": R((1.25, 0.35, 0.55), (0.2, 0.15, 1.0), pole=(1, -0.2, 0.3))})
    ctx.k(T(22), "out3", lt=(4, 8, 0, 0, -0.55, 0.1), ut=(17, -16, 4), head=(-8, 8, 0),
          arms={"R": R((0.75, 1.75, 0.55), (0.05, 0.45, 1.0), pole=(1, 0.2, 0.6)),
                "L": dict(grip=(-0.9, 0.5, -1.2), blade=(0.15, 0.05, -1.0), up=(0, 1, 0), pole=(-0.8, -1, 0.3))})
    ctx.k(T(30), "in2", lt=(2, 6, 0, 0, -0.8, 0.05), ut=(16, -12, 3), head=(-4, 6, 0),
          arms={"R": R((0.72, 1.55, 0.6), (0.05, 0.45, 1.0), pole=(1, 0.2, 0.6))}, feet=PIN)
    ctx.marker(T(26), "CHARGE_PEAK", "cleave")
    ctx.marker(T(16), "TRAIL_START", "blade")
    ctx.marker(T(32), "LEAP", "cleave")
    lift = 1.15 * scale
    ctx.travel(T(30), T(40), d=travel, mode="out2")
    ctx.k(T(36), "smooth", lt=(12, 4, 0, 0, lift, 0.2), ut=(24, -8, 2), head=(-14, 4, 0),
          arms={"R": R((0.75, 2.85 + (lift - 1.15), 0.35), (0.1, 0.1, 1.0), pole=(1, 0.3, 0.7)),
                "L": dict(grip=(-1.1, 0.9, -1.2), blade=(0.2, 0.5, -1.0), up=(0, 1, 0), pole=(-0.8, -0.6, 0.2),
                          space="ut")},
          feet=F(l=dict(z=0.05, lift=1.35 * scale, pitch=-25), r=dict(z=-0.55, lift=1.55 * scale, pitch=-15)))
    ctx.k(T(38), "in2", lt=(0, 4, 0, 0, 0.35 * scale, 0.0), ut=(-12, -6, 1), head=(6, 3, 0),
          arms={"R": R((0.65, 2.55, -0.75), (0.05, 0.9, -0.45), pole=(1, -0.2, 0.5))},
          feet=F(l=dict(z=0.6, lift=0.7, pitch=-10), r=dict(z=-0.9, lift=0.6, pitch=0)))
    ctx.k(T(40), "out3", lt=(-10, 6, 0, 0, -1.0, -0.1), ut=(-30, -8, 0), head=(16, 4, 0),
          arms={"R": R((0.6, -1.45, -2.0), (-0.05, -0.38, -0.92), pole=(1, -0.6, 0.6)),
                "L": dict(grip=(-1.3, -1.0, 0.65), blade=(-0.3, -0.6, 1.0), up=(0, 1, 0), pole=(-1, -0.4, -0.2))},
          feet=F(l=dict(x=-0.85, z=0.95, yaw=28), r=dict(x=0.72, z=-0.95, yaw=-10)),
          overrides={"Head": "out2"})
    ctx.marker(T(41), impact_marker, "cleave")
    ctx.marker(T(42), "SHOCKWAVE", "cleave")
    ctx.marker(T(43), "DEBRIS", "cleave")
    ctx.marker(T(46), "TRAIL_END", "blade")
    ctx.tl.blade_ground_ok.append((T(39), T(43 + hold)))
    ctx.k(T(43), "smooth", lt=(-12, 6, 0, 0, -1.12, -0.12), ut=(-34, -8, -1), head=(11, 4, 0),
          arms={"R": R((0.6, -1.52, -2.02), (-0.05, -0.42, -0.91), pole=(1, -0.6, 0.6))}, feet=PIN)
    ctx.k(T(48), "smooth", lt=(-9, 6, 0, 0, -0.98, -0.08), ut=(-29, -9, 0), head=(15, 5, 0),
          arms={"R": R((0.6, -1.45, -2.0), (-0.05, -0.38, -0.92), pole=(1, -0.6, 0.6))})
    ctx.k(T(43 + hold), "io2", lt=(-10, 7, 0, 0, -1.02, -0.1), ut=(-31, -10, 1), head=(14, 6, 0),
          arms={"R": R((0.6, -1.47, -2.0), (-0.05, -0.39, -0.92), pole=(1, -0.6, 0.6))})
    return T(43 + hold)


def pull_flick(ctx, t0):
    """Pull the blade out of the ground and flick the embers off."""
    ctx.k(t0 + 6, "smooth", lt=(-4, 10, 0, 0, -0.7, 0.0), ut=(-12, -22, 3), head=(8, 10, 0),
          arms={"R": dict(grip=(1.4, -0.65, 0.05), blade=(0.45, 0.35, 1.0), up=(0, 0.3, -1), pole=(1, -0.5, 0.4)),
                "L": dict(grip=(-1.0, -1.1, -0.3), blade=(0.2, -0.3, -1.0), up=(0, 1, 0))},
          feet=F(l=dict(x=-0.8, z=0.8, yaw=26), r=dict(x=0.66, z=-0.75, yaw=-9, lift=0.25)))
    ctx.k(t0 + 14, "out3", lt=(0, 12, 0, 0, -0.45, 0.0), ut=(-6, -10, -3), head=(4, 2, 0),
          arms={"R": dict(grip=(1.45, -0.9, -0.6), blade=(0.85, -0.22, -0.4), up=(0.2, 1, 0), pole=(1, -0.6, 0.3))},
          feet=F(l=dict(x=-0.75, z=0.55, yaw=23), r=dict(x=0.6, z=-0.55, yaw=-8)))
    ctx.marker(t0 + 14, "FLICK", "ember_shed")
    return t0 + 30


def backflip(ctx, t0, back=3.2, height=2.2):
    """Crouch -> backflip (Root joint pitch +360) traveling back -> crouch land."""
    ctx.k(t0 + 10, "smooth", lt=(-14, 10, 0, 0, -1.0, 0.1), ut=(-18, -10, 0), head=(18, 6, 0),
          arms={"R": dict(grip=(1.3, -1.0, 0.4), blade=(0.3, -0.2, 1.0), up=(0, 1, 0)),
                "L": dict(grip=(-1.2, -1.0, 0.4), blade=(-0.2, -0.3, 1.0), up=(0, 1, 0))},
          feet=PIN)
    t_up = t0 + 14
    t_land = t0 + 44
    ctx.k(t_up, "smooth", feet={"L": {"w": 1.0}, "R": {"w": 1.0}})
    ctx.k(t_up + 5, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
          parts={"LeftUpperLeg": (85, 0, -6), "LeftLowerLeg": (-120, 0, 0), "LeftFoot": (-20, 0, 0),
                 "RightUpperLeg": (80, 0, 6), "RightLowerLeg": (-118, 0, 0), "RightFoot": (-20, 0, 0)})
    ctx.travel(t_up, t_land, d=-back, mode="io2")
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t_up, -0.9, "out2")
    ch.add(t_up + 14, height, "in2")
    ch.add(t_land, -0.95, "smooth")
    ctx.flip_hips(t_up, t_land - 3, 360, mode="io2")
    ctx.k(t_up + 14, "smooth", ut=(-25, -4, 0), head=(-10, 0, 0),
          arms={"R": dict(grip=(1.0, 0.2, -0.8), blade=(0.2, 0.9, -0.3), up=(0, 0, 1), space="ut"),
                "L": dict(grip=(-1.0, 0.0, -0.8), blade=(0.0, 0.5, -1.0), up=(0, 1, 0), space="ut")})
    ctx.k(t_land - 4, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
          parts={"LeftUpperLeg": (30, 0, -6), "LeftLowerLeg": (-40, 0, 0), "LeftFoot": (-10, 0, 0),
                 "RightUpperLeg": (20, 0, 6), "RightLowerLeg": (-35, 0, 0), "RightFoot": (-10, 0, 0)})
    ctx.k(t_land, "out3", lt=(-16, None, 0, 0, None, 0.0), ut=(-14, -10, 0), head=(16, 6, 0),
          arms={"R": dict(grip=(1.35, -1.2, 0.3), blade=(0.6, -0.15, 0.8), up=(0, 1, 0)),
                "L": dict(grip=(-1.1, -1.5, -0.6), blade=(0.0, -1.0, -0.3), up=(0, 0, -1))},
          feet=F(l=dict(x=-0.85, z=0.45, yaw=22, w=1.0), r=dict(x=0.75, z=-0.55, yaw=-8, w=1.0)))
    ctx.marker(t_up, "JUMP", "backflip")
    ctx.marker(t_land, "LAND", "backflip")
    return t_land + 14


def charge_overhead(ctx, t0, dur=100, crouch=-0.7):
    """Blade cocked overhead-behind, heat building, tremble ramp."""
    from common import sag_spine
    b = (0.05, 0.45, 1.0)
    ctx.k(t0 + 14, "smooth", lt=(4, 8, 0, 0, crouch, 0.1), ut=(16, -16, 4), head=(-8, 8, 0),
          arms={"R": dict(grip=(0.75, 1.75 + crouch + 0.55, 0.55), blade=b, up=sag_spine(b), pole=(1, 0.2, 0.6)),
                "L": dict(grip=(-0.9, 0.5, -1.2), blade=(0.15, 0.05, -1.0), up=(0, 1, 0))},
          feet=PIN)
    ctx.tl.fx(t0, tremble=0.0)
    ctx.tl.fx(t0 + dur, tremble=2.4)
    ctx.k(t0 + dur, "smooth", lt=(6, 6, 0, 0, crouch - 0.1, 0.12), ut=(20, -14, 4), head=(-10, 8, 0),
          arms={"R": dict(grip=(0.7, 1.8 + crouch + 0.55, 0.65), blade=(0.05, 0.35, 1.0),
                          up=sag_spine((0.05, 0.35, 1.0)), pole=(1, 0.2, 0.6))})
    ctx.marker(t0 + 6, "CHARGE_START", "overhead")
    ctx.marker(t0 + dur // 2, "CHARGE_STAGE", "2")
    ctx.marker(t0 + dur - 4, "CHARGE_PEAK", "overhead")
    ctx.tl.fx(t0 + dur + 2, tremble=0.0)
    return t0 + dur


def ignite(ctx, t0):
    """Ignition ritual: blade held flat before the chest, the left palm slides
    from guard to tip and the edge lights up behind it."""
    ctx.k(t0 + 18, "smooth", lt=(0, 4, 0, 0, -0.4, 0), ut=(-4, -4, 0), head=(-12, 0, 0),
          arms={"R": dict(grip=(0.75, 0.15, -1.0), blade=(-1.0, 0.05, -0.15), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(0.15, 0.25, -1.05), blade=(-1.0, 0.0, 0.0), up=(0, 1, 0), space="ut",
                          pole=(-0.8, -1, 0.4))},
          feet=PIN)
    ctx.k(t0 + 30, "smooth", head=(-14, 2, 0))
    ctx.k(t0 + 70, "io2", ut=(-6, 4, 0), head=(-10, 8, 0),
          arms={"L": dict(grip=(-1.4, 0.35, -0.95), blade=(-0.9, 0.3, 0.1), up=(0, 1, 0), space="ut",
                          pole=(-0.6, -1, 0.5))})
    ctx.k(t0 + 84, "smooth", head=(0, 4, 0),
          arms={"L": dict(grip=(-1.2, -0.3, -0.6), blade=(-0.2, -0.6, -0.8), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 30, "IGNITE", "start")
    ctx.marker(t0 + 70, "BLADE_LIT")
    return t0 + 90


def twirl(ctx, t0, dur=22, turns=1):
    ctx.k(t0, "smooth", arms={"R": dict(grip=(1.05, -0.2, -1.0), blade=(0.1, 0.0, -1.0), up=(0, 1, 0))})
    ctx.twirl_blade(t0 + 2, t0 + 2 + dur, 360 * turns, axis="y")
    ctx.marker(t0 + 2, "TRAIL_START", "twirl")
    ctx.marker(t0 + 4, "FLOURISH", "twirl")
    ctx.marker(t0 + dur, "TRAIL_END", "twirl")
    return t0 + dur + 6


def dash(ctx, t0, d=22.0, slash=True, turn_after=0.0):
    """Coil -> 2-frame burst -> cruise -> backhand draw cut -> skid stop."""
    ctx.k(t0 + 4, "smooth", lt=(-16, 4, 0, 0, -0.95, 0.15), ut=(-26, -6, 0), head=(26, 4, 0),
          arms={"R": dict(grip=(1.25, -1.3, 0.55), blade=(0.25, 0.05, 1.0), up=(0, 1, 0)),
                "L": dict(grip=(-0.85, -0.9, -0.75), blade=(0.2, -0.3, -1.0), up=(0, 1, 0))},
          feet=F(l=dict(x=-0.6, z=-0.6, yaw=6), r=dict(x=0.6, z=0.95, yaw=-6, lift=0.08, pitch=-32)))
    t = t0 + 6
    ctx.marker(t, "DASH_START")
    ctx.marker(t, "TRAIL_START", "body")
    # root path: burst -> cruise -> brake
    ctx.root_key(t, "in2")
    for frac, f_off, mode in ((0.092, 2, "linear"), (0.825, 10, "out3"), (0.98, 18, "out2"), (1.0, 26, "smooth")):
        x0, z0 = ctx.x, ctx.z
        dx, dz = ctx.fwd(d * frac)
        ctx.tl.key(t + f_off, mode, root=dict(x=x0 + dx, z=z0 + dz, yaw=ctx.yaw))
    dx, dz = ctx.fwd(d)
    ctx.x += dx
    ctx.z += dz
    ctx.k(t, "smooth", lt=(-30, 2, 0, 0, -0.7, 0.0), ut=(-24, -4, 0), head=(34, 2, 0),
          feet=F(l=dict(x=-0.6, z=-0.9, lift=0.35, pitch=-10), r=dict(x=0.62, z=1.35, lift=0.45, pitch=-55)))
    ctx.k(t + 3, "smooth", lt=(-38, 0, 2, 0, -0.55, 0.0), ut=(-24, -2, 0), head=(40, 0, 0),
          arms={"R": dict(grip=(1.3, -0.8, 0.85), blade=(0.12, -0.45, 1.0), up=(0, 1, 0.4), space="ut"),
                "L": dict(grip=(-1.3, -0.8, 0.85), blade=(-0.15, -0.6, 1.0), up=(0, 1, 0), space="ut",
                          pole=(-0.5, -1, 0.6))},
          feet=F(l=dict(x=-0.55, z=-1.0, lift=0.95, pitch=-20), r=dict(x=0.6, z=1.7, lift=1.05, pitch=-70)))
    for k_, off in enumerate((2, 5, 8)):
        ctx.marker(t + off, "AFTERIMAGE", str(k_ + 1))
    from common import hor_spine
    if slash:
        b16 = (-0.95, 0.05, 0.35)
        ctx.k(t + 10, "smooth", lt=(-30, 14, 0, 0, -0.6, 0.0), ut=(-16, 30, 0), head=(30, -24, 0),
              arms={"R": dict(grip=(-0.25, -0.75, -0.55), blade=b16, up=hor_spine(b16, -1.0),
                              pole=(1.0, -0.8, -0.6))},
              feet=F(l=dict(x=-0.65, z=-0.9, lift=0.55, pitch=-5), r=dict(x=0.65, z=1.0, lift=0.7, pitch=-40)))
        b19 = (0.95, 0.1, 0.25)
        ctx.k(t + 13, "out3", lt=(-18, -18, 0, 0, -0.85, 0.0), ut=(-8, -34, 0), head=(18, 30, 0),
              arms={"R": dict(grip=(1.55, -0.3, -0.25), blade=b19, up=hor_spine(b19, -1.0), pole=(1.0, -1.0, 0.4)),
                    "L": dict(grip=(-1.2, -0.7, -0.6), blade=(-0.6, -0.2, -0.8), up=(0, 1, 0))},
              feet=F(l=dict(x=-0.75, z=-0.9, lift=0.2, pitch=0), r=dict(x=0.7, z=0.9, lift=0.25, pitch=-20)),
              overrides={"ARM.R": "out4"})
        ctx.marker(t + 13, "SLASH", "draw_cut")
        ctx.marker(t + 10, "TRAIL_START", "blade")
        ctx.marker(t + 19, "TRAIL_END", "blade")
    # skid: feet plant where the body is at that moment (world)
    ctx.k(t + 15, "smooth", lt=(-6, -16, 0, 0, -1.15, 0.05), ut=(6, -26, -4), head=(6, 24, 0),
          feet=F(l=dict(x=-0.95, z=-0.95, yaw=10, lift=0, pitch=0, w=1), r=dict(x=0.85, z=1.05, yaw=-30, lift=0,
                                                                                  pitch=0)))
    ctx.marker(t + 15, "SKID", "dust")
    # feet slide with the last of the momentum (skid), then bite
    for side, rel in (("L", dict(x=-0.95, z=-0.95, yaw=10)), ("R", dict(x=0.85, z=1.05, yaw=-30))):
        ctx.k(t + 26, "smooth", feet={side: {**ctx.world_foot(side, rel), "lift": 0.0, "pitch": 0.0, "w": 1.0}})
    ctx.k(t + 20, "smooth", lt=(-14, -14, 0, 0, -1.05, -0.05), ut=(-12, -22, -2), head=(14, 20, 0),
          arms={"R": dict(grip=(1.45, -0.55, 0.15), blade=(0.85, -0.15, 0.55), up=(0, 1, 0)),
                "L": dict(grip=(-1.15, -0.5, -0.75), blade=(-0.4, -0.1, -0.9), up=(0, 1, 0))})
    ctx.marker(t + 24, "TRAIL_END", "body")
    end = t + 30
    if turn_after:
        ctx.travel(t + 26, end + 10, turn=turn_after, mode="io2")
        ctx.k(end + 10, "smooth", lt=(-4, -8, 0, 0, -0.75, 0.0), ut=(-6, -14, 0), head=(6, 12, 0),
              feet=F(l=dict(x=-0.82, z=-0.6, yaw=12), r=dict(x=0.75, z=0.75, yaw=-24)))
        end += 10
    return end


# --------------------------------------------------------------------------
# Energy moves (left hand casts; the blade arm counter-balances)
# --------------------------------------------------------------------------
def palm_shot(ctx, t0, power=1.0, marker="BOLT"):
    """Chamber at the right hip -> palm jab -> recoil."""
    ctx.k(t0 + 8, "in3", lt=(-4, -26, 0, 0, -0.75, 0.05), ut=(0, -32, 3), head=(4, 50, 0),
          arms={"L": dict(grip=(0.45, -0.8, -0.5), blade=(0.2, 0.35, -1.0), up=(-1, 0.4, 0), space="ut"),
                "R": dict(grip=(1.35, -1.1, 0.7), blade=(0.4, -0.2, 1.0), up=(0, 1, 0))},
          feet=PIN)
    ctx.k(t0 + 12, "out4", lt=(-8, 14, 0, 0, -0.72, -0.3 * power), ut=(-10, 18, -3), head=(6, -10, 0),
          arms={"L": dict(grip=(-0.5, 0.5, -1.62), blade=(0.0, 1.0, -0.2), up=(0, 0.2, 1.0), space="ut",
                          pole=(-1, -0.6, 0.2)),
                "R": dict(grip=(1.55, 0.1, 0.85), blade=(0.5, 0.45, 1.0), up=(0, 1, -0.5), space="ut")})
    ctx.k(t0 + 24, "smooth", lt=(-3, 10, 0, 0, -0.62, -0.1), ut=(-2, 10, -1), head=(4, -6, 0),
          arms={"L": dict(grip=(-0.75, 0.2, -1.3), blade=(0.1, 0.7, -0.7), up=(0, 0.3, 1.0), space="ut")})
    ctx.marker(t0 + 12, marker, f"{power:.1f}")
    return t0 + 26


def summon_circle(ctx, t0, dur=80):
    """Left hand traces a full circle in the air; the sigil answers."""
    pts = [(-0.4, 1.1, -1.25), (0.35, 0.55, -1.3), (-0.1, -0.35, -1.3), (-1.0, -0.2, -1.2), (-1.3, 0.6, -1.0),
           (-0.4, 1.1, -1.25)]
    ctx.k(t0 + 8, "smooth", lt=(0, 0, 0, 0, -0.45, 0), ut=(-2, -6, 0), head=(-4, 4, 0), feet=PIN)
    for i, p in enumerate(pts):
        ctx.k(t0 + 10 + int(i * (dur - 20) / (len(pts) - 1)), "smooth",
              arms={"L": dict(grip=p, blade=(0.0, 0.6, -1.0), up=(0, 0, 1), space="ut", pole=(-1, -0.8, 0.3))},
              head=(-4 + 2 * math.sin(i), 4 + 3 * math.cos(i), 0))
    ctx.k(t0 + dur, "smooth", arms={"L": dict(grip=(-1.2, -0.4, -0.8), blade=(0.1, -0.3, -1.0), up=(0, 1, 0))})
    ctx.marker(t0 + 12, "SUMMON", "circle")
    ctx.marker(t0 + dur - 10, "SIGIL_GROUND")
    return t0 + dur


def chamber_charge(ctx, t0, dur=200):
    """The long coil: palm at the right hip, body wound like a spring."""
    def H(grip, hand=(0.1, 0.3, -1.0), up=(-1, 0.4, 0)):
        return dict(grip=grip, blade=hand, up=up, pole=(-0.9, -1.0, 0.4))

    ctx.k(t0 + 14, "smooth", lt=(-4, -28, 0, 0, -0.62, 0.05), ut=(-8, -24, 3), head=(6, 40, 0),
          arms={"R": dict(grip=(1.35, -1.15, 0.65), blade=(0.45, -0.12, 1.0), up=(0, 1, 0)),
                "L": dict(grip=(-0.6, -0.1, -1.25), blade=(0.35, 0.6, -0.7), up=(0, 1, 0), space="ut",
                          pole=(-0.9, -1, 0.4))},
          feet=F(l=dict(x=-0.62, z=-0.75, yaw=8), r=dict(x=0.95, z=0.95, yaw=-38, lift=0, pitch=0)))
    ctx.marker(t0 + 14, "CHARGE_START", "orb_ignite")
    q = dur - 30
    stages = [(t0 + 14 + int(q * 0.33), -36, -42, -0.9, (0.55, -0.85, -0.55), 0.8),
              (t0 + 14 + int(q * 0.66), -42, -50, -0.98, (0.7, -0.95, -0.4), 1.6),
              (t0 + 14 + q, -46, -54, -1.02, (0.78, -1.0, -0.32), 2.6)]
    for i, (f, lty, uty, ty, g, trem) in enumerate(stages):
        ctx.k(f, "smooth", lt=(-5, lty, 0, 0, ty, 0.1), ut=(4, uty, 5), head=(2, 70 + i * 2, 0),
              arms={"L": H(g)})
        ctx.tl.fx(f, tremble=trem)
        if i < 2:
            ctx.marker(f, "CHARGE_STAGE", str(i + 2))
    ctx.marker(t0 + 14 + q, "CHARGE_PEAK")
    tc = t0 + dur - 10
    ctx.k(tc, "out2", lt=(-5, -47, 0, 0, -1.08, 0.12), ut=(4, -55, 6), head=(-6, 75, 0),
          arms={"L": H((0.82, -1.04, -0.28))})
    ctx.tl.fx(tc - 2, tremble=2.6)
    ctx.tl.fx(tc + 1, tremble=0.0, gain=0.25)
    ctx.marker(tc, "COMPRESS")
    ctx.k(t0 + dur, "out4", lt=(-5, -47, 0, 0, -1.09, 0.12), ut=(4, -55, 6), head=(-6, 75, 0),
          arms={"L": H((0.82, -1.05, -0.27)),
                "R": dict(grip=(1.3, -1.25, 0.85), blade=(0.35, -0.2, 1.0), up=(0, 1, 0))},
          feet=PIN)
    return t0 + dur


def beam_release(ctx, t0, sustain=200, sweep=50.0, recoil=1.2):
    """Stomp-lunge release, sustained beam that sweeps across, recoil skid."""
    ctx.k(t0 + 2, "smooth", feet=F(l=dict(x=-0.62, z=-1.0, yaw=6, lift=0.32, pitch=8)))
    ctx.k(t0 + 5, "smooth", lt=(-10, 20, 0, 0, -0.88, -0.55), ut=(-14, 22, -4), head=(8, -14, 0),
          arms={"L": dict(grip=(-0.5, 0.55, -1.6), blade=(0.0, 1.0, -0.2), up=(0, 0.2, 1.0), space="ut",
                          pole=(-1, -0.6, 0.2)),
                "R": dict(grip=(1.55, 0.15, 0.85), blade=(0.5, 0.5, 1.0), up=(0, 1, -0.5), space="ut")},
          feet=F(l=dict(x=-0.62, z=-1.3, yaw=6, lift=0, pitch=0), r=dict(x=0.85, z=1.25, yaw=-32, lift=0.08,
                                                                         pitch=-30)),
          overrides={"IK.L": "out4"})
    ctx.tl.fx(t0 + 2, gain=1.0, tremble=0.0)
    ctx.tl.fx(t0 + 6, tremble=2.0)
    ctx.marker(t0 + 4, "RELEASE", "beam")
    ctx.marker(t0 + 4, "SCREEN_FLASH")
    ctx.marker(t0 + 5, "STOMP", "dust")
    ctx.marker(t0 + 12, "BEAM_PEAK")
    # sweep: hips/chest rotate the beam across the field while recoil drags back
    n = 4
    for i in range(1, n + 1):
        f = t0 + 5 + int(sustain * i / n)
        a = sweep * math.sin(math.pi * i / n) * (1 if i % 2 else -0.6)
        ctx.k(f, "sine_io", lt=(-6, 18 + a * 0.4, 0, 0, -0.86, -0.4), ut=(2, 18 + a * 0.6, -3),
              head=(4, -10 - a * 0.2, 0),
              arms={"L": dict(grip=(-0.47, 0.64, -1.58), blade=(0.0, 1.0, -0.26), up=(0, 0.2, 1.0), space="ut",
                              pole=(-1, -0.6, 0.2))})
        if i in (2, 4):
            ctx.marker(f - 10, "SECONDARY_BURST", f"sweep{i}")
    ctx.travel(t0 + 8, t0 + 5 + sustain, d=-recoil, mode="out2")
    te = t0 + 5 + sustain
    for side, rel in (("L", dict(x=-0.62, z=-1.3, yaw=6)), ("R", dict(x=0.85, z=1.25, yaw=-32))):
        ctx.k(t0 + 8, "out2", feet={side: {"pin": True, "w": 1.0}})
        ctx.k(te, "smooth", feet={side: ctx.world_foot(side, rel)})
    ctx.tl.fx(te - 8, tremble=1.2)
    ctx.tl.fx(te + 4, tremble=0.0, gain=1.0)
    ctx.marker(te, "DISSIPATE")
    ctx.k(te + 8, "out3", lt=(-3, 14, 0, 0, -0.7, -0.2), ut=(-4, 6, -1), head=(6, -2, 0),
          arms={"L": dict(grip=(-0.95, -0.45, -1.0), blade=(0.25, -0.8, -0.5), up=(0, 0, -1)),
                "R": dict(grip=(1.45, -0.3, 0.6), blade=(0.5, 0.1, 1.0), up=(0, 1, 0), space="ut")})
    ctx.marker(te + 6, "HAND_SHAKE", "ember_shed")
    return te + 16


# --------------------------------------------------------------------------
# Extra moves for ANIM_02..05
# --------------------------------------------------------------------------
DANGLE = {
    "LeftUpperLeg": (10, 4, -3), "LeftLowerLeg": (-24, 0, 0), "LeftFoot": (-38, 0, 0),
    "RightUpperLeg": (-6, -5, 3), "RightLowerLeg": (-34, 0, 0), "RightFoot": (-32, 0, 0),
}
DANGLE_B = {
    "LeftUpperLeg": (-4, 6, -4), "LeftLowerLeg": (-30, 0, 0), "LeftFoot": (-34, 0, 0),
    "RightUpperLeg": (6, -3, 4), "RightLowerLeg": (-22, 0, 0), "RightFoot": (-40, 0, 0),
}
CURL = {
    "LeftUpperLeg": (78, 6, -6), "LeftLowerLeg": (-118, 0, 0), "LeftFoot": (-20, 0, 0),
    "RightUpperLeg": (66, -4, 6), "RightLowerLeg": (-112, 0, 0), "RightFoot": (-25, 0, 0),
}
KNEEL_FEET = dict(l=dict(x=-0.62, z=-0.75, yaw=10, w=1.0, lift=0),
                  r=dict(x=0.6, z=0.9, yaw=-8, w=1.0, lift=0.04, pitch=-58))


def focus(ctx, t0, dur=120):
    """Head bows, breath held, eyes snap up (GLINT)."""
    ctx.k(t0 + 20, "smooth", lt=(-4, 6, 0, 0, -0.55, 0), ut=(-10, -8, 0), head=(-22, 0, 0), feet=PIN)
    ctx.k(t0 + dur - 14, "smooth", lt=(-5, 6, 0, 0, -0.62, 0), ut=(-12, -8, 0), head=(-24, 2, 0))
    ctx.k(t0 + dur - 4, "out3", head=(10, 4, 0), ut=(-8, -10, 0))
    ctx.marker(t0 + dur - 4, "GLINT")
    return t0 + dur


def palm_sweep(ctx, t0):
    """Open palm sweeps right->left at chest height releasing a ring wave."""
    ctx.k(t0 + 10, "in2", lt=(-4, -30, 0, 0, -0.7, 0), ut=(-4, -36, 0), head=(4, 40, 0),
          arms={"L": dict(grip=(0.6, 0.3, -1.25), blade=(0.6, 0.6, -0.6), up=(-1, 0, 0), space="ut")}, feet=PIN)
    ctx.k(t0 + 18, "out3", lt=(-6, 30, 0, 0, -0.75, 0), ut=(-6, 38, 0), head=(4, -30, 0),
          arms={"L": dict(grip=(-1.55, 0.35, -0.6), blade=(-0.8, 0.5, -0.3), up=(0, 0, 1), space="ut")})
    ctx.marker(t0 + 14, "WAVE", "palm_sweep")
    ctx.k(t0 + 34, "smooth", lt=(-2, 12, 0, 0, -0.6, 0), ut=(-4, 8, 0), head=(4, -4, 0))
    return t0 + 34


def overload_slam(ctx, t0):
    """Left hand raised overhead gathering an overload orb, then slammed
    palm-first into the ground on one knee (VOID_SLAM)."""
    ctx.k(t0 + 20, "smooth", lt=(4, 0, 0, 0, -0.3, 0), ut=(14, 6, 0), head=(22, 0, 0),
          arms={"L": dict(grip=(-0.6, 2.2, -0.35), blade=(0.0, 1.0, 0.0), up=(0, 0, 1)),
                "R": dict(grip=(1.4, -0.9, 0.5), blade=(0.4, -0.3, 1.0), up=(0, 1, 0))},
          feet=F(l=dict(x=-0.62, z=-0.4, yaw=8), r=dict(x=0.62, z=0.4, yaw=-10)))
    ctx.marker(t0 + 20, "OVERLOAD", "orb_overhead")
    ctx.tl.fx(t0 + 20, tremble=0.4)
    ctx.k(t0 + 80, "smooth", lt=(6, 0, 0, 0, -0.25, 0), ut=(18, 4, 0), head=(26, 0, 0),
          arms={"L": dict(grip=(-0.55, 2.3, -0.3), blade=(0.0, 1.0, 0.05), up=(0, 0, 1))})
    ctx.tl.fx(t0 + 80, tremble=2.4)
    ctx.k(t0 + 88, "in4", lt=(8, 0, 0, 0, -0.2, 0), ut=(20, 4, 0), head=(28, 0, 0))
    ctx.tl.fx(t0 + 88, tremble=0.0)
    ctx.k(t0 + 96, "out3", lt=(-14, 4, 0, 0, -1.4, 0.05), ut=(-30, -2, 0), head=(-8, 0, 0),
          arms={"L": dict(grip=(-0.4, -2.55, -1.0), blade=(0.0, -0.2, -1.0), up=(0, 1, 0)),
                "R": dict(grip=(1.5, -0.6, 0.6), blade=(0.6, 0.2, 1.0), up=(0, 1, 0))},
          feet=F(**KNEEL_FEET))
    ctx.marker(t0 + 96, "VOID_SLAM")
    ctx.k(t0 + 104, "smooth", lt=(-10, 4, 0, 0, -1.3, 0.05), ut=(-24, -2, 0), head=(-2, 0, 0))
    ctx.k(t0 + 150, "io2", lt=(-11, 4, 0, 0, -1.34, 0.05), ut=(-26, -3, 0), head=(-10, 2, 0))
    return t0 + 150


def kneel_meditate(ctx, t0, dur=240):
    """Kneeling on one knee, blade planted point-down before the body (reverse
    grip), both hands on the pommel; slow breathing."""
    ctx.k(t0, "smooth", lt=(-6, 4, 0, 0, -1.35, 0.05), ut=(-8, -2, 0), head=(-18, 0, 0),
          blade=(180, 0, 0),
          arms={"R": dict(grip=(0.25, -0.75, -1.05), blade=(0.0, 1.0, 0.12), up=(0, 0, -1)),
                "L": dict(grip=(-0.1, -0.6, -1.02), blade=(0.0, 1.0, 0.12), up=(0, 0, -1), pole=(-1, -0.6, 0.3))},
          feet=F(**KNEEL_FEET))
    ctx.blade_x += 180
    f = t0 + 40
    i = 0
    while f < t0 + dur:
        s = 1 if i % 2 == 0 else -1
        ctx.k(f, "sine_io", lt=(-6 + 1.5 * s, 4, 0, 0, -1.35 + 0.03 * s, 0.05), ut=(-8 + 2.2 * s, -2, 0),
              head=(-18 + 1.5 * s, 0, 0))
        f += 40
        i += 1
    ctx.tl.blade_ground_ok.append((t0, t0 + dur + 30))
    return t0 + dur


def rise_draw(ctx, t0):
    """Stand up drawing the planted blade out of the ground (still reverse)."""
    ctx.k(t0 + 30, "smooth", lt=(-2, 6, 0, 0, -0.45, 0.0), ut=(2, -8, 0), head=(6, 4, 0),
          arms={"R": dict(grip=(0.85, 1.7, -0.55), blade=(0.05, 1.0, 0.1), up=(0, 0, -1)),
                "L": dict(grip=(-0.9, -0.2, -0.9), blade=(0.25, 0.1, -1.0), up=(0, 1, 0))},
          feet=F(l=dict(x=-0.66, z=-0.4, yaw=12), r=dict(x=0.62, z=0.55, yaw=-10, lift=0.0, pitch=0)))
    ctx.marker(t0 + 30, "BLADE_DRAWN")
    return t0 + 34


def regrip(ctx, t0):
    """Reverse grip -> forward grip with a twirl around the hand X axis."""
    ctx.k(t0, "smooth", arms={"R": dict(grip=(1.1, 0.2, -1.0), blade=(0.0, 0.2, -1.0), up=(0, 1, 0))})
    ctx.twirl_blade(t0 + 2, t0 + 14, 180, axis="x")
    ctx.marker(t0 + 2, "TRAIL_START", "twirl")
    ctx.marker(t0 + 2, "REGRIP", "twirl")
    ctx.marker(t0 + 16, "TRAIL_END", "twirl")
    return t0 + 18


def salute(ctx, t0):
    ctx.k(t0 + 24, "smooth", lt=(0, 0, 0, 0, -0.15, 0), ut=(-2, 0, 0), head=(-16, 0, 0),
          arms={"R": dict(grip=(0.12, 0.38, -0.8), blade=(0.0, 1.0, -0.08), up=(0, 0, 1)),
                "L": dict(grip=(0.1, 0.0, -0.8), blade=(0.0, 1.0, -0.08), up=(0, 0, 1), pole=(-1, -0.8, 0.4))},
          feet=F(l=dict(x=-0.5, z=0.05, yaw=8), r=dict(x=0.52, z=0.1, yaw=-6)))
    ctx.marker(t0 + 24, "SALUTE")
    return t0 + 30


def ascend_gather(ctx, t0, dur=560):
    """Levitation (Root joint), arms open, blade raised to the sky while a sun
    is gathered in three stages; slow rotation, dangling legs."""
    def U(lift, x, y, z):
        return (x, y + lift, z)
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t0, ctx.tl.value("LowerTorso.ty", t0), "io3")
    ch.add(t0 + 140, 3.2, "smooth")
    ctx.k(t0 + 6, "smooth", feet={"L": {"pin": True, "w": 1.0}, "R": {"pin": True, "w": 1.0}})
    ctx.k(t0 + 22, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}}, parts=dict(DANGLE))
    ctx.marker(t0, "ASCEND")
    ctx.k(t0 + 90, "smooth", lt=(6, 10, 0, 0, None, 0), ut=(10, -6, 2), head=(18, 6, 0),
          arms={"R": dict(grip=U(2.6, 1.45, 1.95, -0.25), blade=(0.2, 1.0, 0.15), up=(1, 0, 0)),
                "L": dict(grip=U(2.6, -1.75, 0.95, -0.35), blade=(-1.0, 0.1, -0.2), up=(0, 1, 0),
                          pole=(-0.4, -1, 0.6))})
    ctx.marker(t0 + 100, "SKY_SIGIL")
    ctx.marker(t0 + 160, "CHARGE_START", "sun_seed")
    ctx.tl.fx(t0 + 160, tremble=0.2)
    yaws = (24, -18, 30, -10, 8, -4)
    n = len(yaws)
    for i, yv in enumerate(yaws):
        f = t0 + 160 + int((dur - 170) * (i + 1) / n)
        lift = 3.15 + 0.06 * (i % 3)
        ctx.k(f, "smooth",
              parts=dict(DANGLE if i % 2 else DANGLE_B),
              lt=(4 + i, yv, 0, 0, lift, 0), ut=(14 + i, -yv * 0.3, 0), head=(28 + i, -yv * 0.2, 0),
              arms={"R": dict(grip=U(lift, 0.72, 2.3, -0.05), blade=(0.0, 1.0, 0.03 * (i % 2)), up=(1, 0, 0)),
                    "L": dict(grip=U(lift, -1.12, 2.05, -0.38), blade=(0.15, 1.0, -0.2), up=(0, 0, 1),
                              pole=(-1, -0.3, 0.6))})
        ctx.tl.fx(f, tremble=0.4 + 0.45 * i)
    ctx.marker(t0 + 260, "SUN_FORM")
    ctx.marker(t0 + 380, "SUN_GROW", "2")
    ctx.marker(t0 + 470, "SUN_GROW", "3")
    ctx.marker(t0 + dur - 6, "CHARGE_PEAK")
    return t0 + dur


def curl_dive_plunge(ctx, t0, top=3.3):
    """Curl + reverse grip + still beat, then dive and plunge (IMPACT)."""
    def U(lift, x, y, z):
        return (x, y + lift, z)
    ctx.k(t0 + 8, "smooth",
          parts=dict(CURL), lt=(-10, 0, 0, 0, top + 0.15, 0.1), ut=(-22, 0, 0), head=(-6, 0, 0),
          blade=(180, 0, 0),
          arms={"R": dict(grip=U(top + 0.15, 0.22, 1.25, -0.75), blade=(0.0, 1.0, 0.15), up=(0, 0, -1)),
                "L": dict(grip=U(top + 0.15, -0.12, 1.12, -0.72), blade=(0.0, 1.0, 0.15), up=(0, 0, -1),
                          pole=(-1, -0.6, 0.3))})
    ctx.blade_x += 180
    ctx.marker(t0 + 4, "REVERSE_GRIP")
    ctx.tl.fx(t0 + 6, tremble=2.8)
    ctx.tl.fx(t0 + 11, tremble=0.0, gain=0.2)
    ctx.k(t0 + 16, "in3", parts=dict(CURL), lt=(-12, 0, 0, 0, top + 0.2, 0.1), ut=(-24, 0, 0), head=(-8, 0, 0),
          feet={"L": {"w": 0.0}, "R": {"w": 0.0}})
    ctx.marker(t0 + 12, "COMPRESS")
    ctx.marker(t0 + 18, "DIVE")
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t0 + 18, top + 0.2, "in3")
    ctx.tl.fx(t0 + 22, gain=1.0)
    ctx.k(t0 + 22, "smooth", parts={
        "LeftUpperLeg": (14, 4, -3), "LeftLowerLeg": (-18, 0, 0), "LeftFoot": (-12, 0, 0),
        "RightUpperLeg": (-10, -4, 3), "RightLowerLeg": (-40, 0, 0), "RightFoot": (-30, 0, 0)},
        lt=(-6, 0, 0, 0, None, 0.05), feet={"L": {"w": 0.0}, "R": {"w": 0.0}})
    ctx.k(t0 + 28, "out4", lt=(-12, 4, 0, 0, -1.4, 0.05), ut=(-26, -2, 0), head=(-12, 0, 0),
          arms={"R": dict(grip=(0.25, -0.75, -1.05), blade=(0.0, 1.0, 0.12), up=(0, 0, -1)),
                "L": dict(grip=(-0.1, -0.88, -1.02), blade=(0.0, 1.0, 0.12), up=(0, 0, -1), pole=(-1, -0.6, 0.3))},
          feet=F(**KNEEL_FEET), overrides={"LowerTorso": "out3"})
    ctx.marker(t0 + 28, "IMPACT", "plunge")
    ctx.marker(t0 + 28, "FLASH")
    ctx.marker(t0 + 30, "PILLAR")
    ctx.marker(t0 + 30, "SHOCKWAVE", "ultimate")
    ctx.marker(t0 + 32, "DEBRIS", "ultimate")
    ctx.marker(t0 + 38, "SHOCKWAVE_2")
    ctx.marker(t0 + 50, "EMBER_RAIN")
    ctx.tl.fx(t0 + 30, tremble=1.4)
    ctx.tl.fx(t0 + 50, tremble=0.3)
    ctx.k(t0 + 34, "smooth", lt=(-9, 4, 0, 0, -1.28, 0.05), ut=(-20, -2, 0), head=(-2, 0, 0))
    ctx.tl.blade_ground_ok.append((t0 + 25, t0 + 400))
    return t0 + 40


def aerial_x(ctx, t0, travel=4.6):
    """Leap, hang time, X-cross double slash in the air, landing stab."""
    from common import sag_spine
    ctx.k(t0 + 6, "smooth", lt=(-10, 4, 0, 0, -1.0, 0.0), ut=(6, -10, 0), head=(-2, 6, 0),
          arms={"R": dict(grip=(1.3, -1.2, 0.55), blade=(0.3, -0.2, 1.0), up=(0, 1, 0)),
                "L": dict(grip=(-1.0, -1.1, -0.6), blade=(0.0, -0.4, -1.0), up=(0, 1, 0))},
          feet=PIN)
    ctx.k(t0 + 10, "smooth", feet={"L": {"w": 1.0}, "R": {"w": 1.0}})
    ctx.marker(t0 + 12, "LEAP", "x")
    ctx.k(t0 + 16, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
          parts={"LeftUpperLeg": (40, 0, -6), "LeftLowerLeg": (-70, 0, 0), "LeftFoot": (-25, 0, 0),
                 "RightUpperLeg": (-10, 0, 6), "RightLowerLeg": (-60, 0, 0), "RightFoot": (-35, 0, 0)})
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t0 + 10, -1.0, "out3")
    ch.add(t0 + 22, 2.6, "smooth")
    ch.add(t0 + 26, 2.55, "in2")
    ch.add(t0 + 42, -1.15, "out3")
    ctx.travel(t0 + 10, t0 + 42, d=travel, mode="io2")
    lift = 2.6
    ctx.k(t0 + 22, "smooth", lt=(10, 0, 0, 0, None, 0.0), ut=(16, -12, 4), head=(-10, 8, 0),
          arms={"R": dict(grip=(0.9, 1.6 + lift, 0.35), blade=(0.55, 0.55, 0.65), up=(-0.6, 0.4, -0.5),
                          pole=(1, 0.2, 0.6)),
                "L": dict(grip=(-0.95, 0.4 + lift, -1.2), blade=(0.2, 0.2, -1.0), up=(0, 1, 0))})
    ctx.marker(t0 + 20, "TRAIL_START", "x_cross")
    b88 = (-0.7, -0.55, -0.45)
    ctx.k(t0 + 28, "in2", lt=(-4, 14, 0, 0, None, 0.0), ut=(-14, 16, -6), head=(8, -10, 0),
          arms={"R": dict(grip=(0.2, -0.4, -1.1), blade=b88, up=(0.5, -0.6, 0.6), pole=(1, -0.6, -0.2),
                          grip_space="ut", dir_space="root")})
    ctx.marker(t0 + 28, "HIT", "x1")
    ctx.marker(t0 + 28, "X_SLASH", "1")
    ctx.k(t0 + 32, "out2", lt=(2, 4, 0, 0, None, 0.0), ut=(4, 20, 4),
          arms={"R": dict(grip=(-0.55, 2.6, -0.5), blade=(-0.45, 0.85, 0.3), up=(0.8, 0.2, -0.3),
                          pole=(1, -0.4, 0.4))})
    b96 = (0.7, -0.5, -0.5)
    ctx.k(t0 + 36, "in2", lt=(-8, -16, 0, 0, None, 0.0), ut=(-16, -18, 6), head=(10, 12, 0),
          arms={"R": dict(grip=(1.3, -0.55, -1.0), blade=b96, up=(-0.5, -0.6, 0.6), pole=(1, -0.8, 0.2),
                          grip_space="ut", dir_space="root"),
                "L": dict(grip=(-1.35, -0.2, 0.7), blade=(-0.5, 0.2, 0.8), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 36, "HIT", "x2")
    ctx.marker(t0 + 36, "X_SLASH", "2")
    ctx.k(t0 + 38, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}})
    ctx.k(t0 + 42, "out3", lt=(-14, 4, 0, 0, None, -0.1), ut=(-24, -8, 0), head=(16, 4, 0),
          arms={"R": dict(grip=(0.8, -0.6, -1.2), blade=(0.05, -0.62, -0.78), up=sag_spine((0.05, -0.62, -0.78)),
                          grip_space="ut", dir_space="root"),
                "L": dict(grip=(-1.25, -0.9, 0.55), blade=(-0.4, -0.5, 0.8), up=(0, 1, 0))},
          feet=F(l=dict(x=-0.85, z=0.75, yaw=24, w=1.0), r=dict(x=0.72, z=-0.85, yaw=-8, w=1.0)))
    ctx.marker(t0 + 42, "FINAL_IMPACT", "stab")
    ctx.marker(t0 + 44, "TRAIL_END", "x_cross")
    ctx.tl.blade_ground_ok.append((t0 + 41, t0 + 60))
    ctx.k(t0 + 52, "smooth", lt=(-12, 4, 0, 0, -1.05, -0.1), ut=(-22, -8, 0), head=(14, 4, 0))
    return t0 + 56



# --------------------------------------------------------------------------
# Dual-blade moves (AzureBlade on the left hand)
# --------------------------------------------------------------------------
def draw_second(ctx, t0):
    """Left hand reaches over the right shoulder and draws the second blade in
    a wide arc (the blade materialises from light at the grip)."""
    ctx.k(t0 + 18, "smooth", lt=(0, -12, 0, 0, -0.4, 0), ut=(-4, -26, 0), head=(4, 20, 0),
          arms={"L": dict(grip=(0.75, 1.1, 0.6), blade=(0.2, 0.4, 1.0), up=(0, 0, 1), space="ut",
                          pole=(-0.4, -0.3, 0.8))}, feet=PIN)
    ctx.marker(t0 + 18, "MATERIALIZE", "azure")
    ctx.k(t0 + 30, "out3", lt=(-4, 14, 0, 0, -0.55, 0), ut=(-8, 22, 0), head=(6, -10, 0),
          arms={"L": dict(grip=(-1.6, 0.25, -0.6), blade=(-0.9, 0.2, -0.4), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 26, "TRAIL_START", "blade_l")
    ctx.marker(t0 + 34, "TRAIL_END", "blade_l")
    ctx.marker(t0 + 30, "DRAW_FLASH")
    return t0 + 44


def x_guard(ctx, t0, hold=40):
    """Both blades crossed before the chest, edges out: skill activation."""
    ctx.k(t0 + 12, "smooth", lt=(-6, 0, 0, 0, -0.75, 0), ut=(-10, 0, 0), head=(6, 0, 0),
          arms={"R": dict(grip=(0.35, 0.15, -1.15), blade=(-0.55, 0.75, -0.3), up=(0, 0, -1), space="ut"),
                "L": dict(grip=(-0.35, 0.15, -1.15), blade=(0.55, 0.75, -0.3), up=(0, 0, -1), space="ut")},
          feet=F(l=dict(x=-0.8, z=0.35, yaw=18), r=dict(x=0.75, z=-0.4, yaw=-14)))
    ctx.marker(t0 + 12, "SKILL_ACTIVATE")
    ctx.tl.fx(t0 + 12, tremble=1.2)
    ctx.k(t0 + 12 + hold, "smooth", lt=(-7, 0, 0, 0, -0.8, 0), ut=(-12, 0, 0), head=(4, 0, 0))
    ctx.tl.fx(t0 + 12 + hold, tremble=0.0)
    return t0 + 12 + hold


def dual_open(ctx, t0):
    """Blades thrown wide from the X guard (the stream begins)."""
    ctx.k(t0 + 6, "out3", lt=(-6, 0, 0, 0, -0.7, 0), ut=(-6, 0, 0), head=(4, 0, 0),
          arms={"R": dict(grip=(1.6, -0.1, -0.5), blade=(0.95, 0.05, 0.2), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(-1.6, -0.1, -0.5), blade=(-0.95, 0.05, 0.2), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 6, "STREAM_START")
    return t0 + 10


def dual_rise(ctx, t0, travel=1.0):
    """Both blades sweep up together from low-wide to high (launcher)."""
    ctx.k(t0 + 10, "in3", lt=(-12, 0, 0, 0, -1.0, 0), ut=(-22, 0, 0), head=(14, 0, 0),
          arms={"R": dict(grip=(1.2, -0.9, -0.7), blade=(0.5, -0.5, -0.7), up=(0, 0, 1), space="ut"),
                "L": dict(grip=(-1.2, -0.9, -0.7), blade=(-0.5, -0.5, -0.7), up=(0, 0, 1), space="ut")},
          feet=PIN)
    ctx.k(t0 + 15, "out3", lt=(8, 0, 0, 0, -0.3, -0.2), ut=(14, 0, 0), head=(-12, 0, 0),
          arms={"R": dict(grip=(0.9, 1.5, -0.4), blade=(0.25, 0.95, 0.15), up=(0, 0, 1), space="ut"),
                "L": dict(grip=(-0.9, 1.5, -0.4), blade=(-0.25, 0.95, 0.15), up=(0, 0, 1), space="ut")})
    ctx.marker(t0 + 7, "TRAIL_START", "blade")
    ctx.marker(t0 + 7, "TRAIL_START", "blade_l")
    ctx.marker(t0 + 13, "SLASH", "dual_rise")
    ctx.marker(t0 + 19, "TRAIL_END", "blade")
    ctx.marker(t0 + 19, "TRAIL_END", "blade_l")
    return t0 + 22


def dual_cross_down(ctx, t0, crouch=-1.15):
    """Both blades from high-wide crossing down into an X on the ground."""
    ctx.k(t0 + 8, "in3", lt=(6, 0, 0, 0, -0.4, 0), ut=(16, 0, 0), head=(-8, 0, 0),
          arms={"R": dict(grip=(1.0, 1.55, 0.2), blade=(0.6, 0.6, 0.5), up=(0, 0, -1), space="ut"),
                "L": dict(grip=(-1.0, 1.55, 0.2), blade=(-0.6, 0.6, 0.5), up=(0, 0, -1), space="ut")})
    ctx.k(t0 + 13, "out3", lt=(-14, 0, 0, 0, crouch, -0.1), ut=(-30, 0, 0), head=(18, 0, 0),
          arms={"R": dict(grip=(-0.25, -0.5, -1.1), blade=(-0.6, -0.45, -0.65), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(0.25, -0.5, -1.1), blade=(0.6, -0.45, -0.65), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 5, "TRAIL_START", "blade")
    ctx.marker(t0 + 5, "TRAIL_START", "blade_l")
    ctx.marker(t0 + 12, "X_CROSS_IMPACT")
    ctx.marker(t0 + 18, "TRAIL_END", "blade")
    ctx.marker(t0 + 18, "TRAIL_END", "blade_l")
    return t0 + 30


def final_thrust(ctx, t0, travel=2.5):
    """Hit 16: both blades coiled back, then the right blade drives forward."""
    ctx.k(t0 + 14, "in4", lt=(-6, -30, 0, 0, -0.9, 0.2), ut=(0, -40, 0), head=(6, 40, 0),
          arms={"R": dict(grip=(1.4, 0.0, 0.8), blade=(0.15, 0.05, -1.0), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(-1.2, 0.3, -0.9), blade=(-0.4, 0.3, 0.85), up=(0, 1, 0), space="ut")},
          feet=PIN)
    ctx.tl.fx(t0 + 2, tremble=0.0)
    ctx.tl.fx(t0 + 14, tremble=2.0)
    ctx.marker(t0 + 6, "FINAL_COIL")
    step(ctx, t0 + 12, dur=10, d=travel, lead="R", lift=0.25,
         end_feet=F(l=dict(x=-0.8, z=0.9, yaw=24), r=dict(x=0.65, z=-1.0, yaw=-6)))
    ctx.k(t0 + 18, "out4", lt=(-12, 16, 0, 0, -0.95, -0.4), ut=(-10, 24, 0), head=(8, -14, 0),
          arms={"R": dict(grip=(0.4, 0.25, -1.65), blade=(-0.05, 0.05, -1.0), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(-1.55, 0.2, 0.7), blade=(-0.6, 0.35, 0.75), up=(0, 1, 0), space="ut")})
    ctx.tl.fx(t0 + 19, tremble=0.0)
    ctx.marker(t0 + 15, "TRAIL_START", "blade")
    ctx.marker(t0 + 18, "HIT", "16")
    ctx.marker(t0 + 18, "STARBURST_FINAL")
    ctx.marker(t0 + 24, "TRAIL_END", "blade")
    ctx.k(t0 + 60, "smooth", lt=(-11, 16, 0, 0, -0.92, -0.38), ut=(-9, 23, 0), head=(9, -12, 0))
    return t0 + 60


# --------------------------------------------------------------------------
# Free-hand / energy moves for ANIM_03..05
# --------------------------------------------------------------------------
def pierce_dash(ctx, t0, d=20.0, turn_after=0.0):
    """Dash with the lightning hand driven forward (blade arm held back)."""
    t_end = dash(ctx, t0, d=d, slash=False, turn_after=turn_after)
    t = t0 + 6
    palm = dict(grip=(-0.5, 0.45, -1.62), blade=(0.0, 0.25, -1.0), up=(0, 1, 0), space="ut",
                pole=(-1, -0.6, 0.2))
    for off in (3, 8, 12):
        ctx.k(t + off, "smooth", arms={"L": dict(palm),
                                       "R": dict(grip=(1.3, -0.7, 0.85), blade=(0.15, -0.3, 1.0), up=(0, 1, 0),
                                                 space="ut")})
    ctx.marker(t + 12, "PIERCE")
    ctx.marker(t + 15, "PIERCE_BURST")
    return t_end


def seals(ctx, t0, n=10, every=14):
    """Rapid two-hand seal sequence before the chest (both hands free)."""
    shapes = [
        ((0.08, 0.15, -0.95), (0.0, 1.0, -0.1), (-0.08, 0.15, -0.95), (0.0, 1.0, -0.1)),
        ((0.12, 0.25, -0.9), (-0.5, 0.6, -0.6), (-0.12, 0.25, -0.9), (0.5, 0.6, -0.6)),
        ((0.0, 0.05, -1.0), (0.0, 0.2, -1.0), (0.0, 0.25, -0.95), (0.0, -0.2, -1.0)),
        ((0.15, 0.35, -0.9), (-0.9, 0.3, -0.2), (-0.15, 0.2, -0.95), (0.9, 0.3, -0.2)),
        ((0.05, 0.4, -0.85), (0.0, 1.0, 0.2), (-0.05, 0.1, -0.95), (0.0, -1.0, -0.2)),
    ]
    f = t0
    for i in range(n):
        rg, rb_, lg, lb = shapes[i % len(shapes)]
        ctx.k(f + every - 4, "out3", head=(-6 + (i % 3), 0, 0),
              arms={"R": dict(grip=rg, blade=rb_, up=(0, 0, 1), space="ut"),
                    "L": dict(grip=lg, blade=lb, up=(0, 0, 1), space="ut", pole=(-1, -0.8, 0.4))})
        ctx.marker(f + every - 4, "SEAL", str(i + 1))
        f += every
    ctx.marker(f - 4, "SEAL_COMPLETE")
    return f


def palm_strike(ctx, t0, hand="L", travel=0.6, marker="BARRAGE_SHOT", value=""):
    """Quick palm thrust with either hand (mirrored), small step."""
    s = 1 if hand == "L" else -1
    other = "R" if hand == "L" else "L"
    ctx.k(t0 + 6, "in3", lt=(-4, -20 * s, 0, 0, -0.7, 0.05), ut=(0, -24 * s, 0), head=(4, 26 * s, 0),
          arms={hand: dict(grip=(0.35 * s, -0.75, -0.5), blade=(0.2 * s, 0.35, -1.0), up=(-s, 0.4, 0), space="ut"),
                other: dict(grip=(-1.1 * s, -0.2, -0.7), blade=(0.0, 0.3, -1.0), up=(0, 1, 0), space="ut")})
    if travel:
        step(ctx, t0 + 4, dur=10, d=travel, lead="R" if hand == "L" else "L", lift=0.22,
             end_feet=F(l=dict(x=-0.75, z=0.45, yaw=20), r=dict(x=0.65, z=-0.55, yaw=-10)))
    ctx.k(t0 + 10, "out4", lt=(-8, 16 * s, 0, 0, -0.75, -0.3), ut=(-8, 20 * s, 0), head=(6, -12 * s, 0),
          arms={hand: dict(grip=(-0.5 * s, 0.45, -1.62), blade=(0.0, 1.0, -0.2), up=(0, 0.2, 1.0), space="ut",
                           pole=(-s, -0.6, 0.2)),
                other: dict(grip=(1.4 * s, 0.0, 0.7), blade=(0.4 * s, 0.3, 1.0), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 10, marker, value or hand)
    ctx.k(t0 + 20, "smooth", lt=(-3, 8 * s, 0, 0, -0.62, -0.1), ut=(-2, 8 * s, 0), head=(3, -4 * s, 0))
    return t0 + 20


def sky_raise(ctx, t0, dur=60, hand="L"):
    """One arm raised straight to the sky, palm open, chest lifted."""
    s = 1 if hand == "L" else -1
    ctx.k(t0 + dur, "io2", lt=(4, 6 * s, 0, 0, -0.3, 0), ut=(10, 8 * s, 0), head=(26, 0, 0),
          arms={hand: dict(grip=(-0.75 * s, 2.3, -0.2), blade=(0.0, 1.0, 0.05), up=(0, 0, -1), space="ut",
                           pole=(-s, 0.2, 0.6))}, feet=PIN)
    ctx.marker(t0 + dur // 2, "SKY_RAISE")
    return t0 + dur


def point_down(ctx, t0, hand="L", dur=16):
    """The raised arm swings down to point at the target (command)."""
    s = 1 if hand == "L" else -1
    ctx.k(t0 + dur, "out3", lt=(-4, -10 * s, 0, 0, -0.45, -0.1), ut=(-8, -12 * s, 0), head=(6, 6 * s, 0),
          arms={hand: dict(grip=(-0.55 * s, 0.35, -1.65), blade=(0.0, 0.1, -1.0), up=(0, 1, 0), space="ut",
                           pole=(-s, -0.6, 0.2))})
    ctx.marker(t0 + dur, "COMMAND", hand)
    return t0 + dur


def overhead_throw(ctx, t0, hold_obj_marker="THROW"):
    """Overhand throw with the right hand (shuriken sphere)."""
    ctx.k(t0 + 16, "in3", lt=(6, -24, 0, 0, -0.55, 0.15), ut=(14, -34, 4), head=(-4, 30, 0),
          arms={"R": dict(grip=(1.1, 1.6, 0.8), blade=(0.0, 1.0, 0.3), up=(0, 0, -1), space="ut"),
                "L": dict(grip=(-1.3, 0.6, -1.0), blade=(0.2, 0.3, -1.0), up=(0, 1, 0), space="ut")},
          feet=PIN)
    ctx.k(t0 + 24, "out4", lt=(-14, 24, 0, 0, -0.85, -0.45), ut=(-22, 30, -4), head=(10, -18, 0),
          arms={"R": dict(grip=(0.3, 0.2, -1.6), blade=(0.0, -0.3, -1.0), up=(0, 1, 0), space="ut"),
                "L": dict(grip=(-1.45, -0.2, 0.7), blade=(-0.5, 0.3, 0.8), up=(0, 1, 0), space="ut")})
    ctx.marker(t0 + 22, hold_obj_marker)
    ctx.k(t0 + 44, "smooth", lt=(-8, 16, 0, 0, -0.7, -0.25), ut=(-12, 18, -2), head=(8, -10, 0),
          arms={"R": dict(grip=(0.6, -0.6, -1.2), blade=(0.2, -0.6, -0.8), up=(0, 1, 0), space="ut")})
    return t0 + 44
