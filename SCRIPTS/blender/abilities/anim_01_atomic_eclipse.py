"""
ANIM_01 ATOMIC ECLIPSE (32 s, 60 fps). Inspirado em "I Am Atomic" (The Eminence in Shadow),
com nome e execução próprios: calma, o mundo escurece, tudo é comprimido num ponto,
silêncio e a explosão atômica com o conjurador no olho dela.

  SHADOW_WALK  0-360     caminhada lenta arrastando a lâmina, circuitos e sigilos a cada passo
  AWAKENING    360-720   energia converge de 34 studs, três círculos no chão, pedras sobem, levita
  SINGULARITY  720-1176  halo de eclipse, hélices, orbes, a lâmina vira energia, implosão e silêncio
  ATOMIC       1176-1500 flash, esfera atômica, ondas de choque, entulho, coluna e cogumelo
  AFTERMATH    1500-1920 cinzas, a lâmina volta, pousa, olha em volta e sacode a lâmina
"""

import anim_engine as ae
from moves import DANGLE, DANGLE_B, F, PIN, Ctx, walk
from vfx_cues import (
    animate,
    cue,
    distort,
    emit,
    fade,
    fade_in_out,
    flash,
    grow,
    highlight,
    light,
    lightning,
    part,
    ring,
    screen,
    shake,
    special,
)

META = dict(
    id="ANIM_01",
    name="ANIM_01_ATOMIC_ECLIPSE",
    inspired_by="I Am Atomic — The Eminence in Shadow",
    concept="Caminhada calma, compressão de toda a magia em um ponto e explosão atômica centrada no conjurador",
    camera=dict(
        loc=(9.0, 13.0, 0.5),
        target=(0.0, 2.0, -0.5),
        lens=26,
        keys=[
            dict(frame=0, loc=(9.0, 13.0, 0.5), target=(0.0, 2.0, -0.5), lens=26),
            dict(frame=330, loc=(8.0, 17.0, 0.8), target=(0.0, 6.5, -0.2), lens=28),
            dict(frame=700, loc=(12.0, 20.0, 1.5), target=(0.0, 6.5, 1.0), lens=24),
            dict(frame=1000, loc=(6.0, 13.5, 2.8), target=(0.0, 6.5, 2.3), lens=35),
            dict(frame=1170, loc=(5.5, 12.5, 2.9), target=(0.0, 6.5, 2.5), lens=40),
            dict(frame=1178, loc=(72.0, 92.0, 8.0), target=(0.0, 6.5, 30.0), lens=24, cut=True),
            dict(frame=1330, loc=(60.0, 78.0, 11.0), target=(0.0, 6.5, 32.0), lens=24),
            dict(frame=1470, loc=(40.0, 54.0, 7.0), target=(0.0, 6.5, 14.0), lens=26),
            dict(frame=1471, loc=(13.0, 22.0, 2.6), target=(0.0, 6.5, 2.6), lens=26, cut=True),
            dict(frame=1560, loc=(12.0, 21.0, 2.0), target=(0.0, 6.5, 1.6), lens=26),
            dict(frame=1640, loc=(10.0, 18.0, 0.8), target=(0.0, 6.5, -0.4), lens=28),
            dict(frame=1920, loc=(9.0, 16.5, 0.6), target=(0.0, 6.5, -0.4), lens=28),
        ],
    ),
    video_step=2,
)

R_LOW = dict(grip=(1.4, -0.9, 0.2), blade=(0.25, -0.45, 1.0), up=(0, 1, 0))  # blade dragging behind


