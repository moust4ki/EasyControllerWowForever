# Native Forever artwork contribution

The runtime primarily requests native atlases from the installed client. The texture
exports here adapt artwork from WoW Forever/Camelot build 1.60.1.70205 for the remaining
keyboard/HUD surfaces and compatibility fallbacks. This is Blizzard-derived artwork,
not original artwork authored by this project; the existing MIT code license should
not be read as a claim of authorship or a new license grant for Blizzard's artwork.

Included: the path-clean provenance manifest, 24 canonical PNG/TGA exports, 32 separate
source layers, and the Python/Blender generators. The source layers preserve static,
hover, focus and activation states. The title/gryphon compatibility exports are retained
for the manifest's complete asset set; the current main window does not display them.

Selected previews show the current configuration, action wheel, chat wheel, editor,
split keyboard and state sheet. They use fixture data and are not game screenshots.

`python tools/convert_textures.py` uses the canonical PNGs in this directory for these
assets and `design/textures` for unchanged textures. Missing canonical sources fail
before conversion. `python tools/package.py` packages the shipped runtime TGAs and
needs neither Blender nor a client extraction.

Raw/full client atlas sheets, packed Blender files, generated workspaces, debug logs
and machine-specific reports are intentionally excluded from this public source branch.
Their content hashes, virtual paths, atlas crop coordinates and transformations remain
in the manifest. These omitted originals are required for the full art rebuild/checks;
the validator has not been weakened to skip them.

Optional full rebuild:

1. Supply a local client extraction containing `provenance.json`, `atlas-map.json`,
   decoded native PNGs, and raw BLPs when validating original pixels.
2. Run `python tools/prepare_native_reforged.py --source <local-extraction>`. This
   recreates the ignored `native/` originals and prepared layers/manifest.
3. Run Blender with `tools/blender_reforged.py`, then `tools/export_reforged.py`.
   Blender packs the original atlas sources as well as the separate component layers.
4. Run `tools/validate_reforged.py`; use its `--native-source` option for original
   extraction verification. It requires the full native/Blender output.
5. `tools/preview_reforged.py` and `tools/build_native_config_scene.py` additionally
   expect sibling `forever-wow` extracts and `native-wow` client fonts as documented
   in their code. These generate the current eight-scene editable composition.

No extracted font files or original client atlas sheets are included in this branch.
