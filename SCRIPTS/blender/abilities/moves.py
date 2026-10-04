"""
Biblioteca de movimentos. Cada função recebe (ctx, frame inicial, ...) e devolve o
frame em que terminou, saindo da pose anterior sem voltar pra base.
"""

import math

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
