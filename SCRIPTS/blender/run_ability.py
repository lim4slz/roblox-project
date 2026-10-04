"""
Monta, faz o bake, renderiza e exporta uma habilidade.

  RBX_ADDON_SRC=<zip do add-on> blender -b --factory-startup RIG/EMBER_R15_RIG.blend \
      --python SCRIPTS/blender/run_ability.py -- anim_01_atomic_eclipse [opções]

  --export        serialize() do add-on -> .rbxanim + checagem de round trip
  --sheet         contact sheet dos frames com marker
  --frames=a-b-s  renderiza só esses frames (debug)
  --clip=a-b-s    renderiza um trecho em mp4
  --video         vídeo completo do previs
  --lowres        480x270, menos samples
  --novfx         sem previs de VFX
"""

import importlib
import json
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "abilities"))

import bpy
from mathutils import Vector

import anim_engine as ae
import previs
import rbx_common as rc
import vfx_cues

CACHE = rc.repo_path("_cache")


def world_points(frames):
    out = []
    tip = Vector((0.0, 0.0, -2.5))
    base = Vector((0.0, 0.0, -0.9))
    grip = Vector(rc.PART_BY_NAME["EmberBlade"][4]) - Vector(rc.PART_BY_NAME["EmberBlade"][2])
    for fr in frames:
        w = fr["world"]
        pts = {
            "blade_tip": w["EmberBlade"] @ tip,
            "blade_base": w["EmberBlade"] @ base,
            "grip": w["EmberBlade"] @ grip,
        }
        if "AzureBlade" in w:
            pts["blade_l_tip"] = w["AzureBlade"] @ tip
            pts["blade_l_base"] = w["AzureBlade"] @ base
        for part in ("LeftHand", "RightHand", "Head", "UpperTorso", "LowerTorso", "LeftFoot", "RightFoot"):
            pts[part] = w[part].to_translation()
        pts["root"] = fr["root"].to_translation()
        out.append({k: [round(c, 4) for c in v] for k, v in pts.items()})
    return out


def blade_windows(tl):
    ob = bpy.data.objects.get("EmberBlade")
    if ob is None or tl.blade_hidden:
        return
    marks = sorted(tl.markers)
    offs = [f for f, n, _ in marks if n == "BLADE_DISSOLVE"]
    ons = [f for f, n, _ in marks if n == "BLADE_REFORM"]
    if not offs:
        return
    ob.hide_render = False
    ob.keyframe_insert("hide_render", frame=tl.frame_start)
    for f in offs:
        ob.hide_render = True
        ob.keyframe_insert("hide_render", frame=f + 18)
    for f in ons:
        ob.hide_render = False
        ob.keyframe_insert("hide_render", frame=f + 20)
    for fc in ob.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "CONSTANT"


def floor_check(tl, frames, anchors, ground_ok):
    bad = []
    for fr, a in zip(frames, anchors):
        y = a["blade_tip"][1] - a["root"][1]
        if y < rc.FLOOR_Y - 0.08 and not any(lo <= fr["frame"] <= hi for lo, hi in ground_ok):
            bad.append((fr["frame"], round(y, 2)))
    return bad


def setup_camera(scene, cam, frames):
    previs.setup_camera(
        scene, cam.get("loc", (7.0, 10.0, 1.0)), cam.get("target", (0, -1.0, -0.8)), lens=cam.get("lens", 30)
    )
    ob = scene.camera
    if cam.get("keys"):
        for kd in cam["keys"]:
            f = kd["frame"]
            if kd.get("cut"):
                ob.keyframe_insert("location", frame=f - 1)
                ob.keyframe_insert("rotation_euler", frame=f - 1)
                ob.data.keyframe_insert("lens", frame=f - 1)
            ob.location = kd["loc"]
            ob.rotation_euler = (Vector(kd["target"]) - Vector(kd["loc"])).to_track_quat("-Z", "Y").to_euler()
            ob.data.lens = kd.get("lens", 28)
            ob.keyframe_insert("location", frame=f)
            ob.keyframe_insert("rotation_euler", frame=f)
            ob.data.keyframe_insert("lens", frame=f)
        for fc in ob.animation_data.action.fcurves:
            pts = fc.keyframe_points
            for i in range(len(pts) - 1):
                cut = abs(pts[i + 1].co.x - pts[i].co.x - 1) < 1e-3
                pts[i].interpolation = "CONSTANT" if cut else "BEZIER"
    elif cam.get("track"):
        k = float(cam["track"])
        base = Vector(cam["loc"])
        smooth = Vector((0, 0, 0))
        for fr in frames:
            r = fr["root"].to_translation()
            smooth = smooth.lerp(Vector((r.x, -r.z, r.y)) * k, 0.35)
            ob.location = base + smooth
            ob.keyframe_insert("location", frame=fr["frame"])


