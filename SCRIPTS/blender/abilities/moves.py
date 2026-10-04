"""
Biblioteca de movimentos. Cada função recebe (ctx, frame inicial, ...) e devolve o
frame em que terminou, saindo da pose anterior sem voltar pra base.
"""

import math

from mathutils import Vector

from common import STANCE_ARMS, STANCE_BODY, STANCE_FEET


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

    def k(
        self,
        f,
        interp="smooth",
        lt=None,
        ut=None,
        head=None,
        blade=None,
        arms=None,
        feet=None,
        parts=None,
        overrides=None,
    ):
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
        y = math.radians(self.yaw)
        x, z = rel.get("x", -0.5 if side == "L" else 0.5), rel.get("z", 0.0)
        wx = self.x + x * math.cos(y) + z * math.sin(y)
        wz = self.z - x * math.sin(y) + z * math.cos(y)
        out = dict(rel)
        out.update(x=wx, z=wz, yaw=rel.get("yaw", 0.0) + self.yaw, world=True)
        return out

    def foot_now(self, side, f):
        return {k: self.tl.value(f"IK.{side}.{k}", f) for k in ("x", "z", "yaw")}


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
    ctx.k(
        f,
        interp,
        lt=body["LowerTorso"],
        ut=body["UpperTorso"],
        head=body["Head"],
        blade=(0.0, 0.0, 0.0),
        arms={k: dict(v) for k, v in STANCE_ARMS.items()},
        feet=STANCE_FEET_REL if feet else PIN,
    )


def breathe(ctx, t0, t1, depth=1.0, period=56):
    if t1 <= t0 + 8:
        return max(t0, t1)
    f = t0
    i = 0
    while f < t1:
        s = 1 if i % 2 == 0 else -1
        ctx.k(
            f,
            "sine_io",
            lt=(0.5 * s * depth, 10 + 2.0 * s * depth, 0.8 * s * depth, 0.0, -0.35 - 0.04 * depth * (1 + s), 0.0),
            ut=(-6 + 1.6 * s * depth, -14 - 1.0 * s * depth, 0.4 * s),
            head=(3 - 1.2 * s * depth, 5 + 1.5 * s * depth, 0.0),
            feet=PIN,
        )
        f += period // 2
        i += 1
    return t1


