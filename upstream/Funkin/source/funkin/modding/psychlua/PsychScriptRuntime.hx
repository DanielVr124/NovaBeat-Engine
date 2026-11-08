package funkin.modding.psychlua;

import haxe.Exception;

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
  static final sharedGlobals:Map<String, Dynamic> = [
    "Function_Continue" => 0,
    "Function_Stop" => 1,
    "Function_StopLua" => 2,
    "Function_StopHScript" => 3
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

  public static function getGlobal(name:String):Dynamic
  {
    return sharedGlobals.get(name);
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
    var results:Array<Dynamic> = [];
    var callArgs:Array<Dynamic> = args == null ? [] : args;
    for (script in scripts.copy())
    {
      var result:Dynamic = script.call(callback, callArgs);
      if (script.lastError != null)
        trace('[Psych Script Runtime] ' + script.sourcePath + ' :: ' + callback + ' :: ' + script.lastError);
      results.push(result);
    }
    return results;
  }

  public static function clear():Void
  {
    for (script in scripts)
      script.destroy();
    scripts.resize(0);
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
