"""
Blender VFX PREVIS — builds keyframed emissive geometry / particle systems
from the resolved cue list (same data the Roblox runtime executes).

Purpose: timing, composition and readability checks in the preview renders.
This is NOT exported to Roblox; the Roblox implementation lives in
ROBLOX/src/shared/VFX (native ParticleEmitter / Beam / Trail / parts).

Conventions: anchors come from <NAME>_timing.json (Roblox world studs per
frame); Blender world = (x, -z, y). Every VFX object uses one of three
materials driven by Object Info Color/Alpha so fades are just keyframes on
obj.color:
  ADD    additive emission (energy, fire, light)
  SMOKE  alpha-blended grey (dust, smoke, ash)
  DARK   opaque-ish black (eclipse disc, scorch)
"""

import math
import random

import bpy
from mathutils import Euler, Matrix, Vector

FPS = 60
_RNG = random.Random(7)
COLL = "VFX_PREVIS"


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def rb(v):
    return Vector((v[0], -v[2], v[1]))


def col(c, palette):
    if isinstance(c, str):
        c = palette[c]
    return (c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


def _coll():
    c = bpy.data.collections.get(COLL)
    if c is None:
        c = bpy.data.collections.new(COLL)
        bpy.context.scene.collection.children.link(c)
    return c


def clear():
    c = bpy.data.collections.get(COLL)
    if c:
        for ob in list(c.all_objects):
            bpy.data.objects.remove(ob, do_unlink=True)


def _mat_add():
    m = bpy.data.materials.get("VFX_ADD")
    if m:
        return m
    m = bpy.data.materials.new("VFX_ADD")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    em = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 6.0
    # rim factor: energy shells read as volumes (brighter at grazing angles)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    rim = nt.nodes.new("ShaderNodeMapRange")
    rim.inputs["To Min"].default_value = 0.35
    rim.inputs["To Max"].default_value = 1.6
    mul2 = nt.nodes.new("ShaderNodeMath")
    mul2.operation = "MULTIPLY"
    nt.links.new(lw.outputs["Facing"], rim.inputs["Value"])
    nt.links.new(info.outputs["Color"], em.inputs["Color"])
    nt.links.new(info.outputs["Alpha"], mul.inputs[0])
    nt.links.new(mul.outputs[0], mul2.inputs[0])
    nt.links.new(rim.outputs["Result"], mul2.inputs[1])
    # boiling energy: 4D noise (W keyframed over the whole timeline)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.name = "VFX_NOISE"
    noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = 0.35
    noise.inputs["Detail"].default_value = 3.0
    nr = nt.nodes.new("ShaderNodeMapRange")
    nr.inputs["From Min"].default_value = 0.3
    nr.inputs["From Max"].default_value = 0.7
    nr.inputs["To Min"].default_value = 0.55
    nr.inputs["To Max"].default_value = 1.35
    mul3 = nt.nodes.new("ShaderNodeMath")
    mul3.operation = "MULTIPLY"
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], nr.inputs["Value"])
    nt.links.new(mul2.outputs[0], mul3.inputs[0])
    nt.links.new(nr.outputs["Result"], mul3.inputs[1])
    nt.links.new(mul3.outputs[0], em.inputs["Strength"])
    w = noise.inputs["W"]
    w.default_value = 0.0
    w.keyframe_insert("default_value", frame=0)
    w.default_value = 160.0
    w.keyframe_insert("default_value", frame=2400)
    for fc in m.node_tree.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    try:
        m.emission_sampling = "NONE"
    except Exception:
        pass
    m.blend_method = "BLEND"
    return m


