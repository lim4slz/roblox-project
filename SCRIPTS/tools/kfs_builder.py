#!/usr/bin/env python3
"""
.rbxanim do add-on -> spec reduzida de KeyframeSequence (json) para o
SCRIPTS/lune/build_kfs.luau montar o .rbxm.

O add-on não exporta KeyframeMarkers, então os markers vêm do _timing.json.
A redução só remove um keyframe se a interpolação linear do Roblox (slerp na
rotação, lerp na posição) entre os vizinhos reproduz ele dentro da tolerância
em todos os poses. Frames com marker, o primeiro e o último ficam sempre.
Depois reamostra em todo frame e meio frame contra o bake denso.

  python3 SCRIPTS/tools/kfs_builder.py [ANIM_01_ATOMIC_ECLIPSE ...]
"""

import json
import math
import os
import sys
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROT_TOL_DEG = 0.35
POS_TOL = 0.006
IDENT = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]

PARENTS = {
    "LowerTorso": "HumanoidRootPart",
    "UpperTorso": "LowerTorso",
    "Head": "UpperTorso",
    "LeftUpperArm": "UpperTorso",
    "LeftLowerArm": "LeftUpperArm",
    "LeftHand": "LeftLowerArm",
    "RightUpperArm": "UpperTorso",
    "RightLowerArm": "RightUpperArm",
    "RightHand": "RightLowerArm",
    "LeftUpperLeg": "LowerTorso",
    "LeftLowerLeg": "LeftUpperLeg",
    "LeftFoot": "LeftLowerLeg",
    "RightUpperLeg": "LowerTorso",
    "RightLowerLeg": "RightUpperLeg",
    "RightFoot": "RightLowerLeg",
    "EmberBlade": "RightHand",
    "AzureBlade": "LeftHand",
    "Scarf1": "UpperTorso",
    "Scarf2": "Scarf1",
    "Scarf3": "Scarf2",
    "Scarf4": "Scarf3",
}


