"""Build the editable source for the live Forever configuration artwork.

Run with the workspace Python (Pillow), not Blender's Python:
    python tools/build_native_config_scene.py --blender ".../blender.exe"

This source-only scene reuses preview_reforged's native atlas/canvas compositor.
It writes no runtime textures and does not alter the existing asset manifest.
All layer images and original atlas crops are packed into ForeverConfig.blend.
The empty composition and synthetic wheel fixtures are artwork references, not game screenshots.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "design" / "reforged"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(folder):
    from PIL import Image
    import preview_reforged as renderer

    class Layers(renderer.Preview):
        def __init__(self):
            super().__init__(OUT)
            self.scenes, self.current, self.group = [], None, ""

        def canvas(self, size, color=(0, 0, 0, 0)):
            return super().canvas(size, color)

        def begin(self, name, size):
            self.current = {"name": name, "size": list(size), "layers": []}
            self.scenes.append(self.current)
            return self.canvas(size)

        def record(self, canvas, layer, label, box, metadata):
            x, y, width, height = box
            bounds = tuple(round(v * renderer.SCALE) for v in (x, y, x + width, y + height))
            crop = layer.crop(bounds)
            if not crop.getchannel("A").getbbox():
                raise ValueError("Empty artwork layer: " + label)
            index = len(self.current["layers"])
            name = re.sub(r"[^a-zA-Z0-9_-]+", "_", label).strip("_")
            relative = Path("layers") / self.current["name"] / f"{index:03d}_{name}.png"
            path = folder / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            crop.save(path)
            self.current["layers"].append(dict(name=label, group=self.group, png=relative.as_posix(),
                pngSha256=digest(path), box=list(box), metadata=metadata))
            canvas.alpha_composite(layer)

        def native(self, canvas, name, box, **options):
            layer = Image.new("RGBA", canvas.size)
            super().native(layer, name, box, **options)
            self.record(canvas, layer, name, box, dict(atlas=name, **self.native_used[name], **options))

        def tile(self, canvas, name, box):
            layer = Image.new("RGBA", canvas.size)
            super().tile(layer, name, box)
            self.record(canvas, layer, name, box, {"runtimeAsset": name, "operation": "tile"})

        def slice(self, canvas, name, box, corner=None, alpha=1):
            layer = Image.new("RGBA", canvas.size)
            super().slice(layer, name, box, corner, alpha)
            self.record(canvas, layer, name, box, {"runtimeAsset": name, "displayCorner": corner,
                "sourceCorner": self.entries[name]["nineSliceCorner"], "alpha": alpha})

        def control(self, canvas, family, box, state):
            role = family == "large"
            active = state in ("selected", "activation")
            hovered = state == "hover" or (active and not role)
            atlas = "common-button-list-" + family
            brightness = .7 if state == "activation" else 1
            self.native(canvas, atlas + ("-hover" if hovered else ""), box,
                        sliced=True, brightness=brightness)
            if role and active:
                self.native(canvas, atlas + "-selected", box, sliced=True, brightness=brightness)

    preview = Layers()
    preview.begin("01_Live_configuration_art", (830, 604))
    preview.group = "01 Native Metal frame and tiled body"
    canvas = preview.native_metal_frame()
    preview.group = "02 Top navigation / selected and static"
    for i in range(5):
        preview.control(canvas, "small", (91 + i * 132, 78, 126, 30), "selected" if i == 0 else "static")
    preview.group = "03 Sidebar navigation / selected and static"
    for i in range(7):
        preview.control(canvas, "mid", (34, 128 + i * 48, 124, 44), "selected" if i == 6 else "static")
    preview.group = "04 Role cards / selected and static"
    for i in range(4):
        preview.control(canvas, "large", (178, 156 + i * 80, 388, 72), "selected" if i == 0 else "static")
    preview.group = "05 Binding navigation"
    preview.control(canvas, "small", (178, 484, 388, 32), "static")
    preview.group = "06 Detail paper and native inset rim"
    preview.slice(canvas, "ck_reforged_parchment", (578, 120, 232, 420), corner=12)
    preview.native(canvas, "common-insideframe", (578, 120, 232, 420), sliced=True)
    preview.group = "07 Apply action / disabled until assigned"
    preview.slice(canvas, "ck_btn_normal", (592, 492, 204, 34), alpha=.45)
    preview.group = "08 Native close"
    preview.native(canvas, "RedButton-Exit", (802, 15, 24, 24))
    canvas.save(folder / "composition_reference.png")

    board = preview.begin("02_Control_state_library", (1680, 362))
    for column, state in enumerate(("static", "hover", "selected", "activation")):
        x = 16 + column * 420
        for family, y, width, height in (("small", 24, 126, 30), ("mid", 88, 124, 44), ("large", 178, 388, 72)):
            preview.group = family + " / " + state
            preview.control(board, family, (x, y, width, height), state)
        preview.group = "Apply action / " + state
        asset_state = {"static": "normal", "hover": "hover", "selected": "active", "activation": "pressed"}[state]
        # This unchanged packaged family already has separate editable source
        # layers in ClassicReforged.blend. The live source references its PNG.
        preview.slice(board, "ck_btn_" + asset_state, (x, 292, 204, 34))
    board.save(folder / "state_library_reference.png")

    # Reuse the renderer's full-canvas wheel components rather than maintaining
    # another wheel art pipeline. A plain Preview avoids recording its internal
    # native/tile calls a second time through the configuration layer subclass.
    wheel_preview = renderer.Preview(OUT)
    fixture = {"data": "Synthetic eight-slot wheel repeating three installed-client Warrior icons; not player bindings or inventory.",
               "icons": ["Ability_Warrior_ShieldBash", "Ability_Warrior_ShieldWall", "Ability_Warrior_Charge"],
               "slots": 8, "selectedIndexBase": 0}
    for index, (state, selected, pressed) in enumerate((("static", None, False),
                                                      ("focus", 0, False), ("activation", 0, True)), 3):
        name = f"{index:02d}_Wheel_{state}"
        board = preview.begin(name, (560, 700))
        before = len(wheel_preview.text_checks)
        components = wheel_preview.wheel_layers(count=8, selected=selected, pressed=pressed)
        approximations = [record for record in wheel_preview.text_checks[before:]
                          if record.get("region") == "native atlas slice approximation"]
        preview.current["fixture"] = dict(fixture, state=state, selected=selected, pressed=pressed)
        preview.current["renderApproximations"] = approximations
        preview.current["reference"] = name + "_reference.png"
        for label, component in components:
            if not component.getchannel("A").getbbox():
                continue  # The static scene has no focused-section artwork.
            preview.group = state + " / " + label
            preview.record(board, component, label, (0, 0, 560, 700),
                           {"compositor": "Preview.wheel_layers", "state": state,
                            "syntheticFixture": fixture, "renderApproximations": approximations})
        board.save(folder / preview.current["reference"])
    preview.native_used.update(wheel_preview.native_used)
    preview.atlas_cache.update(wheel_preview.atlas_cache)

    # Chat scenes share the real daisywheel compositor and retain its input
    # layout. These are explicit UI-state fixtures, with no live chat content.
    chat_preview = renderer.Preview(OUT)
    for index, state in enumerate(("idle", "aim", "pressed"), 6):
        name = f"{index:02d}_Chat_{state}"
        board = preview.begin(name, (340, 508))
        before = len(chat_preview.text_checks)
        components = chat_preview.chat_layers(state=state)
        approximations = [record for record in chat_preview.text_checks[before:]
                          if record.get("region") == "native atlas slice approximation"]
        fixture = {"data": "Offline daisywheel state using the actual default letter layout; no player chat or predictions.",
                   "state": state, "petal": 0, "slot": 1, "indexBase": 0, "caps": False, "symbols": False}
        preview.current["fixture"] = fixture
        preview.current["renderApproximations"] = approximations
        preview.current["reference"] = name + "_reference.png"
        for label, component in components:
            if not component.getchannel("A").getbbox():
                continue
            preview.group = "chat " + state + " / " + label
            preview.record(board, component, label, (0, 0, 340, 508),
                           {"compositor": "Preview.chat_layers", "fixture": fixture,
                            "renderApproximations": approximations})
        board.save(folder / preview.current["reference"])
    preview.native_used.update(chat_preview.native_used)
    preview.atlas_cache.update(chat_preview.atlas_cache)

    native_sources = []
    for index, (name, record) in enumerate(preview.native_used.items()):
        image, display, entry = preview.native_atlas(name)
        file = folder / "native_crops" / f"{index:02d}_{re.sub(r'[^a-zA-Z0-9_-]+', '_', name)}.png"
        file.parent.mkdir(exist_ok=True)
        image.save(file)
        original = preview.native_files[record["fileDataID"]]
        native_sources.append(dict(atlas=name, png=file.relative_to(folder).as_posix(), pngSha256=digest(file),
            originalPngSha256=original["pngSha256"], originalBLPSha256=original["sourceSha256"],
            virtualPath=original["virtualPath"], **{k: v for k, v in record.items() if k != "pngSha256"}))
    manifest = dict(schema=1, generator="tools/build_native_config_scene.py", output="../ForeverConfig.blend",
        note="Editable native artwork reference at the current Lua dimensions. Wheel icons and input state scenes are explicitly offline fixtures. No game screenshot, player data, invented heraldry or runtime texture exports.",
        statePolicy="Native list families have no distinct pressed atlas. Activation preserves the selected overlay and applies the actual temporary 0.70 vertex brightness to both layers.",
        nativeGeometry="Atlas crops and slice margins from installed client DB2; canvas2 normalized to canvas1 using verified 2048x1536 / 1024x768 UiCanvas records.",
        scripts={name: digest(ROOT / name) for name in ("ConfigWindow.lua", "ConfigKit.lua", "ProfileOptions.lua", "ConsumableWheel.lua", "Paddles.lua", "Wheel.lua", "UI.lua", "tools/preview_reforged.py")},
        scenes=preview.scenes, nativeSources=native_sources)
    path = folder / "scene.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("PREPARED", len(preview.scenes), "scenes;", sum(len(s["layers"]) for s in preview.scenes),
          "editable layers;", len(native_sources), "exact native atlas crops", flush=True)
    return path


def build_blend(manifest_path):
    import bpy
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    folder = manifest_path.parent
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.preferences.filepaths.file_preview_type = "NONE"

    def image(path):
        value = bpy.data.images.load(str(path), check_existing=True)
        # Keep authored UI RGB in display space: Raw output + Non-Color inputs
        # avoid linear-light blending brightening translucent native glows.
        value.colorspace_settings.name = "Non-Color"
        value.pack()
        value.use_fake_user = True
        return value

    for record in manifest["nativeSources"]:
        native = image(folder / record["png"])
        native["Native atlas provenance"] = json.dumps(record)
    scenes = []
    for scene_index, entry in enumerate(manifest["scenes"]):
        scene = bpy.context.scene if scene_index == 0 else bpy.data.scenes.new(entry["name"])
        scene.name = entry["name"]
        scenes.append(scene)
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 1
        scene.cycles.use_denoising = False
        scene.cycles.transparent_max_bounces = 32
        # Every full-canvas component intersects the camera ray, including its
        # empty pixels. Trace the bounded stack without stochastic early exits.
        scene.cycles.min_transparent_bounces = 32
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
        scene.render.image_settings.color_depth = "8"
        scene.render.resolution_percentage = 100
        scene.render.resolution_x, scene.render.resolution_y = [round(v * 2) for v in entry["size"]]
        scene.view_settings.view_transform = "Raw"
        scene.view_settings.look = "None"
        scene.view_settings.exposure = 0
        scene.view_settings.gamma = 1
        scene.render.filter_size = .01
        scene["README"] = manifest["note"] + " " + manifest["statePolicy"]
        if entry.get("fixture"):
            scene["Synthetic fixture"] = json.dumps(entry["fixture"])
        if entry.get("renderApproximations"):
            scene["Offline rendering approximations"] = json.dumps(entry["renderApproximations"])
        width, height = entry["size"]
        camera_data = bpy.data.cameras.new(entry["name"] + " / camera")
        camera_data.type = "ORTHO"
        camera_data.sensor_fit = "HORIZONTAL"
        camera_data.ortho_scale = width
        camera = bpy.data.objects.new("Pixel matched source camera", camera_data)
        scene.collection.objects.link(camera)
        camera.location = (0, 0, 100)
        scene.camera = camera
        groups = {}
        for index, layer in enumerate(entry["layers"]):
            path = folder / layer["png"]
            assert digest(path) == layer["pngSha256"], "Layer changed before packing: " + str(path)
            texture = image(path)
            group = groups.get(layer["group"])
            if group is None:
                group = bpy.data.collections.new(layer["group"])
                scene.collection.children.link(group)
                groups[layer["group"]] = group
            x, y, w, h = layer["box"]
            mesh = bpy.data.meshes.new(layer["name"])
            mesh.from_pydata([(0, 0, 0), (w, 0, 0), (w, h, 0), (0, h, 0)], [], [(0, 1, 2, 3)])
            mesh.update()
            uv = mesh.uv_layers.new(name="Packed native layer UV")
            for loop, xy in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop.uv = xy
            obj = bpy.data.objects.new(layer["name"], mesh)
            group.objects.link(obj)
            obj.location = (x - width / 2, height / 2 - y - h, index * .01)
            obj["Native source and adaptation"] = json.dumps(layer["metadata"])
            obj["Layer PNG SHA256"] = layer["pngSha256"]
            material = bpy.data.materials.new(layer["name"])
            material.use_nodes = True
            nodes = material.node_tree.nodes
            nodes.clear()
            tex = nodes.new("ShaderNodeTexImage"); tex.image = texture; tex.interpolation = "Closest"
            emission = nodes.new("ShaderNodeEmission")
            transparent = nodes.new("ShaderNodeBsdfTransparent")
            mix = nodes.new("ShaderNodeMixShader")
            output = nodes.new("ShaderNodeOutputMaterial")
            links = material.node_tree.links
            links.new(tex.outputs["Color"], emission.inputs["Color"])
            links.new(tex.outputs["Alpha"], mix.inputs[0])
            links.new(transparent.outputs[0], mix.inputs[1])
            links.new(emission.outputs[0], mix.inputs[2])
            links.new(mix.outputs[0], output.inputs["Surface"])
            obj.data.materials.append(material)
        assert len([obj for obj in scene.objects if obj.type == "MESH"]) == len(entry["layers"])
    readme = bpy.data.texts.new("SOURCE_README.json")
    readme.write(json.dumps(manifest, indent=2))
    assert all(im.packed_file for im in bpy.data.images if im.source == "FILE")
    bpy.context.window.scene = scenes[0]
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
            area.spaces.active.shading.type = "MATERIAL"
    destination = (folder / manifest["output"]).resolve()
    bpy.ops.wm.save_as_mainfile(filepath=str(destination))
    for scene in scenes:
        scene.render.filepath = str(folder / (scene.name + ".png"))
        bpy.ops.render.render(write_still=True, scene=scene.name)
    print("PASS: packed", len(scenes), "source scenes; exact PNG layer hashes checked; no runtime texture exports", flush=True)

def verify_renders(folder):
    from PIL import Image, ImageChops
    # Different 8-bit rounding between Pillow and Blender may differ by two
    # channel levels after stacked alpha operations; alpha must remain exact.
    manifest = json.loads((folder / "scene.json").read_text(encoding="utf-8"))
    comparisons = [("composition_reference.png", "01_Live_configuration_art.png"),
                   ("state_library_reference.png", "02_Control_state_library.png")]
    comparisons.extend((scene["reference"], scene["name"] + ".png")
                       for scene in manifest["scenes"] if scene.get("reference"))
    for original, rendered in comparisons:
        expected = Image.open(folder / original).convert("RGBA")
        actual = Image.open(folder / rendered).convert("RGBA")
        assert actual.size == expected.size
        difference = ImageChops.difference(actual, expected).getextrema()
        assert difference[3][1] == 0, (rendered, "alpha differs", difference)
        assert max(channel[1] for channel in difference[:3]) <= 2, (rendered, "RGB differs", difference)
    print("PASS:", len(comparisons), "Blender references match compositor alpha exactly; RGB within 2/255 rounding", flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--blender", type=Path, default=Path("C:/Program Files/Blender Foundation/Blender 5.1/blender.exe"))
    parser.add_argument("--manifest", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--prepare-only", action="store_true")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(argv)
    if args.manifest:
        build_blend(args.manifest.resolve())
        return
    folder = OUT / "live-config"
    folder.mkdir(parents=True, exist_ok=True)
    manifest = prepare(folder)
    if not args.prepare_only:
        subprocess.run([str(args.blender), "--background", "--factory-startup", "--python", str(Path(__file__).resolve()),
                        "--", "--manifest", str(manifest)], check=True)
        verify_renders(folder)


if __name__ == "__main__":
    main()