def _mat_smoke():
    m = bpy.data.materials.get("VFX_SMOKE")
    if m:
        return m
    m = bpy.data.materials.new("VFX_SMOKE")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(info.outputs["Color"], dif.inputs["Color"])
    nt.links.new(info.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(dif.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def _mat_particle(name, rgb, strength=10.0):
    """Additive material for particle instances, faded by particle age."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    pinfo = nt.nodes.new("ShaderNodeParticleInfo")
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = strength
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*rgb, 1.0)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(pinfo.outputs["Age"], div.inputs[0])
    nt.links.new(pinfo.outputs["Lifetime"], div.inputs[1])
    nt.links.new(div.outputs[0], inv.inputs[1])
    nt.links.new(inv.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], em.inputs["Strength"])
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    try:
        m.emission_sampling = "NONE"
    except Exception:
        pass
    return m


def _new_obj(name, mesh, mat, rgb, alpha=0.0):
    ob = bpy.data.objects.new(name, mesh)
    _coll().objects.link(ob)
    if mat is not None:
        mesh.materials.append(mat)
    ob.color = (*rgb, alpha)
    ob.visible_shadow = False
    return ob


def _key(ob, path, frame, value=None, interp="BEZIER", easing="AUTO"):
    if value is not None:
        setattr(ob, path, value)
    ob.keyframe_insert(path, frame=frame)
    ad = ob.animation_data
    if ad and ad.action:
        for fc in ad.action.fcurves:
            if fc.data_path == path:
                for kp in fc.keyframe_points:
                    if abs(kp.co.x - frame) < 0.5:
                        kp.interpolation = interp
                        kp.easing = easing


def _fade(ob, rgb, f_in, f_peak, f_out_start, f_out_end, peak=1.0, interp_out="LINEAR"):
    _key(ob, "color", max(0, f_in - 1), (*rgb, 0.0), "CONSTANT")
    _key(ob, "color", f_in, (*rgb, 0.0), "LINEAR")
    _key(ob, "color", f_peak, (*rgb, peak), "LINEAR")
    _key(ob, "color", f_out_start, (*rgb, peak), interp_out)
    _key(ob, "color", f_out_end, (*rgb, 0.0), "CONSTANT")


def _vis_window(ob, f0, f1):
    ob.hide_render = True
    ob.keyframe_insert("hide_render", frame=0)
    ob.hide_render = False
    ob.keyframe_insert("hide_render", frame=max(1, f0 - 1))
    ob.hide_render = True
    ob.keyframe_insert("hide_render", frame=f1 + 1)
    for fc in ob.animation_data.action.fcurves:
        if fc.data_path == "hide_render":
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"


def _torus(name, R, r, segs=96, ring=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=segs, minor_segments=ring)
    ob = bpy.context.object
    me = ob.data
    bpy.data.objects.remove(ob, do_unlink=True)
    me.name = name
    return me


def _sphere(name, r=1.0, segs=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segs, ring_count=rings)
    ob = bpy.context.object
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    bpy.data.objects.remove(ob, do_unlink=True)
    me.name = name
    return me


def _cyl(name, r=1.0, h=1.0, verts=48):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts)
    ob = bpy.context.object
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    bpy.data.objects.remove(ob, do_unlink=True)
    me.name = name
    return me


def _box(name, sx, sy, sz):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.object
    me = ob.data
    bpy.data.objects.remove(ob, do_unlink=True)
    for v in me.vertices:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    me.name = name
    return me


def _helix_curve(name, radius, height, turns, phase, z0):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    n = int(48 * turns)
    sp.points.add(n - 1)
    for i in range(n):
        t = i / (n - 1)
        a = phase + t * turns * 2 * math.pi
        sp.points[i].co = (math.cos(a) * radius, math.sin(a) * radius, z0 + t * height, 1.0)
    cu.bevel_depth = 0.035
    cu.bevel_resolution = 2
    return cu


class Anchors:
    def __init__(self, timing):
        self.f0 = timing["frame_start"]
        self.rows = timing["anchors"]
        self.yaws = [r.get("yaw", 0.0) for r in timing.get("root_motion", [])]

    def at(self, name, frame):
        i = max(0, min(len(self.rows) - 1, frame - self.f0))
        row = self.rows[i]
        if name in row:
            return rb(row[name])
        if name == "feet":
            r = row["root"]
            return rb((r[0], -3.0 + 0.02, r[2]))
        if name == "chest":
            return rb(row["UpperTorso"])
        if name == "hands":
            a, b = Vector(row["LeftHand"]), Vector(row["grip"])
            return rb(tuple((a + b) / 2))
        if name.startswith("ahead:") or name.startswith("chest_ahead:"):
            dist = float(name.split(":")[1])
            r = row["root"]
            i2 = max(0, min(len(self.rows) - 1, frame - self.f0))
            # facing from the chest vs lower-torso offset is noisy; use root yaw
            yaw = self.yaw_at(frame)
            fwd = Vector((-math.sin(yaw), -math.cos(yaw)))  # roblox xz forward
            y = 0.3 if name.startswith("chest_ahead") else -3.0 + 0.02
            return rb((r[0] + fwd.x * dist, y if not name.startswith("chest") else row["UpperTorso"][1], r[2] + fwd.y * dist))
        if name.startswith("sky:"):
            r = row["root"]
            return rb((r[0], float(name[4:]), r[2]))
        if name == "impact":
            t = row["blade_tip"]
            return rb((t[0], -3.0 + 0.02, t[2]))
        return rb(row["root"])

    def yaw_at(self, frame):
        i = max(0, min(len(self.yaws) - 1, frame - self.f0)) if self.yaws else 0
        return math.radians(self.yaws[i]) if self.yaws else 0.0

    def facing(self, frame):
        i = max(0, min(len(self.rows) - 1, frame - self.f0))
        if i + 1 < len(self.rows):
            pass
        return Vector((0, 1, 0))


# --------------------------------------------------------------------------
# components (subset implemented per ability as they are authored)
# --------------------------------------------------------------------------
def fx_ring(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "VIOLET"), P)
    R0, R1 = p.get("r0", 1.0), p.get("r1", 10.0)
    dur = int(p.get("dur", 0.3) * FPS)
    me = _torus("ring", 1.0, p.get("w0", 0.6) * 0.18)
    ob = _new_obj(f"ring_{f}", me, _mat_add(), rgb)
    pos = A.at(c["anchor"] or "feet", f)
    if p.get("orient", "ground") != "ground":
        ob.rotation_euler = (math.radians(90), 0, 0)
        pos = pos + Vector((0, 0, 0.0))
    ob.location = pos + Vector((0, 0, p.get("y", 0.05)))
    _key(ob, "scale", f, (R0, R0, R0 if p.get("orient", "ground") != "ground" else 1.0), "EXPO", "EASE_OUT")
    s1 = (R1, R1, R1 if p.get("orient", "ground") != "ground" else max(1.0, R1 * 0.04))
    _key(ob, "scale", f + dur, s1)
    _fade(ob, rgb, f, f + 1, f + int(dur * 0.4), f + dur, peak=p.get("peak", 0.75))
    _vis_window(ob, f, f + dur)


def fx_flash(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "CORE"), P)
    dur = int(p.get("dur", 0.15) * FPS) + 1
    ob = _new_obj(f"flash_{f}", _sphere("flash", 1.0, 24, 12), _mat_add(), rgb)
    ob.location = A.at(c["anchor"] or "chest", f)
    s0, s1 = p.get("size0", 0.5) / 2, p.get("size1", 4.0) / 2
    _key(ob, "scale", f, (s0, s0, s0), "EXPO", "EASE_OUT")
    _key(ob, "scale", f + dur, (s1, s1, s1))
    _fade(ob, rgb, f, f + 1, f + 1, f + dur, peak=0.6)
    _vis_window(ob, f, f + dur)
    if p.get("light_range"):
        _light(f"flashlight_{f}", ob.location, rgb, p.get("light_brightness", 6) * 900, f, f + dur * 2)


def _light(name, loc, rgb, energy, f0, f1):
    ld = bpy.data.lights.new(name, "POINT")
    ld.color = rgb
    ld.shadow_soft_size = 2.0
    ob = bpy.data.objects.new(name, ld)
    _coll().objects.link(ob)
    ob.location = loc
    ld.energy = 0
    ld.keyframe_insert("energy", frame=max(0, f0 - 1))
    ld.energy = energy
    ld.keyframe_insert("energy", frame=f0)
    ld.energy = 0
    ld.keyframe_insert("energy", frame=f1)
    return ob


def fx_step_sigil(c, A, P):
    f = c["frame"]
    rgb = col("VIOLET", P)
    pos = A.at("feet", f)
    for k, (R, w) in enumerate(((1.6, 0.05), (1.15, 0.03))):
        ob = _new_obj(f"stepsig_{f}_{k}", _torus("ss", R, w), _mat_add(), rgb)
        ob.location = pos + Vector((0, 0, 0.03))
        ob.scale = (1, 1, 0.3)
        _key(ob, "scale", f, (0.2, 0.2, 0.3), "BACK", "EASE_OUT")
        _key(ob, "scale", f + 10, (1, 1, 0.3))
        _key(ob, "rotation_euler", f, (0, 0, 0), "LINEAR")
        _key(ob, "rotation_euler", f + 60, (0, 0, math.radians(60 * (1 if k else -1))))
        _fade(ob, rgb, f, f + 4, f + 20, f + 60, peak=0.8)
        _vis_window(ob, f, f + 60)


def _sigil_group(name, center, R, rgb, f_in, f_out, spin_deg, spokes=12, rings=3):
    root = bpy.data.objects.new(name, None)
    _coll().objects.link(root)
    root.location = center + Vector((0, 0, 0.04))
    parts = []
    radii = [R * (1.0 - 0.18 * i) for i in range(rings)]
    for i, r in enumerate(radii):
        ob = _new_obj(f"{name}_r{i}", _torus("sr", r, 0.06 + 0.03 * (i == 0)), _mat_add(), rgb)
        ob.parent = root
        ob.scale = (1, 1, 0.25)
        parts.append(ob)
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        ob = _new_obj(f"{name}_s{k}", _box("sp", R * 0.36, 0.06, 0.02), _mat_add(), rgb)
        ob.parent = root
        rr = R * 0.73
        ob.location = (math.cos(a) * rr, math.sin(a) * rr, 0)
        ob.rotation_euler = (0, 0, a)
        parts.append(ob)
        rune = _new_obj(f"{name}_u{k}", _box("ru", 0.35, 0.35, 0.02), _mat_add(), rgb)
        rune.parent = root
        rune.location = (math.cos(a + 0.26) * R * 0.91, math.sin(a + 0.26) * R * 0.91, 0)
        rune.rotation_euler = (0, 0, a + 0.785)
        parts.append(rune)
    _key(root, "scale", f_in, (0.05, 0.05, 0.05), "BACK", "EASE_OUT")
    _key(root, "scale", f_in + 24, (1, 1, 1))
    _key(root, "rotation_euler", f_in, (0, 0, 0), "LINEAR")
    _key(root, "rotation_euler", f_out, (0, 0, math.radians(spin_deg * (f_out - f_in) / FPS)))
    for ob in parts:
        _fade(ob, rgb, f_in, f_in + 12, max(f_in + 13, f_out - 8), f_out, peak=0.6)
        _vis_window(ob, f_in, f_out)
    return root


def fx_sigil(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "VIOLET"), P)
    dur = int(p.get("dur", 6.0) * FPS)
    root = _sigil_group(f"sigil_{f}", A.at(c["anchor"] or "feet", f), p.get("radius", 8.0), rgb, f, f + dur,
                        p.get("spin", 20) * (1 if (f // 7) % 2 else -1), p.get("spokes", 12), p.get("rings", 3))
    if p.get("implode_at"):
        fi = p["implode_at"]
        _key(root, "scale", fi - 1, (1, 1, 1), "EXPO", "EASE_IN")
        _key(root, "scale", fi + 10, (0.02, 0.02, 0.02))


def fx_circuits(c, A, P, ao):
    """Glowing magic lines crawling up the body (parented to LowerTorso)."""
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "VIOLET"), P)
    dur = int(p.get("dur", 10.0) * FPS)
    for k in range(p.get("count", 6)):
        cu = _helix_curve("circ", 1.15 + 0.1 * (k % 2), 5.2, 1.3 + 0.3 * (k % 3), k * 1.05, -2.6)
        ob = _new_obj(f"circ_{f}_{k}", cu, _mat_add(), rgb)
        con = ob.constraints.new("CHILD_OF")
        con.target = ao
        con.subtarget = "LowerTorso"
        con.inverse_matrix = Matrix.Identity(4)
        ob.location = (0, 0, 0)
        cu.bevel_factor_end = 0.0
        cu.keyframe_insert("bevel_factor_end", frame=f + k * 8)
        cu.bevel_factor_end = 1.0
        cu.keyframe_insert("bevel_factor_end", frame=f + k * 8 + 120)
        _fade(ob, rgb, f + k * 8, f + k * 8 + 10, f + dur - 12, f + dur, peak=0.5 + 0.1 * (k % 3))
        _vis_window(ob, f, f + dur)


def fx_converge(c, A, P):
    """Streaks rushing in from a big sphere toward the caster."""
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 8.0) * FPS)
    rgb = col(p.get("color", "VIOLET"), P)
    R = p.get("radius", 40.0)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=R)
    em = bpy.context.object
    em.name = f"converge_{f}"
    bpy.context.scene.collection.objects.unlink(em)
    _coll().objects.link(em)
    em.location = A.at("chest", f + dur // 2)
    em.show_instancer_for_render = False
    streak = _new_obj(f"streak_{f}", _box("st", 0.09, 0.09, 1.8), _mat_particle(f"PM_conv_{f}", rgb, 18), rgb, 1)
    streak.hide_render = True
    ps = em.modifiers.new("ps", "PARTICLE_SYSTEM").particle_system
    st = ps.settings
    st.count = int(p.get("count", 1400))
    st.frame_start = f
    st.frame_end = max(f + 1, f + dur - 60)
    st.lifetime = 60
    st.emit_from = "FACE"
    st.use_emit_random = True
    st.normal_factor = -(R - 1.5)  # BU/s -> reaches the core in ~1 s
    st.factor_random = 0.0
    st.effector_weights.gravity = 0.0
    st.drag_factor = 0.0
    st.render_type = "OBJECT"
    st.instance_object = streak
    st.particle_size = 1.0
    st.use_rotations = True
    st.rotation_mode = "VEL"


def fx_particles_burst(name, loc, f, count, rgb, speed, life, size=(0.08, 0.08, 0.9), gravity=0.0, spread=1.0,
                       shape="ico", radius=0.4, strength=14, smoke=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius)
    em = bpy.context.object
    em.name = name
    bpy.context.scene.collection.objects.unlink(em)
    _coll().objects.link(em)
    em.location = loc
    em.show_instancer_for_render = False
    mat = _mat_particle(f"PM_{name}", rgb, strength)
    inst = _new_obj(f"{name}_inst", _box("pi", *size) if not smoke else _sphere("puff", 1.0, 12, 8), mat, rgb, 1)
    inst.hide_render = True
    ps = em.modifiers.new("ps", "PARTICLE_SYSTEM").particle_system
    st = ps.settings
    st.count = count
    st.frame_start = f
    st.frame_end = f + 2
    st.lifetime = life
    st.lifetime_random = 0.4
    st.emit_from = "FACE"
    st.normal_factor = speed
    st.factor_random = speed * 0.35 * spread
    st.effector_weights.gravity = gravity
    st.render_type = "OBJECT"
    st.instance_object = inst
    st.particle_size = 1.0
    st.size_random = 0.5
    st.use_rotations = True
    st.rotation_mode = "VEL"
    st.drag_factor = 0.15
    return em


def fx_nuke(c, A, P):
    f = c["frame"]
    p = c["params"]
    center = A.at(c["anchor"] or "chest", f)
    R = p.get("radius", 60.0)
    grow = int(p.get("grow", 1.5) * FPS)
    hold = int(p.get("hold", 1.2) * FPS)
    fade = int(p.get("fade", 2.0) * FPS)
    layers = (("CORE", 0.22, 0.2), ("VIOLET", 0.7, 0.09), ("VOID", 1.0, 0.16))
    if p.get("palette") == "fire":
        layers = (("CORE", 0.22, 0.2), ("GOLD", 0.6, 0.1), ("EMBER", 0.85, 0.08), ("CRIMSON", 1.0, 0.12))
    for name, scale, peak in layers:
        rgb = col(name, P)
        ob = _new_obj(f"nuke_{name}_{f}", _sphere("nuke", 1.0, 64, 32), _mat_add(), rgb)
        ob.location = center
        _key(ob, "scale", f, (0.5, 0.5, 0.5), "EXPO", "EASE_OUT")
        r = R * scale
        _key(ob, "scale", f + grow, (r, r, r * 0.92))
        _key(ob, "scale", f + grow + hold + fade, (r * 1.08, r * 1.08, r))
        _fade(ob, rgb, f, f + 2, f + grow + hold, f + grow + hold + fade, peak=peak)
        _vis_window(ob, f, f + grow + hold + fade)
    _light(f"nukelight_{f}", center + Vector((0, 0, 6)), col("EMBER" if p.get("palette") == "fire" else "VIOLET", P),
           1.6e5, f, f + grow + hold + fade)


def fx_column(c, A, P):
    f = c["frame"]
    p = c["params"]
    center = A.at(c["anchor"] or "feet", f)
    rgb = col(p.get("color", "VIOLET"), P)
    H = p.get("height", 90.0)
    r = p.get("radius", 6.0)
    dur = int(p.get("dur", 4.0) * FPS)
    for k, (rr, nm, pk) in enumerate(((r, "VIOLET", 0.7), (r * 0.45, "CORE", 1.0))):
        ob = _new_obj(f"column_{f}_{k}", _cyl("col", 1.0, 1.0), _mat_add(), col(nm, P))
        ob.location = center
        _key(ob, "scale", f, (rr * 0.3, rr * 0.3, 0.1), "EXPO", "EASE_OUT")
        _key(ob, "location", f, center, "EXPO", "EASE_OUT")
        _key(ob, "scale", f + 40, (rr, rr, H))
        _key(ob, "location", f + 40, center + Vector((0, 0, H / 2)))
        _fade(ob, col(nm, P), f, f + 6, f + dur - 80, f + dur, peak=pk * 0.18)
        _vis_window(ob, f, f + dur)


def fx_mushroom(c, A, P):
    f = c["frame"]
    p = c["params"]
    center = A.at(c["anchor"] or "feet", f)
    H = p.get("height", 80.0)
    R = p.get("radius", 35.0)
    dur = int(p.get("dur", 5.0) * FPS)
    smoke = col("ASH", P)
    glow = col("VIOLET", P)
    cap = _new_obj(f"mush_cap_{f}", _torus("cap", 1.0, 0.45, 64, 24), _mat_smoke(), (0.32, 0.27, 0.35))
    cap.location = center + Vector((0, 0, H * 0.7))
    _key(cap, "scale", f, (2, 2, 2), "EXPO", "EASE_OUT")
    _key(cap, "location", f, center + Vector((0, 0, H * 0.6)), "SINE", "EASE_OUT")
    _key(cap, "scale", f + 120, (R * 0.8, R * 0.8, R * 0.45))
    _key(cap, "location", f + dur, center + Vector((0, 0, H)))
    _key(cap, "scale", f + dur, (R, R, R * 0.5))
    _fade(cap, (0.32, 0.27, 0.35), f, f + 20, f + dur - 90, f + dur, peak=0.85)
    _vis_window(cap, f, f + dur)
    inner = _new_obj(f"mush_glow_{f}", _torus("capg", 1.0, 0.3, 64, 16), _mat_add(), glow)
    inner.location = cap.location
    _key(inner, "scale", f, (2, 2, 2), "EXPO", "EASE_OUT")
    _key(inner, "location", f, center + Vector((0, 0, H * 0.6)), "SINE", "EASE_OUT")
    _key(inner, "scale", f + 120, (R * 0.7, R * 0.7, R * 0.35))
    _key(inner, "location", f + dur, center + Vector((0, 0, H)))
    _fade(inner, glow, f, f + 10, f + 60, f + 200, peak=0.25)
    _vis_window(inner, f, f + 200)


def fx_dust_wall(c, A, P):
    f = c["frame"]
    p = c["params"]
    center = A.at("feet", f)
    R = p.get("radius", 70.0)
    dur = int(p.get("dur", 3.0) * FPS)
    ob = _new_obj(f"dustwall_{f}", _torus("dw", 1.0, 0.18, 96, 16), _mat_smoke(), (0.36, 0.32, 0.34))
    ob.location = center + Vector((0, 0, 0.5))
    _key(ob, "scale", f, (2, 2, 6), "EXPO", "EASE_OUT")
    _key(ob, "scale", f + dur, (R, R, R * 0.12))
    _fade(ob, (0.36, 0.32, 0.34), f, f + 8, f + int(dur * 0.5), f + dur, peak=0.8)
    _vis_window(ob, f, f + dur)


def fx_debris(c, A, P):
    f = c["frame"]
    p = c["params"]
    loc = A.at(c["anchor"] or "feet", f) + Vector((0, 0, 0.5))
    em = fx_particles_burst(f"debris_{f}", loc, f, p.get("count", 40), (1.0, 0.45, 0.12), p.get("speed", 40.0),
                            int(p.get("dur", 2.0) * FPS), size=(0.7, 0.6, 0.5), gravity=1.0, strength=2.5)
    em.particle_systems[0].settings.normal_factor = p.get("speed", 40.0)


def fx_ash(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 5.0) * FPS)
    center = A.at("feet", f)
    bpy.ops.mesh.primitive_plane_add(size=p.get("radius", 60.0) * 2, location=center + Vector((0, 0, 40)))
    em = bpy.context.object
    em.name = f"ash_{f}"
    bpy.context.scene.collection.objects.unlink(em)
    _coll().objects.link(em)
    em.show_instancer_for_render = False
    inst = _new_obj(f"ash_inst_{f}", _box("ai", 0.12, 0.12, 0.12), _mat_particle(f"PM_ash_{f}", (1.0, 0.45, 0.2), 6),
                    (1, 0.45, 0.2), 1)
    inst.hide_render = True
    ps = em.modifiers.new("ps", "PARTICLE_SYSTEM").particle_system
    st = ps.settings
    st.count = p.get("count", 2500)
    st.frame_start = f
    st.frame_end = f + dur
    st.lifetime = 240
    st.emit_from = "FACE"
    st.normal_factor = -2.0
    st.effector_weights.gravity = 0.04
    st.render_type = "OBJECT"
    st.instance_object = inst
    st.particle_size = 1.0
    st.size_random = 0.7


def fx_helix(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 4.0) * FPS)
    rgb = col(p.get("color", "VIOLET"), P)
    root = bpy.data.objects.new(f"helix_{f}", None)
    _coll().objects.link(root)
    root.location = A.at("LowerTorso", f + 10) + Vector((0, 0, -1.5))
    for k in range(p.get("count", 3)):
        cu = _helix_curve("hx", p.get("radius", 3.0), p.get("height", 7.0), 2.0, k * 2.094, 0.0)
        cu.bevel_depth = 0.09
        ob = _new_obj(f"helix_{f}_{k}", cu, _mat_add(), rgb)
        ob.parent = root
        _fade(ob, rgb, f, f + 30, f + dur - 4, f + dur, peak=0.8)
        _vis_window(ob, f, f + dur)
    _key(root, "rotation_euler", f, (0, 0, 0), "LINEAR")
    _key(root, "rotation_euler", f + dur, (0, 0, math.radians(200 * dur / FPS)))
    _key(root, "scale", f + dur - 8, (1, 1, 1), "EXPO", "EASE_IN")
    _key(root, "scale", f + dur, (0.02, 0.02, 0.4))


def fx_orbs(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 4.0) * FPS)
    rgb = col(p.get("color", "CORE"), P)
    root = bpy.data.objects.new(f"orbs_{f}", None)
    _coll().objects.link(root)
    root.location = A.at("chest", f + 10)
    n = p.get("count", 6)
    for k in range(n):
        a = 2 * math.pi * k / n
        ob = _new_obj(f"orb_{f}_{k}", _sphere("orb", 0.35, 16, 8), _mat_add(), rgb)
        ob.parent = root
        ob.location = (math.cos(a) * p.get("radius", 4.0), math.sin(a) * p.get("radius", 4.0), 0.6 * math.sin(3 * a))
        _fade(ob, rgb, f, f + 20, f + dur - 2, f + dur, peak=1.0)
        _vis_window(ob, f, f + dur)
    _key(root, "rotation_euler", f, (0, 0, 0), "LINEAR")
    _key(root, "rotation_euler", f + dur, (0.3, 0, math.radians(120 * dur / FPS)))
    _key(root, "scale", f + dur - 8, (1, 1, 1), "EXPO", "EASE_IN")
    _key(root, "scale", f + dur, (0.01, 0.01, 0.01))


def fx_halo(c, A, P):
    """Eclipse: dark disc + bright corona + rays, behind the caster's back."""
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 4.0) * FPS)
    rgb = col(p.get("color", "VIOLET"), P)
    core = col("CORE", P)
    root = bpy.data.objects.new(f"halo_{f}", None)
    _coll().objects.link(root)
    pos = A.at("UpperTorso", f + 40)
    root.location = pos + Vector((0, -1.6, 1.2))
    root.rotation_euler = (math.radians(90), 0, 0)
    R = p.get("radius", 3.6)
    disc = _new_obj(f"halo_disc_{f}", _cyl("disc", 1.0, 0.05, 64), _mat_smoke(), (0.0, 0.0, 0.0))
    disc.parent = root
    disc.scale = (R * 0.92, R * 0.92, 1)
    _fade(disc, (0, 0, 0), f, f + 30, f + dur - 4, f + dur, peak=0.97)
    _vis_window(disc, f, f + dur)
    ring = _new_obj(f"halo_ring_{f}", _torus("hr", R, 0.22, 96, 12), _mat_add(), core)
    ring.parent = root
    _fade(ring, core, f, f + 30, f + dur - 4, f + dur, peak=1.0)
    _vis_window(ring, f, f + dur)
    glow = _new_obj(f"halo_glow_{f}", _torus("hg", R * 1.08, 0.6, 96, 12), _mat_add(), rgb)
    glow.parent = root
    _fade(glow, rgb, f, f + 30, f + dur - 4, f + dur, peak=0.35)
    _vis_window(glow, f, f + dur)
    for k in range(16):
        a = 2 * math.pi * k / 16
        L = R * (0.9 + 0.8 * (k % 2))
        ray = _new_obj(f"halo_ray_{f}_{k}", _box("ray", L, 0.07, 0.07), _mat_add(), rgb)
        ray.parent = root
        ray.location = (math.cos(a) * (R + L / 2), math.sin(a) * (R + L / 2), 0)
        ray.rotation_euler = (0, 0, a)
        _fade(ray, rgb, f + 20 + k, f + 40 + k, f + dur - 4, f + dur, peak=0.6)
        _vis_window(ray, f, f + dur)
    _key(root, "scale", f, (0.1, 0.1, 0.1), "BACK", "EASE_OUT")
    _key(root, "scale", f + 30, (1, 1, 1))
    _key(root, "scale", f + dur - 8, (1, 1, 1), "EXPO", "EASE_IN")
    _key(root, "scale", f + dur, (0.02, 0.02, 0.02))


