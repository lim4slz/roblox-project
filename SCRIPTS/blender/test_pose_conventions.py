"""Confere as convenções de eixo/ângulo do roblox_T contra o serializer do add-on."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy

import anim_engine as ae
import previs
import rbx_common as rc

TESTS = [
    ("rest", {}),
    ("R arm fwd rx+90", {"RightUpperArm": (90, 0, 0)}),
    ("L arm side rz-90", {"LeftUpperArm": (0, 0, -90)}),
    ("torso fwd rx-30, head ry+40", {"UpperTorso": (-30, 0, 0), "Head": (0, 40, 0)}),
    ("R elbow rx+90, L knee rx-60", {"RightLowerArm": (90, 0, 0), "LeftLowerLeg": (-60, 0, 0)}),
    ("root ty-0.9 + IK planted", {"LowerTorso": (0, 0, 0, 0, -0.9, 0)}),
]


def main():
    rc.ensure_addon()
    scene = rc.scene_setup()
    ao = bpy.data.objects["EMBER_R15"]
    tl = ae.Timeline("TEST_CONVENTIONS", 1, len(TESTS))
    tl.scarf_params = {}
    for i, (_, parts) in enumerate(TESTS, start=1):
        base = {p: (0, 0, 0, 0, 0, 0) for p in rc.ANIMATED_PARTS if p not in ae.SCARF}
        base.update({k: tuple(v) + (0,) * (6 - len(v)) for k, v in parts.items()})
        tl.key(i, "hold", parts=base)
    tl.key(1, "hold", ik={"L": dict(x=-0.5, z=0, w=0), "R": dict(x=0.5, z=0, w=0)})
    tl.key(len(TESTS), "hold", ik={"L": dict(x=-0.55, z=0.25, w=1), "R": dict(x=0.55, z=-0.25, w=1)})
    frames = ae.evaluate(tl)
    ae.bake_to_action(ao, tl, frames, "TEST_CONVENTIONS")
    last = frames[-1]["world"]
    ankle_l = ae.joint_world(last, "LeftFoot").to_translation()
    print("IK ankle L", tuple(round(v, 4) for v in ankle_l), "target", (-0.55, ae.ANKLE_Y, 0.25))
    foot_l = last["LeftFoot"].to_translation()
    print("foot center y", round(foot_l.y, 4), "(expect", rc.PART_BY_NAME["LeftFoot"][2][1], ")")

    previs.setup_stage(scene, res=(480, 360), samples=8)
    previs.hide_rig_helpers()
    out = rc.repo_path("_cache", "pose_test")
    paths = []
    for cam_name, loc in (("front34", (5.5, 8.5, 0.5)), ("side", (11, 0, -0.5))):
        previs.setup_camera(scene, loc, (0, 0, -0.6), lens=30)
        paths += previs.render_frames(scene, list(range(1, len(TESTS) + 1)), out, prefix=cam_name)
    previs.contact_sheet(paths, os.path.join(out, "sheet.png"), cols=len(TESTS))


if __name__ == "__main__":
    main()
