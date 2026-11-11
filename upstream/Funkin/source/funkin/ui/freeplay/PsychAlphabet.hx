package funkin.ui.freeplay;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.Paths;

/**
 * Psych Engine 0.7.3 bold Alphabet glyphs.
 *
 * This is a focused port of Psych's original Alphabet/AlphaCharacter rendering
 * path, including its per-glyph offsets and horizontal-only menu scaling.
 */
@:nullSafety(Off)
class PsychAlphabet extends FlxSpriteGroup
{
  static var sharedAtlas:Null<FlxAtlasFrames> = null;

  public var targetY:Int = 0;
  public var textWidth:Float = 0;

  var letters:Array<FlxSprite> = [];
  var baseX:Array<Float> = [];
  var baseY:Array<Float> = [];
  var baseOffsetX:Array<Float> = [];
  var baseOffsetY:Array<Float> = [];
  var baseTextWidth:Float = 0;

  public function new(x:Float, y:Float, text:String)
  {
    super(x, y);

    var cursor:Float = 0;
    var row:Int = 0;
    var rowWidths:Array<Float> = [];
    var consecutiveSpaces:Int = 0;
    var atlas = getAtlas();

    for (character in text.split(''))
    {
      if (character == " " || character == "_")
      {
        consecutiveSpaces++;
        continue;
      }

      if (character == "\n")
      {
        rowWidths[row] = cursor;
        cursor = 0;
        consecutiveSpaces = 0;
        row++;
        continue;
      }

      if (consecutiveSpaces > 0)
      {
        cursor += 28 * consecutiveSpaces;
        consecutiveSpaces = 0;
      }

      var lowercase:String = character.toLowerCase();
      var definition:PsychGlyphDefinition = getGlyphDefinition(lowercase);
      var animationName:String = definition.anim ?? lowercase;
      var prefix:String = animationName + " bold";

      var letter:FlxSprite = new FlxSprite();
      // Each glyph is drawn as its own sprite by FlxSpriteGroup. Keep the
      // glyph itself in screen space so gameplay camera scroll cannot hide
      // the Psych Freeplay song list.
      letter.scrollFactor.set(0, 0);
      letter.frames = atlas;
      letter.antialiasing = true;
      letter.animation.addByPrefix(prefix, prefix, 24);
      letter.animation.play(prefix, true);

      if (letter.animation.curAnim == null)
      {
        prefix = "question bold";
        letter.animation.addByPrefix(prefix, prefix, 24);
        letter.animation.play(prefix, true);
      }

      letter.updateHitbox();

      var offsetX:Float = definition.offsetsBold[0];
      var offsetY:Float = definition.offsetsBold[1];
      letter.x = cursor;
      letter.y = row * 85;
      letter.offset.x = offsetX;
      letter.offset.y = offsetY - (70 - letter.height);

      add(letter);
      letters.push(letter);
      baseX.push(cursor);
      baseY.push(row * 85);
      baseOffsetX.push(offsetX);
      baseOffsetY.push(offsetY);

      // Psych's bold Alphabet advances by the glyph width plus its bold X offset.
      cursor += letter.width + offsetX;
    }

    rowWidths[row] = cursor;
    for (width in rowWidths)
      if (width > baseTextWidth) baseTextWidth = width;

    textWidth = baseTextWidth;
  }

  /** Match Psych's Freeplay long-song-name horizontal compression. */
  public function setMenuScale(value:Float):Void
  {
    var targetScale:Float = Math.max(0.01, value);
    textWidth = baseTextWidth * targetScale;

    for (i in 0...letters.length)
    {
      var letter:FlxSprite = letters[i];
      letter.scale.x = targetScale;
      letter.scale.y = 1.0;
      letter.updateHitbox();
      letter.x = baseX[i] * targetScale;
      letter.y = baseY[i];
      letter.offset.x = baseOffsetX[i] * targetScale;
      letter.offset.y = baseOffsetY[i] - (70 - letter.height);
    }
  }

  static function getAtlas():FlxAtlasFrames
  {
    if (sharedAtlas == null)
      sharedAtlas = Paths.getSparrowAtlas("alphabet", "shared");
    return sharedAtlas;
  }

  static function getGlyphDefinition(character:String):PsychGlyphDefinition
  {
    return switch (character)
    {
      case "ç": {anim: null, offsetsBold: [0, -11]};
      case "&": {anim: null, offsetsBold: [0, 2]};
      case "(": {anim: null, offsetsBold: [0, 0]};
      case ")": {anim: null, offsetsBold: [0, 0]};
      case "]": {anim: null, offsetsBold: [0, -1]};
      case "*": {anim: null, offsetsBold: [0, 40]};
      case "+": {anim: null, offsetsBold: [0, 12]};
      case "-": {anim: null, offsetsBold: [0, 16]};
      case "<": {anim: null, offsetsBold: [0, -2]};
      case ">": {anim: null, offsetsBold: [0, -2]};
      case "'": {anim: "apostrophe", offsetsBold: [0, 40]};
      case '"': {anim: "quote", offsetsBold: [0, 40]};
      case "!": {anim: "exclamation", offsetsBold: [0, 0]};
      case "?": {anim: "question", offsetsBold: [0, 0]};
      case ".": {anim: "period", offsetsBold: [0, 0]};
      case "❝": {anim: "start quote", offsetsBold: [0, 40]};
      case "❞": {anim: "end quote", offsetsBold: [0, 40]};
      case ":": {anim: null, offsetsBold: [0, 8]};
      case ";": {anim: null, offsetsBold: [0, 4]};
      case "^": {anim: null, offsetsBold: [0, 38]};
      case ",": {anim: "comma", offsetsBold: [0, -4]};
      case "\\": {anim: "back slash", offsetsBold: [0, 0]};
      case "/": {anim: "forward slash", offsetsBold: [0, 0]};
      case "~": {anim: null, offsetsBold: [0, 20]};
      case "•": {anim: "bullet", offsetsBold: [0, 20]};
      case "¡": {anim: "inverted exclamation", offsetsBold: [0, -20]};
      case "¿": {anim: "inverted question", offsetsBold: [0, -20]};
      default: {anim: null, offsetsBold: [0, 0]};
    };
  }

  public function setMenuPosition(x:Float, y:Float):Void
  {
    setPosition(x, y);
  }

  public function setMenuAlpha(value:Float):Void
  {
    for (letter in letters)
      letter.alpha = value;
  }
}

private typedef PsychGlyphDefinition =
{
  var anim:Null<String>;
  var offsetsBold:Array<Float>;
};
