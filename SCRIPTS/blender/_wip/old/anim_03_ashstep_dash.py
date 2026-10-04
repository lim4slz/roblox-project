"""ANIM_03 — ASHSTEP DASH (mobilidade / alta velocidade)

Sprinter's coil -> explosive 24-stud dash (root motion, expo-out) with the
body stretched and the blade trailing -> backhand draw-cut as it passes ->
skid stop with a counter-lean -> blade twirl flourish -> stance.

Root motion is NOT in the KeyframeSequence (Roblox has no root motion): it
is exported in ANIM_03_ASHSTEP_DASH_timing.json and replayed by
RootMotion.luau on the owning client. The animation itself stays in place.

Timing @60 fps:
  0  STANCE, 4 coil (anticipation, only 4 frames — speed reads from contrast)
  6  DASH_START / TRAIL_START, root 0 -> -24 studs over f6-f22 (expo_out)
  8,11,14 AFTERIMAGE, 9-14 stretched glide
  16 backhand wind (blade across the body), 19 SLASH (left -> right)
  21 SKID (feet plant, dust), 26 momentum overshoot, 30 TRAIL_END
  40-54 FLOURISH (360 blade twirl in the hand), 78 END
"""

import anim_engine as ae
from common import STANCE_ARMS, feet, hor_spine, stance_key

META = dict(
    id="ANIM_03",
    name="ANIM_03_ASHSTEP_DASH",
    concept="Avanço explosivo de 24 studs com corte de passagem",
    camera=dict(loc=(12.0, 2.0, 0.6), target=(0.0, 3.0, -1.0), lens=26, track=0.92),
    alt_cameras={"close": dict(loc=(9.0, 14.0, 0.3), target=(0.0, 17.0, -1.0), lens=30)},
    sheet_frames=[0, 4, 6, 8, 11, 14, 16, 18, 19, 21, 26, 34, 44, 50, 78],
)