def step(
    ctx, t0, dur=26, d=1.4, lateral=0.0, turn=0.0, lead="R", lift=0.35, lt=None, ut=None, head=None, end_feet=None
):
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
        mid.update(
            x=(src["x"] + dst["x"]) / 2,
            z=(src["z"] + dst["z"]) / 2,
            yaw=(src["yaw"] + dst["yaw"]) / 2,
            lift=lf,
            pitch=-12,
        )
        ctx.k(fa, "smooth", feet={side: {"pin": True, "w": 1.0}})
        ctx.k((fa + fb) // 2, "smooth", feet={side: mid})
        ctx.k(fb, "smooth", feet={side: {**dst, "lift": 0.0, "pitch": 0.0}})
    if lt is not None or ut is not None or head is not None:
        ctx.k(t0 + dur // 2, "smooth", lt=lt, ut=ut, head=head)
    return t1


def walk(ctx, t0, steps=3, stride=1.7, step_frames=30, r_arm=None, l_arm=None, sway=1.0):
    f = t0
    for i in range(steps):
        lead = "L" if i % 2 == 0 else "R"
        s_ = 1 if lead == "L" else -1
        src = ctx.foot_now(lead, f)
        ctx.k(f, "smooth", feet={"L": {"pin": True, "w": 1.0}, "R": {"pin": True, "w": 1.0}})
        ctx.travel(f, f + step_frames, d=stride, mode="linear" if 0 < i < steps - 1 else "io2")
        dst = ctx.world_foot(
            lead,
            {
                "x": -0.55 if lead == "L" else 0.55,
                "z": -0.15 if i == steps - 1 else -0.45,
                "yaw": 0.0,
                "lift": 0.0,
                "pitch": 0.0,
                "w": 1.0,
                "knee_out": 6.0,
            },
        )
        mid = dict(dst)
        mid.update(x=(src["x"] + dst["x"]) / 2, z=(src["z"] + dst["z"]) / 2, lift=0.4, pitch=-14)
        ctx.k(
            f + step_frames // 2,
            "smooth",
            lt=(-2, 6 * s_ * sway, 2 * s_ * sway, 0, -0.26, 0),
            ut=(-4, -6 * s_ * sway, -1.5 * s_ * sway),
            head=(2, 4 * s_ * sway, 0),
            feet={lead: mid},
            arms={
                "L": (
                    dict(l_arm) if l_arm else dict(grip=(-1.2, -0.8, -0.45 * s_), blade=(0.1, -0.4, -1.0), up=(0, 1, 0))
                ),
                "R": dict(r_arm) if r_arm else dict(grip=(1.2, -0.95, -0.35), blade=(0.35, -0.3, -1.0), up=(0, 1, 0)),
            },
        )
        ctx.k(f + step_frames, "smooth", lt=(0, 0, 0, 0, -0.36, 0), ut=(-5, 0, 0), head=(3, 0, 0), feet={lead: dst})
        f += step_frames
    return f


def twirl(ctx, t0, dur=22, turns=1):
    ctx.k(t0, "smooth", arms={"R": dict(grip=(1.05, -0.2, -1.0), blade=(0.1, 0.0, -1.0), up=(0, 1, 0))})
    ctx.twirl_blade(t0 + 2, t0 + 2 + dur, 360 * turns, axis="y")
    ctx.marker(t0 + 2, "TRAIL_START", "twirl")
    ctx.marker(t0 + 4, "FLOURISH", "twirl")
    ctx.marker(t0 + dur, "TRAIL_END", "twirl")
    return t0 + dur + 6


DANGLE = {
    "LeftUpperLeg": (10, 4, -3),
    "LeftLowerLeg": (-24, 0, 0),
    "LeftFoot": (-38, 0, 0),
    "RightUpperLeg": (-6, -5, 3),
    "RightLowerLeg": (-34, 0, 0),
    "RightFoot": (-32, 0, 0),
}
DANGLE_B = {
    "LeftUpperLeg": (-4, 6, -4),
    "LeftLowerLeg": (-30, 0, 0),
    "LeftFoot": (-34, 0, 0),
    "RightUpperLeg": (6, -3, 4),
    "RightLowerLeg": (-22, 0, 0),
    "RightFoot": (-40, 0, 0),
}


TRAIL_LEAD = 3


def edge_up(blade, motion):
    """Spine vector (hand +Y) opposite to the swing motion -> edge leads."""
    b = Vector(blade).normalized()
    m = Vector(motion)
    m = m - b * m.dot(b)
    if m.length < 1e-4:
        return (0.0, 1.0, 0.0)
    return tuple(-m.normalized())


CUTS = {
    # (mão, lâmina, cotovelo) na preparação, no golpe e no follow-through; yaw e pitch do tronco
    "diag_a": (
        ((1.35, 1.25, 0.2), (0.4, 0.75, 0.5), (0.75, -0.4, 0.55)),
        ((0.65, 0.35, -1.2), (-0.4, -0.2, -0.9), (0.8, 0, -0.6)),
        ((0.4, 0.1, -0.95), (-0.8, -0.55, -0.2), (0.25, 0, -0.95)),
        (-34, 6, 40),
        (6, -14, -20),
    ),
    "diag_b": (
        ((0.45, 0.9, -1.25), (-0.6, 0.7, 0.2), (0.75, -0.6, 0.25)),
        ((0.95, 0.2, -1.3), (0.45, -0.2, -0.9), (0.7, -0.6, -0.35)),
        ((1.5, -0.55, -0.6), (0.85, -0.5, 0.15), (0.6, -0.6, -0.5)),
        (34, -4, -40),
        (6, -12, -18),
    ),
    "h_rl": (
        ((1.55, 0.2, 0.35), (0.75, 0.05, 0.65), (0.65, -0.65, 0.45)),
        ((0.7, 0.15, -1.3), (-0.3, 0, -0.95), (0.95, 0, -0.3)),
        ((0.3, 0.2, -0.9), (-0.95, 0, -0.25), (0.25, 0, -0.95)),
        (-45, 8, 55),
        (0, -6, -8),
    ),
    "h_lr": (
        ((0.3, 0.55, -1.25), (-0.95, 0.05, 0.1), (0.95, 0, 0.3)),
        ((1.05, 0.25, -1), (0.35, 0, -0.95), (0.6, 0, -0.8)),
        ((1.6, -0.05, -0.2), (0.95, 0.1, 0.2), (0.9, -0.45, 0.2)),
        (36, -6, -42),
        (0, -6, -6),
    ),
    "rise": (
        ((0.55, 0.1, -1.3), (-0.6, -0.5, -0.6), (0.75, 0.4, 0.55)),
        ((1.15, 0.45, -1.3), (0.3, 0.65, -0.7), (0.5, -0.85, -0.25)),
        ((1.5, 1.35, -0.35), (0.4, 0.9, 0.1), (0.7, -0.6, -0.35)),
        (26, -6, -30),
        (-18, 2, 14),
    ),
    "down": (
        ((1.05, 1.45, 0.1), (0.1, 0.5, 1), (0.75, -0.4, 0.55)),
        ((0.75, 0.55, -1.4), (0, 0.2, -1), (0.7, -0.6, -0.35)),
        ((0.9, -0.15, -1.05), (0.05, -0.65, -0.75), (0.6, 0, -0.8)),
        (-14, -2, 4),
        (12, -18, -28),
    ),
    "thrust": (
        ((1.35, -0.1, 0.55), (0.1, 0.1, -1), (0.75, -0.4, 0.55)),
        ((0.75, 0.35, -1.35), (-0.05, 0.05, -1), (0.6, 0, -0.8)),
        ((0.9, -0.05, -1.05), (-0.05, 0, -1), (0.55, 0, -0.85)),
        (-30, 18, 20),
        (2, -10, -10),
    ),
}


def _mx(v):
    return (-v[0], v[1], v[2])


def guard_arm(side, dual=True):
    sx = 1.0 if side == "R" else -1.0
    blade = (0.3 * sx, -0.25, 1.0) if dual else (-0.2 * sx, 0.15, -1.0)
    return dict(grip=(1.65 * sx, -0.3, 0.3), blade=blade, up=(0, 1, 0), space="ut", pole=(sx, -1.0, 0.2))


def dual_guard(ctx, f, interp="smooth", crouch=-0.6):
    ctx.k(
        f,
        interp,
        lt=(-4, 0, 0, 0, crouch, 0),
        ut=(-6, 0, 0),
        head=(4, 0, 0),
        arms={"R": guard_arm("R", ctx.tl.dual), "L": guard_arm("L", ctx.tl.dual)},
    )


def cut(
    ctx,
    t0,
    kind="diag_a",
    wind=14,
    travel=0.0,
    crouch=-0.6,
    settle=18,
    hit_marker="SLASH",
    trail=True,
    intensity=1.0,
    hand="R",
    hit_value=None,
    strike=3,
    follow=5,
):
    """Preparação -> golpe -> follow-through -> assenta. hand="L" espelha pro braço esquerdo."""
    (wg, wb, wp), (sg, sb, sp), (fg, fb, fp), yaws, pitches = CUTS[kind]
    other = "L" if hand == "R" else "R"
    if hand == "L":
        wg, wb, wp, sg, sb, sp, fg, fb, fp = (_mx(v) for v in (wg, wb, wp, sg, sb, sp, fg, fb, fp))
        yaws = tuple(-y for y in yaws)
    tw = t0 + wind
    ts = tw + strike
    tf = ts + follow
    te = tf + settle
    if travel:
        step(
            ctx,
            t0 + max(0, wind - 12),
            dur=16,
            d=travel,
            lead="R",
            lift=0.3,
            end_feet=F(l=dict(x=-0.75, z=0.55, yaw=22), r=dict(x=0.62, z=-0.65, yaw=-8)),
        )
    up_w = edge_up(wb, (Vector(sg) - Vector(wg)))
    up_s = edge_up(sb, (Vector(fg) - Vector(wg)))
    up_f = edge_up(fb, (Vector(fg) - Vector(sg)))
    off = guard_arm(other, ctx.tl.dual)
    ctx.k(
        tw,
        "in3",
        lt=(-4, yaws[0] * 0.35 + 10, 0, 0, crouch, 0),
        ut=(pitches[0], yaws[0] * 0.65, 0),
        head=(4, -yaws[0] * 0.5, 0),
        arms={hand: dict(grip=wg, blade=wb, up=up_w, space="ut", pole=wp), other: off},
    )
    ctx.k(
        ts,
        "out3",
        lt=(-8, yaws[1] * 0.35 + 10, 0, 0, crouch - 0.12, -0.15 * intensity),
        ut=(pitches[1], yaws[1] * 0.65, 0),
        head=(8, -yaws[1] * 0.5, 0),
        arms={hand: dict(grip=sg, blade=sb, up=up_s, space="ut", pole=sp)},
    )
    ctx.k(
        tf,
        "smooth",
        lt=(-9, yaws[2] * 0.35 + 10, 0, 0, crouch - 0.16, -0.1 * intensity),
        ut=(pitches[2], yaws[2] * 0.65, 0),
        head=(8, -yaws[2] * 0.45, 0),
        arms={hand: dict(grip=fg, blade=fb, up=up_f, space="ut", pole=fp), other: off},
    )
    ctx.k(
        te,
        "smooth",
        lt=(-5, yaws[2] * 0.25 + 10, 0, 0, crouch + 0.1, 0),
        ut=(pitches[2] * 0.5, yaws[2] * 0.45, 0),
        head=(5, -yaws[2] * 0.3, 0),
    )
    tag = "blade" if hand == "R" else "blade_l"
    if trail:
        ctx.marker(tw - TRAIL_LEAD, "TRAIL_START", tag)
        ctx.marker(tf + 4, "TRAIL_END", tag)
    ctx.marker(ts, hit_marker, hit_value if hit_value is not None else f"{kind}:{hand}")
    return te


def guard(ctx, f, interp="smooth", crouch=-0.45, feet=None):
    ctx.k(
        f,
        interp,
        lt=(0, 10, 0, 0, crouch, 0),
        ut=(-6, -12, 0),
        head=(3, 5, 0),
        arms={k: dict(v) for k, v in STANCE_ARMS.items()},
        feet=feet,
    )


def spin_cut(ctx, t0, hop=1.0, travel=1.5):
    """Airborne 360 spin with the blade held flat (full-circle sweep)."""
    tw = t0 + 12
    ctx.k(
        tw,
        "smooth",
        lt=(-10, 30, 0, 0, -0.95, 0),
        ut=(-10, -40, 0),
        head=(10, 30, 0),
        arms={
            "R": dict(grip=(1.55, -0.05, 0.35), blade=(0.85, 0.0, 0.75), up=(0, 1, 0), space="ut"),
            "L": dict(grip=(-1.2, 0.3, -0.9), blade=(0.2, 0.1, -1.0), up=(0, 1, 0), space="ut"),
        },
        feet=F(l=dict(x=-0.8, z=0.5, yaw=24), r=dict(x=0.65, z=-0.6, yaw=-8)),
    )
    t_air = tw + 4
    t_land = tw + 26
    ctx.k(t_air, "smooth", feet={"L": {"w": 1.0}, "R": {"w": 1.0}})
    ctx.k(
        t_air + 4,
        "smooth",
        feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
        parts={
            "LeftUpperLeg": (55, 0, -6),
            "LeftLowerLeg": (-85, 0, 0),
            "LeftFoot": (-20, 0, 0),
            "RightUpperLeg": (25, 0, 6),
            "RightLowerLeg": (-70, 0, 0),
            "RightFoot": (-25, 0, 0),
        },
    )
    ctx.travel(t_air, t_land, d=travel, mode="io2")
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t_air, -0.7, "out2")
    ch.add(t_air + 11, -0.7 + hop * 1.7, "in2")
    ch.add(t_land, -0.9, "smooth")
    ctx.k(
        t_air + 11,
        "smooth",
        ut=(-4, 0, 0),
        head=(2, 0, 0),
        arms={"R": dict(grip=(1.6, 0.1, -0.35), blade=(0.9, 0.05, -0.4), up=(0, 1, 0), space="ut")},
    )
    ctx.spin_hips(t_air, t_land - 2, 360, mode="io2")
    ctx.k(t_land - 3, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}})
    ctx.k(
        t_land,
        "out3",
        lt=(-12, None, 0, 0, None, 0),
        ut=(-12, -18, 0),
        head=(12, 16, 0),
        arms={"R": dict(grip=(1.5, -0.6, 0.2), blade=(0.85, -0.3, 0.4), up=(0, 1, 0), space="ut")},
        feet=F(l=dict(x=-0.85, z=0.55, yaw=24, w=1.0), r=dict(x=0.7, z=-0.7, yaw=-6, w=1.0)),
    )
    ctx.marker(tw - 2, "TRAIL_START", "blade")
    ctx.marker(t_air + 9, "SPIN_SLASH", "spin")
    ctx.marker(t_land - 2, "TRAIL_END", "blade")
    ctx.marker(t_land, "LAND", "spin")
    return t_land + 16


