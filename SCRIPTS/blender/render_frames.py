"""
Renderiza frames soltos de uma animação já montada (o .blend salvo pelo run_ability).

  blender -b _cache/previs/<NOME>_previs.blend --python SCRIPTS/blender/render_frames.py -- 150,470,900 [--lowres] [--out=pasta]
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import previs
import rbx_common as rc

args = rc.parse_script_args()
frames = [int(x) for x in args[0].split(",")]
opts = dict(a.split("=", 1) for a in args[1:] if "=" in a)
scene = bpy.context.scene
if "--lowres" in args:
    scene.render.resolution_x, scene.render.resolution_y = 480, 270
    scene.cycles.samples = 6
name = os.path.splitext(os.path.basename(bpy.data.filepath))[0].replace("_previs", "")
out = opts.get("--out", rc.repo_path("_cache", "frames", name))
paths = previs.render_frames(scene, frames, out, prefix="r")
previs.contact_sheet(paths, os.path.join(out, "sheet.png"), cols=min(4, len(paths)))
print("SHEET", os.path.join(out, "sheet.png"))
