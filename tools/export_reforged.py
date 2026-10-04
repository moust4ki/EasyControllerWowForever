"""Convert Blender's supersampled RGBA passes to the exact WoW texture contract."""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "design" / "reforged"
parser = argparse.ArgumentParser()
parser.add_argument("--only", default="")
args = parser.parse_args()
manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
(OUT / "png").mkdir(exist_ok=True)
for asset in manifest["assets"]:
    name = asset["name"]
    if args.only and name not in args.only.split(","):
        continue
    size = asset["width"], asset["height"]
    with Image.open(OUT / "renders" / (name + ".png")) as rendered:
        img = rendered.convert("RGBA").resize(size, Image.Resampling.LANCZOS)
        img.save(OUT / "png" / (name + ".png"))
        img.save(ROOT / "textures" / (name + ".tga"), rle=False)
    for relative in asset["sourceLayers"]:
        dest = OUT / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(OUT / "renders" / relative) as layer:
            layer.convert("RGBA").resize(size, Image.Resampling.LANCZOS).save(dest)
    print(name, size)
