package funkin.modding.psychlua;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.Paths;
import funkin.play.PlayState;
import haxe.Json;

/**
 * An isolated renderer for the classic Psych 0.7.x dialogue JSON shape.
 *
 * This intentionally does not replace NovaBeat's native conversation UI.
 * It reads the owning Psych package's dialogue and portrait metadata and
 * exposes the usual advance/finish flow to the Psych script runtime.
 */
@:nullSafety(Off)
class PsychDialogueOverlay extends FlxSpriteGroup
{
  final owner:PlayState;
  final lines:Array<Dynamic>;
  final onFinished:Void->Void;
  final portraits:Map<String, PsychDialoguePortrait> = [];

  final shade:FlxSprite;
  final panel:FlxSprite;
  final speakerText:FlxText;
  final dialogueText:FlxText;

  var lineIndex:Int = -1;
  var fullText:String = "";
  var revealed:Int = 0;
  var typingElapsed:Float = 0;
  var typeSpeed:Float = 0.05;
  var typeSound:String = "dialogue";
  var finishing:Bool = false;

  public function new(owner:PlayState, lines:Array<Dynamic>, onFinished:Void->Void)
  {
    super();
    this.owner = owner;
    this.lines = lines;
    this.onFinished = onFinished;

    shade = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    shade.alpha = 0.48;

    var panelWidth:Int = Std.int(Math.max(280, FlxG.width - 96));
    var panelX:Float = (FlxG.width - panelWidth) / 2;
    var panelY:Float = FlxG.height - 206;
    panel = new FlxSprite(panelX, panelY).makeGraphic(panelWidth, 164, 0xE0181B23);

    speakerText = new FlxText(panelX + 22, panelY + 12, panelWidth - 44, "", 22);
    speakerText.color = 0xFF63DDF4;
    dialogueText = new FlxText(panelX + 22, panelY + 48, panelWidth - 44, "", 20);
    dialogueText.color = FlxColor.WHITE;
    dialogueText.wordWrap = true;

    for (object in [shade, panel, speakerText, dialogueText])
    {
      object.scrollFactor.set();
      object.cameras = [owner.camHUD];
      add(object);
    }

    showNextLine();
  }

  function showNextLine():Void
  {
    lineIndex++;
    if (lineIndex >= lines.length)
    {
      finish();
      return;
    }

    var line:Dynamic = lines[lineIndex];
    if (line == null)
    {
      showNextLine();
      return;
    }

    var portraitId:String = readString(line, "portrait", "bf");
    var expression:String = readString(line, "expression", "");
    var boxState:String = readString(line, "boxState", "normal");
    fullText = readString(line, "text", " ");
    if (fullText.length == 0) fullText = " ";

    typeSpeed = readFloat(line, "speed", 0.05);
    if (typeSpeed <= 0 || Math.isNaN(typeSpeed)) typeSpeed = 0.05;
    typeSound = readString(line, "sound", "dialogue");

    revealed = 0;
    typingElapsed = 0;
    dialogueText.text = "";

    speakerText.text = portraitId.length > 0
      ? portraitId.substr(0, 1).toUpperCase() + portraitId.substr(1)
      : " ";

    if (boxState.toLowerCase() == "angry")
    {
      panel.color = 0xE02A1117;
      speakerText.color = 0xFFFF7B7B;
    }
    else
    {
      panel.color = 0xE0181B23;
      speakerText.color = 0xFF63DDF4;
    }

    var portrait:Null<PsychDialoguePortrait> = getPortrait(portraitId);
    for (character in portraits)
    {
      character.alpha = character == portrait ? 1 : 0.18;
      character.visible = true;
    }

    if (portrait != null) portrait.playExpression(expression);
    PsychScriptRuntime.dispatch("onNextDialogue", [lineIndex]);
  }

