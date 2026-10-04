"""ANIM_05 — EIGHTFOLD EXECUTION (habilidade especial multi-estágio)

Three stages, each with its own rhythm:
  S1 "Crescent"   — stepping horizontal cut right->left (fast, grounded)
  S2 "Spiral"     — low recoil, 360-degree rising spin cut (airborne,
                    the spin lives on the Root joint so the HRP never turns)
  S3 "Execution"  — leap, hang time, X-cross double slash in the air,
                    landing stab, then the caster turns away while the X
                    detonates behind (delayed payoff)

Note: after the S2 spin every LowerTorso yaw value carries +360 so the
Euler curve never unwinds; 370 == 10 deg for Roblox (same quaternion).

Timing @60 fps:
  S1: 7 wind, 12 HIT_1, 16 follow-through, 22 STAGE_1_END
  S2: 28 recoil, 33 leave ground, 42 HIT_2 (spiral apex), 51 spin done,
      55 land, 60 STAGE_2_END
  S3: 66 crouch, 72 LEAP, 82 apex hang, 88 HIT_3A, 92 rewind, 96 HIT_3B,
      102 FINAL_IMPACT (landing stab), 112 X_DETONATE, 124 turn-away pose,
      170 END
"""

import anim_engine as ae
from common import STANCE_ARMS, STANCE_BODY, STANCE_FEET, feet, hor_spine, sag_spine, stance_key

META = dict(
    id="ANIM_05",
    name="ANIM_05_EIGHTFOLD_EXECUTION",
    concept="Combo de 3 estágios terminando num X que detona",
    camera=dict(loc=(11.0, 10.0, 1.4), target=(0.0, 0.6, -0.3), lens=24, track=0.8),
    alt_cameras={"side": dict(loc=(14.0, 2.0, 0.5), target=(0.0, 3.0, -0.5), lens=26)},
    sheet_frames=[0, 7, 12, 16, 28, 36, 42, 48, 55, 66, 76, 84, 88, 92, 96, 102, 124, 170],
    blade_ground_ok=[(101, 116)],
)

SPIN = 360.0


def UT(grip, blade, up=None, pole=None):
    d = dict(grip=grip, blade=blade, up=up if up is not None else (0, 1, 0), space="ut")
    if pole is not None:
        d["pole"] = pole
    return d


