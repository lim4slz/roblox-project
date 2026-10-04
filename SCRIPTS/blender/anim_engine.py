"""
Motor de animação: as poses são escritas no espaço das juntas do Roblox
(o mesmo CFrame que vai pro Pose do KeyframeSequence) e o bake vai pra Action.

Canais esparsos com easing, IK de perna, IK de braço que desvia do corpo,
limite de pulso, atraso/overlap, ruído, cachecol em Verlet e root motion separado.
"""

import math

from mathutils import Euler, Matrix, Quaternion, Vector

import rbx_common as rc

CH = ("rx", "ry", "rz", "tx", "ty", "tz")


def _back_out(u, s=1.70158):
    u -= 1.0
    return u * u * ((s + 1) * u + s) + 1.0


def _back_in(u, s=1.70158):
    return u * u * ((s + 1) * u - s)


EASES = {
    "linear": lambda u: u,
    "in2": lambda u: u * u,
    "in3": lambda u: u**3,
    "in4": lambda u: u**4,
    "in5": lambda u: u**5,
    "out2": lambda u: 1 - (1 - u) ** 2,
    "out3": lambda u: 1 - (1 - u) ** 3,
    "out4": lambda u: 1 - (1 - u) ** 4,
    "out5": lambda u: 1 - (1 - u) ** 5,
    "io2": lambda u: 2 * u * u if u < 0.5 else 1 - (-2 * u + 2) ** 2 / 2,
    "io3": lambda u: 4 * u**3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2,
    "io4": lambda u: 8 * u**4 if u < 0.5 else 1 - (-2 * u + 2) ** 4 / 2,
    "expo_out": lambda u: 1.0 if u >= 1 else 1 - 2 ** (-10 * u),
    "expo_in": lambda u: 0.0 if u <= 0 else 2 ** (10 * u - 10),
    "back_out": _back_out,
    "back_out_soft": lambda u: _back_out(u, 0.9),
    "back_in": _back_in,
    "sine_io": lambda u: -(math.cos(math.pi * u) - 1) / 2,
}


class Channel:

    __slots__ = ("keys",)

    def __init__(self):
        self.keys = []

    def add(self, frame, value, interp):
        self.keys = [k for k in self.keys if abs(k[0] - frame) > 1e-6]
        self.keys.append((float(frame), float(value), interp))
        self.keys.sort(key=lambda k: k[0])

    def _tangent(self, i):
        k = self.keys
        if i == 0 or i == len(k) - 1:
            return 0.0
        f0, v0, _ = k[i - 1]
        f1, v1, _ = k[i]
        f2, v2, _ = k[i + 1]
        d0 = (v1 - v0) / max(f1 - f0, 1e-6)
        d1 = (v2 - v1) / max(f2 - f1, 1e-6)
        if d0 * d1 <= 0:
            return 0.0
        return 2.0 / (1.0 / d0 + 1.0 / d1)

    def eval(self, frame):
        k = self.keys
        if not k:
            return None
        if frame <= k[0][0]:
            return k[0][1]
        if frame >= k[-1][0]:
            return k[-1][1]
        lo, hi = 0, len(k) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if k[mid][0] <= frame:
                lo = mid
            else:
                hi = mid
        f0, v0, mode = k[lo]
        f1, v1, _ = k[hi]
        span = max(f1 - f0, 1e-6)
        u = (frame - f0) / span
        if mode == "hold":
            return v0
        if mode == "smooth":
            m0 = self._tangent(lo) * span
            m1 = self._tangent(hi) * span
            u2, u3 = u * u, u * u * u
            return (2 * u3 - 3 * u2 + 1) * v0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * v1 + (u3 - u2) * m1
        ease = EASES[mode]
        return v0 + (v1 - v0) * ease(u)


