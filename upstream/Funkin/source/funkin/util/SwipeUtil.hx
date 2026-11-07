package funkin.util;

import flixel.FlxG;
#if FLX_POINTER_INPUT
import flixel.input.FlxSwipe;
#end
import flixel.util.FlxAxes;
import funkin.util.DeviceUtil;

/**
 * Utility class for handling swipe gestures in HaxeFlixel and dispatching signals for different swipe directions.
 *
 * Example usage:
 *
 * ```haxe
 * if (SwipeUtil.justSwipedLeft) trace("Swiped left!");
 *
 * if (SwipeUtil.swipeRight) trace("User is swiping/dragging right!");
 *
 * if (SwipeUtil.justFlickedUp) trace("Flicked up!");
 *
 * if (SwipeUtil.flickUp) trace("User has flicked up!");
 *
 * if (SwipeUtil.justSwipedAny) trace("Swiped in any direction!");
 * ```
 */
class SwipeUtil
{
  /**
   * Tracks if an upward swipe has been detected.
   */
  public static var swipeUp(get, never):Bool;

  /**
   * Tracks if a rightward swipe has been detected.
   */
  public static var swipeRight(get, never):Bool;

  /**
   * Tracks if a leftward swipe has been detected.
   */
  public static var swipeLeft(get, never):Bool;

  /**
   * Tracks if a downward swipe has been detected.
   */
  public static var swipeDown(get, never):Bool;

  /**
   * Tracks if any swipe direction is detected (down, left, up, or right).
   */
  public static var swipeAny(get, never):Bool;

  /**
   * Indicates if there is an up swipe gesture detected.
   */
  public static var justSwipedUp(get, never):Bool;

  /**
   * Indicates if there is a right swipe gesture detected.
   */
  public static var justSwipedRight(get, never):Bool;

  /**
   * Indicates if there is a left swipe gesture detected.
   */
  public static var justSwipedLeft(get, never):Bool;

  /**
   * Indicates if there is a down swipe gesture detected.
   */
  public static var justSwipedDown(get, never):Bool;

  /**
   * Indicates if there is any swipe gesture detected.
   */
  public static var justSwipedAny(get, never):Bool;

  /**
   * Checks if an upward flick direction is detected.
   */
  public static var flickUp(get, never):Bool;

  /**
   * Checks if a rightward flick direction is detected.
   */
  public static var flickRight(get, never):Bool;

  /**
   * Checks if a leftward flick direction is detected.
   */
  public static var flickLeft(get, never):Bool;

  /**
   * Checks if a downward flick direction is detected.
   */
  public static var flickDown(get, never):Bool;

  /**
   *  Boolean variable that returns true if any flick direction is detected (down, left, up, or right).
   */
  public static var flickAny(get, never):Bool;

  static final DEFAULT_SWIPE_THRESHOLD:Float = 100;
  static final MIN_SWIPE_DISTANCE:Float = 20;

  /**
   * Flick manager for the active input source. Browser touch contacts use the
   * touch manager; Quest controller/hand-ray clicks and desktop pointers use
   * the mouse manager.
   */
  public static var flickManager(get, never):Dynamic;

  static function get_flickManager():Dynamic
  {
    #if mobile
    return FlxG.touches.flickManager;
    #elseif web
    if (TouchUtil.hasActiveTouchContact) return FlxG.touches.flickManager;
    return FlxG.mouse.flickManager;
    #else
    return FlxG.mouse.flickManager;
    #end
  }

  /**
   * Updates the swipe threshold based on the provided group.
   *
   * @param items The array whose items' positions are used to calculate the swipe threshold.
   * @param axes The axis to calculate the swipe threshold for.
   * @param multiplier Optional value that multiplies the final swipe threshold with it.
   */
  public static function calculateSwipeThreshold(items:Array<Dynamic>, axes:FlxAxes, ?multiplier:Float = 1):Void
  {
    #if FEATURE_TOUCH_CONTROLS
    var itemCount:Int = items.length - 1;

    if (itemCount <= 0)
    {
      FlxG.touches.swipeThreshold.set(DEFAULT_SWIPE_THRESHOLD, DEFAULT_SWIPE_THRESHOLD);
      #if web
      FlxG.mouse.swipeThreshold.set(DEFAULT_SWIPE_THRESHOLD, DEFAULT_SWIPE_THRESHOLD);
      #end
      return;
    }

    var totalDistanceX:Float = 0;
    var totalDistanceY:Float = 0;

    for (i in 0...itemCount)
    {
      if (axes.x) totalDistanceX += Math.abs(items[i + 1].x - items[i].x);
      if (axes.y) totalDistanceY += Math.abs(items[i + 1].y - items[i].y);
    }

    totalDistanceX = Math.abs((totalDistanceX / itemCount) * 0.9);
    totalDistanceY = Math.abs((totalDistanceY / itemCount) * 0.9);

    FlxG.touches.swipeThreshold.x = (axes.x) ? totalDistanceX * multiplier : DEFAULT_SWIPE_THRESHOLD;
    FlxG.touches.swipeThreshold.y = (axes.y) ? totalDistanceY * multiplier : DEFAULT_SWIPE_THRESHOLD;
    #if web
    // Mouse-backed mobile/Quest pointers use their own threshold object.
    FlxG.mouse.swipeThreshold.x = (axes.x) ? totalDistanceX * multiplier : DEFAULT_SWIPE_THRESHOLD;
    FlxG.mouse.swipeThreshold.y = (axes.y) ? totalDistanceY * multiplier : DEFAULT_SWIPE_THRESHOLD;
    #end
    #end
    return;
  }

