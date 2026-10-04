"""ANIM_05 — TITAN SPECTER: FALLING STAR  (~34 s @ 60 fps)
Inspirado no Susanoo e no meteoro (Tengai Shinsei) de Madara (Naruto
Shippuden). Execução original: um gigante espectral de chamas violetas se
forma em três estágios ao redor do conjurador e espelha seus golpes; depois
um meteoro é arrancado do céu e cai sobre o campo enquanto o gigante
protege o conjurador.

  P1 AWAKEN   0-360     olhos acendem, aura de chamas, chão racha, punho
  P2 SPECTER  360-900   costelas/coluna -> crânio e braços -> armadura e
                        espada colossal; o conjurador aponta a lâmina
  P3 STRIKES  900-1300  corte horizontal (o gigante varre: onda crescente de
                        80 studs) e golpe vertical (fissura de 60 studs)
  P4 STAR     1300-1820 mão ao céu, o céu se rasga, meteoro surge e desce
                        devagar, o braço aponta, impacto colossal a 80
                        studs, o gigante cruza os braços como escudo
  P5 FADE     1820-2040 o gigante se desfaz em chamas, brasas, guarda
"""

import anim_engine as ae
from moves_full import F, PIN, Ctx, breathe, cut, guard, point_down, sky_raise, stance, step

META = dict(
    id="ANIM_05",
    name="ANIM_05_TITAN_SPECTER",
    inspired_by="Susanoo + Tengai Shinsei (meteoro) — Naruto Shippuden",
    concept="Gigante espectral de chamas que espelha os golpes e um meteoro arrancado do céu",
    camera=dict(loc=(26.0, 30.0, 6.0), target=(0.0, 4.0, 8.0), lens=24, track=0.6),
    video_step=2,
)


