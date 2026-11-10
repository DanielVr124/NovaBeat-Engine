package funkin.mobile.ui;

import flixel.FlxCamera;
import flixel.FlxObject;
import funkin.ui.TextMenuList;
import funkin.util.TouchUtil;

/**
 * Adds generous, full-row touch targets to text-only mobile menu lists.
 *
 * TextMenuItem uses a transparent backing sprite sized from its label. Some
 * mobile pointer paths do not consistently hit that transparent sprite,
 * especially after camera/layout changes. These independent FlxObject bounds
 * use the same menu camera and preserve normal keyboard/controller navigation.
 */
class MobileMenuTouchTargets
{
  public static function sync(items:TextMenuList, targets:Array<FlxObject>, viewportWidth:Float,
      minHeight:Float = 64, verticalPadding:Float = 16):Void
  {
    while (targets.length < items.length)
      targets.push(new FlxObject());

    while (targets.length > items.length)
      targets.pop().destroy();

    for (index in 0...items.length)
    {
      var item = items.members[index];
      var target = targets[index];

      var desiredHeight:Float = Math.max(minHeight, item.height + verticalPadding * 2);
      var maxHeight:Float = 180;
      if (index > 0)
        maxHeight = Math.min(maxHeight, Math.abs(item.y - items.members[index - 1].y) * 0.88);
      if (index + 1 < items.length)
        maxHeight = Math.min(maxHeight, Math.abs(items.members[index + 1].y - item.y) * 0.88);

      var hitHeight:Float = Math.max(1, Math.min(desiredHeight, maxHeight));
      target.x = 0;
      target.y = item.y + (item.height - hitHeight) * 0.5;
      target.width = Math.max(1, viewportWidth);
      target.height = hitHeight;
    }
  }

  /**
   * Accept the first visible row hit by a just-completed mobile tap.
   * Pointer/touch releases are consumed here, so callers should disable the
   * TextMenuList's own pointer-selection path while these targets are active.
   */
  public static function tryAccept(items:TextMenuList, targets:Array<FlxObject>, camera:FlxCamera):Bool
  {
    if (items == null || camera == null) return false;

    var count:Int = Std.int(Math.min(items.length, targets.length));
    for (index in 0...count)
    {
      if (TouchUtil.pressAction(targets[index], camera))
      {
        items.selectItem(index);
        items.accept();
        return true;
      }
    }

    return false;
  }
}
