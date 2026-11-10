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

  public function new(x:Float, y:Float, text:String)
  {
    super();
    setMenuPosition(x, y);
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
      letter.x = x + cursor;
      letter.y = y + offsetY;
      add(letter);
      letters.push(letter);
      cursor += letter.width;
    }
    textWidth = cursor;
  }

  static function getAtlas():FlxAtlasFrames
  {
    if (sharedAtlas == null) sharedAtlas = Paths.getSparrowAtlas('alphabet', 'shared');
    return sharedAtlas;
  }

  public function setMenuPosition(x:Float, y:Float):Void
  {
    var deltaX:Float = x - this.x;
    var deltaY:Float = y - this.y;
    this.x = x;
    this.y = y;
    for (letter in letters)
      letter.setPosition(letter.x + deltaX, letter.y + deltaY);
  }

  public function setMenuAlpha(value:Float):Void
  {
    for (letter in letters) letter.alpha = value;
  }
}
