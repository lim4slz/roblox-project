"""
Testa cada corte da biblioteca isolado (preparação, golpe e follow-through, mão direita e esquerda)
e mostra o que encosta no corpo, sem precisar fazer o bake da animação inteira.

  blender -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/pose_lab.py -- [diag_a h_rl ...] [--single]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "abilities"))

import anim_engine as ae
import moves as mv
import rbx_common as rc

ARMS = ("LowerArm", "Hand")
BODY = ae.BODY_VOLUMES


def contacts(world, dual):
    found = {}
    for side in ("Left", "Right"):
        for seg in ARMS:
            box = ae._box(world, side + seg)
            for b in BODY:
                hit = ae._mtv(box, ae._box(world, b))
                if hit and hit[0] > (0.2 if seg == "LowerArm" else 0.12):
                    found[f"{side}{seg}|{b}"] = hit[0]
    blades = [("EmberBlade", ae.OTHER_ARM["EmberBlade"])]
    if dual:
        blades.append(("AzureBlade", ae.OTHER_ARM["AzureBlade"]))
    for blade, other in blades:
        box = ae._box(world, blade)
        for b in BODY + other:
            hit = ae._mtv(box, ae._box(world, b))
            if hit and hit[0] > 0.12:
                found[f"{blade}|{b}"] = hit[0]
    return found


def run(kind, hand, dual):
    tl = ae.Timeline("lab", 0, 80)
    tl.dual = dual
    tl.scarf_params = None
    c = mv.Ctx(tl)
    mv.stance(c, 0)
    mv.dual_guard(c, 0) if dual else None
    c.root_key(0)
    end = mv.cut(c, 6, kind, wind=12, settle=10, hand=hand, hit_value="x", strike=3, follow=5)
    tl.frame_end = end + 4
    frames = ae.evaluate(tl)
    worst = {}
    for fr in frames:
        for k, d in contacts(fr["world"], dual).items():
            if d > worst.get(k, (0, 0))[0]:
                worst[k] = (round(d, 2), fr["frame"])
    return worst, tl


def main():
    rc.ensure_addon()
    args = rc.parse_script_args()
    kinds = [a for a in args if not a.startswith("--")] or list(mv.CUTS)
    dual = "--single" not in args
    total = 0
    for kind in kinds:
        for hand in ("R", "L") if dual else ("R",):
            worst, tl = run(kind, hand, dual)
            total += len(worst)
            tilt = {b: max(v) for b, v in getattr(tl, "blade_tilt", {}).items()}
            push = {s: max(v) for s, v in tl.arm_push.items()}
            items = ", ".join(f"{k} {d}@{f}" for k, (d, f) in sorted(worst.items(), key=lambda kv: -kv[1][0]))
            print(f"LAB {kind:7s} {hand}: {'ok' if not worst else items}   push={push} tilt={tilt}")
    print("LAB TOTAL", total)


main()
