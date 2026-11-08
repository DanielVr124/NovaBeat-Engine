package funkin.modding.psychlua;

import haxe.Exception;
import funkin.Conductor;
import funkin.modding.PsychModRuntime;
import funkin.modding.PsychModRuntime.PsychScriptSource;
import funkin.play.PlayState;

/**
 * Owns interpreter instances used by the Psych compatibility layer.
 *
 * It loads global and song-local scripts, dispatches supported Psych
 * lifecycle/note/game-over callbacks, exposes the bounded gameplay API,
 * and preserves Psych's Lua-first/HScript-second return semantics.
 */
@:nullSafety(Off)
class PsychScriptRuntime
{
  static final scripts:Array<PsychScriptInstance> = [];
  static final customSubstateScripts:Array<PsychScriptInstance> = [];
  static var activeModDirs:Array<String> = [];
  static var activeGlobals:Map<String, Dynamic> = [];
  static var inlineHScriptBridge:Null<PsychScriptInstance> = null;
  static var inlineLuaBridge:Null<PsychScriptInstance> = null;
  static inline final FUNCTION_STOP:String = "##PSYCHLUA_FUNCTIONSTOP";
  static inline final FUNCTION_CONTINUE:String = "##PSYCHLUA_FUNCTIONCONTINUE";
  static inline final FUNCTION_STOP_LUA:String = "##PSYCHLUA_FUNCTIONSTOPLUA";
  static inline final FUNCTION_STOP_HSCRIPT:String = "##PSYCHLUA_FUNCTIONSTOPHSCRIPT";
  static inline final FUNCTION_STOP_ALL:String = "##PSYCHLUA_FUNCTIONSTOPALL";

  static final sharedGlobals:Map<String, Dynamic> = [
    "Function_Continue" => FUNCTION_CONTINUE,
    "Function_Stop" => FUNCTION_STOP,
    "Function_StopLua" => FUNCTION_STOP_LUA,
    "Function_StopHScript" => FUNCTION_STOP_HSCRIPT,
    "Function_StopAll" => FUNCTION_STOP_ALL
  ];

  public static function setGlobal(name:String, value:Dynamic):Void
  {
    if (name == null || name.length == 0) return;
    // Dynamic game globals belong to the active song. Keeping them in
    // sharedGlobals would leak values (and object references) into later songs.
    activeGlobals.set(name, value);
    for (script in scripts)
      script.setVariable(name, value);
  }

  public static function removeGlobal(name:String):Void
  {
    if (name == null || name.length == 0) return;
    sharedGlobals.remove(name);
    activeGlobals.remove(name);
  }

  public static function setHScriptGlobal(name:String, value:Dynamic):Void
  {
    if (name == null || name.length == 0) return;
    for (script in scripts)
      if (script.language == "hscript") script.setVariable(name, value);
    if (inlineHScriptBridge != null)
      inlineHScriptBridge.setVariable(name, value);
  }

  /**
   * Expose only a small list of commonly used Haxe/Flixel classes. The
   * package argument is optional, matching Psych's addHaxeLibrary signature.
   * Arbitrary class resolution is deliberately not exposed to mod scripts.
   */
  public static function addHaxeLibrary(name:String, ?packageName:String = ""):Bool
  {
    if (name == null || name.length == 0) return false;
    var fullName:String = packageName == null || packageName.length == 0 ? name : packageName + "." + name;
    var allowed:Array<String> = [
      "flixel.FlxG",
      "flixel.FlxBasic",
      "flixel.FlxCamera",
      "flixel.FlxSprite",
      "flixel.FlxObject",
      "flixel.math.FlxMath",
      "flixel.math.FlxPoint",
      "flixel.tweens.FlxTween",
      "flixel.tweens.FlxEase",
      "flixel.util.FlxColor",
      "flixel.util.FlxTimer",
      "funkin.Paths",
      "funkin.Conductor",
      "funkin.play.PlayState",
      "funkin.play.notes.NoteSprite",
      "funkin.play.notes.Strumline",
      "funkin.play.character.BaseCharacter"
    ];
    if (allowed.indexOf(fullName) < 0) return false;

    // FlxColor is an abstract type rather than a runtime class. Resolve it
    // through the same safe wrapper used by the default HScript preset.
    if (fullName == "flixel.util.FlxColor")
    {
      setHScriptGlobal(name, PsychScriptInstance.createFlxColorApi());
      return true;
    }

    var resolved:Class<Dynamic> = Type.resolveClass(fullName);
    if (resolved == null) return false;
    setHScriptGlobal(name, resolved);
    return true;
  }

