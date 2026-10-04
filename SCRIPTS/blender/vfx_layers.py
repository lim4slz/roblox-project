"""
Previs das camadas de VFX (vfx_cues.part/animate/ring/...). Simula no Python
as mesmas regras que o runtime do Roblox usa (ROBLOX/src/shared/VFX/Emitter.luau)
e gera objetos com keyframes.
"""

import math
import random

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from vfx_cues import fade
from vfx_previs import FPS, _coll, _mat_add, _mat_smoke, col

STEP = 2
MESHES = {}


# ---------------------------------------------------------------- valores


def rng_range(r, rnd):
    if isinstance(r, (list, tuple)):
        return rnd.uniform(r[0], r[1])
    return float(r)


def curve(c, u, env=0.0):
    if c is None:
        return None
    if isinstance(c, (int, float)):
        return float(c) * (1.0 + env)
    pts = c
    if u <= pts[0][0]:
        v = pts[0][1]
    elif u >= pts[-1][0]:
        v = pts[-1][1]
    else:
        v = pts[-1][1]
        for a, b in zip(pts, pts[1:]):
            if a[0] <= u <= b[0]:
                k = (u - a[0]) / max(b[0] - a[0], 1e-6)
                v = a[1] + (b[1] - a[1]) * k
                break
    return v * (1.0 + env)


def color_at(seq, u, P):
    if seq is None:
        return (1.0, 1.0, 1.0)
    if isinstance(seq, (str, tuple)) and not (isinstance(seq, tuple) and isinstance(seq[0], (list, tuple))):
        return col(seq, P)
    pts = [(t, col(cv, P)) for t, cv in seq]
    if u <= pts[0][0]:
        return pts[0][1]
    if u >= pts[-1][0]:
        return pts[-1][1]
    for a, b in zip(pts, pts[1:]):
        if a[0] <= u <= b[0]:
            k = (u - a[0]) / max(b[0] - a[0], 1e-6)
            return tuple(x + (y - x) * k for x, y in zip(a[1], b[1]))
    return pts[-1][1]


def rvec(v):
    return Vector((v[0], -v[2], v[1]))


# ---------------------------------------------------------------- malhas e materiais


def _mesh(shape):
    if shape in MESHES and MESHES[shape].name in bpy.data.meshes:
        return MESHES[shape]
    if shape == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=12, ring_count=6)
    elif shape == "hiball":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=48, ring_count=24)
    elif shape == "rock":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5)
    elif shape == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1.0, vertices=32)
    elif shape == "disc":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=0.02, vertices=64)
    elif shape == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.04, major_segments=96, minor_segments=8)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.object
    me = ob.data
    if shape == "rock":
        rnd = random.Random(3)
        for v in me.vertices:
            v.co *= rnd.uniform(0.75, 1.15)
    if shape in ("ball", "hiball", "cylinder", "torus"):
        for p in me.polygons:
            p.use_smooth = True
    bpy.data.objects.remove(ob, do_unlink=True)
    me.name = "VFXM_" + shape
    MESHES[shape] = me
    return me


