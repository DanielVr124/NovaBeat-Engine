package funkin.modding.psychlua;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.Conductor;
import funkin.play.PlayState;

/**
 * Psych-compatible time bar for imported Psych songs only.
 *
 * Its two clipped layers follow Psych's Bar.setColors semantics: left is the
 * elapsed/fill segment, right is the remaining/empty segment.
 */
@:nullSafety(Off)
class PsychTimeBar extends FlxSpriteGroup
{
  public final background:FlxSprite;
  public final leftFill:FlxSprite;
  public final rightFill:FlxSprite;
  public final timeText:FlxText;

  public var timeBarType:String = "Time Left";
  public var percent(default, null):Float = 0;

  final owner:PlayState;
  final barWidth:Int;
  final barHeight:Int = 10;
  final leftClip:FlxRect;
  final rightClip:FlxRect;

  public function new(owner:PlayState)
  {
    super();
    this.owner = owner;

    // Psych Engine uses a compact ~400px time bar rather than stretching
    // it across nearly the whole viewport. Cap the desktop width at that
    // proportion and shrink only when the available screen is narrower.
    barWidth = Std.int(Math.max(1, Math.min(400, FlxG.width - 32)));
    var barX:Float = (FlxG.width - barWidth) / 2;
    var textY:Float = 18;
    var textWidth:Float = barWidth;

    timeText = new FlxText(barX, textY, textWidth, "0:00", 18);
    timeText.color = FlxColor.WHITE;
    timeText.alignment = "center";
    timeText.borderSize = 1;
    timeText.borderColor = FlxColor.BLACK;

    var barY:Float = textY + timeText.height / 4;
    background = new FlxSprite(barX, barY).makeGraphic(barWidth, barHeight, 0xFF303030);
    leftFill = new FlxSprite(barX, barY).makeGraphic(barWidth, barHeight, FlxColor.WHITE);
    rightFill = new FlxSprite(barX, barY).makeGraphic(barWidth, barHeight, FlxColor.BLACK);

    leftClip = new FlxRect(0, 0, 0, barHeight);
    rightClip = new FlxRect(0, 0, barWidth, barHeight);
    leftFill.clipRect = leftClip;
    rightFill.clipRect = rightClip;

    for (object in [background, leftFill, rightFill, timeText])
    {
      object.scrollFactor.set();
      object.cameras = [owner.camHUD];
      add(object);
    }
  }

  public function setColors(left:Dynamic, right:Dynamic):Void
  {
    var leftColor:Null<FlxColor> = parseColor(left);
    var rightColor:Null<FlxColor> = parseColor(right);
    if (leftColor != null) leftFill.color = leftColor;
    if (rightColor != null) rightFill.color = rightColor;
  }

  static function parseColor(value:Dynamic):Null<FlxColor>
  {
    if (value == null) return null;
    if (Std.isOfType(value, Int)) return cast value;
    var raw:String = StringTools.trim(Std.string(value));
    if (raw.length == 0) return null;
    try
    {
      return FlxColor.fromString(raw);
    }
    catch (error:Dynamic)
    {
      return null;
    }
  }

  override public function update(elapsed:Float):Void
  {
    if (owner != null)
    {
      var length:Float = FlxG.sound.music == null ? 0 : FlxG.sound.music.length;
      var position:Float = Conductor.instance == null ? 0 : Conductor.instance.songPosition;
      percent = length <= 0 ? 0 : Math.max(0, Math.min(1, position / length));

      var filledWidth:Float = Math.max(0, Math.min(barWidth, percent * barWidth));
      leftClip.set(0, 0, filledWidth, barHeight);
      rightClip.set(filledWidth, 0, barWidth - filledWidth, barHeight);
      // Flixel needs the clip-rect property re-assigned to refresh its frame.
      leftFill.clipRect = leftClip;
      rightFill.clipRect = rightClip;

      var displayMode:String = timeBarType == null ? "time left" : StringTools.trim(timeBarType).toLowerCase();
      visible = displayMode != "disabled";
      if (displayMode == "song name")
      {
        timeText.text = owner.currentSong == null ? "" : owner.currentSong.songName;
      }
      else
      {
        var elapsedTime:Bool = displayMode == "time elapsed";
        var displayTime:Float = elapsedTime ? Math.max(0, position) : Math.max(0, length - position);
        var totalSeconds:Int = Std.int(Math.floor(displayTime / 1000));
        var minutes:Int = Std.int(totalSeconds / 60);
        var seconds:Int = totalSeconds % 60;
        timeText.text = Std.string(minutes) + ":" + StringTools.lpad(Std.string(seconds), "0", 2);
      }
    }

    super.update(elapsed);
  }
}