def backflip(ctx, t0, back=3.2, height=2.2):
    """Crouch -> backflip (Root joint pitch +360) traveling back -> crouch land."""
    ctx.k(
        t0 + 10,
        "smooth",
        lt=(-14, 10, 0, 0, -1.0, 0.1),
        ut=(-18, -10, 0),
        head=(18, 6, 0),
        arms={
            "R": dict(grip=(1.3, -1.0, 0.4), blade=(0.3, -0.2, 1.0), up=(0, 1, 0)),
            "L": dict(grip=(-1.2, -1.0, 0.4), blade=(-0.2, -0.3, 1.0), up=(0, 1, 0)),
        },
        feet=PIN,
    )
    t_up = t0 + 14
    t_land = t0 + 44
    ctx.k(t_up, "smooth", feet={"L": {"w": 1.0}, "R": {"w": 1.0}})
    ctx.k(
        t_up + 5,
        "smooth",
        feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
        parts={
            "LeftUpperLeg": (85, 0, -6),
            "LeftLowerLeg": (-120, 0, 0),
            "LeftFoot": (-20, 0, 0),
            "RightUpperLeg": (80, 0, 6),
            "RightLowerLeg": (-118, 0, 0),
            "RightFoot": (-20, 0, 0),
        },
    )
    ctx.travel(t_up, t_land, d=-back, mode="io2")
    ch = ctx.tl.ch("LowerTorso.ty")
    ch.add(t_up, -0.9, "out2")
    ch.add(t_up + 14, height, "in2")
    ch.add(t_land, -0.95, "smooth")
    ctx.flip_hips(t_up, t_land - 3, 360, mode="io2")
    ctx.k(
        t_up + 14,
        "smooth",
        ut=(-25, -4, 0),
        head=(-10, 0, 0),
        arms={
            "R": dict(grip=(1.0, 0.2, -0.8), blade=(0.2, 0.9, -0.3), up=(0, 0, 1), space="ut"),
            "L": dict(grip=(-1.0, 0.0, -0.8), blade=(0.0, 0.5, -1.0), up=(0, 1, 0), space="ut"),
        },
    )
    ctx.k(
        t_land - 4,
        "smooth",
        feet={"L": {"w": 0.0}, "R": {"w": 0.0}},
        parts={
            "LeftUpperLeg": (30, 0, -6),
            "LeftLowerLeg": (-40, 0, 0),
            "LeftFoot": (-10, 0, 0),
            "RightUpperLeg": (20, 0, 6),
            "RightLowerLeg": (-35, 0, 0),
            "RightFoot": (-10, 0, 0),
        },
    )
    ctx.k(
        t_land,
        "out3",
        lt=(-16, None, 0, 0, None, 0.0),
        ut=(-14, -10, 0),
        head=(16, 6, 0),
        arms={
            "R": dict(grip=(1.35, -1.2, 0.3), blade=(0.6, -0.15, 0.8), up=(0, 1, 0)),
            "L": dict(grip=(-1.1, -1.5, -0.6), blade=(0.0, -1.0, -0.3), up=(0, 0, -1)),
        },
        feet=F(l=dict(x=-0.85, z=0.45, yaw=22, w=1.0), r=dict(x=0.75, z=-0.55, yaw=-8, w=1.0)),
    )
    ctx.marker(t_up, "JUMP", "backflip")
    ctx.marker(t_land, "LAND", "backflip")
    return t_land + 14