def fx_point(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 2.0) * FPS)
    rgb = col("CORE", P)
    ob = _new_obj(f"point_{f}", _sphere("pt", 1.0, 24, 12), _mat_add(), rgb)
    ob.location = A.at("hands", f + 10) + Vector((0, 0.15, 0.25))
    for k, fr in enumerate(range(f, f + dur, 30)):
        _key(ob, "scale", fr, (0.18, 0.18, 0.18), "SINE", "EASE_IN_OUT")
        _key(ob, "scale", fr + 8, (0.42, 0.42, 0.42), "SINE", "EASE_IN_OUT")
    _key(ob, "scale", f + dur, (0.25, 0.25, 0.25))
    _fade(ob, rgb, f, f + 4, f + dur, f + dur + 1, peak=1.0)
    _vis_window(ob, f, f + dur)


# --------------------------------------------------------------------------
# screen-space approximations (compositor + exposure) and camera shake
# --------------------------------------------------------------------------
def screen_track(scene, cues):
    """exposure / saturation keyframes from 'screen' cues."""
    tree = scene.node_tree
    hsv = tree.nodes.get("VFX_HSV")
    if hsv is None:
        rl = tree.nodes.get("Render Layers")
        glare = tree.nodes.get("Glare")
        hsv = tree.nodes.new("CompositorNodeHueSat")
        hsv.name = "VFX_HSV"
        tree.links.new(rl.outputs["Image"], hsv.inputs["Image"])
        tree.links.new(hsv.outputs["Image"], glare.inputs["Image"])
    sat = hsv.inputs["Saturation"]
    vs = scene.view_settings
    base_exp = vs.exposure
    pts_exp = [(0, base_exp)]
    pts_sat = [(0, 1.0)]
    for c in cues:
        if c["fx"] != "screen":
            continue
        f = c["frame"]
        p = c["params"]
        kind = p.get("kind")
        if kind == "white":
            pts_exp += [(f - 1, None), (f, base_exp + 4.0), (f + 3, base_exp + 2.0), (f + 24, base_exp + 0.2),
                        (f + 90, base_exp)]
        elif kind == "flash":
            pts_exp += [(f - 1, None), (f, base_exp + 1.6 * p.get("brightness", 0.4) / 0.4), (f + 8, base_exp)]
        elif kind == "dim":
            d = int(p.get("dur", 1.0) * FPS)
            pts_exp += [(f, None), (f + d, base_exp + 4.0 * p.get("brightness", -0.15))]
            # keep hue in previs: Roblox ColorCorrection affects VFX too, so the
            # runtime uses the same moderated floor (see Screen.luau)
            pts_sat += [(f, None), (f + d, max(0.7, 1.0 + p.get("saturation", -0.3)))]
        elif kind == "restore":
            d = int(p.get("dur", 1.0) * FPS)
            pts_exp += [(f, None), (f + d, base_exp)]
            pts_sat += [(f, None), (f + d, 1.0)]
    last = base_exp
    for fr, v in sorted(pts_exp, key=lambda x: x[0]):
        if v is None:
            v = last
        vs.exposure = v
        vs.keyframe_insert("exposure", frame=fr)
        last = v
    lasts = 1.0
    for fr, v in sorted(pts_sat, key=lambda x: x[0]):
        if v is None:
            v = lasts
        sat.default_value = v
        sat.keyframe_insert("default_value", frame=fr)
        lasts = v