class Timeline:

    def __init__(self, name, frame_start, frame_end):
        self.name = name
        self.frame_start = frame_start
        self.frame_end = frame_end
        self.channels = {}
        self.markers = []
        self.lag = {}
        self.noise = {}
        self.tremble = {}
        self.scarf_params = {}
        self.ik_parts = set()
        self.arm_sides = set()
        self.blade_ground_ok = []
        self.feet_world = False
        self.dual = False
        self.blade_hidden = False
        self.phases = []
        self.clamped_frames = []

    def ch(self, name):
        c = self.channels.get(name)
        if c is None:
            c = self.channels[name] = Channel()
        return c

    def wind(self, frame, x=0.0, y=0.0, z=0.0, interp="smooth"):
        for k, v in (("x", x), ("y", y), ("z", z)):
            self.ch(f"WIND.{k}").add(frame, v, interp)

    def fx(self, frame, interp="smooth", **values):
        for k, v in values.items():
            self.ch(f"NOISE.{k}").add(frame, v, interp)

    def key(self, frame, interp="smooth", parts=None, ik=None, root=None, overrides=None, arms=None):
        overrides = overrides or {}
        for k, v in (root or {}).items():
            self.ch(f"ROOT.{k}").add(frame, v, overrides.get("ROOT", interp))
        root = None
        parts = dict(parts or {})
        for part, vals in list(parts.items()):
            mode = overrides.get(part, interp)
            for i, v in enumerate(vals):
                if v is None:
                    continue
                self.ch(f"{part}.{CH[i]}").add(frame, v, mode)
        parts = {}
        for side, spec in (arms or {}).items():
            spec = dict(spec)
            space = spec.get("space", "root")
            grip_space = spec.get("grip_space", space)
            dir_space = spec.get("dir_space", space)
            ut = self.ut_frame(frame)
            inv = ut.inverted()
            rot_inv = ut.to_3x3().inverted()
            grip = Vector(spec["grip"])
            blade = Vector(spec["blade"])
            upv = Vector(spec.get("up", (0, 1, 0)))
            pole = Vector(spec["pole"]) if spec.get("pole") is not None else None
            if grip_space == "root":
                grip = inv @ grip
            if dir_space == "root":
                blade = rot_inv @ blade
                upv = rot_inv @ upv
                if pole is not None:
                    pole = rot_inv @ pole
            if pole is None:
                pole = default_pole(side)
            r_t = target_frame(blade, upv)
            _, _, _, err = solve_arm(side, grip, r_t, pole)
            if err > 0.05:
                ARM_WARNINGS.append(f"f{frame} {side} arm target out of reach by {err:.2f} studs")
            pre, S, *_ = _arm_consts(side)
            v = grip - S
            dist = v.length
            az = math.degrees(math.atan2(v.x, -v.z))
            el = math.degrees(math.asin(max(-1.0, min(1.0, v.y / max(dist, 1e-6)))))
            prev_az = self.channels.get(f"ARM.{side}.az")
            if prev_az is not None and prev_az.keys:
                ref = prev_az.eval(frame)
                while az - ref > 180:
                    az -= 360
                while az - ref < -180:
                    az += 360
            q = r_t.to_quaternion()
            qch = self.channels.get(f"ARM.{side}.qw")
            if qch is not None and qch.keys:
                pq = Quaternion([self.value(f"ARM.{side}.q{c}", frame) for c in "wxyz"])
                if pq.dot(q) < 0:
                    q = -q
            mode = overrides.get(f"ARM.{side}", overrides.get(f"{pre}UpperArm", interp))
            vals = {
                "az": az,
                "el": el,
                "dist": dist,
                "qw": q.w,
                "qx": q.x,
                "qy": q.y,
                "qz": q.z,
                "px": pole.x,
                "py": pole.y,
                "pz": pole.z,
            }
            for k, val in vals.items():
                self.ch(f"ARM.{side}.{k}").add(frame, val, mode)
            self.arm_sides.add(side)
        for part, vals in parts.items():
            mode = overrides.get(part, interp)
            for i, v in enumerate(vals):
                if v is None:
                    continue
                self.ch(f"{part}.{CH[i]}").add(frame, v, mode)
        for side, spec in (ik or {}).items():
            mode = overrides.get(f"IK.{side}", interp)
            spec = dict(spec)
            if self.feet_world and spec.pop("world", False):
                pass
            elif self.feet_world and spec.pop("pin", False):
                for k in ("x", "z", "yaw"):
                    spec[k] = self.value(f"IK.{side}.{k}", frame)
            elif self.feet_world and ("x" in spec or "z" in spec):
                rw = self.root_world(frame)
                x = spec.get("x", -0.5 if side == "L" else 0.5)
                z = spec.get("z", 0.0)
                pw = rw @ Vector((x, 0.0, z))
                spec["x"], spec["z"] = pw.x, pw.z
                spec["yaw"] = spec.get("yaw", 0.0) + self.value("ROOT.yaw", frame)
            for k, v in spec.items():
                self.ch(f"IK.{side}.{k}").add(frame, v, mode)
            self.ik_parts.add(side)

    def ut_frame(self, frame):
        lt = rc.roblox_T(*[self.value(f"LowerTorso.{c}", frame) for c in CH])
        ut = rc.roblox_T(*[self.value(f"UpperTorso.{c}", frame) for c in CH])
        c0r, _, c1ri = joint_mats("LowerTorso")
        c0w, _, c1wi = joint_mats("UpperTorso")
        return c0r @ lt @ c1ri @ c0w @ ut @ c1wi

    def phase(self, name, start, end):
        self.phases.append((name, int(start), int(end)))

    def marker(self, frame, name, value=""):
        self.markers.append((int(frame), name, value))

    def value(self, name, frame, default=0.0):
        c = self.channels.get(name)
        if c is None:
            return default
        v = c.eval(frame)
        return default if v is None else v

    def part_vals(self, part, frame):
        f = frame - self.lag.get(part, 0.0)
        vals = [self.value(f"{part}.{c}", f) for c in CH]
        amp = self.noise.get(part, 0.0) * self.value("NOISE.gain", frame, 1.0)
        if amp:
            seed = (sum(ord(ch) for ch in part) % 97) * 0.37
            for i in range(3):
                vals[i] += amp * (
                    0.6 * math.sin(frame * 0.071 + seed * (i + 1))
                    + 0.4 * math.sin(frame * 0.153 + seed * 2.3 * (i + 2))
                )
        trem = self.value("NOISE.tremble", frame, 0.0) * self.tremble.get(part, 0.0)
        if trem:
            seed = (sum(ord(ch) for ch in part) % 89) * 0.53
            for i in range(3):
                vals[i] += trem * math.sin(frame * 2.1 + seed * (i + 1.7)) * (0.7 + 0.3 * math.sin(frame * 0.9 + i))
        return vals

    def root_world(self, frame):
        x = self.value("ROOT.x", frame)
        y = self.value("ROOT.y", frame)
        z = self.value("ROOT.z", frame)
        yaw = self.value("ROOT.yaw", frame)
        return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Y")