def draw_second(ctx, t0):
    """Left hand reaches over the right shoulder and draws the second blade in
    a wide arc (the blade materialises from light at the grip)."""
    ctx.k(
        t0 + 18,
        "smooth",
        lt=(0, -12, 0, 0, -0.4, 0),
        ut=(-4, -26, 0),
        head=(4, 20, 0),
        arms={
            "L": dict(grip=(0.75, 1.1, 0.6), blade=(0.2, 0.4, 1.0), up=(0, 0, 1), space="ut", pole=(-0.4, -0.3, 0.8))
        },
        feet=PIN,
    )
    ctx.marker(t0 + 18, "MATERIALIZE", "azure")
    ctx.k(
        t0 + 30,
        "out3",
        lt=(-4, 14, 0, 0, -0.55, 0),
        ut=(-8, 22, 0),
        head=(6, -10, 0),
        arms={"L": dict(grip=(-1.6, 0.25, -0.6), blade=(-0.9, 0.2, -0.4), up=(0, 1, 0), space="ut")},
    )
    ctx.marker(t0 + 26, "TRAIL_START", "blade_l")
    ctx.marker(t0 + 34, "TRAIL_END", "blade_l")
    ctx.marker(t0 + 30, "DRAW_FLASH")
    return t0 + 44


