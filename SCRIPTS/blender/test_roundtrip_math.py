"""Round trip numérico: T autorado -> basis do Blender -> o que o add-on exporta."""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy

import rbx_common as rc


def main():
    rc.ensure_addon()
    from roblox_animations.animation.serialization import serialize

    scene = rc.scene_setup()
    ao = bpy.data.objects["EMBER_R15"]
    bpy.context.view_layer.objects.active = ao
    rng = random.Random(1234)

    ao.animation_data_create()
    act = bpy.data.actions.new("TEST_ROUNDTRIP")
    ao.animation_data.action = act

    expected = {}
    frames = (1, 11)
    for f in frames:
        expected[f] = {}
        for name in rc.ANIMATED_PARTS:
            T = rc.roblox_T(
                rng.uniform(-80, 80),
                rng.uniform(-80, 80),
                rng.uniform(-80, 80),
                rng.uniform(-0.5, 0.5),
                rng.uniform(-0.5, 0.5),
                rng.uniform(-0.5, 0.5),
            )
            pb = ao.pose.bones[name]
            basis = rc.basis_from_roblox_T(pb, T)
            loc, rot, _ = basis.decompose()
            pb.location = loc
            pb.rotation_quaternion = rot
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            expected[f][name] = rc.mat_to_cf(T)

    for fc in rc_fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            if 'pose.bones["Head"]' in fc.data_path and int(kp.co.x) == 1:
                kp.interpolation = "CONSTANT"

    scene.frame_start, scene.frame_end = frames
    data = serialize(ao)
    kfs = data["kfs"]
    max_err = 0.0
    checked = 0
    for kf in kfs:
        frame = round(kf["t"] * rc.SCENE_FPS) + frames[0]
        if frame not in expected:
            continue
        for name, exp in expected[frame].items():
            got = kf["kf"].get(name)
            if got is None:
                raise AssertionError(f"missing pose {name} at frame {frame}")
            err = max(abs(a - b) for a, b in zip(got[0], exp))
            max_err = max(max_err, err)
            checked += 1
    head_styles = sorted({kf["kf"]["Head"][1] for kf in kfs if "Head" in kf["kf"]})
    arm_styles = sorted({kf["kf"]["LeftUpperArm"][1] for kf in kfs if "LeftUpperArm" in kf["kf"]})
    print(f"ROUNDTRIP poses checked={checked} max_abs_err={max_err:.3e}")
    print(f"ROUNDTRIP keyframes emitted={len(kfs)} (expect {frames[1] - frames[0] + 1} dense)")
    print(f"ROUNDTRIP Head styles={head_styles} LeftUpperArm styles={arm_styles}")
    ok = (
        checked == len(rc.ANIMATED_PARTS) * 2
        and max_err < 1e-4
        and len(kfs) == frames[1] - frames[0] + 1
        and "Constant" in head_styles
    )
    print("ROUNDTRIP RESULT:", "PASS" if ok else "FAIL")
    if not ok:
        sys.exit(1)


def rc_fcurves(act):
    from roblox_animations.core.utils import get_action_fcurves

    return get_action_fcurves(act)


if __name__ == "__main__":
    main()