  @:noCompletion
  static inline function get_swipeUp():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.pressed && touch.justMovedUp) return true;
    }
    #end
    #if web
    return DeviceUtil.isMobileBrowser && FlxG.mouse.pressed && FlxG.mouse.justMovedUp;
    #elseif !mobile
    return FlxG.mouse.pressed && FlxG.mouse.justMovedUp;
    #else
    return false;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_swipeRight():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.pressed && touch.justMovedRight) return true;
    }
    #end
    #if web
    return DeviceUtil.isMobileBrowser && FlxG.mouse.pressed && FlxG.mouse.justMovedRight;
    #elseif !mobile
    return FlxG.mouse.pressed && FlxG.mouse.justMovedRight;
    #else
    return false;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_swipeLeft():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.pressed && touch.justMovedLeft) return true;
    }
    #end
    #if web
    return DeviceUtil.isMobileBrowser && FlxG.mouse.pressed && FlxG.mouse.justMovedLeft;
    #elseif !mobile
    return FlxG.mouse.pressed && FlxG.mouse.justMovedLeft;
    #else
    return false;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_swipeDown():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.pressed && touch.justMovedDown) return true;
    }
    #end
    #if web
    return DeviceUtil.isMobileBrowser && FlxG.mouse.pressed && FlxG.mouse.justMovedDown;
    #elseif !mobile
    return FlxG.mouse.pressed && FlxG.mouse.justMovedDown;
    #else
    return false;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_swipeAny():Bool return swipeDown || swipeLeft || swipeRight || swipeUp;

  @:noCompletion
  static inline function get_justSwipedUp():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    for (swipe in FlxG.swipes)
    {
      if (swipe != null && swipe.degrees > 45 && swipe.degrees < 135 && swipe.distance > MIN_SWIPE_DISTANCE) return true;
    }
    return false;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_justSwipedRight():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    for (swipe in FlxG.swipes)
    {
      if (swipe != null && swipe.degrees > -45 && swipe.degrees < 45 && swipe.distance > MIN_SWIPE_DISTANCE) return true;
    }
    return false;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_justSwipedLeft():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    for (swipe in FlxG.swipes)
    {
      if (swipe != null && (swipe.degrees > 135 || swipe.degrees < -135) && swipe.distance > MIN_SWIPE_DISTANCE) return true;
    }
    return false;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_justSwipedDown():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    for (swipe in FlxG.swipes)
    {
      if (swipe != null && swipe.degrees > -135 && swipe.degrees < -45 && swipe.distance > MIN_SWIPE_DISTANCE) return true;
    }
    return false;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_justSwipedAny():Bool
  {
    return justSwipedDown || justSwipedLeft || justSwipedRight || justSwipedUp;
  }

  @:noCompletion
  static inline function get_flickUp():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if mobile
    return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickUp;
    #elseif web
    if (TouchUtil.hasActiveTouchContact) return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickUp;
    #end
    return DeviceUtil.isMobileBrowser && FlxG.mouse.flickManager.flickUp;
    #else
    return FlxG.mouse.flickManager.flickUp;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_flickRight():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if mobile
    return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickRight;
    #elseif web
    if (TouchUtil.hasActiveTouchContact) return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickRight;
    #end
    return DeviceUtil.isMobileBrowser && FlxG.mouse.flickManager.flickRight;
    #else
    return FlxG.mouse.flickManager.flickRight;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_flickLeft():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if mobile
    return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickLeft;
    #elseif web
    if (TouchUtil.hasActiveTouchContact) return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickLeft;
    #end
    return DeviceUtil.isMobileBrowser && FlxG.mouse.flickManager.flickLeft;
    #else
    return FlxG.mouse.flickManager.flickLeft;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_flickDown():Bool
  {
    #if FEATURE_TOUCH_CONTROLS
    #if mobile
    return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickDown;
    #elseif web
    if (TouchUtil.hasActiveTouchContact) return DeviceUtil.isMobileBrowser && FlxG.touches.flickManager.flickDown;
    #end
    return DeviceUtil.isMobileBrowser && FlxG.mouse.flickManager.flickDown;
    #else
    return FlxG.mouse.flickManager.flickDown;
    #end
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_flickAny():Bool
  {
    return flickUp || flickRight || flickLeft || flickDown;
  }

  /**
   * Calls the destroy function from both the global mouse and the touch manager.
   */
  public static inline function resetSwipeVelocity():Void
  {
    FlxG.mouse.flickManager.destroy();
    FlxG.touches.flickManager.destroy();
  }
}