_JOINTS = {}


def joint_mats(name):
    j = _JOINTS.get(name)
    if j is None:
        c0, c1 = rc.joint_c0_c1(name)
        j = _JOINTS[name] = (rc.cf_to_mat(c0), rc.cf_to_mat(c1), rc.cf_to_mat(c1).inverted())
    return j


def fk(Ts, root=None):
    world = {"HumanoidRootPart": root.copy() if root is not None else Matrix.Identity(4)}
    for name, parent, *_ in rc.R15_PARTS[1:]:
        c0, _c1, c1i = joint_mats(name)
        world[name] = world[parent] @ c0 @ Ts.get(name, Matrix.Identity(4)) @ c1i
    return world


def joint_world(world, name):
    parent = rc.PART_BY_NAME[name][1]
    c0, _, _ = joint_mats(name)
    return world[parent] @ c0


L_THIGH = (Vector(rc.PART_BY_NAME["LeftLowerLeg"][4]) - Vector(rc.PART_BY_NAME["LeftUpperLeg"][4])).length
L_SHIN = (Vector(rc.PART_BY_NAME["LeftFoot"][4]) - Vector(rc.PART_BY_NAME["LeftLowerLeg"][4])).length
ANKLE_Y = rc.PART_BY_NAME["LeftFoot"][4][1]


def solve_leg(world, side, target, yaw_deg, pitch_deg, knee_out_deg):
    pre = "Left" if side == "L" else "Right"
    hip_frame = joint_world(world, f"{pre}UpperLeg")
    h = hip_frame.to_translation()
    a = Vector(target)
    d = a - h
    length = d.length
    reach = (L_THIGH + L_SHIN) * 0.9995
    if length > reach:
        d = d.normalized() * reach
        length = reach
    length = max(length, 0.35)
    dn = d.normalized()
    out = knee_out_deg if side == "R" else -knee_out_deg
    f = Matrix.Rotation(math.radians(yaw_deg - out), 3, "Y") @ Vector((0, 0, -1))
    fp = f - dn * f.dot(dn)
    if fp.length < 1e-6:
        fp = Vector((0, 0, -1))
    fp.normalize()
    cos_a = (L_THIGH**2 + length**2 - L_SHIN**2) / (2 * L_THIGH * length)
    alpha = math.acos(max(-1.0, min(1.0, cos_a)))
    thigh = dn * math.cos(alpha) + fp * math.sin(alpha)
    knee = h + thigh * L_THIGH
    shin = (h + d - knee).normalized()
    y = -thigh
    zf = f - y * f.dot(y)
    z = -zf.normalized()
    x = y.cross(z)
    r_hip_w = Matrix((x, y, z)).transposed()
    s_local = r_hip_w.inverted() @ shin
    theta = math.atan2(-s_local.z, -s_local.y)
    r_knee = Matrix.Rotation(theta, 3, "X")
    shin_w = r_hip_w @ r_knee
    foot_w = Matrix.Rotation(math.radians(yaw_deg), 3, "Y") @ Matrix.Rotation(math.radians(pitch_deg), 3, "X")
    r_ankle = shin_w.inverted() @ foot_w
    parent_rot = hip_frame.to_3x3()
    r_hip = parent_rot.inverted() @ r_hip_w
    return r_hip.to_4x4(), r_knee.to_4x4(), r_ankle.to_4x4()


ARM_WARNINGS = []


