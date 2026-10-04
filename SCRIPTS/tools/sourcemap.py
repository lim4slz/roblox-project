#!/usr/bin/env python3
"""
Gera ROBLOX/sourcemap.json no formato do `rojo sourcemap`, pra rodar o
luau-lsp sem ter o Rojo instalado. Com o Rojo é só usar `rojo sourcemap`.
"""

import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RBX = os.path.join(ROOT, "ROBLOX")


def script_node(path):
    f = os.path.basename(path)
    if f.endswith(".server.luau"):
        return f[: -len(".server.luau")], "Script"
    if f.endswith(".client.luau"):
        return f[: -len(".client.luau")], "LocalScript"
    return f[: -len(".luau")], "ModuleScript"


def build(path, name):
    rel = lambda p: os.path.relpath(p, RBX).replace(os.sep, "/")
    entries = sorted(os.listdir(path))
    node = {"name": name, "className": "Folder", "filePaths": [], "children": []}
    for e in entries:
        if e.startswith("init."):
            _, cls = script_node(os.path.join(path, e))
            node["className"] = cls
            node["filePaths"] = [rel(os.path.join(path, e))]
    for e in entries:
        full = os.path.join(path, e)
        if e.startswith("init."):
            continue
        if os.path.isdir(full):
            node["children"].append(build(full, e))
        elif e.endswith(".luau"):
            n, cls = script_node(full)
            node["children"].append({"name": n, "className": cls, "filePaths": [rel(full)]})
    return node


def main():
    src = os.path.join(RBX, "src")
    tree = {
        "name": "EmberAbilities",
        "className": "DataModel",
        "filePaths": ["default.project.json"],
        "children": [
            {
                "name": "ReplicatedStorage",
                "className": "ReplicatedStorage",
                "children": [build(os.path.join(src, "shared"), "Ember")],
            },
            {
                "name": "ServerScriptService",
                "className": "ServerScriptService",
                "children": [build(os.path.join(src, "server"), "EmberServer")],
            },
            {
                "name": "StarterPlayer",
                "className": "StarterPlayer",
                "children": [
                    {
                        "name": "StarterPlayerScripts",
                        "className": "StarterPlayerScripts",
                        "children": [build(os.path.join(src, "client"), "EmberClient")],
                    }
                ],
            },
        ],
    }
    with open(os.path.join(RBX, "sourcemap.json"), "w") as f:
        json.dump(tree, f, indent=1)
    print("ROBLOX/sourcemap.json")


if __name__ == "__main__":
    main()
