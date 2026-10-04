#!/usr/bin/env python3
"""
Gera ROBLOX/src/shared/RigData.luau com as partes extras do rig (lâminas e
cachecol) e os C0/C1 exatamente iguais aos do rig do Blender.

  python3 SCRIPTS/tools/gen_rig_data.py
"""

import ast
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXTRA = ("EmberBlade", "AzureBlade", "Scarf1", "Scarf2", "Scarf3", "Scarf4")


def r15_parts():
    src = open(os.path.join(ROOT, "SCRIPTS", "blender", "rbx_common.py"), encoding="utf-8").read()
    for node in ast.parse(src).body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", None) == "R15_PARTS":
            return ast.literal_eval(node.value)
    raise RuntimeError("R15_PARTS não encontrado")


def joints(meta):
    out = {}

    def walk(n, parent):
        if parent is not None:
            out[n["jname"]] = (parent, n["jointName"], n["jointtransform0"], n["jointtransform1"])
        for c in n.get("children", []):
            walk(c, n["jname"])

    walk(meta["rig"], None)
    return out


def cf(c):
    nums = ", ".join(f"{v:.6f}".rstrip("0").rstrip(".") if v else "0" for v in c)
    return f"CFrame.new({nums})"


def main():
    with open(os.path.join(ROOT, "CHARACTER", "rig_meta_ember_r15.json")) as f:
        meta = json.load(f)
    js = joints(meta)
    sizes = {p[0]: p[3] for p in r15_parts()}
    lines = [
        "-- gerado por SCRIPTS/tools/gen_rig_data.py a partir do rig do Blender, não editar na mão",
        "",
        "return {",
    ]
    for name in EXTRA:
        parent, joint, c0, c1 = js[name]
        sx, sy, sz = sizes[name]
        lines += [
            "\t{",
            f'\t\tname = "{name}",',
            f'\t\tparent = "{parent}",',
            f'\t\tjoint = "{joint}",',
            f"\t\tsize = Vector3.new({sx}, {sy}, {sz}),",
            f"\t\tc0 = {cf(c0)},",
            f"\t\tc1 = {cf(c1)},",
            "\t},",
        ]
    lines.append("}")
    out = os.path.join(ROOT, "ROBLOX", "src", "shared", "RigData.luau")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("RigData.luau:", ", ".join(EXTRA))


if __name__ == "__main__":
    main()