  function getPortrait(id:String):Null<PsychDialoguePortrait>
  {
    if (id == null || id.length == 0) return null;
    if (portraits.exists(id)) return portraits.get(id);

    var metadata = PsychModRuntime.getModAssetFile(owner.currentSong.id, "images/dialogue/" + id + ".json");
    if (metadata == null) return null;

    try
    {
      var config:Dynamic = Json.parse(metadata.source);
      var image:String = readString(config, "image", "");
      if (image.length == 0) return null;

      var character = new PsychDialoguePortrait(id, config, image, owner.camHUD);
      portraits.set(id, character);
      add(character);
      return character;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Dialogue] Could not load portrait metadata for ' + id + ': ' + Std.string(error));
      return null;
    }
  }

  public function advance():Void
  {
    if (finishing) return;

    if (revealed < fullText.length)
    {
      revealed = fullText.length;
      dialogueText.text = fullText;
      return;
    }

    try
    {
      FlxG.sound.play(Paths.sound("dialogueClose"), 0.65);
    }
    catch (error:Dynamic)
    {
      // This optional sound can be absent from a mod package.
    }
    showNextLine();
  }

  override public function update(elapsed:Float):Void
  {
    if (!finishing && revealed < fullText.length)
    {
      typingElapsed += elapsed;
      while (typingElapsed >= typeSpeed && revealed < fullText.length)
      {
        typingElapsed -= typeSpeed;
        var currentChar:String = fullText.charAt(revealed);
        revealed++;
        dialogueText.text = fullText.substr(0, revealed);

        if (typeSound.length > 0 && currentChar != " " && currentChar != "\n")
        {
          try
          {
            FlxG.sound.play(Paths.sound(typeSound), 0.28);
          }
          catch (error:Dynamic)
          {
            // A missing optional dialogue voice sound must not break dialogue.
          }
        }
      }
    }

    super.update(elapsed);
  }

  function finish():Void
  {
    if (finishing) return;
    finishing = true;
    kill();
    onFinished();
  }

  static function readString(object:Dynamic, field:String, fallback:String):String
  {
    var value:Dynamic = Reflect.field(object, field);
    if (value == null) return fallback;
    return Std.string(value);
  }

  static function readFloat(object:Dynamic, field:String, fallback:Float):Float
  {
    var value:Dynamic = Reflect.field(object, field);
    if (value == null) return fallback;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return value;
    var parsed:Null<Float> = Std.parseFloat(Std.string(value));
    return parsed == null ? fallback : parsed;
  }
}

/**
 * Minimal reader for Psych's images/dialogue/<portrait>.json metadata. It
 * supports Sparrow atlases, named expressions, portrait positions and scale.
 */
@:nullSafety(Off)
class PsychDialoguePortrait extends FlxSprite
{
  final portraitId:String;
  final positionKind:String;
  final animationNames:Array<String> = [];

  public function new(id:String, config:Dynamic, image:String, camera:flixel.FlxCamera)
  {
    super(0, 0);
    portraitId = id;
    positionKind = readString(config, "dialogue_pos", "left").toLowerCase();

    frames = Paths.getSparrowAtlas("dialogue/" + image);
    antialiasing = Reflect.field(config, "no_antialiasing") != true;

    var animations:Dynamic = Reflect.field(config, "animations");
    if (Std.isOfType(animations, Array))
    {
      for (entry in (cast animations:Array<Dynamic>))
      {
        var animationName:String = readString(entry, "anim", "");
        var loopName:String = readString(entry, "loop_name", "");
        var idleName:String = readString(entry, "idle_name", loopName);
        if (animationName.length == 0 || loopName.length == 0) continue;

        animation.addByPrefix(animationName, loopName, 24, false);
        if (idleName.length > 0)
          animation.addByPrefix(animationName + "-idle", idleName, 24, true);
        animationNames.push(animationName);
      }
    }

    var scale:Float = readFloat(config, "scale", 1) * 0.7;
    if (scale <= 0) scale = 0.7;
    setGraphicSize(Std.int(width * scale));
    updateHitbox();

    var offsets:Dynamic = Reflect.field(config, "position");
    var offsetX:Float = arrayFloat(offsets, 0);
    var offsetY:Float = arrayFloat(offsets, 1);

    switch (positionKind)
    {
      case "center":
        x = (FlxG.width - width) / 2;
        y = FlxG.height - 206 - height + 16;
      case "right":
        x = FlxG.width - width - 100;
        y = 58;
      default:
        x = -60;
        y = 58;
    }

    x += offsetX;
    y += offsetY;
    scrollFactor.set();
    cameras = [camera];
    alpha = 0.18;
  }

  public function playExpression(expression:String):Void
  {
    if (animationNames.length == 0) return;
    var selected:String = expression;
    if (selected == null || selected.length == 0 || !animationNames.contains(selected))
      selected = animationNames[0];
    animation.play(selected, true);
  }

  static function readString(object:Dynamic, field:String, fallback:String):String
  {
    var value:Dynamic = Reflect.field(object, field);
    return value == null ? fallback : Std.string(value);
  }

  static function readFloat(object:Dynamic, field:String, fallback:Float):Float
  {
    var value:Dynamic = Reflect.field(object, field);
    if (value == null) return fallback;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return value;
    var parsed:Null<Float> = Std.parseFloat(Std.string(value));
    return parsed == null ? fallback : parsed;
  }

  static function arrayFloat(values:Dynamic, index:Int):Float
  {
    if (!Std.isOfType(values, Array)) return 0;
    var items:Array<Dynamic> = cast values;
    if (index < 0 || index >= items.length || items[index] == null) return 0;
    return Std.parseFloat(Std.string(items[index]));
  }
}