def _mat_rock():
    m = bpy.data.materials.get("VFX_ROCK")
    if m:
        return m
    m = bpy.data.materials.new("VFX_ROCK")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.95
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(info.outputs["Color"], bs.inputs["Base Color"])
    nt.links.new(info.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(bs.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def _mat_glass():
    m = bpy.data.materials.get("VFX_GLASS")
    if m:
        return m
    m = bpy.data.materials.new("VFX_GLASS")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    gl = nt.nodes.new("ShaderNodeBsdfRefraction")
    gl.inputs["IOR"].default_value = 1.08
    gl.inputs["Roughness"].default_value = 0.02
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(info.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(gl.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def _material(look):
    if look in ("smoke", "dark"):
        return _mat_smoke()
    if look == "rock":
        return _mat_rock()
    if look == "glass":
        return _mat_glass()
    return _mat_add()


def _object(name, shape, look):
    me = _mesh(shape)
    ob = bpy.data.objects.new(name, me)
    ob.data = me
    _coll().objects.link(ob)
    mat = _material(look)
    ob.material_slots and None
    if not me.materials:
        me.materials.append(mat)
    ob.material_slots[0].link = "OBJECT"
    ob.material_slots[0].material = mat
    ob.visible_shadow = look == "rock"
    return ob


def _bake(ob, frames, locs, rots, scales, colors, f_born, f_dead):
    ob.location = locs[0]
    ob.rotation_euler = rots[0]
    ob.scale = scales[0]
    ob.color = colors[0]
    for path in ("location", "rotation_euler", "scale", "color"):
        ob.keyframe_insert(path, frame=frames[0])
    fcs = {(fc.data_path, fc.array_index): fc for fc in ob.animation_data.action.fcurves}
    series = {"location": locs, "rotation_euler": rots, "scale": scales, "color": colors}
    n = len(frames)
    for path, vals in series.items():
        for i in range(4 if path == "color" else 3):
            fc = fcs[(path, i)]
            if n > 1:
                fc.keyframe_points.add(n - 1)
            co = []
            for f, v in zip(frames, vals):
                co += [f, v[i]]
            fc.keyframe_points.foreach_set("co", co)
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
            fc.update()
    ob.hide_render = True
    ob.keyframe_insert("hide_render", frame=0)
    ob.hide_render = False
    ob.keyframe_insert("hide_render", frame=max(1, f_born))
    ob.hide_render = True
    ob.keyframe_insert("hide_render", frame=f_dead + 1)
    for fc in ob.animation_data.action.fcurves:
        if fc.data_path == "hide_render":
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"


# ---------------------------------------------------------------- part


def _spawn_offset(sp, rnd):
    if not sp:
        return Vector((0, 0, 0)), None
    shape = sp.get("shape", "point")
    r = sp.get("radius", 0.0)
    r0, r1 = r if isinstance(r, (list, tuple)) else (0.0 if shape in ("sphere", "disc") else r, r)
    if shape == "box":
        bx = sp.get("box", (1, 1, 1))
        return (
            Vector((rnd.uniform(-0.5, 0.5) * bx[0], rnd.uniform(-0.5, 0.5) * bx[1], rnd.uniform(-0.5, 0.5) * bx[2])),
            None,
        )
    if shape in ("sphere", "shell"):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        if sp.get("upper"):
            d.y = abs(d.y)
        rad = r1 if shape == "shell" else rnd.uniform(r0, r1)
        return d * rad, d
    if shape == "vring":
        a = rnd.uniform(0, 2 * math.pi)
        rad = rnd.uniform(r0, r1)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        return d * rad, d
    if shape in ("disc", "ring"):
        a = rnd.uniform(0, 2 * math.pi)
        rad = math.sqrt(rnd.uniform(r0 * r0, r1 * r1)) if shape == "disc" else rnd.uniform(r0, r1)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        return d * rad + Vector((0, sp.get("height", 0.0), 0)), d
    return Vector((0, 0, 0)), None


def _cone(axis, spread, rnd):
    axis = axis.normalized()
    if spread <= 0:
        return axis
    ang = math.radians(rnd.uniform(0, spread))
    rot = rnd.uniform(0, 2 * math.pi)
    ortho = axis.orthogonal().normalized()
    d = Quaternion(axis, rot) @ (Quaternion(ortho, ang) @ axis)
    return d.normalized()


def _direction(ly, off, radial, rnd):
    d = ly.get("dir", "up")
    tilt = math.radians(ly.get("tilt", 0.0))
    if d == "out" or d == "in":
        base = radial if radial is not None else (off.normalized() if off.length > 1e-4 else Vector((1, 0, 0)))
        base = Vector((base.x, 0.0, base.z)).normalized() if base.length > 1e-4 else Vector((1, 0, 0))
        base = base * math.cos(tilt) + Vector((0, 1, 0)) * math.sin(tilt)
        if d == "in":
            base = -(radial if radial is not None else off.normalized())
    elif d == "radial":
        base = radial if radial is not None else (off.normalized() if off.length > 1e-4 else Vector((0, 1, 0)))
    elif isinstance(d, (list, tuple)):
        base = Vector(d)
    else:
        base = {
            "up": Vector((0, 1, 0)),
            "down": Vector((0, -1, 0)),
            "forward": Vector((0, 0, -1)),
            "back": Vector((0, 0, 1)),
        }.get(d, Vector((0, 1, 0)))
    return _cone(base, ly.get("spread", 0.0), rnd)


def spawn_times(ly, rnd):
    t = []
    delay = ly.get("delay", 0.0)
    for _ in range(int(ly.get("count", 0))):
        t.append(delay)
    rate, dur = ly.get("rate", 0.0), ly.get("duration", 0.0)
    if rate and dur:
        n = int(rate * dur)
        for i in range(n):
            t.append(delay + (i + rnd.random()) / rate)
    return t


def sim_part(ly, f_cue, A, anchor, rnd, ground_y):
    """Lista de partículas: (frames, posições roblox, velocidades, vida, env, rot0, spin)."""
    out = []
    life_r = ly.get("lifetime", 1.0)
    drag = ly.get("drag", 0.0)
    acc = Vector(ly.get("accel", (0, 0, 0)))
    pull = ly.get("pull", 0.0)
    gnd = ly.get("ground")
    link = ly.get("link", "world") == "follow"
    base_off = Vector(ly.get("offset", (0, 0, 0)))
    pull_f = A.f0 + int(round(ly["pull_at"] * FPS)) if "pull_at" in ly else None
    for st in spawn_times(ly, rnd):
        f0 = f_cue + int(round(st * FPS))
        life = rng_range(life_r, rnd)
        n = max(2, int(round(life * FPS)))
        a0 = A.roblox(anchor, f0)
        sp = ly.get("spawn") or {}
        if sp.get("shape") == "segment":
            b0 = A.roblox(sp["to"], f0)
            off, radial = (b0 - a0) * rnd.random(), None
            jit = sp.get("radius", 0.0)
            off += Vector((rnd.uniform(-jit, jit), rnd.uniform(-jit, jit), rnd.uniform(-jit, jit)))
        else:
            off, radial = _spawn_offset(sp, rnd)
        p0 = a0 + base_off + off
        if ly.get("snap") == "ground":
            p0.y = ground_y
        d = _direction(ly, off, radial, rnd)
        v0 = d * rng_range(ly.get("speed", 0.0), rnd)
        env = rnd.uniform(-1, 1) * ly.get("env", 0.0)
        frames, pos, vel = [], [], []
        p, v = p0.copy(), v0.copy()
        settled = False
        dt = 1.0 / FPS
        for k in range(0, n + 1):
            f = f0 + k
            t = k * dt
            if pull or gnd:
                if k > 0 and not settled:
                    center = A.roblox(ly.get("pull_to", anchor), f) + (base_off if "pull_to" not in ly else Vector())
                    a = acc.copy()
                    pulling = pull and (pull_f is None or f >= pull_f)
                    if pulling:
                        to = center - p
                        if to.length > 1e-3:
                            a += to.normalized() * pull * min(1.0, to.length)
                            v = v * 0.9
                    v = v * math.exp(-drag * dt) + a * dt
                    p = p + v * dt
                    if gnd and p.y < ground_y:
                        p.y = ground_y
                        b = rng_range(gnd.get("bounce", 0.3), rnd)
                        if abs(v.y) < 6.0:
                            v = Vector((v.x * 0.6, 0.0, v.z * 0.6))
                            if v.length < 1.0:
                                settled = True
                        else:
                            v = Vector((v.x * 0.7, -v.y * b, v.z * 0.7))
                cur = p.copy()
            else:
                travel = v0 * ((1 - math.exp(-drag * t)) / drag if drag > 0 else t)
                cur = p0 + travel + acc * (0.5 * t * t)
                v = v0 * math.exp(-drag * t) + acc * t
            if link:
                cur = cur + (A.roblox(anchor, f) - a0)
            frames.append(f)
            pos.append(cur)
            vel.append(v.copy())
        out.append((frames, pos, vel, life, env, rnd.uniform(0, 360), rng_range(ly.get("spin", 0.0), rnd)))
    return out


def build_part(ly, f_cue, A, anchor, P, tag, ground_y):
    rnd = random.Random(hash((tag, f_cue)) & 0xFFFFFFFF)
    shape = ly.get("shape", "ball")
    look = ly.get("look", "neon")
    aspect = Vector(ly.get("aspect", (1, 1, 1)))
    stretch = ly.get("stretch", 0.0)
    orient = ly.get("rot", "random" if shape in ("rock", "shard", "block") else "none")
    vref = max(1.0, rng_range(ly.get("speed", 1.0), random.Random(1)))
    parts = sim_part(ly, f_cue, A, anchor, rnd, ground_y)
    sink = ly.get("ground", {}).get("sink", 0.0) if ly.get("ground") else 0.0
    count = 0
    for i, (frames, pos, vel, life, env, rot0, spin) in enumerate(parts):
        n = len(frames)
        idx = list(range(0, n, STEP))
        if idx[-1] != n - 1:
            idx.append(n - 1)
        fr, locs, rots, scales, cols = [], [], [], [], []
        for k in idx:
            u = k / (n - 1)
            s = curve(ly.get("size", 1.0), u, env)
            sc = Vector((aspect.x * s, aspect.y * s, aspect.z * s))
            p = pos[k]
            if sink and u > 1.0 - sink:
                p = p - Vector((0, s * (u - (1.0 - sink)) / sink, 0))
            if orient == "velocity" and vel[k].length > 1e-3:
                sc.y *= 1.0 + stretch * min(3.0, vel[k].length / vref)
                q = Vector((0, 1, 0)).rotation_difference(vel[k].normalized())
                e = (
                    Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
                    @ q.to_matrix()
                    @ Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
                ).to_euler()
            elif orient == "random":
                ang = math.radians(rot0 + spin * k / FPS)
                e = Euler((ang, ang * 0.7, ang * 1.3))
            else:
                e = Euler((0, 0, math.radians(rot0 * 0 + spin * k / FPS)))
            rgb = color_at(ly.get("color", "CORE"), u, P)
            alpha = 1.0 - max(0.0, min(1.0, curve(ly.get("transparency", 0.0), u)))
            fr.append(frames[k])
            locs.append(rvec(p))
            rots.append(e)
            scales.append(Vector((sc.x, sc.z, sc.y)))
            cols.append((*rgb, alpha * ly.get("intensity", 1.0)))
        ob = _object(f"P_{tag}_{i}", shape, look)
        _bake(ob, fr, locs, rots, scales, cols, frames[0], frames[-1])
        count += 1
    return count


# ---------------------------------------------------------------- animate


def build_animate(ly, f_cue, A, anchor, P, tag):
    f0 = f_cue + int(round(ly.get("delay", 0.0) * FPS))
    life = ly.get("lifetime", 1.0)
    loops = ly.get("loops", 1)
    n = max(2, int(round(life * FPS * loops)))
    shape = ly.get("shape", "hiball")
    ob = _object(f"A_{tag}", shape, ly.get("look", "neon"))
    off = Vector(ly.get("offset", (0, 0, 0)))
    link = ly.get("link", "follow") == "follow"
    a_fix = A.roblox(anchor, f0)
    fr, locs, rots, scales, cols = [], [], [], [], []
    spin = ly.get("spin", (0, 0, 0))
    tilt = ly.get("orient", (0, 0, 0))
    for k in list(range(0, n, STEP)) + [n - 1]:
        u = (k / (n / loops)) % 1.0 if loops > 1 else k / (n - 1)
        if "size_xyz" in ly:
            sx, sy, sz = (curve(c, u) for c in ly["size_xyz"])
        else:
            s = curve(ly.get("size", 1.0), u)
            sx = sy = sz = s
        a = A.roblox(anchor, f0 + k) if link else a_fix
        p = a + off + Vector(ly.get("drift", (0, 0, 0))) * (k / FPS)
        if shape in ("cylinder", "disc", "torus"):
            loc_scale = Vector((sx, sz, sy))
        else:
            loc_scale = Vector((sx, sz, sy))
        t = k / FPS
        e = Euler(
            (
                math.radians(tilt[0] + spin[0] * t),
                math.radians(-(tilt[2] + spin[2] * t)),
                math.radians(tilt[1] + spin[1] * t),
            )
        )
        rgb = color_at(ly.get("color", "CORE"), u, P)
        alpha = 1.0 - max(0.0, min(1.0, curve(ly.get("transparency", 0.0), u)))
        fr.append(f0 + k)
        locs.append(rvec(p))
        rots.append(e)
        scales.append(loc_scale)
        cols.append((*rgb, alpha * ly.get("intensity", 1.0)))
    _bake(ob, fr, locs, rots, scales, cols, f0, f0 + n)
    return 1


# ---------------------------------------------------------------- ring


def build_ring(ly, f_cue, A, anchor, P, tag, scene):
    made = 0
    for j in range(int(ly.get("count", 1))):
        f0 = f_cue + int(round((ly.get("delay", 0.0) + j * ly.get("stagger", 0.0)) * FPS))
        life = ly.get("lifetime", 0.5)
        n = max(2, int(round(life * FPS)))
        cu = bpy.data.curves.new(f"R_{tag}_{j}", "CURVE")
        cu.dimensions = "3D"
        sp = cu.splines.new("NURBS")
        seg = 32
        sp.points.add(seg - 1)
        for i in range(seg):
            a = 2 * math.pi * i / seg
            sp.points[i].co = (math.cos(a), math.sin(a), 0.0, 1.0)
        sp.use_cyclic_u = True
        sp.order_u = 3
        cu.bevel_depth = 0.02
        cu.bevel_resolution = 2
        ob = bpy.data.objects.new(f"R_{tag}_{j}", cu)
        _coll().objects.link(ob)
        cu.materials.append(_mat_add())
        ob.visible_shadow = False
        orient = ly.get("orient", "ground")
        a0 = A.roblox(anchor, f0) + Vector(ly.get("offset", (0, 0, 0)))
        if orient == "facing" and scene.camera is not None:
            scene.frame_set(f0)
            to_cam = (scene.camera.matrix_world.translation - rvec(a0)).normalized()
            base_rot = Vector((0, 0, 1)).rotation_difference(to_cam).to_euler()
        elif orient == "vertical":
            base_rot = Euler((math.radians(90), 0, math.radians(ly.get("yaw", 0.0))))
        else:
            base_rot = Euler((math.radians(ly.get("tiltx", 0.0)), math.radians(ly.get("tiltz", 0.0)), 0))
        for k in list(range(0, n, STEP)) + [n - 1]:
            u = k / (n - 1)
            r = max(
                0.01,
                curve(
                    ly.get("radius", (0.5, 6.0)) if not isinstance(ly.get("radius"), (int, float)) else ly["radius"], u
                ),
            )
            w = max(0.005, curve(ly.get("width", 0.3), u))
            a = A.roblox(anchor, f0 + k) + Vector(ly.get("offset", (0, 0, 0))) if ly.get("link") == "follow" else a0
            ob.location = rvec(a)
            ob.scale = (r, r, r)
            ob.rotation_euler = Euler(
                (base_rot.x, base_rot.y, base_rot.z + math.radians(ly.get("spin", 0.0) * k / FPS))
            )
            cu.bevel_depth = w * 0.5 / r
            rgb = color_at(ly.get("color", "CORE"), u, P)
            alpha = 1.0 - max(0.0, min(1.0, curve(ly.get("transparency", fade()), u)))
            ob.color = (*rgb, alpha * ly.get("intensity", 1.0))
            for path in ("location", "scale", "rotation_euler", "color"):
                ob.keyframe_insert(path, frame=f0 + k)
            cu.keyframe_insert("bevel_depth", frame=f0 + k)
        ob.hide_render = True
        ob.keyframe_insert("hide_render", frame=0)
        ob.hide_render = False
        ob.keyframe_insert("hide_render", frame=max(1, f0))
        ob.hide_render = True
        ob.keyframe_insert("hide_render", frame=f0 + n + 1)
        for fc in ob.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT" if fc.data_path == "hide_render" else "LINEAR"
        made += 1
    return made


# ---------------------------------------------------------------- lightning


def _bolt_points(p0, p1, segs, jitter, rnd):
    d = p1 - p0
    side = d.orthogonal().normalized()
    side2 = d.cross(side).normalized()
    pts = []
    for i in range(segs + 1):
        t = i / segs
        q = p0 + d * t
        if 0 < i < segs:
            amp = jitter * d.length / segs * 1.8 * math.sin(math.pi * t) ** 0.5
            q = q + side * rnd.uniform(-amp, amp) + side2 * rnd.uniform(-amp, amp)
        pts.append(q)
    return pts


def _poly(name, pts, width):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, q in enumerate(pts):
        sp.points[i].co = (q.x, q.y, q.z, 1.0)
    cu.bevel_depth = width * 0.5
    ob = bpy.data.objects.new(name, cu)
    _coll().objects.link(ob)
    cu.materials.append(_mat_add())
    ob.visible_shadow = False
    return ob


def build_lightning(ly, f_cue, A, anchor, P, tag, ground_y):
    rnd = random.Random(hash((tag, f_cue, "L")) & 0xFFFFFFFF)
    made = 0
    flicker = max(2, int(ly.get("flicker", 0.05) * FPS))
    for st in spawn_times(ly, rnd):
        f0 = f_cue + int(round(st * FPS))
        life = max(flicker, int(rng_range(ly.get("lifetime", 0.15), rnd) * FPS))
        a = A.roblox(anchor, f0) + Vector(ly.get("offset", (0, 0, 0)))
        mode = ly.get("target", "around")
        r = rng_range(ly.get("length", (3.0, 7.0)), rnd)
        if mode == "ground":
            ang = rnd.uniform(0, 2 * math.pi)
            dist = rng_range(ly.get("radius", (2.0, 10.0)), rnd)
            b = Vector((a.x + math.cos(ang) * dist, ground_y, a.z + math.sin(ang) * dist))
        elif mode == "anchor":
            b = A.roblox(ly["to"], f0)
        elif mode == "sky":
            b = a + Vector((rnd.uniform(-4, 4), r, rnd.uniform(-4, 4)))
        else:
            d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
            b = a + d * r
        if ly.get("reverse"):
            a, b = b, a
        rgb = color_at(ly.get("color", "LILAC"), 0.0, P)
        core = color_at(ly.get("core", "CORE"), 0.0, P)
        width = ly.get("width", 0.08)
        for v, fs in enumerate(range(f0, f0 + life, flicker)):
            pts = _bolt_points(rvec(a), rvec(b), ly.get("segments", 9), ly.get("jitter", 0.7), rnd)
            group = [(pts, width)]
            for _ in range(ly.get("forks", 2)):
                if rnd.random() < ly.get("fork_chance", 0.6) and len(pts) > 3:
                    i0 = rnd.randint(1, len(pts) - 2)
                    dirv = (pts[-1] - pts[0]).normalized()
                    tip = pts[i0] + (
                        dirv + Vector((rnd.gauss(0, 0.7), rnd.gauss(0, 0.7), rnd.gauss(0, 0.7)))
                    ).normalized() * (pts[-1] - pts[0]).length * rnd.uniform(0.2, 0.45)
                    group.append((_bolt_points(pts[i0], tip, 5, 0.8, rnd), width * 0.55))
            for gi, (gp, w) in enumerate(group):
                for layer_i, (ww, cc, inten) in enumerate(((w * 3.0, rgb, 0.35), (w, core, 1.0))):
                    ob = _poly(f"L_{tag}_{made}_{v}_{gi}_{layer_i}", gp, ww)
                    ob.color = (*cc, inten * ly.get("intensity", 1.0))
                    ob.hide_render = True
                    ob.keyframe_insert("hide_render", frame=0)
                    ob.hide_render = False
                    ob.keyframe_insert("hide_render", frame=max(1, fs))
                    ob.hide_render = True
                    ob.keyframe_insert("hide_render", frame=fs + flicker)
                    for fc in ob.animation_data.action.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = "CONSTANT"
        made += 1
    return made


# ---------------------------------------------------------------- light / distort


def build_light(ly, f_cue, A, anchor, P, tag):
    f0 = f_cue + int(round(ly.get("delay", 0.0) * FPS))
    n = max(2, int(ly.get("lifetime", 0.5) * FPS))
    ld = bpy.data.lights.new(f"LT_{tag}", "POINT")
    ld.shadow_soft_size = ly.get("soft", 2.0)
    ob = bpy.data.objects.new(f"LT_{tag}", ld)
    _coll().objects.link(ob)
    rng = ly.get("range", 20.0)
    for k in [-1] + list(range(0, n, STEP)) + [n - 1, n + 1]:
        u = min(1.0, max(0.0, k / (n - 1)))
        on = 0 <= k <= n - 1
        ob.location = rvec(A.roblox(anchor, f0 + max(0, k)) + Vector(ly.get("offset", (0, 0, 0))))
        ld.color = color_at(ly.get("color", "VIOLET"), u, P)
        ld.energy = (curve(ly.get("brightness", fade(1, 0)), u) * rng * rng * 60.0) if on else 0.0
        ob.keyframe_insert("location", frame=f0 + k)
        ld.keyframe_insert("energy", frame=f0 + k)
        ld.keyframe_insert("color", frame=f0 + k)
    return 1


def build_distort(ly, f_cue, A, anchor, P, tag):
    a = dict(ly)
    a.setdefault("shape", "hiball")
    a["look"] = "glass"
    a.setdefault("link", "world")
    if "radius" in a:
        a["size"] = [(t, v * 2.0) for t, v in a.pop("radius")]
    return build_animate(a, f_cue, A, anchor, P, tag)


# ---------------------------------------------------------------- tela e câmera


def screen_layers(scene, entries):
    """entries: [(frame, layer)] de screen/flash. Gera keys de exposição,
    saturação, contraste e inversão no compositor."""
    tree = scene.node_tree
    rl = tree.nodes.get("Render Layers")
    glare = tree.nodes.get("Glare")
    hsv = tree.nodes.get("VFX_HSV")
    if hsv is None:
        hsv = tree.nodes.new("CompositorNodeHueSat")
        hsv.name = "VFX_HSV"
        tree.links.new(rl.outputs["Image"], hsv.inputs["Image"])
        tree.links.new(hsv.outputs["Image"], glare.inputs["Image"])
    bc = tree.nodes.get("VFX_BC")
    if bc is None:
        bc = tree.nodes.new("CompositorNodeBrightContrast")
        bc.name = "VFX_BC"
        tree.links.new(hsv.outputs["Image"], bc.inputs["Image"])
        tree.links.new(bc.outputs["Image"], glare.inputs["Image"])
    inv = tree.nodes.get("VFX_INV")
    if inv is None:
        inv = tree.nodes.new("CompositorNodeInvert")
        inv.name = "VFX_INV"
        tree.links.new(bc.outputs["Image"], inv.inputs["Color"])
        tree.links.new(inv.outputs["Color"], glare.inputs["Image"])
    vs = scene.view_settings
    base = vs.exposure
    end = max(
        (
            f
            + int(
                (max(ly.get("lifetime", 0.5), ly.get("hold", 0.0)) + ly.get("release", 0.0) + ly.get("delay", 0.0))
                * FPS
            )
            for f, ly in entries
        ),
        default=0,
    )
    if not entries:
        return
    start = min(f for f, _ in entries)
    for f in range(max(0, start - 1), end + 2):
        exp, sat, con, invert = 0.0, 1.0, 0.0, 0.0
        for f0, ly in entries:
            s = f0 + int(ly.get("delay", 0.0) * FPS)
            n = max(1, int(ly.get("lifetime", 0.5) * FPS))
            hold = int(ly.get("hold", 0.0) * FPS)
            rel = int(ly.get("release", 0.0) * FPS)
            if f < s:
                continue
            u = (f - s) / n
            k = 1.0
            if f - s > max(n, hold):
                k = 1.0 - (f - s - max(n, hold)) / rel if rel > 0 else 0.0
                if k <= 0:
                    continue
            u = min(u, 1.0)
            if ly["kind"] == "screen":
                exp += 3.0 * curve(ly.get("brightness", 0.0), u) * k
                sat *= 1.0 + 0.6 * curve(ly.get("saturation", 0.0), u) * k
                con += 40.0 * curve(ly.get("contrast", 0.0), u) * k
            else:
                a = curve(ly.get("alpha", fade(1, 0)), u) * k
                mode = ly.get("mode", "white")
                if mode == "white":
                    exp += 5.0 * a
                elif mode == "black":
                    exp -= 7.0 * a
                elif mode == "invert":
                    invert = max(invert, a)
                    sat *= 1.0 - a
                    con += 60.0 * a
        vs.exposure = base + exp
        vs.keyframe_insert("exposure", frame=f)
        hsv.inputs["Saturation"].default_value = max(0.0, sat)
        hsv.inputs["Saturation"].keyframe_insert("default_value", frame=f)
        bc.inputs["Contrast"].default_value = con
        bc.inputs["Contrast"].keyframe_insert("default_value", frame=f)
        inv.inputs["Fac"].default_value = invert
        inv.inputs["Fac"].keyframe_insert("default_value", frame=f)


def camera_shakes(scene, entries, A):
    cam = scene.camera
    if cam is None or not entries:
        return
    frames = set()
    for f0, ly in entries:
        s = f0 + int(ly.get("delay", 0.0) * FPS)
        frames.update(range(s, s + int(ly.get("lifetime", 0.5) * FPS) + 2))
    base = {}
    for f in sorted(frames):
        scene.frame_set(f)
        base[f] = (cam.location.copy(), cam.rotation_euler.copy())
    for f in sorted(frames):
        off = Vector()
        rot = Vector()
        for f0, ly in entries:
            s = f0 + int(ly.get("delay", 0.0) * FPS)
            n = max(1, int(ly.get("lifetime", 0.5) * FPS))
            if not (s <= f <= s + n):
                continue
            u = (f - s) / n
            amp = curve(ly.get("amplitude", fade(1, 0)), u)
            fall = ly.get("falloff", 0.0)
            if fall:
                d = (base[f][0] - A.at(ly.get("_anchor", "root"), f)).length
                amp *= max(0.0, 1.0 - d / fall)
            fq = ly.get("frequency", 14.0)
            t = f / FPS
            for i in range(3):
                off[i] += amp * 0.5 * math.sin(t * fq * (1.0 + 0.31 * i) * 2.0 + i * 1.7)
                rot[i] += math.radians(ly.get("rot", 0.6)) * amp * math.sin(t * fq * (1.13 + 0.27 * i) * 2.0 + i)
        loc, eul = base[f]
        cam.location = loc + off * 0.15
        cam.rotation_euler = Euler((eul.x + rot.x * 0.3, eul.y + rot.y * 0.3, eul.z + rot.z * 0.3))
        cam.keyframe_insert("location", frame=f)
        cam.keyframe_insert("rotation_euler", frame=f)
