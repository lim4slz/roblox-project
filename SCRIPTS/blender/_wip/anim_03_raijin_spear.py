"""ANIM_03 — RAIJIN SPEAR  (~31 s @ 60 fps)
Inspirado em Chidori / Kirin (Naruto Shippuden — Sasuke). Execução
original: relâmpago condensado na mão livre arrastada pelo chão, três
investidas perfurantes em zigue-zague, depois a tempestade é convocada e um
dragão de relâmpago desce das nuvens sobre o alvo.

  P1 FORM     0-420     agacha, mão esquerda no chão: o relâmpago nasce e
                        "chilreia"; a mão arrasta pelo chão (cicatriz
                        elétrica), tremor crescente, pico
  P2 PIERCE   420-1000  3 investidas perfurantes (20/18/22 studs) com
                        curvas de 150/160 graus, explosão elétrica em cada
  P3 STORM    1000-1400 de pé, braço ao céu: nuvens de tempestade, raios
                        dentro das nuvens, vento crescente
  P4 KIRIN    1400-1650 o braço desce apontando: o dragão de relâmpago
                        mergulha e atinge o alvo (flash, impact frames em
                        P&B, pilar, cratera, onda de choque)
  P5 AFTER    1650-1860 faíscas residuais, abaixa o braço, guarda
"""

import anim_engine as ae
from moves_full import F, PIN, Ctx, breathe, guard, pierce_dash, point_down, sky_raise, stance, step

META = dict(
    id="ANIM_03",
    name="ANIM_03_RAIJIN_SPEAR",
    inspired_by="Chidori / Kirin — Naruto Shippuden",
    concept="Relâmpago na mão, investidas perfurantes e um dragão de relâmpago que cai do céu",
    camera=dict(loc=(14.0, 8.0, 1.0), target=(0.0, 3.0, -0.4), lens=24, track=0.9),
    video_step=2,
)


