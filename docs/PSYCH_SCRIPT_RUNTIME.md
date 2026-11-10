# Psych Lua and HScript compatibility status

NovaBeat's current target is the **official Psych Engine 0.7.3 Lua API baseline** for classic Psych song packages. This is a broad compatibility layer, not a full copy of Psych Engine. It does not claim that every mod or every fork works.

## Interpreters and loading

- Separate Lua and HScript interpreter instances per script file.
- Lua uses hxvm-lua with native Lua on C++ targets; the HTML5 build includes Fengari. The installed-mod folder loader is native-only.
- HScript uses SScript with a bounded execution budget and a restricted preset. It exposes common classes and aliases including `FlxG`, `FlxBasic`, `FlxCamera`, `FlxObject`, a script-safe `FlxPoint` wrapper, `FlxSprite`, `FlxText`, `FlxSubState`, `FlxMath`, `FlxEase`, `FlxTween`, `FlxTimer`, a script-safe `FlxColor` wrapper, `Preferences`/`ClientPrefs`, `Stage`, `Bopper`, `PsychCamera`, `CustomSubstate`, `Paths`, `Conductor`, `PlayState`, `Character`, and `Note`.
- `addHaxeLibrary` uses a strict allowlist. Arbitrary class loading and native reflection are not exposed.
- Global scripts load from each enabled Psych package's `scripts/` folder. Matching chart-referenced stage scripts (`stages/<stage>`), character scripts (`characters/<id>`), custom-event scripts (`custom_events/<event>`), custom-note-type scripts (`custom_notetypes/<type>`), and matching song scripts in `data/<song>/` are loaded by name.
- `addLuaScript` and `addHScript` resolve additional scripts only inside enabled mod `scripts/` folders. Paths are normalized and traversal is rejected. `removeLuaScript` and `removeHScript` invoke `onDestroy` and dispose the interpreter.
- A named `custom_substates/<name>` script loads when `openCustomSubstate(name)` is called and is unloaded when that substate is destroyed.
- Script errors are isolated and traced with their source path.

## Lifecycle callbacks

The bridge covers script creation, update, step, beat, section, countdown, song start/end, pause/resume, note spawn/hit/miss/hold-drop, event dispatch, game-over start/confirm, custom-substate lifecycle, timers, tweens, and sound completion. Supported callbacks include:

- `onCreate`, `onCreatePost`, `onUpdate`, `onUpdatePost`
- `onStepHit`, `onBeatHit`, `onSectionHit`
- `onCountdownTick`, `onStartCountdown`, `onCountdownStarted`, `onCountdownFinished`
- `onSongLoaded`, `onSongStart`, `onEndSong` (legacy `onSongEnd` fallback), `onEvent`
- `onPause`, `onResume`, `onGameOver`, `onGameOverStart`, `onGameOverConfirm`, `onDestroy`
- `goodNoteHit`, `opponentNoteHit`, `noteMiss`, `noteMissPress`, `onSpawnNote`, `onHoldNoteDrop`
- `onCustomSubstateCreate`, `onCustomSubstateCreatePost`, `onCustomSubstateUpdate`, `onCustomSubstateUpdatePost`, `onCustomSubstateDestroy`
- `onTimerCompleted`, `onTweenCompleted`, and `onSoundFinished`

`onGameOverStart` runs after the game-over substate exists. `onGameOverConfirm(retry)` receives `true` for retry and `false` when backing out. It is dispatched only from the game-over screen; pause-menu retry does not trigger it.

Callback return values use Psych's function sentinel values and Lua-first/HScript-second dispatch. `Function_Stop` cancels the associated gameplay event; the language-specific stop sentinels stop dispatch at their documented boundaries.

## Live globals and script communication