def build():
    tl = ae.Timeline(META["name"], 0, 2040)
    tl.lag = {"UpperTorso": 0.8, "Head": 2.4, "RightUpperArm": 0.6, "RightLowerArm": 1.2, "RightHand": 1.6,
              "LeftUpperArm": 0.8, "LeftLowerArm": 1.6, "LeftHand": 2.4}
    tl.noise = {"UpperTorso": 0.4, "Head": 0.55, "LowerTorso": 0.25}
    tl.tremble = {"UpperTorso": 0.5, "Head": 0.4, "LeftUpperArm": 0.9, "LeftLowerArm": 1.0, "LeftHand": 1.3,
                  "RightUpperArm": 0.6}
    tl.scarf_params = dict(gravity=40.0, drag=3.0, stiffness=9.0)
    c = Ctx(tl)
    tl.fx(0, gain=1.0, tremble=0.0)

    # ---------------- P1 AWAKEN ----------------
    tl.phase("AWAKEN", 0, 360)
    stance(c, 0)
    c.root_key(0)
    tl.marker(2, "CAST_START")
    c.k(40, "smooth", lt=(-2, 6, 0, 0, -0.4, 0), ut=(-8, -8, 0), head=(-16, 2, 0), feet=PIN)
    c.k(70, "out3", head=(6, 0, 0), ut=(-4, -6, 0))
    tl.marker(70, "EYES_FLARE")
    tl.marker(90, "AURA")
    tl.marker(130, "GROUND_CRACK")
    tl.wind(90, y=14.0, z=4.0)
    c.k(200, "smooth", lt=(0, 4, 0, 0, -0.42, 0), ut=(-2, 4, 0), head=(4, -4, 0),
        arms={"L": dict(grip=(-0.35, 0.65, -1.1), blade=(0.2, 1.0, -0.2), up=(0, 0, 1), space="ut",
                        pole=(-1, -0.8, 0.3)),
              "R": dict(grip=(1.3, -0.9, 0.3), blade=(0.3, -0.45, 1.0), up=(0, 1, 0))})
    tl.fx(200, tremble=0.6)
    c.k(250, "out4", ut=(-4, 2, 0),
        arms={"L": dict(grip=(-0.4, 0.45, -1.05), blade=(0.1, 0.9, -0.3), up=(0, 0, 1), space="ut",
                        pole=(-1, -0.8, 0.3))})
    tl.marker(250, "FIST")
    tl.fx(256, tremble=0.0)
    breathe(c, 260, 360, depth=1.2, period=48)

    # ---------------- P2 SPECTER ----------------
    tl.phase("SPECTER", 360, 900)
    c.k(400, "smooth", lt=(0, 0, 0, 0, -0.45, 0), ut=(4, 0, 0), head=(10, 0, 0),
        arms={"L": dict(grip=(-1.55, -0.2, -0.6), blade=(-0.7, 0.2, -0.6), up=(0, 1, 0), space="ut"),
              "R": dict(grip=(1.55, -0.2, -0.6), blade=(0.7, -0.2, -0.6), up=(0, 1, 0), space="ut")},
        feet=F(l=dict(x=-0.82, z=0.2, yaw=14), r=dict(x=0.8, z=-0.2, yaw=-14)))
    tl.marker(380, "SPECTER_STAGE", "1")
    tl.marker(530, "SPECTER_STAGE", "2")
    tl.marker(700, "SPECTER_STAGE", "3")
    tl.wind(380, y=30.0, z=6.0)
    tl.fx(380, tremble=0.8)
    c.k(520, "sine_io", lt=(2, 0, 0, 0, -0.5, 0), ut=(8, 0, 0), head=(16, 0, 0))
    tl.fx(520, tremble=1.4)
    c.k(690, "smooth", lt=(4, 0, 0, 0, -0.55, 0), ut=(12, 0, 0), head=(20, 0, 0))
    tl.fx(690, tremble=2.0)
    # blade raised forward: command pose (the titan mirrors it)
    c.k(740, "out3", lt=(-4, 14, 0, 0, -0.55, -0.1), ut=(-6, 18, 0), head=(6, -10, 0),
        arms={"R": dict(grip=(0.9, 0.5, -1.35), blade=(0.0, 0.25, -1.0), up=(0, 1, 0), space="ut"),
              "L": dict(grip=(-1.3, 0.2, -0.9), blade=(-0.3, 0.6, -0.8), up=(0, 1, 0), space="ut")})
    tl.fx(744, tremble=0.0)
    tl.marker(740, "TITAN_POSE")
    breathe(c, 760, 900, depth=1.0, period=46)

    # ---------------- P3 STRIKES ----------------
    tl.phase("STRIKES", 900, 1300)
    t = cut(c, 900, "h_rl", wind=34, travel=1.0, crouch=-0.75, settle=26, hit_marker="SPECTER_SWING",
            hit_value="crescent")
    guard(c, t + 10, crouch=-0.55, feet=PIN)
    t = cut(c, max(t + 40, 1080), "down", wind=34, travel=0.8, crouch=-0.9, settle=30, hit_marker="SPECTER_SLAM",
            hit_value="fissure")
    tl.blade_ground_ok.append((t - 30, t + 10))
    guard(c, t + 12, crouch=-0.5, feet=F(l={}, r={}))
    breathe(c, t + 14, 1300, depth=1.3, period=40)

    # ---------------- P4 FALLING STAR ----------------
    tl.phase("FALLING_STAR", 1300, 1820)
    c.k(1310, "smooth", arms={"R": dict(grip=(1.3, -0.9, 0.3), blade=(0.3, -0.45, 1.0), up=(0, 1, 0))}, feet=PIN)
    t = sky_raise(c, 1310, dur=90)
    tl.marker(1340, "SKY_RIFT")
    tl.marker(1420, "METEOR_APPEAR")
    tl.marker(1430, "METEOR_FALL")
    tl.fx(1420, tremble=0.4)
    c.k(1500, "sine_io", lt=(4, 4, 0, 0, -0.32, 0), ut=(12, 6, 0), head=(32, 2, 0))
    tl.fx(1560, tremble=1.6)
    t = point_down(c, 1584, dur=18)
    tl.fx(t + 2, tremble=0.0)
    tl.marker(1650, "SPECTER_SHIELD")
    tl.marker(1662, "METEOR_IMPACT")
    tl.marker(1662, "IMPACT_FRAME", "1")
    tl.marker(1666, "SHOCKWAVE", "meteor")
    tl.marker(1668, "DEBRIS", "meteor")
    tl.marker(1700, "SHOCKWAVE", "meteor_2")
    tl.marker(1710, "BLAST_ARRIVES")
    tl.wind(1700, y=10.0, z=8.0)
    tl.wind(1712, y=30.0, z=180.0)
    tl.wind(1800, y=8.0, z=30.0)
    c.k(1660, "smooth", lt=(-4, -6, 0, 0, -0.5, 0), ut=(-8, -10, 0), head=(4, 4, 0),
        arms={"L": dict(grip=(-0.6, 0.2, -1.4), blade=(0.0, 0.3, -1.0), up=(0, 1, 0), space="ut")})
    c.k(1714, "out3", lt=(-10, -4, 0, 0, -0.75, 0.25), ut=(-16, -8, 0), head=(-4, 2, 0),
        arms={"L": dict(grip=(-0.5, 0.5, -1.1), blade=(0.3, 0.6, -0.8), up=(0, 0, 1), space="ut")})
    c.k(1790, "smooth", lt=(-8, -4, 0, 0, -0.7, 0.2), ut=(-14, -8, 0), head=(-2, 2, 0))

    # ---------------- P5 FADE ----------------
    tl.phase("FADE", 1820, 2040)
    tl.marker(1830, "SPECTER_FADE")
    tl.marker(1860, "EMBER_RAIN")
    stance(c, 1880)
    end = 2040
    breathe(c, 1880, end)
    tl.marker(end - 40, "DISSIPATE")
    tl.marker(end - 20, "RECOVERY")
    tl.marker(end, "END")
    print("TIMELINE", META["name"], "end frame", end, "=", round(end / 60, 2), "s")
    return tl