def x_guard(ctx, t0, hold=40):
    """Both blades crossed before the chest, edges out: skill activation."""
    ctx.k(
        t0 + 12,
        "smooth",
        lt=(-6, 0, 0, 0, -0.75, 0),
        ut=(-10, 0, 0),
        head=(6, 0, 0),
        arms={
            "R": dict(grip=(0.35, 0.15, -1.15), blade=(-0.55, 0.75, -0.3), up=(0, 0, -1), space="ut"),
            "L": dict(grip=(-0.35, 0.15, -1.15), blade=(0.55, 0.75, -0.3), up=(0, 0, -1), space="ut"),
        },
        feet=F(l=dict(x=-0.8, z=0.35, yaw=18), r=dict(x=0.75, z=-0.4, yaw=-14)),
    )
    ctx.marker(t0 + 12, "SKILL_ACTIVATE")
    ctx.tl.fx(t0 + 12, tremble=1.2)
    ctx.k(t0 + 12 + hold, "smooth", lt=(-7, 0, 0, 0, -0.8, 0), ut=(-12, 0, 0), head=(4, 0, 0))
    ctx.tl.fx(t0 + 12 + hold, tremble=0.0)
    return t0 + 12 + hold


def dual_open(ctx, t0):
    """Blades thrown wide from the X guard (the stream begins)."""
    ctx.k(
        t0 + 6,
        "out3",
        lt=(-6, 0, 0, 0, -0.7, 0),
        ut=(-6, 0, 0),
        head=(4, 0, 0),
        arms={
            "R": dict(grip=(1.6, -0.1, -0.5), blade=(0.95, 0.05, 0.2), up=(0, 1, 0), space="ut"),
            "L": dict(grip=(-1.6, -0.1, -0.5), blade=(-0.95, 0.05, 0.2), up=(0, 1, 0), space="ut"),
        },
    )
    ctx.marker(t0 + 6, "STREAM_START")
    return t0 + 10


