"""ANIM_02 — VOID SUN BURST (habilidade energética complexa)

The left hand chambers an ember-void sun at the right hip while the whole
body coils like a spring; a dead-still "inhale" beat; then the body uncoils
and the palm drives a beam forward, recoil skids the caster back, the beam
dies and the hand sheds the leftover energy.

Arm targets in HumanoidRootPart space (floor y=-3, forward -Z).

Timing @60 fps:
  0   STANCE
  4   CAST_START
  14  wide stance, CHARGE_START (orb ignites in the left palm)
  30  chamber (hand at right hip), 45 deeper coil (tremble rising)
  60  CHARGE_PEAK (max coil, max tremble)
  66  COMPRESS — tremble cut to zero: the stillness before release
  72  release begins (out4: explosive start, decelerating)
  76  RELEASE (palm fully driven, beam fires), 84 BEAM_PEAK
  80-108 sustained beam, recoil skid (root motion +0.7 studs back)
  96  SECONDARY_BURST (detonation at range)
  110 DISSIPATE, 116 HAND_SHAKE, 150 END
"""

import anim_engine as ae
from common import STANCE_ARMS, feet, stance_key

META = dict(
    id="ANIM_02",
    name="ANIM_02_VOID_SUN_BURST",
    concept="Carrega um sol de brasa e vazio na mão e dispara um feixe",
    camera=dict(loc=(12.5, 4.0, 0.4), target=(0.0, 0.2, -0.9), lens=26),
    alt_cameras={"front": dict(loc=(7.0, 11.0, 0.8), target=(0.0, -0.5, -0.8), lens=28)},
    sheet_frames=[0, 14, 30, 45, 60, 66, 72, 74, 76, 84, 100, 110, 118, 150],
)


def H(grip, hand=(0.0, 0.2, -1.0), up=(0, 1, 0), pole=(-0.9, -1.0, 0.4)):
    """Left (casting) hand target."""
    return dict(grip=grip, blade=hand, up=up, pole=pole)


