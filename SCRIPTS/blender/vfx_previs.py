"""Previs dos VFX no Blender: monta as camadas dos cues e os efeitos especiais (círculo, halo, hélice...)."""

import math
import random

import bpy
from mathutils import Matrix, Vector

FPS = 60
_RNG = random.Random(7)
COLL = "VFX_PREVIS"


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

    def roblox(self, name, frame):
        row = self.rows[max(0, min(len(self.rows) - 1, frame - self.f0))]
        if name in row:
            return Vector(row[name])
        r = row["root"]
        if name == "feet":
            return Vector((r[0], -2.98, r[2]))
        if name == "chest":
            return Vector(row["UpperTorso"])
        if name == "hands":
            return (Vector(row["LeftHand"]) + Vector(row["grip"])) / 2
        if name == "blade_mid":
            return (Vector(row["blade_base"]) + Vector(row["blade_tip"])) / 2
        if name.startswith("sky:"):
            return Vector((r[0], float(name[4:]), r[2]))
        if name == "impact":
            t = row["blade_tip"]
            return Vector((t[0], -2.98, t[2]))
        return Vector(r)

    def at(self, name, frame):
        return rb(self.roblox(name, frame))


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
    root = _sigil_group(
        f"sigil_{f}",
        A.at(c["anchor"] or "feet", f),
        p.get("radius", 8.0),
        rgb,
        f,
        f + dur,
        p.get("spin", 20) * (1 if (f // 7) % 2 else -1),
        p.get("spokes", 12),
        p.get("rings", 3),
    )
    if p.get("implode_at"):
        fi = p["implode_at"]
        _key(root, "scale", fi - 1, (1, 1, 1), "EXPO", "EASE_IN")
        _key(root, "scale", fi + 10, (0.02, 0.02, 0.02))


def fx_circuits(c, A, P, ao):
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


SPECIALS = {
    "sigil": "fx_sigil",
    "circuits": "fx_circuits",
    "helix": "fx_helix",
    "orbs": "fx_orbs",
    "halo": "fx_halo",
    "point": "fx_point",
}


def _special(kind, ly, f, anchor, A, P, ao):
    params = dict(ly)
    if "duration" in params:
        params["dur"] = params.pop("duration")
    for k in [k for k in params if k.endswith("_at")]:
        params[k] = A.f0 + int(round(params[k] * FPS))
    c = {"frame": f + int(round(ly.get("delay", 0.0) * FPS)), "anchor": ly.get("anchor", anchor), "params": params}
    fn = globals()[SPECIALS[kind]]
    if kind == "circuits":
        fn(c, A, P, ao)
    else:
        fn(c, A, P)


def build(scene, ao, timing, cues, palette):
    import vfx_layers as vl

    clear()
    A = Anchors(timing)
    scene.cycles.transparent_max_bounces = 24
    skipped, screens, shakes = [], [], []
    counts = {}
    build_trails(cues, A, palette)
    for c in cues:
        fx = c["fx"]
        if fx in ("trail", "hide_blade", "show_blade"):
            continue
        if fx != "emit":
            skipped.append(fx)
            continue
        for i, ly in enumerate(c["params"]["layers"]):
            k = ly["kind"]
            anchor = ly.get("anchor", c["anchor"] or "root")
            tag = f"{c['marker']}_{c['frame']}_{i}"
            f = c["frame"]
            n = 0
            if k == "part":
                n = vl.build_part(ly, f, A, anchor, palette, tag, -2.98)
            elif k == "animate":
                n = vl.build_animate(ly, f, A, anchor, palette, tag)
            elif k == "ring":
                n = vl.build_ring(ly, f, A, anchor, palette, tag, scene)
            elif k == "lightning":
                n = vl.build_lightning(ly, f, A, anchor, palette, tag, -2.98)
            elif k == "light":
                n = vl.build_light(ly, f, A, anchor, palette, tag)
            elif k == "distort":
                n = vl.build_distort(ly, f, A, anchor, palette, tag)
            elif k in ("screen", "flash"):
                screens.append((f, ly))
            elif k == "shake":
                shakes.append((f, dict(ly, _anchor=anchor)))
            elif k in SPECIALS:
                _special(k, ly, f, anchor, A, palette, ao)
                n = 1
            else:
                skipped.append(k)
            counts[k] = counts.get(k, 0) + n
    vl.screen_layers(scene, screens)
    vl.camera_shakes(scene, shakes, A)
    print("previs objetos por tipo:", counts)
    return sorted(set(skipped))


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
    open_ = {}
    for c in sorted([c for c in cues if c["fx"] == "trail"], key=lambda x: x["frame"]):
        tgt = c["anchor"]
        p = c["params"]
        if p.get("on"):
            open_[tgt] = c
        elif tgt in open_:
            s = open_.pop(tgt)
            sp = s["params"]
            cols = [
                col(sp.get("color", "CORE"), P),
                col(sp.get("color2", "GOLD"), P),
                col(sp.get("color3", "EMBER"), P),
            ]
            life = max(4, int(sp.get("lifetime", 0.18) * FPS))
            if tgt == "blade":
                ribbon(f"trail_{s['frame']}", A, "blade_base", "blade_tip", s["frame"], c["frame"], cols, life)
            elif tgt == "blade_l":
                ribbon(f"trailL_{s['frame']}", A, "blade_l_base", "blade_l_tip", s["frame"], c["frame"], cols, life)
            elif tgt == "body":
                ribbon(f"trailB_{s['frame']}", A, "LowerTorso", "Head", s["frame"], c["frame"], cols, life)