  public static function getGlobal(name:String):Dynamic
  {
    return activeGlobals.exists(name) ? activeGlobals.get(name) : sharedGlobals.get(name);
  }

  /**
   * Load global and song-local scripts for the currently activated Psych
   * packages. Global scripts always precede song scripts, matching the
   * established Psych loading order for these two supported scopes.
   */
  public static function loadForSong(modDirs:Array<String>, songId:String, playState:PlayState):Int
  {
    clear();
    activeModDirs = modDirs == null ? [] : modDirs.copy();
    var globals:Map<String, Dynamic> = PsychGameplayApi.createGlobals(playState);
    globals.set("songName", playState.currentSong == null ? "" : playState.currentSong.songName);
    globals.set("bpm", Conductor.instance.bpm);
    globals.set("curBpm", Conductor.instance.bpm);
    globals.set("crochet", Conductor.instance.beatLengthMs);
    globals.set("stepCrochet", Conductor.instance.stepLengthMs);
    globals.set("scrollSpeed", playState.currentChart == null ? 1.0 : playState.currentChart.scrollSpeed);
    globals.set("difficulty", playState.currentDifficulty);
    activeGlobals = new Map<String, Dynamic>();
    for (name => value in globals)
      activeGlobals.set(name, value);
    var loaded:Int = 0;
    var hasCustomStageScript:Bool = false;
    var sources:Array<PsychScriptSource> = PsychModRuntime.getScriptSources(modDirs, songId);
    for (source in sources)
    {
      if (loadSource(source.path, source.source, globals) != null)
      {
        loaded++;
        var normalizedPath:String = StringTools.replace(source.path, "\\", "/").toLowerCase();
        if (StringTools.contains(normalizedPath, "/stages/")) hasCustomStageScript = true;
      }
    }

    if (loaded > 0)
    {
      if (hasCustomStageScript) PsychGameplayApi.hideDefaultStageProps(playState);
      dispatch("onCreate", []);
      dispatch("onSongLoaded", []);
    }
    return loaded;
  }

  public static function openCustomSubstate(playState:PlayState, name:String, pauseGame:Bool = false):Bool
  {
    if (playState == null || name == null || StringTools.trim(name).length == 0
      || PsychGameplayApi.hasActiveCustomSubstate()) return false;

    var normalizedName:String = StringTools.trim(name);
    var sources:Array<PsychScriptSource> = PsychModRuntime.getCustomSubstateScriptSources(activeModDirs, normalizedName);
    for (source in sources)
    {
      var script:Null<PsychScriptInstance> = loadSource(source.path, source.source, activeGlobals);
      if (script != null) customSubstateScripts.push(script);
    }

    var subState:PsychCustomSubState = new PsychCustomSubState(normalizedName, playState);
    setOnScripts("customSubstate", subState);
    setOnScripts("customSubstateName", normalizedName);

    if (!PsychGameplayApi.openCustomSubstate(playState, subState, pauseGame))
    {
      unloadCustomSubstateScripts();
      return false;
    }
    return true;
  }

  public static function closeCustomSubstate(playState:PlayState):Void
  {
    if (playState == null || !PsychGameplayApi.hasActiveCustomSubstate()) return;
    playState.closeSubState();
    playState.persistentUpdate = true;
  }

  public static function unloadCustomSubstateScripts():Void
  {
    for (script in customSubstateScripts.copy())
    {
      scripts.remove(script);
      script.destroy();
    }
    customSubstateScripts.resize(0);
  }

  static function buildBridgeGlobals(?extraVariables:Dynamic):Map<String, Dynamic>
  {
    var result:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (name => value in sharedGlobals)
      result.set(name, value);
    for (name => value in activeGlobals)
      result.set(name, value);
    if (extraVariables != null)
    {
      for (name in Reflect.fields(extraVariables))
        result.set(name, Reflect.field(extraVariables, name));
    }
    return result;
  }

