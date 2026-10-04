"""ANIM_04 — CINDER CATACLYSM (ultimate / grande escala)

Salute -> levitation (3.2 studs, via the Root joint so the HRP and physics
stay grounded) -> blade raised to the sky while a sun is gathered above ->
curl + reverse grip + dead-still beat -> dive -> blade plunged into the
ground (pillar eruption, double shockwave, ember rain) -> kneeling hold ->
blade pulled out, grip flipped back with a twirl -> stance.

Arm targets in HumanoidRootPart space; while levitating the current lift is
added (helper U) because the shoulders rise with the Root joint.

Timing @60 fps:
  6 CAST_START, 12 SIGIL_GROUND, 24 salute
  30 ASCEND (Root ty -0.15 -> +3.2 over f30-f80), 50 SKY_SIGIL
  62 CHARGE_START, 96 SUN_FORM, 120 SUN_GROW, 150 CHARGE_PEAK
  154 REVERSE_GRIP, 162 COMPRESS (stillness), 168 DIVE
  178 IMPACT + FLASH, 180 PILLAR + SHOCKWAVE, 182 DEBRIS, 188 SHOCKWAVE_2
  200 EMBER_RAIN, 222 DISSIPATE, 240 REGRIP, 246 RECOVERY, 260 END
"""

import anim_engine as ae
from common import STANCE_ARMS, feet, stance_key

META = dict(
    id="ANIM_04",
    name="ANIM_04_CINDER_CATACLYSM",
    concept="Ultimate: ascende, forma um sol e crava a lâmina no chão",
    camera=dict(loc=(15.0, 13.0, -0.6), target=(0.0, -0.5, 2.2), lens=22),
    alt_cameras={"low": dict(loc=(8.0, 9.0, -2.2), target=(0.0, 0.0, 1.0), lens=22)},
    sheet_frames=[0, 24, 40, 60, 90, 120, 150, 158, 166, 172, 178, 190, 230, 244, 260],
    blade_ground_ok=[(175, 238)],
)

DANGLE = {
    "LeftUpperLeg": (10, 4, -3), "LeftLowerLeg": (-24, 0, 0), "LeftFoot": (-38, 0, 0),
    "RightUpperLeg": (-6, -5, 3), "RightLowerLeg": (-34, 0, 0), "RightFoot": (-32, 0, 0),
}
DANGLE_B = {
    "LeftUpperLeg": (-4, 6, -4), "LeftLowerLeg": (-30, 0, 0), "LeftFoot": (-34, 0, 0),
    "RightUpperLeg": (6, -3, 4), "RightLowerLeg": (-22, 0, 0), "RightFoot": (-40, 0, 0),
}
CURL = {
    "LeftUpperLeg": (78, 6, -6), "LeftLowerLeg": (-118, 0, 0), "LeftFoot": (-20, 0, 0),
    "RightUpperLeg": (66, -4, 6), "RightLowerLeg": (-112, 0, 0), "RightFoot": (-25, 0, 0),
}
REACH_DOWN = {
    "LeftUpperLeg": (14, 4, -3), "LeftLowerLeg": (-18, 0, 0), "LeftFoot": (-12, 0, 0),
    "RightUpperLeg": (-10, -4, 3), "RightLowerLeg": (-40, 0, 0), "RightFoot": (-30, 0, 0),
}


def U(lift, x, y, z):
    return (x, y + lift, z)


