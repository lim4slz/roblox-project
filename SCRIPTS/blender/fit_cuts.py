"""
Procura, pra cada corte da biblioteca (moves.CUTS), a pegada e o cotovelo mais perto do pedido
que fiquem dentro do alcance do braço R15 e sem encostar no corpo nem a lâmina no chão.
Imprime os valores pra colar no CUTS. Depois confira com o pose_lab.py.

  blender -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/fit_cuts.py -- [diag_a ...] [--guard]
"""

import itertools
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "abilities"))
import rbx_common as rc

rc.ensure_addon()
import anim_engine as ae
import moves as mv
from mathutils import Vector

TOL = {"LowerArm": 0.04, "Hand": 0.03, "blade": 0.03}
RMAX = 1.45


def contacts(world, sides=("Left", "Right")):
    tot, found = 0.0, {}
    for side in sides:
        for seg in ("LowerArm", "Hand"):
            box = ae._box(world, side + seg)
            for b in ae.BODY_VOLUMES:
                hit = ae._mtv(box, ae._box(world, b))
                if hit and hit[0] > TOL[seg]:
                    found[f"{side}{seg}|{b}"] = round(hit[0], 2)
                    tot += hit[0]
        blade = "EmberBlade" if side == "Right" else "AzureBlade"
        box = ae._box(world, blade)
        for b in ae.BODY_VOLUMES + ae.OTHER_ARM[blade]:
            hit = ae._mtv(box, ae._box(world, b))
            if hit and hit[0] > TOL["blade"]:
                found[f"{blade}|{b}"] = round(hit[0], 2)
                tot += hit[0]
    return tot, found


def project(side, grip, r_t):
    _, S, u1, u2, goff = ae._arm_consts(side)
    P = grip - r_t @ goff
    d = P - S
    if d.length > RMAX:
        P = S + d.normalized() * RMAX
    return P + r_t @ goff


POLES = [
    Vector((x, y, z)).normalized()
    for x in (0.3, 0.7, 1.2)
    for y in (-1.0, -0.4, 0.2, 0.7)
    for z in (-0.8, -0.3, 0.2, 0.7)
]
STEPS = [i * 0.15 for i in range(-5, 6)]
YSTEPS = [i * 0.15 for i in range(-3, 4)]


def fit(side, Ts, grip, r_t, pole, check_sides, root=None):
    pre = "Right" if side == "R" else "Left"
    sx = 1 if side == "R" else -1
    names = (f"{pre}UpperArm", f"{pre}LowerArm", f"{pre}Hand")
    base = {n: Ts[n].copy() for n in names}
    g0 = project(side, grip, r_t)
    p0 = Vector(pole).normalized()
    Tc = dict(Ts)
    w0, _ = ae._pose_arm(side, g0, r_t, p0, Tc, base, None)
    raw = contacts(w0, check_sides)
    best = None
    for p in POLES:
        p = Vector((p.x * sx, p.y, p.z))
        pdev = math.acos(max(-1, min(1, p.dot(p0))))
        for dx, dy, dz in itertools.product(STEPS, YSTEPS, STEPS):
            g = project(side, g0 + Vector((dx, dy, dz)), r_t)
            Tc = dict(Ts)
            world, _ = ae._pose_arm(side, g, r_t, p, Tc, base, None)
            tot, found = contacts(world, check_sides)
            if root is not None:
                bw = world["EmberBlade" if side == "R" else "AzureBlade"]
                c, ax, h = bw.to_translation(), [bw.col[i].xyz.normalized() for i in range(3)], ae.HALF["EmberBlade"]
                low = min(
                    (c + ax[0] * h.x * a + ax[1] * h.y * b + ax[2] * h.z * cc).y
                    for a in (-1, 1)
                    for b in (-1, 1)
                    for cc in (-1, 1)
                )
                low -= rc.FLOOR_Y
                if low < 0.15:
                    tot += 0.15 - low
                    found["floor"] = round(low, 2)
            score = (g - g0).length + 0.25 * pdev + tot * 20
            if best is None or score < best[0]:
                best = (score, g, p, tot, found)
    return g0, raw, best


def fmt(v):
    return "(" + ", ".join(f"{x:.2f}" for x in v) + ")"


args = rc.parse_script_args()
kinds = [a for a in args if not a.startswith("--")] or list(mv.CUTS)
out = {}
if "--guard" in args:
    tl = ae.Timeline("fit", 0, 80)
    tl.dual = True
    tl.scarf_params = None
    c = mv.Ctx(tl)
    mv.stance(c, 0)
    mv.dual_guard(c, 0)
    c.root_key(0)
    Ts, _ = ae._body_pose(tl, 0)
    grip, r_t, pole = ae._arm_controls(tl, "L", 0)
    g0, raw, best = fit("L", Ts, grip, r_t, pole, ("Left",))
    print(
        f"FIT guard L: {fmt(grip)} pole {fmt(pole)} raw={raw[1]}  -> {fmt(best[1])} pole {fmt(best[2])} left={best[4]}"
    )
    kinds = []
for kind in kinds:
    tl = ae.Timeline("fit", 0, 80)
    tl.dual = True
    tl.scarf_params = None
    c = mv.Ctx(tl)
    mv.stance(c, 0)
    mv.dual_guard(c, 0)
    c.root_key(0)
    mv.cut(c, 6, kind, wind=12, settle=10, hand="R", hit_value="x", strike=3, follow=5)
    row = []
    for f in (18, 21, 26):
        Ts, root = ae._body_pose(tl, f)
        g, rt, p = ae._arm_controls(tl, "L", f)
        ae._arm_solve("L", g, rt, p, Ts, Vector(), None)
        grip, r_t, pole = ae._arm_controls(tl, "R", f)
        g0, raw, best = fit("R", Ts, grip, r_t, pole, ("Right",), root)
        print(f"FIT {kind:7s} f{f}: {fmt(grip)} -> reach {fmt(g0)} raw={raw[1]}")
        print(f"FIT {kind:7s} f{f}:   best {fmt(best[1])} pole {fmt(best[2])} left={best[4]}")
        row.append(([round(v, 2) for v in best[1]], [round(v, 2) for v in best[2]]))
    out[kind] = row
print("FITJSON", json.dumps(out))
