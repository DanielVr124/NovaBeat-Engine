package funkin.modding.psychlua;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.Conductor;
import funkin.play.PlayState;

/**
 * Small HUD time bar used only by imported Psych songs.
 *
 * NovaBeat does not have Psych's legacy time-bar widget, so this gives scripts
 * a real live bar and text field rather than a no-op setTimeBarColors callback.
 * It stays isolated from native FNF/V-Slice songs.
 */
@:nullSafety(Off)
class PsychTimeBar extends FlxSpriteGroup
{
  public final background:FlxSprite;
  public final leftFill:FlxSprite;
  public final rightFill:FlxSprite;
  public final timeText:FlxText;

  public var timeBarType:String = "timeLeft";
  public var percent(default, null):Float = 0;

  final owner:PlayState;
  final halfWidth:Int;
  final rightWidth:Int;
  final barHeight:Int = 10;

  public function new(owner:PlayState)
  {
    super();
    this.owner = owner;

    var barWidth:Int = Std.int(Math.max(240, FlxG.width - 160));
    halfWidth = Std.int(barWidth / 2);
    rightWidth = barWidth - halfWidth;
    var barX:Float = (FlxG.width - barWidth) / 2;
    var barY:Float = 18;

    background = new FlxSprite(barX, barY).makeGraphic(barWidth, barHeight, 0xFF303030);
    leftFill = new FlxSprite(barX, barY).makeGraphic(halfWidth, barHeight, 0xFF00D7FF);
    rightFill = new FlxSprite(barX + halfWidth, barY).makeGraphic(rightWidth, barHeight, 0xFF00D7FF);

    // Scale from the top-left so the progress masks grow in the same direction.
    leftFill.origin.set(0, 0);
    rightFill.origin.set(0, 0);
    leftFill.scale.x = 0;
    rightFill.scale.x = 0;

    timeText = new FlxText(barX, barY + 13, barWidth, "0:00", 14);
    timeText.color = FlxColor.WHITE;
    timeText.alignment = CENTER;

    for (object in [background, leftFill, rightFill, timeText])
    {
      object.scrollFactor.set();
      object.cameras = [owner.camHUD];
      add(object);
    }
  }

  public function setColors(left:Dynamic, right:Dynamic):Void
  {
    leftFill.color = parseColor(left, 0xFF00D7FF);
    rightFill.color = parseColor(right, 0xFF00D7FF);
  }

  static function parseColor(value:Dynamic, fallback:FlxColor):FlxColor
  {
    if (value == null) return fallback;
    if (Std.isOfType(value, Int)) return cast value;
    var raw:String = StringTools.trim(Std.string(value));
    if (raw.length == 0) return fallback;
    try
    {
      var parsed:FlxColor = FlxColor.fromString(raw);
      return parsed;
    }
    catch (error:Dynamic)
    {
      return fallback;
    }
  }

  override public function update(elapsed:Float):Void
  {
    if (owner != null)
    {
      var length:Float = owner.currentSongLengthMs;
      var position:Float = Conductor.instance == null ? 0 : Conductor.instance.songPosition;
      percent = length <= 0 ? 0 : Math.max(0, Math.min(1, position / length));

      var filledWidth:Float = percent * (halfWidth + rightWidth);
      leftFill.scale.x = Math.max(0, Math.min(1, filledWidth / halfWidth));
      rightFill.scale.x = Math.max(0, Math.min(1, (filledWidth - halfWidth) / rightWidth));

      var displayTime:Float = timeBarType != null && timeBarType.toLowerCase() == "elapsed"
        ? Math.max(0, position)
        : Math.max(0, length - position);
      var totalSeconds:Int = Std.int(Math.floor(displayTime / 1000));
      var minutes:Int = Std.int(totalSeconds / 60);
      var seconds:Int = totalSeconds % 60;
      timeText.text = Std.string(minutes) + ":" + StringTools.lpad(Std.string(seconds), "0", 2);
    }

    super.update(elapsed);
  }
}
