package funkin.modding.psychlua;

import haxe.Exception;
import haxe.io.Path;
import hscript.SScript;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.Conductor;
import funkin.Paths;
import funkin.play.PlayState;
import funkin.play.character.BaseCharacter;
import funkin.play.notes.NoteSprite;

#if (cpp || js)
import vm.lua.Lua;
#end

/**
 * Owns one isolated Psych HScript or Lua interpreter.
 *
 * The runtime injects the supported gameplay globals and helper API.
 * HScript is instruction/time-bounded; Lua has an instruction hook and has
 * host filesystem, process, package, debug, and dynamic-loader globals removed.
 */
@:nullSafety(Off)
class PsychScriptInstance
{
  public final sourcePath:String;
  public final language:String;
  public var lastError(default, null):Null<String> = null;

  var hscript:Null<SScript> = null;
  #if (cpp || js)
  var lua:Null<Lua> = null;
  var luaResetBudget:Dynamic = null;
  var luaHasFunction:Dynamic = null;
  #end
  var destroyed:Bool = false;

  static inline final HSCRIPT_INSTRUCTION_LIMIT:Int = 250000;
  static inline final HSCRIPT_TIME_LIMIT_MS:Int = 100;
  static inline final LUA_INSTRUCTION_BUDGET:Int = 5000;
  static inline final LUA_HOOK_INTERVAL:Int = 1000;

  public function new(sourcePath:String, source:String, initialVariables:Map<String, Dynamic>)
  {
    if (sourcePath == null || sourcePath.length == 0)
      throw new Exception("A source path is required for a Psych script.");

    this.sourcePath = sourcePath;
    var extension:String = Path.extension(sourcePath).toLowerCase();

    switch (extension)
    {
      case "hx", "hscript":
        language = "hscript";
        createHScript(source, initialVariables);
      case "lua":
        language = "lua";
        createLua(source, initialVariables);
      default:
        throw new Exception("Unsupported Psych script extension: ." + extension);
    }
  }

  function createHScript(source:String, initialVariables:Map<String, Dynamic>):Void
  {
    var runtime = new SScript("", false, false);
    runtime.defaultFunc = null;
    runtime.hscriptSandboxed = true;
    runtime.hscriptInstructionLimit = HSCRIPT_INSTRUCTION_LIMIT;
    runtime.hscriptTimeLimitMs = HSCRIPT_TIME_LIMIT_MS;

    for (name => value in initialVariables)
      runtime.set(name, value);

    // These are the commonly used Psych HScript preset classes. They are
    // bound directly rather than making arbitrary class resolution available.
    runtime.set("FlxG", FlxG);
    runtime.set("FlxCamera", FlxCamera);
    runtime.set("FlxSprite", FlxSprite);
    runtime.set("FlxText", FlxText);
    runtime.set("FlxSubState", FlxSubState);
    runtime.set("FlxMath", FlxMath);
    runtime.set("FlxEase", FlxEase);
    runtime.set("FlxTween", FlxTween);
    // FlxColor is an abstract over Int, not a runtime class. Expose the
    // public static palette and factory methods through a script-friendly object.
    var flxColorApi:Dynamic = {};
    for (name => value in FlxColor.colorLookup)
      Reflect.setField(flxColorApi, name, value);
    Reflect.setField(flxColorApi, "colorLookup", FlxColor.colorLookup);
    Reflect.setField(flxColorApi, "fromInt", function(value:Int):Int return FlxColor.fromInt(value));
    Reflect.setField(flxColorApi, "fromRGB", function(red:Int, green:Int, blue:Int, alpha:Int = 255):Int return FlxColor.fromRGB(red, green, blue, alpha));
    Reflect.setField(flxColorApi, "fromRGBFloat", function(red:Float, green:Float, blue:Float, alpha:Float = 1):Int return FlxColor.fromRGBFloat(red, green, blue, alpha));
    Reflect.setField(flxColorApi, "fromCMYK", function(cyan:Float, magenta:Float, yellow:Float, black:Float, alpha:Float = 1):Int return FlxColor.fromCMYK(cyan, magenta, yellow, black, alpha));
    Reflect.setField(flxColorApi, "fromHSB", function(hue:Float, saturation:Float, brightness:Float, alpha:Float = 1):Int return FlxColor.fromHSB(hue, saturation, brightness, alpha));
    Reflect.setField(flxColorApi, "fromHSL", function(hue:Float, saturation:Float, lightness:Float, alpha:Float = 1):Int return FlxColor.fromHSL(hue, saturation, lightness, alpha));
    Reflect.setField(flxColorApi, "fromString", function(value:String):Null<Int> return FlxColor.fromString(value));
    runtime.set("FlxColor", flxColorApi);
    runtime.set("FlxTimer", FlxTimer);
    runtime.set("Conductor", Conductor);
    runtime.set("Paths", Paths);
    runtime.set("PlayState", PlayState);
    runtime.set("Character", BaseCharacter);
    runtime.set("Note", NoteSprite);
    runtime.set("StringTools", StringTools);

    runtime.doString(source, sourcePath);
    if (runtime.parsingException != null)
    {
      var error:String = Std.string(runtime.parsingException);
      runtime.destroy();
      throw new Exception("HScript error in " + sourcePath + ": " + error);
    }

    hscript = runtime;
  }

