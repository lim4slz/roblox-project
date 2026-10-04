"""
Coisas compartilhadas: definição do rig R15 (studs e eixos do Roblox), instalação
do add-on RBXMonkey (RBX_ADDON_SRC aponta pro zip/pasta do add-on) e conversões de CFrame.
"""

import json
import math
import os
import shutil
import sys
import tempfile
import zipfile

import bpy
from mathutils import Matrix

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ADDON_PACKAGE = "roblox_animations"
SCENE_FPS = 60

R15_PARTS = [
    ("HumanoidRootPart", None, (0.0, 0.0, 0.0), (2.0, 2.0, 1.0), None, None),
    ("LowerTorso", "HumanoidRootPart", (0.0, -0.800028, 0.0), (2.0, 0.4, 1.0), (0.0, -1.0, 0.0), "Root"),
    ("UpperTorso", "LowerTorso", (0.0, 0.199983, 0.0), (2.0, 1.6, 1.0), (0.0, -0.6, 0.0), "Waist"),
    ("Head", "UpperTorso", (0.0, 1.5, 0.0), (1.25, 1.25, 1.25), (0.0, 1.0, 0.0), "Neck"),
    ("LeftUpperArm", "UpperTorso", (-1.5, 0.368673, 0.0), (1.0, 1.17, 1.0), (-1.0, 0.763, 0.0), "LeftShoulder"),
    ("LeftLowerArm", "LeftUpperArm", (-1.5, -0.224072, 0.0), (1.0, 1.05, 1.0), (-1.5, 0.0347, 0.0), "LeftElbow"),
    ("LeftHand", "LeftLowerArm", (-1.5, -0.850046, 0.0), (1.0, 0.3, 1.0), (-1.5, -0.7251, 0.0), "LeftWrist"),
    ("RightUpperArm", "UpperTorso", (1.5, 0.368673, 0.0), (1.0, 1.17, 1.0), (1.0, 0.763, 0.0), "RightShoulder"),
    ("RightLowerArm", "RightUpperArm", (1.5, -0.224072, 0.0), (1.0, 1.05, 1.0), (1.5, 0.0347, 0.0), "RightElbow"),
    ("RightHand", "RightLowerArm", (1.5, -0.850046, 0.0), (1.0, 0.3, 1.0), (1.5, -0.7251, 0.0), "RightWrist"),
    ("LeftUpperLeg", "LowerTorso", (-0.5, -1.420782, 0.0), (1.0, 1.0, 1.0), (-0.5, -1.0, 0.0), "LeftHip"),
    ("LeftLowerLeg", "LeftUpperLeg", (-0.5, -2.200903, 0.0), (1.0, 0.9, 1.0), (-0.5, -1.8209, 0.0), "LeftKnee"),
    ("LeftFoot", "LeftLowerLeg", (-0.5, -2.85, 0.0), (1.0, 0.3, 1.0), (-0.5, -2.75, 0.0), "LeftAnkle"),
    ("RightUpperLeg", "LowerTorso", (0.5, -1.420782, 0.0), (1.0, 1.0, 1.0), (0.5, -1.0, 0.0), "RightHip"),
    ("RightLowerLeg", "RightUpperLeg", (0.5, -2.200903, 0.0), (1.0, 0.9, 1.0), (0.5, -1.8209, 0.0), "RightKnee"),
    ("RightFoot", "RightLowerLeg", (0.5, -2.85, 0.0), (1.0, 0.3, 1.0), (0.5, -2.75, 0.0), "RightAnkle"),
    ("EmberBlade", "RightHand", (1.5, -0.88, -2.1), (0.14, 0.32, 5.2), (1.5, -0.88, 0.0), "EmberBladeGrip"),
    ("AzureBlade", "LeftHand", (-1.5, -0.88, -2.1), (0.14, 0.32, 5.2), (-1.5, -0.88, 0.0), "AzureBladeGrip"),
    ("Scarf1", "UpperTorso", (0.0, 0.45, 0.58), (0.72, 0.86, 0.08), (0.0, 0.85, 0.58), "ScarfJoint1"),
    ("Scarf2", "Scarf1", (0.0, -0.35, 0.58), (0.68, 0.86, 0.08), (0.0, 0.05, 0.58), "ScarfJoint2"),
    ("Scarf3", "Scarf2", (0.0, -1.15, 0.58), (0.62, 0.86, 0.08), (0.0, -0.75, 0.58), "ScarfJoint3"),
    ("Scarf4", "Scarf3", (0.0, -1.95, 0.58), (0.54, 0.86, 0.08), (0.0, -1.55, 0.58), "ScarfJoint4"),
]
PART_BY_NAME = {p[0]: p for p in R15_PARTS}
AUGMENT_PARTS = ("EmberBlade", "AzureBlade", "Scarf1", "Scarf2", "Scarf3", "Scarf4")
BODY_PARTS = tuple(p[0] for p in R15_PARTS if p[0] not in AUGMENT_PARTS)
ANIMATED_PARTS = tuple(p[0] for p in R15_PARTS if p[1] is not None)
HIP_HEIGHT = 2.0
FLOOR_Y = -3.0


def cf_translation(x, y, z):
    return [float(x), float(y), float(z), 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]