def build():
    tl = ae.Timeline(META["name"], 0, 1920)
    tl.lag = {
        "UpperTorso": 1.0,
        "Head": 3.0,
        "RightUpperArm": 1.0,
        "RightLowerArm": 2.0,
        "RightHand": 3.0,
        "LeftUpperArm": 1.2,
        "LeftLowerArm": 2.4,
        "LeftHand": 3.6,
        "LeftUpperLeg": 2.0,
        "LeftLowerLeg": 3.5,
        "LeftFoot": 5.0,
        "RightUpperLeg": 2.5,
        "RightLowerLeg": 4.0,
        "RightFoot": 5.5,
    }
    tl.noise = {"UpperTorso": 0.4, "Head": 0.6, "LowerTorso": 0.3, "LeftUpperArm": 0.5, "RightUpperArm": 0.4}
    tl.tremble = {
        "UpperTorso": 0.5,
        "Head": 0.4,
        "LeftUpperArm": 0.9,
        "LeftLowerArm": 1.0,
        "LeftHand": 1.3,
        "RightUpperArm": 0.8,
        "RightLowerArm": 0.9,
    }
    tl.scarf_params = dict(gravity=36.0, drag=3.0, stiffness=8.0)
    c = Ctx(tl)
    tl.fx(0, gain=1.0, tremble=0.0)
    tl.wind(0, z=6.0)

    # ---------------- P1 SHADOW WALK ----------------
    tl.phase("SHADOW_WALK", 0, 360)
    c.k(
        0,
        "smooth",
        lt=(0, 0, 0, 0, -0.3, 0),
        ut=(-4, 0, 0),
        head=(-10, 0, 0),
        blade=(0, 0, 0),
        arms={"R": dict(R_LOW), "L": dict(grip=(-1.2, -0.85, -0.2), blade=(0.1, -0.4, -1.0), up=(0, 1, 0))},
        feet=F(l=dict(x=-0.55, z=0.1, yaw=4), r=dict(x=0.55, z=-0.1, yaw=-4)),
    )
    c.root_key(0)
    tl.marker(2, "CAST_START")
    tl.marker(10, "CIRCUITS_START")
    t = walk(c, 24, steps=5, stride=1.3, step_frames=56, r_arm=R_LOW, sway=0.7)
    for i in range(5):
        tl.marker(24 + 56 * (i + 1) - 2, "STEP_SIGIL", str(i + 1))
    c.k(
        t + 20,
        "smooth",
        lt=(0, 0, 0, 0, -0.32, 0),
        ut=(-3, 0, 0),
        head=(-6, 0, 0),
        feet=F(l=dict(x=-0.58, z=0.15, yaw=6), r=dict(x=0.58, z=-0.1, yaw=-6)),
    )
    c.k(348, "smooth", head=(4, 0, 0), ut=(-1, 0, 0))
    tl.marker(350, "AWAKEN")

    # ---------------- P2 AWAKENING ----------------
    tl.phase("AWAKENING", 360, 720)
    c.k(
        420,
        "smooth",
        lt=(1, 2, 0, 0, -0.28, 0),
        ut=(2, 4, 0),
        head=(2, -4, 0),
        arms={
            "L": dict(grip=(-0.5, 0.0, -1.15), blade=(0.15, 0.2, -1.0), up=(0, 1, 0), space="ut", pole=(-0.9, -1, 0.4)),
            "R": dict(grip=(1.6, -0.85, 0.35), blade=(0.35, -0.4, 1.0), up=(0, 1, 0)),
        },
        feet=PIN,
    )
    tl.marker(420, "CONVERGE")
    tl.marker(430, "SIGIL_GROUND", "1")
    tl.marker(450, "DIM")
    tl.marker(520, "SIGIL_GROUND", "2")
    tl.marker(600, "SIGIL_GROUND", "3")
    tl.fx(420, tremble=0.0)
    c.k(
        520,
        "sine_io",
        lt=(2, -2, 0, 0, -0.3, 0),
        ut=(4, 2, 0),
        head=(6, 2, 0),
        arms={
            "L": dict(grip=(-0.45, 0.25, -1.2), blade=(0.1, 0.4, -1.0), up=(0, 1, 0), space="ut", pole=(-0.9, -1, 0.4))
        },
    )
    tl.fx(560, tremble=0.4)
    # levitation starts
    ch = tl.ch("LowerTorso.ty")
    ch.add(600, -0.3, "io3")
    ch.add(720, 0.7, "smooth")
    c.k(610, "smooth", feet={"L": {"pin": True, "w": 1.0}, "R": {"pin": True, "w": 1.0}})
    c.k(640, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}}, parts=dict(DANGLE))
    c.k(700, "smooth", lt=(4, 0, 0, 0, None, 0), ut=(8, 0, 0), head=(14, 0, 0))
    tl.wind(600, y=10.0, z=4.0)
    tl.marker(612, "LEVITATE")

    # ---------------- P3 SINGULARITY ----------------
    tl.phase("SINGULARITY", 720, 1176)
    ch.add(840, 2.6, "smooth")
    c.k(
        800,
        "smooth",
        parts=dict(DANGLE_B),
        lt=(6, 0, 0, 0, None, 0),
        ut=(10, 0, 0),
        head=(20, 0, 0),
        arms={
            "L": dict(
                grip=(-1.85, 0.35, -0.35), blade=(-0.3, 0.2, -1.0), up=(1.0, 0.1, 0.3), space="ut", pole=(-0.3, -1, 0.6)
            ),
            "R": dict(
                grip=(1.85, 0.35, -0.35), blade=(0.8, 0.55, 0.1), up=(-1.0, 0.1, 0.3), space="ut", pole=(0.3, -1, 0.6)
            ),
        },
    )
    tl.marker(760, "HALO")
    tl.marker(800, "HELIX")
    tl.marker(820, "ORBS")
    tl.fx(800, tremble=0.6)
    for i, (f, yv) in enumerate(((870, 14), (930, -12), (990, 6))):
        c.k(
            f,
            "sine_io",
            parts=dict(DANGLE if i % 2 == 0 else DANGLE_B),
            lt=(6 + i, yv, 0, 0, None, 0),
            ut=(11 + i, -yv * 0.4, 0),
            head=(22 + i, -yv * 0.3, 0),
            arms={
                "L": dict(
                    grip=(-1.82, 0.42 + 0.06 * i, -0.4),
                    blade=(-0.3, 0.25, -1.0),
                    up=(1.0, 0.1, 0.3),
                    space="ut",
                    pole=(-0.3, -1, 0.6),
                ),
                "R": dict(
                    grip=(1.82, 0.42 + 0.06 * i, -0.4),
                    blade=(0.8, 0.6, 0.1),
                    up=(-1.0, 0.1, 0.3),
                    space="ut",
                    pole=(0.3, -1, 0.6),
                ),
            },
        )
        tl.fx(f, tremble=1.0 + 0.7 * i)
    tl.marker(990, "CHARGE_PEAK")
    tl.marker(1000, "BLADE_DISSOLVE")
    tl.wind(990, y=18.0, z=2.0)
    # hands come together: compression
    c.k(
        1036,
        "in2",
        lt=(-4, 0, 0, 0, 2.7, 0),
        ut=(-10, 0, 0),
        head=(-8, 0, 0),
        arms={
            "R": dict(
                grip=(0.52, 0.05, -1.05), blade=(0.0, 1.0, 0.15), up=(0.75, -0.1, 0.65), space="ut", pole=(1, -0.8, 0.4)
            ),
            "L": dict(
                grip=(-0.52, 0.05, -1.05),
                blade=(0.0, 1.0, 0.15),
                up=(-0.75, -0.1, 0.65),
                space="ut",
                pole=(-1, -0.8, 0.4),
            ),
        },
    )
    tl.marker(1040, "IMPLODE")
    tl.fx(1030, tremble=2.8)
    tl.fx(1046, tremble=0.0, gain=0.15)
    tl.wind(1040, y=0.0, z=0.0)
    tl.marker(1060, "SILENCE")
    for k_, f in enumerate((1080, 1110, 1140)):
        tl.marker(f, "POINT_PULSE", str(k_ + 1))
    c.k(1140, "smooth", lt=(-4, 0, 0, 0, 2.72, 0), ut=(-10, 0, 0), head=(-10, 0, 0))
    # inhale
    c.k(
        1166,
        "in3",
        lt=(2, 0, 0, 0, 2.82, 0),
        ut=(-2, 0, 0),
        head=(6, 0, 0),
        arms={
            "L": dict(
                grip=(-0.55, 0.05, -1.15), blade=(0.0, 1.0, 0.1), up=(-0.6, -0.1, 0.8), space="ut", pole=(-1, -0.8, 0.4)
            )
        },
    )
    tl.fx(1160, gain=1.0)

    # ---------------- P4 ATOMIC ----------------
    tl.phase("ATOMIC", 1176, 1500)
    c.k(
        1176,
        "out4",
        lt=(-6, 14, 0, 0, 2.6, -0.2),
        ut=(-10, 18, -3),
        head=(6, -10, 0),
        arms={
            "L": dict(
                grip=(-0.7, 0.3, -1.6), blade=(0.0, 1.0, -0.2), up=(0, 0.2, 1.0), space="ut", pole=(-1, -0.3, 0.3)
            ),
            "R": dict(grip=(1.55, 0.1, 0.85), blade=(0.55, 0.45, 1.0), up=(0, 1, -0.5), space="ut"),
        },
    )
    tl.marker(1176, "RELEASE")
    tl.marker(1176, "WHITE_FLASH")
    tl.marker(1178, "NUKE")
    tl.marker(1182, "SHOCKWAVE", "1")
    tl.marker(1185, "DUST_WALL")
    tl.marker(1190, "DEBRIS")
    tl.marker(1200, "SHOCKWAVE", "2")
    tl.marker(1200, "COLUMN")
    tl.marker(1225, "SHOCKWAVE", "3")
    tl.marker(1240, "MUSHROOM")
    tl.fx(1178, tremble=1.6)
    tl.fx(1330, tremble=0.2)
    tl.wind(1176, z=0.0)
    tl.wind(1182, y=30.0, z=170.0)
    tl.wind(1300, y=10.0, z=60.0)
    tl.wind(1500, y=4.0, z=14.0)
    c.k(1200, "smooth", lt=(-3, 12, 0, 0, 2.62, -0.1), ut=(-2, 14, -2), head=(10, -8, 0), parts=dict(DANGLE_B))
    c.k(
        1320,
        "sine_io",
        lt=(0, 8, 0, 0, 2.55, 0),
        ut=(0, 8, 0),
        head=(4, -4, 0),
        parts=dict(DANGLE),
        arms={
            "L": dict(
                grip=(-0.6, 0.45, -1.5), blade=(0.0, 1.0, -0.3), up=(0, 0.3, 1.0), space="ut", pole=(-1, -0.6, 0.2)
            )
        },
    )
    c.k(
        1440,
        "sine_io",
        lt=(2, 4, 0, 0, 2.5, 0),
        ut=(2, 4, 0),
        head=(-2, 0, 0),
        parts=dict(DANGLE_B),
        arms={
            "L": dict(grip=(-0.9, 0.1, -1.25), blade=(0.1, 0.6, -0.8), up=(0, 0.4, 1.0), space="ut"),
            "R": dict(grip=(1.7, -0.3, 0.6), blade=(0.5, 0.1, 1.0), up=(0, 1, 0), space="ut"),
        },
    )

    # ---------------- P5 AFTERMATH ----------------
    tl.phase("AFTERMATH", 1500, 1920)
    tl.marker(1500, "ASH_FALL")
    tl.marker(1560, "SCREEN_RESTORE")
    tl.marker(1590, "BLADE_REFORM")
    ch.add(1500, 2.5, "io3")
    ch.add(1640, -0.3, "smooth")
    c.k(
        1600,
        "smooth",
        parts={
            "LeftUpperLeg": (14, 4, -3),
            "LeftLowerLeg": (-18, 0, 0),
            "LeftFoot": (-14, 0, 0),
            "RightUpperLeg": (-6, -4, 3),
            "RightLowerLeg": (-26, 0, 0),
            "RightFoot": (-20, 0, 0),
        },
        lt=(0, 2, 0, 0, None, 0),
        ut=(-2, 0, 0),
        head=(-6, 0, 0),
    )
    c.k(1630, "smooth", feet={"L": {"w": 0.0}, "R": {"w": 0.0}})
    c.k(
        1642,
        "out3",
        lt=(-4, 2, 0, 0, None, 0),
        ut=(-6, 0, 0),
        head=(-10, 0, 0),
        arms={"L": dict(grip=(-1.2, -0.75, -0.3), blade=(0.1, -0.4, -1.0), up=(0, 1, 0)), "R": dict(R_LOW)},
        feet=F(l=dict(x=-0.6, z=0.12, yaw=6, w=1.0), r=dict(x=0.6, z=-0.1, yaw=-6, w=1.0)),
    )
    tl.marker(1642, "LAND", "soft")
    c.k(1700, "smooth", lt=(0, -10, 0, 0, -0.3, 0), ut=(-2, -14, 0), head=(4, -30, 0), feet=PIN)
    c.k(1740, "smooth", lt=(0, 12, 0, 0, -0.3, 0), ut=(-2, 16, 0), head=(2, 34, 0), feet=PIN)
    c.k(
        1762,
        "out3",
        lt=(0, 8, 0, 0, -0.34, 0),
        ut=(-4, 6, 0),
        head=(2, 6, 0),
        arms={"R": dict(grip=(1.45, -0.9, -0.6), blade=(0.85, -0.22, -0.4), up=(0.2, 1, 0))},
    )
    tl.marker(1762, "FLICK", "ember_shed")
    tl.marker(1748, "TRAIL_START", "flick")
    tl.marker(1770, "TRAIL_END", "flick")
    c.k(
        1812,
        "smooth",
        lt=(0, 4, 0, 0, -0.32, 0),
        ut=(-3, -4, 0),
        head=(-4, 2, 0),
        arms={"R": dict(R_LOW), "L": dict(grip=(-1.2, -0.85, -0.2), blade=(0.1, -0.4, -1.0), up=(0, 1, 0))},
        feet=F(l=dict(x=-0.58, z=0.15, yaw=6), r=dict(x=0.58, z=-0.1, yaw=-6)),
    )
    c.k(1920, "sine_io", lt=(0, 2, 0, 0, -0.3, 0), ut=(-4, -2, 0), head=(-8, 0, 0), feet=PIN)
    tl.marker(1880, "DISSIPATE")
    tl.marker(1900, "RECOVERY")
    tl.marker(1920, "END")
    return tl