Timing globals (`bpm`, `curBpm`, `crochet`, `stepCrochet`, `curStep`, `curBeat`, `curDecStep`, `curDecBeat`, `songPosition`, and `songLength`) are refreshed before callback execution. Live song globals also include score, misses, hits, combo, health, song/difficulty identifiers, playback rate, vocals state, stage, character objects/names/default positions, camera follow position, and common gameplay preferences.

- `setGlobal`, `getVar`, `setVar`, `removeVar`
- `callOnScripts`, `callOnLuas`, `callOnHScript`, `setOnScripts`, `setOnLuas`, `setOnHScript`
- `callScript`, `getGlobalFromScript`, `setGlobalFromScript`, `getGlobals`, `isRunning`
- `runHaxeCode`, `runHaxeFunction`, `runLuaCode`, `runLuaFunction`

The inline Haxe/Lua helper interpreters are separate from loaded mod scripts: they can be invoked explicitly, but do not receive lifecycle callbacks or appear in `getRunningScripts()`. `getGlobals(script)` intentionally returns a safe snapshot of NovaBeat-injected runtime globals; it does **not** expose an arbitrary interpreter's complete private global table. Script-specific private-global enumeration is not implemented.

## Gameplay API surface

### Properties, scoring, and input
- `getProperty`, `setProperty`, `getPropertyFromClass`, `setPropertyFromClass` (restricted class allowlist), `getPropertyFromGroup`, `setPropertyFromGroup`
- `getScore`, `setScore`, `addScore`, `getMisses`, `setMisses`, `addMisses`, `getHits`, `setHits`, `addHits`, `getHealth`, `setHealth`, `addHealth`
- `getSongPosition`, `getSongName`, `getDifficulty`, `getSongLength`, `getRandomInt`, `getRandomFloat`, `getRandomBool`
- Keyboard, gamepad, and mouse queries: `keyboardJustPressed`, `keyboardPressed`, `keyboardReleased`, `anyGamepadJustPressed`, `anyGamepadPressed`, `anyGamepadReleased`, `gamepadAnalogX/Y`, `mouseClicked`, `mousePressed`, `mouseReleased`, `getMouseX/Y`, `getMouseWheel`. Mouse coordinates use camera screen space to match Psych helper behavior.
- Rating and color helpers: `setRatingPercent`, `setRatingName`, `setRatingFC`, `getColorFromName`, `getColorFromString`, `getColorFromHex`, and `FlxColor`.

### Characters, cameras, and notes
- `getCharacterX/Y`, `setCharacterX/Y`, `characterDance`, `characterPlayAnim`, `playAnim`, `addOffset`, and `cameraSetTarget`
- `addCharacterToList` instantiates and caches a supported NovaBeat character's assets. It does not replace the active BF/DAD/GF; active character swapping and the associated icon/stage transaction are not implemented.
- `cameraShake`, `cameraFlash`, `cameraFade`, `triggerEvent`
- Note group access and note tweens, including `noteTweenX/Y/Angle/Direction/Alpha`

### Sprites, animation, text, and geometry
- Basic sprite creation, animation, visibility/camera, scale, scroll-factor, size, add/remove, and draw-order helpers.
- Animation helpers: `addAnimation`, `addAnimationByPrefix`, `addAnimationByIndices`, `objectPlayAnimation`, and deprecated aliases.
- FlxAnimate: `makeFlxAnimateSprite`, `loadAnimateAtlas`, `addAnimationBySymbol`, and `addAnimationBySymbolIndices` create a `FunkinSprite` backed by NovaBeat's installed Adobe Animate atlas renderer. The standard folder must contain `Animation.json` and the referenced spritemap assets; `images/` prefixes are accepted and traversal/absolute paths are rejected.
- Sprite helpers: `makeGraphic`, `loadGraphic`, `loadFrames` (Sparrow/Packer), `updateHitbox`, `updateHitboxFromGroup`, `screenCenter`, `setBlendMode`, `objectsOverlap`, `getPixelColor`, `luaSpriteExists`, `luaTextExists`.
- Text helpers: `makeLuaText`, `addLuaText`, `setTextString`, `setTextSize`, `setTextColor`, `setTextFont`, `setTextAlignment`, and `setTextBorder`.
- Geometry: `getMidpointX/Y`, `getGraphicMidpointX/Y`, `getScreenPositionX/Y`.

