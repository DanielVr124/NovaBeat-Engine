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
  explicit set of common Psych HScript globals (FlxG, FlxSprite, FlxText,
  FlxSubState, FlxTween, FlxTimer, FlxColor, Paths, Conductor, PlayState,
  Character, and Note).
- Global scripts load from each selected Psych package's `scripts/` folder.
  Matching chart-referenced stage scripts (`stages/<stage>`), character scripts
  (`characters/<id>`), custom-event scripts (`custom_events/<event>`), and
  custom-note-type scripts (`custom_notetypes/<type>`) are loaded by name,
  followed by matching song scripts in `data/<song>/`.
- A named `custom_substates/<name>` script is loaded only when a script calls
  `openCustomSubstate(name)`; it is unloaded when that substate is destroyed.
- Script errors are isolated and traced with their source path; an individual
  script that fails to load is not treated as a successful load.

### Callback bridge
Supported callbacks currently include:
- `onCreate`, `onCreatePost`
- `onUpdate`, `onUpdatePost`
- `onStepHit`, `onBeatHit`, `onSectionHit`
- `onCountdownTick`, `onCountdownFinished`
- `onSongLoaded`, `onEvent`, `onSoundFinished`
- `onStartCountdown`, `onSongStart`, `onSongEnd`
- `onPause`, `onResume`, `onGameOver`, `onDestroy`
- `goodNoteHit`, `opponentNoteHit`, `noteMiss`, `noteMissPress`, `onSpawnNote`,
  `onHoldNoteDrop`, `onGameOverConfirm`
- `onCustomSubstateCreate`, `onCustomSubstateCreatePost`,
  `onCustomSubstateUpdate`, `onCustomSubstateUpdatePost`,
  `onCustomSubstateDestroy`

`onGameOverConfirm` is dispatched only when the player confirms the game-over
screen. Retrying from the pause menu does not trigger this callback.

Song timing globals include `bpm`, `curBpm`, `crochet`, `stepCrochet`,
`curStep`, `curBeat`, `curDecStep`, `curDecBeat`, and `songPosition`.

Live globals set through `setGlobal` are scoped to the active song and are
available to scripts loaded later in that song. `setOnScripts`, `setOnLuas`,
and `setOnHScript` update only interpreters that are already loaded; transient
values are not promoted into the persistent built-in global table. Clearing the
song runtime resets this per-song global state.

Callback return values use Psych 0.7.3's official string sentinel values and
preserve Lua-first/HScript-second ordering. `Function_Stop` cancels the
associated gameplay action; `Function_StopLua`, `Function_StopHScript`, and
`Function_StopAll` stop script dispatch at their language boundaries. Note callbacks receive direction, note kind,
sustain state, and a live note-group index.

### Initial gameplay API surface
- `getProperty`, `setProperty`
- `getPropertyFromClass`, `setPropertyFromClass` for a small class allowlist
- `getPropertyFromGroup`, `setPropertyFromGroup`
- `score`, `misses`, `hits`, `combo`, `rating`, and `ratingPercent` map to the
  live song score/tallies
- `getVar`, `setVar`, `removeVar`
- `getSongPosition`, `getRandomInt`, `getRandomFloat`, `getRandomBool`
- Basic keyboard, gamepad, and mouse queries: `keyboardJustPressed`,
  `keyboardPressed`, `keyboardReleased`, `anyGamepadJustPressed`,
  `anyGamepadPressed`, `anyGamepadReleased`, `gamepadAnalogX`,
  `gamepadAnalogY`, `mouseClicked`, `mousePressed`, `mouseReleased`,
  `getMouseX`, `getMouseY`, and `getMouseWheel`
- Basic gameplay utility helpers: `getColorFromHex`, `addScore`, `setScore`,
  `addMisses`, `setMisses`, `addHits`, and `setHits`
- `addHaxeLibrary` with a restricted Flixel/NovaBeat class allowlist
- `runHaxeCode` / `runHaxeFunction` and `runLuaCode` / `runLuaFunction`
  for basic cross-language code and function calls