def dual_rise(ctx, t0, travel=1.0):
    """Both blades sweep up together from low-wide to high (launcher)."""
    ctx.k(
        t0 + 10,
        "in3",
        lt=(-12, 0, 0, 0, -1.0, 0),
        ut=(-22, 0, 0),
        head=(14, 0, 0),
        arms={
            "R": dict(grip=(1.2, -0.9, -0.7), blade=(0.5, -0.5, -0.7), up=(0, 0, 1), space="ut"),
            "L": dict(grip=(-1.2, -0.9, -0.7), blade=(-0.5, -0.5, -0.7), up=(0, 0, 1), space="ut"),
        },
        feet=PIN,
    )
    ctx.k(
        t0 + 15,
        "out3",
        lt=(8, 0, 0, 0, -0.3, -0.2),
        ut=(14, 0, 0),
        head=(-12, 0, 0),
        arms={
            "R": dict(grip=(0.9, 1.5, -0.4), blade=(0.25, 0.95, 0.15), up=(0, 0, 1), space="ut"),
            "L": dict(grip=(-0.9, 1.5, -0.4), blade=(-0.25, 0.95, 0.15), up=(0, 0, 1), space="ut"),
        },
    )
    ctx.marker(t0 + 7, "TRAIL_START", "blade")
    ctx.marker(t0 + 7, "TRAIL_START", "blade_l")
    ctx.marker(t0 + 13, "SLASH", "dual_rise")
    ctx.marker(t0 + 19, "TRAIL_END", "blade")
    ctx.marker(t0 + 19, "TRAIL_END", "blade_l")
    return t0 + 22


