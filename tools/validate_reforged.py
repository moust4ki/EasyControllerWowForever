"""Validate Blender's Reforged texture set without modifying any files.

Run from any directory:
    python tools/validate_reforged.py
    python tools/validate_reforged.py --package dist/EasyController-VERSION.zip
    python tools/validate_reforged.py --only ck_btn_normal,ck_reforged_frame

The manifest is design/reforged/manifest.json. Layer paths are relative to
that directory (repository-relative paths and {"path": "..."} entries also
work). Layers are audited independently, not compared to the beauty render:
Blender's occlusion makes a simple layer composite an unreliable equality test.
Native source PNG hashes and references are mandatory; --native-source also
checks the extraction build identity, original BLP hashes, pixels and alpha.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPECS = {
    **{f"ck_btn_{state}": (128, 32, 6) for state in ("normal", "hover", "active", "pressed")},
    "ck_select": (128, 32, 10),
    **{f"ck_sk_key_{state}": (128, 64, 12) for state in
       ("normal", "hover", "active", "pressed", "target_l", "target_r")},
    "ck_panel_bg": (128, 128, 0),
    "ck_reforged_frame": (128, 128, 16),
    "ck_reforged_parchment": (256, 256, 16),
    "ck_reforged_title": (512, 128, 0),
    **{f"ck_reforged_role_{state}": (512, 128, 12) for state in ("normal", "hover", "active", "pressed")},
    **{f"ck_reforged_gryphon_{side}": (256, 256, 0) for side in ("left", "right")},
    **{f"ck_reforged_slot_{state}": (128, 128, 0) for state in ("normal", "hover", "pressed")},
}
STATE_GROUPS = {
    "role cards": [f"ck_reforged_role_{state}" for state in ("normal", "hover", "active", "pressed")],
    "gryphon directions": ["ck_reforged_gryphon_left", "ck_reforged_gryphon_right"],
    "HUD slot borders": [f"ck_reforged_slot_{state}" for state in ("normal", "hover", "pressed")],
    "buttons": [f"ck_btn_{state}" for state in ("normal", "hover", "active", "pressed")],
    "keyboard keys": [f"ck_sk_key_{state}" for state in
                      ("normal", "hover", "active", "pressed", "target_l", "target_r")],
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def rgba(path, expected=None, png=False, tga=False, power_of_two=True):
    data = path.read_bytes()
    if png:
        require(len(data) >= 33 and data[:8] == b"\x89PNG\r\n\x1a\n", f"{path.name}: invalid PNG header")
        require(data[24:26] == bytes((8, 6)), f"{path.name}: PNG must use 8-bit RGBA (32 bpp)")
    if tga:
        require(len(data) >= 18, f"{path.name}: incomplete TGA header")
        require(data[1] == 0 and data[2] == 2, f"{path.name}: TGA must be uncompressed true-color, without a color map")
        require(data[16] == 32 and data[17] & 15 == 8, f"{path.name}: TGA must have 32 bpp and 8 alpha bits")
    with Image.open(path) as source:
        require(source.mode == "RGBA", f"{path.name}: expected RGBA, got {source.mode}")
        if expected:
            require(source.size == expected, f"{path.name}: expected {expected}, got {source.size}")
        if power_of_two:
            require(all(n > 0 and n & (n - 1) == 0 for n in source.size), f"{path.name}: dimensions must be powers of two")
        result = source.copy()
    require(result.getchannel("A").getbbox() is not None, f"{path.name}: image is entirely transparent")
    return result


def layer_path(value, folder, root):
    if isinstance(value, dict):
        value = value.get("path")
    require(isinstance(value, str) and value.strip(), "sourceLayers entries must be paths or objects with a path")
    path = Path(value)
    candidates = [path] if path.is_absolute() else [folder / path, root / path]
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved.is_file():
            require(resolved.is_relative_to(folder.resolve()), f"layer must stay within {folder}: {value}")
            return resolved
    raise ValueError(f"missing source layer: {value}")


def validate_native_pixels(path, png, name):
    """Audit native mip zero directly; Pillow does not support raw BGRA BLP2."""
    data = path.read_bytes()
    if data[:4] == b"BLP2" and len(data) > 8 and data[8] == 3:
        require(len(data) >= 1172, f"{name}: incomplete raw BGRA BLP2 header")
        image_type, encoding, alpha_depth, _, _, width, height = struct.unpack_from("<I4B2I", data, 4)
        require(image_type == 1 and encoding == 3 and alpha_depth == 8,
                f"{name}: unsupported raw BGRA BLP2 format")
        require(width > 0 and height > 0 and png.size == (width, height),
                f"{name}: retained source PNG dimensions differ from native BLP")
        offset = struct.unpack_from("<I", data, 20)[0]
        length = struct.unpack_from("<I", data, 84)[0]
        require(offset >= 1172 and length == width * height * 4 and offset + length <= len(data),
                f"{name}: invalid or truncated raw BGRA BLP2 mip zero")
        # Compare in the native channel order without reusing the conversion code.
        require(data[offset:offset + length] == png.tobytes("raw", "BGRA"),
                f"{name}: retained source PNG pixels/alpha differ from native BLP")
    else:
        with Image.open(path) as blp:
            decoded = blp.convert("RGBA")
            require(decoded.size == png.size and decoded.tobytes() == png.tobytes(),
                    f"{name}: retained source PNG pixels/alpha differ from native BLP")



def validate_native_provenance(manifest, folder, root, extraction=None):
    """Verify retained source PNGs and, when available, the extracted client BLPs."""
    client = manifest.get("nativeClient")
    require(isinstance(client, dict), "manifest must identify the installed native client")
    for key in ("source", "product", "version", "buildKey", "mode"):
        require(isinstance(client.get(key), str) and client[key].strip(), f"nativeClient: missing {key}")
    require(len(client["buildKey"]) == 32 and all(c in "0123456789abcdef" for c in client["buildKey"].lower()),
            "nativeClient: buildKey must be a 32-character hexadecimal key")
    originals = {}
    if extraction is not None:
        original = json.loads((extraction / "provenance.json").read_text(encoding="utf-8-sig"))
        for key in ("source", "product", "version", "buildKey", "mode"):
            require(client[key] == original.get(key), f"nativeClient {key} differs from the extraction record")
        originals = {entry["fileDataId"]: entry for entry in original["assets"]}
    records = manifest.get("nativeArtwork")
    require(isinstance(records, list) and records, "nativeArtwork must be a nonempty source list")
    by_name, ids = {}, set()
    for record in records:
        require(isinstance(record, dict), "nativeArtwork entries must be objects")
        file_id, virtual = record.get("fileDataId"), record.get("virtualPath")
        require(type(file_id) is int and file_id > 0, "nativeArtwork: invalid FileDataID")
        require(file_id not in ids, f"nativeArtwork: duplicate FileDataID {file_id}")
        ids.add(file_id)
        require(isinstance(virtual, str) and virtual.lower().endswith(".blp"), f"{file_id}: missing native BLP path")
        normalized = virtual.replace("\\", "/")
        name = Path(normalized).stem.lower()
        require(name not in by_name, f"nativeArtwork: ambiguous source basename {name}")
        by_name[name] = record
        for field in ("sourceSha256", "pngSha256"):
            digest = record.get(field)
            require(isinstance(digest, str) and len(digest) == 64 and all(c in "0123456789abcdef" for c in digest.lower()),
                    f"{virtual}: missing or invalid {field}")
        path = layer_path(record.get("png"), folder, root)
        require(path.is_relative_to((folder / "native").resolve()), f"{virtual}: retained source PNG must be inside native/")
        require(hashlib.sha256(path.read_bytes()).hexdigest() == record["pngSha256"].lower(),
                f"{virtual}: retained native PNG hash differs from provenance")
        png = rgba(path, png=True)
        if extraction is not None:
            require(file_id in originals, f"{virtual}: FileDataID missing from extraction record")
            original = originals[file_id]
            require(original["virtualPath"].replace("\\", "/").lower() == normalized.lower(), f"{file_id}: native path differs from extraction record")
            require(original["sourceSha256"].lower() == record["sourceSha256"].lower(), f"{virtual}: BLP hash differs from extraction record")
            require(original["pngSha256"].lower() == record["pngSha256"].lower(), f"{virtual}: PNG hash differs from extraction record")
            raw = (extraction / "raw" / normalized).resolve()
            require(raw.is_relative_to((extraction / "raw").resolve()), f"{virtual}: invalid extracted BLP path")
            require(hashlib.sha256(raw.read_bytes()).hexdigest() == record["sourceSha256"].lower(), f"{virtual}: extracted BLP bytes differ from recorded hash")
            validate_native_pixels(raw, png, virtual)
    for entry in manifest["assets"]:
        sources = entry.get("nativeSources")
        require(isinstance(sources, list) and sources, f"{entry['name']}: missing nativeSources")
        require(all(isinstance(name, str) and name.lower() in by_name for name in sources),
                f"{entry['name']}: nativeSources contains an unverified source")
        note = entry.get("adaptation")
        require(isinstance(note, str) and note.strip(), f"{entry['name']}: missing adaptation description")
    return len(records)


def validate_asset(entry, folder, root):
    name = entry["name"]
    width, height, corner = SPECS[name]
    require((entry.get("width"), entry.get("height")) == (width, height), f"{name}: manifest dimensions differ from the fixed spec")
    require((entry.get("nineSliceCorner") or 0) == corner, f"{name}: expected nine-slice corner {corner}")
    require(isinstance(entry.get("state"), str) and entry["state"].strip(), f"{name}: missing state label")
    source = rgba(folder / "png" / f"{name}.png", (width, height), png=True)
    runtime = rgba(root / "textures" / f"{name}.tga", (width, height), tga=True)
    require(source.tobytes() == runtime.tobytes(), f"{name}: PNG and runtime TGA pixels or alpha differ")
    if name == "ck_reforged_frame":
        center = source.getchannel("A").crop((corner, corner, width - corner, height - corner))
        require(center.getextrema() == (0, 0), f"{name}: the entire 96x96 nine-slice center must be fully transparent")
    elif name.startswith("ck_reforged_slot_"):
        center = source.getchannel("A").crop((width // 2 - 1, height // 2 - 1, width // 2 + 1, height // 2 + 1))
        require(center.getextrema() == (0, 0), f"{name}: the HUD slot center must be fully transparent")
    layers = entry.get("sourceLayers")
    require(isinstance(layers, list) and layers, f"{name}: sourceLayers must be a nonempty list")
    seen = set()
    for reference in layers:
        path = layer_path(reference, folder, root)
        require(path not in seen, f"{name}: duplicate source layer {path.name}")
        seen.add(path)
        layer = rgba(path, png=True, power_of_two=False)
        require(layer.width <= width and layer.height <= height, f"{name}: layer {path.name} exceeds its asset canvas")
    return hashlib.sha256(source.tobytes()).hexdigest(), len(layers)


def validate_package(path, root):
    with zipfile.ZipFile(path) as package:
        names = package.namelist()
        require(all(name.startswith("EasyController/") for name in names), "package must have a single EasyController/ root")
        for name in SPECS:
            member = f"EasyController/textures/{name}.tga"
            require(names.count(member) == 1, f"package must contain exactly one {member}")
            require(package.read(member) == (root / "textures" / f"{name}.tga").read_bytes(), f"package has stale texture bytes: {member}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="addon repository root")
    parser.add_argument("--package", type=Path, help="optional built addon ZIP to audit")
    parser.add_argument("--native-source", type=Path, help="extraction directory with raw/ and provenance.json; uses ../forever-wow when present")
    parser.add_argument("--only", help="comma-separated asset names for an explicitly partial render proof")
    args = parser.parse_args(argv)
    selected = set(args.only.split(",")) if args.only else set(SPECS)
    if not selected <= set(SPECS):
        parser.error(f"unknown asset names: {sorted(selected - set(SPECS))}")
    if args.only and args.package:
        parser.error("--package requires a full audit without --only")
    root = args.root.resolve()
    folder = root / "design" / "reforged"
    extraction = args.native_source
    if extraction is None and (root.parent / "forever-wow" / "provenance.json").is_file():
        extraction = root.parent / "forever-wow"
    if extraction is not None:
        extraction = extraction.resolve()
    errors, hashes, layer_count = [], {}, 0
    try:
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8-sig"))
        require(isinstance(manifest, dict), "manifest must be a JSON object")
        generator = manifest.get("generator")
        require(generator and "blender" in json.dumps(generator).lower(), "manifest must identify its Blender generator")
        blend = folder / "ClassicReforged.blend"
        require(blend.is_file() and blend.stat().st_size > 0, "missing or empty ClassicReforged.blend")
        assets = manifest.get("assets")
        require(isinstance(assets, list), "manifest assets must be an array")
        names = [entry.get("name") for entry in assets if isinstance(entry, dict)]
        require(len(names) == len(assets), "each asset must be an object")
        require(all(isinstance(name, str) for name in names), "each asset must have a name")
        require(len(set(names)) == len(names), "manifest contains duplicate asset names")
        require(set(names) == set(SPECS), f"manifest must contain exactly the {len(SPECS)} specified assets; "
                f"missing={sorted(set(SPECS) - set(names))}, extra={sorted(set(names) - set(SPECS))}")
        native_count = validate_native_provenance(manifest, folder, root, extraction)
        print(f"PASS: {native_count} native source hashes and asset references" +
              ("; extracted BLP pixels/alpha verified" if extraction is not None else "; raw extraction unavailable"))
    except (OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    for entry in assets:
        if entry["name"] not in selected:
            continue
        try:
            digest, count = validate_asset(entry, folder, root)
            hashes[entry["name"]] = digest
            layer_count += count
            print(f"PASS: {entry['name']} ({entry['width']}x{entry['height']}, {count} layers)")
        except (OSError, ValueError) as error:
            errors.append(str(error))
    for group, names in STATE_GROUPS.items():
        names = [name for name in names if name in selected]
        if len(names) > 1 and all(name in hashes for name in names):
            if len({hashes[name] for name in names}) != len(names):
                errors.append(f"{group}: each state must have distinct RGBA pixels")
    if args.package:
        try:
            validate_package(args.package, root)
            print(f"PASS: all {len(SPECS)} runtime textures match {args.package.name}")
        except (OSError, ValueError, zipfile.BadZipFile) as error:
            errors.append(str(error))
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    if errors:
        print(f"Reforged audit failed: {len(errors)} problem(s).", file=sys.stderr)
        return 1
    scope = f"Partial Reforged proof ({len(hashes)}/{len(SPECS)} assets)" if args.only else "Reforged audit"
    print(f"{scope} passed: {len(hashes)} assets, {layer_count} source layers; PNG/TGA pixels and alpha match.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