def build():
    tl = ae.Timeline(META["name"], 0, 150)
    tl.lag = {"UpperTorso": 0.8, "Head": 2.5, "LeftUpperArm": 0.6, "LeftLowerArm": 1.2,
              "LeftHand": 2.0, "RightUpperArm": 1.5, "RightLowerArm": 2.5, "RightHand": 3.5}
    tl.noise = {"UpperTorso": 0.4, "Head": 0.6, "LowerTorso": 0.2}
    tl.tremble = {"UpperTorso": 0.5, "Head": 0.4, "LeftUpperArm": 0.9, "LeftLowerArm": 1.1,
                  "LeftHand": 1.6, "RightUpperArm": 0.4}
    tl.scarf_params = dict(gravity=40.0, drag=3.6, stiffness=10.0)

    stance_key(tl, 0, root=dict(x=0, y=0, z=0, yaw=0))
    tl.fx(0, tremble=0.0, gain=1.0)
    tl.marker(4, "CAST_START")

    # 6 — right foot starts sliding back
    tl.key(6, "smooth",
           parts={"LowerTorso": (-2, 0, 0, 0, -0.45, 0.05), "UpperTorso": (-6, -20, 0)},
           ik=feet(r=dict(x=0.75, z=0.1, yaw=-20, lift=0.3, pitch=-10)))

    # 14 — wide stance, orb ignites; blade swept low behind
    tl.key(14, "smooth",
           parts={"LowerTorso": (-4, -28, 0, 0, -0.62, 0.05),
                  "UpperTorso": (-8, -24, 3),
                  "Head": (6, 40, 0)},
           arms={"R": dict(grip=(1.35, -1.15, 0.65), blade=(0.45, -0.12, 1.0), up=(0, 1, 0)),
                 "L": dict(grip=(-0.6, -0.1, -1.25), blade=(0.35, 0.6, -0.7), up=(0, 1, 0), pole=(-0.9, -1.0, 0.4), space="ut")},
           ik=feet(l=dict(x=-0.62, z=-0.75, yaw=8), r=dict(x=0.95, z=0.95, yaw=-38, lift=0, pitch=0)))
    tl.marker(14, "CHARGE_START", "orb_ignite")
    tl.fx(14, gain=1.0, tremble=0.2)

    # 30 — chamber: palm pulled to the right hip, body coils right
    tl.key(30, "smooth",
           parts={"LowerTorso": (-6, -36, 0, 0, -0.9, 0.08),
                  "UpperTorso": (2, -42, 4),
                  "Head": (4, 62, 0)},
           arms={"R": dict(grip=(1.3, -1.25, 0.85), blade=(0.35, -0.2, 1.0), up=(0, 1, 0)),
                 "L": H((0.55, -0.85, -0.55), (0.2, 0.35, -1.0), up=(-1, 0.4, 0))})
    tl.fx(30, tremble=0.8)
    tl.marker(30, "CHARGE_STAGE", "2")

    # 45 — deeper coil, energy roaring
    tl.key(45, "smooth",
           parts={"LowerTorso": (-5, -42, 0, 0, -0.98, 0.1),
                  "UpperTorso": (4, -50, 5),
                  "Head": (2, 70, 0)},
           arms={"L": H((0.7, -0.95, -0.4), (0.15, 0.3, -1.0), up=(-1, 0.4, 0))})
    tl.fx(45, tremble=1.6)
    tl.marker(45, "CHARGE_STAGE", "3")

    # 60 — CHARGE_PEAK
    tl.key(60, "smooth",
           parts={"LowerTorso": (-4, -46, 0, 0, -1.02, 0.12),
                  "UpperTorso": (6, -54, 6),
                  "Head": (-2, 74, 0)},
           arms={"L": H((0.78, -1.0, -0.32), (0.1, 0.3, -1.0), up=(-1, 0.4, 0))})
    tl.fx(60, tremble=2.6)
    tl.marker(60, "CHARGE_PEAK")

    # 66 — COMPRESS: tremble cut, dead still (contrast)
    tl.key(66, "out2",
           parts={"LowerTorso": (-5, -47, 0, 0, -1.08, 0.12),
                  "UpperTorso": (4, -55, 6),
                  "Head": (-6, 75, 0)},
           arms={"L": H((0.82, -1.04, -0.28), (0.1, 0.3, -1.0), up=(-1, 0.4, 0))})
    tl.fx(64, tremble=2.6)
    tl.fx(67, tremble=0.0, gain=0.25)
    tl.marker(66, "COMPRESS")

    # 72 — last frame of the held breath
    tl.key(72, "out4",
           parts={"LowerTorso": (-5, -47, 0, 0, -1.09, 0.12), "UpperTorso": (4, -55, 6), "Head": (-6, 75, 0)},
           arms={"L": H((0.82, -1.05, -0.27), (0.1, 0.3, -1.0), up=(-1, 0.4, 0)),
                 "R": dict(grip=(1.3, -1.25, 0.85), blade=(0.35, -0.2, 1.0), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.62, z=-0.75, yaw=8), r=dict(x=0.95, z=0.95, yaw=-38, lift=0, pitch=0)),
           root=dict(z=0.0))

    # 74 — front foot lifts for the stomp
    tl.key(74, "smooth", ik=feet(l=dict(x=-0.62, z=-1.0, yaw=6, lift=0.32, pitch=8)))
    # 77 — RELEASE: stomp-lunge, full uncoil, palm driven forward at chest
    # height; blade arm thrown back-up => one straight line of action
    tl.key(77, "smooth",
           parts={"LowerTorso": (-10, 20, 0, 0, -0.88, -0.55),
                  "UpperTorso": (-14, 22, -4),
                  "Head": (8, -14, 0)},
           arms={"L": dict(grip=(-0.5, 0.55, -1.6), blade=(0.0, 1.0, -0.2), up=(0, 0.2, 1.0), space="ut",
                           pole=(-1, -0.6, 0.2)),
                 "R": dict(grip=(1.55, 0.15, 0.85), blade=(0.5, 0.5, 1.0), up=(0, 1, -0.5), space="ut")},
           ik=feet(l=dict(x=-0.62, z=-1.3, yaw=6, lift=0, pitch=0),
                   r=dict(x=0.85, z=1.25, yaw=-32, lift=0.08, pitch=-30)),
           overrides={"IK.L": "out4"})
    tl.fx(74, gain=1.0, tremble=0.0)
    tl.fx(78, tremble=2.0)
    tl.marker(76, "RELEASE", "beam")
    tl.marker(76, "SCREEN_FLASH")
    tl.marker(77, "STOMP", "dust")

    # 82 — recoil pushes the caster back
    tl.key(82, "smooth",
           parts={"LowerTorso": (-5, 17, 0, 0, -0.86, -0.4),
                  "UpperTorso": (2, 18, -3),
                  "Head": (4, -10, 0)},
           arms={"L": dict(grip=(-0.48, 0.62, -1.58), blade=(0.0, 1.0, -0.25), up=(0, 0.2, 1.0), space="ut",
                           pole=(-1, -0.6, 0.2))},
           root=dict(z=0.25))
    tl.marker(84, "BEAM_PEAK")

    # 100 — sustained beam, drifting back
    tl.key(100, "smooth",
           parts={"LowerTorso": (-6, 16, 0, 0, -0.84, -0.35),
                  "UpperTorso": (2, 19, -3),
                  "Head": (3, -11, 0)},
           arms={"L": dict(grip=(-0.47, 0.66, -1.58), blade=(0.0, 1.0, -0.28), up=(0, 0.2, 1.0), space="ut",
                           pole=(-1, -0.6, 0.2))},
           root=dict(z=0.6))
    tl.fx(100, tremble=1.6)
    tl.marker(96, "SECONDARY_BURST", "target_detonation")

    # 110 — beam ends, arm drops
    tl.key(110, "smooth",
           parts={"LowerTorso": (-3, 14, 0, 0, -0.7, -0.2), "UpperTorso": (-2, 12, -2), "Head": (4, -6, 0)},
           arms={"L": dict(grip=(-0.75, 0.25, -1.3), blade=(0.1, 0.6, -0.8), up=(0, 0.4, 1.0), space="ut"),
                 "R": dict(grip=(1.45, -0.3, 0.6), blade=(0.5, 0.1, 1.0), up=(0, 1, 0), space="ut")},
           root=dict(z=0.7))
    tl.fx(108, tremble=1.2)
    tl.fx(114, tremble=0.0, gain=1.0)
    tl.marker(110, "DISSIPATE")

    # 118 — hand shake-off (wrist flick down)
    tl.key(118, "out3",
           parts={"UpperTorso": (-4, 6, -1), "Head": (6, -2, 0)},
           arms={"L": H((-0.95, -0.45, -1.0), (0.25, -0.8, -0.5), up=(0, 0, -1))})
    tl.marker(116, "HAND_SHAKE", "ember_shed")

    # 120-126 — front (left) foot steps back under the body
    tl.key(120, "smooth", ik=feet(l=dict(x=-0.66, z=-0.55, yaw=12, lift=0.32, pitch=6)))
    tl.key(126, "smooth", ik=feet(l=dict(x=-0.7, z=0.2, yaw=18, lift=0.0, pitch=0)))
    # 132 — right foot steps forward toward stance
    tl.key(132, "smooth",
           parts={"LowerTorso": (0, 6, 0, 0, -0.45, 0.0), "UpperTorso": (-5, -8, 0), "Head": (3, 4, 0)},
           arms={"R": dict(grip=(1.1, -0.8, -0.6), blade=(-0.1, 0.35, -1.0), up=(0, 1, 0.5)),
                 "L": dict(STANCE_ARMS["L"])},
           ik=feet(r=dict(x=0.62, z=0.0, yaw=-12, lift=0.3, pitch=-5)))
    tl.marker(132, "RECOVERY")
    stance_key(tl, 150, "smooth")
    tl.marker(150, "END")
    return tl