def build():
    tl = ae.Timeline(META["name"], 0, 1860)
    tl.lag = {"UpperTorso": 0.6, "Head": 2.0, "RightUpperArm": 0.8, "RightLowerArm": 1.5, "RightHand": 2.2,
              "LeftUpperArm": 0.5, "LeftLowerArm": 1.0, "LeftHand": 1.5}
    tl.noise = {"UpperTorso": 0.35, "Head": 0.5, "LowerTorso": 0.2}
    tl.tremble = {"LeftUpperArm": 1.0, "LeftLowerArm": 1.3, "LeftHand": 1.8, "UpperTorso": 0.5, "Head": 0.4}
    tl.scarf_params = dict(gravity=42.0, drag=3.2, stiffness=10.0)
    c = Ctx(tl)
    tl.fx(0, gain=1.0, tremble=0.0)

    # ---------------- P1 FORM ----------------
    tl.phase("FORM", 0, 420)
    stance(c, 0)
    c.root_key(0)
    tl.marker(2, "CAST_START")
    breathe(c, 0, 40)
    c.k(90, "smooth", lt=(-14, 10, 0, 0, -1.05, 0.1), ut=(-22, -8, 0), head=(26, 4, 0),
        arms={"L": dict(grip=(-0.95, -2.45, -1.05), blade=(0.1, -0.2, -1.0), up=(0, 1, 0), pole=(-1, -0.4, 0.4)),
              "R": dict(grip=(1.3, -1.2, 0.65), blade=(0.25, -0.2, 1.0), up=(0, 1, 0))},
        feet=F(l=dict(x=-0.75, z=-0.55, yaw=8), r=dict(x=0.8, z=0.75, yaw=-24)))
    tl.marker(92, "LIGHTNING_FORM")
    for k_, f in enumerate((120, 180, 240, 300, 360)):
        tl.marker(f, "CHIRP", str(k_ + 1))
    tl.fx(92, tremble=0.6)
    # hand drags across the ground, body shifting with it
    c.k(220, "smooth", lt=(-15, -4, 0, 0, -1.1, 0.12), ut=(-24, -16, 0), head=(26, 14, 0),
        arms={"L": dict(grip=(-0.2, -2.5, -1.2), blade=(0.3, -0.2, -1.0), up=(0, 1, 0), pole=(-1, -0.4, 0.4))})
    tl.marker(140, "GROUND_SCAR")
    tl.fx(220, tremble=1.4)
    c.k(330, "smooth", lt=(-16, -16, 0, 0, -1.12, 0.12), ut=(-24, -26, 0), head=(26, 24, 0),
        arms={"L": dict(grip=(0.45, -2.45, -0.95), blade=(0.5, -0.2, -0.8), up=(0, 1, 0), pole=(-1, -0.4, 0.4))})
    tl.fx(330, tremble=2.2)
    c.k(400, "smooth", lt=(-12, 6, 0, 0, -1.0, 0.1), ut=(-18, -4, 0), head=(22, 2, 0),
        arms={"L": dict(grip=(-0.55, -1.25, -1.2), blade=(0.0, 0.3, -1.0), up=(0, 1, 0), pole=(-1, -0.6, 0.3))})
    tl.marker(392, "LIGHTNING_PEAK")
    tl.fx(406, tremble=0.0)

    # ---------------- P2 PIERCE ----------------
    tl.phase("PIERCE", 420, 1000)
    t = pierce_dash(c, 410, d=20.0, turn_after=150.0)
    t = pierce_dash(c, t + 18, d=18.0, turn_after=-160.0)
    t = pierce_dash(c, t + 16, d=22.0, turn_after=0.0)
    guard(c, t + 14, crouch=-0.55, feet=F(l=dict(x=-0.8, z=0.4, yaw=18), r=dict(x=0.7, z=-0.45, yaw=-10)))
    tl.marker(t + 30, "FIZZLE")
    t = breathe(c, t + 16, max(t + 60, 1000), depth=1.6, period=34)

    # ---------------- P3 STORM ----------------
    tl.phase("STORM", t, t + 400)
    t0 = t
    c.k(t0 + 20, "smooth", lt=(0, 4, 0, 0, -0.32, 0), ut=(-2, 0, 0), head=(6, 0, 0),
        arms={"R": dict(grip=(1.3, -0.9, 0.3), blade=(0.3, -0.45, 1.0), up=(0, 1, 0))},
        feet=F(l=dict(x=-0.62, z=0.15, yaw=8), r=dict(x=0.6, z=-0.12, yaw=-8)))
    t = sky_raise(c, t0 + 20, dur=60)
    tl.marker(t0 + 40, "STORM_CLOUDS")
    for k_, off in enumerate((120, 190, 260, 320)):
        tl.marker(t0 + off, "CLOUD_FLASH", str(k_ + 1))
    tl.wind(t0 + 40, z=10.0)
    tl.wind(t0 + 340, y=6.0, z=60.0)
    tl.fx(t0 + 80, tremble=0.3)
    c.k(t0 + 200, "sine_io", lt=(2, 8, 0, 0, -0.3, 0), ut=(12, 10, 0), head=(30, 4, 0),
        arms={"L": dict(grip=(-0.72, 2.32, -0.25), blade=(0.0, 1.0, 0.05), up=(0, 0, -1), space="ut",
                        pole=(-1, 0.2, 0.6))})
    tl.fx(t0 + 340, tremble=1.8)
    c.k(t0 + 360, "smooth", lt=(4, 6, 0, 0, -0.34, 0), ut=(14, 8, 0), head=(14, -6, 0))

    # ---------------- P4 KIRIN ----------------
    tl.phase("KIRIN", t0 + 380, t0 + 650)
    t = point_down(c, t0 + 382, dur=16)
    tl.fx(t, tremble=0.0)
    tl.marker(t, "DRAGON_DESCEND")
    strike = t + 60
    tl.marker(strike, "KIRIN_STRIKE")
    tl.marker(strike, "IMPACT_FRAME", "1")
    tl.marker(strike + 3, "IMPACT_FRAME", "2")
    tl.marker(strike + 2, "SHOCKWAVE", "kirin")
    tl.marker(strike + 4, "DEBRIS", "kirin")
    tl.marker(strike + 30, "SHOCKWAVE", "kirin2")
    tl.wind(strike, y=20.0, z=150.0)
    tl.wind(strike + 120, y=6.0, z=30.0)
    c.k(strike + 4, "out3", lt=(-2, -6, 0, 0, -0.42, 0.15), ut=(-2, -8, 0), head=(2, 4, 0))
    c.k(strike + 120, "smooth", lt=(-3, -8, 0, 0, -0.44, 0.1), ut=(-5, -10, 0), head=(4, 6, 0))

    # ---------------- P5 AFTER ----------------
    tl.phase("AFTERMATH", strike + 140, 1860)
    t = strike + 150
    c.k(t, "smooth", lt=(-1, 6, 0, 0, -0.38, 0), ut=(-4, -4, 0), head=(4, 4, 0),
        arms={"L": dict(grip=(-1.15, -0.8, -0.45), blade=(0.1, -0.5, -1.0), up=(0, 1, 0))}, feet=PIN)
    tl.marker(t, "SPARK_RESIDUE")
    stance(c, t + 40)
    end = max(1860, t + 120)
    tl.frame_end = end
    breathe(c, t + 40, end)
    tl.marker(end - 40, "DISSIPATE")
    tl.marker(end - 20, "RECOVERY")
    tl.marker(end, "END")
    print("TIMELINE", META["name"], "end frame", end, "=", round(end / 60, 2), "s")
    return tl