def camera_shake(cam, cues, fps=FPS):
    shakes = [(c["frame"], c["params"]) for c in cues if c["fx"] == "shake"]
    if not shakes or cam.animation_data is None:
        return
    for fc in list(cam.animation_data.action.fcurves):
        if fc.data_path != "location":
            continue
        for kp in fc.keyframe_points:
            f = kp.co.x
            off = 0.0
            for f0, p in shakes:
                d = p.get("dur", 0.3) * fps
                if f0 <= f <= f0 + d:
                    k = 1.0 - (f - f0) / d
                    off += p.get("amp", 1.0) * 0.12 * k * math.sin(f * (2.1 + fc.array_index) + fc.array_index)
            kp.co.y += off
            kp.handle_left.y += off
            kp.handle_right.y += off


HANDLERS = {
    "ring": fx_ring, "flash": fx_flash, "step_sigil": fx_step_sigil, "sigil": fx_sigil,
    "converge": fx_converge, "nuke": fx_nuke, "column": fx_column, "mushroom": fx_mushroom,
    "dust_wall": fx_dust_wall, "debris": fx_debris, "ash": fx_ash, "helix": fx_helix, "orbs": fx_orbs,
    "halo": fx_halo, "point": fx_point,
}


def build(scene, ao, timing, cues, palette):
    clear()
    A = Anchors(timing)
    scene.cycles.transparent_max_bounces = 24
    skipped = []
    build_trails(cues, A, palette)
    fx_blade_visibility(cues, timing, None)
    for c in cues:
        fx = c["fx"]
        if fx in ("trail", "hide_blade", "show_blade"):
            continue
        if fx == "afterimage":
            fx_afterimage(c, A, palette, ao)
            continue
        if fx == "circuits":
            fx_circuits(c, A, palette, ao)
        elif fx in HANDLERS:
            HANDLERS[fx](c, A, palette)
        elif fx in ("screen", "shake"):
            continue
        else:
            skipped.append(fx)
    screen_track(scene, cues)
    if scene.camera is not None:
        camera_shake(scene.camera, cues)
    return sorted(set(skipped))


# ==========================================================================
# Components for ANIM_02..05
# ==========================================================================
def follow(ob, A, anchor, f0, f1, offset=Vector((0, 0, 0)), step=1):
    for f in range(f0, f1 + 1, step):
        ob.location = A.at(anchor, f) + offset
        ob.keyframe_insert("location", frame=f)
    for fc in ob.animation_data.action.fcurves:
        if fc.data_path == "location":
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"


