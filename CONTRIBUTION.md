# Optional contribution from the local 1.8.2 branch

This branch extends upstream `9cdc4bf` (1.8.2). It is a reviewable source contribution,
not a replacement release for current upstream. At handoff, upstream was `31e8d59`
(1.11.7). It has not been rebased or merged onto that version.

## Small fixes to pick independently

- `Predict.lua`: prune exactly the excess learned words, including tied frequencies;
  retain useful context and use the selected language for fallback suggestions.
- `Upgrades.lua`: wait for equipped item information/stat data before comparing an
  upgrade, including an occupied offhand when considering a two-handed weapon.
- `Vibration.lua`: give gameplay alerts priority over typing and wheel feedback;
  stale completion timers cannot stop a newer vibration.
- `tools/release.py`: match the exact release heading, without accidentally taking
  prerelease notes when the requested release is missing.

Each has focused regression tests under `tools/` and its own commit.

## Larger optional groups

| Group | Main modules | Behavior |
| --- | --- | --- |
| HUD indicators | Supplies, Options, Core | Independent bag/ammo switches, off when unset; explicit saved choices preserved; unknown/question-mark ammo icons suppressed. |
| Custom wheels | ConsumableWheel, Core, Options | Optional fixed eight-direction custom slots; empty directions do nothing; mouse and controller cues match their real activation targets. |
| Refresh work | Mapping, Paddles, Toggle, Supplies, ConsumableWheel | Avoid all-layer construction for one mapping lookup, coalesce cooldown events, reuse unchanged geometry, and skip unrelated/hidden wheel refresh work. Tests measure API calls, not FPS. |
| Role layouts | Profiles, ProfileOptions, Mapping, MyWheels, Chat, Options, MapWindow | Explicit General/Tank/Healer/Damage profiles; shared utility bindings; confirmed copy; known-spell role assignment with conflict checks. Native action-bar contents remain game-owned. |
| Native UI | ConfigWindow, ConfigKit, UI, Wheel, StickKeyboard, MyWheels, ConsumableWheel, Paddles | Native Forever/Camelot materials and states; measured wrapping, scrollable details above pinned Apply, readable picker names, solid radial wheels and matching editor. |
| Trigger forwarding | Toggle | Direct secure bindings preserve original target/button and both hardware edges; a secure wrapper tracks held-trigger use without changing native action attributes. |

## Porting boundaries

- Upstream already has equivalents for addon-owned sticky channels (`0c11042`,
  `5a66637`) and positive ammo-ID validation (`7e5b789`). The local Message changes
  include recipient/draft regressions; they are not claimed as a new upstream fix.
- Upstream's automatic per-character profiles differ from this branch's explicit
  role activation and shared-utility model. Its saved-data scope also includes
  supplies/custom resources and wheel categories. Reconcile these semantics and
  migrations deliberately; do not replace the current Profiles file blindly.
- Upstream now routes stance/form-dependent actions through `M:BarMacro` and
  `relayMacros`. A port of direct Toggle binding must preserve those semantics.
- Upstream 1.11.7 rejects macro/multiline edit boxes in Fields.lua to avoid flattening
  macro bodies; it also gates range hooks and includes surnames in profile keys.
  Preserve these fixes. This branch has no generic Fields module. Its profile
  `UnitFullName()` identity still needs a Forever surname acceptance check.
- This branch does not contain upstream's generic field keyboard, stance support,
  hold/release wheel changes or all later native-button protection work.

## Verification and limits

All 35 TOC Lua modules compiled with Lua 5.1. All 102 Lua regression groups across
15 test files passed, including 648 mapping comparisons. Seven Python package/release
tests passed. The installed local payload was checked byte-for-byte against its package.

Lua tests load the actual addon modules with mocked game APIs. They do not prove
secure-engine behavior, macro execution, real controller feel or in-game rendering.
The user has not tested macros in this build. The direct-binding change is a
preventive improvement, not a reproduced diagnosis of every reported macro failure.
Native secure handler contracts were checked against installed client source.

Run the Lua files in `tools/test_*.lua` with Lua 5.1 from the addon root. Run Python
checks with `python -m unittest discover -s tools -p "test_*.py"`, then
`python tools/release.py check v1.8.2-local.5` and `python tools/package.py`.

Artwork previews are labeled source-based reconstructions with fixture data, not
in-game screenshots. Full HUD/trigger layers, supplies combinations and some picker
views still need human visual acceptance. No WoW launch or game-input automation is
part of the supplied test process. See [art-source notes](design/reforged/README.md)
for source contents and optional Blender rebuild prerequisites.
