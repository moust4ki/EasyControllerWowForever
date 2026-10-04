"""Convert PNG textures to TGA files WoW can load.

Usage:
    pip install pillow
    python tools/convert_textures.py            # default textures plus canonical Blender assets
    python tools/convert_textures.py path/to/pngs

Default conversion uses design/textures for unchanged assets. When the Reforged
manifest exists, its design/reforged/png files replace matching basenames and add
new assets. An explicit source directory converts only that directory.
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def is_pow2(n):
    return n > 0 and n & (n - 1) == 0


def main():
    explicit_source = len(sys.argv) > 1
    src = Path(sys.argv[1]) if explicit_source else ROOT / "design" / "textures"
    pngs = sorted(src.glob("*.png"))
    manifest_path = ROOT / "design" / "reforged" / "manifest.json"
    if not explicit_source and manifest_path.exists():
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
            assets = manifest["assets"]
            if not isinstance(assets, list) or not assets:
                raise ValueError("assets must be a nonempty array")
            sources = {png.name: png for png in pngs}
            seen = set()
            for asset in assets:
                name = asset["name"]
                if not isinstance(name, str) or not name or Path(name).name != name:
                    raise ValueError("asset names must be filename stems")
                if name in seen:
                    raise ValueError(f"duplicate asset: {name}")
                seen.add(name)
                png = manifest_path.parent / "png" / f"{name}.png"
                if not png.is_file():
                    raise ValueError(f"missing canonical Blender source: {png}")
                sources[png.name] = png
            pngs = sorted(sources.values(), key=lambda png: png.name)
        except (OSError, ValueError, KeyError, TypeError) as error:
            sys.exit(f"Cannot resolve Reforged textures: {error}")
    if not pngs:
        sys.exit(f"No PNG found in {src}")
    dst = ROOT / "textures"
    dst.mkdir(exist_ok=True)
    for png in pngs:
        img = Image.open(png).convert("RGBA")
        w, h = img.size
        if not (is_pow2(w) and is_pow2(h)):
            print(f"  warning: {png.name} is {w}x{h}, WoW needs powers of 2")
        out = dst / (png.stem + ".tga")
        img.save(out, rle=False)
        print(f"{png.name} ({w}x{h}) -> textures/{out.name}")
    print(f"{len(pngs)} textures converted.")


if __name__ == "__main__":
    main()