def _trail_material(name, cols, life, f0, f1):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "vf"
    val = nt.nodes.new("ShaderNodeValue")
    val.outputs[0].default_value = f0
    val.outputs[0].keyframe_insert("default_value", frame=f0)
    val.outputs[0].default_value = f1 + life
    val.outputs[0].keyframe_insert("default_value", frame=f1 + life)
    for fc in nt.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    age = nt.nodes.new("ShaderNodeMath")
    age.operation = "SUBTRACT"
    nt.links.new(val.outputs[0], age.inputs[0])
    nt.links.new(attr.outputs["Fac"], age.inputs[1])
    born = nt.nodes.new("ShaderNodeMath")
    born.operation = "GREATER_THAN"
    born.inputs[1].default_value = -0.5
    nt.links.new(age.outputs[0], born.inputs[0])
    fade = nt.nodes.new("ShaderNodeMapRange")
    fade.inputs["From Min"].default_value = 0.0
    fade.inputs["From Max"].default_value = float(life)
    fade.inputs["To Min"].default_value = 1.0
    fade.inputs["To Max"].default_value = 0.0
    nt.links.new(age.outputs[0], fade.inputs["Value"])
    vis = nt.nodes.new("ShaderNodeMath")
    vis.operation = "MULTIPLY"
    nt.links.new(born.outputs[0], vis.inputs[0])
    nt.links.new(fade.outputs["Result"], vis.inputs[1])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*cols[0], 1)
    ramp.color_ramp.elements[1].color = (*cols[2], 1)
    mid = ramp.color_ramp.elements.new(0.45)
    mid.color = (*cols[1], 1)
    agen = nt.nodes.new("ShaderNodeMapRange")
    agen.inputs["From Max"].default_value = float(life)
    nt.links.new(age.outputs[0], agen.inputs["Value"])
    nt.links.new(agen.outputs["Result"], ramp.inputs["Fac"])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    st = nt.nodes.new("ShaderNodeMath")
    st.operation = "MULTIPLY"
    st.inputs[1].default_value = 5.0
    nt.links.new(vis.outputs[0], st.inputs[0])
    nt.links.new(st.outputs[0], em.inputs["Strength"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    try:
        m.emission_sampling = "NONE"
    except Exception:
        pass
    return m


def ribbon(name, A, a_name, b_name, f0, f1, cols, life=10, extend=None):
    """Swept surface between two anchors over [f0, f1], fading by age."""
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    layer = bm.verts.layers.float.new("vf")
    prev = None
    for f in range(f0, f1 + 1):
        a = A.at(a_name, f)
        b = A.at(b_name, f)
        if extend:
            b = a + (b - a) * extend
        va = bm.verts.new(a)
        vb = bm.verts.new(b)
        va[layer] = f
        vb[layer] = f
        if prev:
            bm.faces.new((prev[0], prev[1], vb, va))
        prev = (va, vb)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    _coll().objects.link(ob)
    me.materials.append(_trail_material(f"M_{name}", cols, life, f0, f1))
    ob.visible_shadow = False
    _vis_window(ob, f0, f1 + life)
    return ob


def build_trails(cues, A, P):
    """Pair TRAIL on/off cues per target and build fading ribbons."""
    open_ = {}
    for c in sorted([c for c in cues if c["fx"] == "trail"], key=lambda x: x["frame"]):
        tgt = c["anchor"]
        p = c["params"]
        if p.get("on"):
            open_[tgt] = c
        elif tgt in open_:
            s = open_.pop(tgt)
            sp = s["params"]
            cols = [col(sp.get("color", "CORE"), P), col(sp.get("color2", "GOLD"), P), col(sp.get("color3", "EMBER"), P)]
            life = max(4, int(sp.get("lifetime", 0.18) * FPS))
            if tgt == "blade":
                ribbon(f"trail_{s['frame']}", A, "blade_base", "blade_tip", s["frame"], c["frame"], cols, life)
            elif tgt == "blade_l":
                ribbon(f"trailL_{s['frame']}", A, "blade_l_base", "blade_l_tip", s["frame"], c["frame"], cols, life)
            elif tgt == "body":
                ribbon(f"trailB_{s['frame']}", A, "LowerTorso", "Head", s["frame"], c["frame"], cols, life)


def _jag_curve(name, p0, p1, segs=10, jitter=0.6, rng=_RNG, bevel=0.06):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(segs)
    d = p1 - p0
    for i in range(segs + 1):
        t = i / segs
        q = p0 + d * t
        if 0 < i < segs:
            q = q + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter * d.length / segs * 1.6
        sp.points[i].co = (q.x, q.y, q.z, 1.0)
    cu.bevel_depth = bevel
    return cu


def bolt_flicker(name, p0, p1, f, dur, rgb, variants=3, bevel=0.06, jitter=0.6):
    for v in range(variants):
        ob = _new_obj(f"{name}_{v}", _jag_curve(f"{name}_c{v}", p0, p1, 10, jitter, bevel=bevel), _mat_add(), rgb)
        start = f + v * max(1, dur // variants)
        end = min(f + dur, start + max(2, dur // variants + 1))
        _fade(ob, rgb, start, start, end - 1, end, peak=1.0)
        _vis_window(ob, start, end)


def fx_bolts(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "ELECTRIC"), P)
    dur = max(4, int(p.get("dur", 0.2) * FPS))
    origin = A.at(c["anchor"] or "chest", f)
    lo, hi = p.get("length", (2.0, 6.0))
    for k in range(p.get("count", 4)):
        if p.get("from_sky"):
            p0, p1 = origin + Vector((0, 0, hi)), origin
        else:
            dirv = Vector((_RNG.uniform(-1, 1), _RNG.uniform(-1, 1), _RNG.uniform(-0.6, 1.0)))
            if p.get("forward"):
                dirv = Vector((_RNG.uniform(-0.4, 0.4), 1.0, _RNG.uniform(-0.3, 0.3)))
            if p.get("to_ground"):
                dirv.z = -abs(dirv.z) - 0.6
            p0, p1 = origin, origin + dirv.normalized() * _RNG.uniform(lo, hi)
        bolt_flicker(f"bolt_{f}_{k}", p0, p1, f + _RNG.randint(0, 3), dur, rgb, bevel=0.05 if hi < 30 else 0.25)


def fx_lightning_hand(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 4.0) * FPS)
    rgb = col(p.get("color", "ELECTRIC"), P)
    core = _new_obj(f"lhand_core_{f}", _sphere("lc", 0.35, 16, 8), _mat_add(), col("CORE", P))
    follow(core, A, c["anchor"], f, f + dur)
    _fade(core, col("CORE", P), f, f + 4, f + dur - 4, f + dur, peak=0.9)
    _vis_window(core, f, f + dur)
    glow = _new_obj(f"lhand_glow_{f}", _sphere("lg", 0.8, 16, 8), _mat_add(), rgb)
    follow(glow, A, c["anchor"], f, f + dur)
    _fade(glow, rgb, f, f + 4, f + dur - 4, f + dur, peak=0.35)
    _vis_window(glow, f, f + dur)
    for k in range(f, f + dur, 3):
        pos = A.at(c["anchor"], k)
        for j in range(2):
            d = Vector((_RNG.uniform(-1, 1), _RNG.uniform(-1, 1), _RNG.uniform(-1, 1))).normalized()
            ob = _new_obj(f"lh_{f}_{k}_{j}", _jag_curve("lhc", pos, pos + d * _RNG.uniform(0.8, 2.2), 6, 0.9,
                                                       bevel=0.025), _mat_add(), rgb)
            _fade(ob, rgb, k, k, k + 2, k + 3, peak=1.0)
            _vis_window(ob, k, k + 3)


def fx_scar_path(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 3.0) * FPS)
    fade = int(p.get("fade", 1.5) * FPS)
    rgb = col(p.get("color", "ELECTRIC"), P)
    cu = bpy.data.curves.new(f"scar_{f}", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    pts = []
    for k in range(f, f + dur, 4):
        h = A.at(c["anchor"], k)
        pts.append(Vector((h.x, h.y, -2.97)))
    sp.points.add(len(pts) - 1)
    for i, q in enumerate(pts):
        sp.points[i].co = (q.x, q.y, q.z, 1)
    cu.bevel_depth = 0.08
    ob = _new_obj(f"scar_{f}", cu, _mat_add(), rgb)
    cu.bevel_factor_end = 0.0
    cu.keyframe_insert("bevel_factor_end", frame=f)
    cu.bevel_factor_end = 1.0
    cu.keyframe_insert("bevel_factor_end", frame=f + dur)
    _fade(ob, rgb, f, f + 6, f + dur, f + dur + fade, peak=0.7)
    _vis_window(ob, f, f + dur + fade)


def fx_storm_clouds(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 10.0) * FPS)
    R = p.get("radius", 70.0)
    center = A.at(c["anchor"], f)
    rgbc = (0.08, 0.08, 0.12)
    for k in range(5):
        ob = _new_obj(f"cloud_{f}_{k}", _sphere("cl", 1.0, 32, 16), _mat_smoke(), rgbc)
        ob.location = center + Vector((_RNG.uniform(-0.3, 0.3) * R, _RNG.uniform(-0.3, 0.3) * R, _RNG.uniform(-3, 3)))
        ob.scale = (R * (0.6 + 0.2 * k / 5), R * (0.55 + 0.15 * k / 5), 4.0 + k)
        _key(ob, "rotation_euler", f, (0, 0, 0), "LINEAR")
        _key(ob, "rotation_euler", f + dur, (0, 0, math.radians(20 * (1 if k % 2 else -1))))
        _fade(ob, rgbc, f, f + 90, f + dur - 60, f + dur, peak=0.82)
        _vis_window(ob, f, f + dur)
    if p.get("rift"):
        ring = _new_obj(f"rift_{f}", _torus("rift", R * 0.25, 2.0, 64, 8), _mat_add(), col("CRIMSON", P))
        ring.location = center + Vector((0, 0, -6))
        _key(ring, "scale", f, (0.1, 0.1, 0.1), "EXPO", "EASE_OUT")
        _key(ring, "scale", f + 120, (1, 1, 0.3))
        _fade(ring, col("CRIMSON", P), f, f + 30, f + dur - 60, f + dur, peak=0.5)
        _vis_window(ring, f, f + dur)


def fx_cloud_flash(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "ELECTRIC"), P)
    center = A.at(c["anchor"], f)
    _light(f"cflash_{f}", center, rgb, 4e5, f, f + 8)
    for k in range(p.get("count", 3)):
        a = center + Vector((_RNG.uniform(-30, 30), _RNG.uniform(-30, 30), -2))
        b = a + Vector((_RNG.uniform(-25, 25), _RNG.uniform(-25, 25), _RNG.uniform(-6, 2)))
        bolt_flicker(f"cbolt_{f}_{k}", a, b, f, 8, rgb, bevel=0.25, jitter=0.8)


def fx_dragon(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 1.0) * FPS)
    rgb = col(p.get("color", "ELECTRIC"), P)
    target = A.at(c["anchor"], f + dur)
    H = p.get("height", 70.0)
    pts = []
    for i in range(40):
        t = i / 39
        ang = t * 2.4 * math.pi
        r = (1 - t) * 18
        pts.append(target + Vector((math.cos(ang) * r, math.sin(ang) * r - (1 - t) * 20, H * (1 - t) ** 1.4)))
    cu = bpy.data.curves.new(f"dragon_{f}", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, q in enumerate(pts):
        sp.points[i].co = (q.x, q.y, q.z, 1)
    sp.order_u = 4
    sp.use_endpoint_u = True
    cu.bevel_depth = 1.6
    cu.bevel_resolution = 3
    ob = _new_obj(f"dragon_{f}", cu, _mat_add(), rgb)
    cu.bevel_factor_end = 0.0
    cu.keyframe_insert("bevel_factor_end", frame=f)
    cu.bevel_factor_end = 1.0
    cu.keyframe_insert("bevel_factor_end", frame=f + dur)
    cu.bevel_factor_start = 0.0
    cu.keyframe_insert("bevel_factor_start", frame=f + dur // 2)
    cu.bevel_factor_start = 0.95
    cu.keyframe_insert("bevel_factor_start", frame=f + dur + 6)
    _fade(ob, rgb, f, f + 4, f + dur + 2, f + dur + 10, peak=0.9)
    _vis_window(ob, f, f + dur + 10)
    head = _new_obj(f"dragon_head_{f}", _sphere("dh", 2.6, 24, 12), _mat_add(), col("CORE", P))
    for k in range(dur + 1):
        t = k / dur
        idx = min(len(pts) - 1, int(t * (len(pts) - 1)))
        head.location = pts[idx]
        head.keyframe_insert("location", frame=f + k)
    _fade(head, col("CORE", P), f, f + 4, f + dur, f + dur + 2, peak=1.0)
    _vis_window(head, f, f + dur + 2)
    for k in range(f, f + dur, 4):
        t = (k - f) / dur
        idx = min(len(pts) - 1, int(t * (len(pts) - 1)))
        bolt_flicker(f"dbolt_{k}", pts[idx], pts[idx] + Vector((_RNG.uniform(-6, 6), _RNG.uniform(-6, 6),
                                                                _RNG.uniform(-6, 6))), k, 4, rgb, 2, 0.12)


def fx_pillar(c, A, P):
    f = c["frame"]
    p = c["params"]
    center = A.at(c["anchor"], f)
    H = p.get("height", 60.0)
    rise = max(2, int(p.get("rise", 0.15) * FPS))
    hold = int(p.get("hold", 0.5) * FPS)
    fade = int(p.get("fade", 0.6) * FPS)
    for k, (rr, nm, pk) in enumerate(((p.get("r1", 5.0), p.get("color", "EMBER"), 0.35),
                                      (p.get("r0", 3.0) * 0.5, p.get("color2", "CORE"), 0.9))):
        ob = _new_obj(f"pillar_{f}_{k}", _cyl("pl", 1.0, 1.0), _mat_add(), col(nm, P))
        _key(ob, "scale", f, (rr, rr, 0.5), "EXPO", "EASE_OUT")
        _key(ob, "location", f, center, "EXPO", "EASE_OUT")
        _key(ob, "scale", f + rise, (rr, rr, H))
        _key(ob, "location", f + rise, center + Vector((0, 0, H / 2)))
        _key(ob, "scale", f + rise + hold + fade, (rr * 0.2, rr * 0.2, H))
        _fade(ob, col(nm, P), f, f + 1, f + rise + hold, f + rise + hold + fade, peak=pk)
        _vis_window(ob, f, f + rise + hold + fade)


def fx_spiral_sphere(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 2.0) * FPS)
    grow = int(p.get("grow", 1.0) * FPS)
    rgb = col(p.get("color", "AZURE"), P)
    rgb2 = col(p.get("color2", "CYAN"), P)
    root = bpy.data.objects.new(f"sphere_{f}", None)
    _coll().objects.link(root)
    follow(root, A, c["anchor"], f, f + dur, Vector((0, 0.45, 0.35)))
    r0, r1 = p.get("r0", 0.3), p.get("r1", 1.0)
    _key(root, "scale", f, (r0, r0, r0), "SINE", "EASE_OUT")
    _key(root, "scale", f + grow, (r1, r1, r1))
    core = _new_obj(f"sphere_core_{f}", _sphere("sc", 0.55, 24, 12), _mat_add(), col("CORE", P))
    core.parent = root
    shell = _new_obj(f"sphere_shell_{f}", _sphere("ss", 1.0, 32, 16), _mat_add(), rgb)
    shell.parent = root
    parts = [(core, col("CORE", P), 0.9), (shell, rgb, 0.4)]
    for k in range(3):
        ring = _new_obj(f"sphere_ring_{f}_{k}", _torus("sr", 1.05, 0.05, 48, 6), _mat_add(), rgb2)
        ring.parent = root
        ring.rotation_euler = (math.radians(60 * k), math.radians(30 * k), 0)
        _key(ring, "rotation_euler", f, (math.radians(60 * k), math.radians(30 * k), 0), "LINEAR")
        _key(ring, "rotation_euler", f + dur, (math.radians(60 * k + 30), math.radians(30 * k),
                                                 math.radians(1440 * dur / FPS)))
        parts.append((ring, rgb2, 0.8))
    for ob, cc, pk in parts:
        _fade(ob, cc, f, f + 6, f + dur - 2, f + dur, peak=pk)
        _vis_window(ob, f, f + dur)


def fx_spiral_crater(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 2.0) * FPS)
    rgb = col(p.get("color", "AZURE"), P)
    center = A.at(c["anchor"], f)
    center = Vector((center.x, center.y, -2.97))
    R = p.get("radius", 8.0)
    for k in range(5):
        cu = bpy.data.curves.new(f"sarm_{f}_{k}", "CURVE")
        cu.dimensions = "3D"
        sp = cu.splines.new("POLY")
        n = 40
        sp.points.add(n - 1)
        for i in range(n):
            t = i / (n - 1)
            a = k * 2 * math.pi / 5 + t * 1.8 * math.pi
            sp.points[i].co = (center.x + math.cos(a) * R * t, center.y + math.sin(a) * R * t, center.z, 1)
        cu.bevel_depth = 0.12
        ob = _new_obj(f"sarm_{f}_{k}", cu, _mat_add(), rgb)
        cu.bevel_factor_end = 0.0
        cu.keyframe_insert("bevel_factor_end", frame=f)
        cu.bevel_factor_end = 1.0
        cu.keyframe_insert("bevel_factor_end", frame=f + 12)
        _fade(ob, rgb, f, f + 2, f + dur - 30, f + dur, peak=0.8)
        _vis_window(ob, f, f + dur)