def mat_to_quat(r):
    m00, m01, m02, m10, m11, m12, m20, m21, m22 = r
    tr = m00 + m11 + m22
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        q = (0.25 * s, (m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s)
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        q = ((m21 - m12) / s, 0.25 * s, (m01 + m10) / s, (m02 + m20) / s)
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        q = ((m02 - m20) / s, (m01 + m10) / s, 0.25 * s, (m12 + m21) / s)
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2
        q = ((m10 - m01) / s, (m02 + m20) / s, (m12 + m21) / s, 0.25 * s)
    n = math.sqrt(sum(c * c for c in q))
    return tuple(c / n for c in q)


def slerp(a, b, t):
    d = sum(i * j for i, j in zip(a, b))
    if d < 0:
        b, d = tuple(-c for c in b), -d
    if d > 0.9995:
        out = tuple(x + (y - x) * t for x, y in zip(a, b))
    else:
        th = math.acos(d)
        s = math.sin(th)
        wa, wb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
        out = tuple(wa * x + wb * y for x, y in zip(a, b))
    n = math.sqrt(sum(c * c for c in out))
    return tuple(c / n for c in out)


def pose_at(frames, bone, i):
    p = frames[i]["kf"].get(bone)
    cf = p[0] if p else IDENT
    return (cf[0], cf[1], cf[2]), mat_to_quat(cf[3:12])


def lerp_pose(pa, pb, t):
    return tuple(x + (y - x) * t for x, y in zip(pa[0], pb[0])), slerp(pa[1], pb[1], t)


def pose_err(pa, pb):
    d = min(1.0, abs(sum(i * j for i, j in zip(pa[1], pb[1]))))
    return math.degrees(2 * math.acos(d)), math.dist(pa[0], pb[0])


def reduce(frames, bones, forced):
    keep = [0]
    i, n = 0, len(frames)
    while i < n - 1:
        best = j = i + 1
        while j < n:
            ok = True
            for k in range(i + 1, j):
                t = (frames[k]["t"] - frames[i]["t"]) / (frames[j]["t"] - frames[i]["t"])
                for b in bones:
                    er, et = pose_err(lerp_pose(pose_at(frames, b, i), pose_at(frames, b, j), t), pose_at(frames, b, k))
                    if er > ROT_TOL_DEG or et > POS_TOL:
                        ok = False
                        break
                if not ok:
                    break
            if not ok:
                break
            best = j
            if j in forced:
                break
            j += 1
        keep.append(best)
        i = best
    return sorted(set(keep) | set(forced) | {n - 1})


def sample(frames, idxs, bone, t):
    for a, b in zip(idxs, idxs[1:]):
        if frames[a]["t"] <= t <= frames[b]["t"]:
            u = (t - frames[a]["t"]) / max(frames[b]["t"] - frames[a]["t"], 1e-9)
            return lerp_pose(pose_at(frames, bone, a), pose_at(frames, bone, b), u)
    return pose_at(frames, bone, idxs[-1])


def dense_sample(frames, bone, t, fps):
    i = min(int(t * fps), len(frames) - 2)
    u = (t - frames[i]["t"]) / max(frames[i + 1]["t"] - frames[i]["t"], 1e-9)
    return lerp_pose(pose_at(frames, bone, i), pose_at(frames, bone, i + 1), min(max(u, 0), 1))


def build(name, priority="Action", loop=False):
    folder = os.path.join(ROOT, "ANIMATIONS", name)
    with open(os.path.join(folder, name + ".rbxanim"), "rb") as f:
        data = json.loads(zlib.decompress(f.read()))
    with open(os.path.join(folder, name + "_timing.json")) as f:
        timing = json.load(f)
    fps = timing["fps"]
    frames = data["kfs"]
    bones = sorted({b for kf in frames for b in kf["kf"]})

    marker_idx = {}
    for m in timing["markers"]:
        marker_idx.setdefault(round(m["time_s"] * fps), []).append(m)
    keep = reduce(frames, bones, set(marker_idx))

    worst_r = worst_t = 0.0
    worst_at = None
    steps = (len(frames) - 1) * 2
    for s in range(steps + 1):
        t = s / (2 * fps)
        for b in bones:
            er, et = pose_err(sample(frames, keep, b, t), dense_sample(frames, b, t, fps))
            if er > worst_r:
                worst_r, worst_at = er, (round(t, 4), b)
            worst_t = max(worst_t, et)

    spec = {
        "name": name,
        "fps": fps,
        "duration": data["t"],
        "priority": priority,
        "loop": loop,
        "authored_hip_height": 2.0,
        "parents": PARENTS,
        "root": "HumanoidRootPart",
        "keyframes": [
            {
                "t": round(frames[i]["t"], 6),
                "frame": i + timing["frame_start"],
                "markers": [{"name": m["name"], "value": m.get("value", "")} for m in marker_idx.get(i, [])],
                "poses": {
                    b: [round(c, 6) for c in (frames[i]["kf"][b][0] if b in frames[i]["kf"] else IDENT)] for b in bones
                },
            }
            for i in keep
        ],
    }
    report = {
        "name": name,
        "dense_keyframes": len(frames),
        "kept_keyframes": len(keep),
        "reduction_pct": round(100 * (1 - len(keep) / len(frames)), 1),
        "tolerance": {"rot_deg": ROT_TOL_DEG, "pos_studs": POS_TOL},
        "validation_samples": (steps + 1) * len(bones),
        "max_rot_error_deg": round(worst_r, 4),
        "max_rot_error_at": worst_at,
        "max_pos_error_studs": round(worst_t, 5),
        "markers": len(timing["markers"]),
        "marker_frames_kept": all(i in keep for i in marker_idx),
        "bones": bones,
    }
    out = os.path.join(ROOT, "_cache", "kfs", name + ".kfs.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(spec, f, separators=(",", ":"))
    rep = os.path.join(ROOT, "EXPORT", "reports", name + "_reduction.json")
    os.makedirs(os.path.dirname(rep), exist_ok=True)
    with open(rep, "w") as f:
        json.dump(report, f, indent=2)
    return report


if __name__ == "__main__":
    names = sys.argv[1:] or sorted(
        d
        for d in os.listdir(os.path.join(ROOT, "ANIMATIONS"))
        if os.path.exists(os.path.join(ROOT, "ANIMATIONS", d, d + ".rbxanim"))
    )
    for n in names:
        r = build(n)
        print(json.dumps({k: v for k, v in r.items() if k != "bones"}))