  public static function runHaxeCode(code:String, ?variablesToBring:Dynamic):Bool
  {
    if (code == null || code.length == 0) return true;
    if (inlineHScriptBridge == null)
    {
      inlineHScriptBridge = new PsychScriptInstance(
        "novabeat-inline-hscript.hx",
        "",
        buildBridgeGlobals(variablesToBring)
      );
      scripts.push(inlineHScriptBridge);
    }
    else if (variablesToBring != null)
    {
      for (name in Reflect.fields(variablesToBring))
        inlineHScriptBridge.setVariable(name, Reflect.field(variablesToBring, name));
    }

    var succeeded:Bool = inlineHScriptBridge.executeSnippet(code);
    if (!succeeded && inlineHScriptBridge.lastError != null)
      trace('[Psych Script Runtime] runHaxeCode failed: ' + inlineHScriptBridge.lastError);
    return succeeded;
  }

  public static function runLuaCode(code:String, ?variablesToBring:Dynamic):Bool
  {
    #if (cpp || js)
    if (code == null || code.length == 0) return true;
    if (inlineLuaBridge == null)
    {
      inlineLuaBridge = new PsychScriptInstance(
        "novabeat-inline-lua.lua",
        "",
        buildBridgeGlobals(variablesToBring)
      );
      scripts.push(inlineLuaBridge);
    }
    else if (variablesToBring != null)
    {
      for (name in Reflect.fields(variablesToBring))
        inlineLuaBridge.setVariable(name, Reflect.field(variablesToBring, name));
    }

    var succeeded:Bool = inlineLuaBridge.executeSnippet(code);
    if (!succeeded && inlineLuaBridge.lastError != null)
      trace('[Psych Script Runtime] runLuaCode failed: ' + inlineLuaBridge.lastError);
    return succeeded;
    #else
    return false;
    #end
  }

  public static function runHaxeFunction(name:String, ?args:Array<Dynamic>):Dynamic
  {
    var callArgs:Array<Dynamic> = args == null ? [] : args;
    for (script in scripts)
    {
      if (script.language != "hscript" || !script.hasFunction(name)) continue;
      return script.call(name, callArgs);
    }
    if (inlineHScriptBridge != null && inlineHScriptBridge.hasFunction(name))
      return inlineHScriptBridge.call(name, callArgs);
    return null;
  }

  public static function runLuaFunction(name:String, ?args:Array<Dynamic>):Dynamic
  {
    var callArgs:Array<Dynamic> = args == null ? [] : args;
    for (script in scripts)
    {
      if (script.language != "lua" || !script.hasFunction(name)) continue;
      return script.call(name, callArgs);
    }
    if (inlineLuaBridge != null && inlineLuaBridge.hasFunction(name))
      return inlineLuaBridge.call(name, callArgs);
    return null;
  }

  /**
   * Refresh Psych's timing globals immediately before script callbacks. Many
   * callbacks are dispatched from inside PlayState.update (notes, steps,
   * timers, tweens, and events), before the outer frame update can refresh them.
   */
  public static function updateTimingGlobals():Void
  {
    setGlobal("curStep", Conductor.instance.currentStep);
    setGlobal("curBeat", Conductor.instance.currentBeat);
    setGlobal("songPosition", Conductor.instance.songPosition);
    setGlobal("curDecStep", Conductor.instance.currentStepTime);
    setGlobal("curDecBeat", Conductor.instance.currentBeatTime);
    setGlobal("curSection", Std.int(Math.floor(Conductor.instance.currentStep / 16)));
    setGlobal("curBpm", Conductor.instance.bpm);
    setGlobal("bpm", Conductor.instance.bpm);
    setGlobal("crochet", Conductor.instance.beatLengthMs);
    setGlobal("stepCrochet", Conductor.instance.stepLengthMs);
  }

  public static function updateFrame(elapsed:Float):Void
  {
    dispatch("onUpdate", [elapsed]);
  }

  /**
   * Check whether any loaded mod script implements a callback. This allows
   * version/name aliases to remain mutually exclusive instead of firing both.
   */
  public static function hasCallback(callback:String):Bool
  {
    if (callback == null || callback.length == 0) return false;

    for (script in scripts)
      if (script.hasFunction(callback)) return true;

    if (inlineLuaBridge != null && inlineLuaBridge.hasFunction(callback)) return true;
    if (inlineHScriptBridge != null && inlineHScriptBridge.hasFunction(callback)) return true;

    return false;
  }

