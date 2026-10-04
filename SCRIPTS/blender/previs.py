"""Palco, câmera, render e vídeo do previs (Cycles CPU)."""

import math
import os
import subprocess

import bpy
from mathutils import Vector

FLOOR_Z = -3.0


def _mat(name, rgba, rough=0.8, emission=None, strength=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Roughness"].default_value = rough
    if emission:
        b.inputs["Emission Color"].default_value = emission
        b.inputs["Emission Strength"].default_value = strength
    return m


def setup_stage(scene, res=(640, 360), samples=12):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.max_bounces = 4
    try:
        scene.cycles.use_denoising = True
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0

    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.03, 0.03, 0.042, 1.0)
    bg.inputs["Strength"].default_value = 1.0

    if "PREVIS_Floor" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, FLOOR_Z))
        floor = bpy.context.object
        floor.name = "PREVIS_Floor"
        floor.data.materials.append(_mat("M_floor", (0.07, 0.068, 0.078, 1.0), rough=0.55))
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=81, y_subdivisions=81, size=80, location=(0, 0, FLOOR_Z + 0.002))
        grid = bpy.context.object
        grid.name = "PREVIS_Grid"
        mod = grid.modifiers.new("wire", "WIREFRAME")
        mod.thickness = 0.02
        grid.data.materials.append(_mat("M_grid", (0.12, 0.12, 0.14, 1.0), rough=0.9))

    def light(name, kind, loc, rot, energy, color, size=4.0):
        if name in bpy.data.objects:
            return bpy.data.objects[name]
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = color
        if kind == "AREA":
            ld.size = size
        ob = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(ob)
        ob.location = loc
        ob.rotation_euler = rot
        return ob

    light(
        "PREVIS_Key",
        "AREA",
        (6, 8, 6),
        (math.radians(-50), math.radians(30), math.radians(150)),
        4200,
        (1.0, 0.9, 0.82),
        5,
    )
    light(
        "PREVIS_Rim",
        "AREA",
        (-5, -7, 5),
        (math.radians(55), math.radians(-20), math.radians(-30)),
        3800,
        (0.55, 0.62, 1.0),
        4,
    )
    light("PREVIS_Fill", "AREA", (-8, 6, 1), (math.radians(-80), 0, math.radians(-130)), 900, (0.9, 0.85, 1.0), 6)

    scene.use_nodes = True
    tree = scene.node_tree
    if "Glare" not in tree.nodes:
        rl = tree.nodes.get("Render Layers") or tree.nodes.new("CompositorNodeRLayers")
        comp = tree.nodes.get("Composite") or tree.nodes.new("CompositorNodeComposite")
        glare = tree.nodes.new("CompositorNodeGlare")
        glare.name = "Glare"
        glare.glare_type = "FOG_GLOW"
        glare.quality = "MEDIUM"
        try:
            glare.threshold = 0.9
            glare.size = 8
        except Exception:
            pass
        tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], comp.inputs["Image"])


def setup_camera(scene, loc, target, lens=32, name="PREVIS_Cam"):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    return cam


def render_frames(scene, frames, out_dir, prefix="f"):
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for f in frames:
        scene.frame_set(f)
        path = os.path.join(out_dir, f"{prefix}_{f:04d}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def contact_sheet(paths, out_path, cols=5, label=True):
    if not paths:
        return None
    rows = math.ceil(len(paths) / cols)
    lst = out_path + ".txt"
    with open(lst, "w") as f:
        for p in paths:
            f.write(f"file '{p}'\nduration 1\n")
    vf = f"tile={cols}x{rows}:padding=4:color=black"
    cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        lst,
        "-vf",
        vf,
        "-frames:v",
        "1",
        out_path,
    ]
    subprocess.run(cmd, check=False)
    os.remove(lst)
    return out_path


def encode_video(frame_glob_dir, prefix, fps, out_path, start_number):
    cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-y",
        "-framerate",
        str(fps),
        "-start_number",
        str(start_number),
        "-i",
        os.path.join(frame_glob_dir, f"{prefix}_%04d.png"),
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-crf",
        "23",
        "-movflags",
        "+faststart",
        out_path,
    ]
    subprocess.run(cmd, check=False)
    return out_path


def hide_rig_helpers():
    for ob in bpy.data.objects:
        if ob.type == "ARMATURE":
            ob.hide_render = True
        if ob.name in ("HumanoidRootPart",):
            ob.hide_render = True
