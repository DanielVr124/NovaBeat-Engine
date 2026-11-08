package funkin.modding.psychlua;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.Conductor;
import funkin.Paths;
import funkin.play.PlayState;

/**
 * Deliberately bounded Psych API surface for the first script-enabled tier.
 * Mod code can inspect/mutate gameplay objects and create basic sprites, but
 * it cannot access arbitrary process, filesystem, network, or class-loading APIs.
 */
@:nullSafety(Off)
@:access(funkin.play.PlayState)
class PsychGameplayApi
{
  static final spriteTweens:Map<String, FlxTween> = [];

  public static function createGlobals(state:PlayState):Map<String, Dynamic>
  {
    var vars:Map<String, Dynamic> = [];

    vars.set("getProperty", function(path:String, ?allowMaps:Bool = false):Dynamic return getProperty(state, path, allowMaps));
    vars.set("setProperty", function(path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic return setProperty(state, path, value, allowMaps));
    vars.set("getPropertyFromClass", function(className:String, path:String, ?allowMaps:Bool = false):Dynamic
      return getPropertyFromClass(className, path, allowMaps));
    vars.set("setPropertyFromClass", function(className:String, path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
      return setPropertyFromClass(className, path, value, allowMaps));
    vars.set("getPropertyFromGroup", function(group:String, index:Int, path:String, ?allowMaps:Bool = false):Dynamic
      return getPropertyFromGroup(state, group, index, path, allowMaps));
    vars.set("setPropertyFromGroup", function(group:String, index:Int, path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
      return setPropertyFromGroup(state, group, index, path, value, allowMaps));

    vars.set("setVar", function(name:String, value:Dynamic):Dynamic
    {
      state.variables.set(name, value);
      return value;
    });
    vars.set("getVar", function(name:String):Dynamic return state.variables.get(name));
    vars.set("removeVar", function(name:String):Bool return state.variables.remove(name));

    vars.set("getSongPosition", function():Float return Conductor.instance.songPosition);
    vars.set("debugPrint", function(message:Dynamic, ?color:Dynamic):Void trace(Std.string(message)));
    vars.set("getRandomInt", function(min:Int, max:Int):Int return FlxG.random.int(min, max));
    vars.set("getRandomFloat", function(min:Float, max:Float):Float return FlxG.random.float(min, max));
    vars.set("getRandomBool", function(?chance:Float = 50):Bool return FlxG.random.bool(chance));
    vars.set("getRunningScripts", function():Array<String> return PsychScriptRuntime.getScriptPaths());

    vars.set("makeLuaSprite", function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Bool
    {
      var sprite = new FlxSprite(x, y);
      try
      {
        if (image != null && image.length > 0)
          sprite.loadGraphic(Paths.image(image));
        state.variables.set(tag, sprite);
        return true;
      }
      catch (error:Dynamic)
      {
        sprite.destroy();
        trace('[Psych API] makeLuaSprite(' + tag + ') failed: ' + Std.string(error));
        return false;
      }
    });

    vars.set("makeAnimatedLuaSprite", function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Bool
    {
      var sprite = new FlxSprite(x, y);
      try
      {
        sprite.frames = Paths.getSparrowAtlas(image);
        state.variables.set(tag, sprite);
        return true;
      }
      catch (error:Dynamic)
      {
        sprite.destroy();
        trace('[Psych API] makeAnimatedLuaSprite(' + tag + ') failed: ' + Std.string(error));
        return false;
      }
    });

    vars.set("addAnimationByPrefix", function(tag:String, name:String, prefix:String, ?framerate:Int = 24, ?loop:Bool = true):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.animation.addByPrefix(name, prefix, framerate, loop);
      return true;
    });
    vars.set("objectPlayAnimation", function(tag:String, name:String, ?force:Bool = false, ?reversed:Bool = false, ?frame:Int = 0):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.animation.play(name, force, reversed, frame);
      return true;
    });
    vars.set("addLuaSprite", function(tag:String, ?inFront:Bool = false):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      if (inFront) state.add(sprite);
      else state.insert(0, sprite);
      return true;
    });
    vars.set("removeLuaSprite", function(tag:String, ?destroy:Bool = true):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      state.remove(sprite, true);
      if (destroy) sprite.destroy();
      return true;
    });
    vars.set("setObjectCamera", function(tag:String, camera:String):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      var normalized:String = camera == null ? "game" : camera.toLowerCase();
      sprite.cameras = [normalized == "hud" || normalized == "camhud" ? state.camHUD : state.camGame];
      return true;
    });
    vars.set("setScrollFactor", function(tag:String, x:Float, ?y:Null<Float>):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.scrollFactor.set(x, y == null ? x : y);
      return true;
    });
    vars.set("scaleObject", function(tag:String, x:Float, y:Float):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.scale.set(x, y);
      sprite.updateHitbox();
      return true;
    });
    vars.set("setGraphicSize", function(tag:String, width:Int, ?height:Int = 0):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.setGraphicSize(width, height);
      sprite.updateHitbox();
      return true;
    });
    vars.set("setObjectOrder", function(tag:String, index:Int):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      state.remove(sprite, false);
      var target:Int = Std.int(Math.max(0, Math.min(index, state.members.length)));
      state.insert(target, sprite);
      return true;
    });
    vars.set("getObjectOrder", function(tag:String):Int
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      return sprite == null ? -1 : state.members.indexOf(sprite);
    });

    vars.set("triggerEvent", function(name:String, ?value1:String = "", ?value2:String = ""):Void
      triggerEvent(state, name, value1, value2));

    // Basic Psych-compatible camera aliases. They are read-only snapshots;
    // scripts should use getProperty/setProperty for mutable nested values.
    vars.set("screenWidth", FlxG.width);
    vars.set("screenHeight", FlxG.height);
    vars.set("songName", state.currentSong == null ? "" : state.currentSong.songName);
    vars.set("Function_Continue", 0);
    vars.set("Function_Stop", 1);
    vars.set("Function_StopLua", 2);
    vars.set("Function_StopHScript", 3);
    vars.set("Function_StopAll", 4);

    return vars;
  }

  static function getSprite(state:PlayState, tag:String):Null<FlxSprite>
  {
    if (tag == null || !state.variables.exists(tag)) return null;
    var value:Dynamic = state.variables.get(tag);
    return Std.isOfType(value, FlxSprite) ? cast value : null;
  }

  static function getProperty(state:PlayState, path:String, allowMaps:Bool = false):Dynamic
  {
    if (path == null || path.length == 0) return null;
    try
    {
      var parts:Array<String> = path.split(".");
      var current:Dynamic = resolveRoot(state, parts.shift());
      if (current == null) return null;
      for (part in parts)
      {
        current = getSegment(current, part, allowMaps);
        if (current == null) return null;
      }
      return current;
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] getProperty(' + path + ') failed: ' + Std.string(error));
      return null;
    }
  }

  static function setProperty(state:PlayState, path:String, value:Dynamic, allowMaps:Bool = false):Dynamic
  {
    if (path == null || path.length == 0) return null;
    try
    {
      var parts:Array<String> = path.split(".");
      var rootName:String = parts.shift();
      var current:Dynamic = resolveRoot(state, rootName);
      if (current == null) return null;
      if (parts.length == 0)
      {
        if (state.variables.exists(rootName))
          state.variables.set(rootName, value);
        else
          Reflect.setProperty(state, rootName, value);
        return value;
      }
      for (i in 0...(parts.length - 1))
      {
        current = getSegment(current, parts[i], allowMaps);
        if (current == null) return null;
      }
      return setSegment(current, parts[parts.length - 1], value, allowMaps);
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] setProperty(' + path + ') failed: ' + Std.string(error));
      return null;
    }
  }

  static function resolveRoot(state:PlayState, name:String):Dynamic
  {
    if (name == null) return null;
    switch (name)
    {
      case "this", "instance", "game":
        return state;
      case "notes":
        return getActiveNotes(state);
      case "boyfriend":
        return getStageCharacter(state, "getBoyfriend");
      case "dad", "opponent":
        return getStageCharacter(state, "getDad");
      case "gf", "girlfriend":
        return getStageCharacter(state, "getGirlfriend");
      case "FlxG", "flixel.FlxG":
        return FlxG;
      default:
        if (state.variables.exists(name)) return state.variables.get(name);
        return Reflect.getProperty(state, name);
    }
  }

  static function getStageCharacter(state:PlayState, getter:String):Dynamic
  {
    var stage:Dynamic = Reflect.getProperty(state, "currentStage");
    if (stage == null) return null;
    var method:Dynamic = Reflect.field(stage, getter);
    return method == null ? null : Reflect.callMethod(stage, method, []);
  }

  static function getSegment(object:Dynamic, segment:String, allowMaps:Bool):Dynamic
  {
    if (object == null) return null;
    var bracket:EReg = ~/^([^\[]+)\[([0-9]+)\]$/;
    if (bracket.match(segment))
    {
      var field:String = bracket.matched(1);
      var index:Int = Std.parseInt(bracket.matched(2));
      var collection:Dynamic = getField(object, field, allowMaps);
      return collection == null ? null : collection[index];
    }
    return getField(object, segment, allowMaps);
  }

  static function getField(object:Dynamic, field:String, allowMaps:Bool):Dynamic
  {
    if (object == null) return null;
    if (allowMaps && Reflect.hasField(object, "get"))
      return Reflect.callMethod(object, Reflect.field(object, "get"), [field]);
    return Reflect.getProperty(object, field);
  }

  static function setSegment(object:Dynamic, segment:String, value:Dynamic, allowMaps:Bool):Dynamic
  {
    var bracket:EReg = ~/^([^\[]+)\[([0-9]+)\]$/;
    if (bracket.match(segment))
    {
      var field:String = bracket.matched(1);
      var index:Int = Std.parseInt(bracket.matched(2));
      var collection:Dynamic = getField(object, field, allowMaps);
      if (collection == null) return null;
      collection[index] = value;
      return value;
    }

    if (allowMaps && Reflect.hasField(object, "set"))
    {
      Reflect.callMethod(object, Reflect.field(object, "set"), [segment, value]);
      return value;
    }
    Reflect.setProperty(object, segment, value);
    return value;
  }

  static function getPropertyFromClass(className:String, path:String, allowMaps:Bool):Dynamic
  {
    var allowed:Array<String> = [
      "flixel.FlxG",
      "flixel.math.FlxMath",
      "flixel.util.FlxColor",
      "funkin.Paths",
      "funkin.play.PlayState"
    ];
    if (allowed.indexOf(className) == -1) return null;
    var klass:Dynamic = Type.resolveClass(className);
    return getFromObject(klass, path, allowMaps);
  }

  static function setPropertyFromClass(className:String, path:String, value:Dynamic, allowMaps:Bool):Dynamic
  {
    var allowed:Array<String> = ["flixel.FlxG", "flixel.util.FlxColor", "funkin.play.PlayState"];
    if (allowed.indexOf(className) == -1) return null;
    var klass:Dynamic = Type.resolveClass(className);
    return setOnObject(klass, path, value, allowMaps);
  }

  static function getFromObject(root:Dynamic, path:String, allowMaps:Bool):Dynamic
  {
    if (root == null || path == null) return null;
    var parts:Array<String> = path.split(".");
    var current:Dynamic = root;
    for (part in parts)
    {
      current = getSegment(current, part, allowMaps);
      if (current == null) return null;
    }
    return current;
  }

  static function setOnObject(root:Dynamic, path:String, value:Dynamic, allowMaps:Bool):Dynamic
  {
    if (root == null || path == null) return null;
    var parts:Array<String> = path.split(".");
    var current:Dynamic = root;
    for (i in 0...(parts.length - 1))
    {
      current = getSegment(current, parts[i], allowMaps);
      if (current == null) return null;
    }
    return setSegment(current, parts[parts.length - 1], value, allowMaps);
  }

  public static function getNoteId(state:PlayState, note:NoteSprite):Int
  {
    return getActiveNotes(state).indexOf(note);
  }

  static function getActiveNotes(state:PlayState):Array<NoteSprite>
  {
    var result:Array<NoteSprite> = [];
    if (state.playerStrumline != null && state.playerStrumline.notes != null)
      for (note in state.playerStrumline.notes.members)
        if (note != null && note.exists && note.alive) result.push(note);
    if (state.opponentStrumline != null && state.opponentStrumline.notes != null)
      for (note in state.opponentStrumline.notes.members)
        if (note != null && note.exists && note.alive) result.push(note);
    result.sort(function(a:NoteSprite, b:NoteSprite):Int
    {
      return Reflect.compare(a.strumTime, b.strumTime);
    });
    return result;
  }

  static function getPropertyFromGroup(state:PlayState, group:String, index:Int, path:String, allowMaps:Bool):Dynamic
  {
    var collection:Dynamic = resolveRoot(state, group);
    if (collection == null) return null;
    var members:Dynamic = Reflect.field(collection, "members");
    var item:Dynamic = members != null ? members[index] : collection[index];
    return getFromObject(item, path, allowMaps);
  }

  static function setPropertyFromGroup(state:PlayState, group:String, index:Int, path:String, value:Dynamic, allowMaps:Bool):Dynamic
  {
    var collection:Dynamic = resolveRoot(state, group);
    if (collection == null) return null;
    var members:Dynamic = Reflect.field(collection, "members");
    var item:Dynamic = members != null ? members[index] : collection[index];
    return setOnObject(item, path, value, allowMaps);
  }

  static function triggerEvent(state:PlayState, name:String, value1:String, value2:String):Void
  {
    switch (StringTools.trim(name).toLowerCase())
    {
      case "add camera zoom":
        var gameZoom:Float = parseFloatOr(value1, 0);
        var hudZoom:Float = parseFloatOr(value2, 0);
        if (gameZoom != 0) state.camGame.zoom += gameZoom;
        if (hudZoom != 0) state.camHUD.zoom += hudZoom;
      case "screen shake":
        var gameParts:Array<String> = value1.split(",");
        var hudParts:Array<String> = value2.split(",");
        if (gameParts.length >= 2)
          state.camGame.shake(parseFloatOr(gameParts[1], 0), parseFloatOr(gameParts[0], 0));
        if (hudParts.length >= 2)
          state.camHUD.shake(parseFloatOr(hudParts[1], 0), parseFloatOr(hudParts[0], 0));
      case "set property":
        setProperty(state, value1, value2);
      default:
        trace('[Psych API] Unsupported built-in event: ' + name);
    }
  }

  static function parseFloatOr(value:String, fallback:Float):Float
  {
    var result:Null<Float> = Std.parseFloat(value);
    return result == null || Math.isNaN(result) ? fallback : result;
  }
}