  public static function dispatchStop(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Bool
  {
    var result:PsychDispatchResult = dispatchInternal(callback, args, ignoreStops);
    return result.value == FUNCTION_STOP;
  }

  /**
   * Match Psych's callOnScripts ordering and return handling:
   * execute every Lua script first, then HScript only when Lua returned
   * Function_Continue (or no value). StopLua/StopHScript/StopAll stop script
   * dispatch at their respective language boundary; only Function_Stop
   * cancels the gameplay operation itself.
   */
  static function dispatchInternal(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):PsychDispatchResult
  {
    updateTimingGlobals();
    var callArgs:Array<Dynamic> = args == null ? [] : args;
    var results:Array<Dynamic> = [];
    var value:Dynamic = FUNCTION_CONTINUE;
    var luaResult:Dynamic = FUNCTION_CONTINUE;

    for (script in scripts.copy())
    {
      if (script.language != "lua") continue;
      var result:Dynamic = script.call(callback, callArgs);
      if (script.lastError != null)
        trace('[Psych Script Runtime] ' + script.sourcePath + ' :: ' + callback + ' :: ' + script.lastError);
      results.push(result);

      if (result != null && result != FUNCTION_CONTINUE)
      {
        value = result;
        luaResult = result;
      }

      if (!ignoreStops && (result == FUNCTION_STOP_LUA || result == FUNCTION_STOP_ALL))
        break;
    }

    // Psych's callOnScripts only runs HScript when Lua returned Continue.
    if (luaResult == null || luaResult == FUNCTION_CONTINUE)
    {
      for (script in scripts.copy())
      {
        if (script.language != "hscript") continue;
        var result:Dynamic = script.call(callback, callArgs);
        if (script.lastError != null)
          trace('[Psych Script Runtime] ' + script.sourcePath + ' :: ' + callback + ' :: ' + script.lastError);
        results.push(result);

        if (result != null && result != FUNCTION_CONTINUE)
          value = result;

        if (!ignoreStops && (result == FUNCTION_STOP_HSCRIPT || result == FUNCTION_STOP_ALL))
          break;
      }
    }

    return { results: results, value: value };
  }

  public static function getScriptPaths():Array<String>
  {
    return [for (script in scripts) script.sourcePath];
  }

  /**
   * Creates and registers a script from source text supplied by the mod loader.
   * File access is kept outside the interpreter so browser and native targets
   * can share the same runtime API.
   */
  public static function loadSource(sourcePath:String, source:String, ?variables:Map<String, Dynamic>):Null<PsychScriptInstance>
  {
    var initial:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (name => value in sharedGlobals)
      initial.set(name, value);
    if (variables != null)
      for (name => value in variables)
        initial.set(name, value);

    try
    {
      var script = new PsychScriptInstance(sourcePath, source, initial);
      scripts.push(script);
      return script;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Script Runtime] Failed to load ' + sourcePath + ': ' + Std.string(error));
      return null;
    }
  }

  /**
   * Calls one callback on every registered script in load order.
   * The return values are preserved so the Psych event bridge can implement
   * Function_Stop / Function_StopLua / Function_StopHScript semantics.
   */
  public static function dispatch(callback:String, ?args:Array<Dynamic>):Array<Dynamic>
  {
    return dispatchInternal(callback, args).results;
  }

