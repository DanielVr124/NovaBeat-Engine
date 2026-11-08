# Psych Lua and HScript compatibility status

NovaBeat now has an early native Psych scripting tier for classic Psych song
packages. This is a limited compatibility layer, not a full replacement for
Psych Engine and not yet compatible with every Psych mod.

## Implemented

### Interpreters and loading
- Separate Lua and HScript interpreter instances per script file.
- Lua uses hxvm-lua with native Lua on C++ targets; the HTML5 build includes
  Fengari. The mod-folder loader itself is currently native-only.
- HScript uses SScript, with a bounded instruction/time budget and a small,
  explicit set of common Psych HScript globals (FlxG, FlxSprite, FlxTween,
  FlxTimer, FlxColor, Paths, Conductor, PlayState, Character, and Note).
- Global scripts load from each selected Psych package's `scripts/` folder;
  matching song scripts load from `data/<song>/`. Global scripts load before
  song-local scripts.
- Script errors are isolated and traced with their source path; an individual
  script that fails to load is not treated as a successful load.

### Callback bridge
Supported callbacks currently include:
- `onCreate`, `onCreatePost`
- `onUpdate`, `onUpdatePost`
- `onStepHit`, `onBeatHit`
- `onStartCountdown`, `onSongStart`, `onSongEnd`
- `onPause`, `onDestroy`
- `goodNoteHit`, `opponentNoteHit`, `noteMiss`, `onSpawnNote`

Callback return values support the basic Psych stop codes, including
language-specific stop behavior. Note callbacks receive direction, note kind,
sustain state, and a live note-group index.

### Initial gameplay API surface
- `getProperty`, `setProperty`
- `getPropertyFromClass`, `setPropertyFromClass` for a small class allowlist
- `getPropertyFromGroup`, `setPropertyFromGroup`
- `getVar`, `setVar`, `removeVar`
- `getSongPosition`, `getRandomInt`, `getRandomFloat`, `getRandomBool`
- `runHaxeCode` / `runHaxeFunction` and `runLuaCode` / `runLuaFunction`
  for basic cross-language code and function calls
- Named timers/tweens: `runTimer`, `cancelTimer`, `doTweenX/Y/Alpha/Angle/Zoom/Color`,
  `cancelTween`, with `onTimerCompleted` and `onTweenCompleted` callbacks
- Basic sprite creation, animation, visibility/camera, scale, scroll-factor,
  size, add/remove, and draw-order helpers
- Basic `triggerEvent` handling for camera zoom, screen shake, and set-property

The Lua VM removes its filesystem, OS, package-loading, debug, and garbage
collector globals. HScript execution is sandboxed and receives only the common
preset classes listed above plus the explicit runtime API.

## Not supported yet

The current tier deliberately keeps these package types unavailable:
- Custom Psych event scripts (`custom_events/`)
- Custom note types/notes (`custom_notetypes/`, `custom_notes/`)
- Custom substates (`custom_substates/`)
- Stage scripts (`stages/`) and custom character scripts (`characters/`)
- Custom stage JSON, character JSON/atlases, and Psych-specific stage/character
  lifecycle behavior
- Full Psych global-sharing semantics between script instances and the full
  Psych HScript preset/class registry
- Full sound, shader, input, dialogue, cutscene, save-data, and
  mod-setting APIs
- Every version-specific legacy API and extension used by arbitrary mods
- HTML5 local-mod discovery and launching

The code must not mark a package compatible merely because an interpreter can
parse its script files. Mods using unsupported script roots remain blocked.
The supported APIs are an initial subset; a real mod can still depend on
functions NovaBeat has not implemented.

## Debug smoke test

On a debug build, open the existing developer console while in gameplay and
run:

```text
testPsychScriptRuntimes
```

A passing result verifies that the HScript and Lua adapters can load a simple
function and call it. It does not prove that a representative Psych mod plays
correctly. The next validation step is to test real, script-light Psych song
packages with their actual scripts and audio.

## Platform note

The interpreter dependencies are configured for native C++ and HTML5 builds.
However, current Psych folder discovery reads installed mod folders through
native filesystem access, so the script-enabled Psych mod path is not yet
available in the browser. Android and Windows require successful native build
and gameplay validation before the feature is considered tested.