def export(ao, tl, frames, timing, out_dir, name):
    from roblox_animations.animation.serialization import serialize

    data = serialize(ao)
    data.setdefault("export_info", {})["markers"] = timing["markers"]
    raw = json.dumps(data, separators=(",", ":"))
    with open(os.path.join(out_dir, f"{name}.rbxanim"), "wb") as f:
        f.write(zlib.compress(raw.encode("utf-8"), 9))

    # compara o que o add-on gerou com o T autorado frame a frame
    by_f = {fr["frame"]: fr for fr in frames}
    max_err, missing, checked = 0.0, 0, 0
    ident = rc.cf_translation(0, 0, 0)
    for kf in data["kfs"]:
        fr = by_f.get(round(kf["t"] * rc.SCENE_FPS) + tl.frame_start)
        if fr is None:
            continue
        for part, T in fr["T"].items():
            exp = rc.mat_to_cf(T)
            got = kf["kf"].get(part)
            if got is None:
                if max(abs(a - b) for a, b in zip(exp, ident)) > 1e-5:
                    missing += 1
                continue
            max_err = max(max_err, max(abs(a - b) for a, b in zip(got[0], exp)))
            checked += 1
    check = {
        "addon_version": rc.addon_version(),
        "keyframes": len(data["kfs"]),
        "frames_expected": tl.frame_end - tl.frame_start + 1,
        "duration_s": data["t"],
        "poses_checked": checked,
        "max_abs_component_error": max_err,
        "missing_nonidentity_poses": missing,
        "easing_styles": sorted({p[1] for kf in data["kfs"] for p in kf["kf"].values()}),
    }
    rc.write_json(os.path.join(out_dir, f"{name}_export_check.json"), check)
    print("EXPORT CHECK", json.dumps(check))


def frames_to_video(scene, fr_list, tmp_dir, out_path, fps):
    previs.render_frames(scene, fr_list, tmp_dir, prefix="f")
    seq = os.path.join(tmp_dir, "seq")
    os.makedirs(seq, exist_ok=True)
    for i, f in enumerate(fr_list):
        dst = os.path.join(seq, f"s_{i:04d}.png")
        if os.path.exists(dst):
            os.remove(dst)
        os.link(os.path.join(tmp_dir, f"f_{f:04d}.png"), dst)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    previs.encode_video(seq, "s", fps, out_path, 0)