  function createLua(source:String, initialVariables:Map<String, Dynamic>):Void
  {
    #if (cpp || js)
    var runtime = new Lua();

    // Install the instruction hook while the debug library is still present.
    // The hook remains active after its global library is removed below.
    var bootstrap:String =
      "local __novabeat_budget = " + Std.string(LUA_INSTRUCTION_BUDGET) + "\n" +
      "local function __novabeat_hook()\n" +
      "  __novabeat_budget = __novabeat_budget - 1\n" +
      "  if __novabeat_budget <= 0 then error('NovaBeat Lua instruction budget exceeded', 0) end\n" +
      "end\n" +
      "function __novabeat_reset_budget() __novabeat_budget = " + Std.string(LUA_INSTRUCTION_BUDGET) + " end\n" +
      "function __novabeat_has_function(name) return type(_G[name]) == 'function' end\n" +
      "debug.sethook(__novabeat_hook, '', " + Std.string(LUA_HOOK_INTERVAL) + ")\n";

    try
    {
      runtime.run(bootstrap);
      luaResetBudget = runtime.getGlobalVar("__novabeat_reset_budget");
      luaHasFunction = runtime.getGlobalVar("__novabeat_has_function");
      runtime.setGlobalVar("__novabeat_reset_budget", null);
      runtime.setGlobalVar("__novabeat_has_function", null);

      // Remove host-level filesystem, process, package and debug access only
      // after the execution-budget hook has been installed and captured.
      for (name in ["io", "os", "package", "debug", "dofile", "loadfile", "require", "collectgarbage"])
        runtime.setGlobalVar(name, null);

      for (name => value in initialVariables)
        runtime.setGlobalVar(name, value);

      resetLuaBudget();
      runtime.run(source);
      lua = runtime;
    }
    catch (error:Dynamic)
    {
      runtime.destroy();
      throw new Exception("Lua error in " + sourcePath + ": " + Std.string(error));
    }
    #else
    throw new Exception("Lua scripts are not supported on this target.");
    #end
  }

  public function hasFunction(name:String):Bool
  {
    if (destroyed || name == null || name.length == 0) return false;

    if (hscript != null)
      return hscript.exists(name);

    #if (cpp || js)
    if (lua != null && luaHasFunction != null)
    {
      try
      {
        return Reflect.callMethod(null, luaHasFunction, [name]) == true;
      }
      catch (error:Dynamic)
      {
        lastError = Std.string(error);
      }
    }
    #end

    return false;
  }

  public function call(name:String, args:Array<Dynamic>):Dynamic
  {
    if (destroyed) return null;
    lastError = null;
    if (!hasFunction(name)) return null;

    try
    {
      if (hscript != null)
      {
        var result = hscript.call(name, args);
        if (!result.succeeded)
        {
          lastError = result.exceptions == null ? "Unknown HScript callback error." : result.exceptions.map(Std.string).join("\n");
          return null;
        }
        return result.returnValue;
      }

      #if (cpp || js)
      if (lua != null)
      {
        resetLuaBudget();
        return lua.call(name, args);
      }
      #end
    }
    catch (error:Dynamic)
    {
      lastError = Std.string(error);
    }

    return null;
  }

  /**
   * Execute another code chunk in this interpreter. Used by Psych's
   * runHaxeCode/runLuaCode helpers to preserve an interpreter between calls.
   */
  public function executeSnippet(source:String):Bool
  {
    if (destroyed || source == null || source.length == 0) return !destroyed;
    lastError = null;
    try
    {
      if (hscript != null)
      {
        hscript.doString(source, sourcePath);
        if (hscript.parsingException != null)
        {
          lastError = Std.string(hscript.parsingException);
          return false;
        }
        return true;
      }

      #if (cpp || js)
      if (lua != null)
      {
        resetLuaBudget();
        lua.run(source);
        return true;
      }
      #end
    }
    catch (error:Dynamic)
    {
      lastError = Std.string(error);
    }
    return false;
  }

  public function setVariable(name:String, value:Dynamic):Void
  {
    if (destroyed || name == null || name.length == 0) return;
    if (hscript != null) hscript.set(name, value);
    #if (cpp || js)
    if (lua != null) lua.setGlobalVar(name, value);
    #end
  }

  public function getVariable(name:String):Dynamic
  {
    if (destroyed || name == null || name.length == 0) return null;
    if (hscript != null) return hscript.get(name);
    #if (cpp || js)
    if (lua != null) return lua.getGlobalVar(name);
    #end
    return null;
  }

  #if (cpp || js)
  function resetLuaBudget():Void
  {
    if (luaResetBudget != null)
      Reflect.callMethod(null, luaResetBudget, []);
  }
  #end

  public function destroy():Void
  {
    if (destroyed) return;
    destroyed = true;

    if (hscript != null)
    {
      hscript.destroy();
      hscript = null;
    }

    #if (cpp || js)
    if (lua != null)
    {
      lua.destroy();
      lua = null;
    }
    luaResetBudget = null;
    luaHasFunction = null;
    #end
  }
}