- `callOnScripts`, `callOnLuas`, `callOnHScript`, `setOnScripts`, `setOnLuas`,
  and `setOnHScript` for inter-script communication
- Named timers/tweens: `runTimer`, `cancelTimer`, `doTweenX/Y/Alpha/Angle/Zoom/Color`,
  `cancelTween`, with `onTimerCompleted` and `onTweenCompleted` callbacks
- Basic sprite creation, animation, visibility/camera, scale, scroll-factor,
  size, add/remove, and draw-order helpers
- Basic text and graphic helpers: `makeGraphic`, `makeLuaText`, `addLuaText`,
  `setTextString`, `setTextSize`, `setTextColor`, `setTextFont`,
  `setTextAlignment`, and `setTextBorder`
- Named custom substate helpers: `openCustomSubstate`, `closeCustomSubstate`,
  and `insertToCustomSubstate`
- Basic sound playback/control: `playSound`, tagged stop/pause/resume/volume,
  `playMusic`, and `stopMusic` (no arbitrary streaming or external file access)
- Basic `triggerEvent` handling for camera zoom, screen shake, and set-property

The Lua VM removes its filesystem, OS, package-loading, debug, and garbage
collector globals. It also provides compatibility aliases for commonly used
Lua 5.1/LuaJIT standard-library names (`unpack`, `loadstring`,
`string.gfind`, `math.mod`, `math.atan2`, and `table.maxn`) when the
embedded Lua version does not provide them. This does not make the embedded
Lua runtime a complete LuaJIT replacement. HScript execution is sandboxed and
receives only the common preset classes listed above plus the explicit runtime
API.

## Not supported yet

The current tier still does not support:
- Arbitrary custom note classes in `custom_notes/`, custom note-skin rendering,
  non-standard lane layouts, alternate section types, GF-specific sections,
  or custom arrow/splash skin metadata.
- Psych stage JSON and the full stage registry/lifecycle. A matching
  `stages/<id>` Lua/HScript file can draw a scripted stage over NovaBeat's
  default stage container; the default props are hidden, but Psych-specific
  default zooms, stage JSON, and every advanced camera behavior are not mapped.
- All Psych character formats and class implementations. The adapter converts
  the common Sparrow `image` + `animations` JSON format and maps basic
  positions, camera offsets, icon, scale, sing duration, and pixel/flip flags.
  Packer, AnimateAtlas, multi-atlas, custom class, and other advanced character
  formats remain unsupported.
- Every detail of custom note-type behavior. The chart's string note kind is
  preserved, the matching `custom_notetypes/<type>` script is loaded, and
  note callbacks receive the type, but custom note-kind classes and all
  per-type scoring/health/animation rules are not automatically recreated.
- The complete Psych HScript preset/class registry and exact global-sharing
  semantics between every version of Lua and HScript.
- Advanced sound features (voice channels, audio time/volume queries, sound
  fading/filters), shaders, contextual action/control binding APIs, dialogue,
  cutscene, save-data, and mod-setting APIs.
- Every version-specific legacy API and extension used by arbitrary mods.
- HTML5 local-mod discovery and launching.

The compatibility gate still blocks unsupported custom note classes, stage
and character assets that do not have a matching adapter, custom skin data,
and chart structures that cannot be mapped safely. The APIs above are a
limited subset; a real mod can still depend on functions NovaBeat has not
implemented. A successful script parse or compile does not prove gameplay
compatibility.

## Debug smoke test

On a debug build, open the existing developer console while in gameplay and
run:

```text
testPsychScriptRuntimes
```

A passing result verifies HScript and Lua function execution, argument passing,
injected globals, and (for Lua) that host filesystem/process/package/debug
entry points remain unavailable. It does not prove that a representative Psych
mod plays correctly. The next validation step is to test real, script-light Psych song
packages with their actual scripts and audio.

## Platform note

The interpreter dependencies are configured for native C++ and HTML5 builds.
However, current Psych folder discovery reads installed mod folders through
native filesystem access, so the script-enabled Psych mod path is not yet
available in the browser. Android and Windows require successful native build
and gameplay validation before the feature is considered tested.