def sparks(count, color=("CORE", "LILAC", "VIOLET"), speed=(8, 16), spread=70, life=(0.3, 0.6), size=0.14, **kw):
    c0, c1, c2 = color
    return part(
        shape="block",
        count=count,
        dir=kw.pop("dir", "up"),
        spread=spread,
        speed=speed,
        drag=1.2,
        accel=(0, -40, 0),
        lifetime=life,
        size=fade(size, size * 0.2),
        aspect=(0.35, 1, 0.35),
        rot="velocity",
        stretch=2.5,
        color=[(0, c0), (0.5, c1), (1, c2)],
        transparency=fade(0, 1),
        **kw
    )


def dust(count, radius=0.6, speed=(3, 6), size=(0.4, 1.6), life=(0.6, 1.1), color="DUST", **kw):
    return part(
        shape="ball",
        look="smoke",
        count=count,
        spawn={"shape": "ring", "radius": radius},
        dir="out",
        tilt=kw.pop("tilt", 8),
        spread=12,
        speed=speed,
        drag=2.2,
        lifetime=life,
        size=grow(*size),
        env=0.25,
        transparency=[(0, 0.45), (1, 1)],
        color=color,
        **kw
    )


def pulse(size0, size1, life, color="CORE", t0=0.1, **kw):
    spec = dict(shape="hiball", lifetime=life, size=grow(size0, size1), color=color, transparency=[(0, t0), (1, 1)])
    spec.update(kw)
    return animate(**spec)


