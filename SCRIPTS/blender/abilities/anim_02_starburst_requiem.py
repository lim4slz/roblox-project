"""ANIM_02 — STARBURST REQUIEM  (~31 s @ 60 fps)
Inspirado em "Starburst Stream" (Sword Art Online). Execução original:
segunda lâmina materializada de luz, ativação em guarda X, sequência de 16
golpes alternando as mãos com ritmo que ACELERA (36 -> 24 -> 15 frames por
golpe), estocada final em câmera-lenta que explode, seguida de um
"overdrive" aéreo e um X no chão.

  P1 DRAW        0-250     respiração, saque da segunda lâmina (materializa),
                           guarda X: SKILL_ACTIVATE (lâminas acendem)
  P2 STARBURST   250-~900  16 golpes encadeados com passos; afterimages nos
                           golpes rápidos; HIT 16 = estocada + STARBURST_FINAL
  P3 OVERDRIVE   ~900-1450 recua, lançador duplo, giro aéreo com as duas
                           lâminas abertas, X cruzado no chão, mortal para
                           trás, mini-rajada de 4 golpes
  P4 FINALE      ~1450-1860 lâminas sacudidas, a segunda se desfaz em luz,
                           giro da lâmina, guarda
"""

import anim_engine as ae
from moves import (
    F,
    PIN,
    Ctx,
    backflip,
    breathe,
    cut,
    draw_second,
    dual_cross_down,
    dual_open,
    dual_rise,
    final_thrust,
    guard,
    spin_cut,
    stance,
    step,
    twirl,
    x_guard,
)

META = dict(
    id="ANIM_02",
    name="ANIM_02_STARBURST_REQUIEM",
    inspired_by="Starburst Stream — Sword Art Online",
    concept="Duas lâminas, 16 golpes acelerando em luz azul, estocada final explosiva e overdrive aéreo",
    camera=dict(loc=(13.0, 10.0, 1.4), target=(0.0, 4.0, -0.4), lens=26, track=0.9),
    video_step=2,
)

SEQUENCE = [
    # hand, kind, wind, settle, travel, strike, follow
    ("R", "diag_a", 14, 10, 1.0, 3, 5),
    ("L", "diag_a", 12, 10, 0.0, 3, 5),
    ("R", "h_rl", 12, 8, 0.8, 3, 5),
    ("L", "h_rl", 12, 8, 0.0, 3, 5),
    ("R", "rise", 9, 6, 0.0, 3, 4),
    ("L", "rise", 9, 6, 0.6, 3, 4),
    ("R", "diag_b", 8, 6, 0.0, 2, 4),
    ("L", "diag_b", 8, 6, 0.0, 2, 4),
    ("R", "thrust", 8, 6, 0.8, 2, 4),
    ("L", "thrust", 8, 6, 0.0, 2, 4),
    ("R", "h_lr", 6, 4, 0.0, 2, 3),
    ("L", "h_lr", 6, 4, 0.0, 2, 3),
    ("R", "diag_a", 5, 4, 0.6, 2, 3),
    ("L", "diag_a", 5, 4, 0.0, 2, 3),
    ("R", "down", 5, 4, 0.0, 2, 3),
]