def _arm_consts(side):
    pre = "Left" if side == "L" else "Right"
    ut_c = Vector(rc.PART_BY_NAME["UpperTorso"][2])
    s = Vector(rc.PART_BY_NAME[f"{pre}UpperArm"][4])
    e = Vector(rc.PART_BY_NAME[f"{pre}LowerArm"][4])
    w = Vector(rc.PART_BY_NAME[f"{pre}Hand"][4])
    grip = Vector(rc.PART_BY_NAME["EmberBlade"][4]) if side == "R" else Vector((-1.5, -0.88, 0.0))
    return pre, s - ut_c, e - s, w - e, grip - w


def target_frame(blade, up):
    bd = Vector(blade).normalized()
    upv = Vector(up)
    z = -bd
    y = upv - z * upv.dot(z)
    if y.length < 1e-5:
        y = Vector((0, 0, 1)) - z * z.z
    y.normalize()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed()


def default_pole(side):
    return Vector((0.6 if side == "R" else -0.6, -1.0, 0.5))


def solve_arm(side, grip, r_t, pole):
    pre, S, u1, u2, g_off = _arm_consts(side)
    l2 = u2.length
    l1 = u1.length
    P = Vector(grip) - r_t @ g_off
    d_vec = P - S
    D = d_vec.length
    k = -u1.y
    cos_t = (D * D - l1 * l1 - l2 * l2) / (2 * l2 * k)
    cos_t = max(math.cos(math.radians(155)), min(1.0, cos_t))
    theta = math.acos(cos_t)
    v = u1 + Vector((0, -math.cos(theta), -math.sin(theta))) * l2
    a_l = v.normalized()
    c_l = Vector((0, 0, 1)) - a_l * a_l.z
    c_l = c_l.normalized() if c_l.length > 1e-6 else Vector((1, 0, 0))
    d_l = a_l.cross(c_l)
    b = d_vec.normalized() if D > 1e-6 else -a_l
    p = Vector(pole)
    p_p = p - b * p.dot(b)
    back = Vector((0, 0, 1)) - b * b.z
    if back.length < 1e-6:
        back = Vector((1.0 if side == "R" else -1.0, 0, 0))
    lim = 0.3 * max(p.length, 1e-6)
    if p_p.length < lim:
        w = p_p.length / lim
        p_p = p_p.normalized() * w + back.normalized() * (1.0 - w) if p_p.length > 1e-9 else back
    c_w = p_p.normalized()
    d_w = b.cross(c_w)
    r1 = Matrix((b, c_w, d_w)).transposed() @ Matrix((a_l, c_l, d_l))
    r_el = Matrix.Rotation(theta, 3, "X")
    r_w = (r1 @ r_el).inverted() @ r_t
    err = abs(D - v.length)
    return r1, r_el, r_w, err


def arm_aim(side, grip, blade, up=(0, 1, 0), pole=None, compat=None):
    pre, S, u1, u2, g_off = _arm_consts(side)
    l1, l2 = u1.length, u2.length
    bd = Vector(blade).normalized()
    upv = Vector(up)
    z = -bd
    y = upv - z * upv.dot(z)
    if y.length < 1e-5:
        y = Vector((0, 0, 1)) - z * z.z
    y.normalize()
    x = y.cross(z)
    r_t = Matrix((x, y, z)).transposed()
    P = Vector(grip) - r_t @ g_off
    d_vec = P - S
    D = d_vec.length
    k = -u1.y
    cos_t = (D * D - l1 * l1 - l2 * l2) / (2 * l2 * k)
    cos_t = max(math.cos(math.radians(155)), min(1.0, cos_t))
    theta = math.acos(cos_t)
    f = Vector((0, -math.cos(theta), -math.sin(theta)))
    v = u1 + f * l2
    b = d_vec.normalized()
    q_align = v.normalized().rotation_difference(b)
    e = q_align @ u1
    if pole is None:
        pole = (0.6 if side == "R" else -0.6, -1.0, 0.5)
    p = Vector(pole)
    e_p = e - b * e.dot(b)
    p_p = p - b * p.dot(b)
    if e_p.length > 1e-6 and p_p.length > 1e-6:
        e_p.normalize()
        p_p.normalize()
        ang = math.atan2(e_p.cross(p_p).dot(b), max(-1.0, min(1.0, e_p.dot(p_p))))
        q_sw = Quaternion(b, ang)
    else:
        q_sw = Quaternion()
    r1 = (q_sw @ q_align).to_matrix()
    reach_err = abs(D - (u1 + f * l2).length)
    if reach_err > 0.05:
        ARM_WARNINGS.append(
            f"{side} arm target out of reach by {reach_err:.2f} studs (grip={tuple(round(c, 2) for c in grip)})"
        )
    r_el = Matrix.Rotation(theta, 3, "X")
    r_w = (r1 @ r_el).inverted() @ r_t
    out = {}
    for part, rot in ((f"{pre}UpperArm", r1), (f"{pre}LowerArm", r_el), (f"{pre}Hand", r_w)):
        cmp = None
        if compat and part in compat:
            cmp = Euler([math.radians(a) for a in compat[part][:3]], "ZYX")
        eu = rot.to_euler("ZYX", cmp) if cmp else rot.to_euler("ZYX")
        out[part] = (math.degrees(eu.x), math.degrees(eu.y), math.degrees(eu.z))
    return out