def build():
    tl = ae.Timeline(META["name"], 0, 260)
    tl.lag = {"UpperTorso": 1.0, "Head": 3.0, "RightUpperArm": 0.8, "RightLowerArm": 1.5,
              "RightHand": 2.0, "LeftUpperArm": 1.2, "LeftLowerArm": 2.4, "LeftHand": 3.5,
              "LeftUpperLeg": 1.5, "LeftLowerLeg": 3.0, "LeftFoot": 4.5,
              "RightUpperLeg": 2.0, "RightLowerLeg": 3.5, "RightFoot": 5.0}
    tl.noise = {"UpperTorso": 0.6, "Head": 0.8, "LowerTorso": 0.5, "LeftUpperArm": 0.6}
    tl.tremble = {"UpperTorso": 0.5, "Head": 0.5, "RightUpperArm": 0.8, "RightLowerArm": 0.9,
                  "LeftUpperArm": 0.9, "LeftLowerArm": 1.0, "LeftHand": 1.4}
    tl.scarf_params = dict(gravity=30.0, drag=3.0, stiffness=8.0)

    stance_key(tl, 0, root=dict(x=0, y=0, z=0, yaw=0))
    tl.fx(0, gain=1.0, tremble=0.0)
    tl.marker(6, "CAST_START")
    tl.marker(12, "SIGIL_GROUND")

    # 10 — gather: right foot draws in, blade starts rising
    tl.key(10, "smooth",
           parts={"LowerTorso": (-2, 4, 0, 0, -0.3, 0), "UpperTorso": (-4, -6, 0), "Head": (-4, 2, 0)},
           arms={"R": dict(grip=(0.6, -0.2, -1.0), blade=(-0.1, 0.8, -0.6), up=(0, 0.6, 1))},
           ik=feet(r=dict(x=0.55, z=0.0, yaw=-4, lift=0.25)))

    # 24 — SALUTE: blade vertical before the face, two hands, head bowed
    tl.key(24, "smooth",
           parts={"LowerTorso": (0, 0, 0, 0, -0.15, 0), "UpperTorso": (-2, 0, 0), "Head": (-16, 0, 0)},
           arms={"R": dict(grip=(0.12, 0.38, -0.8), blade=(0.0, 1.0, -0.08), up=(0, 0, 1)),
                 "L": dict(grip=(0.1, 0.0, -0.8), blade=(0.0, 1.0, -0.08), up=(0, 0, 1),
                           pole=(-1, -0.8, 0.4))},
           ik=feet(l=dict(x=-0.5, z=0.05, yaw=8), r=dict(x=0.52, z=0.1, yaw=-6, lift=0)))

    # 30 — ASCEND begins (still salute)
    tl.key(30, "io3", parts={"LowerTorso": (0, 0, 0, 0, -0.15, 0), "Head": (-14, 0, 0)},
           ik=feet(l=dict(x=-0.5, z=0.05, yaw=8, w=1), r=dict(x=0.52, z=0.1, yaw=-6, w=1)))
    tl.marker(30, "ASCEND")
    # feet release from the floor
    tl.key(36, "smooth", ik={"L": dict(w=1.0), "R": dict(w=1.0)})
    tl.key(46, "smooth", ik={"L": dict(w=0.0), "R": dict(w=0.0)}, parts=dict(DANGLE))

    # levitation curve (Root joint ty) authored explicitly for a clean ease
    tl.ch("LowerTorso.ty").add(30, -0.15, "io3")
    tl.ch("LowerTorso.ty").add(80, 3.2, "smooth")

    # 60 — arms spread: blade arm up, left arm open; chest open, look up
    lift = 2.34  # value of the io3 levitation curve at f60
    tl.key(60, "smooth",
           parts={"LowerTorso": (6, 10, 0, 0, None, 0), "UpperTorso": (10, -6, 2), "Head": (18, 6, 0)},
           arms={"R": dict(grip=U(lift, 1.45, 1.95, -0.25), blade=(0.2, 1.0, 0.15), up=(1, 0, 0)),
                 "L": dict(grip=U(lift, -1.75, 0.95, -0.35), blade=(-1.0, 0.1, -0.2), up=(0, 1, 0),
                           pole=(-0.4, -1, 0.6))})
    tl.marker(50, "SKY_SIGIL")
    tl.marker(62, "CHARGE_START", "sun_seed")
    tl.fx(62, tremble=0.2)

    # 80 — top of the ascent
    lift = 3.2
    tl.key(80, "smooth",
           parts=dict(DANGLE_B, **{"LowerTorso": (4, 18, 0, 0, None, 0), "UpperTorso": (12, -8, 3),
                                    "Head": (24, 8, 0)}))
    # 100 — blade straight to the sky, left hand reaching for the sun
    tl.key(100, "smooth",
           parts=dict(DANGLE, **{"LowerTorso": (2, 8, 0, 0, 3.15, 0), "UpperTorso": (14, -2, 0),
                                  "Head": (30, 2, 0)}),
           arms={"R": dict(grip=U(3.15, 0.75, 2.3, -0.1), blade=(0.0, 1.0, 0.05), up=(1, 0, 0)),
                 "L": dict(grip=U(3.15, -1.15, 2.05, -0.4), blade=(0.15, 1.0, -0.2), up=(0, 0, 1),
                           pole=(-1, -0.3, 0.6))})
    tl.marker(96, "SUN_FORM")
    tl.fx(100, tremble=0.6)
    # 130 — slow drift, energy roaring
    tl.key(130, "smooth",
           parts=dict(DANGLE_B, **{"LowerTorso": (4, -6, 0, 0, 3.25, 0), "UpperTorso": (16, 4, -2),
                                    "Head": (32, -4, 0)}),
           arms={"R": dict(grip=U(3.25, 0.72, 2.3, -0.05), blade=(0.0, 1.0, 0.0), up=(1, 0, 0))})
    tl.marker(120, "SUN_GROW")
    tl.fx(130, tremble=1.6)
    # 150 — CHARGE_PEAK
    tl.key(150, "smooth",
           parts=dict(DANGLE, **{"LowerTorso": (6, -2, 0, 0, 3.3, 0), "UpperTorso": (18, 2, 0),
                                  "Head": (34, 0, 0), "EmberBlade": (0, 0, 0)}),
           arms={"R": dict(grip=U(3.3, 0.72, 2.3, 0.0), blade=(0.0, 1.0, 0.0), up=(1, 0, 0)),
                 "L": dict(grip=U(3.3, -1.12, 2.05, -0.35), blade=(0.15, 1.0, -0.2), up=(0, 0, 1),
                           pole=(-1, -0.3, 0.6))})
    tl.fx(150, tremble=2.8)
    tl.marker(150, "CHARGE_PEAK")

    # 154-160 — curl, blade flips to reverse grip, both hands on the hilt
    tl.key(158, "smooth",
           parts=dict(CURL, **{"LowerTorso": (-10, 0, 0, 0, 3.45, 0.1), "UpperTorso": (-22, 0, 0),
                                "Head": (-6, 0, 0), "EmberBlade": (180, 0, 0)}),
           arms={"R": dict(grip=U(3.45, 0.22, 1.25, -0.75), blade=(0.0, 1.0, 0.15), up=(0, 0, -1)),
                 "L": dict(grip=U(3.45, -0.12, 1.12, -0.72), blade=(0.0, 1.0, 0.15), up=(0, 0, -1),
                           pole=(-1, -0.6, 0.3))})
    tl.marker(154, "REVERSE_GRIP")
    # 162-168 — COMPRESS: dead still, tremble cut
    tl.key(166, "in3",
           parts=dict(CURL, **{"LowerTorso": (-12, 0, 0, 0, 3.5, 0.1), "UpperTorso": (-24, 0, 0),
                                "Head": (-8, 0, 0)}),
           arms={"R": dict(grip=U(3.5, 0.22, 1.28, -0.75), blade=(0.0, 1.0, 0.15), up=(0, 0, -1)),
                 "L": dict(grip=U(3.5, -0.12, 1.15, -0.72), blade=(0.0, 1.0, 0.15), up=(0, 0, -1),
                           pole=(-1, -0.6, 0.3))},
           ik=feet(l=dict(x=-0.62, z=-0.7, yaw=10, w=0.0), r=dict(x=0.6, z=0.85, yaw=-8, w=0.0)))
    tl.fx(156, tremble=2.8)
    tl.fx(161, tremble=0.0, gain=0.2)
    tl.marker(162, "COMPRESS")
    tl.marker(168, "DIVE")

    # 172 — legs reach for the floor mid-dive
    tl.key(172, "smooth", parts=dict(REACH_DOWN, LowerTorso=(-6, 0, 0, 0, None, 0.05)),
           ik={"L": dict(w=0.0), "R": dict(w=0.0)})
    tl.fx(172, gain=1.0)

    # 178 — IMPACT: kneel, blade plunged
    tl.key(178, "out4",
           parts={"LowerTorso": (-12, 4, 0, 0, -1.4, 0.05), "UpperTorso": (-26, -2, 0), "Head": (-12, 0, 0)},
           arms={"R": dict(grip=(0.25, -0.75, -1.05), blade=(0.0, 1.0, 0.12), up=(0, 0, -1)),
                 "L": dict(grip=(-0.1, -0.88, -1.02), blade=(0.0, 1.0, 0.12), up=(0, 0, -1),
                           pole=(-1, -0.6, 0.3))},
           ik=feet(l=dict(x=-0.62, z=-0.75, yaw=10, w=1.0, lift=0),
                   r=dict(x=0.6, z=0.9, yaw=-8, w=1.0, lift=0.04, pitch=-58)),
           overrides={"LowerTorso": "out3"})
    tl.ch("LowerTorso.ty").add(168, 3.5, "in3")
    tl.marker(178, "IMPACT", "plunge")
    tl.marker(178, "FLASH")
    tl.marker(180, "PILLAR")
    tl.marker(180, "SHOCKWAVE")
    tl.marker(182, "DEBRIS")
    tl.marker(188, "SHOCKWAVE_2")
    tl.marker(200, "EMBER_RAIN")
    # 184 — recoil jolt
    tl.key(184, "smooth", parts={"LowerTorso": (-9, 4, 0, 0, -1.28, 0.05), "UpperTorso": (-20, -2, 0),
                                 "Head": (-2, 0, 0)})
    tl.fx(180, tremble=1.4)
    tl.fx(200, tremble=0.3)
    # 214 — kneeling hold, breathing
    tl.key(214, "io2", parts={"LowerTorso": (-11, 4, 0, 0, -1.36, 0.05), "UpperTorso": (-24, -3, 1),
                              "Head": (-14, 2, 0)},
           arms={"R": dict(grip=(0.25, -0.72, -1.05), blade=(0.0, 1.0, 0.12), up=(0, 0, -1)),
                 "L": dict(grip=(-0.1, -0.85, -1.02), blade=(0.0, 1.0, 0.12), up=(0, 0, -1),
                           pole=(-1, -0.6, 0.3))})
    tl.fx(214, tremble=0.0)
    tl.marker(222, "DISSIPATE")

    # 232 — stand and draw the blade out of the ground (still reverse)
    tl.key(232, "smooth",
           parts={"LowerTorso": (-2, 6, 0, 0, -0.45, 0.0), "UpperTorso": (2, -8, 0), "Head": (6, 4, 0)},
           arms={"R": dict(grip=(0.85, 1.7, -0.55), blade=(0.05, 1.0, 0.1), up=(0, 0, -1)),
                 "L": dict(grip=(-0.9, -0.2, -0.9), blade=(0.25, 0.1, -1.0), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.66, z=-0.4, yaw=12), r=dict(x=0.62, z=0.55, yaw=-10, lift=0.0, pitch=0)))
    # 246 — regrip twirl: reverse -> forward
    tl.key(240, "smooth", parts={"EmberBlade": (180, 0, 0)})
    tl.key(250, "io3", parts={"EmberBlade": (360, 0, 0)})
    tl.key(240, "io3", parts={"EmberBlade": (180, 0, 0)})
    tl.marker(240, "REGRIP", "twirl")
    tl.key(248, "smooth",
           arms={"R": dict(grip=(1.1, 0.2, -1.0), blade=(0.0, 0.2, -1.0), up=(0, 1, 0))})
    tl.marker(246, "RECOVERY")
    stance_key(tl, 260, "smooth")
    tl.ch("EmberBlade.rx").add(260, 360.0, "smooth")
    tl.marker(260, "END")

    return tl