def main():
    args = rc.parse_script_args()
    mod_name, flags = args[0], set(args[1:])
    opts = dict(a.split("=", 1) for a in flags if "=" in a)

    rc.ensure_addon()
    scene = rc.scene_setup()
    mod = importlib.import_module(mod_name)
    meta = mod.META
    name = meta["name"]

    ae.ARM_WARNINGS.clear()
    tl = mod.build()
    tl.blade_ground_ok = list(tl.blade_ground_ok) + list(meta.get("blade_ground_ok", []))
    for w in ae.ARM_WARNINGS:
        print("ARM WARNING:", w)

    ao = bpy.data.objects["EMBER_R15"]
    frames = ae.evaluate(tl)
    ae.bake_to_action(ao, tl, frames, name)
    ae.keys_to_sparse_action(ao, tl, name + "__CONTROL")
    print("floor clamp:", tl.clamped_frames or "none")

    scene.frame_start, scene.frame_end = tl.frame_start, tl.frame_end
    for m in list(scene.timeline_markers):
        scene.timeline_markers.remove(m)
    for f, n, _ in tl.markers:
        scene.timeline_markers.new(n, frame=f)

    fps = rc.SCENE_FPS
    out_dir = rc.repo_path("ANIMATIONS", name)
    ref_dir = rc.repo_path("REFERENCE", name)
    os.makedirs(out_dir, exist_ok=True)

    anchors = world_points(frames)
    timing = {
        "id": meta["id"],
        "name": name,
        "fps": fps,
        "frame_start": tl.frame_start,
        "frame_end": tl.frame_end,
        "duration_s": round((tl.frame_end - tl.frame_start) / fps, 4),
        "phases": [{"name": n, "start": s, "end": e} for n, s, e in tl.phases],
        "markers": [
            {"name": n, "frame": f, "time_s": round((f - tl.frame_start) / fps, 4), "value": v}
            for f, n, v in sorted(tl.markers)
        ],
        "root_motion": [
            {
                "t": round((fr["frame"] - tl.frame_start) / fps, 4),
                "pos": [round(c, 4) for c in fr["root"].to_translation()],
                "yaw": round(tl.value("ROOT.yaw", fr["frame"]), 3),
            }
            for fr in frames
        ],
        "arm_warnings": list(ae.ARM_WARNINGS),
        "blade_floor_penetration": floor_check(tl, frames, anchors, tl.blade_ground_ok),
    }
    rc.write_json(os.path.join(out_dir, f"{name}_timing.json"), timing)
    print("blade below floor:", timing["blade_floor_penetration"] or "none")

    cues = vfx_cues.resolve(getattr(mod, "CUES", []), timing)
    hits = vfx_cues.resolve(getattr(mod, "HITS", []), timing)
    rc.write_json(
        os.path.join(out_dir, f"{name}_vfx_cues.json"),
        {"name": name, "palette": vfx_cues.PALETTE, "cues": cues, "hits": hits},
    )

    previs.setup_stage(scene, res=meta.get("res", (640, 360)), samples=10)
    previs.hide_rig_helpers()
    for blade, hidden in (("AzureBlade", not getattr(tl, "dual", False)), ("EmberBlade", tl.blade_hidden)):
        if blade in bpy.data.objects:
            bpy.data.objects[blade].hide_render = hidden
    blade_windows(tl)
    setup_camera(scene, meta.get("camera", {}), frames)
    # o .blend da animação fica limpo (rig + action); o previs com VFX vai pro _cache
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, f"{name}.blend"), compress=True)
    if cues and "--novfx" not in flags:
        import vfx_previs

        skipped = vfx_previs.build(scene, ao, dict(timing, anchors=anchors), cues, vfx_cues.PALETTE)
        print("previs:", len(cues), "cues, sem preview no Blender:", skipped)
        os.makedirs(os.path.join(CACHE, "previs"), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CACHE, "previs", f"{name}_previs.blend"), compress=True)

    if "--export" in flags:
        export(ao, tl, frames, timing, out_dir, name)

    if "--lowres" in flags:
        scene.render.resolution_x, scene.render.resolution_y = 480, 270
        scene.cycles.samples = 6
    if "--sheet" in flags or "--frames" in opts:
        kfr = meta.get("sheet_frames") or sorted({f for f, _, _ in tl.markers})
        if "--frames" in opts:
            if "," in opts["--frames"]:
                kfr = [int(x) for x in opts["--frames"].split(",")]
            else:
                lo, hi, *st = [int(x) for x in opts["--frames"].split("-")]
                kfr = list(range(lo, hi + 1, st[0] if st else 1))
        tmp = os.path.join(CACHE, "sheets", name)
        paths = previs.render_frames(scene, kfr, tmp, prefix="k")
        sheet = os.path.join(ref_dir, f"{name}_keys.png") if "--frames" not in opts else os.path.join(tmp, "check.png")
        os.makedirs(os.path.dirname(sheet), exist_ok=True)
        previs.contact_sheet(paths, sheet, cols=min(6, len(paths)))
    if "--clip" in opts:
        lo, hi, st = [int(x) for x in opts["--clip"].split("-")]
        frames_to_video(
            scene,
            list(range(lo, hi + 1, st)),
            os.path.join(CACHE, "clip", name),
            os.path.join(ref_dir, f"{name}_clip_{lo}_{hi}.mp4"),
            fps // st,
        )
    if "--video" in flags:
        st = meta.get("video_step", 1)
        frames_to_video(
            scene,
            list(range(tl.frame_start, tl.frame_end + 1, st)),
            os.path.join(CACHE, "video", name),
            os.path.join(ref_dir, f"{name}_previs.mp4"),
            fps // st,
        )
    print("DONE", name)


if __name__ == "__main__":
    main()