def _blend_T(a, b, w):
    if w <= 0.0:
        return a
    if w >= 1.0:
        return b
    qa, qb = a.to_quaternion(), b.to_quaternion()
    q = qa.slerp(qb, w)
    t = a.to_translation().lerp(b.to_translation(), w)
    return Matrix.Translation(t) @ q.to_matrix().to_4x4()


SCARF = ("Scarf1", "Scarf2", "Scarf3", "Scarf4")


class ScarfSim:
    def __init__(self, gravity=38.0, drag=2.6, stiffness=0.0, substeps=6, iters=8):
        self.gravity = gravity
        self.drag = drag
        self.stiffness = stiffness
        self.substeps = substeps
        self.iters = iters
        self.lengths = []
        pivots = [Vector(rc.PART_BY_NAME[n][4]) for n in SCARF]
        tip = pivots[-1] + Vector((0, -0.8, 0))
        pts = pivots + [tip]
        for i in range(len(pts) - 1):
            self.lengths.append((pts[i + 1] - pts[i]).length)
        self.p = None
        self.pp = None
        self.anchor_local_y = pivots[0].y - rc.PART_BY_NAME["UpperTorso"][2][1]

    def _local_rest(self):
        pivots = [Vector(rc.PART_BY_NAME[n][4]) for n in SCARF]
        return pivots + [pivots[-1] + Vector((0, -0.8, 0))]

    def reset(self, ut_world):
        ut_c = Vector(rc.PART_BY_NAME["UpperTorso"][2])
        pts = [ut_world @ (p - ut_c) for p in self._local_rest()]
        self.p = [v.copy() for v in pts]
        self.pp = [v.copy() for v in pts]

    def step(self, ut_world, dt, wind=None):
        ut_c = Vector(rc.PART_BY_NAME["UpperTorso"][2])
        rest = self._local_rest()
        anchor = ut_world @ (rest[0] - ut_c)
        inv = ut_world.inverted()
        sub = dt / self.substeps
        self._t = getattr(self, "_t", 0.0) + dt
        prev_anchor = self.p[0].copy()
        for s in range(self.substeps):
            a_now = prev_anchor.lerp(anchor, (s + 1) / self.substeps)
            self.p[0] = a_now
            self.pp[0] = a_now
            for i in range(1, len(self.p)):
                v = (self.p[i] - self.pp[i]) * max(0.0, 1.0 - self.drag * sub)
                self.pp[i] = self.p[i].copy()
                acc = Vector((0, -self.gravity, 0))
                if wind is not None:
                    acc += wind * (0.75 + 0.25 * math.sin(self._t * 23.0 + i * 1.7))
                if self.stiffness:
                    target = ut_world @ (rest[i] - ut_c)
                    acc += (target - self.p[i]) * self.stiffness
                self.p[i] = self.p[i] + v + acc * sub * sub
            for _ in range(self.iters):
                for i in range(len(self.p) - 1):
                    a, b = self.p[i], self.p[i + 1]
                    delta = b - a
                    dist = max(delta.length, 1e-6)
                    corr = delta * ((dist - self.lengths[i]) / dist)
                    if i == 0:
                        self.p[i + 1] = b - corr
                    else:
                        self.p[i] = a + corr * 0.5
                        self.p[i + 1] = b - corr * 0.5
                for i in range(1, len(self.p)):
                    lp = inv @ self.p[i]
                    changed = False
                    min_z = 0.56 if lp.y > -2.4 else 0.35
                    if lp.z < min_z:
                        lp.z = min_z
                        changed = True
                    max_y = self.anchor_local_y + 0.35
                    if lp.y > max_y:
                        lp.y = max_y
                        changed = True
                    if changed:
                        self.p[i] = ut_world @ lp

    def joint_Ts(self, world_ut):
        Ts = {}
        parent_rot = world_ut.to_3x3()
        for i, name in enumerate(SCARF):
            d_world = (self.p[i + 1] - self.p[i]).normalized()
            d_local = parent_rot.inverted() @ d_world
            q = Vector((0, -1, 0)).rotation_difference(d_local)
            r = q.to_matrix()
            Ts[name] = r.to_4x4()
            parent_rot = parent_rot @ r
        return Ts


