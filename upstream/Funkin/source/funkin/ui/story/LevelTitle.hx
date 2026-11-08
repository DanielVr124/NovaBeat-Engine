package funkin.ui.story;

import flixel.FlxSprite;
import flixel.math.FlxRect;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import funkin.util.MathUtil;

class LevelTitle extends FlxSpriteGroup
{
  static final LOCK_PAD:Int = 4;

  public final level:Level;
  public var targetY:Float;

  var title:FlxSprite;
  var lock:FlxSprite;

  // Keep the lock's intended state separate from the carousel visibility.
  // FlxSpriteGroup.visible propagates to all children, so the carousel uses
  // setDisplayVisible() to hide only the week title and preserve lock state.
  var displayVisible:Bool = true;
  var lockRequested:Bool = false;

  public function new(x:Int, y:Int, level:Level)
  {
    super(x, y);

    this.level = level;

    if (this.level == null) throw 'Level cannot be null!';

    buildLevelTitle();
    buildLevelLock();
  }

  override function get_width():Float
  {
    if (length == 0) return 0;

    if (lock.visible)
    {
      return title.width + lock.width + LOCK_PAD;
    }
    else
    {
      return title.width;
    }
  }

  public var isFlashing:Bool = false;

  var flashTick:Float = 0;
  final flashFramerate:Float = 20;

  override public function update(elapsed:Float):Void
  {
    this.y = MathUtil.smoothLerpPrecision(y, targetY, elapsed, 0.451);

    if (isFlashing)
    {
      flashTick += elapsed;
      if (flashTick >= 1 / flashFramerate)
      {
        flashTick %= 1 / flashFramerate;
        title.color = (title.color == FlxColor.WHITE) ? 0xFF33ffff : FlxColor.WHITE;
      }
    }
  }

  /**
   * Show or hide the week title without changing the FlxSpriteGroup's own
   * visibility. Changing the group's visibility propagates to every child
   * and would turn the lock sprite on again when a hidden week returns.
   */
  public function setDisplayVisible(value:Bool):Void
  {
    displayVisible = value;
    title.visible = value;
    lock.visible = value && lockRequested;
  }

  /**
   * Clip both the week title and its lock icon to NovaBeat's lower carousel
   * panel. The crop is recalculated while the group animates so sprites never
   * draw over the custom background above the panel.
   */
  public function clipToPanel(panelTop:Float, panelBottom:Float):Void
  {
    clipChildToPanel(title, panelTop, panelBottom);
    clipChildToPanel(lock, panelTop, panelBottom);
  }

  public function clearPanelClip():Void
  {
    title.clipRect = null;
    lock.clipRect = null;
  }

  function clipChildToPanel(sprite:FlxSprite, panelTop:Float, panelBottom:Float):Void
  {
    if (sprite == null || sprite.frame == null) return;

    var scaleY:Float = Math.max(0.0001, Math.abs(sprite.scale.y));
    var worldTop:Float = this.y + sprite.y;
    var cropTop:Float = Math.max(0, (panelTop - worldTop) / scaleY);
    var cropBottom:Float = Math.min(sprite.frameHeight, (panelBottom - worldTop) / scaleY);

    if (cropTop <= 0 && cropBottom >= sprite.frameHeight)
    {
      if (sprite.clipRect != null) sprite.clipRect = null;
      return;
    }

    // Clip rectangles are pixel-aligned. Rounding before comparing keeps
    // fractional tween movement from replacing the rectangle every frame.
    var clipY:Float = Math.floor(cropTop);
    var clipBottom:Float = Math.ceil(cropBottom);
    var clipHeight:Float = Math.max(0, clipBottom - clipY);
    var currentClip:Null<FlxRect> = sprite.clipRect;

    if (currentClip != null && currentClip.x == 0 && currentClip.y == clipY
      && currentClip.width == sprite.frameWidth && currentClip.height == clipHeight) return;

    if (clipHeight <= 0)
      sprite.clipRect = FlxRect.get(0, 0, 0, 0);
    else
      sprite.clipRect = FlxRect.get(0, clipY, sprite.frameWidth, clipHeight);
  }

  public function showLock():Void
  {
    if (lockRequested) return;

    lockRequested = true;
    lock.visible = displayVisible;
    this.x -= (lock.width + LOCK_PAD) / 2;
  }

  public function hideLock():Void
  {
    if (!lockRequested) return;

    lockRequested = false;
    lock.visible = false;
    this.x += (lock.width + LOCK_PAD) / 2;
  }

  function buildLevelTitle():Void
  {
    title = level.buildTitleGraphic();
    add(title);
  }

  function buildLevelLock():Void
  {
    lock = new FlxSprite(0, 0).loadGraphic(Paths.image('storymenu/ui/lock'));
    lock.x = title.x + title.width + LOCK_PAD;
    lock.visible = false;
    add(lock);
  }
}
