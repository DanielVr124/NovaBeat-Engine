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
@:access(funkin.play.PlayState)
class PsychScriptRuntime
{
  static final scripts:Array<PsychScriptInstance> = [];
  static final customSubstateScripts:Array<PsychScriptInstance> = [];
  static var activeModDirs:Array<String> = [];
  static var activeGlobals:Map<String, Dynamic> = [];
  static var inlineHScriptBridge:Null<PsychScriptInstance> = null;
  static var inlineLuaBridge:Null<PsychScriptInstance> = null;
  static var executingScript:Null<PsychScriptInstance> = null;
  static var pendingSongLifecycleCallbacks:Bool = false;
  // Retain the active imported-song context so failures swallowed by an
  // interpreter callback are still written to the persistent launch log.
  static var activeDiagnosticSongId:String = "";
  static var activeDiagnosticDifficulty:String = "";
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
    if (inlineHScriptBridge != null) inlineHScriptBridge.setVariable(name, value);
    if (inlineLuaBridge != null) inlineLuaBridge.setVariable(name, value);
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

    if (fullName == "flixel.math.FlxPoint")
    {
      setHScriptGlobal(name, PsychScriptInstance.createFlxPointApi());
      return true;
    }

    var resolved:Class<Dynamic> = Type.resolveClass(fullName);
    if (resolved == null) return false;
    setHScriptGlobal(name, resolved);
    return true;
  }

  /** Close the currently executing mod script, matching Psych's close() helper. */
  public static function closeCurrentScript():Bool
  {
    return executingScript != null && executingScript.close();
  }

  /** Persist script callback failures even when an interpreter handles the exception internally. */
  static function logScriptCallbackFailure(script:PsychScriptInstance, callback:String, message:String):Void
  {
    var detail:String = script.sourcePath + " | callback=" + callback + " | " + message;
    trace('[Psych Script Runtime] Callback failed: ' + detail);
    if (activeDiagnosticSongId != null && activeDiagnosticSongId.length > 0)
      PsychModRuntime.logSongLaunchStep(activeDiagnosticSongId, activeDiagnosticDifficulty,
        'scripts.callback.failed', detail);
  }

  /** Invoke a script with a scoped current-script context for close/ignoreSelf helpers. */
  static function callScriptInstance(script:PsychScriptInstance, callback:String, args:Array<Dynamic>):Dynamic
  {
    if (script == null || script.closed) return null;
    var previous:Null<PsychScriptInstance> = executingScript;
    executingScript = script;
    var result:Dynamic = null;
    try
    {
      result = script.call(callback, args == null ? [] : args);
    }
    catch (error:Dynamic)
    {
      executingScript = previous;
      logScriptCallbackFailure(script, callback, Std.string(error));
      throw error;
    }
    executingScript = previous;

    // PsychScriptInstance.call() intentionally catches interpreter exceptions
    // so one bad callback cannot take down gameplay. Do not let that safety
    // behavior hide the exact script and callback from the launch diagnostic.
    if (script.lastError != null)
      logScriptCallbackFailure(script, callback, script.lastError);

    if (script.closed)
    {
      scripts.remove(script);
      customSubstateScripts.remove(script);
      script.destroy();
    }
    return result;
  }

  static function isExcludedScript(script:PsychScriptInstance, exclusions:Array<String>):Bool
  {
    if (exclusions == null || exclusions.length == 0) return false;
    var path:String = normalizeScriptPath(script.sourcePath);
    var base:String = path.split("/").pop();
    for (exclusion in exclusions)
    {
      var candidate:String = normalizeScriptPath(exclusion);
      if (candidate.length == 0) continue;
      if (candidate == path || StringTools.endsWith(path, "/" + candidate)
        || (candidate.indexOf("/") < 0 && candidate == base)) return true;
    }
    return false;
  }

  static function isExcludedValue(value:Dynamic, exclusions:Array<Dynamic>):Bool
  {
    return exclusions != null && exclusions.indexOf(value) >= 0;
  }

  public static function getExecutingScriptPath():String
  {
    return executingScript == null ? "" : executingScript.sourcePath;
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
  public static function loadForSong(modDirs:Array<String>, songId:String, playState:PlayState, ?deferLifecycleCallbacks:Bool = false):Int
  {
    var loaded:Int = 0;
    var phase:String = 'scripts.clear';
    var difficulty:String = playState == null ? '' : playState.currentDifficulty;

    try
    {
      PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.clear.begin');
      clear();
      PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.clear.complete');
      activeDiagnosticSongId = songId == null ? "" : songId;
      activeDiagnosticDifficulty = difficulty == null ? "" : difficulty;
      activeModDirs = modDirs == null ? [] : modDirs.copy();

      phase = 'globals.create';
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

      // Psych scripts can read globals in their top-level declarations, before
      // onCreate is dispatched. Populate the complete song state before parsing
      // and executing the first line of any mod script.
      phase = 'globals.update';
      PsychGameplayApi.updateGlobals(playState);

      phase = 'scripts.discover';
      PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.sources.discover.begin');
      var sources:Array<PsychScriptSource> = PsychModRuntime.getScriptSources(modDirs, songId);
      PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.sources.discover.complete',
        'count=' + sources.length);

      var hasCustomStageScript:Bool = false;
      for (source in sources)
      {
        phase = 'scripts.source.load';
        PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.source.begin', source.path);
        var script:Null<PsychScriptInstance> = loadSource(source.path, source.source, activeGlobals, songId, difficulty);
        if (script != null)
        {
          loaded++;
          var normalizedPath:String = StringTools.replace(source.path, "\\", "/").toLowerCase();
          if (StringTools.contains(normalizedPath, "/stages/")
            || PsychModRuntime.isRootPsychStageScript(songId, source.path))
            hasCustomStageScript = true;
          PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.source.complete', source.path);
        }
        else
        {
          PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.source.rejected', source.path);
        }
      }

      phase = 'scripts.stage.setup';
      if (loaded > 0)
      {
        if (hasCustomStageScript) PsychGameplayApi.hideDefaultStageProps(playState);
        if (deferLifecycleCallbacks)
          pendingSongLifecycleCallbacks = true;
        else
          dispatchLoadedCallbacks();
      }

      PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.load.complete', 'count=' + loaded);
    }
    catch (error:Dynamic)
    {
      var message:String = Std.string(error);
      PsychModRuntime.logSongLaunchStep(songId, difficulty, 'scripts.load.failed', phase + ' | ' + message);
      trace('[Psych Script Runtime] Song script initialization failed during ' + phase + ': ' + message);
      pendingSongLifecycleCallbacks = false;
      // Do not leave a partially loaded script set running without its normal
      // onCreate/onSongLoaded lifecycle when song initialization was aborted.
      try
      {
        clear();
      }
      catch (cleanupError:Dynamic)
      {
        trace('[Psych Script Runtime] Cleanup after failed song script initialization also failed: ' + Std.string(cleanupError));
      }
    }

    return loaded;
  }

  /** Dispatch lifecycle callbacks after song notes and chart events have been prepared. */
  public static function dispatchLoadedCallbacks():Void
  {
    if (!pendingSongLifecycleCallbacks) return;
    pendingSongLifecycleCallbacks = false;
    if (scripts.length == 0) return;

    if (activeDiagnosticSongId.length > 0)
      PsychModRuntime.logSongLaunchStep(activeDiagnosticSongId, activeDiagnosticDifficulty, 'scripts.lifecycle.onCreate.begin');
    dispatch("onCreate", []);
    if (activeDiagnosticSongId.length > 0)
      PsychModRuntime.logSongLaunchStep(activeDiagnosticSongId, activeDiagnosticDifficulty, 'scripts.lifecycle.onCreate.complete');

    if (activeDiagnosticSongId.length > 0)
      PsychModRuntime.logSongLaunchStep(activeDiagnosticSongId, activeDiagnosticDifficulty, 'scripts.lifecycle.onSongLoaded.begin');
    dispatch("onSongLoaded", []);
    if (activeDiagnosticSongId.length > 0)
      PsychModRuntime.logSongLaunchStep(activeDiagnosticSongId, activeDiagnosticDifficulty, 'scripts.lifecycle.onSongLoaded.complete');
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
      return callScriptInstance(script, name, callArgs);
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
      return callScriptInstance(script, name, callArgs);
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
    setGlobal("songLength", PlayState.instance?.currentSongLengthMs ?? 0);
    var state:Null<PlayState> = PlayState.instance;
    if (state != null) PsychGameplayApi.updateGlobals(state);
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
    {
      // Inline runLuaCode/runHaxeCode bridges are helper interpreters, not
      // loaded mod files. Keep them out of lifecycle callback detection even
      // if a future refactor accidentally registers one in the script list.
      if (script == inlineHScriptBridge || script == inlineLuaBridge) continue;
      if (script.hasFunction(callback)) return true;
    }
    return false;
  }

  public static function dispatchStop(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Bool
  {
    return dispatchInternal(callback, args, ignoreStops).value == FUNCTION_STOP;
  }

  /** Dispatch a callback using Psych's distinct Lua and HScript argument shapes. */
  public static function dispatchSplit(callback:String, luaArgs:Array<Dynamic>, hscriptArgs:Array<Dynamic>,
      ?ignoreStops:Bool = false):Array<Dynamic>
  {
    return dispatchSplitInternal(callback, luaArgs, hscriptArgs, ignoreStops).results;
  }

  /** Split-argument dispatch variant which reports whether Function_Stop cancelled gameplay. */
  public static function dispatchStopSplit(callback:String, luaArgs:Array<Dynamic>, hscriptArgs:Array<Dynamic>,
      ?ignoreStops:Bool = false):Bool
  {
    return dispatchSplitInternal(callback, luaArgs, hscriptArgs, ignoreStops).value == FUNCTION_STOP;
  }

  /**
   * Psych's note callbacks are not identical to generic callOnScripts:
   * Lua gets chart index/direction/type values, while HScript gets the Note
   * object. Psych still invokes HScript when Lua returned Function_StopLua,
   * but not for Stop, StopHScript, or StopAll.
   */
  public static function dispatchPsychNoteCallback(callback:String, luaArgs:Array<Dynamic>,
      hscriptArgs:Array<Dynamic>):Void
  {
    var luaResult:Dynamic = callOnLuas(callback, luaArgs);
    if (luaResult != FUNCTION_STOP && luaResult != FUNCTION_STOP_HSCRIPT && luaResult != FUNCTION_STOP_ALL)
      callOnHScript(callback, hscriptArgs);
  }

  /** Some Psych hooks (notably onSpawnNote) invoke both language arrays independently. */
  public static function dispatchSeparate(callback:String, luaArgs:Array<Dynamic>, hscriptArgs:Array<Dynamic>):Void
  {
    callOnLuas(callback, luaArgs);
    callOnHScript(callback, hscriptArgs);
  }

  static function dispatchInternal(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):PsychDispatchResult
  {
    return dispatchSplitInternal(callback, args, args, ignoreStops);
  }

  /**
   * Match Psych's callOnScripts ordering and return handling:
   * execute every Lua script first, then HScript only when Lua returned
   * Function_Continue (or no value). StopLua/StopHScript/StopAll stop script
   * dispatch at their documented boundaries.
   */
  static function dispatchSplitInternal(callback:String, luaArgs:Array<Dynamic>, hscriptArgs:Array<Dynamic>,
      ?ignoreStops:Bool = false):PsychDispatchResult
  {
    updateTimingGlobals();
    var luaCallArgs:Array<Dynamic> = luaArgs == null ? [] : luaArgs;
    var hscriptCallArgs:Array<Dynamic> = hscriptArgs == null ? [] : hscriptArgs;
    var results:Array<Dynamic> = [];
    var value:Dynamic = FUNCTION_CONTINUE;
    var luaResult:Dynamic = FUNCTION_CONTINUE;

    for (script in scripts.copy())
    {
      if (script.language != "lua") continue;
      var result:Dynamic = callScriptInstance(script, callback, luaCallArgs);
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
        var result:Dynamic = callScriptInstance(script, callback, hscriptCallArgs);
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

  public static function getActiveModDirectory():String
  {
    return activeModDirs.length == 0 ? "" : activeModDirs[0];
  }

  /** Resolve the directory which owns the currently executing script. */
  public static function getExecutingScriptModDirectory():String
  {
    if (executingScript == null || executingScript.sourcePath == null) return getActiveModDirectory();
    var path:String = normalizeScriptPath(executingScript.sourcePath);
    var wrappedPath:String = "/" + path + "/";
    for (directory in activeModDirs)
    {
      var marker:String = "/" + directory.toLowerCase() + "/";
      if (wrappedPath.indexOf(marker) >= 0) return directory;
    }
    return getActiveModDirectory();
  }

  public static function getScriptPaths():Array<String>
  {
    return [for (script in scripts) script.sourcePath];
  }

  static function normalizeScriptPath(value:String):String
  {
    if (value == null) return "";
    var result:String = StringTools.replace(StringTools.trim(value), "\\", "/").toLowerCase();
    while (StringTools.startsWith(result, "./")) result = result.substr(2);
    while (StringTools.startsWith(result, "/")) result = result.substr(1);
    return result;
  }

  static function findScript(scriptPath:String, ?language:String):Null<PsychScriptInstance>
  {
    var requested:String = normalizeScriptPath(scriptPath);
    if (requested.length == 0) return null;
    var matches:Array<PsychScriptInstance> = [];
    var requestedHasDirectory:Bool = requested.indexOf("/") >= 0;
    for (script in scripts)
    {
      if (script == inlineHScriptBridge || script == inlineLuaBridge) continue;
      if (language != null && script.language != language) continue;
      var loaded:String = normalizeScriptPath(script.sourcePath);
      if (loaded == requested || StringTools.endsWith(loaded, "/" + requested))
        return script;

      // A bare filename is accepted for Psych's common cross-script helpers,
      // but only when it identifies exactly one script across enabled mods.
      if (!requestedHasDirectory && loaded.split("/").pop() == requested)
        matches.push(script);
    }
    return matches.length == 1 ? matches[0] : null;
  }

  public static function isScriptRunning(scriptPath:String, ?language:String):Bool
  {
    return findScript(scriptPath, language) != null;
  }

  public static function addScript(scriptPath:String, language:String, ?ignoreAlreadyRunning:Bool = false):Bool
  {
    if (scriptPath == null || language == null) return false;
    var extension:String = language == "hscript" ? "hx" : "lua";
    var requested:String = StringTools.trim(scriptPath);
    var lower:String = normalizeScriptPath(requested);
    if (!StringTools.endsWith(lower, ".lua") && !StringTools.endsWith(lower, ".hx")
      && !StringTools.endsWith(lower, ".hscript"))
      requested += "." + extension;

    var existing:Null<PsychScriptInstance> = findScript(requested, language);
    if (existing != null)
    {
      if (ignoreAlreadyRunning) return false;
      removeScript(requested, language);
    }

    var source:Null<PsychScriptSource> = PsychModRuntime.getScriptSource(activeModDirs, requested);
    if (source == null) return false;
    var sourceExtension:String = normalizeScriptPath(source.path);
    if (language == "lua" && !StringTools.endsWith(sourceExtension, ".lua")) return false;
    if (language == "hscript" && !StringTools.endsWith(sourceExtension, ".hx")
      && !StringTools.endsWith(sourceExtension, ".hscript")) return false;
    return loadSource(source.path, source.source, activeGlobals) != null;
  }

  public static function removeScript(scriptPath:String, ?language:String):Bool
  {
    var script:Null<PsychScriptInstance> = findScript(scriptPath, language);
    if (script == null) return false;
    if (!script.closed) callScriptInstance(script, "onDestroy", []);
    scripts.remove(script);
    customSubstateScripts.remove(script);
    if (!script.closed) script.destroy();
    return true;
  }

  public static function callScript(scriptPath:String, callback:String, ?args:Array<Dynamic>):Dynamic
  {
    var script:Null<PsychScriptInstance> = findScript(scriptPath);
    if (script == null || callback == null || callback.length == 0) return null;
    updateTimingGlobals();
    var result:Dynamic = callScriptInstance(script, callback, args == null ? [] : args);
    if (script.lastError != null)
      trace('[Psych Script Runtime] ' + script.sourcePath + ' :: ' + callback + ' :: ' + script.lastError);
    return result;
  }

  public static function getGlobalFromScript(scriptPath:String, name:String):Dynamic
  {
    var script:Null<PsychScriptInstance> = findScript(scriptPath);
    return script == null ? null : script.getVariable(name);
  }

  public static function setGlobalFromScript(scriptPath:String, name:String, value:Dynamic):Bool
  {
    var script:Null<PsychScriptInstance> = findScript(scriptPath);
    if (script == null || name == null || name.length == 0) return false;
    script.setVariable(name, value);
    return true;
  }

  /**
   * Returns a snapshot of the values NovaBeat injected into the selected
   * script. Interpreter-private locals and functions are intentionally omitted.
   */
  public static function getScriptGlobals(scriptPath:String):Dynamic
  {
    if (findScript(scriptPath) == null) return null;
    var result:Dynamic = {};
    for (name => value in activeGlobals)
      Reflect.setField(result, name, value);
    return result;
  }

  /**
   * Creates and registers a script from source text supplied by the mod loader.
   * File access is kept outside the interpreter so browser and native targets
   * can share the same runtime API.
   */
  public static function loadSource(sourcePath:String, source:String, ?variables:Map<String, Dynamic>,
      ?diagnosticSongId:String, ?diagnosticDifficulty:String):Null<PsychScriptInstance>
  {
    var initial:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (name => value in sharedGlobals)
      initial.set(name, value);
    if (variables != null)
      for (name => value in variables)
        initial.set(name, value);
    var sourceName:String = sourcePath.split("/").pop();
    if (sourceName == null) sourceName = sourcePath;
    var extensionIndex:Int = sourceName.lastIndexOf(".");
    if (extensionIndex > 0) sourceName = sourceName.substr(0, extensionIndex);
    initial.set("scriptName", sourceName);

    try
    {
      var script = new PsychScriptInstance(sourcePath, source, initial, diagnosticSongId, diagnosticDifficulty);
      scripts.push(script);
      return script;
    }
    catch (error:Dynamic)
    {
      var message:String = Std.string(error);
      trace('[Psych Script Runtime] Failed to load ' + sourcePath + ': ' + message);
      if (diagnosticSongId != null)
        PsychModRuntime.logSongLaunchStep(diagnosticSongId, diagnosticDifficulty ?? '',
          'scripts.source.failed', sourcePath + ' | ' + message);
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

  public static function callOnLuas(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false,
      ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic
  {
    updateTimingGlobals();
    var value:Dynamic = FUNCTION_CONTINUE;
    var resultExclusions:Array<Dynamic> = excludeValues == null ? [FUNCTION_CONTINUE] : excludeValues;
    for (script in scripts.copy())
    {
      if (script.language != "lua" || isExcludedScript(script, exclusions)) continue;
      var result:Dynamic = callScriptInstance(script, callback, args == null ? [] : args);
      var excluded:Bool = isExcludedValue(result, resultExclusions);
      if (result != null && !excluded) value = result;
      if (!ignoreStops && !excluded && (result == FUNCTION_STOP_LUA || result == FUNCTION_STOP_ALL)) break;
    }
    return value;
  }

  public static function callOnHScript(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false,
      ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic
  {
    updateTimingGlobals();
    var value:Dynamic = FUNCTION_CONTINUE;
    var resultExclusions:Array<Dynamic> = excludeValues == null ? [FUNCTION_CONTINUE] : excludeValues;
    for (script in scripts.copy())
    {
      if (script.language != "hscript" || isExcludedScript(script, exclusions)) continue;
      var result:Dynamic = callScriptInstance(script, callback, args == null ? [] : args);
      var excluded:Bool = isExcludedValue(result, resultExclusions);
      if (result != null && !excluded) value = result;
      if (!ignoreStops && !excluded && (result == FUNCTION_STOP_HSCRIPT || result == FUNCTION_STOP_ALL)) break;
    }
    return value;
  }

  public static function callOnScripts(callback:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false,
      ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic
  {
    var luaResult:Dynamic = callOnLuas(callback, args, ignoreStops, exclusions, excludeValues);
    if (luaResult == null || luaResult == FUNCTION_CONTINUE)
      return callOnHScript(callback, args, ignoreStops, exclusions, excludeValues);
    return luaResult;
  }

  public static function setOnScripts(name:String, value:Dynamic, ?exclusions:Array<String>):Void
  {
    // setOnScripts updates only the currently loaded interpreters. It must not
    // promote transient script variables into the persistent runtime globals.
    setOnLuas(name, value, exclusions);
    setOnHScript(name, value, exclusions);
  }

  public static function setOnLuas(name:String, value:Dynamic, ?exclusions:Array<String>):Void
  {
    for (script in scripts.copy())
      if (script.language == "lua" && !isExcludedScript(script, exclusions)) script.setVariable(name, value);
    if (inlineLuaBridge != null) inlineLuaBridge.setVariable(name, value);
  }

  public static function setOnHScript(name:String, value:Dynamic, ?exclusions:Array<String>):Void
  {
    for (script in scripts.copy())
      if (script.language == "hscript" && !isExcludedScript(script, exclusions)) script.setVariable(name, value);
    if (inlineHScriptBridge != null) inlineHScriptBridge.setVariable(name, value);
  }

  public static function clear():Void
  {
    executingScript = null;
    pendingSongLifecycleCallbacks = false;
    for (script in scripts)
      script.destroy();
    scripts.resize(0);
    customSubstateScripts.resize(0);
    if (inlineHScriptBridge != null) inlineHScriptBridge.destroy();
    if (inlineLuaBridge != null) inlineLuaBridge.destroy();
    activeModDirs = [];
    activeDiagnosticSongId = "";
    activeDiagnosticDifficulty = "";
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
        "function add(a, b) { return a + b; } function echo(value) { return value; } function readInjected() { return injectedValue; } function readPreset() { var point = FlxPoint.get(4, 5); var valid = point.x == 4 && point.y == 5; point.put(); return FlxBasic != null && FlxObject != null && FlxPoint != null && valid; }",
        ["injectedValue" => 17]
      );
      hscriptPassed = hscript.hasFunction("add")
        && hscript.call("add", [2, 3]) == 5
        && hscript.call("echo", ["novabeat"]) == "novabeat"
        && hscript.call("readInjected", []) == 17
        && hscript.call("readPreset", []) == true
        && hscript.lastError == null;
      if (!hscriptPassed)
        trace('[Psych Script Runtime] HScript smoke test did not pass function, argument, injected-global, or preset-class checks.');
    }
    catch (error:Dynamic)
    {
      trace('[Psych Script Runtime] HScript smoke test failed: ' + Std.string(error));
    }
    if (hscript != null) hscript.destroy();

    var closePassed:Bool = false;
    var closeScript:Null<PsychScriptInstance> = null;
    try
    {
      closeScript = new PsychScriptInstance(
        "novabeat-close-smoke-test.hx",
        "function closeAndReturn() { close(); return 23; } function shouldNotRun() { return 99; }",
        ["close" => function():Bool return PsychScriptRuntime.closeCurrentScript()]
      );
      var closeResult:Dynamic = callScriptInstance(closeScript, "closeAndReturn", []);
      closePassed = closeResult == 23 && closeScript.closed
        && closeScript.call("shouldNotRun", []) == null && closeScript.lastError == null;
      if (!closePassed)
        trace('[Psych Script Runtime] close() smoke test did not close the current script after its callback returned.');
    }
    catch (error:Dynamic)
    {
      trace('[Psych Script Runtime] close() smoke test failed: ' + Std.string(error));
    }
    if (closeScript != null && !closeScript.closed) closeScript.destroy();

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

    // Regression test the exact stage-script API shape used by common Psych
    // 0.7.3 stage files (including the legacy close(true) call).
    var forestStageLuaPassed:Bool = false;
    var forestStageLua:Null<PsychScriptInstance> = null;
    var forestStageCalls:Array<String> = [];
    var forestStageArgumentsValid:Bool = true;
    try
    {
      forestStageLua = new PsychScriptInstance(
        "novabeat-forest-stage-smoke-test.lua",
        "function onCreate()\n"
          + "makeLuaSprite('forestfront', 'forestfront', -160, -456)\n"
          + "setScrollFactor('forestfront', 1.0, 1.0)\n"
          + "makeLuaSprite('foresttree', 'foresttree', -850, -630)\n"
          + "setScrollFactor('foresttree', 1.0, 1.0)\n"
          + "makeLuaSprite('forestback', 'forestback', -900, -950)\n"
          + "setScrollFactor('forestback', 1.0, 1.0)\n"
          + "addLuaSprite('forestback', false)\n"
          + "addLuaSprite('forestfront', false)\n"
          + "addLuaSprite('foresttree', false)\n"
          + "close(true)\n"
          + "end",
        [
          "makeLuaSprite" => function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Bool
          {
            forestStageCalls.push("make:" + tag);
            if (tag != image || (tag == "forestfront" && (x != -160 || y != -456))
              || (tag == "foresttree" && (x != -850 || y != -630))
              || (tag == "forestback" && (x != -900 || y != -950)))
              forestStageArgumentsValid = false;
            return true;
          },
          "setScrollFactor" => function(tag:String, x:Float, ?y:Null<Float>):Bool
          {
            forestStageCalls.push("scroll:" + tag);
            if (x != 1.0 || (y != null && y != 1.0)) forestStageArgumentsValid = false;
            return true;
          },
          "addLuaSprite" => function(tag:String, ?inFront:Bool = false):Bool
          {
            forestStageCalls.push("add:" + tag);
            if (inFront) forestStageArgumentsValid = false;
            return true;
          },
          "close" => function(?_ignoreSelf:Bool = false):Bool return PsychScriptRuntime.closeCurrentScript()
        ]
      );
      callScriptInstance(forestStageLua, "onCreate", []);
      forestStageLuaPassed = forestStageLua.closed && forestStageLua.lastError == null
        && forestStageArgumentsValid && forestStageCalls.join("|")
          == "make:forestfront|scroll:forestfront|make:foresttree|scroll:foresttree|make:forestback|scroll:forestback|add:forestback|add:forestfront|add:foresttree";
      if (!forestStageLuaPassed)
        trace('[Psych Script Runtime] Forest.lua stage API smoke test failed: calls=' + forestStageCalls.join(",")
          + ' argsValid=' + forestStageArgumentsValid + ' error=' + forestStageLua.lastError);
    }
    catch (error:Dynamic)
    {
      trace('[Psych Script Runtime] Forest.lua stage API smoke test failed: ' + Std.string(error));
    }
    if (forestStageLua != null && !forestStageLua.closed) forestStageLua.destroy();

    var apiPassed:Bool = PlayState.instance != null && PsychGameplayApi.runApiSmokeTests(PlayState.instance);
    if (!apiPassed)
      trace('[Psych Script Runtime] Gameplay API registration smoke test failed.');

    return hscriptPassed && closePassed && luaPassed && forestStageLuaPassed && apiPassed;
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
