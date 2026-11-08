package funkin.modding.psychlua;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.math.FlxPoint;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import funkin.Conductor;
import funkin.Paths;
import funkin.play.PlayState;
import funkin.Highscore;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.SustainTrail;
import funkin.play.character.BaseCharacter;
import funkin.play.notes.Strumline;
import funkin.play.notes.StrumlineNote;

/**
 * Deliberately bounded Psych API surface for the first script-enabled tier.
 * Mod code can inspect/mutate gameplay objects and create basic sprites, but
 * it cannot access arbitrary process, filesystem, network, or class-loading APIs.
 */
@:nullSafety(Off)
@:access(funkin.play.PlayState)
class PsychGameplayApi
{
  static final activeTweens:Map<String, FlxTween> = [];
  static final activeTimers:Map<String, FlxTimer> = [];
  static final scriptVariables:Map<String, Dynamic> = [];
  static final activeSounds:Map<String, FlxSound> = [];
  static var activeCustomSubstate:Null<PsychCustomSubState> = null;
  static var nextSoundTag:Int = 0;

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
      scriptVariables.set(name, value);
      return value;
    });
    vars.set("getVar", function(name:String):Dynamic return scriptVariables.get(name));
    vars.set("removeVar", function(name:String):Bool return scriptVariables.remove(name));

    vars.set("playSound", function(sound:String, ?volume:Float = 1, ?tag:String = ""):Bool
      return playTaggedSound(sound, volume, tag));
    vars.set("playMusic", function(music:String, ?volume:Float = 1, ?looped:Bool = true):Bool
      return playModMusic(music, volume, looped));
    vars.set("stopSound", function(?tag:String = ""):Void stopTaggedSound(tag));
    vars.set("pauseSound", function(?tag:String = ""):Void pauseTaggedSound(tag));
    vars.set("resumeSound", function(?tag:String = ""):Void resumeTaggedSound(tag));
    vars.set("setSoundVolume", function(tag:String, volume:Float):Bool return setTaggedSoundVolume(tag, volume));
    vars.set("stopMusic", function():Void
    {
      if (FlxG.sound.music != null) FlxG.sound.music.stop();
    });

    vars.set("getSongPosition", function():Float return Conductor.instance.songPosition);
    vars.set("keyboardJustPressed", function(key:String):Bool return keyboardStatus(key, "justPressed"));
    vars.set("keyboardPressed", function(key:String):Bool return keyboardStatus(key, "pressed"));
    vars.set("keyboardReleased", function(key:String):Bool return keyboardStatus(key, "justReleased"));
    vars.set("anyGamepadJustPressed", function(button:String):Bool return FlxG.gamepads.anyJustPressed(button));
    vars.set("anyGamepadPressed", function(button:String):Bool return FlxG.gamepads.anyPressed(button));
    vars.set("anyGamepadReleased", function(button:String):Bool return FlxG.gamepads.anyJustReleased(button));
    vars.set("gamepadAnalogX", function(id:Int, ?leftStick:Bool = true):Float
    {
      var controller = FlxG.gamepads.getByID(id);
      if (controller == null) return 0.0;
      var stickId:FlxGamepadInputID = leftStick
        ? FlxGamepadInputID.LEFT_ANALOG_STICK
        : FlxGamepadInputID.RIGHT_ANALOG_STICK;
      return controller.getXAxis(stickId);
    });
    vars.set("gamepadAnalogY", function(id:Int, ?leftStick:Bool = true):Float
    {
      var controller = FlxG.gamepads.getByID(id);
      if (controller == null) return 0.0;
      var stickId:FlxGamepadInputID = leftStick
        ? FlxGamepadInputID.LEFT_ANALOG_STICK
        : FlxGamepadInputID.RIGHT_ANALOG_STICK;
      return controller.getYAxis(stickId);
    });
    vars.set("mouseClicked", function(?button:String = "left"):Bool return mouseStatus(button, "justPressed"));
    vars.set("mousePressed", function(?button:String = "left"):Bool return mouseStatus(button, "pressed"));
    vars.set("mouseReleased", function(?button:String = "left"):Bool return mouseStatus(button, "justReleased"));
    vars.set("getMouseX", function(?camera:String = "game"):Float return getMousePosition(state, camera).x);
    vars.set("getMouseY", function(?camera:String = "game"):Float return getMousePosition(state, camera).y);
    vars.set("getMouseWheel", function():Int return FlxG.mouse.wheel);
    vars.set("getColorFromHex", function(color:String):Int return parsePsychColor(color));
    vars.set("addScore", function(value:Int):Void setProperty(state, "score", state.songScore + value));
    vars.set("setScore", function(value:Int):Void setProperty(state, "score", value));
    vars.set("addMisses", function(value:Int):Void setProperty(state, "misses", Highscore.tallies.missed + value));
    vars.set("setMisses", function(value:Int):Void setProperty(state, "misses", value));
    vars.set("addHits", function(value:Int):Void setProperty(state, "hits", Highscore.tallies.totalNotesHit + value));
    vars.set("setHits", function(value:Int):Void setProperty(state, "hits", value));
    vars.set("debugPrint", function(message:Dynamic, ?color:Dynamic):Void trace(Std.string(message)));
    vars.set("getRandomInt", function(min:Int, max:Int):Int return FlxG.random.int(min, max));
    vars.set("getRandomFloat", function(min:Float, max:Float):Float return FlxG.random.float(min, max));
    vars.set("getRandomBool", function(?chance:Float = 50):Bool return FlxG.random.bool(chance));
    vars.set("getRunningScripts", function():Array<String> return PsychScriptRuntime.getScriptPaths());
    vars.set("addHaxeLibrary", function(name:String, ?packageName:String = ""):Bool
      return PsychScriptRuntime.addHaxeLibrary(name, packageName));
    vars.set("runHaxeCode", function(code:String, ?variablesToBring:Dynamic):Bool
      return PsychScriptRuntime.runHaxeCode(code, variablesToBring));
    vars.set("runHaxeFunction", function(name:String, ?args:Array<Dynamic>):Dynamic
      return PsychScriptRuntime.runHaxeFunction(name, args));
    vars.set("runLuaCode", function(code:String, ?variablesToBring:Dynamic):Bool
      return PsychScriptRuntime.runLuaCode(code, variablesToBring));
    vars.set("runLuaFunction", function(name:String, ?args:Array<Dynamic>):Dynamic
      return PsychScriptRuntime.runLuaFunction(name, args));
    vars.set("callOnScripts", function(name:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Dynamic
      return PsychScriptRuntime.callOnScripts(name, args, ignoreStops));
    vars.set("callOnLuas", function(name:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Dynamic
      return PsychScriptRuntime.callOnLuas(name, args, ignoreStops));
    vars.set("callOnHScript", function(name:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false):Dynamic
      return PsychScriptRuntime.callOnHScript(name, args, ignoreStops));
    vars.set("setOnScripts", function(name:String, value:Dynamic):Void PsychScriptRuntime.setOnScripts(name, value));
    vars.set("setOnLuas", function(name:String, value:Dynamic):Void PsychScriptRuntime.setOnLuas(name, value));
    vars.set("setOnHScript", function(name:String, value:Dynamic):Void PsychScriptRuntime.setOnHScript(name, value));

    vars.set("doTweenX", function(tag:String, objectTag:String, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return startTween(state, tag, objectTag, {x: value}, duration, ease));
    vars.set("doTweenY", function(tag:String, objectTag:String, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return startTween(state, tag, objectTag, {y: value}, duration, ease));
    vars.set("doTweenAlpha", function(tag:String, objectTag:String, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return startTween(state, tag, objectTag, {alpha: value}, duration, ease));
    vars.set("doTweenAngle", function(tag:String, objectTag:String, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return startTween(state, tag, objectTag, {angle: value}, duration, ease));
    vars.set("doTweenZoom", function(tag:String, cameraTag:String, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return startTween(state, tag, cameraTag, {zoom: value}, duration, ease));
    vars.set("doTweenColor", function(tag:String, objectTag:String, color:String, duration:Float, ?ease:String = "linear"):Bool
      return startColorTween(state, tag, objectTag, color, duration, ease));
    vars.set("noteTweenX", function(tag:String, note:Int, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return noteTween(state, tag, note, {x: value}, duration, ease));
    vars.set("noteTweenY", function(tag:String, note:Int, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return noteTween(state, tag, note, {y: value}, duration, ease));
    vars.set("noteTweenAngle", function(tag:String, note:Int, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return noteTween(state, tag, note, {angle: value}, duration, ease));
    vars.set("noteTweenAlpha", function(tag:String, note:Int, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return noteTween(state, tag, note, {alpha: value}, duration, ease));
    vars.set("cancelTween", function(tag:String):Bool return cancelTween(tag));
    vars.set("runTimer", function(tag:String, time:Float, ?loops:Int = 1):Bool return runTimer(tag, time, loops));
    vars.set("cancelTimer", function(tag:String):Bool return cancelTimer(tag));

    vars.set("openCustomSubstate", function(name:String, ?pauseGame:Bool = false):Bool
      return PsychScriptRuntime.openCustomSubstate(state, name, pauseGame));
    vars.set("closeCustomSubstate", function():Void PsychScriptRuntime.closeCustomSubstate(state));
    vars.set("insertToCustomSubstate", function(tag:String, ?position:Int = -1):Bool
      return insertToCustomSubstate(state, tag, position));
    vars.set("customSubstate", null);
    vars.set("customSubstateName", "");

    vars.set("makeLuaSprite", function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Bool
    {
      var sprite = new FlxSprite(x, y);
      try
      {
        if (image != null && image.length > 0)
          sprite.loadGraphic(Paths.image(image));
        scriptVariables.set(tag, sprite);
        return true;
      }
      catch (error:Dynamic)
      {
        sprite.destroy();
        trace('[Psych API] makeLuaSprite(' + tag + ') failed: ' + Std.string(error));
        return false;
      }
    });

    vars.set("makeGraphic", function(tag:String, width:Int, height:Int, ?color:Dynamic = null):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null)
      {
        sprite = new FlxSprite();
        scriptVariables.set(tag, sprite);
      }
      sprite.makeGraphic(width, height, parsePsychColor(color));
      return true;
    });

    vars.set("makeLuaText", function(tag:String, text:String, width:Float, ?x:Float = 0, ?y:Float = 0, ?size:Int = 16):Bool
    {
      var object:FlxText = new FlxText(x, y, width, text == null ? "" : text, size);
      scriptVariables.set(tag, object);
      return true;
    });
    vars.set("addLuaText", function(tag:String, ?inFront:Bool = false):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null || !Std.isOfType(sprite, FlxText)) return false;
      if (inFront) state.add(sprite);
      else state.insert(0, sprite);
      return true;
    });
    vars.set("setTextString", function(tag:String, value:String):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).text = value == null ? "" : value;
      return true;
    });
    vars.set("setTextSize", function(tag:String, value:Int):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).size = value;
      return true;
    });
    vars.set("setTextColor", function(tag:String, value:Dynamic):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      object.color = parsePsychColor(value);
      return true;
    });
    vars.set("setTextFont", function(tag:String, value:String):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).font = value;
      return true;
    });
    vars.set("setTextAlignment", function(tag:String, value:String):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).alignment = cast value;
      return true;
    });
    vars.set("setTextBorder", function(tag:String, borderSize:Float, ?borderColor:Dynamic = null, ?borderStyle:String = "outline"):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      var textObject:FlxText = cast object;
      textObject.setBorderStyle(resolveTextBorderStyle(borderStyle), parsePsychColor(borderColor), borderSize);
      return true;
    });

    vars.set("makeAnimatedLuaSprite", function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Bool
    {
      var sprite = new FlxSprite(x, y);
      try
      {
        sprite.frames = Paths.getSparrowAtlas(image);
        scriptVariables.set(tag, sprite);
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
      scriptVariables.remove(tag);
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
    vars.set("difficulty", state.currentDifficulty);
    vars.set("game", state);
    vars.set("stage", state.currentStage);
    vars.set("camGame", state.camGame);
    vars.set("camHUD", state.camHUD);

    if (state.currentStage != null)
    {
      vars.set("boyfriend", state.currentStage.getBoyfriend());
      vars.set("dad", state.currentStage.getDad());
      vars.set("gf", state.currentStage.getGirlfriend());
    }

    vars.set("add", function(object:Dynamic):Dynamic
    {
      if (object != null && Std.isOfType(object, FlxBasic))
        state.add(cast object);
      return object;
    });
    vars.set("insert", function(index:Int, object:Dynamic):Dynamic
    {
      if (object != null && Std.isOfType(object, FlxBasic))
        state.insert(index, cast object);
      return object;
    });
    vars.set("remove", function(object:Dynamic, ?destroy:Bool = false):Dynamic
    {
      if (object != null && Std.isOfType(object, FlxBasic))
      {
        state.remove(cast object, true);
        if (destroy) (cast object:FlxBasic).destroy();
      }
      return object;
    });

    if (state.playerStrumline != null)
    {
      for (i in 0...Strumline.DIRECTIONS.length)
      {
        var receptor = state.playerStrumline.getByDirection(Strumline.DIRECTIONS[i]);
        if (receptor != null)
        {
          vars.set("defaultPlayerStrumX" + i, receptor.x);
          vars.set("defaultPlayerStrumY" + i, receptor.y);
        }
      }
    }
    if (state.opponentStrumline != null)
    {
      for (i in 0...Strumline.DIRECTIONS.length)
      {
        var receptor = state.opponentStrumline.getByDirection(Strumline.DIRECTIONS[i]);
        if (receptor != null)
        {
          vars.set("defaultOpponentStrumX" + i, receptor.x);
          vars.set("defaultOpponentStrumY" + i, receptor.y);
        }
      }
    }
    vars.set("Function_Continue", PsychScriptRuntime.getGlobal("Function_Continue"));
    vars.set("Function_Stop", PsychScriptRuntime.getGlobal("Function_Stop"));
    vars.set("Function_StopLua", PsychScriptRuntime.getGlobal("Function_StopLua"));
    vars.set("Function_StopHScript", PsychScriptRuntime.getGlobal("Function_StopHScript"));
    vars.set("Function_StopAll", PsychScriptRuntime.getGlobal("Function_StopAll"));

    return vars;
  }

  public static function hideDefaultStageProps(state:PlayState):Void
  {
    if (state == null || state.currentStage == null) return;
    for (member in state.currentStage.members)
    {
      if (member == null || Std.isOfType(member, BaseCharacter)) continue;
      member.visible = false;
    }
  }

  static function playTaggedSound(soundPath:String, volume:Float, tag:String):Bool
  {
    if (soundPath == null || soundPath.length == 0) return false;
    var soundTag:String = tag == null || tag.length == 0
      ? "psych-sound-" + Std.string(nextSoundTag++)
      : tag;
    stopTaggedSound(soundTag);

    try
    {
      var sound:FlxSound = FlxG.sound.play(Paths.sound(soundPath), volume, false, null, true, function():Void
      {
        activeSounds.remove(soundTag);
        PsychScriptRuntime.dispatch("onSoundFinished", [soundTag]);
      });
      if (sound == null) return false;
      activeSounds.set(soundTag, sound);
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] playSound(' + soundPath + ') failed: ' + Std.string(error));
      return false;
    }
  }

  static function playModMusic(musicPath:String, volume:Float, looped:Bool):Bool
  {
    if (musicPath == null || musicPath.length == 0) return false;
    try
    {
      FlxG.sound.playMusic(Paths.music(musicPath), volume, looped);
      return FlxG.sound.music != null;
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] playMusic(' + musicPath + ') failed: ' + Std.string(error));
      return false;
    }
  }

  static function stopTaggedSound(tag:String):Void
  {
    if (tag == null || tag.length == 0)
    {
      for (sound in activeSounds)
        if (sound != null) sound.stop();
      activeSounds.clear();
      return;
    }

    var sound:Null<FlxSound> = activeSounds.get(tag);
    if (sound != null) sound.stop();
    activeSounds.remove(tag);
  }

  static function pauseTaggedSound(tag:String):Void
  {
    var sound:Null<FlxSound> = activeSounds.get(tag);
    if (sound != null) sound.pause();
  }

  static function resumeTaggedSound(tag:String):Void
  {
    var sound:Null<FlxSound> = activeSounds.get(tag);
    if (sound != null) sound.resume();
  }

  static function setTaggedSoundVolume(tag:String, volume:Float):Bool
  {
    var sound:Null<FlxSound> = activeSounds.get(tag);
    if (sound == null) return false;
    sound.volume = Math.max(0, Math.min(1, volume));
    return true;
  }

  static function resolveEase(name:String):Float->Float
  {
    return switch (name == null ? "linear" : name.toLowerCase())
    {
      case "quadin": FlxEase.quadIn;
      case "quadout": FlxEase.quadOut;
      case "quadinout": FlxEase.quadInOut;
      case "cubein": FlxEase.cubeIn;
      case "cubeout": FlxEase.cubeOut;
      case "cubeinout": FlxEase.cubeInOut;
      case "sinein": FlxEase.sineIn;
      case "sineout": FlxEase.sineOut;
      case "sineinout": FlxEase.sineInOut;
      case "circin": FlxEase.circIn;
      case "circout": FlxEase.circOut;
      case "bounceout": FlxEase.bounceOut;
      case "elasticout": FlxEase.elasticOut;
      default: FlxEase.linear;
    }
  }

  static function startTween(state:PlayState, tag:String, objectTag:String, values:Dynamic, duration:Float, ease:String):Bool
  {
    var target:Dynamic = getProperty(state, objectTag);
    return startTweenTarget(tag, target, values, duration, ease, [tag, values]);
  }

  static function startTweenTarget(tag:String, target:Dynamic, values:Dynamic, duration:Float, ease:String, callbackArgs:Array<Dynamic>):Bool
  {
    if (tag == null || tag.length == 0 || target == null || duration < 0) return false;
    cancelTween(tag);

    var tween:FlxTween = FlxTween.tween(target, values, duration, {
      ease: resolveEase(ease),
      onComplete: function(_:FlxTween):Void
      {
        activeTweens.remove(tag);
        PsychScriptRuntime.dispatch("onTweenCompleted", callbackArgs);
      }
    });
    activeTweens.set(tag, tween);
    return true;
  }

  static function startColorTween(state:PlayState, tag:String, objectTag:String, color:String, duration:Float, ease:String):Bool
  {
    var target:Dynamic = getProperty(state, objectTag);
    if (!Std.isOfType(target, FlxSprite)) return false;
    var sprite:FlxSprite = cast target;
    var parsedColor:Null<FlxColor> = FlxColor.fromString(color);
    if (parsedColor == null) return false;
    if (tag == null || tag.length == 0 || duration < 0) return false;
    cancelTween(tag);

    var tween:FlxTween = FlxTween.color(sprite, duration, sprite.color, parsedColor, {
      ease: resolveEase(ease),
      onComplete: function(_:FlxTween):Void
      {
        activeTweens.remove(tag);
        PsychScriptRuntime.dispatch("onTweenCompleted", [tag, {color: color}]);
      }
    });
    activeTweens.set(tag, tween);
    return true;
  }

  static function cancelTween(tag:String):Bool
  {
    var tween:Null<FlxTween> = activeTweens.get(tag);
    if (tween == null) return false;
    tween.cancel();
    activeTweens.remove(tag);
    return true;
  }

  static function runTimer(tag:String, time:Float, loops:Int):Bool
  {
    if (tag == null || tag.length == 0 || time < 0) return false;
    cancelTimer(tag);
    var timer = new FlxTimer();
    timer.start(time, function(t:FlxTimer):Void
    {
      PsychScriptRuntime.dispatch("onTimerCompleted", [tag, t.loops, t.loopsLeft]);
      if (t.finished)
        activeTimers.remove(tag);
    }, loops);
    activeTimers.set(tag, timer);
    return true;
  }

  static function cancelTimer(tag:String):Bool
  {
    var timer:Null<FlxTimer> = activeTimers.get(tag);
    if (timer == null) return false;
    timer.cancel();
    activeTimers.remove(tag);
    return true;
  }

  public static function hasActiveCustomSubstate():Bool
  {
    return activeCustomSubstate != null;
  }

  public static function openCustomSubstate(state:PlayState, subState:PsychCustomSubState, pauseGame:Bool):Bool
  {
    if (state == null || subState == null || activeCustomSubstate != null) return false;
    activeCustomSubstate = subState;
    state.persistentUpdate = !pauseGame;
    state.shouldSubstatePause = pauseGame;
    state.openSubState(subState);
    return true;
  }

  public static function insertToCustomSubstate(state:PlayState, tag:String, position:Int = -1):Bool
  {
    if (activeCustomSubstate == null) return false;
    var object:Null<FlxSprite> = getSprite(state, tag);
    if (object == null) return false;
    if (position < 0 || position >= activeCustomSubstate.members.length)
      activeCustomSubstate.add(object);
    else
      activeCustomSubstate.insert(position, object);
    return true;
  }

  public static function finishCustomSubstate(subState:PsychCustomSubState):Void
  {
    if (activeCustomSubstate == subState) activeCustomSubstate = null;
  }

  public static function clear():Void
  {
    activeCustomSubstate = null;
    for (tween in activeTweens)
      tween.cancel();
    for (timer in activeTimers)
      timer.cancel();
    activeTweens.clear();
    activeTimers.clear();
    for (sound in activeSounds)
      if (sound != null) sound.stop();
    activeSounds.clear();
    scriptVariables.clear();
  }

  static function keyboardStatus(key:String, status:String):Bool
  {
    if (key == null || StringTools.trim(key).length == 0) return false;
    var normalized:String = StringTools.trim(key);
    if (normalized.toLowerCase() == "esc") normalized = "ESCAPE";
    if (normalized.toLowerCase() == "return") normalized = "ENTER";
    var keyState:Dynamic = Reflect.getProperty(FlxG.keys, status);
    if (keyState == null) return false;
    var pressed:Dynamic = Reflect.getProperty(keyState, normalized.toUpperCase());
    return pressed == true;
  }

  static function mouseStatus(button:String, status:String):Bool
  {
    var normalized:String = button == null ? "left" : button.toLowerCase();
    return switch (normalized)
    {
      case "right":
        switch (status)
        {
          case "pressed": FlxG.mouse.pressedRight;
          case "justReleased": FlxG.mouse.justReleasedRight;
          default: FlxG.mouse.justPressedRight;
        }
      case "middle":
        switch (status)
        {
          case "pressed": FlxG.mouse.pressedMiddle;
          case "justReleased": FlxG.mouse.justReleasedMiddle;
          default: FlxG.mouse.justPressedMiddle;
        }
      default:
        switch (status)
        {
          case "pressed": FlxG.mouse.pressed;
          case "justReleased": FlxG.mouse.justReleased;
          default: FlxG.mouse.justPressed;
        }
    }
  }

  static function getMousePosition(state:PlayState, camera:String):FlxPoint
  {
    var targetCamera:FlxCamera = state.camGame;
    if (camera != null && camera.toLowerCase() == "hud") targetCamera = state.camHUD;
    return FlxG.mouse.getWorldPosition(targetCamera);
  }

  /**
   * Convert Psych's string border-style names into HaxeFlixel's enum.
   * A string cast is not valid for this enum on C++ targets.
   */
  static function resolveTextBorderStyle(value:String):FlxTextBorderStyle
  {
    return switch (value == null ? "outline" : StringTools.trim(value).toLowerCase())
    {
      case "none": FlxTextBorderStyle.NONE;
      case "shadow": FlxTextBorderStyle.SHADOW;
      case "shadow_xy", "shadow-xy": FlxTextBorderStyle.SHADOW_XY(1, 1);
      case "outline_fast", "outline-fast", "outlinefast": FlxTextBorderStyle.OUTLINE_FAST;
      default: FlxTextBorderStyle.OUTLINE;
    };
  }

  static function parsePsychColor(value:Dynamic):FlxColor
  {
    if (value == null) return FlxColor.WHITE;
    if (Std.isOfType(value, Int)) return cast value;
    var colorText:String = StringTools.trim(Std.string(value));
    if (colorText.length == 0) return FlxColor.WHITE;
    if (!StringTools.startsWith(colorText, "#") && !StringTools.startsWith(colorText.toLowerCase(), "0x")
      && (~/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.match(colorText)))
      colorText = "#" + colorText;
    var parsed:Null<FlxColor> = FlxColor.fromString(colorText);
    return parsed == null ? FlxColor.WHITE : parsed;
  }

  static function getSprite(state:PlayState, tag:String):Null<FlxSprite>
  {
    if (tag == null || !scriptVariables.exists(tag)) return null;
    var value:Dynamic = scriptVariables.get(tag);
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
        switch (rootName)
        {
          case "defaultCamZoom":
            state.currentCameraZoom = cast value;
            state.camGame.zoom = state.currentCameraZoom;
          case "cameraX":
            state.cameraFollowPoint.x = cast value;
          case "cameraY":
            state.cameraFollowPoint.y = cast value;
          case "score":
            state.songScore = cast value;
          case "misses":
            Highscore.tallies.missed = Std.int(value);
          case "hits":
            Highscore.tallies.totalNotesHit = Std.int(value);
          case "combo":
            Highscore.tallies.combo = Std.int(value);
          default:
            if (scriptVariables.exists(rootName))
              scriptVariables.set(rootName, value);
            else
              Reflect.setProperty(state, rootName, value);
        }
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
      case "strumLineNotes":
        return getAllStrumNotes(state);
      case "playerStrums":
        return state.playerStrumline == null ? [] : state.playerStrumline.strumlineNotes.members;
      case "opponentStrums":
        return state.opponentStrumline == null ? [] : state.opponentStrumline.strumlineNotes.members;
      case "boyfriend":
        return getStageCharacter(state, "getBoyfriend");
      case "dad", "opponent":
        return getStageCharacter(state, "getDad");
      case "gf", "girlfriend":
        return getStageCharacter(state, "getGirlfriend");
      case "FlxG", "flixel.FlxG":
        return FlxG;
      case "camFollow", "cameraFollowPoint":
        return state.cameraFollowPoint;
      case "cameraX":
        return state.cameraFollowPoint.x;
      case "cameraY":
        return state.cameraFollowPoint.y;
      case "defaultCamZoom":
        return state.currentCameraZoom;
      case "score":
        return state.songScore;
      case "misses":
        return Highscore.tallies.missed;
      case "hits":
        return Highscore.tallies.totalNotesHit;
      case "combo":
        return Highscore.tallies.combo;
      case "rating", "ratingPercent":
        return Highscore.tallies.totalNotes <= 0
          ? 0.0
          : Highscore.tallies.totalNotesHit / Highscore.tallies.totalNotes;
      default:
        if (scriptVariables.exists(name)) return scriptVariables.get(name);
        return Reflect.getProperty(state, name);
    }
  }

  static function getStageCharacter(state:PlayState, getter:String):Null<BaseCharacter>
  {
    var stage = state.currentStage;
    if (stage == null) return null;
    return switch (getter)
    {
      case "getBoyfriend": stage.getBoyfriend();
      case "getDad": stage.getDad();
      case "getGirlfriend": stage.getGirlfriend();
      default: null;
    }
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

  static function getAllStrumNotes(state:PlayState):Array<StrumlineNote>
  {
    var result:Array<StrumlineNote> = [];
    // Psych's combined strumLineNotes group is opponent receptors first,
    // followed by the player's receptors.
    if (state.opponentStrumline != null)
      for (note in state.opponentStrumline.strumlineNotes.members) result.push(note);
    if (state.playerStrumline != null)
      for (note in state.playerStrumline.strumlineNotes.members) result.push(note);
    return result;
  }

  static function getStrumNote(state:PlayState, index:Int):Null<StrumlineNote>
  {
    var notes:Array<StrumlineNote> = getAllStrumNotes(state);
    if (notes.length == 0) return null;
    var normalized:Int = index < 0 ? 0 : index % notes.length;
    return notes[normalized];
  }

  static function noteTween(state:PlayState, tag:String, noteIndex:Int, values:Dynamic, duration:Float, ease:String):Bool
  {
    var target:Null<StrumlineNote> = getStrumNote(state, noteIndex);
    if (target == null) return false;
    return startTweenTarget(tag, target, values, duration, ease, [tag]);
  }

  public static function getNoteId(state:PlayState, note:NoteSprite):Int
  {
    return getActiveNotes(state).indexOf(note);
  }

  public static function getNoteIdForHold(state:PlayState, holdNote:SustainTrail):Int
  {
    if (holdNote == null) return -1;
    var notes:Array<NoteSprite> = getActiveNotes(state);
    for (index in 0...notes.length)
    {
      var note:NoteSprite = notes[index];
      if (note.strumTime == holdNote.strumTime
        && note.direction == holdNote.noteDirection)
        return index;
    }
    return -1;
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
    if (collection == null || index < 0) return null;
    var members:Dynamic = Reflect.field(collection, "members");
    var count:Int = members != null ? members.length : collection.length;
    if (index >= count) return null;
    var item:Dynamic = members != null ? members[index] : collection[index];
    return getFromObject(item, path, allowMaps);
  }

  static function setPropertyFromGroup(state:PlayState, group:String, index:Int, path:String, value:Dynamic, allowMaps:Bool):Dynamic
  {
    var collection:Dynamic = resolveRoot(state, group);
    if (collection == null || index < 0) return null;
    var members:Dynamic = Reflect.field(collection, "members");
    var count:Int = members != null ? members.length : collection.length;
    if (index >= count) return null;
    var item:Dynamic = members != null ? members[index] : collection[index];
    return setOnObject(item, path, value, allowMaps);
  }

  public static function triggerEvent(state:PlayState, name:String, value1:String, value2:String):Void
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
      case "camera follow pos":
        if (value1 != null && value1.length > 0 && value2 != null && value2.length > 0)
        {
          var x:Float = parseFloatOr(value1, state.cameraFollowPoint.x);
          var y:Float = parseFloatOr(value2, state.cameraFollowPoint.y);
          state.cameraFollowPoint.setPosition(x, y);
        }
      case "play animation":
        var characterId:String = value2 == null || value2.length == 0 ? "bf" : value2.toLowerCase();
        if (characterId == "boyfriend" || characterId == "player") characterId = "bf";
        if (characterId == "opponent") characterId = "dad";
        if (state.currentStage != null)
        {
          var character:Null<BaseCharacter> = state.currentStage.getCharacter(characterId);
          if (character != null && value1 != null && value1.length > 0)
            character.playAnimation(value1, true);
        }
      case "hey!":
        var heyCharacter:String = value1 == null || value1.length == 0 ? "bf" : value1.toLowerCase();
        if (heyCharacter == "boyfriend" || heyCharacter == "player") heyCharacter = "bf";
        if (heyCharacter == "opponent") heyCharacter = "dad";
        if (state.currentStage != null)
        {
          var character:Null<BaseCharacter> = state.currentStage.getCharacter(heyCharacter);
          if (character != null && character.hasAnimation("hey"))
            character.playAnimation("hey", true);
        }
      case "set gf speed":
        var girlfriend:Null<BaseCharacter> = state.currentStage == null ? null : state.currentStage.getGirlfriend();
        var speed:Int = Std.int(parseFloatOr(value1, 1));
        if (girlfriend != null) girlfriend.danceEvery = Std.int(Math.max(1, speed));
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