def fx_spiral_rings(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 0.6) * FPS)
    rgb = col(p.get("color", "CYAN"), P)
    pos = A.at(c["anchor"], f)
    lo, hi = p.get("radius", (2.0, 18.0))
    for k in range(p.get("count", 5)):
        ob = _new_obj(f"sring_{f}_{k}", _torus("srg", 1.0, 0.05, 64, 6), _mat_add(), rgb)
        ob.location = pos
        ob.rotation_euler = (math.radians(90 + 12 * k), 0, math.radians(37 * k))
        s0 = lo
        s1 = lo + (hi - lo) * (k + 1) / p.get("count", 5)
        _key(ob, "scale", f + k * 2, (s0, s0, s0), "EXPO", "EASE_OUT")
        _key(ob, "scale", f + k * 2 + dur, (s1, s1, s1))
        _fade(ob, rgb, f + k * 2, f + k * 2 + 1, f + k * 2 + dur // 2, f + k * 2 + dur, peak=0.8)
        _vis_window(ob, f + k * 2, f + k * 2 + dur)


def fx_sphere_shot(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "AZURE"), P)
    start = A.at(c["anchor"], f)
    travel = p.get("travel", 18.0)
    fly = max(4, int(travel / p.get("speed", 60.0) * FPS))
    fwd = (A.at("chest", f) - A.at("root", f))
    fwd.z = 0
    i = max(0, min(len(A.rows) - 1, f - A.f0))
    j = min(len(A.rows) - 1, i + 1)
    head_dir = A.at("LeftHand", f) - A.at("LowerTorso", f)
    head_dir.z = 0
    d = head_dir.normalized() if head_dir.length > 0.1 else Vector((0, 1, 0))
    ob = _new_obj(f"shot_{f}", _sphere("sh", p.get("radius", 0.7), 16, 8), _mat_add(), rgb)
    _key(ob, "location", f, start, "LINEAR")
    _key(ob, "location", f + fly, start + d * travel)
    _fade(ob, rgb, f, f + 1, f + fly, f + fly + 1, peak=0.9)
    _vis_window(ob, f, f + fly)
    fx_flash({"frame": f + fly, "anchor": None, "params": {"color": "CORE", "size0": 1.0, "size1": 6.0, "dur": 0.15}},
             type("X", (), {"at": lambda self, n, fr: start + d * travel})(), P)
    fx_ring({"frame": f + fly, "anchor": None, "params": {"color": p.get("color2", "CYAN"), "r0": 0.5, "r1": 7.0,
                                                         "w0": 0.8, "dur": 0.3, "orient": "facing"}},
            type("X", (), {"at": lambda self, n, fr: start + d * travel})(), P)


def _shuriken_group(name, rgb, rgb2, blades=4):
    root = bpy.data.objects.new(name, None)
    _coll().objects.link(root)
    spin = bpy.data.objects.new(name + "_spin", None)
    _coll().objects.link(spin)
    spin.parent = root
    parts = []
    core = _new_obj(name + "_core", _sphere("shc", 0.5, 24, 12), _mat_add(), (1, 1, 1))
    core.parent = root
    parts.append((core, (1.0, 1.0, 1.0), 0.9))
    shell = _new_obj(name + "_shell", _sphere("shs", 1.0, 32, 16), _mat_add(), rgb)
    shell.parent = root
    parts.append((shell, rgb, 0.35))
    for k in range(blades):
        a = 2 * math.pi * k / blades
        bl = _new_obj(f"{name}_blade{k}", _box("shb", 2.4, 0.5, 0.04), _mat_add(), rgb2)
        bl.parent = spin
        bl.location = (math.cos(a) * 2.0, math.sin(a) * 2.0, 0)
        bl.rotation_euler = (0, 0, a + 0.5)
        parts.append((bl, rgb2, 0.8))
    ring = _new_obj(name + "_ring", _torus("shr", 2.2, 0.06, 64, 6), _mat_add(), rgb2)
    ring.parent = spin
    parts.append((ring, rgb2, 0.6))
    return root, spin, parts


def fx_shuriken(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 5.0) * FPS)
    rgb, rgb2 = col(p.get("color", "AZURE"), P), col(p.get("color2", "WIND"), P)
    root, spin, parts = _shuriken_group(f"shur_{f}", rgb, rgb2, p.get("blades", 4))
    follow(root, A, c["anchor"], f, f + dur, Vector((0, 0, p.get("above", 1.6))))
    r0, r1 = p.get("r0", 0.4), p.get("r1", 2.4)
    _key(root, "scale", f, (r0, r0, r0), "SINE", "EASE_OUT")
    _key(root, "scale", f + int(p.get("grow", 4.0) * FPS), (r1, r1, r1))
    _key(spin, "rotation_euler", f, (0, 0, 0), "LINEAR")
    _key(spin, "rotation_euler", f + dur, (0, 0, math.radians(2000 * dur / FPS)))
    for ob, cc, pk in parts:
        _fade(ob, cc, f, f + 10, f + dur - 1, f + dur, peak=pk)
        _vis_window(ob, f, f + dur)


def fx_shuriken_fly(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 0.7) * FPS)
    rgb, rgb2 = col(p.get("color", "AZURE"), P), col(p.get("color2", "WIND"), P)
    root, spin, parts = _shuriken_group(f"shfly_{f}", rgb, rgb2)
    start = A.at(c["anchor"], f) + Vector((0, 0, 1.0))
    head = A.at("chest", f) - A.at("LowerTorso", f)
    d = Vector((0, 1, 0))
    r = p.get("radius", 2.6)
    root.scale = (r, r, r)
    _key(root, "location", f, start, "SINE", "EASE_IN")
    _key(root, "location", f + dur, start + d * p.get("travel", 40.0) + Vector((0, 0, -1.0)))
    _key(spin, "rotation_euler", f, (0, 0, 0), "LINEAR")
    _key(spin, "rotation_euler", f + dur, (0, 0, math.radians(2400 * dur / FPS)))
    for ob, cc, pk in parts:
        _fade(ob, cc, f, f + 1, f + dur - 1, f + dur, peak=pk)
        _vis_window(ob, f, f + dur)


def fx_wind_dome(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 2.0) * FPS)
    R = p.get("radius", 26.0)
    rgb, rgb2 = col(p.get("color", "WIND"), P), col(p.get("color2", "AZURE"), P)
    center = A.at(c["anchor"], f)
    center = Vector((center.x, center.y, -3.0))
    dome = _new_obj(f"dome_{f}", _sphere("dm", 1.0, 48, 24), _mat_add(), rgb2)
    dome.location = center
    _key(dome, "scale", f, (2, 2, 2), "EXPO", "EASE_OUT")
    _key(dome, "scale", f + 30, (R, R, R * 0.85))
    _fade(dome, rgb2, f, f + 3, f + dur - 6, f + dur, peak=0.12)
    _vis_window(dome, f, f + dur)
    spin = bpy.data.objects.new(f"dome_spin_{f}", None)
    _coll().objects.link(spin)
    spin.location = center
    for k in range(70):
        u = _RNG.uniform(0, 2 * math.pi)
        v = _RNG.uniform(0.05, 0.95)
        rr = R * _RNG.uniform(0.3, 0.95)
        L = _RNG.uniform(2.0, 7.0)
        ob = _new_obj(f"dome_blade_{f}_{k}", _box("db", L, 0.08, 0.08), _mat_add(), rgb)
        ob.parent = spin
        ob.location = (math.cos(u) * rr * math.sqrt(1 - v * v), math.sin(u) * rr * math.sqrt(1 - v * v), rr * v)
        ob.rotation_euler = (_RNG.uniform(-0.5, 0.5), _RNG.uniform(-0.5, 0.5), u + math.pi / 2)
        _fade(ob, rgb, f + 6, f + 14, f + dur - 8, f + dur, peak=0.9)
        _vis_window(ob, f + 6, f + dur)
    _key(spin, "rotation_euler", f, (0, 0, 0), "LINEAR")
    _key(spin, "rotation_euler", f + dur, (0, 0, math.radians(720 * dur / FPS)))
    _key(spin, "scale", f + 6, (0.2, 0.2, 0.2), "EXPO", "EASE_OUT")
    _key(spin, "scale", f + 30, (1, 1, 1))


