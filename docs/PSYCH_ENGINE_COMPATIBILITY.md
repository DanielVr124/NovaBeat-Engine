# Official Psych Engine compatibility

## Compatibility target

NovaBeat's detection target is **official Psych Engine across version families**, including older and newer releases. Detection is intentionally version-agnostic: a package can be identified from its long-lived Psych chart/script layout even when it does not declare an engine version. When metadata explicitly supplies a Psych Engine version, NovaBeat displays it; otherwise it displays **Psych Engine (version unknown)**. Psych forks are out of scope unless explicitly added later.

The goal is to detect official Psych packages regardless of release version, then run compatible mods inside NovaBeat's own gameplay runtime. Detection and runtime compatibility are separate: recognizing a package from an older/newer version does not imply all of that version's APIs have already been implemented. The initial scripting-API compatibility baseline for runtime development is Psych 0.7.3, with version-specific adapters added as testing reveals differences. This is not a plan to bundle a second complete copy of Psych Engine or to ship other people's mod assets with NovaBeat. Installed mods remain separate packages.

## Architecture

Keep the native V-Slice path and Psych compatibility path isolated:

1. **Package discovery** identifies Psych folders across version families even when they do not contain NovaBeat or Polymod metadata. It reads explicit Psych-version fields from supported metadata files, but never mistakes a mod's generic `version` field for the engine version. If no exact Psych version is declared, it records the engine as Psych with the version unknown, and inventories the Psych-specific content.
2. **Data adapters** read Psych song charts, character/stage data, events, note types, dialogue, and other standard data formats, then map them into NovaBeat runtime models.
3. **Lua runtime** executes Psych Lua scripts and exposes the expected globals, properties, callbacks, timers, tweens, sprite helpers, sound helpers, and gameplay functions.
4. **HScript runtime** executes supported Psych HScript files through a separate adapter, with the same game lifecycle and object model.
5. **Gameplay lifecycle bridge** dispatches callbacks in Psych's expected order (global/song/stage/character/event/note-type scripts, create/update/beat/step/note/pause/game-over/end-song callbacks, and script return-value handling).
6. **Compatibility tests** run known-good, minimal fixtures for each feature and representative real mods before the engine marks a Psych package launchable.

The script runtimes must be behind platform-neutral interfaces. Platform-specific interpreter implementations can be selected per target; a desktop-only interpreter must never be advertised as HTML5 or mobile support.

## Feature coverage

A Psych package is not considered supported merely because its folder or chart can be detected.

The version-agnostic detection checklist includes:

- Psych folder and metadata detection across older/newer official layouts; explicit version extraction where declared; safe `version unknown` fallback where it is not; and mod load order.
- Psych song chart JSON, difficulties, note lanes, sustain notes, BPM changes, song speed, player/opponent/GF assignments, and stage assignment.
- Character definitions, sprite atlases/animations, icons, offsets, and character script hooks.
- Stage data, stage Lua/HScript, foreground/background ordering, camera behavior, and common stage effects.
- Global scripts under `scripts/`, song scripts under `data/<song>/`, stage scripts under `stages/`, character scripts, custom events, and custom note types.
- Lua API compatibility: globals, callbacks, property access, object groups, sprites, animations, cameras, tweens, timers, audio, input, and common helper functions.
- HScript compatibility and the shared script lifecycle.
- Story/freeplay metadata, dialogue/cutscenes, videos where supported by the target platform, shaders, and common mod settings.
- Multiple enabled mods, predictable load order, script cleanup, and error isolation.

Missing APIs must be reported clearly. NovaBeat must not silently skip a script and then claim the mod is compatible.

## Platform policy

The intended product goal is Windows, Android, iOS, and HTML5. The current classic-chart adapter uses native mod-folder scanning (`sys`) and is therefore enabled only on native targets. It is not yet available in HTML5. Lua/HScript interpreters must be implemented and tested separately per platform; native LuaJIT availability does not prove that the same runtime works in a browser build.

Mod assets and scripts are loaded from the installed/downloaded mod package. They are not added to NovaBeat's base asset bundle, so the number of supported mods does not multiply the default game download.

## Safety and launch gate

Mod scripts are executable code. Installing and running an untrusted mod must be an explicit player action with a clear source and warning. Script APIs must not expose unrestricted process execution, arbitrary native library loading, or unrestricted file/network access.

A package can be marked launchable only for the compatibility tier it actually passes. The current **early scripted-song tier** requires a valid legacy Psych `data/<song>/<chart>.json` chart plus an `Inst` audio file under the matching `songs/<song>/` or `assets/songs/<song>/` folder. It supports global Lua/HScript files under `scripts/`, matching song-local files under `data/<song>/`, chart-referenced `custom_events/` and `custom_notetypes/` scripts, matching stage/character scripts, and named custom substate scripts when opened by a script. It imports standard chart note lanes/sustains/BPM changes, common chart event shapes and `events.json`, and string-valued note kinds when a matching note-type script exists. It accepts standard Sparrow character JSON with a custom character ID and matching stage scripts; custom stages currently render as scripted overlays over the built-in stage container. Arbitrary custom note classes, non-standard lane layouts, alternate section types, GF-specific sections, and custom note skins remain blocked rather than being guessed. The standard psych substate create/update/destroy callback set and basic text/sprite helpers are available. The current API subset is not full Psych compatibility; mods can still call unsupported APIs or behave incorrectly. A successful compile alone is not proof that a representative mod plays correctly.

## Implementation sequence

1. ✅ Version-agnostic package detection and diagnostics.
2. ✅ First native classic-chart compatibility tier using the existing FNF legacy chart importer; unsupported script roots and chart-level features are blocked instead of silently replaced or dropped.
3. Validate the first tier with representative script-free Psych packages on Windows and Android, including their audio and end-of-song flow.
4. ✅ Add separate Lua and HScript interpreter adapters with global/song script loading and an initial lifecycle/note callback bridge.
5. ✅ Implement an initial high-use Psych API subset: properties/groups, basic sprites, timers, tweens, limited audio, Lua↔HScript calls, and common built-in events. Expand input, advanced audio, and less common APIs after fixture testing.
6. ✅ Add chart-referenced custom event and custom note-type script loading, with conservative chart validation.
7. ✅ Add an initial Sparrow character JSON adapter and script-driven stage overlay; advanced character/stage formats remain gated.
8. ✅ Add named custom substate lifecycle callbacks and core UI helpers; expand API coverage and validate against representative mods on each target platform.

## Current status

The repository has an experience scanner and a version-agnostic Psych detector. It checks long-lived official Psych script roots, Lua/HScript files, legacy chart JSON, Psych week/character/stage JSON schemas, common nested `mods/<mod>` extraction layouts, and explicit engine/version fields from NovaBeat, Polymod, and generic package metadata. It deliberately does not infer the Psych engine version from a generic mod `version` field.

The current native classic Psych chart tier loads global/song Lua and HScript files plus chart-referenced custom event, custom note-type, stage, and character scripts. It preserves string-valued note kinds, adapts common chart event shapes and external `events.json`, converts the common Sparrow character JSON format, and supports simple script-driven stage overlays. It also includes named custom substates with create/createPost/update/updatePost/destroy callbacks, plus basic text and graphic helpers. Arbitrary custom note classes, custom note skins, advanced stage/character schemas, and many Psych 0.7.3 APIs remain unsupported. The mod-folder discovery and asset loader still rely on native filesystem access; HTML5 local-mod launching is not implemented. Windows, Android, and HTML5 builds are being validated separately, and a successful compile is not proof that representative gameplay and audio work.
