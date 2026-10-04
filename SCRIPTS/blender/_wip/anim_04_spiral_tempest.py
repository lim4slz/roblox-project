"""ANIM_04 — SPIRAL TEMPEST  (~31 s @ 60 fps)
Inspirado em Rasengan / Rasenshuriken (Naruto). Execução original, mãos
livres (a lâmina fica oculta nesta habilidade): selos -> esfera espiral
moldada com as duas mãos -> investida e cratera espiral -> rajada de seis
mini-esferas -> esfera gigante com quatro lâminas giratórias erguida acima
da cabeça, arremessada, explode numa cúpula de vento cortante.

  P1 SEALS     0-300     10 selos rápidos, selo final + explosão de aura
  P2 SPHERE    300-700   mão esquerda espalmada, a direita gira acima
                         formando a esfera, investida de 14 studs,
                         SPIRAL_IMPACT + moagem (o corpo empurra)
  P3 BARRAGE   700-1100  6 golpes de palma alternados com passos laterais
  P4 SHURIKEN  1100-1640 esfera com lâminas acima da cabeça (cresce em 3
                         estágios), arremesso por cima, voo, cúpula de vento
  P5 AFTER     1640-1860 respiração pesada, guarda
"""

import math

import anim_engine as ae
from moves_full import (F, PIN, Ctx, breathe, dash, guard, overhead_throw, palm_strike, seals, stance, step)

META = dict(
    id="ANIM_04",
    name="ANIM_04_SPIRAL_TEMPEST",
    inspired_by="Rasengan / Rasenshuriken — Naruto",
    concept="Esfera espiral moldada à mão, cratera, rajada e uma shuriken de vento gigante",
    camera=dict(loc=(13.0, 10.0, 1.2), target=(0.0, 4.0, -0.2), lens=26, track=0.9),
    video_step=2,
    hide_blade=True,
)


