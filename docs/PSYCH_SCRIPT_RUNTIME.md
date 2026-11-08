# Psych Script Runtime Foundation

This branch now carries separate interpreter adapters for Psych-style HScript
(`.hx`) and Lua (`.lua`) source files.

## Implemented in the interpreter foundation

- A separately owned interpreter instance per source file.
- HScript execution through SScript, the dialect used by Psych Engine's
  HScript integration.
- Lua execution through hxvm-lua: native Lua on C++ targets and Fengari on
  JavaScript targets.
- Shared compatibility constants and a callback dispatcher that preserves
  callback return values for later Psych stop/continue semantics.
- HScript instruction/time budgets and a Lua instruction hook.
- Removal of Lua's filesystem, OS, package-loading and debug globals.
- A debug-console smoke test named `testPsychScriptRuntimes` that verifies
  each runtime can load a function and call it.

## Deliberately not enabled yet

This is **not full Psych Engine compatibility** and does not yet make
script-dependent mods launchable. The interpreter does not yet expose the
Psych APIs or connect mod files to gameplay. Missing pieces include:

- Loading global, song, stage, character, event and note-type scripts in
  Psych's established order and scope.
- Psych globals such as `setProperty`, `getProperty`, `triggerEvent`,
  `makeLuaSprite`, `addLuaSprite`, `runHaxeCode`, and class accessors.
- The complete lifecycle/callback map, including countdown, update, beat,
  step, note hit/miss, event, pause/retry and destroy behavior.
- Script-to-script globals and Lua/HScript cross-calls with Psych's exact
  return-value/stop semantics.
- Compatibility coverage for version-specific Psych APIs and extensions.

The chart-only launch gate in `PsychModRuntime.inspectPackage` remains
unchanged. A package containing scripts must not be marked launchable until
the required runtime/API behavior is implemented and tested against real mods.

## Smoke-test usage

On a debug build, open the existing developer console while in gameplay and
run:

```text
testPsychScriptRuntimes
```

A passing result verifies the HScript and Lua interpreter adapters only; it
does not prove gameplay compatibility with a Psych mod.
