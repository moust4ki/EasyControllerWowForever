"""Build the CurseForge / release zip: dist/EasyController-<version>.zip

The zip holds a single EasyController/ folder with what the game loads:
the TOC and its files, Bindings.xml, the TGA textures, LICENSE, README and
CHANGELOG. Design sources and tools are left out.

Usage:
    python tools/package.py
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "EasyController"
EXTRA = ["Bindings.xml", "LICENSE", "README.md", "CHANGELOG.md"]

# These runtime selectors build texture names from a fixed family prefix.
TEXTURE_FAMILIES = {
    "ck_btn": ("ck_btn_normal", "ck_btn_hover", "ck_btn_active", "ck_btn_pressed"),
    "ck_reforged_role": ("ck_reforged_role_normal", "ck_reforged_role_hover",
                         "ck_reforged_role_active", "ck_reforged_role_pressed"),
    "ck_reforged_gryphon_": ("ck_reforged_gryphon_left", "ck_reforged_gryphon_right"),
}


def main():
    toc = (ROOT / f"{ADDON}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    listed = [line.strip() for line in toc.splitlines()
              if line.strip() and not line.startswith("#")]

    files = [f"{ADDON}.toc"] + listed + EXTRA
    files += sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "textures").glob("*.tga"))

    missing = [f for f in files if not (ROOT / f).is_file()]
    if missing:
        sys.exit("Missing files: " + ", ".join(missing))

    # Every texture the code references must be packaged
    code = "".join((ROOT / f).read_text(encoding="utf-8") for f in listed)
    names = set(re.findall(r'"(ck_[a-z0-9_]+)"', code))
    names = {texture for name in names for texture in TEXTURE_FAMILIES.get(name, (name,))}
    packaged = {Path(f).stem for f in files if f.startswith("textures/")}
    absent = sorted(n for n in names if n not in packaged)
    if absent:
        sys.exit("Textures used but not packaged: " + ", ".join(absent))

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"{ADDON}-{version}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(ROOT / f, f"{ADDON}/{f}")
    size = out.stat().st_size / 1024
    print(f"{out.relative_to(ROOT)}: {len(files)} files, {size:.0f} KB")


if __name__ == "__main__":
    main()