  public static function callOnLuas(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Dynamic
  {
    updateTimingGlobals();
    var results:Array<Dynamic> = [];
    var value:Dynamic = FUNCTION_CONTINUE;
    for (script in scripts.copy())
    {
      if (script.language != "lua") continue;
      var result:Dynamic = script.call(callback, args == null ? [] : args);
      results.push(result);
      if (result != null && result != FUNCTION_CONTINUE) value = result;
      if (!ignoreStops && (result == FUNCTION_STOP_LUA || result == FUNCTION_STOP_ALL)) break;
    }
    return value;
  }

  public static function callOnHScript(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Dynamic
  {
    updateTimingGlobals();
    var value:Dynamic = FUNCTION_CONTINUE;
    for (script in scripts.copy())
    {
      if (script.language != "hscript") continue;
      var result:Dynamic = script.call(callback, args == null ? [] : args);
      if (result != null && result != FUNCTION_CONTINUE) value = result;
      if (!ignoreStops && (result == FUNCTION_STOP_HSCRIPT || result == FUNCTION_STOP_ALL)) break;
    }
    return value;
  }

  public static function callOnScripts(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Dynamic
  {
    var luaResult:Dynamic = callOnLuas(callback, args, ignoreStops);
    if (luaResult == null || luaResult == FUNCTION_CONTINUE)
      return callOnHScript(callback, args, ignoreStops);
    return luaResult;
  }

  public static function setOnScripts(name:String, value:Dynamic):Void
  {
    // setOnScripts updates only the currently loaded interpreters. It must not
    // promote transient script variables into the persistent runtime globals.
    setOnLuas(name, value);
    setOnHScript(name, value);
  }

  public static function setOnLuas(name:String, value:Dynamic):Void
  {
    for (script in scripts)
      if (script.language == "lua") script.setVariable(name, value);
  }

  public static function setOnHScript(name:String, value:Dynamic):Void
  {
    for (script in scripts)
      if (script.language == "hscript") script.setVariable(name, value);
  }

  public static function clear():Void
  {
    for (script in scripts)
      script.destroy();
    scripts.resize(0);
    customSubstateScripts.resize(0);
    activeModDirs = [];
    inlineHScriptBridge = null;
    inlineLuaBridge = null;
    activeGlobals = new Map<String, Dynamic>();
    PsychGameplayApi.clear();
  }

  /**
   * Debug-only integration test. This uses the same interpreter wrappers that
   * mod scripts will use and verifies a function call on both runtimes.
   */
  public static function runSmokeTests():Bool
  {
    var hscriptPassed:Bool = false;
    var hscript:Null<PsychScriptInstance> = null;
    try
    {
      hscript = new PsychScriptInstance(
        "novabeat-hscript-smoke-test.hx",
        "function add(a, b) { return a + b; } function echo(value) { return value; } function readInjected() { return injectedValue; }",
        ["injectedValue" => 17]
      );
      hscriptPassed = hscript.hasFunction("add")
        && hscript.call("add", [2, 3]) == 5
        && hscript.call("echo", ["novabeat"]) == "novabeat"
        && hscript.call("readInjected", []) == 17
        && hscript.lastError == null;
      if (!hscriptPassed)
        trace('[Psych Script Runtime] HScript smoke test did not pass function, argument, or injected-global checks.');
    }
    catch (error:Dynamic)
    {
      trace('[Psych Script Runtime] HScript smoke test failed: ' + Std.string(error));
    }
    if (hscript != null) hscript.destroy();

    #if (cpp || js)
    var luaPassed:Bool = false;
    var lua:Null<PsychScriptInstance> = null;
    try
    {
      lua = new PsychScriptInstance(
        "novabeat-lua-smoke-test.lua",
        "function add(a, b) return a + b end\nfunction echo(value) return value end\nfunction readInjected() return injectedValue end\nfunction sandboxIntact() return io == nil and os == nil and package == nil and debug == nil and require == nil and dofile == nil and loadfile == nil end\nfunction legacyRuntimeCompatibility() local values = {10, 20, 30}; local compile = loadstring('return 7'); return unpack(values) == 10 and compile() == 7 and string.gfind == string.gmatch and math.mod(7, 4) == 3 and math.atan2(1, 1) > 0 and table.maxn({[4] = true}) == 4 end",
        ["injectedValue" => 17]
      );
      luaPassed = lua.hasFunction("add")
        && lua.call("add", [2, 3]) == 5
        && lua.call("echo", ["novabeat"]) == "novabeat"
        && lua.call("readInjected", []) == 17
        && lua.call("sandboxIntact", []) == true
        && lua.call("legacyRuntimeCompatibility", []) == true
        && lua.lastError == null;
      if (!luaPassed)
        trace('[Psych Script Runtime] Lua smoke test did not pass function, argument, injected-global, or sandbox checks.');
    }
    catch (error:Dynamic)
    {
      trace('[Psych Script Runtime] Lua smoke test failed: ' + Std.string(error));
    }
    if (lua != null) lua.destroy();
    return hscriptPassed && luaPassed;
    #else
    return false;
    #end
  }
}


typedef PsychDispatchResult =
{
  var results:Array<Dynamic>;
  var value:Dynamic;
}
