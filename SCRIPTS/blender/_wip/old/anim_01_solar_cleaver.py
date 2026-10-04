"""ANIM_01 — SOLAR CLEAVER: "Forma Solar Completa" (32.0 s @ 60 fps)

Ataque de alto impacto expandido para uma sequência cinematográfica.
Cinco fases com intensidade crescente; o salto com corte que racha o chão
é o motivo recorrente (1x, depois 3x em marcha, depois a versão gigante).

  P1 IGNIÇÃO      0-262    respiração, ritual de ignição (palma corre a
                           lâmina), giro da lâmina, calor acumulando
  P2 KATA         262-620  aproximação + 5 cortes pesados encadeados
                           (diagonal, ascendente, horizontal, giro aéreo 360,
                           vertical) com passos reais
  P3 CLEAVER      620-900  carga sobre a cabeça (tremor crescente) -> salto
                           com corte -> impacto -> lâmina arrancada + flick
  P4 MARCHA       900-1200 três cortes saltados em sequência, cada um maior,
                           avançando; caminhada pesada pelo fogo
  P5 FINAL        1200-1920 mortal para trás, carga máxima, corte solar
                           gigante (FINAL_IMPACT + erupção em linha), vira de
                           costas para a erupção, retorna, giro da lâmina,
                           guarda
"""

import anim_engine as ae
from moves import (Ctx, F, PIN, backflip, breathe, charge_overhead, cut, guard, ignite, leap_cleave,
                   pull_flick, spin_cut, stance, step, twirl, walk)

META = dict(
    id="ANIM_01",
    name="ANIM_01_SOLAR_CLEAVER",
    concept="Forma solar completa: kata pesada, três cortes que racham o chão e um corte solar final",
    camera=dict(loc=(15.0, 6.0, 1.2), target=(0.0, 3.0, -0.6), lens=24, track=0.9),
    video_step=2,
)


def build():
    tl = ae.Timeline(META["name"], 0, 1920)
    tl.lag = {"UpperTorso": 0.6, "Head": 2.0, "RightUpperArm": 0.4, "RightLowerArm": 0.8,
              "RightHand": 1.0, "LeftUpperArm": 1.0, "LeftLowerArm": 2.0, "LeftHand": 3.0}
    tl.noise = {"UpperTorso": 0.35, "Head": 0.5, "LowerTorso": 0.15}
    tl.tremble = {"UpperTorso": 0.4, "Head": 0.3, "RightUpperArm": 0.7, "RightLowerArm": 0.8, "RightHand": 0.9}
    tl.scarf_params = dict(gravity=45.0, drag=4.0, stiffness=14.0)
    c = Ctx(tl)
    tl.fx(0, gain=1.0, tremble=0.0)

    # ---------------- P1 IGNIÇÃO ----------------
    tl.phase("IGNITION", 0, 262)
    stance(c, 0)
    c.root_key(0)
    tl.marker(2, "CAST_START")
    t = breathe(c, 0, 60)
    t = ignite(c, 60)
    t = twirl(c, t + 2, dur=24)
    guard(c, t + 10, crouch=-0.5, feet=PIN)
    tl.marker(t + 20, "HEAT", "build")
    t = breathe(c, t + 12, 262, depth=1.4, period=40)

    # ---------------- P2 KATA ----------------
    tl.phase("KATA", 262, 620)
    t = step(c, max(t, 262), dur=30, d=1.6, lead="R")
    t = cut(c, t + 2, "diag_a", wind=14, travel=1.3)
    t = cut(c, t - 4, "rise", wind=10)
    t = cut(c, t - 2, "h_rl", wind=12, travel=1.2)
    guard(c, t + 4, crouch=-0.6, feet=PIN)
    t = spin_cut(c, t + 4, hop=1.0, travel=1.6)
    t = cut(c, t, "down", wind=16, travel=1.0, crouch=-0.8, hit_marker="SLASH")
    tl.marker(t - 12, "IMPACT_MINOR", "down")
    guard(c, t + 8, crouch=-0.5, feet=F(l={}, r={}))
    t = breathe(c, t + 10, 620, depth=1.6, period=36)

    # ---------------- P3 CLEAVER ----------------
    tl.phase("CLEAVER", 620, 900)
    t = charge_overhead(c, max(t, 620), dur=110)
    t = leap_cleave(c, t - 10, scale=1.0, travel=2.6, hold=24)
    tl.marker(t - 12, "SECONDARY_BURST", "crack_eruption")
    t = pull_flick(c, t)
    guard(c, t + 10, crouch=-0.5, feet=F(l={}, r={}))
    t = breathe(c, t + 12, 900, depth=1.5, period=38)

    # ---------------- P4 MARCHA ----------------
    tl.phase("MARCH", 900, 1200)
    t = leap_cleave(c, max(t, 900), scale=0.6, travel=2.0, hold=8)
    t = leap_cleave(c, t - 6, scale=0.75, travel=2.3, hold=8)
    t = leap_cleave(c, t - 6, scale=0.9, travel=2.6, hold=16)
    tl.marker(t - 6, "SECONDARY_BURST", "crack_eruption")
    t = pull_flick(c, t)
    guard(c, t + 8, crouch=-0.42, feet=F(l={}, r={}))
    t = walk(c, t + 10, steps=3, stride=1.6, step_frames=30)
    guard(c, t + 6, crouch=-0.45, feet=F(l={}, r={}))

    # ---------------- P5 FINAL ----------------
    tl.phase("FINALE", 1200, 1920)
    t = backflip(c, max(t + 12, 1200), back=3.4, height=2.2)
    t = charge_overhead(c, t + 2, dur=150, crouch=-0.78)
    tl.marker(t - 60, "CHARGE_MAX")
    t = leap_cleave(c, t - 10, scale=1.35, travel=5.5, hold=46, impact_marker="FINAL_IMPACT")
    tl.marker(t - 34, "ERUPTION", "line")
    t = pull_flick(c, t + 6)
    # turn the back on the eruption
    t = step(c, t + 6, dur=34, d=0.8, turn=180, lead="L",
             end_feet=F(l=dict(x=-0.62, z=0.2, yaw=10), r=dict(x=0.6, z=-0.15, yaw=-6)))
    c.k(t + 6, "smooth", lt=(0, 4, 0, 0, -0.32, 0), ut=(-2, -4, 0), head=(4, -38, 0),
        arms={"R": dict(grip=(1.45, -0.85, 0.35), blade=(0.6, -0.55, 0.55), up=(0, 1, 0)),
              "L": dict(grip=(-1.1, -0.95, -0.2), blade=(0.1, -0.5, -1.0), up=(0, 1, 0))},
        feet=PIN)
    tl.marker(t + 10, "AFTERMATH", "back_to_fire")
    c.k(t + 60, "sine_io", lt=(1, 6, 0, 0, -0.3, 0), ut=(-1, -2, 0), head=(6, -44, 0), feet=PIN)
    c.k(t + 90, "sine_io", head=(2, -20, 0), feet=PIN)
    t = step(c, t + 92, dur=34, d=0.6, turn=-180, lead="R")
    t = twirl(c, t + 4, dur=26)
    stance(c, t + 16)
    end = max(1920, t + 90)
    tl.frame_end = end
    t = breathe(c, t + 16, end, depth=1.0, period=56)
    tl.marker(end - 40, "DISSIPATE")
    tl.marker(end - 20, "RECOVERY")
    tl.marker(end, "END")
    print("TIMELINE", META["name"], "end frame", end, "=", round(end / 60, 2), "s")
    return tl