def glow_disc(size0, size1, life, color="VIOLET", t0=0.35, **kw):
    spec = dict(
        shape="disc",
        lifetime=life,
        size_xyz=(grow(size0, size1), 1.0, grow(size0, size1)),
        color=color,
        transparency=[(0, t0), (1, 1)],
        link="world",
    )
    spec.update(kw)
    return animate(**spec)


def screen_state(brightness, saturation, life, hold_until, contrast=0.0, release=0.0):
    return screen(
        lifetime=life,
        hold_until=hold_until,
        release=release,
        brightness=brightness,
        saturation=saturation,
        contrast=contrast,
    )


CUES = [
    # P1 SHADOW WALK ---------------------------------------------------------
    emit("CAST_START", None, screen_state(grow(0, -0.05), grow(0, -0.12), 2.0, "DIM")),
    emit(
        "CIRCUITS_START",
        "character",
        special("circuits", count=6, color="VIOLET", until="IMPLODE"),
        part(
            anchor="LowerTorso",
            shape="ball",
            look="smoke",
            rate=16,
            until="AWAKEN",
            spawn={"shape": "box", "box": (1.8, 2.8, 1.2)},
            dir="up",
            spread=20,
            speed=(1.5, 3.2),
            drag=1.0,
            accel=(0, 1.2, 0),
            lifetime=(0.9, 1.5),
            size=[(0, 0.3), (0.4, 1.0), (1, 1.5)],
            env=0.3,
            transparency=[(0, 1), (0.2, 0.55), (1, 1)],
            color=[(0, "VOID"), (0.5, "ABYSS"), (1, "INK")],
        ),
        part(
            anchor="LowerTorso",
            shape="ball",
            rate=10,
            until="AWAKEN",
            spawn={"shape": "box", "box": (2.2, 3.4, 1.4)},
            dir="up",
            spread=15,
            speed=(1.0, 2.5),
            lifetime=(1.0, 1.8),
            size=fade(0.16, 0.04),
            color=[(0, "LILAC"), (1, "VIOLET")],
            transparency=fade_in_out(0.0, 1.0, 0.2, 0.6),
        ),
        part(
            anchor="blade_tip",
            shape="block",
            rate=18,
            until="AWAKEN",
            dir=(0, 1, 0.6),
            spread=55,
            speed=(5, 11),
            drag=1.5,
            accel=(0, -45, 0),
            lifetime=(0.25, 0.5),
            size=fade(0.13, 0.03),
            aspect=(0.35, 1, 0.35),
            rot="velocity",
            stretch=2.5,
            color=[(0, "CORE"), (0.4, "LILAC"), (1, "VIOLET")],
            transparency=fade(0, 1),
        ),
        part(
            anchor="blade_tip",
            shape="block",
            snap="ground",
            rate=22,
            until="AWAKEN",
            lifetime=1.6,
            size=fade(0.22, 0.1),
            aspect=(0.6, 0.08, 1.4),
            color=[(0, "LILAC"), (1, "VOID")],
            transparency=[(0, 0.1), (0.6, 0.5), (1, 1)],
        ),
    ),
    emit(
        "STEP_SIGIL",
        "feet",
        ring(radius=grow(0.3, 3.4), width=fade(0.28, 0.02), lifetime=0.5, color=[(0, "CORE"), (1, "VIOLET")]),
        glow_disc(0.6, 4.5, 0.4, "VIOLET"),
        dust(7),
        sparks(10, spawn={"shape": "disc", "radius": 0.8}),
        light(range=10, brightness=fade(1.0, 0), lifetime=0.35, color="VIOLET", offset=(0, 0.6, 0)),
    ),
    emit(
        "AWAKEN",
        "Head",
        pulse(0.15, 1.3, 0.25, "CORE", offset=(0.0, 0.1, -0.62)),
        animate(
            shape="cube",
            lifetime=0.35,
            size_xyz=(grow(0.1, 4.0), 0.04, 0.04),
            offset=(0.0, 0.12, -0.66),
            color="LILAC",
            transparency=fade(0, 1),
        ),
        ring(anchor="feet", radius=grow(0.5, 7.0), width=fade(0.6, 0.05), lifetime=0.55, color="VIOLET"),
        dust(16, anchor="feet", speed=(6, 10), size=(0.5, 2.0)),
        highlight(anchor="character", color="VIOLET", fill=0.85, outline=0.0, until="RELEASE"),
        flash(mode="white", lifetime=0.18, alpha=fade(0.18, 0)),
    ),
    # P2 AWAKENING ------------------------------------------------------------
    emit(
        "CONVERGE",
        "chest",
        part(
            shape="block",
            rate=28,
            until="CHARGE_PEAK",
            spawn={"shape": "shell", "radius": 34},
            dir="in",
            speed=(38, 46),
            lifetime=(0.75, 0.85),
            size=0.12,
            aspect=(0.5, 1, 0.5),
            rot="velocity",
            stretch=5,
            color=[(0, "LILAC"), (0.6, "VIOLET"), (1, "CORE")],
            transparency=[(0, 1), (0.25, 0.15), (0.9, 0), (1, 1)],
        ),
        part(
            shape="ball",
            rate=6,
            until="IMPLODE",
            spawn={"shape": "shell", "radius": 14},
            dir="in",
            speed=(3, 6),
            lifetime=(2.0, 2.6),
            size=grow(0.25, 0.6),
            color=[(0, "LILAC"), (1, "VIOLET")],
            transparency=fade_in_out(0.2, 1.0, 0.25, 0.7),
        ),
        lightning(
            rate=2.5,
            until="HALO",
            target="around",
            length=(2.0, 4.5),
            lifetime=(0.08, 0.16),
            flicker=0.04,
            width=0.05,
            color="LILAC",
            forks=1,
        ),
    ),
    emit(
        "SIGIL_GROUND",
        "feet",
        special(
            "sigil", radius=8.0, color="VIOLET", spin=24, spokes=12, rings=3, until="RELEASE", implode_at="IMPLODE"
        ),
        part(
            shape="cylinder",
            count=12,
            spawn={"shape": "ring", "radius": 8.0},
            offset=(0, 3.0, 0),
            lifetime=(1.0, 1.4),
            size=[(0, 0.0), (0.15, 1.0), (1, 0.6)],
            aspect=(0.18, 6.0, 0.18),
            color=[(0, "CORE"), (1, "VIOLET")],
            transparency=[(0, 0.1), (1, 1)],
        ),
        ring(radius=grow(7.0, 9.5), width=fade(0.6, 0.05), lifetime=0.6, color="CORE"),
        part(
            shape="rock",
            look="rock",
            count=26,
            spawn={"shape": "disc", "radius": (4, 22)},
            snap="ground",
            dir="up",
            spread=10,
            speed=(0.5, 1.4),
            drag=0.3,
            accel=(0, 0.22, 0),
            life_until="SILENCE",
            size=[(0, 0.0), (0.03, 1.0), (0.955, 1.0), (1, 0.0)],
            env=0.55,
            aspect=(1.0, 0.7, 0.9),
            spin=(15, 60),
            color="STONE",
            pull=260,
            pull_to="hands",
            pull_at="IMPLODE",
        ),
        when="1",
    ),
    emit(
        "SIGIL_GROUND",
        "feet",
        special(
            "sigil", radius=14.0, color="CORE", spin=-14, spokes=16, rings=2, until="RELEASE", implode_at="IMPLODE"
        ),
        part(
            shape="cylinder",
            count=16,
            spawn={"shape": "ring", "radius": 14.0},
            offset=(0, 4.0, 0),
            lifetime=(1.0, 1.4),
            size=[(0, 0.0), (0.15, 1.0), (1, 0.6)],
            aspect=(0.2, 8.0, 0.2),
            color=[(0, "CORE"), (1, "VIOLET")],
            transparency=[(0, 0.1), (1, 1)],
        ),
        ring(radius=grow(13.0, 16.0), width=fade(0.7, 0.05), lifetime=0.6, color="LILAC"),
        part(
            shape="rock",
            look="rock",
            count=22,
            spawn={"shape": "disc", "radius": (6, 26)},
            snap="ground",
            dir="up",
            spread=10,
            speed=(0.6, 1.6),
            drag=0.3,
            accel=(0, 0.25, 0),
            life_until="SILENCE",
            size=[(0, 0.0), (0.03, 1.0), (0.955, 1.0), (1, 0.0)],
            env=0.55,
            aspect=(0.9, 0.6, 1.1),
            spin=(15, 60),
            color="STONE",
            pull=260,
            pull_to="hands",
            pull_at="IMPLODE",
        ),
        when="2",
    ),
    emit(
        "SIGIL_GROUND",
        "feet",
        special(
            "sigil", radius=20.0, color="VIOLET", spin=9, spokes=24, rings=3, until="RELEASE", implode_at="IMPLODE"
        ),
        part(
            shape="cylinder",
            count=20,
            spawn={"shape": "ring", "radius": 20.0},
            offset=(0, 5.0, 0),
            lifetime=(1.0, 1.4),
            size=[(0, 0.0), (0.15, 1.0), (1, 0.6)],
            aspect=(0.22, 10.0, 0.22),
            color=[(0, "CORE"), (1, "VIOLET")],
            transparency=[(0, 0.1), (1, 1)],
        ),
        ring(radius=grow(19.0, 23.0), width=fade(0.8, 0.05), lifetime=0.6, color="VIOLET"),
        when="3",
    ),
    emit("DIM", None, screen_state(grow(-0.05, -0.15), grow(-0.12, -0.35), 4.0, "IMPLODE")),
    emit(
        "LEVITATE",
        "feet",
        ring(radius=grow(1.0, 10.0), width=fade(0.9, 0.05), lifetime=0.65, color=[(0, "CORE"), (1, "VIOLET")]),
        glow_disc(1.0, 9.0, 0.6, "VIOLET", 0.3),
        dust(20, radius=1.0, speed=(8, 13), size=(0.6, 2.4), life=(0.8, 1.3)),
        part(
            anchor="LeftFoot",
            shape="ball",
            rate=14,
            until="IMPLODE",
            dir="down",
            spread=25,
            speed=(2, 4),
            lifetime=(0.4, 0.7),
            size=fade(0.5, 0.08),
            color=[(0, "LILAC"), (1, "VOID")],
            transparency=fade(0.1, 1),
        ),
        part(
            anchor="RightFoot",
            shape="ball",
            rate=14,
            until="IMPLODE",
            dir="down",
            spread=25,
            speed=(2, 4),
            lifetime=(0.4, 0.7),
            size=fade(0.5, 0.08),
            color=[(0, "LILAC"), (1, "VOID")],
            transparency=fade(0.1, 1),
        ),
    ),
    # P3 SINGULARITY ----------------------------------------------------------
    emit(
        "HALO",
        "UpperTorso",
        special("halo", radius=3.6, color="VIOLET", until="IMPLODE"),
        part(
            shape="ball",
            rate=34,
            until="IMPLODE",
            link="follow",
            offset=(0, 0.7, 1.3),
            spawn={"shape": "vring", "radius": 3.6},
            dir="radial",
            spread=12,
            speed=(2, 5),
            drag=1.2,
            lifetime=(0.45, 0.8),
            size=fade(0.28, 0.05),
            color=[(0, "CORE"), (0.4, "LILAC"), (1, "VIOLET")],
            transparency=fade(0.05, 1),
        ),
        lightning(
            rate=7,
            until="IMPLODE",
            target="around",
            length=(2.5, 5.5),
            lifetime=(0.08, 0.18),
            flicker=0.04,
            width=0.06,
            color="LILAC",
            forks=2,
            anchor="chest",
        ),
    ),
    emit("HELIX", "character", special("helix", count=3, radius=3.2, height=7.5, color="VIOLET", until="IMPLODE")),
    emit("ORBS", "chest", special("orbs", count=6, radius=4.2, color="CORE", until="IMPLODE")),
    emit(
        "CHARGE_PEAK",
        "hands",
        pulse(0.5, 5.0, 0.25, "CORE"),
        ring(radius=grow(0.5, 6.0), width=fade(0.5, 0.02), lifetime=0.3, orient="facing", color="CORE"),
        ring(anchor="feet", radius=grow(2.0, 32.0), width=fade(1.2, 0.1), lifetime=0.7, color="LILAC"),
        sparks(
            46, dir="radial", spawn={"shape": "sphere", "radius": 0.5}, spread=180, speed=(14, 26), life=(0.35, 0.7)
        ),
        shake(amplitude=fade(0.35, 0), frequency=26, lifetime=0.6, falloff=200),
        flash(mode="white", lifetime=0.25, alpha=fade(0.35, 0)),
        light(range=24, brightness=fade(1.4, 0), lifetime=0.4, color="LILAC"),
    ),
    emit(
        "BLADE_DISSOLVE",
        "blade_base",
        special("blade", visible=False, fade=0.3),
        part(
            shape="block",
            count=70,
            spawn={"shape": "segment", "to": "blade_tip", "radius": 0.08},
            spread=180,
            speed=(0.5, 2.5),
            lifetime=(0.6, 1.1),
            size=fade(0.16, 0.04),
            aspect=(1, 1, 1),
            rot="random",
            spin=(90, 360),
            color=[(0, "CORE"), (0.4, "LILAC"), (1, "VIOLET")],
            transparency=fade(0, 1),
            pull=80,
            pull_to="hands",
        ),
        light(range=8, brightness=fade(1.0, 0), lifetime=0.5, color="LILAC", anchor="blade_mid"),
    ),
    emit(
        "IMPLODE",
        "hands",
        ring(
            radius=grow(22.0, 0.2),
            width=[(0, 0.4), (1, 1.4)],
            lifetime=0.22,
            color=[(0, "VIOLET"), (1, "CORE")],
            transparency=[(0, 0.6), (1, 0)],
        ),
        part(
            shape="block",
            count=110,
            spawn={"shape": "shell", "radius": 18},
            dir="in",
            speed=(50, 70),
            lifetime=(0.26, 0.34),
            size=0.14,
            aspect=(0.5, 1, 0.5),
            rot="velocity",
            stretch=6,
            color=[(0, "VIOLET"), (1, "CORE")],
            transparency=[(0, 0.6), (0.8, 0), (1, 1)],
        ),
        distort(radius=grow(7.0, 0.3), lifetime=0.3, transparency=[(0, 0.3), (1, 0.7)]),
        screen_state(grow(-0.15, -0.45), grow(-0.35, -0.6), 0.25, "RELEASE", contrast=grow(0, 0.25)),
        shake(amplitude=fade(0.5, 0), frequency=30, lifetime=0.35, falloff=200),
    ),
    emit(
        "SILENCE",
        "hands",
        special("point", until="RELEASE"),
        part(
            shape="ball",
            rate=10,
            until="RELEASE",
            spawn={"shape": "shell", "radius": 1.2},
            dir="in",
            speed=(1.0, 1.8),
            lifetime=(0.6, 0.9),
            size=fade(0.08, 0.02),
            color="CORE",
            transparency=fade_in_out(0.0, 1.0, 0.3, 0.7),
        ),
    ),
    emit(
        "POINT_PULSE",
        "hands",
        ring(radius=grow(0.3, 3.8), width=fade(0.3, 0.02), lifetime=0.32, orient="facing", color="CORE"),
        light(range=16, brightness=fade(0.8, 0), lifetime=0.25, color="CORE"),
        screen(lifetime=0.2, brightness=fade(0.06, 0)),
    ),
    # P4 ATOMIC ----------------------------------------------------------------
    emit(
        "RELEASE",
        "hands",
        flash(mode="invert", lifetime=0.05, alpha=1.0),
        flash(mode="black", delay=0.05, lifetime=0.05, alpha=1.0),
        flash(mode="white", delay=0.1, lifetime=1.2, alpha=[(0, 1.0), (0.1, 0.5), (0.4, 0.15), (1, 0)]),
        shake(amplitude=[(0, 3.5), (0.3, 2.0), (1, 0)], frequency=18, rot=1.5, lifetime=2.4, falloff=600),
        screen_state([(0, 0.08), (1, 0.03)], [(0, 0.3), (1, 0.15)], 3.5, "SCREEN_RESTORE", release=2.5),
        special("fov", delta=12, lifetime=0.9),
    ),
    emit(
        "NUKE",
        "hands",
        pulse(
            1.0,
            50.0,
            3.0,
            "CORE",
            t0=0.0,
            size=[(0, 1.0), (0.15, 44.0), (1, 50.0)],
            transparency=[(0, 0.0), (0.12, 0.35), (0.4, 0.8), (1, 1)],
            intensity=0.6,
        ),
        animate(
            shape="hiball",
            lifetime=5.2,
            size=[(0, 2.0), (0.28, 112.0), (0.5, 120.0), (1, 124.0)],
            color=[(0, "LILAC"), (0.3, "VIOLET"), (1, "VOID")],
            transparency=[(0, 0.45), (0.4, 0.72), (1, 1)],
            link="world",
            intensity=0.35,
        ),
        animate(
            shape="hiball",
            lifetime=5.0,
            size=[(0, 4.0), (0.25, 128.0), (1, 136.0)],
            color="LILAC",
            transparency=[(0, 0.8), (0.5, 0.92), (1, 1)],
            link="world",
            spin=(0, 40, 0),
            intensity=0.3,
        ),
        part(
            shape="hiball",
            count=36,
            spawn={"shape": "sphere", "radius": (0, 18)},
            dir="radial",
            spread=30,
            speed=(14, 30),
            drag=1.4,
            lifetime=(1.6, 2.6),
            size=grow(6.0, 15.0),
            env=0.3,
            color=[(0, "LILAC"), (0.3, "VIOLET"), (1, "VOID")],
            transparency=[(0, 0.65), (1, 1)],
            intensity=0.4,
        ),
        part(
            shape="block",
            count=130,
            spawn={"shape": "sphere", "radius": 2},
            dir="radial",
            spread=180,
            speed=(60, 110),
            drag=0.8,
            lifetime=(0.6, 1.2),
            size=fade(0.35, 0.1),
            aspect=(0.4, 1, 0.4),
            rot="velocity",
            stretch=5,
            color=[(0, "CORE"), (0.4, "LILAC"), (1, "VIOLET")],
            transparency=fade(0, 1),
        ),
        distort(radius=grow(6.0, 95.0), lifetime=0.9, transparency=[(0, 0.15), (1, 1)]),
        light(range=60, brightness=[(0, 2.0), (0.3, 1.2), (1, 0)], lifetime=4.5, color="LILAC"),
    ),
    emit(
        "SHOCKWAVE",
        "feet",
        ring(radius=grow(4.0, 80.0), width=fade(3.0, 0.4), lifetime=1.0, color="CORE"),
        glow_disc(6.0, 150.0, 1.0, "LILAC", 0.5, intensity=0.4),
        when="1",
    ),
    emit(
        "SHOCKWAVE", "feet", ring(radius=grow(4.0, 100.0), width=fade(2.4, 0.3), lifetime=1.3, color="VIOLET"), when="2"
    ),
    emit(
        "SHOCKWAVE",
        "feet",
        ring(radius=grow(4.0, 120.0), width=fade(1.8, 0.2), lifetime=1.6, color="CRIMSON"),
        when="3",
    ),
    emit(
        "DUST_WALL",
        "feet",
        part(
            shape="hiball",
            look="smoke",
            count=64,
            spawn={"shape": "ring", "radius": 6},
            dir="out",
            tilt=6,
            spread=6,
            speed=(48, 66),
            drag=0.9,
            lifetime=(2.6, 3.4),
            size=grow(3.0, 13.0),
            env=0.3,
            color=[(0, "DUST"), (1, "ASH")],
            transparency=[(0, 0.25), (0.6, 0.55), (1, 1)],
        ),
    ),
    emit(
        "DEBRIS",
        "feet",
        part(
            shape="rock",
            look="rock",
            count=46,
            spawn={"shape": "disc", "radius": (1, 8)},
            snap="ground",
            dir="out",
            tilt=48,
            spread=18,
            speed=(40, 80),
            accel=(0, -196.2, 0),
            lifetime=3.6,
            size=1.3,
            env=0.6,
            spin=(200, 600),
            color="STONE",
            ground={"bounce": (0.2, 0.4), "sink": 0.2},
        ),
        part(
            shape="ball",
            count=180,
            spawn={"shape": "sphere", "radius": 3, "upper": True},
            dir="radial",
            spread=40,
            speed=(20, 60),
            drag=0.8,
            accel=(0, -10, 0),
            lifetime=(1.0, 2.4),
            size=fade(0.22, 0.04),
            color=[(0, "CORE"), (0.4, "LILAC"), (1, "VIOLET")],
            transparency=fade(0, 1),
        ),
    ),
    emit(
        "COLUMN",
        "feet",
        animate(
            shape="cylinder",
            lifetime=4.5,
            offset=(0, 110, 0),
            link="world",
            size_xyz=(
                [(0, 1.0), (0.08, 12.0), (1, 9.0)],
                [(0, 1.0), (0.12, 220.0), (1, 220.0)],
                [(0, 1.0), (0.08, 12.0), (1, 9.0)],
            ),
            color="CORE",
            transparency=[(0, 0.0), (0.6, 0.3), (1, 1)],
            intensity=0.6,
        ),
        animate(
            shape="cylinder",
            lifetime=4.5,
            offset=(0, 110, 0),
            link="world",
            size_xyz=(
                [(0, 2.0), (0.1, 20.0), (1, 26.0)],
                [(0, 2.0), (0.12, 220.0), (1, 220.0)],
                [(0, 2.0), (0.1, 20.0), (1, 26.0)],
            ),
            color="VIOLET",
            transparency=[(0, 0.4), (1, 1)],
            intensity=0.4,
        ),
        part(
            shape="block",
            rate=36,
            duration=3.5,
            spawn={"shape": "disc", "radius": 4},
            dir="up",
            spread=4,
            speed=(80, 120),
            lifetime=(1.0, 1.4),
            size=0.5,
            aspect=(0.3, 1, 0.3),
            rot="velocity",
            stretch=6,
            color=[(0, "CORE"), (1, "LILAC")],
            transparency=fade(0, 1),
        ),
    ),
    emit(
        "MUSHROOM",
        "feet",
        part(
            shape="hiball",
            look="smoke",
            count=26,
            offset=(0, 82, 0),
            spawn={"shape": "sphere", "radius": (0, 8)},
            dir="radial",
            spread=30,
            speed=(8, 16),
            drag=0.6,
            accel=(0, 4, 0),
            lifetime=(5.0, 6.0),
            size=grow(16.0, 42.0),
            env=0.25,
            color=[(0, "DUST"), (1, "ASH")],
            transparency=[(0, 0.3), (0.7, 0.6), (1, 1)],
        ),
        glow_disc(30.0, 80.0, 5.0, "VIOLET", 0.45, offset=(0, 72, 0), intensity=0.4),
        ring(
            radius=grow(20.0, 92.0),
            width=fade(3.0, 0.5),
            lifetime=3.0,
            color="WHITE",
            offset=(0, 58, 0),
            transparency=[(0, 0.4), (1, 1)],
        ),
        part(
            shape="hiball",
            look="smoke",
            rate=10,
            duration=3.0,
            spawn={"shape": "disc", "radius": 6},
            dir="up",
            spread=8,
            speed=(20, 30),
            lifetime=(2.8, 3.4),
            size=grow(6.0, 15.0),
            color=[(0, "DUST"), (1, "ASH")],
            transparency=[(0, 0.4), (1, 1)],
        ),
    ),
    # P5 AFTERMATH ---------------------------------------------------------------
    emit(
        "ASH_FALL",
        "feet",
        part(
            shape="block",
            look="smoke",
            rate=60,
            duration=6.0,
            offset=(0, 40, 0),
            spawn={"shape": "box", "box": (110, 2, 110)},
            dir="down",
            spread=10,
            speed=(3, 6),
            accel=(0, -1, 0),
            lifetime=(7.0, 9.0),
            size=0.28,
            aspect=(1, 0.1, 1),
            rot="random",
            spin=(60, 220),
            color="ASH",
            transparency=[(0, 1), (0.1, 0.2), (0.85, 0.3), (1, 1)],
        ),
        part(
            shape="ball",
            rate=18,
            duration=6.0,
            spawn={"shape": "disc", "radius": (2, 45)},
            snap="ground",
            dir="up",
            spread=20,
            speed=(1, 3),
            lifetime=(2.5, 4.0),
            size=fade(0.16, 0.04),
            color=[(0, "LILAC"), (1, "VIOLET")],
            transparency=fade_in_out(0.1, 1.0, 0.2, 0.6),
        ),
        glow_disc(68.0, 70.0, 7.0, "ABYSS", 0.2, look="dark"),
        ring(
            radius=grow(30.0, 31.0), width=fade(1.4, 0.6), lifetime=6.0, color="VIOLET", transparency=[(0, 0.3), (1, 1)]
        ),
    ),
    emit(
        "BLADE_REFORM",
        "blade_mid",
        special("blade", visible=True, delay=0.33, fade=0.15),
        part(
            shape="block",
            count=70,
            spawn={"shape": "shell", "radius": 3.5},
            dir="in",
            speed=(5, 8),
            lifetime=(0.4, 0.55),
            size=fade(0.08, 0.16),
            rot="random",
            spin=(90, 360),
            pull=60,
            color=[(0, "VIOLET"), (1, "CORE")],
            transparency=[(0, 1), (0.3, 0.1), (1, 0)],
        ),
        pulse(0.3, 2.6, 0.3, "LILAC", delay=0.5),
        light(range=10, brightness=fade(1.2, 0), lifetime=0.4, color="LILAC", delay=0.5),
    ),
    emit(
        "LAND",
        "feet",
        ring(radius=grow(0.5, 4.5), width=fade(0.4, 0.05), lifetime=0.4, color="LILAC"),
        dust(12, speed=(4, 7)),
        tier="secondary",
    ),
    emit(
        "FLICK",
        "blade_base",
        part(
            shape="block",
            count=30,
            spawn={"shape": "segment", "to": "blade_tip"},
            dir=(1, 0.3, -0.6),
            spread=35,
            speed=(8, 16),
            drag=1.0,
            accel=(0, -30, 0),
            lifetime=(0.4, 0.8),
            size=fade(0.14, 0.03),
            aspect=(0.35, 1, 0.35),
            rot="velocity",
            stretch=2.5,
            color=[(0, "CORE"), (0.5, "LILAC"), (1, "VIOLET")],
            transparency=fade(0, 1),
        ),
    ),
    cue("TRAIL_START", "trail", "blade", on=True, color="LILAC", color2="VIOLET", color3="VOID", lifetime=0.22),
    cue("TRAIL_END", "trail", "blade", on=False),
]

HITS = [
    cue("NUKE", "blast", "feet", radius=60.0, damage=45, knockback=90.0, lift=45.0),
    cue("SHOCKWAVE", "push", "feet", when="3", radius=120.0, damage=0, knockback=45.0, lift=15.0),
]
