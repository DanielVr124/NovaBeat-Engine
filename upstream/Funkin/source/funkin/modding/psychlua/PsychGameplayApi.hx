package funkin.modding.psychlua;

import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import funkin.ui.freeplay.FreeplayState;
import funkin.play.cutscene.VideoCutscene;
import funkin.data.song.SongRegistry;
import funkin.play.song.Song;
import funkin.ui.transition.LoadingState;
import funkin.modding.ExperienceManager;
import funkin.modding.PsychModRuntime;
import funkin.modding.PsychModRuntime.PsychScriptSource;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.math.FlxPoint;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxAxes;
import openfl.display.BlendMode;
import flixel.util.FlxTimer;
import flixel.util.FlxSave;
#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end
import flixel.sound.FlxSound;
import funkin.Conductor;
import funkin.Paths;
import funkin.graphics.FunkinSprite;
import funkin.Assets;
import funkin.play.PlayState;
import funkin.play.PlayStatePlaylist;
import funkin.Highscore;
import funkin.Preferences;
import funkin.util.Constants;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.SustainTrail;
import funkin.play.character.BaseCharacter;
import funkin.data.character.CharacterData.CharacterDataParser;
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
  // [web-build] Compile the complete Psych 0.7.3 compatibility API on feature-branch changes.
  static final activeTweens:Map<String, FlxTween> = [];
  static final activeTimers:Map<String, FlxTimer> = [];
  static final scriptVariables:Map<String, Dynamic> = [];
  // Keep tags for objects transferred into a custom substate so their stale
  // script-variable references can be released when that substate closes.
  static final customSubstateObjects:Map<String, FlxSprite> = [];
  static final activeSounds:Map<String, FlxSound> = [];
  static final activeSaves:Map<String, FlxSave> = [];
  #if (!flash && sys)
  static final runtimeShaderSources:Map<String, Array<String>> = [];
  #end
  static final preloadedCharacters:Map<String, BaseCharacter> = [];
  static var activeTimeBar:Null<PsychTimeBar> = null;
  static var activeDialogue:Null<PsychDialogueOverlay> = null;
  static var activeCustomSubstate:Null<PsychCustomSubState> = null;
  static var nextSoundTag:Int = 0;
  static var psychCurrentSection:Int = 0;
  static var psychHasSectionMarkers:Bool = false;
  static var psychMustHitSection:Bool = false;
  static var psychAltAnim:Bool = false;
  static var psychGFSection:Bool = false;

  public static function setPsychSectionState(section:Int, mustHit:Bool, altAnimation:Bool, gfSection:Bool):Void
  {
    psychCurrentSection = Std.int(Math.max(0, section));
    psychHasSectionMarkers = true;
    psychMustHitSection = mustHit;
    psychAltAnim = altAnimation;
    psychGFSection = gfSection;
    PsychScriptRuntime.setGlobal("curSection", getCurrentPsychSection());
    PsychScriptRuntime.setGlobal("mustHitSection", psychMustHitSection);
    PsychScriptRuntime.setGlobal("altAnim", psychAltAnim);
    PsychScriptRuntime.setGlobal("gfSection", psychGFSection);
  }

  public static function getCurrentPsychSection():Int
  {
    return psychHasSectionMarkers
      ? psychCurrentSection
      : Std.int(Math.floor(Conductor.instance.currentStep / 16));
  }

  public static function hasPsychSectionMarkers():Bool
  {
    return psychHasSectionMarkers;
  }

  static function initializePsychSectionState(state:PlayState):Void
  {
    if (state == null || state.currentChart == null) return;
    var rawEvents:Dynamic = Reflect.field(state.currentChart, "events");
    if (!Std.isOfType(rawEvents, Array)) return;

    var firstMarker:Dynamic = null;
    var bestMarker:Dynamic = null;
    var bestTime:Float = -1.0e30;
    var songPosition:Float = Conductor.instance.songPosition;
    for (event in (cast rawEvents:Array<Dynamic>))
    {
      if (event == null || Reflect.field(event, "eventKind") != "PsychCompatibilityEvent") continue;
      var value:Dynamic = Reflect.field(event, "value");
      if (value == null || Reflect.field(value, "name") != "__PsychSectionState") continue;
      if (firstMarker == null) firstMarker = event;
      var eventTime:Float = Std.parseFloat(Std.string(Reflect.field(event, "time")));
      if (!Math.isNaN(eventTime) && eventTime <= songPosition && eventTime >= bestTime)
      {
        bestMarker = event;
        bestTime = eventTime;
      }
    }

    var selected:Dynamic = bestMarker == null ? firstMarker : bestMarker;
    if (selected == null) return;
    var selectedValue:Dynamic = Reflect.field(selected, "value");
    psychCurrentSection = Std.int(Reflect.field(selectedValue, "curSection"));
    psychHasSectionMarkers = true;
    psychMustHitSection = Reflect.field(selectedValue, "mustHitSection") == true;
    psychAltAnim = Reflect.field(selectedValue, "altAnim") == true;
    psychGFSection = Reflect.field(selectedValue, "gfSection") == true;
  }

  public static function createGlobals(state:PlayState):Map<String, Dynamic>
  {
    var vars:Map<String, Dynamic> = [];
    psychCurrentSection = 0;
    psychHasSectionMarkers = false;
    psychMustHitSection = false;
    psychAltAnim = false;
    psychGFSection = false;
    initializePsychSectionState(state);

    ensureTimeBar(state);
    if (activeTimeBar != null)
    {
      vars.set("timeBar", activeTimeBar);
      vars.set("timeTxt", activeTimeBar.timeText);
      vars.set("timeBarType", activeTimeBar.timeBarType);
    }

    vars.set("close", function(?_ignoreSelf:Bool = false):Bool return PsychScriptRuntime.closeCurrentScript());

    vars.set("getProperty", function(path:String, ?allowMaps:Bool = false):Dynamic return getProperty(state, path, allowMaps));
    vars.set("setProperty", function(path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic return setProperty(state, path, value, allowMaps));
    // Psych exposes explicit helpers for objects created by makeLuaSprite /
    // makeLuaText. These use the same tag table as getProperty/setProperty.
    vars.set("getPropertyLuaSprite", function(tag:String, property:String):Dynamic
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      return sprite == null ? null : getFromObject(sprite, property, false);
    });
    vars.set("setPropertyLuaSprite", function(tag:String, property:String, value:Dynamic):Dynamic
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      return sprite == null ? null : setOnObject(sprite, property, value, false);
    });
    vars.set("getPropertyFromClass", function(className:String, path:String, ?allowMaps:Bool = false):Dynamic
      return getPropertyFromClass(className, path, allowMaps));
    vars.set("setPropertyFromClass", function(className:String, path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
      return setPropertyFromClass(className, path, value, allowMaps));
    vars.set("getPropertyFromGroup", function(group:String, index:Int, path:String, ?allowMaps:Bool = false):Dynamic
      return getPropertyFromGroup(state, group, index, path, allowMaps));
    vars.set("setPropertyFromGroup", function(group:String, index:Int, path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
      return setPropertyFromGroup(state, group, index, path, value, allowMaps));
    vars.set("removeFromGroup", function(group:String, index:Int, ?dontDestroy:Bool = false):Bool
      return removeFromGroup(state, group, index, dontDestroy));

    vars.set("setVar", function(name:String, value:Dynamic):Dynamic
    {
      scriptVariables.set(name, value);
      return value;
    });
    vars.set("getVar", function(name:String):Dynamic return scriptVariables.get(name));
    vars.set("removeVar", function(name:String):Bool return scriptVariables.remove(name));

    vars.set("initSaveData", function(name:String, ?folder:String = "psychenginemods"):Bool
      return initSaveData(name, folder));
    vars.set("flushSaveData", function(name:String):Bool
    {
      var save:Null<FlxSave> = activeSaves.get(getSaveDataKey(name));
      if (save == null) return false;
      save.flush();
      return true;
    });
    vars.set("getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null):Dynamic
    {
      var save:Null<FlxSave> = activeSaves.get(getSaveDataKey(name));
      if (save == null || field == null || field.length == 0) return defaultValue;
      return Reflect.hasField(save.data, field) ? Reflect.field(save.data, field) : defaultValue;
    });
    vars.set("setDataFromSave", function(name:String, field:String, value:Dynamic):Bool
    {
      var save:Null<FlxSave> = activeSaves.get(getSaveDataKey(name));
      if (save == null || field == null || field.length == 0) return false;
      Reflect.setField(save.data, field, value);
      return true;
    });
    vars.set("eraseSaveData", function(name:String):Bool
    {
      var save:Null<FlxSave> = activeSaves.get(getSaveDataKey(name));
      if (save == null) return false;
      save.erase();
      activeSaves.remove(getSaveDataKey(name));
      return true;
    });
    vars.set("getModSetting", function(saveTag:String, ?modName:String = null):Dynamic
      return PsychModRuntime.getModSetting(saveTag, modName));

    vars.set("playSound", function(sound:String, ?volume:Float = 1, ?tag:String = ""):Bool
      return playTaggedSound(sound, volume, tag));
    vars.set("playMusic", function(music:String, ?volume:Float = 1, ?looped:Bool = false):Bool
      return playModMusic(music, volume, looped));
    vars.set("stopSound", function(?tag:String = ""):Void stopTaggedSound(tag));
    vars.set("pauseSound", function(?tag:String = ""):Void pauseTaggedSound(tag));
    vars.set("resumeSound", function(?tag:String = ""):Void resumeTaggedSound(tag));
    vars.set("setSoundVolume", function(tag:String, volume:Float):Bool return setTaggedSoundVolume(tag, volume));
    vars.set("getSoundVolume", function(?tag:String = ""):Float
    {
      if (tag == null || tag.length == 0)
        return FlxG.sound.music == null ? 0 : FlxG.sound.music.volume;
      var sound:Null<FlxSound> = activeSounds.get(tag);
      return sound == null ? 0 : sound.volume;
    });
    vars.set("getSoundTime", function(tag:String):Float
    {
      var sound:Null<FlxSound> = activeSounds.get(tag);
      return sound == null ? 0 : sound.time;
    });
    vars.set("setSoundTime", function(tag:String, value:Float):Bool
    {
      var sound:Null<FlxSound> = activeSounds.get(tag);
      if (sound == null) return false;
      var wasPlaying:Bool = sound.playing;
      sound.pause();
      sound.time = Math.max(0, value);
      if (wasPlaying) sound.play();
      return true;
    });
    vars.set("getSoundPitch", function(tag:String):Float
    {
      // Psych only exposes pitch for tagged modchart sounds, not global music.
      if (tag == null || tag.length == 0) return 0;
      var sound:Null<FlxSound> = activeSounds.get(tag);
      return sound == null ? 0 : sound.pitch;
    });
    vars.set("setSoundPitch", function(tag:String, value:Float, ?doPause:Bool = false):Bool
    {
      if (tag == null || tag.length == 0) return false;
      var sound:Null<FlxSound> = activeSounds.get(tag);
      if (sound == null) return false;
      var wasPlaying:Bool = sound.playing;
      if (doPause) sound.pause();
      sound.pitch = value;
      if (doPause && wasPlaying) sound.play();
      return true;
    });

    vars.set("soundFadeIn", function(tag:String, duration:Float, ?fromValue:Float = 0, ?toValue:Float = 1):Bool
    {
      var sound:Null<FlxSound> = resolveSound(tag);
      if (sound == null || duration < 0) return false;
      sound.fadeIn(duration, fromValue, toValue);
      return true;
    });
    vars.set("soundFadeOut", function(tag:String, duration:Float, ?toValue:Float = 0):Bool
    {
      var sound:Null<FlxSound> = resolveSound(tag);
      if (sound == null || duration < 0) return false;
      sound.fadeOut(duration, toValue);
      return true;
    });
    vars.set("soundFadeCancel", function(tag:String):Bool
    {
      var sound:Null<FlxSound> = resolveSound(tag);
      if (sound == null || sound.fadeTween == null) return false;
      sound.fadeTween.cancel();
      sound.fadeTween = null;
      return true;
    });

    // Precache helpers intentionally resolve through NovaBeat's asset paths.
    // The mod loader still requires a native installed-mod filesystem.
    vars.set("precacheImage", function(name:String, ?allowGPU:Bool = true):Bool
    {
      if (name == null || name.length == 0) return false;
      try
      {
        FlxG.bitmap.add(Paths.image(name));
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] precacheImage(' + name + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("precacheSound", function(name:String):Bool
    {
      if (name == null || name.length == 0) return false;
      try
      {
        FlxG.sound.cache(Paths.sound(name));
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] precacheSound(' + name + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("precacheMusic", function(name:String):Bool
    {
      if (name == null || name.length == 0) return false;
      try
      {
        FlxG.sound.cache(Paths.music(name));
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] precacheMusic(' + name + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("setHealthBarColors", function(left:Dynamic, right:Dynamic):Bool
    {
      if (state.healthBar == null) return false;
      // NovaBeat's current health bar is a two-color filled bar rather than
      // Psych's player/opponent split bar. Keep the API useful, but make the
      // visual mapping explicit: left=empty/background, right=filled.
      state.healthBar.createFilledBar(parsePsychColor(left), parsePsychColor(right));
      state.healthBar.updateBar();
      return true;
    });
    vars.set("setTimeBarColors", function(left:Dynamic, right:Dynamic):Bool
    {
      if (activeTimeBar == null || !activeTimeBar.exists) return false;
      activeTimeBar.setColors(left, right);
      return true;
    });
    vars.set("startDialogue", function(dialogueFile:String, ?music:String = null):Bool
      return startPsychDialogue(state, dialogueFile, music));
    vars.set("stopMusic", function():Void
    {
      if (FlxG.sound.music != null) FlxG.sound.music.stop();
    });

    vars.set("getSongPosition", function():Float return Conductor.instance.songPosition);
    // Common Psych convenience functions. These mirror direct PlayState
    // access while keeping scripts independent of the engine's field layout.
    vars.set("getHealth", function():Float return state.health);
    vars.set("setHealth", function(?value:Float = 1):Void state.health = value);
    vars.set("addHealth", function(?value:Float = 0):Void state.health += value);
    vars.set("getSongName", function():String return state.currentSong == null ? "" : state.currentSong.songName);
    vars.set("getDifficulty", function():String return state.currentDifficulty);
    vars.set("getSongLength", function():Float return state.currentSongLengthMs);
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
    vars.set("keyJustPressed", function(?name:String = ""):Bool return noteKeyStatus(state, name, "justPressed"));
    vars.set("keyPressed", function(?name:String = ""):Bool return noteKeyStatus(state, name, "pressed"));
    vars.set("keyReleased", function(?name:String = ""):Bool return noteKeyStatus(state, name, "justReleased"));
    vars.set("gamepadJustPressed", function(id:Int, name:String):Bool return gamepadButtonStatus(id, name, "justPressed"));
    vars.set("gamepadPressed", function(id:Int, name:String):Bool return gamepadButtonStatus(id, name, "pressed"));
    vars.set("gamepadReleased", function(id:Int, name:String):Bool return gamepadButtonStatus(id, name, "justReleased"));
    vars.set("stringStartsWith", function(value:String, prefix:String):Bool
      return value != null && prefix != null && StringTools.startsWith(value, prefix));
    vars.set("stringEndsWith", function(value:String, suffix:String):Bool
      return value != null && suffix != null && StringTools.endsWith(value, suffix));
    vars.set("stringSplit", function(value:String, separator:String):Array<String>
      return value == null || separator == null || separator.length == 0 ? (value == null ? [] : [value]) : value.split(separator));
    vars.set("stringTrim", function(value:String):String return value == null ? "" : StringTools.trim(value));

    vars.set("initLuaShader", function(name:String, ?glslVersion:Int = 120):Bool return initLuaShader(name, glslVersion));
    vars.set("setSpriteShader", function(objectPath:String, shaderName:String):Bool return setSpriteShader(state, objectPath, shaderName));
    vars.set("removeSpriteShader", function(objectPath:String):Bool return removeSpriteShader(state, objectPath));
    #if (!flash && sys)
    vars.set("getShaderBool", function(objectPath:String, property:String):Dynamic return getRuntimeShader(state, objectPath)?.getBool(property));
    vars.set("getShaderBoolArray", function(objectPath:String, property:String):Dynamic return getRuntimeShader(state, objectPath)?.getBoolArray(property));
    vars.set("getShaderInt", function(objectPath:String, property:String):Dynamic return getRuntimeShader(state, objectPath)?.getInt(property));
    vars.set("getShaderIntArray", function(objectPath:String, property:String):Dynamic return getRuntimeShader(state, objectPath)?.getIntArray(property));
    vars.set("getShaderFloat", function(objectPath:String, property:String):Dynamic return getRuntimeShader(state, objectPath)?.getFloat(property));
    vars.set("getShaderFloatArray", function(objectPath:String, property:String):Dynamic return getRuntimeShader(state, objectPath)?.getFloatArray(property));
    vars.set("setShaderBool", function(objectPath:String, property:String, value:Bool):Bool
    {
      var shader = getRuntimeShader(state, objectPath);
      if (shader == null) return false;
      shader.setBool(property, value);
      return true;
    });
    vars.set("setShaderBoolArray", function(objectPath:String, property:String, values:Dynamic):Bool
    {
      var shader = getRuntimeShader(state, objectPath);
      if (shader == null) return false;
      shader.setBoolArray(property, values);
      return true;
    });
    vars.set("setShaderInt", function(objectPath:String, property:String, value:Int):Bool
    {
      var shader = getRuntimeShader(state, objectPath);
      if (shader == null) return false;
      shader.setInt(property, value);
      return true;
    });
    vars.set("setShaderIntArray", function(objectPath:String, property:String, values:Dynamic):Bool
    {
      var shader = getRuntimeShader(state, objectPath);
      if (shader == null) return false;
      shader.setIntArray(property, values);
      return true;
    });
    vars.set("setShaderFloat", function(objectPath:String, property:String, value:Float):Bool
    {
      var shader = getRuntimeShader(state, objectPath);
      if (shader == null) return false;
      shader.setFloat(property, value);
      return true;
    });
    vars.set("setShaderFloatArray", function(objectPath:String, property:String, values:Dynamic):Bool
    {
      var shader = getRuntimeShader(state, objectPath);
      if (shader == null) return false;
      shader.setFloatArray(property, values);
      return true;
    });
    vars.set("setShaderSampler2D", function(objectPath:String, property:String, imagePath:String):Bool
    {
      var shader:Dynamic = getRuntimeShader(state, objectPath);
      if (shader == null || imagePath == null || imagePath.length == 0) return false;
      var graphic = FlxG.bitmap.add(Paths.image(imagePath));
      if (graphic == null || graphic.bitmap == null) return false;
      // The pinned flixel-addons release may not expose setSampler2D().
      // Its ShaderInput objects are still available through the OpenFL shader
      // data map, so update the input directly without depending on that helper.
      var shaderData:Dynamic = Reflect.field(shader, "data");
      if (shaderData == null) return false;
      var shaderInput:Dynamic = Reflect.field(shaderData, property);
      if (shaderInput == null) return false;
      Reflect.setField(shaderInput, "input", graphic.bitmap);
      return true;
    });
    #else
    vars.set("getShaderBool", function(objectPath:String, property:String):Dynamic return null);
    vars.set("getShaderBoolArray", function(objectPath:String, property:String):Dynamic return null);
    vars.set("getShaderInt", function(objectPath:String, property:String):Dynamic return null);
    vars.set("getShaderIntArray", function(objectPath:String, property:String):Dynamic return null);
    vars.set("getShaderFloat", function(objectPath:String, property:String):Dynamic return null);
    vars.set("getShaderFloatArray", function(objectPath:String, property:String):Dynamic return null);
    vars.set("setShaderBool", function(objectPath:String, property:String, value:Bool):Bool return false);
    vars.set("setShaderBoolArray", function(objectPath:String, property:String, values:Dynamic):Bool return false);
    vars.set("setShaderInt", function(objectPath:String, property:String, value:Int):Bool return false);
    vars.set("setShaderIntArray", function(objectPath:String, property:String, values:Dynamic):Bool return false);
    vars.set("setShaderFloat", function(objectPath:String, property:String, value:Float):Bool return false);
    vars.set("setShaderFloatArray", function(objectPath:String, property:String, values:Dynamic):Bool return false);
    vars.set("setShaderSampler2D", function(objectPath:String, property:String, imagePath:String):Bool return false);
    #end

    vars.set("checkFileExists", function(path:String, ?absolute:Bool = false):Bool
    {
      if (absolute) return false;
      if (PsychModRuntime.getModFile(path) != null) return true;
      try return Assets.exists(Paths.file(path)) catch (error:Dynamic) return false;
    });
    vars.set("getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false):Dynamic
    {
      if (path == null || path.length == 0) return null;
      if (!ignoreModFolders)
      {
        var file:Null<PsychScriptSource> = PsychModRuntime.getModFile(path);
        if (file != null) return file.source;
      }
      try
      {
        var assetPath:String = Paths.file(path);
        return Assets.exists(assetPath) ? Assets.getText(assetPath) : null;
      }
      catch (error:Dynamic)
      {
        return null;
      }
    });
    vars.set("saveFile", function(path:String, content:String, ?absolute:Bool = false):Bool
      return !absolute && PsychModRuntime.saveModFile(path, content));
    vars.set("deleteFile", function(path:String, ?ignoreModFolders:Bool = false):Bool
      return !ignoreModFolders && PsychModRuntime.deleteModFile(path));
    vars.set("directoryFileList", function(path:String):Array<String>
      return PsychModRuntime.listModDirectory(path));
 
    vars.set("callMethod", function(methodPath:String, ?args:Array<Dynamic> = null):Dynamic
      return callSafeMethod(state, methodPath, parseInstanceArguments(state, args)));
    vars.set("callMethodFromClass", function(className:String, methodPath:String, ?args:Array<Dynamic> = null):Dynamic
      return callSafeClassMethod(className, methodPath, parseInstanceArguments(state, args)));
    vars.set("createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic> = null):Bool
      return createSafeInstance(variableToSave, className, args));
    vars.set("addInstance", function(objectName:String, ?inFront:Bool = false):Bool
      return addSafeInstance(state, objectName, inFront));
    vars.set("instanceArg", function(instanceName:String, ?className:String = null):String
    {
      if (instanceName == null || instanceName.length == 0) return "";
      var token:String = "##PSYCHLUA_STRINGTOOBJ::" + instanceName;
      if (className != null && className.length > 0) token += "::" + className;
      return token;
    });

    // Psych's Animate helpers use NovaBeat's existing FunkinSprite atlas renderer.
    // Texture files are resolved through the active Polymod asset set.
    vars.set("makeFlxAnimateSprite", function(tag:String, ?x:Float = 0, ?y:Float = 0, ?loadFolder:String = null):Bool
    {
      if (tag == null || StringTools.trim(tag).length == 0) return false;
      var normalizedTag:String = StringTools.replace(tag, ".", "");
      var previous:Null<FlxSprite> = getSprite(state, normalizedTag);
      if (previous != null)
      {
        // addLuaSprite() stores stage sprites inside currentStage. Remove a
        // replaced Animate sprite from its actual parent before destroying it;
        // otherwise the stage keeps drawing a destroyed FlxAnimate on retry.
        removeFromParent(state, previous);
        previous.destroy();
        scriptVariables.remove(normalizedTag);
      }

      var sprite:PsychAnimateSprite = new PsychAnimateSprite(x, y);
      if (loadFolder != null && StringTools.trim(loadFolder).length > 0
        && !loadPsychAnimateAtlas(sprite, loadFolder))
      {
        sprite.destroy();
        return false;
      }
      scriptVariables.set(normalizedTag, sprite);
      return true;
    });
    vars.set("loadAnimateAtlas", function(tag:String, folderOrImg:Dynamic, ?spriteJson:Dynamic = null, ?animationJson:Dynamic = null):Bool
    {
      var sprite:Null<PsychAnimateSprite> = getPsychAnimateSprite(state, tag);
      return sprite != null && loadPsychAnimateAtlas(sprite, folderOrImg, spriteJson, animationJson);
    });
    vars.set("addAnimationBySymbol", function(tag:String, name:String, symbol:String,
        ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0):Bool
    {
      var sprite:Null<PsychAnimateSprite> = getPsychAnimateSprite(state, tag);
      if (sprite == null || !sprite.psychAtlasLoaded || name == null || symbol == null) return false;
      try
      {
        sprite.anim.addBySymbol(name, symbol, framerate, loop);
        sprite.addOffset(name, matX, matY);
        if (sprite.getCurrentAnimation().length == 0) sprite.playPsychAnimation(name, true);
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] addAnimationBySymbol(' + tag + ', ' + symbol + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("addAnimationBySymbolIndices", function(tag:String, name:String, symbol:String, ?indices:Dynamic = null,
        ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0):Bool
    {
      var sprite:Null<PsychAnimateSprite> = getPsychAnimateSprite(state, tag);
      if (sprite == null || !sprite.psychAtlasLoaded || name == null || symbol == null) return false;
      var parsedIndices:Array<Int> = parsePsychAnimateIndices(indices);
      if (parsedIndices.length == 0) parsedIndices = [0];
      try
      {
        sprite.anim.addBySymbolIndices(name, symbol, parsedIndices, framerate, loop);
        sprite.addOffset(name, matX, matY);
        if (sprite.getCurrentAnimation().length == 0) sprite.playPsychAnimation(name, true);
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] addAnimationBySymbolIndices(' + tag + ', ' + symbol + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("getMidpointX", function(variable:String):Float
    {
      var object:Dynamic = getProperty(state, variable);
      if (!Std.isOfType(object, FlxObject)) return 0.0;
      var midpoint:FlxPoint = (cast object:FlxObject).getMidpoint();
      return midpoint.x;
    });
    vars.set("getMidpointY", function(variable:String):Float
    {
      var object:Dynamic = getProperty(state, variable);
      if (!Std.isOfType(object, FlxObject)) return 0.0;
      var midpoint:FlxPoint = (cast object:FlxObject).getMidpoint();
      return midpoint.y;
    });
    vars.set("getGraphicMidpointX", function(variable:String):Float
    {
      var object:Dynamic = getProperty(state, variable);
      if (!Std.isOfType(object, FlxSprite)) return 0.0;
      var midpoint:FlxPoint = (cast object:FlxSprite).getGraphicMidpoint();
      return midpoint.x;
    });
    vars.set("getGraphicMidpointY", function(variable:String):Float
    {
      var object:Dynamic = getProperty(state, variable);
      if (!Std.isOfType(object, FlxSprite)) return 0.0;
      var midpoint:FlxPoint = (cast object:FlxSprite).getGraphicMidpoint();
      return midpoint.y;
    });
    vars.set("getScreenPositionX", function(variable:String, ?camera:String = "game"):Float
    {
      var object:Dynamic = getProperty(state, variable);
      if (!Std.isOfType(object, FlxObject)) return 0.0;
      var position:FlxPoint = (cast object:FlxObject).getScreenPosition(resolveCamera(state, camera));
      return position.x;
    });
    vars.set("getScreenPositionY", function(variable:String, ?camera:String = "game"):Float
    {
      var object:Dynamic = getProperty(state, variable);
      if (!Std.isOfType(object, FlxObject)) return 0.0;
      var position:FlxPoint = (cast object:FlxObject).getScreenPosition(resolveCamera(state, camera));
      return position.y;
    });
    vars.set("getColorFromHex", function(color:String):Int return parsePsychColor(color));
    vars.set("addScore", function(value:Int):Void setProperty(state, "score", state.songScore + value));
    vars.set("setScore", function(value:Int):Void setProperty(state, "score", value));
    vars.set("addMisses", function(value:Int):Void setProperty(state, "misses", Highscore.tallies.missed + value));
    vars.set("setMisses", function(value:Int):Void setProperty(state, "misses", value));
    vars.set("addHits", function(value:Int):Void setProperty(state, "hits", Highscore.tallies.totalNotesHit + value));
    vars.set("setHits", function(value:Int):Void setProperty(state, "hits", value));

    // Psych 0.7.x exposes read helpers as well as setters for song tallies.
    vars.set("getScore", function():Int return Std.int(state.songScore));
    vars.set("getMisses", function():Int return Highscore.tallies.missed);
    vars.set("getHits", function():Int return Highscore.tallies.totalNotesHit);
    vars.set("getColorFromName", function(name:String):Int return parsePsychColor(name));
    vars.set("getColorFromString", function(value:String):Int return parsePsychColor(value));
    vars.set("FlxColor", PsychScriptInstance.createFlxColorApi());

    // Cross-script helpers and runtime script management.
    vars.set("callScript", function(script:String, callback:String, ?args:Array<Dynamic>):Dynamic
      return PsychScriptRuntime.callScript(script, callback, args));
    vars.set("getGlobalFromScript", function(script:String, name:String):Dynamic
      return PsychScriptRuntime.getGlobalFromScript(script, name));
    vars.set("setGlobalFromScript", function(script:String, name:String, value:Dynamic):Bool
      return PsychScriptRuntime.setGlobalFromScript(script, name, value));
    vars.set("getGlobals", function(script:String):Dynamic return PsychScriptRuntime.getScriptGlobals(script));
    vars.set("isRunning", function(script:String):Bool return PsychScriptRuntime.isScriptRunning(script));
    vars.set("addLuaScript", function(script:String, ?ignoreAlreadyRunning:Bool = false):Bool
      return PsychScriptRuntime.addScript(script, "lua", ignoreAlreadyRunning));
    vars.set("addHScript", function(script:String, ?ignoreAlreadyRunning:Bool = false):Bool
      return PsychScriptRuntime.addScript(script, "hscript", ignoreAlreadyRunning));
    vars.set("removeLuaScript", function(script:String):Bool return PsychScriptRuntime.removeScript(script, "lua"));
    vars.set("removeHScript", function(script:String):Bool return PsychScriptRuntime.removeScript(script, "hscript"));

    // Character position and camera focus helpers use NovaBeat's actual stage
    // characters. They do not create substitute characters or fake group data.
    vars.set("addCharacterToList", function(name:String, ?role:String = "bf"):Bool
    {
      if (name == null || StringTools.trim(name).length == 0) return false;
      var normalized:String = StringTools.trim(name);
      var existing:Null<BaseCharacter> = preloadedCharacters.get(normalized);
      if (existing != null && existing.exists) return true;

      // Constructing a character is the engine's actual asset preload path.
      // This deliberately does not replace the active BF/DAD/GF; character
      // swapping needs a full stage/health-icon transaction and is not faked.
      try
      {
        var character:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(normalized, true);
        if (character == null) return false;
        character.visible = false;
        character.active = false;
        preloadedCharacters.set(normalized, character);
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] addCharacterToList(' + normalized + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("getCharacterX", function(role:String):Float
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      return character == null ? 0 : character.x;
    });
    vars.set("getCharacterY", function(role:String):Float
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      return character == null ? 0 : character.y;
    });
    vars.set("setCharacterX", function(role:String, value:Float):Bool
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      if (character == null) return false;
      character.x = value;
      return true;
    });
    vars.set("setCharacterY", function(role:String, value:Float):Bool
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      if (character == null) return false;
      character.y = value;
      return true;
    });
    vars.set("cameraSetTarget", function(role:String):Bool
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      if (character == null || character.cameraFocusPoint == null) return false;
      state.tweenCameraToPosition(character.cameraFocusPoint.x, character.cameraFocusPoint.y, 0);
      var normalizedRole:String = switch (StringTools.trim(role).toLowerCase())
      {
        case "gf", "girlfriend": "gf";
        case "dad", "opponent": "dad";
        default: "boyfriend";
      };
      PsychScriptRuntime.dispatch("onMoveCamera", [normalizedRole]);
      return true;
    });
    vars.set("startCountdown", function():Bool
    {
      state.startCountdown();
      return true;
    });
    vars.set("endSong", function():Bool
    {
      state.endSong();
      return true;
    });
    vars.set("restartSong", function(?skipTransition:Bool = false):Bool
    {
      // PlayState preserves its launch parameters for a state reset.
      FlxG.resetState();
      return true;
    });
    vars.set("loadSong", function(?name:String = null, ?difficultyNum:Int = -1):Bool
    {
      if (name == null || StringTools.trim(name).length == 0)
        name = state.currentSong == null ? "" : state.currentSong.id;
      if (name == null || name.length == 0) return false;

      var normalizedName:String = psychSongSlug(name);
      var targetId:String = "";
      var currentId:String = state.currentSong == null ? "" : state.currentSong.id;
      if (normalizedName == psychSongSlug(currentId)
        || (state.currentSong != null && normalizedName == psychSongSlug(state.currentSong.songName)))
      {
        targetId = currentId;
      }
      else
      {
        var matches:Array<String> = [];
        for (songId in PsychModRuntime.collectSongIds(ExperienceManager.getActivePsychModDirs()))
        {
          if ((psychSongSlug(songId) == normalizedName || StringTools.endsWith(psychSongSlug(songId), "-" + normalizedName))
            && !matches.contains(songId))
            matches.push(songId);
        }
        if (matches.length != 1)
        {
          trace('[Psych API] loadSong could not resolve an unambiguous active Psych song: ' + name);
          return false;
        }
        targetId = matches[0];
      }

      var targetSong:Null<Song> = SongRegistry.instance.fetchEntry(targetId);
      if (targetSong == null) return false;

      var variation:String = targetSong.variations.contains(state.currentVariation)
        ? state.currentVariation
        : Constants.DEFAULT_VARIATION;
      var availableDifficulties:Array<String> = targetSong.listDifficulties(variation);
      if (availableDifficulties.length == 0) return false;

      var targetDifficulty:String = "";
      if (difficultyNum >= 0)
      {
        var standardDifficulties:Array<String> = ["easy", "normal", "hard"];
        var preferred:String = difficultyNum < standardDifficulties.length
          ? standardDifficulties[difficultyNum]
          : "";
        for (candidate in availableDifficulties)
          if (candidate.toLowerCase() == preferred) targetDifficulty = candidate;

        // Older Psych charts can define additional numbered difficulties.
        if (targetDifficulty.length == 0 && difficultyNum < availableDifficulties.length)
          targetDifficulty = availableDifficulties[difficultyNum];
      }
      else if (availableDifficulties.contains(state.currentDifficulty))
      {
        targetDifficulty = state.currentDifficulty;
      }
      else
      {
        for (candidate in availableDifficulties)
          if (candidate.toLowerCase() == "normal") targetDifficulty = candidate;
        if (targetDifficulty.length == 0) targetDifficulty = availableDifficulties[0];
      }

      if (targetSong.getDifficulty(targetDifficulty, variation) == null) return false;
      LoadingState.loadPlayState({
        targetSong: targetSong,
        targetDifficulty: targetDifficulty,
        targetVariation: variation,
        targetInstrumental: "",
        practiceMode: state.isPracticeMode,
        botPlayMode: state.isBotPlayMode,
        minimalMode: state.isMinimalMode,
        playbackRate: state.playbackRate
      }, true);
      return true;
    });

    vars.set("exitSong", function(?skipTransition:Bool = false):Bool
    {
      if (skipTransition)
      {
        FlxTransitionableState.skipNextTransIn = true;
        FlxTransitionableState.skipNextTransOut = true;
      }
      FlxG.sound.playMusic(Paths.music("freakyMenu"), 1, true);
      FlxG.switchState(() -> funkin.ui.freeplay.FreeplayState.buildForActiveExperience(null));
      return true;
    });
    vars.set("startVideo", function(videoFile:String):Bool
    {
      if (videoFile == null || StringTools.trim(videoFile).length == 0) return false;
      try
      {
        var requestedPath:String = StringTools.trim(videoFile);
        var songId:String = PlayState.instance == null || PlayState.instance.currentSong == null
          ? ""
          : PlayState.instance.currentSong.id;
        var modVideoPath:Null<String> = PsychModRuntime.resolvePsychVideoPath(songId, requestedPath);
        VideoCutscene.play(modVideoPath ?? Paths.videos(requestedPath));
        return true;
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] startVideo(' + videoFile + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("setRatingPercent", function(value:Float):Void PsychScriptRuntime.setGlobal("ratingPercent", value));
    vars.set("setRatingName", function(value:String):Void PsychScriptRuntime.setGlobal("ratingName", value));
    vars.set("setRatingFC", function(value:String):Void PsychScriptRuntime.setGlobal("ratingFC", value));
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
    vars.set("callOnScripts", function(name:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false,
        ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Bool
    {
      var exclusions:Array<String> = excludeScripts == null ? [] : excludeScripts.copy();
      var current:String = PsychScriptRuntime.getExecutingScriptPath();
      if (ignoreSelf && current.length > 0 && !exclusions.contains(current)) exclusions.push(current);
      PsychScriptRuntime.callOnScripts(name, args, ignoreStops, exclusions, excludeValues);
      return true;
    });
    vars.set("callOnLuas", function(name:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false,
        ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Bool
    {
      var exclusions:Array<String> = excludeScripts == null ? [] : excludeScripts.copy();
      var current:String = PsychScriptRuntime.getExecutingScriptPath();
      if (ignoreSelf && current.length > 0 && !exclusions.contains(current)) exclusions.push(current);
      PsychScriptRuntime.callOnLuas(name, args, ignoreStops, exclusions, excludeValues);
      return true;
    });
    vars.set("callOnHScript", function(name:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false,
        ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Bool
    {
      var exclusions:Array<String> = excludeScripts == null ? [] : excludeScripts.copy();
      var current:String = PsychScriptRuntime.getExecutingScriptPath();
      if (ignoreSelf && current.length > 0 && !exclusions.contains(current)) exclusions.push(current);
      PsychScriptRuntime.callOnHScript(name, args, ignoreStops, exclusions, excludeValues);
      return true;
    });
    vars.set("setOnScripts", function(name:String, value:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null):Void
    {
      var ignored:Array<String> = exclusions == null ? [] : exclusions.copy();
      var current:String = PsychScriptRuntime.getExecutingScriptPath();
      if (ignoreSelf && current.length > 0 && !ignored.contains(current)) ignored.push(current);
      PsychScriptRuntime.setOnScripts(name, value, ignored);
    });
    vars.set("setOnLuas", function(name:String, value:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null):Void
    {
      var ignored:Array<String> = exclusions == null ? [] : exclusions.copy();
      var current:String = PsychScriptRuntime.getExecutingScriptPath();
      if (ignoreSelf && current.length > 0 && !ignored.contains(current)) ignored.push(current);
      PsychScriptRuntime.setOnLuas(name, value, ignored);
    });
    vars.set("setOnHScript", function(name:String, value:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null):Void
    {
      var ignored:Array<String> = exclusions == null ? [] : exclusions.copy();
      var current:String = PsychScriptRuntime.getExecutingScriptPath();
      if (ignoreSelf && current.length > 0 && !ignored.contains(current)) ignored.push(current);
      PsychScriptRuntime.setOnHScript(name, value, ignored);
    });

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
    vars.set("noteTweenDirection", function(tag:String, note:Int, value:Float, duration:Float, ?ease:String = "linear"):Bool
      return noteTween(state, tag, note, {angle: value}, duration, ease));
    vars.set("startTween", function(tag:String, objectTag:String, values:Dynamic, duration:Float, ?ease:String = "linear"):Bool
      return startTween(state, tag, objectTag, values, duration, ease));
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
        {
          var resolvedImage:String = Paths.image(image);
          sprite.loadGraphic(resolvedImage);
          if (state.currentSong != null)
            PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.image.load.complete",
              "api=makeLuaSprite tag=" + tag + " request=" + image + " resolved=" + resolvedImage);
        }
        scriptVariables.set(tag, sprite);
        return true;
      }
      catch (error:Dynamic)
      {
        sprite.destroy();
        if (state.currentSong != null)
          PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.image.load.failed",
            "api=makeLuaSprite tag=" + tag + " request=" + image + " error=" + Std.string(error));
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
    vars.set("setTextWidth", function(tag:String, width:Float):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).fieldWidth = width;
      return true;
    });
    vars.set("setTextHeight", function(tag:String, height:Float):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).fieldHeight = height;
      return true;
    });
    vars.set("setTextAutoSize", function(tag:String, enabled:Bool):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).autoSize = enabled;
      return true;
    });
    vars.set("setTextItalic", function(tag:String, enabled:Bool):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      (cast object:FlxText).italic = enabled;
      return true;
    });
    vars.set("getTextString", function(tag:String):Dynamic
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      return object != null && Std.isOfType(object, FlxText) ? (cast object:FlxText).text : null;
    });
    vars.set("getTextSize", function(tag:String):Int
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      return object != null && Std.isOfType(object, FlxText) ? (cast object:FlxText).size : -1;
    });
    vars.set("getTextFont", function(tag:String):Dynamic
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      return object != null && Std.isOfType(object, FlxText) ? (cast object:FlxText).font : null;
    });
    vars.set("getTextWidth", function(tag:String):Float
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      return object != null && Std.isOfType(object, FlxText) ? (cast object:FlxText).fieldWidth : 0;
    });
    vars.set("removeLuaText", function(tag:String, ?destroy:Bool = true):Bool
    {
      var object:Null<FlxSprite> = getSprite(state, tag);
      if (object == null || !Std.isOfType(object, FlxText)) return false;
      removeFromParent(state, object);
      if (destroy)
      {
        object.kill();
        object.destroy();
        scriptVariables.remove(tag);
      }
      return true;
    });

    vars.set("makeAnimatedLuaSprite", function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Bool
    {
      var sprite = new FlxSprite(x, y);
      try
      {
        sprite.frames = Paths.getSparrowAtlas(image);
        if (state.currentSong != null)
          PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.atlas.load.complete",
            "api=makeAnimatedLuaSprite tag=" + tag + " request=" + image);
        scriptVariables.set(tag, sprite);
        return true;
      }
      catch (error:Dynamic)
      {
        sprite.destroy();
        if (state.currentSong != null)
          PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.atlas.load.failed",
            "api=makeAnimatedLuaSprite tag=" + tag + " request=" + image + " error=" + Std.string(error));
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

    vars.set("addAnimation", function(tag:String, name:String, frames:Array<Int>, ?framerate:Int = 24, ?loop:Bool = false):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null || frames == null || frames.length == 0) return false;
      sprite.animation.add(name, frames, framerate, loop);
      return true;
    });
    vars.set("addAnimationByIndices", function(tag:String, name:String, prefix:String, indices:Dynamic,
        ?framerate:Int = 24, ?loop:Bool = false):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      var parsed:Array<Int> = [];
      if (Std.isOfType(indices, Array))
        for (index in (cast indices:Array<Dynamic>))
          parsed.push(Std.int(index));
      else if (indices != null)
        for (part in Std.string(indices).split(","))
        {
          var value:Null<Int> = Std.parseInt(StringTools.trim(part));
          if (value != null) parsed.push(value);
        }
      if (parsed.length == 0) return false;
      sprite.animation.addByIndices(name, prefix, parsed, "", framerate, loop);
      return true;
    });
    vars.set("playAnim", function(tag:String, name:String, ?force:Bool = false, ?reversed:Bool = false, ?frame:Int = 0):Bool
    {
      var object:Dynamic = getProperty(state, tag);
      if (Std.isOfType(object, BaseCharacter))
      {
        (cast object:BaseCharacter).playAnimation(name, force, false, reversed);
        return true;
      }
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null && Std.isOfType(object, FlxSprite)) sprite = cast object;
      if (sprite == null) return false;
      sprite.animation.play(name, force, reversed, frame);
      return true;
    });
    vars.set("addOffset", function(characterTag:String, animation:String, x:Float, y:Float):Bool
    {
      var object:Dynamic = getProperty(state, characterTag);
      if (!Std.isOfType(object, BaseCharacter)) return false;
      (cast object:BaseCharacter).animationOffsets.set(animation, [x, y]);
      return true;
    });
    vars.set("characterDance", function(?role:String = "bf"):Bool
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      if (character == null) return false;
      character.dance();
      return true;
    });
    vars.set("loadGraphic", function(tag:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null || image == null || image.length == 0) return false;
      var resolvedImage:String = Paths.image(image);
      sprite.loadGraphic(resolvedImage, gridX > 0 && gridY > 0, gridX, gridY);
      if (state.currentSong != null)
        PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.image.load.complete",
          "api=loadGraphic tag=" + tag + " request=" + image + " resolved=" + resolvedImage);
      return true;
    });
    vars.set("loadFrames", function(tag:String, image:String, ?spriteType:String = "sparrow"):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null || image == null || image.length == 0) return false;
      try
      {
        sprite.frames = StringTools.trim(spriteType).toLowerCase() == "packer"
          ? Paths.getPackerAtlas(image)
          : Paths.getSparrowAtlas(image);
        if (state.currentSong != null)
          PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.atlas.load.complete",
            "api=loadFrames tag=" + tag + " request=" + image + " type=" + spriteType);
        return true;
      }
      catch (error:Dynamic)
      {
        if (state.currentSong != null)
          PsychModRuntime.logSongLaunchStep(state.currentSong.id, state.currentDifficulty, "lua.atlas.load.failed",
            "api=loadFrames tag=" + tag + " request=" + image + " type=" + spriteType + " error=" + Std.string(error));
        trace('[Psych API] loadFrames(' + tag + ') failed: ' + Std.string(error));
        return false;
      }
    });
    vars.set("updateHitbox", function(tag:String):Bool
    {
      var object:Dynamic = getProperty(state, tag);
      if (!Std.isOfType(object, FlxSprite)) object = getSprite(state, tag);
      if (!Std.isOfType(object, FlxSprite)) return false;
      (cast object:FlxSprite).updateHitbox();
      return true;
    });
    vars.set("updateHitboxFromGroup", function(group:String, index:Int):Bool
    {
      var object:Dynamic = getGroupMember(state, group, index);
      if (!Std.isOfType(object, FlxSprite)) return false;
      (cast object:FlxSprite).updateHitbox();
      return true;
    });
    vars.set("screenCenter", function(tag:String, ?axes:String = "xy"):Bool
    {
      var object:Dynamic = getProperty(state, tag);
      if (!Std.isOfType(object, FlxSprite)) object = getSprite(state, tag);
      if (!Std.isOfType(object, FlxSprite)) return false;
      var normalized:String = axes == null ? "xy" : StringTools.trim(axes).toLowerCase();
      var resolvedAxes:FlxAxes = normalized == "x" ? FlxAxes.X : (normalized == "y" ? FlxAxes.Y : FlxAxes.XY);
      (cast object:FlxSprite).screenCenter(resolvedAxes);
      return true;
    });
    vars.set("setBlendMode", function(tag:String, ?mode:String = ""):Bool
    {
      var object:Dynamic = getProperty(state, tag);
      if (!Std.isOfType(object, FlxSprite)) object = getSprite(state, tag);
      if (!Std.isOfType(object, FlxSprite)) return false;
      var blend:BlendMode = switch (mode == null ? "" : StringTools.trim(mode).toLowerCase())
      {
        case "add", "additive": BlendMode.ADD;
        case "multiply": BlendMode.MULTIPLY;
        case "screen": BlendMode.SCREEN;
        case "darken": BlendMode.DARKEN;
        case "lighten": BlendMode.LIGHTEN;
        case "overlay": BlendMode.OVERLAY;
        case "hardlight": BlendMode.HARDLIGHT;
        case "difference": BlendMode.DIFFERENCE;
        case "invert": BlendMode.INVERT;
        case "alpha": BlendMode.ALPHA;
        case "erase": BlendMode.ERASE;
        default: BlendMode.NORMAL;
      };
      (cast object:FlxSprite).blend = blend;
      return true;
    });
    vars.set("objectsOverlap", function(first:String, second:String):Bool
    {
      var objectA:Dynamic = getProperty(state, first);
      if (objectA == null) objectA = getSprite(state, first);
      var objectB:Dynamic = getProperty(state, second);
      if (objectB == null) objectB = getSprite(state, second);
      if (!Std.isOfType(objectA, FlxBasic) || !Std.isOfType(objectB, FlxBasic)) return false;
      return FlxG.overlap(cast objectA, cast objectB);
    });
    vars.set("getPixelColor", function(tag:String, x:Int, y:Int):Int
    {
      var sprite:Dynamic = getProperty(state, tag);
      if (!Std.isOfType(sprite, FlxSprite)) sprite = getSprite(state, tag);
      if (!Std.isOfType(sprite, FlxSprite)) return FlxColor.BLACK;
      try
      {
        return (cast sprite:FlxSprite).pixels.getPixel32(x, y);
      }
      catch (error:Dynamic)
      {
        return FlxColor.BLACK;
      }
    });
    vars.set("luaSpriteExists", function(tag:String):Bool return getSprite(state, tag) != null);
    vars.set("luaTextExists", function(tag:String):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      return sprite != null && Std.isOfType(sprite, FlxText);
    });
    vars.set("luaSoundExists", function(tag:String):Bool return activeSounds.exists(tag));
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

      // Stage is a nested group in NovaBeat. Add Psych props inside that group
      // so "behind characters" means behind the characters, not behind the
      // entire stage (which used to cover every background-level Lua sprite).
      var stage = state.currentStage;
      if (stage != null)
      {
        // Stage.preAdd assigns the stage camera. Preserve a camera explicitly
        // selected by the Psych script before addLuaSprite(), e.g. "hud".
        var requestedCameras = sprite.cameras;
        if (inFront)
        {
          stage.add(sprite);
        }
        else
        {
          var firstCharacterIndex:Int = -1;
          for (i in 0...stage.members.length)
          {
            if (Std.isOfType(stage.members[i], BaseCharacter))
            {
              firstCharacterIndex = i;
              break;
            }
          }
          if (firstCharacterIndex >= 0) stage.insert(firstCharacterIndex, sprite);
          else stage.add(sprite);
        }
        if (requestedCameras != null) sprite.cameras = requestedCameras;
      }
      else
      {
        if (inFront) state.add(sprite);
        else state.insert(0, sprite);
      }
      return true;
    });
    vars.set("removeLuaSprite", function(tag:String, ?destroy:Bool = true):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      removeFromParent(state, sprite);
      scriptVariables.remove(tag);
      if (destroy) sprite.destroy();
      return true;
    });
    vars.set("setObjectCamera", function(tag:String, camera:String):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      var normalized:String = camera == null ? "game" : camera.toLowerCase();
      sprite.cameras = [resolveCamera(state, normalized)];
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
    // Psych 0.7.x deprecated aliases remain in widespread mod use.
    vars.set("addAnimationByIndicesLoop", function(tag:String, name:String, prefix:String,
        indices:String, ?framerate:Int = 24):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      var parsed:Array<Int> = [];
      if (indices != null)
        for (part in indices.split(","))
        {
          var value:Null<Int> = Std.parseInt(StringTools.trim(part));
          if (value != null) parsed.push(value);
        }
      if (parsed.length == 0) return false;
      sprite.animation.addByIndices(name, prefix, parsed, "", framerate, true);
      return true;
    });
    vars.set("characterPlayAnim", function(role:String, animation:String, ?forced:Bool = false):Bool
    {
      var character:Null<BaseCharacter> = getCharacterForRole(state, role);
      if (character == null || animation == null || !character.hasAnimation(animation)) return false;
      character.playAnimation(animation, forced);
      return true;
    });
    vars.set("luaSpriteMakeGraphic", function(tag:String, width:Int, height:Int, color:Dynamic):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null || width <= 0 || height <= 0) return false;
      sprite.makeGraphic(width, height, parsePsychColor(color));
      return true;
    });
    vars.set("luaSpriteAddAnimationByPrefix", function(tag:String, name:String, prefix:String,
        ?framerate:Int = 24, ?loop:Bool = true):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.animation.addByPrefix(name, prefix, framerate, loop);
      if (sprite.animation.curAnim == null) sprite.animation.play(name, true);
      return true;
    });
    vars.set("luaSpriteAddAnimationByIndices", function(tag:String, name:String, prefix:String,
        indices:String, ?framerate:Int = 24):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null || indices == null) return false;
      var parsed:Array<Int> = [];
      for (part in indices.split(","))
      {
        var value:Null<Int> = Std.parseInt(StringTools.trim(part));
        if (value != null) parsed.push(value);
      }
      if (parsed.length == 0) return false;
      sprite.animation.addByIndices(name, prefix, parsed, "", framerate, false);
      if (sprite.animation.curAnim == null) sprite.animation.play(name, true);
      return true;
    });
    vars.set("luaSpritePlayAnimation", function(tag:String, name:String, ?forced:Bool = false):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.animation.play(name, forced);
      return true;
    });
    vars.set("setLuaSpriteCamera", function(tag:String, ?camera:String = ""):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.cameras = [resolveCamera(state, camera)];
      return true;
    });
    vars.set("setLuaSpriteScrollFactor", function(tag:String, scrollX:Float, scrollY:Float):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.scrollFactor.set(scrollX, scrollY);
      return true;
    });
    vars.set("scaleLuaSprite", function(tag:String, x:Float, y:Float):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      sprite.scale.set(x, y);
      sprite.updateHitbox();
      return true;
    });
    vars.set("musicFadeIn", function(duration:Float, ?fromValue:Float = 0, ?toValue:Float = 1):Bool
    {
      if (FlxG.sound.music == null || duration < 0) return false;
      FlxG.sound.music.fadeIn(duration, fromValue, toValue);
      return true;
    });
    vars.set("musicFadeOut", function(duration:Float, ?toValue:Float = 0):Bool
    {
      if (FlxG.sound.music == null || duration < 0) return false;
      FlxG.sound.music.fadeOut(duration, toValue);
      return true;
    });

    vars.set("setObjectOrder", function(tag:String, index:Int):Bool
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return false;
      var stage = state.currentStage;
      if (stage != null && stage.members.indexOf(sprite) >= 0)
      {
        stage.remove(sprite, false);
        var target:Int = Std.int(Math.max(0, Math.min(index, stage.members.length)));
        stage.insert(target, sprite);
      }
      else
      {
        state.remove(sprite, false);
        var target:Int = Std.int(Math.max(0, Math.min(index, state.members.length)));
        state.insert(target, sprite);
      }
      return true;
    });
    vars.set("getObjectOrder", function(tag:String):Int
    {
      var sprite:Null<FlxSprite> = getSprite(state, tag);
      if (sprite == null) return -1;
      var stage = state.currentStage;
      var stageIndex:Int = stage == null ? -1 : stage.members.indexOf(sprite);
      return stageIndex >= 0 ? stageIndex : state.members.indexOf(sprite);
    });

    vars.set("triggerEvent", function(name:String, ?value1:String = "", ?value2:String = ""):Void
      triggerEvent(state, name, value1, value2));
    vars.set("cameraShake", function(camera:String, intensity:Float, duration:Float):Bool
    {
      if (duration < 0 || intensity < 0) return false;
      resolveCamera(state, camera).shake(intensity, duration);
      return true;
    });
    vars.set("cameraFlash", function(camera:String, color:Dynamic, duration:Float, ?forced:Bool = false):Bool
    {
      if (duration < 0) return false;
      resolveCamera(state, camera).flash(parsePsychColor(color), duration, null, forced);
      return true;
    });
    vars.set("cameraFade", function(camera:String, color:Dynamic, duration:Float, ?forced:Bool = false, ?fadeOut:Bool = false):Bool
    {
      if (duration < 0) return false;
      resolveCamera(state, camera).fade(parsePsychColor(color), duration, fadeOut, null, forced);
      return true;
    });

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
    // Psych's camOther is the separate top-layer overlay camera. NovaBeat's
    // existing pause/overlay camera provides the same independent draw layer.
    vars.set("camOther", state.camPause);

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
        var basic:FlxBasic = cast object;
        removeFromParent(state, basic);
        if (destroy) basic.destroy();
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

  /**
   * Refresh Psych's widely used song globals from the live NovaBeat state.
   * These values must not be frozen at script-load time: mods read score,
   * health, character names, camera position and preferences throughout play.
   */
  /**
   * Debug smoke test for the public Psych callback surface. This validates
   * that the expected functions are registered and callable values exist;
   * it intentionally does not execute them or mutate gameplay state.
   */
  public static function runApiSmokeTests(state:PlayState):Bool
  {
    if (state == null) return false;
    var globals:Map<String, Dynamic> = createGlobals(state);
    var required:Array<String> = [
      "getProperty", "setProperty", "getPropertyFromClass", "setPropertyFromClass",
      "getPropertyFromGroup", "setPropertyFromGroup", "removeFromGroup", "setVar", "getVar", "removeVar",
      "getHealth", "setHealth", "addHealth", "getSongPosition", "getSongName",
      "getDifficulty", "getSongLength", "getScore", "getMisses", "getHits",
      "callScript", "callOnScripts", "callOnLuas", "callOnHScript",
      "getGlobalFromScript", "setGlobalFromScript", "getGlobals", "isRunning",
      "addLuaScript", "addHScript", "removeLuaScript", "removeHScript",
      "makeLuaSprite", "makeAnimatedLuaSprite", "makeLuaText", "makeGraphic",
      "addLuaSprite", "removeLuaSprite", "addLuaText", "removeLuaText", "luaTextExists",
      "setTextString", "setTextSize", "setTextWidth", "setTextHeight", "setTextAutoSize",
      "setTextItalic", "setTextFont", "setTextColor", "setTextAlignment", "setTextBorder",
      "getTextString", "getTextSize", "getTextWidth", "getTextFont", "objectPlayAnimation",
      "initSaveData", "flushSaveData", "getDataFromSave", "setDataFromSave", "eraseSaveData", "getModSetting",
      "addAnimationByPrefix", "addAnimationByIndices", "doTweenX", "startTween",
      "noteTweenX", "noteTweenDirection", "runTimer", "cancelTimer", "cancelTween",
      "playSound", "playMusic", "stopSound", "pauseSound", "resumeSound",
      "getSoundVolume", "getSoundTime", "setSoundTime", "getSoundPitch", "setSoundPitch",
      "soundFadeIn", "soundFadeOut", "soundFadeCancel",
      "setTimeBarColors", "close", "keyJustPressed", "keyPressed", "keyReleased",
      "gamepadJustPressed", "gamepadPressed", "gamepadReleased",
      "stringStartsWith", "stringEndsWith", "stringSplit", "stringTrim",
      "checkFileExists", "getTextFromFile", "saveFile", "deleteFile", "directoryFileList",
      "initLuaShader", "setSpriteShader", "removeSpriteShader", "getShaderBool", "getShaderBoolArray",
      "getShaderInt", "getShaderIntArray", "getShaderFloat", "getShaderFloatArray",
      "setShaderBool", "setShaderBoolArray", "setShaderInt", "setShaderIntArray",
      "setShaderFloat", "setShaderFloatArray", "setShaderSampler2D",
      "callMethod", "callMethodFromClass", "createInstance", "addInstance", "instanceArg",
      "makeFlxAnimateSprite", "loadAnimateAtlas", "addAnimationBySymbol", "addAnimationBySymbolIndices",
      "cameraShake", "cameraFlash", "cameraFade", "triggerEvent", "camOther",
      "openCustomSubstate", "closeCustomSubstate", "insertToCustomSubstate",
      "getCharacterX", "getCharacterY", "setCharacterX", "setCharacterY",
      "cameraSetTarget", "startCountdown", "endSong", "restartSong", "exitSong", "loadSong", "startVideo", "startDialogue",
      "addCharacterToList", "precacheImage", "precacheSound", "precacheMusic", "setHealthBarColors",
      "addAnimationByIndicesLoop", "characterPlayAnim", "luaSpriteMakeGraphic",
      "luaSpriteAddAnimationByPrefix", "luaSpriteAddAnimationByIndices", "luaSpritePlayAnimation",
      "setLuaSpriteCamera", "setLuaSpriteScrollFactor", "scaleLuaSprite", "musicFadeIn", "musicFadeOut"
    ];

    // Pin the complete callback registration surface to official Psych 0.7.3.
    // This intentionally checks every public Lua callback, including less common
    // helpers, so a later refactor cannot silently drop a compatibility global.
    var officialPsych073Callbacks:Array<String> = [
      "FlxColor",
      "addAnimation",
      "addAnimationByIndices",
      "addAnimationByIndicesLoop",
      "addAnimationByPrefix",
      "addAnimationBySymbol",
      "addAnimationBySymbolIndices",
      "addCharacterToList",
      "addHScript",
      "addHealth",
      "addHits",
      "addInstance",
      "addLuaScript",
      "addLuaSprite",
      "addLuaText",
      "addMisses",
      "addOffset",
      "addScore",
      "anyGamepadJustPressed",
      "anyGamepadPressed",
      "anyGamepadReleased",
      "callMethod",
      "callMethodFromClass",
      "callOnHScript",
      "callOnLuas",
      "callOnScripts",
      "callScript",
      "cameraFade",
      "cameraFlash",
      "cameraSetTarget",
      "cameraShake",
      "cancelTimer",
      "cancelTween",
      "characterDance",
      "characterPlayAnim",
      "checkFileExists",
      "close",
      "closeCustomSubstate",
      "createInstance",
      "debugPrint",
      "deleteFile",
      "directoryFileList",
      "doTweenAlpha",
      "doTweenAngle",
      "doTweenColor",
      "doTweenX",
      "doTweenY",
      "doTweenZoom",
      "endSong",
      "eraseSaveData",
      "exitSong",
      "flushSaveData",
      "gamepadAnalogX",
      "gamepadAnalogY",
      "gamepadJustPressed",
      "gamepadPressed",
      "gamepadReleased",
      "getCharacterX",
      "getCharacterY",
      "getColorFromHex",
      "getColorFromName",
      "getColorFromString",
      "getDataFromSave",
      "getGlobalFromScript",
      "getGlobals",
      "getGraphicMidpointX",
      "getGraphicMidpointY",
      "getHealth",
      "getHits",
      "getMidpointX",
      "getMidpointY",
      "getMisses",
      "getModSetting",
      "getMouseX",
      "getMouseY",
      "getObjectOrder",
      "getPixelColor",
      "getProperty",
      "getPropertyFromClass",
      "getPropertyFromGroup",
      "getPropertyLuaSprite",
      "getRandomBool",
      "getRandomFloat",
      "getRandomInt",
      "getRunningScripts",
      "getScore",
      "getScreenPositionX",
      "getScreenPositionY",
      "getShaderBool",
      "getShaderBoolArray",
      "getShaderFloat",
      "getShaderFloatArray",
      "getShaderInt",
      "getShaderIntArray",
      "getSongPosition",
      "getSoundPitch",
      "getSoundTime",
      "getSoundVolume",
      "getTextFont",
      "getTextFromFile",
      "getTextSize",
      "getTextString",
      "getTextWidth",
      "getVar",
      "initLuaShader",
      "initSaveData",
      "insertToCustomSubstate",
      "instanceArg",
      "isRunning",
      "keyJustPressed",
      "keyPressed",
      "keyReleased",
      "keyboardJustPressed",
      "keyboardPressed",
      "keyboardReleased",
      "loadAnimateAtlas",
      "loadFrames",
      "loadGraphic",
      "loadSong",
      "luaSoundExists",
      "luaSpriteAddAnimationByIndices",
      "luaSpriteAddAnimationByPrefix",
      "luaSpriteExists",
      "luaSpriteMakeGraphic",
      "luaSpritePlayAnimation",
      "luaTextExists",
      "makeAnimatedLuaSprite",
      "makeFlxAnimateSprite",
      "makeGraphic",
      "makeLuaSprite",
      "makeLuaText",
      "mouseClicked",
      "mousePressed",
      "mouseReleased",
      "musicFadeIn",
      "musicFadeOut",
      "noteTweenAlpha",
      "noteTweenAngle",
      "noteTweenDirection",
      "noteTweenX",
      "noteTweenY",
      "objectPlayAnimation",
      "objectsOverlap",
      "openCustomSubstate",
      "pauseSound",
      "playAnim",
      "playMusic",
      "playSound",
      "precacheImage",
      "precacheMusic",
      "precacheSound",
      "removeFromGroup",
      "removeHScript",
      "removeLuaScript",
      "removeLuaSprite",
      "removeLuaText",
      "removeSpriteShader",
      "restartSong",
      "resumeSound",
      "runTimer",
      "saveFile",
      "scaleLuaSprite",
      "scaleObject",
      "screenCenter",
      "setBlendMode",
      "setCharacterX",
      "setCharacterY",
      "setDataFromSave",
      "setGlobalFromScript",
      "setGraphicSize",
      "setHealth",
      "setHealthBarColors",
      "setHits",
      "setLuaSpriteCamera",
      "setLuaSpriteScrollFactor",
      "setMisses",
      "setObjectCamera",
      "setObjectOrder",
      "setOnHScript",
      "setOnLuas",
      "setOnScripts",
      "setProperty",
      "setPropertyFromClass",
      "setPropertyFromGroup",
      "setPropertyLuaSprite",
      "setRatingFC",
      "setRatingName",
      "setRatingPercent",
      "setScore",
      "setScrollFactor",
      "setShaderBool",
      "setShaderBoolArray",
      "setShaderFloat",
      "setShaderFloatArray",
      "setShaderInt",
      "setShaderIntArray",
      "setShaderSampler2D",
      "setSoundPitch",
      "setSoundTime",
      "setSoundVolume",
      "setSpriteShader",
      "setTextAlignment",
      "setTextAutoSize",
      "setTextBorder",
      "setTextColor",
      "setTextFont",
      "setTextHeight",
      "setTextItalic",
      "setTextSize",
      "setTextString",
      "setTextWidth",
      "setTimeBarColors",
      "setVar",
      "soundFadeCancel",
      "soundFadeIn",
      "soundFadeOut",
      "startCountdown",
      "startDialogue",
      "startTween",
      "startVideo",
      "stopSound",
      "stringEndsWith",
      "stringSplit",
      "stringStartsWith",
      "stringTrim",
      "triggerEvent",
      "updateHitbox",
      "updateHitboxFromGroup"
    ];
    for (name in officialPsych073Callbacks)
      if (!required.contains(name)) required.push(name);

    var missing:Array<String> = [];
    for (name in required)
      if (!globals.exists(name) || globals.get(name) == null) missing.push(name);

    if (resolveCamera(state, "camOther") != state.camPause
      || resolveCamera(state, "other") != state.camPause
      || resolveCamera(state, "camHUD") != state.camHUD
      || resolveCamera(state, "camGame") != state.camGame)
    {
      trace('[Psych API Smoke Test] Camera aliases did not resolve to the expected layers.');
      return false;
    }

    if (missing.length > 0)
    {
      trace('[Psych API Smoke Test] Missing registrations: ' + missing.join(", "));
      return false;
    }

    var sandboxPassed:Bool = isSafeSaveIdentifier("psych_mod-save")
      && !isSafeSaveIdentifier("../outside")
      && resolveSafePsychClass("flixel.FlxSprite") != null
      && resolveSafePsychClass("sys.io.File") == null
      && resolveSafePsychClass("openfl.net.URLLoader") == null;
    if (!sandboxPassed)
    {
      trace('[Psych API Smoke Test] A sandbox path or class allowlist check failed.');
      return false;
    }
    return true;
  }

  /**
   * Apply Psych's opponent/player character colors to NovaBeat's two-color bar.
   * Non-Psych songs and characters without both color triplets keep native colors.
   */
  public static function applyPsychHealthBarColors(state:PlayState):Bool
  {
    if (state == null || state.currentSong == null || state.currentStage == null
      || state.healthBar == null || !PsychModRuntime.isImportedSong(state.currentSong.id)) return false;

    var boyfriend:Null<BaseCharacter> = state.currentStage.getBoyfriend();
    var opponent:Null<BaseCharacter> = state.currentStage.getDad();
    if (boyfriend == null || opponent == null) return false;

    var colors:Null<Array<Int>> = PsychModRuntime.getPsychHealthBarColors(
      state.currentSong.id,
      boyfriend.characterId,
      opponent.characterId
    );
    if (colors == null || colors.length != 6) return false;

    state.healthBar.createFilledBar(
      FlxColor.fromRGB(colors[0], colors[1], colors[2]),
      FlxColor.fromRGB(colors[3], colors[4], colors[5])
    );
    state.healthBar.updateBar();
    return true;
  }

  public static function updateGlobals(state:PlayState):Void
  {
    if (state == null) return;
    initializePsychSectionState(state);
    if (activeTimeBar != null)
    {
      var requestedTimeBarType:Dynamic = PsychScriptRuntime.getGlobal("timeBarType");
      if (requestedTimeBarType != null)
        activeTimeBar.timeBarType = Std.string(requestedTimeBarType);
    }
    PsychScriptRuntime.setGlobal("health", state.health);
    PsychScriptRuntime.setGlobal("score", state.songScore);
    PsychScriptRuntime.setGlobal("misses", Highscore.tallies.missed);
    PsychScriptRuntime.setGlobal("hits", Highscore.tallies.totalNotesHit);
    PsychScriptRuntime.setGlobal("combo", Highscore.tallies.combo);
    PsychScriptRuntime.setGlobal("songName", state.currentSong == null ? "" : state.currentSong.songName);
    PsychScriptRuntime.setGlobal("songPath", state.currentSong == null ? "" : state.currentSong.id);
    PsychScriptRuntime.setGlobal("difficulty", state.currentDifficulty);
    PsychScriptRuntime.setGlobal("difficultyName", state.currentDifficulty);
    PsychScriptRuntime.setGlobal("songLength", state.currentSongLengthMs);
    PsychScriptRuntime.setGlobal("playbackRate", state.playbackRate);
    PsychScriptRuntime.setGlobal("hasVocals", state.vocals != null);
    PsychScriptRuntime.setGlobal("inGameOver", state.isGameOverState);
    PsychScriptRuntime.setGlobal("practice", state.isPracticeMode);
    PsychScriptRuntime.setGlobal("botPlay", state.isBotPlayMode);
    PsychScriptRuntime.setGlobal("startedCountdown", state.isInCountdown);
    PsychScriptRuntime.setGlobal("inChartEditor", false);
    PsychScriptRuntime.setGlobal("screenWidth", FlxG.width);
    PsychScriptRuntime.setGlobal("screenHeight", FlxG.height);
    PsychScriptRuntime.setGlobal("cameraX", state.cameraFollowPoint == null ? 0 : state.cameraFollowPoint.x);
    PsychScriptRuntime.setGlobal("cameraY", state.cameraFollowPoint == null ? 0 : state.cameraFollowPoint.y);
    PsychScriptRuntime.setGlobal("curStage", state.currentStage == null ? "" : state.currentStage.stageName);
    PsychScriptRuntime.setGlobal("downscroll", Preferences.downscroll);
    PsychScriptRuntime.setGlobal("flashingLights", Preferences.flashingLights);
    PsychScriptRuntime.setGlobal("framerate", Preferences.framerate);
    PsychScriptRuntime.setGlobal("cameraZoomOnBeat", Preferences.zoomCamera);
    PsychScriptRuntime.setGlobal("noteOffset", Preferences.globalOffset);
    PsychScriptRuntime.setGlobal("luaDebugMode", false);
    PsychScriptRuntime.setGlobal("luaDeprecatedWarnings", false);
    PsychScriptRuntime.setGlobal("isStoryMode", PlayStatePlaylist.isStoryMode);

    var currentStage = state.currentStage;
    if (currentStage != null)
    {
      var boyfriend:Null<BaseCharacter> = currentStage.getBoyfriend();
      var dad:Null<BaseCharacter> = currentStage.getDad();
      var girlfriend:Null<BaseCharacter> = currentStage.getGirlfriend();
      PsychScriptRuntime.setGlobal("boyfriend", boyfriend);
      PsychScriptRuntime.setGlobal("dad", dad);
      PsychScriptRuntime.setGlobal("gf", girlfriend);
      PsychScriptRuntime.setGlobal("boyfriendName", boyfriend == null ? "" : boyfriend.characterId);
      PsychScriptRuntime.setGlobal("dadName", dad == null ? "" : dad.characterId);
      PsychScriptRuntime.setGlobal("gfName", girlfriend == null ? "" : girlfriend.characterId);
      if (boyfriend != null)
      {
        PsychScriptRuntime.setGlobal("defaultBoyfriendX", boyfriend.originalPosition.x);
        PsychScriptRuntime.setGlobal("defaultBoyfriendY", boyfriend.originalPosition.y);
      }
      if (dad != null)
      {
        PsychScriptRuntime.setGlobal("defaultOpponentX", dad.originalPosition.x);
        PsychScriptRuntime.setGlobal("defaultOpponentY", dad.originalPosition.y);
      }
      if (girlfriend != null)
      {
        PsychScriptRuntime.setGlobal("defaultGirlfriendX", girlfriend.originalPosition.x);
        PsychScriptRuntime.setGlobal("defaultGirlfriendY", girlfriend.originalPosition.y);
      }
    }

    var activeDirectory:String = PsychScriptRuntime.getActiveModDirectory();
    PsychScriptRuntime.setGlobal("currentModDirectory", activeDirectory);
    PsychScriptRuntime.setGlobal("curSection", psychCurrentSection);
    PsychScriptRuntime.setGlobal("rating", Highscore.tallies.totalNotes <= 0
      ? 0.0
      : Highscore.tallies.totalNotesHit / Highscore.tallies.totalNotes);

    // Psych 0.7.3 startup globals which have direct NovaBeat equivalents.
    // Campaign-only values stay at explicit neutral defaults because this
    // engine launches imported Psych songs from Freeplay rather than Psych weeks.
    PsychScriptRuntime.setGlobal("weekRaw", null);
    PsychScriptRuntime.setGlobal("week", 0);
    PsychScriptRuntime.setGlobal("seenCutscene", false);
    PsychScriptRuntime.setGlobal("version", Constants.VERSION);
    PsychScriptRuntime.setGlobal("mustHitSection", psychMustHitSection);
    PsychScriptRuntime.setGlobal("altAnim", psychAltAnim);
    PsychScriptRuntime.setGlobal("gfSection", psychGFSection);
    PsychScriptRuntime.setGlobal("healthGainMult", 1.0);
    PsychScriptRuntime.setGlobal("healthLossMult", 1.0);
    PsychScriptRuntime.setGlobal("guitarHeroSustains", false);
    PsychScriptRuntime.setGlobal("instakillOnMiss", false);
    PsychScriptRuntime.setGlobal("middlescroll", false);
    PsychScriptRuntime.setGlobal("ghostTapping", true);
    PsychScriptRuntime.setGlobal("hideHud", state.isMinimalMode);
    PsychScriptRuntime.setGlobal("scoreZoom", true);
    PsychScriptRuntime.setGlobal("healthBarAlpha", state.healthBar == null ? 1.0 : state.healthBar.alpha);
    PsychScriptRuntime.setGlobal("noResetButton", false);
    PsychScriptRuntime.setGlobal("lowQuality", false);
    PsychScriptRuntime.setGlobal("shadersEnabled", Preferences.performanceStageShaders);
    PsychScriptRuntime.setGlobal("noteSkin", state.currentChart?.noteStyle ?? Constants.DEFAULT_NOTE_STYLE);
    PsychScriptRuntime.setGlobal("noteSkinPostfix", "");
    PsychScriptRuntime.setGlobal("splashSkin", state.currentChart?.noteStyle ?? Constants.DEFAULT_NOTE_STYLE);
    PsychScriptRuntime.setGlobal("splashSkinPostfix", "");
    PsychScriptRuntime.setGlobal("splashAlpha", 1.0);
    PsychScriptRuntime.setGlobal("ratingName", "");
    PsychScriptRuntime.setGlobal("ratingFC", "");
    PsychScriptRuntime.setGlobal("difficultyPath", psychSongSlug(state.currentDifficulty));
    PsychScriptRuntime.setGlobal("inChartEditor", state.isChartingMode);

    #if html5
    PsychScriptRuntime.setGlobal("buildTarget", "web");
    #elseif windows
    PsychScriptRuntime.setGlobal("buildTarget", "windows");
    #elseif linux
    PsychScriptRuntime.setGlobal("buildTarget", "linux");
    #elseif mac
    PsychScriptRuntime.setGlobal("buildTarget", "mac");
    #elseif android
    PsychScriptRuntime.setGlobal("buildTarget", "android");
    #elseif ios
    PsychScriptRuntime.setGlobal("buildTarget", "ios");
    #else
    PsychScriptRuntime.setGlobal("buildTarget", "native");
    #end
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
    var normalizedTag:String = tag == null ? "" : StringTools.replace(tag, ".", "");
    var soundTag:String = normalizedTag.length == 0
      ? "psych-sound-" + Std.string(nextSoundTag++)
      : normalizedTag;
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

    // A sprite should belong to exactly one parent. It may previously have
    // been placed in currentStage by addLuaSprite(), or in the PlayState /
    // another custom substate. Remove it from its actual owner before moving.
    removeFromParent(state, object);
    if (position < 0 || position >= activeCustomSubstate.members.length)
      activeCustomSubstate.add(object);
    else
      activeCustomSubstate.insert(position, object);
    customSubstateObjects.set(tag, object);
    return true;
  }

  public static function finishCustomSubstate(subState:PsychCustomSubState):Void
  {
    if (activeCustomSubstate == subState) activeCustomSubstate = null;

    // The FlxSubState owns and destroys transferred sprites. Drop only the
    // compatibility tag references here; do not destroy the objects twice.
    for (tag => object in customSubstateObjects)
      if (scriptVariables.get(tag) == object) scriptVariables.remove(tag);
    customSubstateObjects.clear();
  }

  public static function clear():Void
  {
    activeCustomSubstate = null;
    customSubstateObjects.clear();
    for (tween in activeTweens)
      tween.cancel();
    for (timer in activeTimers)
      timer.cancel();
    activeTweens.clear();
    activeTimers.clear();
    for (sound in activeSounds)
      if (sound != null) sound.stop();
    for (save in activeSaves)
      if (save != null) save.flush();
    activeSaves.clear();
    activeSounds.clear();
    activeTimeBar = null;
    activeDialogue = null;
    for (character in preloadedCharacters)
      if (character != null) character.destroy();
    preloadedCharacters.clear();
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

  static function resolveCamera(state:PlayState, camera:String):FlxCamera
  {
    var normalized:String = camera == null ? "game" : StringTools.trim(camera).toLowerCase();
    return switch (normalized)
    {
      case "hud", "camhud": state.camHUD;
      case "other", "camother", "pause", "campause": state.camPause;
      default: state.camGame;
    };
  }

  static function getMousePosition(state:PlayState, camera:String):FlxPoint
  {
    // Psych's getMouseX/Y helpers return camera screen coordinates, not
    // world coordinates. Keep the coordinate space consistent with mods.
    return FlxG.mouse.getScreenPosition(resolveCamera(state, camera));
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

  static function psychSongSlug(value:String):String
  {
    if (value == null) return "";
    var normalized:String = ~/[^a-zA-Z0-9]+/g.replace(StringTools.trim(value), "-").toLowerCase();
    while (StringTools.startsWith(normalized, "-")) normalized = normalized.substr(1);
    while (StringTools.endsWith(normalized, "-")) normalized = normalized.substr(0, normalized.length - 1);
    return normalized;
  }

  public static function hasActiveDialogue():Bool
  {
    return activeDialogue != null && activeDialogue.exists;
  }

  public static function advanceDialogue():Void
  {
    if (hasActiveDialogue()) activeDialogue.advance();
  }

  static function startPsychDialogue(state:PlayState, dialogueFile:String, ?music:String):Bool
  {
    if (state == null || state.currentSong == null || hasActiveDialogue()) return false;
    var source:Null<PsychScriptSource> = PsychModRuntime.getSongDataFile(state.currentSong.id, dialogueFile);
    if (source == null)
    {
      trace('[Psych Dialogue] Could not find data/' + state.currentSong.id + '/' + dialogueFile + '.json in the owning Psych package.');
      resumeAfterMissingPsychDialogue(state);
      return false;
    }

    try
    {
      var parsed:Dynamic = haxe.Json.parse(source.source);
      var rawLines:Dynamic = Reflect.field(parsed, "dialogue");
      if (!Std.isOfType(rawLines, Array) || (cast rawLines:Array<Dynamic>).length == 0)
      {
        trace('[Psych Dialogue] The dialogue file contains no dialogue lines: ' + source.path);
        resumeAfterMissingPsychDialogue(state);
        return false;
      }

      var lines:Array<Dynamic> = [];
      for (line in (cast rawLines:Array<Dynamic>))
        if (line != null) lines.push(line);
      if (lines.length == 0)
      {
        trace('[Psych Dialogue] The dialogue file contains no usable dialogue lines: ' + source.path);
        resumeAfterMissingPsychDialogue(state);
        return false;
      }

      var endingSong:Bool = state.isSongEnd;
      activeDialogue = new PsychDialogueOverlay(state, lines, function():Void
      {
        var finishedDialogue:Null<PsychDialogueOverlay> = activeDialogue;
        activeDialogue = null;
        if (finishedDialogue != null)
          state.remove(finishedDialogue, true);

        state.isInCutscene = false;
        if (music != null && StringTools.trim(music).length > 0
          && FlxG.sound.music != null)
          FlxG.sound.music.fadeOut(1, 0);

        // Match Psych's common pre-countdown / post-song dialogue lifecycle.
        if (endingSong) state.endSong();
        else state.startCountdown();
      });

      state.isInCutscene = true;
      state.add(activeDialogue);

      if (music != null && StringTools.trim(music).length > 0)
      {
        FlxG.sound.playMusic(Paths.music(StringTools.trim(music)), 0, true);
        if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(2, 0, 1);
      }
      return true;
    }
    catch (error:Dynamic)
    {
      activeDialogue = null;
      trace('[Psych Dialogue] Could not parse ' + source.path + ': ' + Std.string(error));
      resumeAfterMissingPsychDialogue(state);
      return false;
    }
  }

  static function resumeAfterMissingPsychDialogue(state:PlayState):Void
  {
    if (state == null) return;
    // Psych resumes the countdown/end-song flow when the requested dialogue
    // file cannot be found. Do the same so a missing optional file never
    // strands a chart in an input-disabled cutscene.
    if (state.isSongEnd) state.endSong();
    else state.startCountdown();
  }

  static function ensureTimeBar(state:PlayState):Void
  {
    if (state == null || state.currentSong == null || !PsychModRuntime.isImportedSong(state.currentSong.id))
      return;

    if (activeTimeBar != null && activeTimeBar.exists) return;
    activeTimeBar = new PsychTimeBar(state);
    activeTimeBar.cameras = [state.camHUD];
    state.add(activeTimeBar);
  }

  static function resolveSound(tag:String):Null<FlxSound>
  {
    if (tag == null || tag.length == 0) return FlxG.sound.music;
    return activeSounds.get(tag);
  }

  static function getCharacterForRole(state:PlayState, role:String):Null<BaseCharacter>
  {
    var normalized:String = role == null ? "bf" : StringTools.trim(role).toLowerCase();
    return switch (normalized)
    {
      case "dad", "opponent", "1": getStageCharacter(state, "getDad");
      case "gf", "girlfriend", "2": getStageCharacter(state, "getGirlfriend");
      default: getStageCharacter(state, "getBoyfriend");
    };
  }

  static function getSprite(state:PlayState, tag:String):Null<FlxSprite>
  {
    if (tag == null || !scriptVariables.exists(tag)) return null;
    var value:Dynamic = scriptVariables.get(tag);
    return Std.isOfType(value, FlxSprite) ? cast value : null;
  }

  /**
   * Remove an object from the group that actually owns it. Psych Lua sprites
   * added with addLuaSprite() are children of currentStage, not PlayState.
   * Destroying one through PlayState.remove() alone leaves a dead member in
   * the stage draw list and can crash FlxAnimate during retry.
   */
  static function removeFromParent(state:PlayState, object:FlxBasic):Void
  {
    if (object == null) return;

    // Remove every stale copy defensively. A script may have moved an object
    // through multiple groups before calling remove(), and FlxGroup.add()
    // does not guarantee that old parents no longer retain it.
    if (activeCustomSubstate != null && activeCustomSubstate.members.indexOf(object) >= 0)
      activeCustomSubstate.remove(object, true);

    var stage = state.currentStage;
    // Stage is a FlxSpriteGroup wrapper: its drawable sprites live in the
    // inner group, not Stage.members. Check that actual owner before removing.
    if (stage != null && Std.isOfType(object, FlxSprite))
    {
      var stageSprite:FlxSprite = cast object;
      if (stage.containsStageSprite(stageSprite))
        stage.remove(stageSprite, true);
    }

    if (state.members.indexOf(object) >= 0)
      state.remove(object, true);
  }

  static function getProperty(state:PlayState, path:String, allowMaps:Bool = false):Dynamic
  {
    if (path == null || path.length == 0) return null;

    // Psych character objects expose imageFile and animation.frameName,
    // properties that the native FlxAnimate character class does not name
    // identically. Resolve these aliases before ordinary reflection.
    var lowerPath:String = path.toLowerCase();
    var imageFileSuffix:String = ".imagefile";
    if (StringTools.endsWith(lowerPath, imageFileSuffix))
    {
      var characterPath:String = path.substr(0, path.length - imageFileSuffix.length);
      var character:Dynamic = getProperty(state, characterPath, allowMaps);
      if (Std.isOfType(character, BaseCharacter))
        return (cast character:BaseCharacter).getPsychImageFile();
    }

    var currentAnimationSuffix:String = ".animation.curanim.name";
    if (StringTools.endsWith(lowerPath, currentAnimationSuffix))
    {
      var characterPath:String = path.substr(0, path.length - currentAnimationSuffix.length);
      var character:Dynamic = getProperty(state, characterPath, allowMaps);
      if (Std.isOfType(character, BaseCharacter))
      {
        var animationName:String = (cast character:BaseCharacter).getCurrentAnimation();
        // NovaBeat uses a separate hold animation suffix; Psych keeps the
        // base sing animation name while a note is being sustained.
        if (StringTools.endsWith(animationName, Constants.ANIMATION_HOLD_SUFFIX))
          animationName = animationName.substr(0, animationName.length - Constants.ANIMATION_HOLD_SUFFIX.length);
        return animationName;
      }
    }

    var frameNameSuffix:String = ".animation.framename";
    if (StringTools.endsWith(lowerPath, frameNameSuffix))
    {
      var characterPath:String = path.substr(0, path.length - frameNameSuffix.length);
      var character:Dynamic = getProperty(state, characterPath, allowMaps);
      if (Std.isOfType(character, BaseCharacter))
        return (cast character:BaseCharacter).getPsychFrameName();
    }

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
            state.currentCameraZoom = parseDynamicFloatOr(value, state.currentCameraZoom);
            state.camGame.zoom = state.currentCameraZoom;
          case "cameraX":
            state.cameraFollowPoint.x = parseDynamicFloatOr(value, state.cameraFollowPoint.x);
          case "cameraY":
            state.cameraFollowPoint.y = parseDynamicFloatOr(value, state.cameraFollowPoint.y);
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
      case "scoreTxt":
        return Reflect.field(state, "scoreText");
      case "timeBar":
        return activeTimeBar;
      case "timeBarBG":
        return activeTimeBar == null ? null : activeTimeBar.background;
      case "timeTxt":
        return activeTimeBar == null ? null : activeTimeBar.timeText;
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

  static function resolveSafePsychClass(className:String):Class<Dynamic>
  {
    if (className == null || className.length == 0) return null;
    var normalized:String = StringTools.trim(className);
    var aliases:Map<String, String> = [
      "FlxG" => "flixel.FlxG",
      "FlxSprite" => "flixel.FlxSprite",
      "FlxText" => "flixel.text.FlxText",
      "FlxObject" => "flixel.FlxObject",
      "FlxPoint" => "flixel.math.FlxPoint",
      "FlxMath" => "flixel.math.FlxMath",
      "FlxTimer" => "flixel.util.FlxTimer",
      "FlxTween" => "flixel.tweens.FlxTween",
      "FlxEase" => "flixel.tweens.FlxEase",
      "Conductor" => "funkin.Conductor",
      "Paths" => "funkin.Paths",
      "PlayState" => "funkin.play.PlayState"
    ];
    if (aliases.exists(normalized)) normalized = aliases.get(normalized);
    var allowed:Array<String> = [
      "flixel.FlxG", "flixel.FlxSprite", "flixel.text.FlxText", "flixel.FlxObject",
      "flixel.math.FlxPoint", "flixel.math.FlxMath", "flixel.util.FlxTimer",
      "flixel.tweens.FlxTween", "flixel.tweens.FlxEase", "funkin.Conductor",
      "funkin.Paths", "funkin.play.PlayState"
    ];
    if (allowed.indexOf(normalized) < 0) return null;
    return Type.resolveClass(normalized);
  }

  static function parseInstanceArguments(state:PlayState, args:Array<Dynamic>):Array<Dynamic>
  {
    var result:Array<Dynamic> = args == null ? [] : args.copy();
    for (i in 0...result.length)
    {
      var value:Dynamic = result[i];
      if (!Std.isOfType(value, String)) continue;
      var token:String = cast value;
      if (!StringTools.startsWith(token, "##PSYCHLUA_STRINGTOOBJ::")) continue;
      var payload:String = token.substr("##PSYCHLUA_STRINGTOOBJ::".length);
      var parts:Array<String> = payload.split("::");
      var path:String = parts[0];
      var root:Dynamic = state;
      if (parts.length > 1)
      {
        root = resolveSafePsychClass(parts[1]);
        if (root == null) continue;
      }
      result[i] = getFromObject(root, path, true);
    }
    return result;
  }

  static function isSafeReflectedMethod(target:Dynamic, methodName:String):Bool
  {
    if (target == null || methodName == null) return false;
    if (Std.isOfType(target, BaseCharacter))
      return ["playAnimation", "dance", "setPosition", "setFacingFlip"].contains(methodName);
    if (Std.isOfType(target, FlxText))
      return ["setFormat", "setBorderStyle", "setPosition", "setGraphicSize", "updateHitbox",
        "screenCenter", "setScrollFactor", "setSize", "kill", "destroy", "reset"].contains(methodName);
    if (Std.isOfType(target, FlxSprite))
      return ["setPosition", "setGraphicSize", "updateHitbox", "screenCenter", "setScrollFactor",
        "setSize", "kill", "destroy", "reset", "centerOrigin", "centerOffsets", "setFacingFlip",
        "makeGraphic", "loadGraphic"].contains(methodName);
    if (Std.isOfType(target, FlxCamera))
      return ["shake", "flash", "fade", "follow", "focusOn"].contains(methodName);
    if (Std.isOfType(target, FlxTimer)) return ["start", "cancel"].contains(methodName);
    if (Std.isOfType(target, FlxTween)) return ["cancel"].contains(methodName);
    if (Std.isOfType(target, PlayState))
      return ["startCountdown", "endSong", "pause", "resume", "triggerEvent"].contains(methodName);
    // FlxTypedGroup is a FlxBasic, so its group operations must be checked first.
    if (Reflect.field(target, "members") != null)
      return ["add", "remove", "insert", "clear"].contains(methodName);
    if (Std.isOfType(target, FlxBasic)) return ["kill", "destroy", "reset"].contains(methodName);
    return false;
  }

  static function callSafeMethod(state:PlayState, methodPath:String, args:Array<Dynamic>):Dynamic
  {
    if (methodPath == null || methodPath.length == 0) return null;
    var parts:Array<String> = methodPath.split(".");
    var methodName:String = StringTools.trim(parts.pop());
    if (methodName.length == 0) return null;
    var target:Dynamic = state;
    if (parts.length > 0) target = getProperty(state, parts.join("."));
    if (!isSafeReflectedMethod(target, methodName)) return null;
    var method:Dynamic = Reflect.field(target, methodName);
    if (method == null) return null;
    try return Reflect.callMethod(target, method, args == null ? [] : args) catch (error:Dynamic)
    {
      trace('[Psych API] callMethod(' + methodPath + ') failed: ' + Std.string(error));
      return null;
    }
  }

  static function callSafeClassMethod(className:String, methodPath:String, args:Array<Dynamic>):Dynamic
  {
    var target:Dynamic = resolveSafePsychClass(className);
    if (target == null || methodPath == null || methodPath.indexOf(".") >= 0) return null;
    var safeMethods:Map<String, Array<String>> = [
      "flixel.math.FlxMath" => ["max", "min", "abs", "floor", "ceil", "round", "roundDecimal", "lerp", "bound", "remapToRange"],
      "flixel.tweens.FlxEase" => ["linear", "quadIn", "quadOut", "quadInOut", "cubeIn", "cubeOut", "cubeInOut",
        "quartIn", "quartOut", "quartInOut", "quintIn", "quintOut", "quintInOut", "sineIn", "sineOut", "sineInOut"],
      "funkin.Conductor" => ["getBPMFromSeconds", "getBPMAtTime"],
      "funkin.Paths" => ["image", "font", "sound", "music", "video"]
    ];
    var normalized:String = StringTools.trim(className);
    if (normalized == "FlxMath") normalized = "flixel.math.FlxMath";
    if (normalized == "FlxEase") normalized = "flixel.tweens.FlxEase";
    if (normalized == "Conductor") normalized = "funkin.Conductor";
    if (normalized == "Paths") normalized = "funkin.Paths";
    if (!safeMethods.exists(normalized) || !safeMethods.get(normalized).contains(methodPath)) return null;
    var method:Dynamic = Reflect.field(target, methodPath);
    if (method == null) return null;
    try return Reflect.callMethod(target, method, args == null ? [] : args) catch (error:Dynamic) return null;
  }

  static function createSafeInstance(tag:String, className:String, args:Array<Dynamic>):Bool
  {
    if (!isSafeSaveIdentifier(tag) || scriptVariables.exists(tag)) return false;
    var constructor:Class<Dynamic> = resolveSafePsychClass(className);
    if (constructor == null || ["flixel.FlxG", "flixel.math.FlxMath", "flixel.tweens.FlxEase",
      "funkin.Conductor", "funkin.Paths", "funkin.play.PlayState"].contains(Type.getClassName(constructor))) return false;
    try
    {
      var instance:Dynamic = Type.createInstance(constructor, args == null ? [] : args);
      if (instance == null) return false;
      scriptVariables.set(tag, instance);
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] createInstance(' + tag + ') failed: ' + Std.string(error));
      return false;
    }
  }

  static function addSafeInstance(state:PlayState, tag:String, inFront:Bool):Bool
  {
    var instance:Dynamic = scriptVariables.get(tag);
    if (!Std.isOfType(instance, FlxBasic)) return false;
    if (inFront) state.add(cast instance);
    else state.insert(0, cast instance);
    return true;
  }

  #if (!flash && sys)
  static function shaderCacheKey(name:String):String
  {
    return PsychScriptRuntime.getExecutingScriptModDirectory() + "::" + name;
  }

  static function initLuaShader(name:String, glslVersion:Int):Bool
  {
    if (name == null || StringTools.trim(name).length == 0 || !Preferences.performanceStageShaders) return false;
    var shaderName:String = StringTools.trim(name);
    if (StringTools.endsWith(shaderName.toLowerCase(), ".frag")) shaderName = shaderName.substr(0, shaderName.length - 5);
    if (StringTools.endsWith(shaderName.toLowerCase(), ".vert")) shaderName = shaderName.substr(0, shaderName.length - 5);
    var key:String = shaderCacheKey(shaderName);
    if (runtimeShaderSources.exists(key)) return true;

    var fragment:Null<PsychScriptSource> = PsychModRuntime.getModFile("shaders/" + shaderName + ".frag");
    if (fragment == null) return false;
    var vertex:Null<PsychScriptSource> = PsychModRuntime.getModFile("shaders/" + shaderName + ".vert");
    runtimeShaderSources.set(key, [fragment.source, vertex == null ? null : vertex.source]);
    return true;
  }

  static function getRuntimeShader(state:PlayState, objectPath:String):Null<FlxRuntimeShader>
  {
    var object:Dynamic = getProperty(state, objectPath);
    if (!Std.isOfType(object, FlxSprite)) object = getSprite(state, objectPath);
    if (!Std.isOfType(object, FlxSprite)) return null;
    var shader:Dynamic = (cast object:FlxSprite).shader;
    return Std.isOfType(shader, FlxRuntimeShader) ? cast shader : null;
  }

  static function setSpriteShader(state:PlayState, objectPath:String, shaderName:String):Bool
  {
    if (shaderName == null || shaderName.length == 0) return false;
    var key:String = shaderCacheKey(shaderName);
    if (!runtimeShaderSources.exists(key) && !initLuaShader(shaderName, 120)) return false;
    var object:Dynamic = getProperty(state, objectPath);
    if (!Std.isOfType(object, FlxSprite)) object = getSprite(state, objectPath);
    if (!Std.isOfType(object, FlxSprite)) return false;
    var source:Array<String> = runtimeShaderSources.get(key);
    try
    {
      (cast object:FlxSprite).shader = new FlxRuntimeShader(source[0], source[1]);
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] Could not create runtime shader ' + shaderName + ': ' + Std.string(error));
      return false;
    }
  }
  #else
  static function initLuaShader(name:String, glslVersion:Int):Bool return false;
  static function setSpriteShader(state:PlayState, objectPath:String, shaderName:String):Bool return false;
  #end

  static function removeSpriteShader(state:PlayState, objectPath:String):Bool
  {
    var object:Dynamic = getProperty(state, objectPath);
    if (!Std.isOfType(object, FlxSprite)) object = getSprite(state, objectPath);
    if (!Std.isOfType(object, FlxSprite)) return false;
    (cast object:FlxSprite).shader = null;
    return true;
  }

  static function getSaveDataKey(name:String):String
  {
    return PsychScriptRuntime.getExecutingScriptModDirectory() + "::" + name;
  }

  static function getPsychAnimateSprite(state:PlayState, tag:String):Null<PsychAnimateSprite>
  {
    var sprite:Null<FlxSprite> = getSprite(state, tag);
    return sprite != null && Std.isOfType(sprite, PsychAnimateSprite) ? cast sprite : null;
  }

  static function parsePsychAnimateIndices(indices:Dynamic):Array<Int>
  {
    var result:Array<Int> = [];
    if (indices == null) return [0];
    if (Std.isOfType(indices, Array))
    {
      for (value in (cast indices:Array<Dynamic>))
      {
        if (value == null) continue;
        var parsed:Null<Int> = Std.parseInt(Std.string(value));
        if (parsed != null && parsed >= 0) result.push(parsed);
      }
    }
    else
    {
      for (part in Std.string(indices).split(","))
      {
        var parsed:Null<Int> = Std.parseInt(StringTools.trim(part));
        if (parsed != null && parsed >= 0) result.push(parsed);
      }
    }
    return result;
  }

  /**
   * Load a standard Adobe Animate atlas from the active Polymod asset set.
   * Psych's separate JSON override overload is rejected explicitly; the
   * supported atlas folder must contain Animation.json and its spritemaps.
   */
  static function loadPsychAnimateAtlas(sprite:PsychAnimateSprite, folderOrImg:Dynamic,
      ?spriteJson:Dynamic = null, ?animationJson:Dynamic = null):Bool
  {
    if (sprite == null || folderOrImg == null || !Std.isOfType(folderOrImg, String)) return false;
    if (spriteJson != null || animationJson != null)
    {
      trace('[Psych API] loadAnimateAtlas: separate JSON overrides are not supported; use the atlas folder containing Animation.json and its spritemaps.');
      return false;
    }

    var folder:String = StringTools.replace(StringTools.trim(Std.string(folderOrImg)), "\\", "/");
    if (StringTools.startsWith(folder, "images/")) folder = folder.substr("images/".length);
    while (StringTools.startsWith(folder, "./")) folder = folder.substr(2);
    if (folder.length == 0 || StringTools.startsWith(folder, "/")
      || (folder.length > 1 && folder.charAt(1) == ":")) return false;
    for (part in folder.split("/"))
      if (part == ".." || part == "." || part.length == 0) return false;

    try
    {
      sprite.loadTextureAtlas(folder);
      sprite.psychAtlasLoaded = true;
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych API] loadAnimateAtlas(' + folder + ') failed: ' + Std.string(error));
      return false;
    }
  }

  static function initSaveData(name:String, folder:String):Bool
  {
    var directory:String = PsychScriptRuntime.getExecutingScriptModDirectory();
    if (directory.length == 0 || !isSafeSaveIdentifier(name) || !isSafeSaveIdentifier(folder)) return false;
    var key:String = directory + "::" + name;
    if (activeSaves.exists(key)) return true;
    var save:FlxSave = new FlxSave();
    var savePath:String = Constants.SAVE_PATH + "/" + folder + "/" + directory;
    if (!save.bind(name, savePath)) return false;
    activeSaves.set(key, save);
    return true;
  }

  static function isSafeSaveIdentifier(value:String):Bool
  {
    if (value == null || value.length == 0 || value.length > 64) return false;
    for (i in 0...value.length)
    {
      var code:Int = value.charCodeAt(i);
      var safe:Bool = (code >= 48 && code <= 57) || (code >= 65 && code <= 90)
        || (code >= 97 && code <= 122) || code == 45 || code == 95;
      if (!safe) return false;
    }
    return true;
  }

  static function noteKeyStatus(state:PlayState, name:String, status:String):Bool
  {
    if (state == null || name == null) return false;
    return switch (StringTools.trim(name).toLowerCase())
    {
      case "left": status == "justPressed" ? state.controls.NOTE_LEFT_P : (status == "pressed" ? state.controls.NOTE_LEFT : state.controls.NOTE_LEFT_R);
      case "down": status == "justPressed" ? state.controls.NOTE_DOWN_P : (status == "pressed" ? state.controls.NOTE_DOWN : state.controls.NOTE_DOWN_R);
      case "up": status == "justPressed" ? state.controls.NOTE_UP_P : (status == "pressed" ? state.controls.NOTE_UP : state.controls.NOTE_UP_R);
      case "right": status == "justPressed" ? state.controls.NOTE_RIGHT_P : (status == "pressed" ? state.controls.NOTE_RIGHT : state.controls.NOTE_RIGHT_R);
      default:
        var method:Dynamic = Reflect.field(state.controls, status);
        if (method == null) return false;
        try return Reflect.callMethod(state.controls, method, [name]) == true catch (error:Dynamic) return false;
    };
  }

  static function gamepadButtonStatus(id:Int, name:String, status:String):Bool
  {
    if (name == null || name.length == 0) return false;
    var gamepad = FlxG.gamepads.getByID(id);
    if (gamepad == null) return false;
    var buttonSet:Dynamic = switch (status)
    {
      case "justPressed": gamepad.justPressed;
      case "pressed": gamepad.pressed;
      default: gamepad.justReleased;
    };
    return Reflect.getProperty(buttonSet, name) == true;
  }

  static function removeFromGroup(state:PlayState, group:String, index:Int, dontDestroy:Bool):Bool
  {
    var collection:Dynamic = resolveRoot(state, group);
    var item:Dynamic = getGroupMember(state, group, index);
    if (collection == null || item == null) return false;

    var members:Dynamic = Reflect.field(collection, "members");
    if (members != null)
    {
      var removeMethod:Dynamic = Reflect.field(collection, "remove");
      if (removeMethod == null) return false;
      if (!dontDestroy)
      {
        var killMethod:Dynamic = Reflect.field(item, "kill");
        if (killMethod != null) Reflect.callMethod(item, killMethod, []);
      }
      Reflect.callMethod(collection, removeMethod, [item, true]);
      if (!dontDestroy)
      {
        var destroyMethod:Dynamic = Reflect.field(item, "destroy");
        if (destroyMethod != null) Reflect.callMethod(item, destroyMethod, []);
      }
      return true;
    }

    if (Std.isOfType(collection, Array))
      return (cast collection:Array<Dynamic>).remove(item);
    return false;
  }

  static function getGroupMember(state:PlayState, group:String, index:Int):Dynamic
  {
    var collection:Dynamic = resolveRoot(state, group);
    if (collection == null || index < 0) return null;
    var members:Dynamic = Reflect.field(collection, "members");
    if (members != null)
      return index < members.length ? members[index] : null;
    return index < collection.length ? collection[index] : null;
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

  /**
   * Change the live BF/GF/DAD character using the same stage transaction used
   * during initial character construction. Old characters are retained as
   * hidden preloads so a later Psych Change Character event can switch back.
   */
  static function changePsychCharacter(state:PlayState, role:String, characterId:String):Bool
  {
    if (state == null || state.currentStage == null || characterId == null) return false;
    var requested:String = StringTools.trim(characterId);
    if (requested.length == 0) return false;

    var normalizedRole:String = StringTools.trim(role).toLowerCase();
    var propertyName:String;
    var current:Null<BaseCharacter>;
    switch (normalizedRole)
    {
      case "bf", "boyfriend", "player":
        normalizedRole = "bf";
        propertyName = "player";
        current = state.currentStage.getBoyfriend();
      case "gf", "girlfriend":
        normalizedRole = "gf";
        propertyName = "girlfriend";
        current = state.currentStage.getGirlfriend();
      case "dad", "opponent":
        normalizedRole = "dad";
        propertyName = "opponent";
        current = state.currentStage.getDad();
      default:
        return false;
    }

    if (current == null) return false;
    if (current.characterId == requested) return true;

    var replacement:Null<BaseCharacter> = preloadedCharacters.get(requested);
    if (replacement == null || !replacement.exists)
    {
      try
      {
        replacement = CharacterDataParser.fetchCharacter(requested);
      }
      catch (error:Dynamic)
      {
        trace('[Psych API] Could not load replacement character ' + requested + ': ' + Std.string(error));
        return false;
      }
    }
    if (replacement == null) return false;

    // Pop the active role only after the replacement is known to exist.
    var removed:Null<BaseCharacter> = switch (normalizedRole)
    {
      case "bf": state.currentStage.getBoyfriend(true);
      case "gf": state.currentStage.getGirlfriend(true);
      default: state.currentStage.getDad(true);
    };
    if (removed == null) return false;

    removed.visible = false;
    removed.active = false;
    preloadedCharacters.set(removed.characterId, removed);

    preloadedCharacters.remove(requested);
    replacement.debug = false;
    replacement.visible = true;
    replacement.active = true;
    state.currentStage.addCharacter(replacement, removed.characterType);
    applyPsychHealthBarColors(state);

    // Keep the live chart's legacy character mirrors synchronized. This does
    // not modify the package's on-disk chart or the saved mod content.
    if (state.currentChart != null && state.currentChart.characters != null)
      Reflect.setField(state.currentChart.characters, propertyName, requested);

    PsychScriptRuntime.setGlobal("boyfriendName",
      state.currentStage.getBoyfriend()?.characterId ?? "bf");
    PsychScriptRuntime.setGlobal("gfName",
      state.currentStage.getGirlfriend()?.characterId ?? "gf");
    PsychScriptRuntime.setGlobal("dadName",
      state.currentStage.getDad()?.characterId ?? "dad");
    return true;
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
      case "change scroll speed":
        // Psych's event uses value1 as a multiplier against the chart's base
        // scroll speed and value2 as a duration in seconds. Reuse PlayState's
        // native helper so both lanes tween together, playback-rate scaling is
        // respected, and pause/resume behavior stays consistent.
        if (state.currentChart != null && state.playerStrumline != null && state.opponentStrumline != null)
        {
          var multiplier:Float = parseFloatOr(value1, 1.0);
          var duration:Float = Math.max(0, parseFloatOr(value2, 0));
          if (!Math.isNaN(multiplier) && multiplier > 0)
          {
            var targetSpeed:Float = state.currentChart.scrollSpeed * multiplier;
            state.tweenScrollSpeed(targetSpeed, duration, FlxEase.linear,
              ["playerStrumline", "opponentStrumline"]);
          }
        }
      case "change character":
        var role:String = value1 == null || value1.length == 0 ? "bf" : value1;
        changePsychCharacter(state, role, value2);
      default:
        // Chart validation requires a matching custom_events script for
        // non-built-in events. Those scripts receive the event through the
        // standard Psych onEvent callback dispatched immediately below.
    }

    // Psych's onEvent callback is the entry point for custom event scripts.
    // Dispatch it for chart events and Lua-triggered events alike, after the
    // native built-in event has applied its own behavior.
    PsychScriptRuntime.dispatch("onEvent", [name, value1, value2]);
  }

  static function parseDynamicFloatOr(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;
    var parsed:Null<Float> = Std.parseFloat(Std.string(value));
    return parsed == null || Math.isNaN(parsed) ? fallback : parsed;
  }

  static function parseFloatOr(value:String, fallback:Float):Float
  {
    var result:Null<Float> = Std.parseFloat(value);
    return result == null || Math.isNaN(result) ? fallback : result;
  }
}

/** Psych-style animation offsets on NovaBeat's native Adobe Animate sprite. */
@:nullSafety(Off)
class PsychAnimateSprite extends FunkinSprite
{
  public var psychAtlasLoaded:Bool = false;
  final psychAnimOffsets:Map<String, Array<Float>> = [];

  public function new(x:Float = 0, y:Float = 0)
  {
    super(x, y);
  }

  public function addOffset(name:String, x:Float, y:Float):Void
  {
    if (name == null || name.length == 0) return;
    psychAnimOffsets.set(name, [x, y]);
  }

  public function playPsychAnimation(name:String, force:Bool = false, reverse:Bool = false, startFrame:Int = 0):Void
  {
    if (name == null || name.length == 0) return;
    anim.play(name, force, reverse, startFrame);
    var values:Null<Array<Float>> = psychAnimOffsets.get(name);
    if (values != null && values.length >= 2) offset.set(values[0], values[1]);
  }
}
