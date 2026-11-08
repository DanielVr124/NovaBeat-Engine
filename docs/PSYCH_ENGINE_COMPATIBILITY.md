# Official Psych Engine compatibility

## Compatibility target

NovaBeat's compatibility target is the **official ShadowMario Psych Engine 0.7.3 mod format and scripting API**. Psych forks are out of scope unless explicitly added later.

The goal is to run compatible Psych mods inside NovaBeat's own gameplay runtime. This is not a plan to bundle a second complete copy of Psych Engine or to ship other people's mod assets with NovaBeat. Installed mods remain separate packages.

## Architecture

Keep the native V-Slice path and Psych compatibility path isolated:

1. **Package discovery** identifies Psych folders even when they do not contain NovaBeat or Polymod metadata. It records the declared/detected engine and version, and inventories the Psych-specific content.
2. **Data adapters** read Psych song charts, character/stage data, events, note types, dialogue, and other standard data formats, then map them into NovaBeat runtime models.
3. **Lua runtime** executes Psych Lua scripts and exposes the expected globals, properties, callbacks, timers, tweens, sprite helpers, sound helpers, and gameplay functions.
4. **HScript runtime** executes supported Psych HScript files through a separate adapter, with the same game lifecycle and object model.
5. **Gameplay lifecycle bridge** dispatches callbacks in Psych's expected order (global/song/stage/character/event/note-type scripts, create/update/beat/step/note/pause/game-over/end-song callbacks, and script return-value handling).
6. **Compatibility tests** run known-good, minimal fixtures for each feature and representative real mods before the engine marks a Psych package launchable.

The script runtimes must be behind platform-neutral interfaces. Platform-specific interpreter implementations can be selected per target; a desktop-only interpreter must never be advertised as HTML5 or mobile support.

## Feature coverage

A Psych package is not considered supported merely because its folder or chart can be detected.

The compatibility checklist includes:

- Psych folder and metadata detection, version identification, and mod load order.
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

The intended product goal is Windows, Android, iOS, and HTML5, but support is enabled per platform only after its interpreter and APIs are implemented and tested. In particular, native LuaJIT availability does not prove that the same Lua runtime works in a browser build.

Mod assets and scripts are loaded from the installed/downloaded mod package. They are not added to NovaBeat's base asset bundle, so the number of supported mods does not multiply the default game download.

## Safety and launch gate

Mod scripts are executable code. Installing and running an untrusted mod must be an explicit player action with a clear source and warning. Script APIs must not expose unrestricted process execution, arbitrary native library loading, or unrestricted file/network access.

A Psych package remains **detected but not launchable** until an end-to-end test proves its chart loads, gameplay starts, its required scripts execute, and the song can finish without a compatibility-blocking error. A detected folder, parsed chart, or successful compile is not sufficient.

## Implementation sequence

1. Improve package detection and diagnostics without changing launchability.
2. Add Psych chart/data readers and validate them against fixtures from official 0.7.3.
3. Add the Lua interpreter adapter and core callback/property API.
4. Add stage, character, event, and note-type script loading.
5. Add HScript and the remaining high-use Psych API surface.
6. Expand compatibility fixtures, test representative mods, and enable launchability only for the verified feature set on each platform.

## Current status

The repository already has an experience scanner and an engine bridge that can label some packages as Psych Engine. The bridge currently marks Psych packages as not launchable, correctly, because no Psych Lua/HScript runtime or compatible gameplay API is integrated yet. The first implementation pass is strengthening discovery; runtime support is still pending.