def build():
    tl = ae.Timeline(META["name"], 0, 1860)
    tl.dual = True
    tl.lag = {
        "UpperTorso": 0.5,
        "Head": 1.8,
        "RightUpperArm": 0.3,
        "RightLowerArm": 0.6,
        "RightHand": 0.8,
        "LeftUpperArm": 0.3,
        "LeftLowerArm": 0.6,
        "LeftHand": 0.8,
    }
    tl.noise = {"UpperTorso": 0.3, "Head": 0.45, "LowerTorso": 0.15}
    tl.tremble = {
        "UpperTorso": 0.4,
        "RightUpperArm": 0.7,
        "RightLowerArm": 0.7,
        "LeftUpperArm": 0.7,
        "LeftLowerArm": 0.7,
        "Head": 0.3,
    }
    tl.scarf_params = dict(gravity=44.0, drag=3.4, stiffness=10.0)
    c = Ctx(tl)
    tl.fx(0, gain=1.0, tremble=0.0)

    # ---------------- P1 DRAW ----------------
    tl.phase("DRAW", 0, 250)
    stance(c, 0)
    c.root_key(0)
    tl.marker(2, "CAST_START")
    t = breathe(c, 0, 80)
    t = draw_second(c, t)
    t = x_guard(c, t + 4, hold=60)
    t = dual_open(c, max(t, 240))

    # ---------------- P2 STARBURST ----------------
    tl.phase("STARBURST", 250, t + 700)
    for i, (hand, kind, wind, settle, travel, strike, follow) in enumerate(SEQUENCE, start=1):
        start = t - (4 if i > 1 else 0)
        t = cut(
            c,
            start,
            kind,
            wind=wind,
            travel=travel,
            crouch=-0.65 - 0.02 * i,
            settle=settle,
            hit_marker="HIT",
            hand=hand,
            hit_value=str(i),
            strike=strike,
            follow=follow,
            intensity=1.0 + i * 0.04,
        )
        if i >= 11:
            tl.marker(t - settle - 2, "AFTERIMAGE", str(i))
    t = final_thrust(c, t - 2, travel=2.5)
    p2_end = t
    tl.phases[-1] = ("STARBURST", 250, p2_end)

    # ---------------- P3 OVERDRIVE ----------------
    tl.phase("OVERDRIVE", p2_end, p2_end + 520)
    t = step(
        c, t + 4, dur=26, d=-1.6, lead="L", end_feet=F(l=dict(x=-0.8, z=0.5, yaw=20), r=dict(x=0.7, z=-0.55, yaw=-10))
    )
    t = dual_rise(c, t)
    # airborne spin with both blades thrown wide
    c.k(
        t + 6, "smooth", arms={"L": dict(grip=(-1.55, -0.05, 0.35), blade=(-0.85, 0.0, 0.75), up=(0, 1, 0), space="ut")}
    )
    t = spin_cut(c, t, hop=1.3, travel=2.0)
    tl.marker(t - 20, "HIT", "spin_dual")
    t = dual_cross_down(c, t)
    guard(c, t + 8, crouch=-0.55, feet=PIN)
    t = backflip(c, t + 10, back=3.0, height=2.0)
    for j, (hand, kind) in enumerate((("R", "h_rl"), ("L", "h_rl"), ("R", "diag_b"), ("L", "diag_b"))):
        t = cut(
            c,
            t - (3 if j else 0),
            kind,
            wind=5,
            travel=0.7 if j % 2 == 0 else 0.0,
            settle=4,
            hit_marker="HIT",
            hand=hand,
            hit_value=f"od{j + 1}",
            strike=2,
            follow=3,
        )
        tl.marker(t - 6, "AFTERIMAGE", f"od{j + 1}")
    tl.phases[-1] = ("OVERDRIVE", p2_end, t)

    # ---------------- P4 FINALE ----------------
    tl.phase("FINALE", t, 1860)
    c.k(
        t + 16,
        "out3",
        lt=(-4, 0, 0, 0, -0.55, 0),
        ut=(-4, 0, 0),
        head=(6, 0, 0),
        arms={
            "R": dict(grip=(1.55, -0.6, -0.1), blade=(0.85, -0.5, 0.2), up=(0, 1, 0), space="ut"),
            "L": dict(grip=(-1.55, -0.6, -0.1), blade=(-0.85, -0.5, 0.2), up=(0, 1, 0), space="ut"),
        },
        feet=F(l=dict(x=-0.75, z=0.3, yaw=16), r=dict(x=0.7, z=-0.3, yaw=-12)),
    )
    tl.marker(t + 16, "BLADE_SHED")
    c.k(
        t + 70,
        "smooth",
        lt=(-2, 6, 0, 0, -0.42, 0),
        ut=(-4, -4, 0),
        head=(4, 6, 0),
        arms={"L": dict(grip=(-1.15, -0.85, -0.3), blade=(0.0, -0.6, -1.0), up=(0, 1, 0))},
        feet=PIN,
    )
    tl.marker(t + 60, "DEMATERIALIZE", "azure")
    t = twirl(c, t + 80, dur=26)
    stance(c, t + 14)
    end = max(1860, t + 80)
    tl.frame_end = end
    t = breathe(c, t + 14, end)
    tl.marker(end - 40, "DISSIPATE")
    tl.marker(end - 20, "RECOVERY")
    tl.marker(end, "END")
    print("TIMELINE", META["name"], "end frame", end, "=", round(end / 60, 2), "s")
    return tl