def joint_c0_c1(name):
    _, parent, center, _, pivot, _ = PART_BY_NAME[name]
    pcenter = PART_BY_NAME[parent][2]
    c0 = cf_translation(*(pivot[i] - pcenter[i] for i in range(3)))
    c1 = cf_translation(*(pivot[i] - center[i] for i in range(3)))
    return c0, c1


def build_rig_meta(rig_name="EmberR15"):
    children = {}
    for part in R15_PARTS:
        children.setdefault(part[1], []).append(part[0])

    def node(name):
        _, parent, center, _, _, joint = PART_BY_NAME[name]
        n = {
            "jname": name,
            "pname": name,
            "transform": cf_translation(*center),
            "children": [node(c) for c in children.get(name, [])],
            "aux": [],
            "auxTransform": [],
            "isDeformBone": False,
            "jointType": "Motor6D" if parent else None,
            "hasSkinnedMesh": False,
        }
        if parent:
            c0, c1 = joint_c0_c1(name)
            n["jointtransform0"] = c0
            n["jointtransform1"] = c1
            n["jointName"] = joint
        return n

    return {
        "rigName": rig_name,
        "rig": node("HumanoidRootPart"),
        "meshToBone": {p[0]: p[0] for p in R15_PARTS if p[1] is not None},
        "parts": [p[0] for p in R15_PARTS],
    }


def _addon_source():
    src = os.environ.get("RBX_ADDON_SRC", "")
    if not src:
        raise RuntimeError(
            "Set RBX_ADDON_SRC to the add-on folder or release zip "
            "(add-on-roblox-animations-importer-exporter-v3.0.1.zip)."
        )
    return os.path.abspath(src)


def ensure_addon():
    if ADDON_PACKAGE in sys.modules and hasattr(bpy.types.Scene, "rbx_anim_settings"):
        return sys.modules[ADDON_PACKAGE]
    src = _addon_source()
    root = os.path.join(tempfile.gettempdir(), "rbx_addon_runtime")
    target = os.path.join(root, ADDON_PACKAGE)
    if os.path.isdir(target):
        shutil.rmtree(target)
    os.makedirs(root, exist_ok=True)
    if zipfile.is_zipfile(src):
        with zipfile.ZipFile(src) as zf:
            names = zf.namelist()
            prefix = ""
            manifest = [n for n in names if n.endswith("blender_manifest.toml")]
            if manifest:
                prefix = manifest[0][: -len("blender_manifest.toml")]
            os.makedirs(target)
            for n in names:
                if not n.startswith(prefix) or n.endswith("/"):
                    continue
                rel = n[len(prefix) :]
                dst = os.path.join(target, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                with zf.open(n) as fsrc, open(dst, "wb") as fdst:
                    fdst.write(fsrc.read())
    else:
        shutil.copytree(src, target)
    if root not in sys.path:
        sys.path.insert(0, root)
    import importlib

    mod = importlib.import_module(ADDON_PACKAGE)
    mod.register()
    if not hasattr(bpy.types.Scene, "rbx_anim_settings"):
        raise RuntimeError("Add-on registered but rbx_anim_settings missing")
    return mod


def addon_version():
    src = _addon_source()
    if zipfile.is_zipfile(src):
        with zipfile.ZipFile(src) as zf:
            for n in zf.namelist():
                if n.endswith("blender_manifest.toml"):
                    text = zf.read(n).decode("utf-8")
                    break
    else:
        with open(os.path.join(src, "blender_manifest.toml"), encoding="utf-8") as f:
            text = f.read()
    for line in text.splitlines():
        if line.strip().startswith("version"):
            return line.split("=", 1)[1].strip().strip('"')
    return "unknown"


def cf_to_mat(cf):
    mat = Matrix.Translation((cf[0], cf[1], cf[2]))
    mat[0][0:3] = (cf[3], cf[4], cf[5])
    mat[1][0:3] = (cf[6], cf[7], cf[8])
    mat[2][0:3] = (cf[9], cf[10], cf[11])
    return mat


def mat_to_cf(mat):
    return [
        mat[0][3],
        mat[1][3],
        mat[2][3],
        mat[0][0],
        mat[0][1],
        mat[0][2],
        mat[1][0],
        mat[1][1],
        mat[1][2],
        mat[2][0],
        mat[2][1],
        mat[2][2],
    ]


def roblox_T(rx=0.0, ry=0.0, rz=0.0, tx=0.0, ty=0.0, tz=0.0):
    r = (
        Matrix.Rotation(math.radians(rx), 4, "X")
        @ Matrix.Rotation(math.radians(ry), 4, "Y")
        @ Matrix.Rotation(math.radians(rz), 4, "Z")
    )
    return Matrix.Translation((tx, ty, tz)) @ r


def basis_from_roblox_T(pose_bone, T):
    from roblox_animations.core.utils import to_matrix

    n = to_matrix(pose_bone.bone.get("nicetransform"))
    return n.inverted() @ T @ n


def scene_setup(fps=SCENE_FPS):
    scene = bpy.context.scene
    scene.render.fps = int(fps)
    scene.render.fps_base = 1.0
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    return scene


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def repo_path(*parts):
    return os.path.join(REPO_ROOT, *parts)


def parse_script_args():
    argv = sys.argv
    if "--" in argv:
        return argv[argv.index("--") + 1 :]
    return []
