"""
Monta o rig R15 com o create_rig do add-on e salva RIG/EMBER_R15_RIG.blend.

  RBX_ADDON_SRC=<zip do add-on> blender -b --factory-startup --python SCRIPTS/blender/build_rig.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bmesh
import bpy
from mathutils import Vector

import rbx_common as rc

PALETTE = {
    "skin": (0.95, 0.78, 0.62, 1.0),
    "coat": (0.20, 0.16, 0.18, 1.0),
    "coat_trim": (0.55, 0.18, 0.06, 1.0),
    "pants": (0.26, 0.22, 0.26, 1.0),
    "boots": (0.09, 0.07, 0.07, 1.0),
    "scarf": (0.85, 0.22, 0.06, 1.0),
    "blade_core": (1.0, 0.55, 0.12, 1.0),
    "blade_steel": (0.18, 0.17, 0.2, 1.0),
    "hidden": (1.0, 1.0, 1.0, 1.0),
}
PART_MATERIAL = {
    "Head": "skin",
    "UpperTorso": "coat",
    "LowerTorso": "coat_trim",
    "LeftUpperArm": "coat",
    "RightUpperArm": "coat",
    "LeftLowerArm": "coat",
    "RightLowerArm": "coat",
    "LeftHand": "skin",
    "RightHand": "skin",
    "LeftUpperLeg": "pants",
    "RightUpperLeg": "pants",
    "LeftLowerLeg": "pants",
    "RightLowerLeg": "pants",
    "LeftFoot": "boots",
    "RightFoot": "boots",
    "HumanoidRootPart": "hidden",
    "Scarf1": "scarf",
    "Scarf2": "scarf",
    "Scarf3": "scarf",
    "Scarf4": "scarf",
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, rgba, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.65
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = rgba
    return mat


def rbx_to_blender(v):
    return Vector((v[0], -v[2], v[1]))


def box_mesh(name, size, bevel=0.06):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
    if bevel > 0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.edges),
            offset=min(bevel, min(size) * 0.3),
            segments=2,
            affect="EDGES",
            profile=0.7,
        )
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    return me


def blade_mesh(name):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()

    def rv(x, y, z):
        return bm.verts.new(rbx_to_blender((x, y, z)))

    def prism(z0, z1, r_y, r_x, sides=8, taper=1.0):
        ring0, ring1 = [], []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ring0.append(rv(math.cos(a) * r_x, math.sin(a) * r_y, z0))
            ring1.append(rv(math.cos(a) * r_x * taper, math.sin(a) * r_y * taper, z1))
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        bm.faces.new(list(reversed(ring0)))
        bm.faces.new(ring1)

    prism(1.35, 2.6, 0.09, 0.07)
    prism(2.6, 2.72, 0.12, 0.1, taper=0.7)
    prism(1.22, 1.35, 0.26, 0.11)
    segs = 10
    top, bot = [], []
    for i in range(segs + 1):
        t = i / segs
        z = 1.22 - t * 3.82
        curve = 0.12 * t * t
        h = 0.16 * (1.0 - 0.55 * t) if i < segs else 0.0
        y_top = 0.08 + curve
        y_bot = y_top - h - 0.06 * (1 - t)
        w = 0.045 * (1 - 0.6 * t)
        top.append((rv(-w, y_top, z), rv(w, y_top, z)))
        bot.append(rv(0.0, y_bot, z))
    for i in range(segs):
        a0l, a0r = top[i]
        a1l, a1r = top[i + 1]
        b0, b1 = bot[i], bot[i + 1]
        bm.faces.new((a0l, a1l, a1r, a0r))
        bm.faces.new((a0l, b0, b1, a1l))
        bm.faces.new((a0r, a1r, b1, b0))
    bm.faces.new((top[0][0], top[0][1], bot[0]))
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    return me


def build_parts(parts_coll, mats):
    objs = {}
    for name, parent, center, size, pivot, joint in rc.R15_PARTS:
        if name in ("EmberBlade", "AzureBlade"):
            me = blade_mesh(name)
        elif name.startswith("Scarf"):
            me = box_mesh(name, size, bevel=0.02)
        elif name == "Head":
            me = box_mesh(name, size, bevel=0.28)
        else:
            me = box_mesh(name, size, bevel=0.06)
        obj = bpy.data.objects.new(name, me)
        parts_coll.objects.link(obj)
        obj.location = rbx_to_blender(center)
        if name in ("EmberBlade", "AzureBlade"):
            for poly in me.polygons:
                poly.material_index = 0
            me.materials.append(mats["blade_steel"])
            me.materials.append(mats["blade_core"] if name == "EmberBlade" else mats["azure_core"])
            for poly in me.polygons:
                c = poly.center
                rz = -c.y
                if rz < 1.2:
                    poly.material_index = 1
        else:
            me.materials.append(mats[PART_MATERIAL[name]])
        if name == "HumanoidRootPart":
            obj.hide_render = True
            obj.display_type = "WIRE"
        objs[name] = obj
    return objs


def add_face(head_obj, mats):
    for side in (-1, 1):
        me = box_mesh(f"Eye_{'L' if side < 0 else 'R'}", (0.18, 0.07, 0.02), bevel=0.0)
        eye = bpy.data.objects.new(me.name, me)
        head_obj.users_collection[0].objects.link(eye)
        eye.parent = head_obj
        eye.location = rbx_to_blender((0.22 * side, 0.08, -0.64))
        me.materials.append(mats["eye"])


def main():
    reset_scene()
    rc.ensure_addon()
    scene = rc.scene_setup()

    mats = {k: make_material(f"M_{k}", v) for k, v in PALETTE.items()}
    mats["blade_core"] = make_material("M_blade_core", PALETTE["blade_core"], emission=6.0)
    mats["eye"] = make_material("M_eye", (1.0, 0.6, 0.15, 1.0), emission=12.0)
    mats["azure_core"] = make_material("M_azure_core", (0.35, 0.7, 1.0, 1.0), emission=6.0)

    master = bpy.data.collections.new("RIG: EmberR15")
    scene.collection.children.link(master)
    parts = bpy.data.collections.new("Parts")
    master.children.link(parts)
    rig_coll = bpy.data.collections.new("EmberR15 Rig")
    master.children.link(rig_coll)

    meta = rc.build_rig_meta("EmberR15")
    rc.write_json(rc.repo_path("CHARACTER", "rig_meta_ember_r15.json"), meta)

    meta_obj = bpy.data.objects.new("__RigMeta_EmberR15", None)
    master.objects.link(meta_obj)
    import json

    meta_obj["RigMeta"] = json.dumps(meta)

    objs = build_parts(parts, mats)
    add_face(objs["Head"], mats)

    from roblox_animations.rig.creation import create_rig

    create_rig("LOCAL_YAXIS_EXTEND", meta_obj.name)
    ao = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    ao.name = "EMBER_R15"
    ao.data.name = "EMBER_R15_Armature"
    scene.rbx_anim_settings.rbx_anim_armature = ao.name

    for pb in ao.pose.bones:
        pb.rotation_mode = "QUATERNION"

    report = {"armature": ao.name, "addon_version": rc.addon_version(), "bones": []}
    problems = []
    for b in ao.data.bones:
        has = all(k in b for k in ("transform", "transform1", "nicetransform"))
        if not has:
            problems.append(f"bone {b.name} lacks Motor6D custom props")
        pivot_rbx = None
        if rc.PART_BY_NAME.get(b.name) and rc.PART_BY_NAME[b.name][4]:
            pivot_rbx = rc.PART_BY_NAME[b.name][4]
            expect = rbx_to_blender(pivot_rbx)
            if (b.head_local - expect).length > 1e-4:
                problems.append(f"bone {b.name} head {tuple(b.head_local)} != pivot {tuple(expect)}")
        report["bones"].append(
            {
                "name": b.name,
                "parent": b.parent.name if b.parent else None,
                "head_blender": [round(x, 5) for x in b.head_local],
                "pivot_roblox": pivot_rbx,
                "joint_type": b.get("rbx_joint_type"),
                "motor6d_props": has,
            }
        )
    constrained = {o.name: [c.subtarget for c in o.constraints if c.type == "CHILD_OF"] for o in objs.values()}
    for name, subs in constrained.items():
        if name != "HumanoidRootPart" and subs != [name]:
            problems.append(f"part {name} constrained to {subs}")
    report["part_constraints"] = constrained
    report["problems"] = problems
    rc.write_json(rc.repo_path("RIG", "rig_report.json"), report)

    bpy.ops.wm.save_as_mainfile(filepath=rc.repo_path("RIG", "EMBER_R15_RIG.blend"), compress=True)
    print("RIG BUILD:", "OK" if not problems else "PROBLEMS")
    for p in problems:
        print("  -", p)


if __name__ == "__main__":
    main()