def build():
    tl = ae.Timeline(META["name"], 0, 78)
    tl.lag = {"UpperTorso": 0.5, "Head": 2.0, "RightUpperArm": 0.6, "RightLowerArm": 1.2,
              "RightHand": 1.6, "LeftUpperArm": 1.0, "LeftLowerArm": 2.0, "LeftHand": 3.0}
    tl.noise = {"UpperTorso": 0.3, "Head": 0.4}
    tl.scarf_params = dict(gravity=40.0, drag=4.0, stiffness=12.0)

    stance_key(tl, 0, root=dict(x=0, y=0, z=0, yaw=0))
    tl.marker(1, "CAST_START")

    # 4 — coil: low sprinter's start, blade drawn back
    tl.key(4, "smooth",
           parts={"LowerTorso": (-16, 4, 0, 0, -0.95, 0.15),
                  "UpperTorso": (-26, -6, 0),
                  "Head": (26, 4, 0)},
           arms={"R": dict(grip=(1.25, -1.3, 0.55), blade=(0.25, 0.05, 1.0), up=(0, 1, 0)),
                 "L": dict(grip=(-0.85, -0.9, -0.75), blade=(0.2, -0.3, -1.0), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.6, z=-0.6, yaw=6), r=dict(x=0.6, z=0.95, yaw=-6, lift=0.08, pitch=-32)),
           root=dict(z=0.0))

    # 6 — launch
    tl.key(6, "smooth",
           parts={"LowerTorso": (-30, 2, 0, 0, -0.7, 0.0), "UpperTorso": (-24, -4, 0), "Head": (34, 2, 0)},
           ik=feet(l=dict(x=-0.6, z=-0.9, lift=0.35, pitch=-10), r=dict(x=0.62, z=1.35, lift=0.45, pitch=-55)))
    tl.marker(6, "DASH_START")
    tl.marker(6, "TRAIL_START", "body")

    # 9 — stretched glide (expo root motion is on its fastest part)
    tl.key(9, "smooth",
           parts={"LowerTorso": (-38, 0, 2, 0, -0.55, 0.0), "UpperTorso": (-24, -2, 0), "Head": (40, 0, 0)},
           arms={"R": dict(grip=(1.3, -0.8, 0.85), blade=(0.12, -0.45, 1.0), up=(0, 1, 0.4), space="ut"),
                 "L": dict(grip=(-1.3, -0.8, 0.85), blade=(-0.15, -0.6, 1.0), up=(0, 1, 0), space="ut",
                           pole=(-0.5, -1, 0.6))},
           ik=feet(l=dict(x=-0.55, z=-1.0, lift=0.95, pitch=-20, w=1.0),
                   r=dict(x=0.6, z=1.7, lift=1.05, pitch=-70)))
    tl.marker(8, "AFTERIMAGE", "1")
    tl.marker(11, "AFTERIMAGE", "2")
    tl.marker(14, "AFTERIMAGE", "3")

    # 13 — glide 2 (slight lift, legs scissor)
    tl.key(13, "smooth",
           parts={"LowerTorso": (-36, -6, -2, 0, -0.5, 0.0), "UpperTorso": (-22, 14, 0), "Head": (38, -8, 0)},
           arms={"R": dict(grip=(0.2, -0.8, -0.5), blade=(-0.8, -0.25, 0.55), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.6, z=-0.7, lift=1.05, pitch=-25), r=dict(x=0.6, z=1.4, lift=1.15, pitch=-60)))

    # 16 — backhand wind: blade across the body, torso turned left
    b16 = (-0.95, 0.05, 0.35)
    tl.key(16, "smooth",
           parts={"LowerTorso": (-30, 14, 0, 0, -0.6, 0.0), "UpperTorso": (-16, 30, 0), "Head": (30, -24, 0)},
           arms={"R": dict(grip=(-0.25, -0.75, -0.55), blade=b16, up=hor_spine(b16, -1.0),
                           pole=(1.0, -0.8, -0.6))},
           ik=feet(l=dict(x=-0.65, z=-0.9, lift=0.55, pitch=-5), r=dict(x=0.65, z=1.0, lift=0.7, pitch=-40)))

    # 19 — SLASH: blade whips left -> right across the target line
    b19 = (0.95, 0.1, 0.25)
    tl.key(19, "out3",
           parts={"LowerTorso": (-18, -18, 0, 0, -0.85, 0.0), "UpperTorso": (-8, -34, 0), "Head": (18, 30, 0)},
           arms={"R": dict(grip=(1.55, -0.3, -0.25), blade=b19, up=hor_spine(b19, -1.0), pole=(1.0, -1.0, 0.4)),
                 "L": dict(grip=(-1.2, -0.7, -0.6), blade=(-0.6, -0.2, -0.8), up=(0, 1, 0))},
           ik=feet(l=dict(x=-0.75, z=-0.9, lift=0.2, pitch=0), r=dict(x=0.7, z=0.9, lift=0.25, pitch=-20)),
           overrides={"RightUpperArm": "out4", "RightLowerArm": "out4", "RightHand": "out4"})
    tl.marker(19, "SLASH", "draw_cut")

    # 21 — SKID: feet plant wide, deep, counter-lean
    tl.key(21, "smooth",
           parts={"LowerTorso": (-6, -16, 0, 0, -1.15, 0.05), "UpperTorso": (6, -26, -4), "Head": (6, 24, 0)},
           ik=feet(l=dict(x=-0.95, z=-0.95, yaw=10, lift=0, pitch=0, w=1),
                   r=dict(x=0.85, z=1.05, yaw=-30, lift=0, pitch=0)))
    tl.marker(21, "SKID", "dust")

    # 26 — momentum overshoot forward
    tl.key(26, "smooth",
           parts={"LowerTorso": (-14, -14, 0, 0, -1.05, -0.05), "UpperTorso": (-12, -22, -2), "Head": (14, 20, 0)},
           arms={"R": dict(grip=(1.45, -0.55, 0.15), blade=(0.85, -0.15, 0.55), up=(0, 1, 0)),
                 "L": dict(grip=(-1.15, -0.5, -0.75), blade=(-0.4, -0.1, -0.9), up=(0, 1, 0))})
    tl.marker(30, "TRAIL_END", "body")

    # 36 — settle, start rising
    tl.key(36, "smooth",
           parts={"LowerTorso": (-4, -8, 0, 0, -0.75, 0.0), "UpperTorso": (-6, -14, 0), "Head": (6, 12, 0)},
           arms={"R": dict(grip=(1.2, -0.45, -0.75), blade=(0.3, 0.6, -0.75), up=(0, 0.5, 1))},
           ik=feet(l=dict(x=-0.82, z=-0.6, yaw=12), r=dict(x=0.75, z=0.75, yaw=-24)))

    # 40-54 — FLOURISH: blade twirls 360 deg around the grip (EmberBlade joint)
    tl.key(40, "smooth", parts={"EmberBlade": (0, 0, 0)},
           arms={"R": dict(grip=(1.05, -0.2, -1.0), blade=(0.1, 0.0, -1.0), up=(0, 1, 0))})
    tl.key(54, "io3", parts={"EmberBlade": (0, 360, 0)})
    tl.key(40, "io3", parts={"EmberBlade": (0, 0, 0)})
    tl.marker(42, "FLOURISH", "twirl")
    tl.key(56, "back_out_soft",
           parts={"LowerTorso": (0, 4, 0, 0, -0.42, 0.0), "UpperTorso": (-5, -12, 0), "Head": (3, 6, 0)},
           arms={"R": dict(grip=(1.0, -0.7, -0.9), blade=(-0.25, 0.5, -1.0), up=(0, 1, 0.5)),
                 "L": dict(STANCE_ARMS["L"])},
           ik=feet(l=dict(x=-0.75, z=0.2, yaw=20, lift=0.0), r=dict(x=0.6, z=-0.2, yaw=-10, lift=0.25)))
    tl.marker(58, "RECOVERY")
    stance_key(tl, 78, "smooth")
    tl.marker(78, "END")

    # root motion: expo-out burst, last 0.4 stud is the skid slide
    # 2-frame burst -> cruise (~132 studs/s) -> brake; last 0.5 stud = skid
    tl.ch("ROOT.z").add(6, 0.0, "in2")
    tl.ch("ROOT.z").add(8, -2.2, "linear")
    tl.ch("ROOT.z").add(16, -19.8, "out3")
    tl.ch("ROOT.z").add(24, -23.5, "out2")
    tl.ch("ROOT.z").add(32, -24.0, "smooth")
    return tl
