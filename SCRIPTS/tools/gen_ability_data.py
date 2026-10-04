#!/usr/bin/env python3
"""
Gera ROBLOX/src/shared/Abilities/<Nome>.luau a partir do _timing.json e do
_vfx_cues.json de cada animação (markers, fases, root motion, cues e hits).

  python3 SCRIPTS/tools/gen_ability_data.py [ANIM_01_ATOMIC_ECLIPSE ...]
"""

import json
import math
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "ROBLOX", "src", "shared", "Abilities")
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def module_name(name):
    words = name.split("_")[2:]
    return "".join(w.capitalize() for w in words), " ".join(w.capitalize() for w in words)


def num(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def lua(v, indent=0):
    pad = "\t" * indent
    if v is None:
        return "nil"
    if isinstance(v, (bool, int, float)):
        return num(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        if all(isinstance(x, (int, float, str)) for x in v):
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        inner = ",\n".join(pad + "\t" + lua(x, indent + 1) for x in v)
        return "{\n" + inner + ",\n" + pad + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        parts = []
        for k, x in v.items():
            if x is None:
                continue
            key = k if IDENT.match(k) else "[" + json.dumps(k) + "]"
            parts.append(f"{key} = {lua(x, indent + 1)}")
        flat = "{ " + ", ".join(parts) + " }"
        if len(flat) + len(pad) < 110 and "\n" not in flat:
            return flat
        return "{\n" + ",\n".join(pad + "\t" + p for p in parts) + ",\n" + pad + "}"
    raise TypeError(type(v))


def reduce_root(rows, tol=0.01, yaw_tol=0.5):
    pts = [(r["t"], r["pos"][0], r["pos"][2], r["yaw"]) for r in rows]
    keep = [0]
    i = 0
    while i < len(pts) - 1:
        j = i + 2
        while j < len(pts):
            a, b = pts[i], pts[j]
            ok = True
            for k in range(i + 1, j):
                u = (pts[k][0] - a[0]) / (b[0] - a[0])
                x = a[1] + (b[1] - a[1]) * u
                z = a[2] + (b[2] - a[2]) * u
                y = a[3] + (b[3] - a[3]) * u
                if math.hypot(x - pts[k][1], z - pts[k][2]) > tol or abs(y - pts[k][3]) > yaw_tol:
                    ok = False
                    break
            if not ok:
                break
            j += 1
        i = j - 1
        keep.append(i)
    return [[round(v, 4) for v in pts[k]] for k in sorted(set(keep))]


def clean_layer(ly, palette):
    out = {}
    for k, v in ly.items():
        if k in ("intensity",):
            continue
        if isinstance(v, str) and k.startswith("color") and v not in palette:
            raise ValueError(f"cor desconhecida {v}")
        out[k] = v
    return out


def clean_cue(c, fps, f0, palette):
    params = {}
    for k, v in c["params"].items():
        if k == "layers":
            params[k] = [clean_layer(ly, palette) for ly in v]
            continue
        if k.endswith("_until"):
            continue
        if k.endswith("_at"):
            v = round((v - f0) / fps, 4)
        if isinstance(v, str) and k.startswith("color") and v not in palette:
            raise ValueError(f"cor desconhecida {v} em {c['marker']}")
        params[k] = v
    out = {"t": c["time"], "fx": c["fx"], "marker": c["marker"]}
    if c.get("anchor"):
        out["anchor"] = c["anchor"]
    if c.get("layer") and c["layer"] != "primary":
        out["tier"] = c["layer"]
    if c.get("when") is not None:
        out["value"] = c["when"]
    out["params"] = params
    return out


def generate(name):
    folder = os.path.join(ROOT, "ANIMATIONS", name)
    with open(os.path.join(folder, name + "_timing.json")) as f:
        timing = json.load(f)
    with open(os.path.join(folder, name + "_vfx_cues.json")) as f:
        vfx = json.load(f)
    fps, f0 = timing["fps"], timing["frame_start"]
    mod, display = module_name(name)
    data = {
        "Id": timing["id"],
        "Name": mod,
        "DisplayName": display,
        "Animation": name,
        "Duration": timing["duration_s"],
        "Phases": [
            [p["name"], round((p["start"] - f0) / fps, 4), round((p["end"] - f0) / fps, 4)] for p in timing["phases"]
        ],
        "Markers": [[m["time_s"], m["name"], m["value"]] for m in timing["markers"]],
        "RootMotion": reduce_root(timing["root_motion"]),
        "Cues": [clean_cue(c, fps, f0, vfx["palette"]) for c in vfx["cues"]],
        "Hits": [clean_cue(c, fps, f0, vfx["palette"]) for c in vfx.get("hits", [])],
    }
    body = lua(data)
    text = (
        "--!nocheck\n"
        f"-- gerado por SCRIPTS/tools/gen_ability_data.py a partir de ANIMATIONS/{name}, não editar na mão\n"
        "-- RootMotion: { t, x, z, yaw } relativo ao início (studs/graus, -Z = frente)\n\n"
        f"return {body}\n"
    )
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, mod + ".luau")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(
        f"{name} -> {os.path.relpath(path, ROOT)}: {len(data['Cues'])} cues, {len(data['Hits'])} hits, "
        f"{len(data['RootMotion'])} chaves de root motion"
    )
    return data


if __name__ == "__main__":
    names = sys.argv[1:] or sorted(
        d
        for d in os.listdir(os.path.join(ROOT, "ANIMATIONS"))
        if os.path.exists(os.path.join(ROOT, "ANIMATIONS", d, d + "_vfx_cues.json"))
    )
    for n in names:
        generate(n)