### Timers, tweens, custom substates, and audio
- Named timers and tweens: `runTimer`, `cancelTimer`, `doTweenX/Y/Alpha/Angle/Zoom/Color`, `startTween`, `cancelTween`.
- Named custom substate helpers: `openCustomSubstate`, `closeCustomSubstate`, `insertToCustomSubstate`.
- Audio: `playSound`, tagged stop/pause/resume/volume, `playMusic`, `stopMusic`, `getSoundVolume/Time/Pitch`, `setSoundTime/Pitch`, `soundFadeIn/Out/Cancel`, `musicFadeIn/Out`, and `luaSoundExists`.
- Asset helpers: `precacheImage`, `precacheSound`, `precacheMusic`.
- Song and cutscene flow: `startCountdown`, `endSong`, `restartSong`, `loadSong` (only uniquely resolved songs in the active imported Psych packages), `exitSong` (returns to NovaBeat Freeplay), `startDialogue` (reads the active song's `data/<song>/` JSON, supports typed text, basic Sparrow portrait metadata, optional music, and the cutscene-advance input), and `startVideo` (uses the platform's existing video player with the default start-cutscene flow; Psych's optional mid-song/loop/skip controls are not mapped).
- HUD: `setTimeBarColors` controls a separate live time bar shown only for imported Psych songs. The exposed `timeBar` and `timeTxt` are NovaBeat-backed compatibility objects; the time bar uses two color segments rather than Psych's exact gradient widget.

The standard Psych 0.7.3 Lua callback comparison covers **123 of 123** registered callbacks, and all **14 of 14** deprecated callbacks in that release are present. The extended helper audit also registers the names found across the 0.7.3 `psychlua` helper modules. An automated registration smoke check pins the complete official callback list. This is API-surface coverage, not perfect semantic parity: FlxAnimate supports the normal atlas-folder workflow through NovaBeat's `FunkinSprite` renderer, but Psych's separate JSON override overload is not mapped; runtime shaders are available only on native `sys` targets, and reflection calls are deliberately constrained to approved classes and methods.

## Not supported yet

- Exact visual parity for Psych's original dialogue box: the adapter renders the standard dialogue JSON, text typing, optional music, basic Sparrow portrait metadata/expressions/position/scale, and advance flow, but not all original speech-bubble animation, idle/loop offsets, locale fallback, or editor features.
- Exact parity for all Psych time-bar properties and gradients. The compatibility bar is a NovaBeat-backed two-segment bar with `timeBar`, `timeTxt`, `timeBarType`, and `setTimeBarColors`.
- Arbitrary custom note classes in `custom_notes/`, custom note-skin rendering, non-standard lane layouts, alternate section types, GF-specific sections, or custom arrow/splash skin metadata.
- Psych stage JSON and the full stage registry/lifecycle. Matching stage Lua/HScript files can render scripted overlays, but Psych-specific stage JSON, default zoom rules, and all camera behavior are not mapped.
- All Psych character formats and class implementations. The adapter converts common Sparrow character JSON; Packer, AnimateAtlas, multi-atlas, custom class, and advanced character formats remain gated. Active character replacement is not yet implemented.
- Every detail of the Psych HScript preset and exact private-global sharing semantics.
- Full parity for Psych's mod settings UI. `getModSetting` reads the owning mod's `data/settings.json` defaults and the per-mod values stored in the active game save; `initSaveData`, `getDataFromSave`, `setDataFromSave`, `flushSaveData`, and `eraseSaveData` provide mod-namespaced save slots.
- The FlxAnimate adapter currently supports the standard atlas-folder format through NovaBeat's existing renderer. Psych's separate `spriteJson` / `animationJson` override arguments and non-folder image-only inputs are not mapped; atlases must use the normal folder layout.
- Full unrestricted reflection. `callMethod`, `callMethodFromClass`, and `createInstance` use explicit class/method allowlists rather than Psych's arbitrary `Type.resolveClass` behavior.
- Filesystem access is mod-scoped: file read/write/delete/list helpers operate only inside the currently executing mod folder. Absolute paths and traversal are rejected; Lua's general `io` and `os` libraries stay disabled.
- Every version-specific legacy extension or fork beyond the audited 0.7.3 surface.
- HTML5 local-mod discovery and launching. The browser interpreter can compile, but the current installed-mod folder scanner depends on native filesystem access.

The Lua VM removes general filesystem, OS, package-loading, debug, and garbage-collector entry points. Psych-compatible file helpers are separately exposed with paths confined to the executing mod's folder. Common Lua 5.1/LuaJIT aliases (`unpack`, `loadstring`, `string.gfind`, `math.mod`, `math.atan2`, and `table.maxn`) are supplied where missing. This does not make Fengari a complete LuaJIT replacement.

A successful script parse, API registration smoke test, or compile does not prove that a representative mod plays correctly. Real-mod validation is still required. The API comparison does not measure full signature parity, event ordering for every edge case, asset compatibility, or whether a mod-specific chart behaves identically to Psych. Dialogue file/portrait lookup currently requires native installed-mod filesystem access.

## Debug smoke test

On a debug build, open the developer console during gameplay and run:

```text
testPsychScriptRuntimes
```

The test checks Lua/HScript execution, argument passing, injected globals, the FlxPoint HScript preset wrapper, blocked Lua host entry points, and registration of the supported gameplay API. It does not simulate a complete song or prove a real mod is compatible.

## Platform note

The interpreter dependencies are configured for native C++ and HTML5. Installed Psych mod discovery and runtime script lookup still use native filesystem access, so HTML5 local-mod launching is not available. Runtime shaders and mod-folder read/write helpers are native-only; their API names remain registered in the browser build and report unsupported operations. Windows and Android builds must still pass before native testing.


## GorillaFunkin DEMO validation notes

The inspected GorillaFunkin DEMO package uses classic Psych v1 charts with the normal four-key split (legacy note lanes 0–3 and 4–7), standard `Hurt Note` notes, song-local Lua, custom-event Lua, custom stage Lua plus Psych stage JSON, three pre-song MP4 videos, and Psych `weeks/*.json` story groups. Its nested legacy event arrays are already read by the event importer.

The compatibility layer now also:
- reads `character.animation.curAnim.name` as the active NovaBeat character animation name, normalizing NovaBeat's sustain-hold suffix for Psych camera scripts;
- exposes the Psych HUD aliases `scoreTxt`, `timeBar`, `timeBarBG`, and `timeTxt` to custom-event property/tween helpers;
- resolves week songs by either their folder ID or their imported display title, matches menu-character JSON filenames case-insensitively, imports each menu character's confirm animation, and respects the week JSON's difficulty restriction;
- keeps a song launchable when a Psych chart names a player-side character that is not bundled in that mod or registered by the host engine, using NovaBeat's standard BF as a safe fallback. Missing opponent/GF character data remains a validation error.

This fallback is intentionally limited to the playable character: the inspected package's `player1` names `bf capuchin`, `bf capuchin run`, and `KFIC` are not in the mod's own `characters/` folder (the first two exist only in the original GorillaFunkin installation's base assets, while `KFIC` has no definition in that install). To display those exact player-side variants in a different engine, the mod author would need to bundle their character JSON definitions with the mod.

This is targeted compatibility for the inspected package, not a guarantee of complete Psych 0.7.3 or fork parity. A successful HTML/native compile still needs to be followed by an actual native gameplay test with the mod installed.
