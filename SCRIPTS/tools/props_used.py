#!/usr/bin/env python3
"""Lista (Classe, Propriedade) que o runtime escreve, pra conferir no banco de reflexão (check_props.luau)."""

import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "ROBLOX", "src")
NEW = re.compile(r'local\s+(\w+)\s*=\s*Instance\.new\("(\w+)"\)')
ASSIGN = re.compile(r"^\s*(\w+)\.(\w+)\s*(?:,\s*\w+\.\w+\s*)?=[^=]")
TYPED = re.compile(
    r"\b(\w+)\s*:\s*(Part|BasePart|Beam|Attachment|Trail|ColorCorrectionEffect|Frame|Highlight|PointLight)\b"
)

pairs = set()
for base, _, files in os.walk(SRC):
    for f in files:
        if not f.endswith(".luau"):
            continue
        cls = {}
        for line in open(os.path.join(base, f), encoding="utf-8"):
            for v, c in NEW.findall(line):
                cls[v] = c
            for v, c in TYPED.findall(line):
                cls.setdefault(v, "Part" if c == "BasePart" else c)
            if "Pool.get(" in line:
                m = re.search(r"(?:local\s+)?(\w+)\s*=\s*Pool\.get", line)
                if m:
                    cls[m.group(1)] = "Part"
            m = ASSIGN.match(line)
            if m and m.group(1) in cls:
                pairs.add((cls[m.group(1)], m.group(2)))
out = os.path.join(ROOT, "_cache", "props_used.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(sorted(pairs), open(out, "w"), indent=0)
print(len(pairs), "pares classe/propriedade ->", os.path.relpath(out, ROOT))