def build():
    tl = ae.Timeline(META["name"], 0, 1860)
    tl.blade_hidden = True
    tl.lag = {"UpperTorso": 0.6, "Head": 2.0, "RightUpperArm": 0.4, "RightLowerArm": 0.8, "RightHand": 1.2,
              "LeftUpperArm": 0.4, "LeftLowerArm": 0.8, "LeftHand": 1.2}
    tl.noise = {"UpperTorso": 0.35, "Head": 0.5, "LowerTorso": 0.2}
    tl.tremble = {"RightUpperArm": 0.8, "RightLowerArm": 1.0, "RightHand": 1.3, "LeftUpperArm": 0.8,
                  "LeftLowerArm": 1.0, "LeftHand": 1.3, "UpperTorso": 0.5}
    tl.scarf_params = dict(gravity=42.0, drag=3.2, stiffness=10.0)
    c = Ctx(tl)
    tl.fx(0, gain=1.0, tremble=0.0)

    # ---------------- P1 SEALS ----------------
    tl.phase("SEALS", 0, 300)
    c.k(0, "smooth", lt=(0, 6, 0, 0, -0.35, 0), ut=(-4, -6, 0), head=(2, 4, 0),
        arms={"R": dict(grip=(1.2, -0.8, -0.4), blade=(0.1, -0.4, -1.0), up=(0, 1, 0)),
              "L": dict(grip=(-1.2, -0.8, -0.4), blade=(-0.1, -0.4, -1.0), up=(0, 1, 0))},
        feet=F(l=dict(x=-0.7, z=0.25, yaw=14), r=dict(x=0.62, z=-0.3, yaw=-10)))
    c.root_key(0)
    tl.marker(2, "CAST_START")
    breathe(c, 0, 36)
    c.k(44, "smooth", lt=(-4, 0, 0, 0, -0.5, 0), ut=(-8, 0, 0), head=(-6, 0, 0), feet=PIN)
    t = seals(c, 44, n=10, every=14)
    c.k(t + 10, "out3", lt=(-6, 0, 0, 0, -0.62, 0), ut=(-10, 0, 0), head=(4, 0, 0),
        arms={"R": dict(grip=(0.06, 0.2, -0.95), blade=(0.0, 1.0, -0.1), up=(0, 0, 1), space="ut"),
              "L": dict(grip=(-0.06, 0.2, -0.95), blade=(0.0, 1.0, -0.1), up=(0, 0, 1), space="ut",
                        pole=(-1, -0.8, 0.4))})
    tl.marker(t + 10, "AURA_BURST")
    tl.fx(t + 10, tremble=1.0)
    tl.fx(t + 60, tremble=0.0)
    c.k(max(t + 70, 290), "smooth", lt=(-5, 0, 0, 0, -0.6, 0), ut=(-9, 0, 0), head=(2, 0, 0))

    # ---------------- P2 SPHERE ----------------
    tl.phase("SPHERE", 300, 700)
    base = (-0.3, 0.05, -1.2)
    c.k(310, "smooth", lt=(-4, 10, 0, 0, -0.55, 0), ut=(-6, 14, 0), head=(-10, -8, 0),
        arms={"L": dict(grip=base, blade=(0.2, 0.0, -1.0), up=(0, 1, 0), space="ut", pole=(-1, -0.8, 0.4)),
              "R": dict(grip=(-0.25, 0.5, -1.15), blade=(0.0, -0.3, -1.0), up=(0, 0, 1), space="ut")})
    tl.marker(310, "SPHERE_FORM")
    for i in range(12):
        a = i * math.pi / 2
        f = 322 + i * 9
        c.k(f, "smooth", arms={"R": dict(grip=(-0.3 + 0.32 * math.cos(a), 0.5, -1.2 + 0.32 * math.sin(a)),
                                         blade=(-math.sin(a) * 0.5, -0.4, -1.0), up=(0, 0, 1), space="ut")})
    tl.marker(380, "SPHERE_GROW")
    tl.fx(330, tremble=0.4)
    tl.fx(430, tremble=1.4)
    # transfer to the right palm and charge
    c.k(440, "smooth", lt=(-10, -10, 0, 0, -0.85, 0.1), ut=(-14, -16, 0), head=(14, 12, 0),
        arms={"R": dict(grip=(0.9, -0.1, -1.0), blade=(0.0, 0.3, -1.0), up=(0, 1, 0), space="ut"),
              "L": dict(grip=(-1.2, -0.4, -0.6), blade=(0.0, -0.3, -1.0), up=(0, 1, 0), space="ut")},
        feet=PIN)
    tl.fx(446, tremble=0.0)
    tl.marker(440, "SPHERE_TRANSFER")
    t = dash(c, 446, d=14.0, slash=False)
    palm = dict(grip=(0.45, 0.4, -1.62), blade=(0.0, 0.2, -1.0), up=(0, 1, 0), space="ut", pole=(1, -0.6, 0.2))
    for off in (9, 14, 19):
        c.k(446 + off, "smooth", arms={"R": dict(palm), "L": dict(grip=(-1.4, -0.3, 0.7), blade=(-0.4, -0.3, 0.8),
                                                                  up=(0, 1, 0), space="ut")})
    tl.marker(446 + 19, "SPIRAL_IMPACT")
    tl.marker(446 + 20, "SHOCKWAVE", "spiral")
    tl.fx(446 + 20, tremble=2.4)
    c.k(446 + 50, "smooth", lt=(-16, 4, 0, 0, -1.05, -0.25), ut=(-20, 8, 0), head=(18, -4, 0),
        arms={"R": dict(grip=(0.42, 0.35, -1.65), blade=(0.0, 0.2, -1.0), up=(0, 1, 0), space="ut",
                        pole=(1, -0.6, 0.2))})
    tl.marker(446 + 50, "SPIRAL_BLAST")
    tl.fx(446 + 52, tremble=0.0)
    guard(c, 446 + 80, crouch=-0.5, feet=F(l={}, r={}))
    t = breathe(c, 446 + 84, 700, depth=1.6, period=34)

    # ---------------- P3 BARRAGE ----------------
    tl.phase("BARRAGE", 700, 1100)
    t = 700
    for i in range(6):
        hand = "L" if i % 2 == 0 else "R"
        t = palm_strike(c, t, hand=hand, travel=0.6, value=str(i + 1))
        if i % 2 == 1:
            t = step(c, t, dur=16, d=0.0, lateral=1.4 if i % 4 == 1 else -1.4, lead="R" if i % 4 == 1 else "L")
    guard(c, t + 8, crouch=-0.5, feet=F(l={}, r={}))
    t = breathe(c, t + 10, 1100, depth=1.6, period=34)

    # ---------------- P4 SHURIKEN ----------------
    tl.phase("SHURIKEN", 1100, 1640)
    c.k(1130, "smooth", lt=(2, -6, 0, 0, -0.55, 0.05), ut=(10, -10, 0), head=(20, 6, 0),
        arms={"R": dict(grip=(0.65, 1.65, -0.35), blade=(0.0, 1.0, 0.1), up=(0, 0, -1), space="ut",
                        pole=(1, 0, 0.6)),
              "L": dict(grip=(-0.25, 1.2, -0.7), blade=(0.4, 0.8, -0.2), up=(0, 0, 1), space="ut",
                        pole=(-1, -0.4, 0.4))},
        feet=F(l=dict(x=-0.82, z=0.35, yaw=18), r=dict(x=0.75, z=-0.35, yaw=-12)))
    tl.marker(1124, "SHURIKEN_FORM")
    tl.marker(1250, "SHURIKEN_GROW", "2")
    tl.marker(1350, "SHURIKEN_GROW", "3")
    tl.wind(1124, z=8.0)
    tl.wind(1380, y=10.0, z=40.0)
    for i, f in enumerate((1200, 1280, 1360, 1420)):
        c.k(f, "sine_io", lt=(2 + i, -6 + 3 * (i % 2), 0, 0, -0.6 - 0.05 * i, 0.05), ut=(10 + i, -10, 0),
            head=(22, 6, 0))
        tl.fx(f, tremble=0.5 + 0.5 * i)
    t = overhead_throw(c, 1436)
    tl.fx(t - 20, tremble=0.0)
    tl.marker(1458, "SHURIKEN_FLY")
    tl.marker(1500, "SHURIKEN_DOME")
    tl.marker(1500, "SHOCKWAVE", "dome")
    tl.marker(1620, "DOME_COLLAPSE")
    tl.wind(1500, y=10.0, z=120.0)
    tl.wind(1640, y=4.0, z=15.0)
    c.k(1560, "smooth", lt=(-6, 10, 0, 0, -0.6, -0.1), ut=(-8, 12, 0), head=(6, -6, 0))

    # ---------------- P5 AFTER ----------------
    tl.phase("AFTERMATH", 1640, 1860)
    guard(c, 1660, crouch=-0.5, feet=F(l={}, r={}))
    c.k(1660, "smooth", arms={"R": dict(grip=(1.2, -0.8, -0.4), blade=(0.1, -0.4, -1.0), up=(0, 1, 0)),
                              "L": dict(grip=(-1.2, -0.8, -0.4), blade=(-0.1, -0.4, -1.0), up=(0, 1, 0))})
    end = 1860
    t = breathe(c, 1664, end, depth=2.2, period=40)
    tl.marker(end - 40, "DISSIPATE")
    tl.marker(end - 20, "RECOVERY")
    tl.marker(end, "END")
    print("TIMELINE", META["name"], "end frame", end, "=", round(end / 60, 2), "s")
    return tl
