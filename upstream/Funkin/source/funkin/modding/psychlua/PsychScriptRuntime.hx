package funkin.modding.psychlua;

import haxe.Exception;
import funkin.Conductor;
import funkin.modding.PsychModRuntime;
import funkin.modding.PsychModRuntime.PsychScriptSource;
import funkin.play.PlayState;

/**
 * Owns interpreter instances used by the Psych compatibility layer.
 *
 * This first stage provides isolated HScript/Lua execution, shared constants,
 * callback dispatch, and a debug smoke test. It does not yet expose Psych's
 * PlayState, FlxG, character, sprite, camera, event, or note APIs.
 */
@:nullSafety(Off)
class PsychScriptRuntime
{
  static final scripts:Array<PsychScriptInstance> = [];
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
    sharedGlobals.set(name, value);
    for (script in scripts)
      script.setVariable(name, value);
  }

  public static function removeGlobal(name:String):Void
  {
    if (name == null || name.length == 0) return;
    sharedGlobals.remove(name);
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

    var resolved:Class<Dynamic> = Type.resolveClass(fullName);
    if (resolved == null) return false;
    setHScriptGlobal(name, resolved);
    return true;
  }

  public static function getGlobal(name:String):Dynamic
  {
    return sharedGlobals.get(name);
  }

  /**
   * Load global and song-local scripts for the currently activated Psych
   * packages. Global scripts always precede song scripts, matching the
   * established Psych loading order for these two supported scopes.
   */
  public static function loadForSong(modDirs:Array<String>, songId:String, playState:PlayState):Int
  {
    clear();
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
    var sources:Array<PsychScriptSource> = PsychModRuntime.getScriptSources(modDirs, songId);
    for (source in sources)
    {
      if (loadSource(source.path, source.source, globals) != null)
        loaded++;
    }

    if (loaded > 0)
    {
      dispatch("onCreate", []);
      dispatch("onSongLoaded", []);
    }
    return loaded;
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

  public static function updateFrame(elapsed:Float):Void
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
    dispatch("onUpdate", [elapsed]);
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
    setOnLuas(name, value);
    setOnHScript(name, value);
    setGlobal(name, value);
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
        "function add(a, b) { return a + b; }",
        new Map<String, Dynamic>()
      );
      hscriptPassed = hscript.hasFunction("add") && hscript.call("add", [2, 3]) == 5 && hscript.lastError == null;
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
        "function add(a, b) return a + b end",
        new Map<String, Dynamic>()
      );
      luaPassed = lua.hasFunction("add") && lua.call("add", [2, 3]) == 5 && lua.lastError == null;
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