def fx_flame_aura(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 10.0) * FPS)
    rgb = col(p.get("color", "VIOLET"), P)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.6, depth=0.2, vertices=24)
    em = bpy.context.object
    em.name = f"aura_{f}"
    bpy.context.scene.collection.objects.unlink(em)
    _coll().objects.link(em)
    follow(em, A, "feet", f, f + dur, Vector((0, 0, 0.2)), step=4)
    em.show_instancer_for_render = False
    inst = _new_obj(f"aura_inst_{f}", _sphere("ai", 0.35, 10, 6), _mat_particle(f"PM_aura_{f}", rgb, 7), rgb, 1)
    inst.hide_render = True
    ps = em.modifiers.new("ps", "PARTICLE_SYSTEM").particle_system
    st = ps.settings
    st.count = int(dur * 6)
    st.frame_start = f
    st.frame_end = f + dur
    st.lifetime = 50
    st.lifetime_random = 0.5
    st.emit_from = "FACE"
    st.normal_factor = 0.0
    st.object_align_factor = (0, 0, 6.0)
    st.factor_random = 1.2
    st.effector_weights.gravity = -0.25
    st.render_type = "OBJECT"
    st.instance_object = inst
    st.particle_size = 1.0
    st.size_random = 0.6


def fx_crack(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "EMBER"), P)
    center = A.at(c["anchor"], f)
    center = Vector((center.x, center.y, -2.975))
    grow = max(2, int(p.get("grow", 0.2) * FPS))
    hold = int(p.get("hold", 1.0) * FPS)
    fade = int(p.get("fade", 0.6) * FPS)
    lo, hi = p.get("length", (3.0, 8.0))
    for k in range(p.get("count", 7)):
        a = _RNG.uniform(0, 2 * math.pi)
        L = _RNG.uniform(lo, hi)
        ob = _new_obj(f"crack_{f}_{k}", _box("ck", 1.0, p.get("width", 0.3), 0.03), _mat_add(), rgb)
        ob.rotation_euler = (0, 0, a)
        d = Vector((math.cos(a), math.sin(a), 0))
        _key(ob, "scale", f, (0.01, 1, 1), "EXPO", "EASE_OUT")
        _key(ob, "location", f, center, "EXPO", "EASE_OUT")
        _key(ob, "scale", f + grow, (L, 1, 1))
        _key(ob, "location", f + grow, center + d * L / 2)
        _fade(ob, rgb, f, f + 1, f + grow + hold, f + grow + hold + fade, peak=0.7)
        _vis_window(ob, f, f + grow + hold + fade)


def fx_burst(c, A, P):
    f = c["frame"]
    p = c["params"]
    tmpl = p.get("template", "sparks")
    rgb = col(p.get("color", "GOLD"), P) if tmpl not in ("dust", "dust_ring", "smoke") else (0.5, 0.45, 0.42)
    sp = p.get("speed", (20, 40))
    speed = sum(sp) / 2 if isinstance(sp, (list, tuple)) else sp
    if tmpl in ("dust", "dust_ring", "smoke"):
        speed = 8.0
    life = 30 if tmpl in ("sparks", "void_sparks") else 60
    fx_particles_burst(f"burst_{tmpl}_{f}", A.at(c["anchor"] or "chest", f), f, int(p.get("count", 20)), rgb,
                       speed, life, size=(0.06, 0.06, 0.7) if "spark" in tmpl else (0.18, 0.18, 0.18),
                       gravity=0.3 if "spark" in tmpl else 0.05, strength=10 if "dust" not in tmpl else 1.5)


def fx_slash_hit(c, A, P):
    f = c["frame"]
    p = c["params"]
    fx_burst({"frame": f, "anchor": c["anchor"], "params": {"template": "sparks", "count": p.get("count", 16),
                                                            "color": p.get("color2", "CYAN"), "speed": (25, 45)}},
             A, P)
    fx_flash({"frame": f, "anchor": c["anchor"], "params": {"color": p.get("color", "CORE"), "size0": 0.3,
                                                            "size1": 2.2, "dur": 0.08}}, A, P)


def fx_starburst(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "CYAN"), P)
    dur = int(p.get("dur", 0.3) * FPS)
    pos = A.at(c["anchor"], f)
    S = p.get("size", 20)
    for k in range(8):
        a = math.pi * k / 4
        L = S * (1.0 if k % 2 == 0 else 0.55)
        ob = _new_obj(f"star_{f}_{k}", _box("sb", L, 0.12, 0.12), _mat_add(), rgb)
        ob.location = pos
        ob.rotation_euler = (math.radians(90), a, 0)
        _key(ob, "scale", f, (0.05, 1, 1), "EXPO", "EASE_OUT")
        _key(ob, "scale", f + dur, (1, 0.3, 0.3))
        _fade(ob, rgb, f, f + 1, f + 4, f + dur, peak=1.0)
        _vis_window(ob, f, f + dur)


def fx_thrust_rings(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "AZURE"), P)
    pos = A.at(c["anchor"], f)
    d = (A.at("blade_tip", f) - A.at("blade_base", f))
    d = d.normalized() if d.length > 0.01 else Vector((0, 1, 0))
    L = p.get("length", 24)
    dur = int(p.get("dur", 0.4) * FPS)
    for k in range(p.get("count", 4)):
        ob = _new_obj(f"thr_{f}_{k}", _torus("tr", 1.0, 0.12, 48, 6), _mat_add(), rgb)
        ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        start = pos + d * (L * k / p.get("count", 4))
        _key(ob, "location", f + k * 2, start, "EXPO", "EASE_OUT")
        _key(ob, "location", f + k * 2 + dur, start + d * 6)
        s = 1.0 + k
        _key(ob, "scale", f + k * 2, (0.3, 0.3, 0.3), "EXPO", "EASE_OUT")
        _key(ob, "scale", f + k * 2 + dur, (s * 2.5, s * 2.5, s * 2.5))
        _fade(ob, rgb, f + k * 2, f + k * 2 + 1, f + k * 2 + dur // 2, f + k * 2 + dur, peak=0.9)
        _vis_window(ob, f + k * 2, f + k * 2 + dur)


def fx_x_ground(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "CYAN"), P)
    center = A.at(c["anchor"], f)
    center = Vector((center.x, center.y, -2.97))
    L = p.get("length", 22)
    dur = int(p.get("dur", 1.4) * FPS)
    for k, a in enumerate((math.radians(45), math.radians(-45))):
        ob = _new_obj(f"xg_{f}_{k}", _box("xg", L, 0.5, 0.04), _mat_add(), rgb)
        ob.location = center
        ob.rotation_euler = (0, 0, a)
        _key(ob, "scale", f, (0.02, 1, 1), "EXPO", "EASE_OUT")
        _key(ob, "scale", f + 8, (1, 1, 1))
        _fade(ob, rgb, f, f + 1, f + dur - 30, f + dur, peak=0.9)
        _vis_window(ob, f, f + dur)


def fx_specter(c, A, P):
    """Giant spectral warrior built from primitives (previs stand-in for the
    Roblox SpecterRig model). Stages/actions are keyed by later cues."""
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 20.0) * FPS)
    rgb = col(p.get("color", "VIOLET"), P)
    rgb2 = col(p.get("color2", "BLUEFLAME"), P)
    H = p.get("height", 18.0)
    root = bpy.data.objects.new("SPECTER", None)
    _coll().objects.link(root)
    base = A.at("feet", f)
    root.location = base + Vector((0, -1.5, 0))
    parts = {"1": [], "2": [], "3": []}

    def add(stage, ob, cc, pk):
        ob.parent = root
        parts[stage].append((ob, cc, pk))

    spine = _new_obj("sp_spine", _cyl("spn", 0.6, H * 0.45, 16), _mat_add(), rgb)
    spine.location = (0, -1.2, H * 0.45)
    add("1", spine, rgb, 0.5)
    for i in range(6):
        rib = _new_obj(f"sp_rib{i}", _torus("rib", 3.2 - 0.25 * i, 0.22, 32, 6), _mat_add(), rgb2)
        rib.location = (0, 0, H * 0.32 + i * 1.1)
        rib.scale = (1, 0.7, 0.35)
        add("1", rib, rgb2, 0.55)
    skull = _new_obj("sp_skull", _sphere("skl", 2.4, 24, 12), _mat_add(), rgb)
    skull.location = (0, 0.3, H * 0.86)
    add("2", skull, rgb, 0.35)
    for sx in (-0.8, 0.8):
        eye = _new_obj(f"sp_eye{sx}", _sphere("eye", 0.45, 12, 6), _mat_add(), col("CRIMSON", P))
        eye.location = (sx, 2.4, H * 0.88)
        add("2", eye, col("CRIMSON", P), 1.0)
    arms = {}
    for side in (-1, 1):
        sh = bpy.data.objects.new(f"sp_shoulder{side}", None)
        _coll().objects.link(sh)
        sh.parent = root
        sh.location = (side * 4.2, 0, H * 0.72)
        arms[side] = sh
        up = _new_obj(f"sp_upper{side}", _cyl("upa", 0.9, 6.0, 12), _mat_add(), rgb)
        up.location = (side * 1.0, 0, -2.6)
        up.rotation_euler = (0, side * 0.35, 0)
        up.parent = sh
        parts["2"].append((up, rgb, 0.4))
        lo = _new_obj(f"sp_lower{side}", _cyl("loa", 0.8, 6.0, 12), _mat_add(), rgb2)
        lo.location = (side * 2.0, 2.2, -5.4)
        lo.rotation_euler = (math.radians(-70), 0, 0)
        lo.parent = sh
        parts["2"].append((lo, rgb2, 0.45))
    for i, (sx, sz, w, h) in enumerate(((0, H * 0.62, 7.5, 4.0), (0, H * 0.42, 6.0, 3.2), (-4.2, H * 0.74, 3.2, 2.0),
                                        (4.2, H * 0.74, 3.2, 2.0))):
        plate = _new_obj(f"sp_armor{i}", _box("arm", w, 2.4, h), _mat_add(), rgb)
        plate.location = (sx, 0.6, sz)
        add("3", plate, rgb, 0.3)
    blade = _new_obj("sp_blade", _box("spb", 1.2, 0.4, 26.0), _mat_add(), col("CORE", P))
    blade.parent = arms[1]
    blade.location = (2.6, 6.5, -2.0)
    blade.rotation_euler = (math.radians(-60), 0, 0)
    parts["3"].append((blade, col("CORE", P), 0.6))
    fx_specter.state = {"root": root, "parts": parts, "arms": arms, "end": f + dur, "start": f}
    _key(root, "scale", f, (0.6, 0.6, 0.6), "BACK", "EASE_OUT")
    _key(root, "scale", f + 40, (1, 1, 1))
    for ob, cc, pk in parts["1"]:
        _fade(ob, cc, f, f + 40, f + dur - 60, f + dur, peak=pk)
        _vis_window(ob, f, f + dur)