def build():
    tl = ae.Timeline(META["name"], 0, 170)
    tl.lag = {"UpperTorso": 0.7, "Head": 2.2, "RightUpperArm": 0.5, "RightLowerArm": 1.0,
              "RightHand": 1.4, "LeftUpperArm": 1.0, "LeftLowerArm": 2.0, "LeftHand": 3.0}
    tl.noise = {"UpperTorso": 0.35, "Head": 0.5}
    tl.tremble = {"RightUpperArm": 0.5, "RightLowerArm": 0.6, "UpperTorso": 0.3}
    tl.scarf_params = dict(gravity=42.0, drag=2.8, stiffness=8.0)

    stance_key(tl, 0, root=dict(x=0, y=0, z=0, yaw=0))
    tl.fx(0, gain=1.0, tremble=0.0)
    tl.marker(1, "CAST_START")

    # ---------------- S1: crescent ----------------
    b7 = (0.75, 0.05, 1.0)
    tl.key(7, "smooth",
           parts={"LowerTorso": (-4, -16, 0, 0, -0.6, 0.0), "UpperTorso": (-8, -40, 0), "Head": (6, 40, 0)},
           arms={"R": dict(grip=(1.5, -0.4, 0.45), blade=b7, up=hor_spine(b7)),
                 "L": dict(grip=(-0.7, -0.3, -1.1), blade=(0.3, 0.1, -1.0), up=(0, 1, 0))},
           ik=feet(r=dict(x=0.6, z=-0.3, lift=0.3)), root=dict(z=0.0))
    tl.marker(4, "TRAIL_START", "blade")
    b12 = (-0.25, 0.0, -1.0)
    tl.key(12, "linear",
           parts={"LowerTorso": (-8, 14, 0, 0, -0.75, 0.0), "UpperTorso": (-10, 12, 0), "Head": (10, -6, 0)},
           arms={"R": dict(grip=(0.35, -0.3, -1.55), blade=b12, up=hor_spine(b12))},
           ik=feet(r=dict(x=0.6, z=-1.05, yaw=-6, lift=0)),
           root=dict(z=-1.2), overrides={"ROOT": "out2", "RightUpperArm": "linear"})
    tl.marker(12, "HIT_1", "crescent")
    b16 = (-1.0, 0.0, 0.25)
    tl.key(16, "out3",
           parts={"LowerTorso": (-6, 30, 0, 0, -0.72, 0.0), "UpperTorso": (-6, 34, 0), "Head": (6, -28, 0)},
           arms={"R": dict(grip=(-0.1, -0.35, -0.85), blade=b16, up=hor_spine(b16), pole=(1, -1, -0.4),
                           grip_space="ut", dir_space="root"),
                 "L": dict(grip=(-1.3, -0.6, 0.4), blade=(-0.5, -0.3, 0.8), up=(0, 1, 0))},
           root=dict(z=-1.4))
    tl.marker(22, "STAGE_1_END")

    # ---------------- S2: spiral ----------------
    tl.key(28, "smooth",
           parts={"LowerTorso": (-12, 40, 0, 0, -1.0, 0.0), "UpperTorso": (-14, 22, 0), "Head": (12, -22, 0)},
           arms={"R": dict(grip=(-0.7, -1.4, -0.9), blade=(-0.8, -0.2, -0.5), up=(0, 1, 0), pole=(1, -1, 0)),
                 "L": dict(grip=(-1.2, -0.9, 0.5), blade=(-0.4, -0.4, 0.8), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.8, z=0.4, yaw=30), r=dict(x=0.62, z=-1.1, yaw=10, lift=0)))
    tl.marker(28, "TRAIL_START", "spiral")
    tl.key(33, "smooth",
           parts={"LowerTorso": (-6, 50, 0, 0, -0.55, 0.0), "UpperTorso": (-6, 16, 0)},
           ik={"L": dict(w=1.0), "R": dict(w=1.0)})
    tl.key(37, "smooth", ik={"L": dict(w=0.0), "R": dict(w=0.0)},
           parts={"LeftUpperLeg": (60, 0, -8), "LeftLowerLeg": (-90, 0, 0), "LeftFoot": (-20, 0, 0),
                  "RightUpperLeg": (20, 0, 6), "RightLowerLeg": (-70, 0, 0), "RightFoot": (-30, 0, 0)})
    # spin (Root joint yaw 50 -> 410) with rising cut
    tl.ch("LowerTorso.ry").add(33, 50.0, "io2")
    tl.ch("LowerTorso.ry").add(51, 50.0 + SPIN, "smooth")
    tl.ch("LowerTorso.ty").add(33, -0.55, "out2")
    tl.ch("LowerTorso.ty").add(43, 1.7, "in2")
    tl.ch("LowerTorso.ty").add(55, -0.85, "smooth")
    tl.key(42, "smooth",
           parts={"UpperTorso": (10, -10, 8), "Head": (-6, 8, 0), "LowerTorso": (8, None, 0, 0, None, 0)},
           arms={"R": UT((1.85, 0.7, -0.75), (0.55, 0.85, -0.3), up=(-0.4, 0.2, 1.0), pole=(1, -0.6, 0.4)),
                 "L": UT((-1.9, 0.0, 0.4), (-0.8, -0.2, 0.5), pole=(-0.6, -1, 0.2))})
    tl.marker(42, "HIT_2", "spiral")
    tl.key(48, "smooth",
           parts={"UpperTorso": (2, -4, 4), "LeftUpperLeg": (30, 0, -6), "LeftLowerLeg": (-50, 0, 0),
                  "RightUpperLeg": (40, 0, 6), "RightLowerLeg": (-80, 0, 0)},
           arms={"R": UT((1.75, 0.4, 0.2), (0.6, 0.3, 0.75), up=(0, 1, 0), pole=(1, -0.8, 0.3))})
    tl.key(53, "smooth", ik={"L": dict(w=0.0), "R": dict(w=0.0)})
    tl.key(55, "out3",
           parts={"LowerTorso": (-12, None, 0, 0, None, 0.0), "UpperTorso": (-12, -20, 0), "Head": (14, 18, 0)},
           arms={"R": dict(grip=(1.5, -0.9, 0.3), blade=(0.85, -0.25, 0.4), up=(0, 1, 0)),
                 "L": dict(grip=(-1.15, -0.6, -0.8), blade=(-0.3, -0.2, -0.9), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.85, z=0.6, yaw=24, w=1.0), r=dict(x=0.7, z=-0.8, yaw=-6, w=1.0, lift=0)),
           root=dict(z=-2.4), overrides={"ROOT": "smooth"})
    tl.marker(55, "LAND", "spiral_land")
    tl.marker(58, "TRAIL_END", "spiral")
    tl.marker(60, "STAGE_2_END")

    # ---------------- S3: execution ----------------
    tl.key(66, "smooth",
           parts={"LowerTorso": (-10, 4 + SPIN, 0, 0, -1.0, 0.0), "UpperTorso": (6, -10, 0), "Head": (-2, 6, 0)},
           arms={"R": dict(grip=(1.3, -1.2, 0.55), blade=(0.3, -0.2, 1.0), up=(0, 1, 0)),
                 "L": dict(grip=(-1.0, -1.1, -0.6), blade=(0.0, -0.4, -1.0), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.75, z=0.3, yaw=20), r=dict(x=0.65, z=-0.45, yaw=-8)))
    tl.key(70, "smooth", ik={"L": dict(w=1.0), "R": dict(w=1.0)})
    tl.marker(72, "LEAP")
    tl.key(76, "smooth", ik={"L": dict(w=0.0), "R": dict(w=0.0)},
           parts={"LeftUpperLeg": (40, 0, -6), "LeftLowerLeg": (-70, 0, 0), "LeftFoot": (-25, 0, 0),
                  "RightUpperLeg": (-10, 0, 6), "RightLowerLeg": (-60, 0, 0), "RightFoot": (-35, 0, 0)})
    tl.ch("LowerTorso.ty").add(70, -1.0, "out3")
    tl.ch("LowerTorso.ty").add(82, 2.6, "smooth")
    tl.ch("LowerTorso.ty").add(86, 2.55, "in2")
    tl.ch("LowerTorso.ty").add(102, -1.15, "out3")
    # apex: one-handed blade cocked high behind, left arm forward
    lift = 2.6
    tl.key(82, "smooth",
           parts={"LowerTorso": (10, 0 + SPIN, 0, 0, None, 0.0), "UpperTorso": (16, -12, 4), "Head": (-10, 8, 0)},
           arms={"R": dict(grip=(0.9, 1.6 + lift, 0.35), blade=(0.55, 0.55, 0.65),
                           up=(-0.6, 0.4, -0.5), pole=(1, 0.2, 0.6)),
                 "L": dict(grip=(-0.95, 0.4 + lift, -1.2), blade=(0.2, 0.2, -1.0), up=(0, 1, 0))},
           root=dict(z=-4.4))
    tl.marker(80, "TRAIL_START", "x_cross")
    tl.fx(80, tremble=0.6)
    tl.fx(86, tremble=0.0)
    # HIT_3A: top-right -> bottom-left
    lift = 1.7
    b88 = (-0.7, -0.55, -0.45)
    tl.key(88, "in2",
           parts={"LowerTorso": (-4, 14 + SPIN, 0, 0, None, 0.0), "UpperTorso": (-14, 16, -6), "Head": (8, -10, 0)},
           arms={"R": dict(grip=(0.2, -0.4, -1.1), blade=b88, up=(0.5, -0.6, 0.6), pole=(1, -0.6, -0.2),
                           grip_space="ut", dir_space="root")})
    tl.marker(88, "HIT_3A", "x_cross_1")
    # rewind: blade flips up-left
    lift = 1.2
    tl.key(92, "out2",
           parts={"LowerTorso": (2, 4 + SPIN, 0, 0, None, 0.0), "UpperTorso": (4, 20, 4)},
           arms={"R": dict(grip=(-0.55, 1.4 + lift, -0.5), blade=(-0.45, 0.85, 0.3), up=(0.8, 0.2, -0.3),
                           pole=(1, -0.4, 0.4))})
    # HIT_3B: top-left -> bottom-right
    lift = 0.5
    b96 = (0.7, -0.5, -0.5)
    tl.key(96, "in2",
           parts={"LowerTorso": (-8, -16 + SPIN, 0, 0, None, 0.0), "UpperTorso": (-16, -18, 6), "Head": (10, 12, 0)},
           arms={"R": dict(grip=(1.3, -0.55, -1.0), blade=b96, up=(-0.5, -0.6, 0.6), pole=(1, -0.8, 0.2),
                           grip_space="ut", dir_space="root"),
                 "L": dict(grip=(-1.35, -0.2, 0.7), blade=(-0.5, 0.2, 0.8), up=(0, 1, 0), space="ut")},
           root=dict(z=-5.6))
    tl.marker(96, "HIT_3B", "x_cross_2")
    tl.key(98, "smooth", ik={"L": dict(w=0.0), "R": dict(w=0.0)})
    # FINAL_IMPACT: landing stab
    tl.key(102, "out3",
           parts={"LowerTorso": (-14, 4 + SPIN, 0, 0, None, -0.1), "UpperTorso": (-24, -8, 0), "Head": (16, 4, 0)},
           arms={"R": dict(grip=(0.8, -0.6, -1.2), blade=(0.05, -0.62, -0.78), up=sag_spine((0.05, -0.62, -0.78)),
                           grip_space="ut", dir_space="root"),
                 "L": dict(grip=(-1.25, -0.9, 0.55), blade=(-0.4, -0.5, 0.8), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.85, z=0.75, yaw=24, w=1.0), r=dict(x=0.72, z=-0.85, yaw=-8, w=1.0)),
           root=dict(z=-6.0))
    tl.marker(102, "FINAL_IMPACT", "stab")
    tl.marker(104, "TRAIL_END", "x_cross")
    tl.fx(102, tremble=1.2)
    tl.fx(110, tremble=0.0)
    tl.key(110, "smooth",
           parts={"LowerTorso": (-12, 4 + SPIN, 0, 0, -1.05, -0.1), "UpperTorso": (-22, -8, 0), "Head": (14, 4, 0)},
           arms={"R": dict(grip=(0.8, -0.58, -1.2), blade=(0.05, -0.6, -0.78), up=sag_spine((0.05, -0.6, -0.78)),
                           grip_space="ut", dir_space="root")})
    tl.marker(112, "X_DETONATE")

    # turn-away execution pose: back to the blast, blade flicked out
    tl.key(124, "smooth",
           parts={"LowerTorso": (0, 160 + SPIN, 0, 0, -0.5, 0.0), "UpperTorso": (2, -14, 0), "Head": (4, -30, 0)},
           arms={"R": dict(grip=(1.55, -0.7, 0.4), blade=(0.8, -0.3, 0.5), up=(0, 1, 0), space="ut"),
                 "L": dict(grip=(-1.0, -0.65, -0.5), blade=(0.2, -0.2, -1.0), up=(0, 1, 0), space="ut")},
           ik=feet(l=dict(x=-0.62, z=0.35, yaw=150), r=dict(x=0.55, z=-0.45, yaw=175)))
    tl.marker(124, "EXECUTION_POSE")
    tl.key(140, "smooth",
           parts={"LowerTorso": (0, 168 + SPIN, 0, 0, -0.46, 0.0), "UpperTorso": (0, -10, 0), "Head": (2, -24, 0)},
           ik=feet(l=dict(x=-0.62, z=0.35, yaw=150), r=dict(x=0.55, z=-0.45, yaw=175)))
    tl.marker(142, "RECOVERY")
    # return to stance facing forward again (yaw 370 == 10)
    body = dict(STANCE_BODY)
    body["LowerTorso"] = (0.0, 10.0 + SPIN, 0.0, 0.0, -0.35, 0.0)
    tl.key(170, "smooth", parts=body, ik={k: dict(v) for k, v in STANCE_FEET.items()},
           arms={k: dict(v) for k, v in STANCE_ARMS.items()})
    tl.marker(170, "END")
    return tl
