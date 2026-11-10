package funkin.ui.freeplay;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.Paths;

/**
 * Psych's animated sprite-letter treatment, isolated from the V-Slice font UI.
 * Positions are managed by PsychFreeplayState to retain the original list motion.
 */
@:nullSafety(Off)
class PsychAlphabet extends FlxSpriteGroup
{
  static var sharedAtlas:Null<FlxAtlasFrames> = null;
  public var targetY:Int = 0;
  public var textWidth:Float = 0;
  var letters:Array<FlxSprite> = [];
  var baseX:Array<Float> = [];
  var baseOffsetY:Array<Float> = [];

  public function new(x:Float, y:Float, text:String)
  {
    super(x, y);
    var atlas = getAtlas();
    var cursor:Float = 0;

    for (character in text.split(''))
    {
      if (character == ' ')
      {
        cursor += 28;
        continue;
      }

      var letter = new FlxSprite();
      letter.frames = atlas;
      letter.antialiasing = true;

      var lowercase = character.toLowerCase();
      var animationName = switch (lowercase)
      {
        case "'": "apostrophe";
        case '"': "quote";
        case "!": "exclamation";
        case "?": "question";
        case ".": "period";
        case ",": "comma";
        case "/": "forward slash";
        case "\\": "back slash";
        case "•": "bullet";
        case "¡": "inverted exclamation";
        case "¿": "inverted question";
        default: lowercase;
      };
      var prefix = animationName + " bold";
      letter.animation.addByPrefix(prefix, prefix, 24);
      letter.animation.play(prefix, true);
      if (letter.animation.curAnim == null)
      {
        prefix = "question bold";
        letter.animation.addByPrefix(prefix, prefix, 24);
        letter.animation.play(prefix, true);
      }
      letter.updateHitbox();

      var offsetY:Float = switch (lowercase)
      {
        case "'": 40;
        case '"': 40;
        case "*": 40;
        case "+": 12;
        case "-": 16;
        case "^": 38;
        case ",": -4;
        case ":": 8;
        case ";": 4;
        case "~": 20;
        case "•": 20;
        default: 0;
      };
      letter.x = cursor;
      letter.y = 0;
      letter.offset.y = offsetY - (70 - letter.height);
      add(letter);
      letters.push(letter);
      baseX.push(cursor);
      baseOffsetY.push(offsetY);
      cursor += letter.width;
    }
    textWidth = cursor;
  }

  /** Match the scale clamp used by Psych's original Alphabet Freeplay items. */
  public function setMenuScale(value:Float):Void
  {
    var targetScale:Float = Math.max(0.01, value);
    textWidth = 0;
    for (i in 0...letters.length)
    {
      var letter = letters[i];
      letter.scale.set(targetScale, targetScale);
      letter.updateHitbox();
      letter.x = baseX[i] * targetScale;
      letter.y = 0;
      letter.offset.y = baseOffsetY[i] * targetScale - (70 * targetScale - letter.height);
      textWidth = Math.max(textWidth, letter.x + letter.width);
    }
  }

  static function getAtlas():FlxAtlasFrames
  {
    if (sharedAtlas == null) sharedAtlas = Paths.getSparrowAtlas('alphabet', 'shared');
    return sharedAtlas;
  }

  public function setMenuPosition(x:Float, y:Float):Void
  {
    this.setPosition(x, y);
  }

  public function setMenuAlpha(value:Float):Void
  {
    for (letter in letters) letter.alpha = value;
  }
}
