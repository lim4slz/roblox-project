"""
Cues e emissores de VFX. Um cue dispara num marker da animação e carrega uma
lista de camadas (emissores). O mesmo dado vai pro previs do Blender e pro
runtime do Roblox (gen_ability_data.py -> Abilities/<Nome>.luau).

Tipos de camada:
  part      partículas 3D (Parts) com curvas de tamanho/transparência/cor
  animate   um objeto só, no lugar, tocando as curvas (pulso, esfera, coluna)
  ring      anel de Beams com raio/largura animados
  lightning raios com bifurcação
  light     PointLight com curvas
  screen    ColorCorrection com curvas
  flash     overlay de tela (branco, preto, inverter)
  shake     tremor de câmera com falloff
  distort   esfera de vidro que entorta o fundo
  highlight Highlight no personagem

Curvas: [(t, valor)] ou [(t, valor, env)], t de 0 a 1 na vida da partícula.
Cores:  [(t, "NOME_DA_PALETA" ou (r, g, b))].
Ranges: número ou (min, max).
"""

PALETTE = {
    "CORE": (255, 248, 230),
    "GOLD": (255, 196, 64),
    "EMBER": (255, 120, 24),
    "CRIMSON": (214, 38, 30),
    "VIOLET": (150, 70, 255),
    "LILAC": (205, 160, 255),
    "VOID": (60, 16, 110),
    "ABYSS": (24, 6, 46),
    "ASH": (46, 40, 44),
    "DUST": (120, 108, 112),
    "STONE": (88, 80, 86),
    "INK": (8, 6, 10),
    "WHITE": (255, 255, 255),
    "AZURE": (70, 160, 255),
    "CYAN": (130, 235, 255),
    "ELECTRIC": (150, 200, 255),
    "STORM": (40, 40, 70),
    "WIND": (200, 240, 255),
    "BLUEFLAME": (120, 120, 255),
}

KINDS = (
    "part",
    "animate",
    "ring",
    "lightning",
    "light",
    "screen",
    "flash",
    "shake",
    "distort",
    "highlight",
    "fov",
    "sigil",
    "circuits",
    "helix",
    "orbs",
    "trail",
    "blade",
)


def cue(marker, fx, anchor=None, offset=0, layer="primary", when=None, **params):
    return {
        "marker": marker,
        "offset": offset,
        "fx": fx,
        "anchor": anchor,
        "layer": layer,
        "when": when,
        "params": params,
    }


def emit(marker, anchor, *layers, offset=0, when=None, tier="primary"):
    return cue(marker, "emit", anchor, offset=offset, layer=tier, when=when, layers=list(layers))


def _layer(kind, kw):
    kw = dict(kw)
    kw["kind"] = kind
    return kw


def part(**kw):
    return _layer("part", kw)


def animate(**kw):
    return _layer("animate", kw)


def ring(**kw):
    return _layer("ring", kw)


def lightning(**kw):
    return _layer("lightning", kw)


def light(**kw):
    return _layer("light", kw)


def screen(**kw):
    return _layer("screen", kw)


def flash(**kw):
    return _layer("flash", kw)


def shake(**kw):
    return _layer("shake", kw)


def distort(**kw):
    return _layer("distort", kw)


def highlight(**kw):
    return _layer("highlight", kw)


def special(kind, **kw):
    return _layer(kind, kw)


def fade(a=0.0, b=1.0, hold=0.0):
    pts = [(0.0, a)]
    if hold:
        pts.append((hold, a))
    pts.append((1.0, b))
    return pts


def fade_in_out(peak=0.0, edge=1.0, inn=0.12, out=0.6):
    return [(0.0, edge), (inn, peak), (out, peak), (1.0, edge)]


def grow(a, b, mid=None):
    return [(0.0, a), (0.5, mid), (1.0, b)] if mid is not None else [(0.0, a), (1.0, b)]


def _marker_frames(timing):
    occ, vals = {}, {}
    for m in timing["markers"]:
        occ.setdefault(m["name"], []).append(m["frame"])
        vals.setdefault(m["name"], []).append((m["frame"], m.get("value", "")))
    return occ, vals


def _next(frames, after):
    return next((e for e in frames if e >= after), frames[-1])


def resolve(cues, timing):
    """Liga cada cue aos frames dos markers. Markers repetidos geram um cue por
    ocorrência. Converte *_until / until em segundos e *_at em frame absoluto."""
    fps = timing["fps"]
    f0 = timing["frame_start"]
    occ, vals = _marker_frames(timing)
    used = {}
    out = []
    for c in cues:
        frames = occ.get(c["marker"])
        if c.get("when") is not None:
            frames = [fr for fr, v in vals.get(c["marker"], []) if v == c["when"]]
        if not frames:
            raise KeyError(f"cue usa marker que não existe: {c['marker']}")
        if c["marker"] in ("TRAIL_START", "TRAIL_END") and len(frames) > 1:
            key = (c["marker"], c["fx"], c["params"].get("on"))
            k = used.get(key, 0)
            used[key] = k + 1
            frames = [frames[min(k, len(frames) - 1)]]
        for fr in frames:
            d = dict(c)
            d["params"] = dict(c["params"])
            d["frame"] = fr + c["offset"]
            d["time"] = round((d["frame"] - f0) / fps, 4)

            def until(name, start):
                ends = occ.get(name)
                if not ends:
                    raise KeyError(f"until usa marker que não existe: {name}")
                return round((_next(ends, start) - start) / fps, 4)

            for key in [k for k in d["params"] if k.endswith("_at")]:
                at = occ.get(d["params"][key])
                if not at:
                    raise KeyError(f"{key} usa marker que não existe: {d['params'][key]}")
                d["params"][key] = _next(at, d["frame"])
            for key in ("dur_until", "grow_until", "hold_until", "linger_until"):
                if key in d["params"]:
                    d["params"][key.replace("_until", "")] = until(d["params"][key], d["frame"])
            if "layers" in d["params"]:
                layers = []
                for ly in d["params"]["layers"]:
                    ly = dict(ly)
                    start = d["frame"] + int(round(ly.get("delay", 0.0) * fps))
                    for key, target in (("until", "duration"), ("life_until", "lifetime"), ("hold_until", "hold")):
                        if key in ly:
                            ly[target] = until(ly.pop(key), start)
                    for key in [k for k in ly if k.endswith("_at")]:
                        ly[key] = round((_next(occ[ly[key]], start) - f0) / fps, 4)
                    layers.append(ly)
                d["params"]["layers"] = layers
            out.append(d)
    out.sort(key=lambda d: d["frame"])
    return out
