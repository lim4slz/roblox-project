"""Pose base (stance) e ajudantes de coluna usados pelas habilidades."""

import math

from mathutils import Matrix, Vector

STANCE_FEET = {
    "L": dict(x=-0.72, z=0.45, yaw=22.0, lift=0.0, pitch=0.0, knee_out=8.0, w=1.0),
    "R": dict(x=0.58, z=-0.5, yaw=-8.0, lift=0.0, pitch=0.0, knee_out=6.0, w=1.0),
}

STANCE_BODY = {
    "LowerTorso": (0.0, 10.0, 0.0, 0.0, -0.35, 0.0),
    "UpperTorso": (-6.0, -14.0, 0.0),
    "Head": (3.0, 5.0, 0.0),
    "EmberBlade": (0.0, 0.0, 0.0),
}

STANCE_ARMS = {
    "R": dict(grip=(1.0, -0.75, -0.9), blade=(-0.3, 0.45, -1.0), up=(0.0, 1.0, 0.5)),
    "L": dict(grip=(-0.95, -0.4, -0.8), blade=(0.25, 0.1, -1.0), up=(0.0, 1.0, 0.0), pole=(-0.6, -1.0, 0.6)),
}


def sag_spine(blade, sign=1.0):
    return tuple(Matrix.Rotation(math.radians(90.0 * sign), 3, "X") @ Vector(blade))


def hor_spine(blade, sign=1.0):
    return tuple(Matrix.Rotation(math.radians(-90.0 * sign), 3, "Y") @ Vector(blade))


def stance_key(tl, frame, interp="smooth", root=None):
    tl.key(
        frame,
        interp,
        parts=dict(STANCE_BODY),
        ik={k: dict(v) for k, v in STANCE_FEET.items()},
        arms={k: dict(v) for k, v in STANCE_ARMS.items()},
        root=root,
    )


def feet(l=None, r=None, **common):
    out = {}
    for side, spec in (("L", l), ("R", r)):
        if spec is None:
            continue
        d = dict(STANCE_FEET[side])
        d.update(common)
        d.update(spec)
        out[side] = d
    return out