def dual_cross_down(ctx, t0, crouch=-1.15):
    """Both blades from high-wide crossing down into an X on the ground."""
    ctx.k(
        t0 + 8,
        "in3",
        lt=(6, 0, 0, 0, -0.4, 0),
        ut=(16, 0, 0),
        head=(-8, 0, 0),
        arms={
            "R": dict(grip=(1.0, 1.55, 0.2), blade=(0.6, 0.6, 0.5), up=(0, 0, -1), space="ut"),
            "L": dict(grip=(-1.0, 1.55, 0.2), blade=(-0.6, 0.6, 0.5), up=(0, 0, -1), space="ut"),
        },
    )
    ctx.k(
        t0 + 13,
        "out3",
        lt=(-14, 0, 0, 0, crouch, -0.1),
        ut=(-30, 0, 0),
        head=(18, 0, 0),
        arms={
            "R": dict(grip=(-0.25, -0.5, -1.1), blade=(-0.6, -0.45, -0.65), up=(0, 1, 0), space="ut"),
            "L": dict(grip=(0.25, -0.5, -1.1), blade=(0.6, -0.45, -0.65), up=(0, 1, 0), space="ut"),
        },
    )
    ctx.marker(t0 + 5, "TRAIL_START", "blade")
    ctx.marker(t0 + 5, "TRAIL_START", "blade_l")
    ctx.marker(t0 + 12, "X_CROSS_IMPACT")
    ctx.marker(t0 + 18, "TRAIL_END", "blade")
    ctx.marker(t0 + 18, "TRAIL_END", "blade_l")
    return t0 + 30


def final_thrust(ctx, t0, travel=2.5):
    """Hit 16: both blades coiled back, then the right blade drives forward."""
    ctx.k(
        t0 + 14,
        "in4",
        lt=(-6, -30, 0, 0, -0.9, 0.2),
        ut=(0, -40, 0),
        head=(6, 40, 0),
        arms={
            "R": dict(grip=(1.4, 0.0, 0.8), blade=(0.15, 0.05, -1.0), up=(0, 1, 0), space="ut"),
            "L": dict(grip=(-1.2, 0.3, -0.9), blade=(-0.4, 0.3, 0.85), up=(0, 1, 0), space="ut"),
        },
        feet=PIN,
    )
    ctx.tl.fx(t0 + 2, tremble=0.0)
    ctx.tl.fx(t0 + 14, tremble=2.0)
    ctx.marker(t0 + 6, "FINAL_COIL")
    step(
        ctx,
        t0 + 12,
        dur=10,
        d=travel,
        lead="R",
        lift=0.25,
        end_feet=F(l=dict(x=-0.8, z=0.9, yaw=24), r=dict(x=0.65, z=-1.0, yaw=-6)),
    )
    ctx.k(
        t0 + 18,
        "out4",
        lt=(-12, 16, 0, 0, -0.95, -0.4),
        ut=(-10, 24, 0),
        head=(8, -14, 0),
        arms={
            "R": dict(grip=(0.4, 0.25, -1.65), blade=(-0.05, 0.05, -1.0), up=(0, 1, 0), space="ut"),
            "L": dict(grip=(-1.55, 0.2, 0.7), blade=(-0.6, 0.35, 0.75), up=(0, 1, 0), space="ut"),
        },
    )
    ctx.tl.fx(t0 + 19, tremble=0.0)
    ctx.marker(t0 + 15, "TRAIL_START", "blade")
    ctx.marker(t0 + 18, "HIT", "16")
    ctx.marker(t0 + 18, "STARBURST_FINAL")
    ctx.marker(t0 + 24, "TRAIL_END", "blade")
    ctx.k(t0 + 60, "smooth", lt=(-11, 16, 0, 0, -0.92, -0.38), ut=(-9, 23, 0), head=(9, -12, 0))
    return t0 + 60