_TIP_LOCAL = Vector((0.0, 0.0, -2.5))
_BLADE_C = Vector(rc.PART_BY_NAME["EmberBlade"][2])


def _tip_y(world, root_inv):
    return (root_inv @ (world["EmberBlade"] @ _TIP_LOCAL)).y


def _tip_y_of(world, root_inv, blade):
    return (root_inv @ (world[blade] @ _TIP_LOCAL)).y


def _blade_floor_clamp(Ts, world, root, floor=rc.FLOOR_Y + 0.02, blades=(("EmberBlade", "RightHand"),)):
    root_inv = root.inverted()
    changed = False
    for blade, hand in blades:
        if _tip_y_of(world, root_inv, blade) >= floor:
            continue
        base = Ts[hand]
        best = None
        for step in range(1, 91):
            for sgn in (1, -1):
                Ts[hand] = base @ Matrix.Rotation(math.radians(step * sgn), 4, "X")
                w = fk(Ts, root)
                if _tip_y_of(w, root_inv, blade) >= floor:
                    best = Ts[hand]
                    break
            if best is not None:
                break
        Ts[hand] = best if best is not None else base
        changed = changed or best is not None
        world = fk(Ts, root)
    return changed


HALF = {p[0]: Vector(p[3]) * 0.5 for p in rc.R15_PARTS}
BODY_VOLUMES = ("UpperTorso", "LowerTorso", "Head", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg")
ARM_AVOID = (
    ("UpperArm", ("LowerTorso", "LeftUpperLeg", "RightUpperLeg")),
    ("LowerArm", BODY_VOLUMES),
    ("Hand", BODY_VOLUMES),
)
WRIST_TWIST = 150.0
WRIST_SWING = 110.0
CONTACT_MARGIN = 0.03


def _box(world, name):
    m = world[name]
    return m.to_translation(), [m.col[i].xyz.normalized() for i in range(3)], HALF[name]


def _mtv(a, b):
    ca, aa, ha = a
    cb, ab, hb = b
    d = ca - cb
    axes = list(aa) + list(ab)
    for u in aa:
        for v in ab:
            w = u.cross(v)
            if w.length > 1e-3:
                axes.append(w.normalized())
    best = None
    for axis in axes:
        ra = sum(h * abs(x.dot(axis)) for h, x in zip(ha, aa))
        rb = sum(h * abs(x.dot(axis)) for h, x in zip(hb, ab))
        dist = d.dot(axis)
        o = ra + rb - abs(dist)
        if o <= 0:
            return None
        if best is None or o < best[0]:
            best = (o, axis if dist >= 0 else -axis)
    return best


def _wrist_limits(r_el, r_w, prev):
    q = r_w.to_quaternion()
    tw = Quaternion((q.w, 0.0, q.y, 0.0))
    if tw.magnitude < 1e-6:
        tw = Quaternion()
    tw.normalize()
    swing = q @ tw.inverted()
    ang = math.degrees(2.0 * math.atan2(tw.y, tw.w))
    if prev is not None:
        while ang - prev > 180.0:
            ang -= 360.0
        while ang - prev < -180.0:
            ang += 360.0
    raw = ang
    ang = max(-WRIST_TWIST, min(WRIST_TWIST, ang))
    axis, sw = swing.to_axis_angle()
    if math.degrees(sw) > WRIST_SWING:
        swing = Quaternion(axis, math.radians(WRIST_SWING))
    half = Matrix.Rotation(math.radians(ang * 0.5), 3, "Y")
    full = swing.to_matrix() @ Matrix.Rotation(math.radians(ang), 3, "Y")
    return r_el @ half, half.inverted() @ full, raw


PUSH_MAX = 0.8
REACH_GUARD = 0.96


def _pose_arm(side, g, r_t, pole, Ts, base, twist_prev):
    pre = "Left" if side == "L" else "Right"
    r1, r_el, r_w, _ = solve_arm(side, g, r_t, pole)
    r_el, r_w, twist = _wrist_limits(r_el, r_w, twist_prev)
    for n, rot in zip((f"{pre}UpperArm", f"{pre}LowerArm", f"{pre}Hand"), (r1, r_el, r_w)):
        Ts[n] = rot.to_4x4() @ base[n]
    return fk(Ts, Matrix.Identity(4)), twist


def _worst_contact(world, pre):
    worst = None
    for seg, bodies in ARM_AVOID:
        box = _box(world, pre + seg)
        for b in bodies:
            hit = _mtv(box, _box(world, b))
            if hit and (worst is None or hit[0] > worst[0]):
                worst = (hit[0], hit[1], seg, box[0])
    return worst


def _reach_limit(side, grip, r_t, push):
    _, S, u1, u2, g_off = _arm_consts(side)
    limit = (u1.length + u2.length) * REACH_GUARD
    for _ in range(12):
        d = (grip + push - r_t @ g_off - S).length
        if d <= limit or push.length < 1e-4:
            break
        push = push * 0.8
    return push


def _arm_solve(side, grip, r_t, pole, Ts, push, twist_prev, estimate=False):
    pre = "Left" if side == "L" else "Right"
    names = (f"{pre}UpperArm", f"{pre}LowerArm", f"{pre}Hand")
    base = {n: Ts[n] for n in names}
    if not estimate:
        _, twist = _pose_arm(side, grip + push, r_t, pole, Ts, base, twist_prev)
        return twist
    added = Vector()
    for _ in range(8):
        world, _ = _pose_arm(side, grip + push + added, r_t, pole, Ts, base, None)
        worst = _worst_contact(world, pre)
        if worst is None or worst[0] < 0.01:
            break
        depth, axis, seg, center = worst
        to_ut = world["UpperTorso"].to_3x3().inverted()
        if seg == "Hand":
            d = to_ut @ axis
        else:
            c = world["UpperTorso"].inverted() @ center
            d = Vector((c.x, 0.0, c.z))
            if d.length < 1e-3:
                d = Vector((1.0 if side == "R" else -1.0, 0.0, 0.0))
            d.normalize()
        added += d * (depth + CONTACT_MARGIN)
        if (push + added).length > PUSH_MAX:
            added = (push + added).normalized() * PUSH_MAX - push
            break
    return _reach_limit(side, grip, r_t, push + added) - push


def _smooth_pushes(rows, radius=6, sigma=3.0):
    n = len(rows)
    dil = []
    for i in range(n):
        lo, hi = max(0, i - radius), min(n, i + radius + 1)
        dil.append(max(rows[lo:hi], key=lambda v: v.length))
    w = [math.exp(-(k * k) / (2 * sigma * sigma)) for k in range(-radius, radius + 1)]
    out = []
    for i in range(n):
        acc, tot = Vector(), 0.0
        for k, wk in zip(range(-radius, radius + 1), w):
            j = i + k
            if 0 <= j < n:
                acc += dil[j] * wk
                tot += wk
        out.append(acc / tot)
    return out


def _body_pose(tl, fe):
    Ts = {}
    for part in rc.ANIMATED_PARTS:
        if part in SCARF:
            continue
        rx, ry, rz, tx, ty, tz = tl.part_vals(part, fe)
        Ts[part] = rc.roblox_T(rx, ry, rz, tx, ty, tz)
    root = tl.root_world(fe)
    world = fk(Ts, Matrix.Identity(4))
    for side in ("L", "R"):
        if side not in tl.ik_parts:
            continue
        w = tl.value(f"IK.{side}.w", fe, 1.0)
        if w <= 0:
            continue
        pre = "Left" if side == "L" else "Right"
        x = tl.value(f"IK.{side}.x", fe, -0.5 if side == "L" else 0.5)
        z = tl.value(f"IK.{side}.z", fe, 0.0)
        lift = tl.value(f"IK.{side}.lift", fe, 0.0)
        yaw = tl.value(f"IK.{side}.yaw", fe, 0.0)
        pitch = tl.value(f"IK.{side}.pitch", fe, 0.0)
        kout = tl.value(f"IK.{side}.knee_out", fe, 6.0)
        if tl.feet_world:
            ph = root.inverted() @ Vector((x, 0.0, z))
            x, z = ph.x, ph.z
            yaw = yaw - tl.value("ROOT.yaw", fe)
        th, tk, ta = solve_leg(world, side, (x, ANKLE_Y + lift, z), yaw, pitch, kout)
        Ts[f"{pre}UpperLeg"] = _blend_T(Ts[f"{pre}UpperLeg"], th, w)
        Ts[f"{pre}LowerLeg"] = _blend_T(Ts[f"{pre}LowerLeg"], tk, w)
        Ts[f"{pre}Foot"] = _blend_T(Ts[f"{pre}Foot"], ta, w)
    return Ts, root


def _arm_controls(tl, side, fe):
    pre = "Left" if side == "L" else "Right"
    _, S, *_ = _arm_consts(side)
    fp = fe - tl.lag.get(f"{pre}UpperArm", 0.0)
    fo = fe - tl.lag.get(f"{pre}Hand", 0.0)
    az = math.radians(tl.value(f"ARM.{side}.az", fp))
    el = math.radians(tl.value(f"ARM.{side}.el", fp))
    dist = tl.value(f"ARM.{side}.dist", fp)
    grip = S + Vector((math.cos(el) * math.sin(az), math.sin(el), -math.cos(el) * math.cos(az))) * dist
    q = Quaternion([tl.value(f"ARM.{side}.q{c}", fo) for c in "wxyz"]).normalized()
    pole = Vector([tl.value(f"ARM.{side}.p{c}", fp) for c in "xyz"])
    return grip, q.to_matrix(), pole


def evaluate(tl, fps=rc.SCENE_FPS):
    warm = 45
    frame_list = list(range(tl.frame_start - warm, tl.frame_end + 1))
    sides = sorted(tl.arm_sides)

    pushes = {s: [Vector() for _ in frame_list] for s in sides}
    for _ in range(2):
        extra = {s: [] for s in sides}
        for i, f in enumerate(frame_list):
            fe = max(f, tl.frame_start)
            Ts, _ = _body_pose(tl, fe)
            for side in sides:
                grip, r_t, pole = _arm_controls(tl, side, fe)
                extra[side].append(_arm_solve(side, grip, r_t, pole, Ts, pushes[side][i], None, estimate=True))
        for side in sides:
            pushes[side] = [a + b for a, b in zip(pushes[side], _smooth_pushes(extra[side]))]
    tl.arm_push = {s: [round(v.length, 3) for v in pushes[s][warm:]] for s in sides}

    frames = []
    scarf = ScarfSim(**tl.scarf_params) if tl.scarf_params is not None else None
    dt = 1.0 / fps
    twist = {s: None for s in sides}
    for i, f in enumerate(frame_list):
        fe = max(f, tl.frame_start)
        Ts, root = _body_pose(tl, fe)
        for side in sides:
            grip, r_t, pole = _arm_controls(tl, side, fe)
            twist[side] = _arm_solve(side, grip, r_t, pole, Ts, pushes[side][i], twist[side])
        world = fk(Ts, root)
        if not any(lo <= fe <= hi for lo, hi in tl.blade_ground_ok):
            blades = (
                (("EmberBlade", "RightHand"), ("AzureBlade", "LeftHand")) if tl.dual else (("EmberBlade", "RightHand"),)
            )
            fixed = False if tl.blade_hidden else _blade_floor_clamp(Ts, world, root, blades=blades)
            if fixed:
                tl.clamped_frames.append(fe)
                world = fk(Ts, root)
        if scarf is not None:
            ut = world["UpperTorso"]
            if scarf.p is None:
                scarf.reset(ut)
            wind = Vector((tl.value("WIND.x", fe), tl.value("WIND.y", fe), tl.value("WIND.z", fe)))
            scarf.step(ut, dt, wind if wind.length > 1e-3 else None)
            Ts.update(scarf.joint_Ts(ut))
            world = fk(Ts, root)
        else:
            for n in SCARF:
                Ts[n] = Matrix.Identity(4)
        if f >= tl.frame_start:
            frames.append({"frame": f, "T": Ts, "root": root, "world": world})
    return frames


def bake_to_action(ao, tl, frames, action_name):
    import bpy

    if ao.animation_data is None:
        ao.animation_data_create()
    old = bpy.data.actions.get(action_name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(action_name)
    act.use_fake_user = True
    ao.animation_data.action = act
    prev_q = {}
    for fr in frames:
        f = fr["frame"]
        for part, T in fr["T"].items():
            pb = ao.pose.bones[part]
            basis = rc.basis_from_roblox_T(pb, T)
            loc, q, _ = basis.decompose()
            pq = prev_q.get(part)
            if pq is not None and pq.dot(q) < 0:
                q = -q
            prev_q[part] = q
            pb.location = loc
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=f, group=part)
            pb.keyframe_insert("rotation_quaternion", frame=f, group=part)
        from roblox_animations.core.constants import get_transform_to_blender

        t2b = get_transform_to_blender()
        ao.matrix_world = t2b @ fr["root"] @ t2b.inverted()
        ao.keyframe_insert("location", frame=f, group="ROOT_MOTION_PREVIS")
        ao.keyframe_insert("rotation_euler", frame=f, group="ROOT_MOTION_PREVIS")
    from roblox_animations.core.utils import get_action_fcurves

    for fc in get_action_fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    for fr_, name, value in tl.markers:
        m = act.pose_markers.new(name)
        m.frame = fr_
    act.frame_range = (tl.frame_start, tl.frame_end)
    act["rbx_markers"] = [{"frame": f, "name": n, "value": v} for f, n, v in tl.markers]
    return act


def keys_to_sparse_action(ao, tl, action_name):
    import bpy

    old = bpy.data.actions.get(action_name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(action_name)
    act.use_fake_user = True
    frames = sorted({int(k[0]) for c in tl.channels.values() for k in c.keys})
    import json

    act["rbx_key_frames"] = frames
    act["rbx_channels_json"] = json.dumps(
        {name: [[k[0], round(k[1], 4), k[2]] for k in c.keys] for name, c in tl.channels.items()}
    )
    return act