def fx_specter_stage(c, A, P):
    st = getattr(fx_specter, "state", None)
    if not st:
        return
    f = c["frame"]
    stage = str(c["params"].get("stage", 2))
    for ob, cc, pk in st["parts"].get(stage, []):
        _fade(ob, cc, f, f + 40, st["end"] - 60, st["end"], peak=pk)
        _vis_window(ob, f, st["end"])


def fx_specter_action(c, A, P):
    st = getattr(fx_specter, "state", None)
    if not st:
        return
    f = c["frame"]
    act = c["params"].get("action")
    arm = st["arms"][1]
    larm = st["arms"][-1]
    if act == "swing":
        _key(arm, "rotation_euler", f - 30, (0, 0, math.radians(70)), "BACK", "EASE_IN")
        _key(arm, "rotation_euler", f, (0, 0, math.radians(-110)), "EXPO", "EASE_OUT")
        _key(arm, "rotation_euler", f + 50, (0, 0, math.radians(-20)))
    elif act == "slam":
        _key(arm, "rotation_euler", f - 30, (math.radians(70), 0, 0), "BACK", "EASE_IN")
        _key(arm, "rotation_euler", f, (math.radians(-80), 0, 0), "EXPO", "EASE_OUT")
        _key(arm, "rotation_euler", f + 60, (0, 0, 0))
    elif act == "shield":
        for a, s in ((arm, 1), (larm, -1)):
            _key(a, "rotation_euler", f - 20, (0, 0, 0), "BACK", "EASE_OUT")
            _key(a, "rotation_euler", f, (math.radians(-60), 0, math.radians(-55 * s)))
            _key(a, "rotation_euler", f + 140, (math.radians(-60), 0, math.radians(-55 * s)))
    elif act == "fade":
        root = st["root"]
        _key(root, "scale", f, (1, 1, 1), "SINE", "EASE_IN")
        _key(root, "scale", f + 90, (1.25, 1.25, 1.4))


def fx_crescent_wave(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "VIOLET"), P)
    dur = int(p.get("dur", 0.9) * FPS)
    R = p.get("radius", 20.0)
    start = A.at(c["anchor"], f) + Vector((0, 2, 0))
    me = _torus("cw", 1.0, 0.06, 64, 6)
    # keep the front half only (crescent)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < 0.15], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    ob = _new_obj(f"cwave_{f}", me, _mat_add(), rgb)
    ob.scale = (R, R, R * 0.5)
    _key(ob, "location", f, start, "SINE", "EASE_OUT")
    _key(ob, "location", f + dur, start + Vector((0, p.get("travel", 80.0), 0)))
    _key(ob, "scale", f, (R * 0.5, R * 0.5, R * 0.3), "EXPO", "EASE_OUT")
    _key(ob, "scale", f + dur, (R * 1.3, R * 1.3, R * 0.6))
    _fade(ob, rgb, f, f + 2, f + dur // 2, f + dur, peak=0.9)
    _vis_window(ob, f, f + dur)


def fx_fissure(c, A, P):
    f = c["frame"]
    p = c["params"]
    rgb = col(p.get("color", "VIOLET"), P)
    dur = int(p.get("dur", 3.0) * FPS)
    start = A.at(c["anchor"], f)
    start = Vector((start.x, start.y, -2.97))
    L = p.get("length", 60.0)
    ob = _new_obj(f"fiss_{f}", _box("fs", 1.6, 1.0, 0.05), _mat_add(), rgb)
    _key(ob, "scale", f, (1, 0.01, 1), "EXPO", "EASE_OUT")
    _key(ob, "location", f, start, "EXPO", "EASE_OUT")
    _key(ob, "scale", f + 18, (1, L, 1))
    _key(ob, "location", f + 18, start + Vector((0, L / 2, 0)))
    _fade(ob, rgb, f, f + 1, f + dur - 60, f + dur, peak=0.9)
    _vis_window(ob, f, f + dur)
    for k in range(8):
        fx_debris({"frame": f + 2 + k * 2, "anchor": None, "params": {"count": 8, "speed": 24.0, "dur": 1.5}},
                  type("X", (), {"at": lambda self, n, fr, kk=k: start + Vector((0, L * (kk + 1) / 9, 0))})(), P)


def fx_meteor(c, A, P):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("fall", 4.0) * FPS)
    target = A.at(c["anchor"], f + dur)
    target = Vector((target.x, target.y, -3.0))
    R = p.get("radius", 20.0)
    start = target + Vector((0, 60.0, p.get("start_height", 300.0)))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=R)
    rock = bpy.context.object
    rock.name = f"meteor_{f}"
    bpy.context.scene.collection.objects.unlink(rock)
    _coll().objects.link(rock)
    for v in rock.data.vertices:
        v.co *= _RNG.uniform(0.85, 1.12)
    rock.data.materials.append(_mat_smoke())
    rock.color = (0.12, 0.08, 0.07, 1.0)
    shell = _new_obj(f"meteor_fire_{f}", _sphere("mf", R * 1.15, 32, 16), _mat_add(), col("EMBER", P))
    trail = _new_obj(f"meteor_trail_{f}", _cyl("mt", R * 0.9, 1.0, 24), _mat_add(), col("CRIMSON", P))
    d = (target - start).normalized()
    trail.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    for ob in (rock, shell, trail):
        _key(ob, "location", f, start, "SINE", "EASE_IN")
        _key(ob, "location", f + dur, target + Vector((0, 0, R * 0.3)))
    _key(trail, "scale", f, (1, 1, R * 2), "LINEAR")
    _key(trail, "scale", f + dur, (1, 1, R * 7))
    _key(rock, "rotation_euler", f, (0, 0, 0), "LINEAR")
    _key(rock, "rotation_euler", f + dur, (1.2, 0.6, 0.3))
    _fade(rock, (0.12, 0.08, 0.07), f, f + 20, f + dur, f + dur + 1, peak=1.0)
    _fade(shell, col("EMBER", P), f, f + 40, f + dur, f + dur + 1, peak=0.45)
    _fade(trail, col("CRIMSON", P), f, f + 40, f + dur, f + dur + 1, peak=0.25)
    for ob in (rock, shell, trail):
        _vis_window(ob, f, f + dur)


def fx_afterimage(c, A, P, ao):
    f = c["frame"]
    p = c["params"]
    dur = int(p.get("dur", 0.3) * FPS)
    rgb = col(p.get("color", "AZURE"), P)
    scene = bpy.context.scene
    scene.frame_set(f)
    deps = bpy.context.evaluated_depsgraph_get()
    for name in ("Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
                 "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
                 "RightLowerLeg", "RightFoot"):
        src = bpy.data.objects.get(name)
        if src is None:
            continue
        ev = src.evaluated_get(deps)
        ob = bpy.data.objects.new(f"ghost_{f}_{name}", src.data.copy())
        ob.data.materials.clear()
        ob.data.materials.append(_mat_add())
        _coll().objects.link(ob)
        ob.matrix_world = ev.matrix_world.copy()
        ob.color = (*rgb, 0.0)
        _fade(ob, rgb, f, f + 1, f + 2, f + dur, peak=0.35)
        _vis_window(ob, f, f + dur)


def fx_blade_visibility(cues, timing, ability_meta):
    """Keyframe the previs blade meshes from materialize / hide cues."""
    azure = bpy.data.objects.get("AzureBlade")
    ember = bpy.data.objects.get("EmberBlade")
    names = {c["fx"]: c["frame"] for c in cues}
    if azure is not None:
        azure.hide_render = True
        azure.keyframe_insert("hide_render", frame=0)
        if "materialize" in names:
            azure.hide_render = False
            azure.keyframe_insert("hide_render", frame=names["materialize"])
        if "dematerialize" in names:
            azure.hide_render = True
            azure.keyframe_insert("hide_render", frame=names["dematerialize"] + 20)
    if ember is not None:
        ember.hide_render = False
        ember.keyframe_insert("hide_render", frame=0)
        if "hide_blade" in names:
            ember.hide_render = True
            ember.keyframe_insert("hide_render", frame=0)
        if "show_blade" in names:
            ember.hide_render = False
            ember.keyframe_insert("hide_render", frame=names["show_blade"])
    for ob in (azure, ember):
        if ob is not None and ob.animation_data:
            for fc in ob.animation_data.action.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = "CONSTANT"


def fx_materialize(c, A, P):
    fx_burst({"frame": c["frame"], "anchor": c["anchor"], "params": {"template": "sparks", "count": 30,
                                                                     "color": c["params"].get("color", "AZURE"),
                                                                     "speed": (6, 14)}}, A, P)
    fx_flash({"frame": c["frame"], "anchor": c["anchor"], "params": {"color": "CORE", "size0": 0.3, "size1": 2.5,
                                                                     "dur": 0.15}}, A, P)


HANDLERS.update({
    "bolts": fx_bolts, "lightning_hand": fx_lightning_hand, "scar_path": fx_scar_path,
    "storm_clouds": fx_storm_clouds, "cloud_flash": fx_cloud_flash, "dragon": fx_dragon, "pillar": fx_pillar,
    "spiral_sphere": fx_spiral_sphere, "spiral_crater": fx_spiral_crater, "spiral_rings": fx_spiral_rings,
    "sphere_shot": fx_sphere_shot, "shuriken": fx_shuriken, "shuriken_fly": fx_shuriken_fly,
    "wind_dome": fx_wind_dome, "flame_aura": fx_flame_aura, "crack": fx_crack, "burst": fx_burst,
    "slash_hit": fx_slash_hit, "starburst": fx_starburst, "thrust_rings": fx_thrust_rings, "x_ground": fx_x_ground,
    "specter": fx_specter, "specter_stage": fx_specter_stage, "specter_action": fx_specter_action,
    "crescent_wave": fx_crescent_wave, "fissure": fx_fissure, "meteor": fx_meteor,
    "materialize": fx_materialize, "dematerialize": fx_materialize,
})
