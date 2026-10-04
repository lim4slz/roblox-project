"""
QA de movimento: interpenetração entre partes do corpo e giros bruscos de junta.

  blender -b ANIMATIONS/<NOME>/<NOME>.blend --python SCRIPTS/blender/check_motion.py -- [--from=0 --to=1920]

Escreve ANIMATIONS/<NOME>/<NOME>_motion_check.json
"""

import json
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
import rbx_common as rc

ARMS = ("LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")
BODY = ("Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg")
SKIP = {
    ("LeftUpperArm", "UpperTorso"),
    ("RightUpperArm", "UpperTorso"),
    ("LeftUpperArm", "Head"),
    ("RightUpperArm", "Head"),
}
DEPTH_TOL = 0.12
ARM_TORSO_TOL = 0.2
SPIN_DEG_PER_FRAME = 18.0


def obb(ob):
    m = ob.matrix_world
    corners = [m @ Vector(c) for c in ob.bound_box]
    center = sum(corners, Vector()) / 8
    axes = [m.col[i].xyz.normalized() for i in range(3)]
    half = [max(abs((c - center).dot(a)) for c in corners) for a in axes]
    return center, axes, half


def overlap_depth(a, b):
    ca, aa, ha = a
    cb, ab, hb = b
    d = cb - ca
    tests = list(aa) + list(ab)
    for u in aa:
        for v in ab:
            w = u.cross(v)
            if w.length > 1e-4:
                tests.append(w.normalized())
    depth = math.inf
    for axis in tests:
        ra = sum(h * abs(x.dot(axis)) for h, x in zip(ha, aa))
        rb = sum(h * abs(x.dot(axis)) for h, x in zip(hb, ab))
        o = ra + rb - abs(d.dot(axis))
        if o <= 0:
            return 0.0
        depth = min(depth, o)
    return depth


def joint_local(name, mats):
    parent = rc.PART_BY_NAME[name][1]
    if parent is None or parent not in mats:
        return None
    return (mats[parent].inverted() @ mats[name]).to_quaternion()


def ranges(frames):
    out = []
    for f in sorted(frames):
        if out and f - out[-1][1] <= 2:
            out[-1][1] = f
        else:
            out.append([f, f])
    return out


def main():
    args = rc.parse_script_args()
    opts = dict(a.split("=", 1) for a in args if "=" in a)
    scene = bpy.context.scene
    f0 = int(opts.get("--from", scene.frame_start))
    f1 = int(opts.get("--to", scene.frame_end))
    parts = [p[0] for p in rc.R15_PARTS if p[0] in bpy.data.objects and p[0] != "HumanoidRootPart"]
    pairs = [
        (a, b)
        for a in ARMS + ("EmberBlade",)
        for b in BODY
        if (a, b) not in SKIP and rc.PART_BY_NAME[a][1] != b and rc.PART_BY_NAME[b][1] != a
    ]
    if "AzureBlade" in parts and not bpy.data.objects["AzureBlade"].hide_render:
        pairs += [("AzureBlade", b) for b in BODY]
    pairs += [(a, b) for a in ("LeftLowerArm", "LeftHand") for b in ("RightLowerArm", "RightHand")]

    hits = {}
    spins = {}
    quats = {}
    prev = {}
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        mats = {p: bpy.data.objects[p].matrix_world.copy() for p in parts}
        boxes = {p: obb(bpy.data.objects[p]) for p in parts}
        for a, b in pairs:
            if bpy.data.objects[a].hide_render or bpy.data.objects[b].hide_render:
                continue
            dep = overlap_depth(boxes[a], boxes[b])
            tol = ARM_TORSO_TOL if ("LowerArm" in a or "UpperArm" in a) else DEPTH_TOL
            if dep > tol:
                hits.setdefault(f"{a}|{b}", []).append((f, round(dep, 3)))
        for p in parts:
            q = joint_local(p, mats)
            if q is None:
                continue
            if p in prev:
                ang = math.degrees(prev[p].rotation_difference(q).angle)
                ang = min(ang, 360.0 - ang)
                quats.setdefault(p, []).append((f, q))
                if ang > SPIN_DEG_PER_FRAME and not p.endswith("Blade"):
                    spins.setdefault(p, []).append((f, round(ang, 1)))
            prev[p] = q

    windows = {}
    for p, series in quats.items():
        if p.endswith("Blade") or p.startswith("Scarf"):
            continue
        sm = []
        for i in range(len(series)):
            acc = Quaternion((0, 0, 0, 0))
            ref = series[i][1]
            for j in range(max(0, i - 3), min(len(series), i + 4)):
                q = series[j][1]
                acc += q if q.dot(ref) >= 0 else -q
            acc.normalize()
            sm.append((series[i][0], acc))
        steps = []
        for i in range(1, len(sm)):
            a = math.degrees(sm[i - 1][1].rotation_difference(sm[i][1]).angle)
            steps.append((sm[i][0], min(a, 360.0 - a)))
        for i in range(len(steps)):
            tot, j = 0.0, i
            while j < len(steps) and steps[j][0] - steps[i][0] < 40:
                tot += steps[j][1]
                j += 1
            if tot > 200:
                windows.setdefault(p, []).append((steps[i][0], round(tot)))

    report = {
        "frames": [f0, f1],
        "depth_tolerance": DEPTH_TOL,
        "arm_vs_body_tolerance": ARM_TORSO_TOL,
        "spin_threshold_deg_per_frame": SPIN_DEG_PER_FRAME,
        "interpenetration": {
            k: {"ranges": ranges([f for f, _ in v]), "max_depth": max(d for _, d in v)} for k, v in sorted(hits.items())
        },
        "rotation_over_40_frames_gt_200deg": {
            k: {"ranges": ranges([f for f, _ in v]), "max_deg": max(d for _, d in v)}
            for k, v in sorted(windows.items())
        },
        "fast_joint_rotation": {
            k: {"ranges": ranges([f for f, _ in v]), "max_deg": max(d for _, d in v)} for k, v in sorted(spins.items())
        },
    }
    name = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
    out = os.path.join(os.path.dirname(bpy.data.filepath), f"{name}_motion_check.json")
    with open(out, "w") as fh:
        json.dump(report, fh, indent=1)
    print("MOTION CHECK", json.dumps(report))


main()
