package funkin.util;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxCamera;
import flixel.FlxG;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

/**
 * Touch/pointer input helpers used only by NovaBeat's custom menu presentation.
 *
 * The original FNF touch helpers remain untouched so the protected FNF menu
 * path keeps its existing input behavior.
 */
class NovaBeatMenuInput
{
  public static var pointer(get, never):Dynamic;
  public static var pointerEvent(get, never):Bool;
  public static var pressed(get, never):Bool;
  public static var justPressed(get, never):Bool;
  public static var justReleased(get, never):Bool;
  public static var justMoved(get, never):Bool;
  public static var swipeUp(get, never):Bool;
  public static var swipeDown(get, never):Bool;
  public static var swipeLeft(get, never):Bool;
  public static var swipeRight(get, never):Bool;
  public static var swipeAny(get, never):Bool;
  public static var justSwipedAny(get, never):Bool;
  public static var flickManager(get, never):Dynamic;
  public static var flickUp(get, never):Bool;
  public static var flickDown(get, never):Bool;
  public static var flickLeft(get, never):Bool;
  public static var flickRight(get, never):Bool;

  static function get_pointer():Dynamic
  {
    #if FLX_TOUCH
    var pressedTouch:Null<FlxTouch> = null;
    var releasedTouch:Null<FlxTouch> = null;

    for (touch in FlxG.touches.list)
    {
      if (touch == null) continue;
      if (touch.justPressed) return touch;
      if (pressedTouch == null && touch.pressed) pressedTouch = touch;
      if (releasedTouch == null && touch.justReleased) releasedTouch = touch;
    }

    if (pressedTouch != null) return pressedTouch;
    if (releasedTouch != null) return releasedTouch;
    #end

    #if web
    return FlxG.mouse;
    #elseif !mobile
    return FlxG.mouse;
    #else
    return null;
    #end
  }

  static function get_pointerEvent():Bool
  {
    return pressed || justPressed || justReleased;
  }

  static function get_pressed():Bool
  {
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.pressed) return true;
    }
    #end
    #if web
    return FlxG.mouse.pressed;
    #elseif !mobile
    return FlxG.mouse.pressed;
    #else
    return false;
    #end
  }

  static function get_justPressed():Bool
  {
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.justPressed) return true;
    }
    #end
    #if web
    return FlxG.mouse.justPressed;
    #elseif !mobile
    return FlxG.mouse.justPressed;
    #else
    return false;
    #end
  }

  static function get_justReleased():Bool
  {
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.justReleased) return true;
    }
    #end
    #if web
    return FlxG.mouse.justReleased;
    #elseif !mobile
    return FlxG.mouse.justReleased;
    #else
    return false;
    #end
  }

  static function get_justMoved():Bool
  {
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.justMoved) return true;
    }
    #end
    #if web
    return FlxG.mouse.justMoved;
    #elseif !mobile
    return FlxG.mouse.justMoved;
    #else
    return false;
    #end
  }

  static function get_swipeUp():Bool
  {
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
  }

  static function get_swipeDown():Bool
  {
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
  }

  static function get_swipeLeft():Bool
  {
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
  }

  static function get_swipeRight():Bool
  {
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
  }

  static function get_swipeAny():Bool
  {
    return swipeUp || swipeDown || swipeLeft || swipeRight;
  }

  static function get_flickManager():Dynamic
  {
    #if mobile
    return FlxG.touches.flickManager;
    #elseif web
    #if FLX_TOUCH
    // FlxTouch initializes its flick manager on release, so retain the touch
    // manager through the release frame and the full inertia phase. On Quest,
    // where taps may arrive only as mouse events, use the mouse manager instead.
    if (hasActiveTouchContact() || hasReleasedTouchContact() || FlxG.touches.flickManager.initialized)
      return FlxG.touches.flickManager;
    #end
    return FlxG.mouse.flickManager;
    #else
    return FlxG.mouse.flickManager;
    #end
  }

  static inline function get_flickUp():Bool return flickManager.flickUp;
  static inline function get_flickDown():Bool return flickManager.flickDown;
  static inline function get_flickLeft():Bool return flickManager.flickLeft;
  static inline function get_flickRight():Bool return flickManager.flickRight;

  static function hasActiveTouchContact():Bool
  {
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && (touch.pressed || touch.justPressed)) return true;
    }
    #end
    return false;
  }

  static function hasReleasedTouchContact():Bool
  {
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.justReleased) return true;
    }
    #end
    return false;
  }

  public static inline function resetSwipeVelocity():Void
  {
    FlxG.mouse.flickManager.destroy();
    FlxG.touches.flickManager.destroy();
  }

  static function get_justSwipedAny():Bool
  {
    for (swipe in FlxG.swipes)
    {
      if (swipe != null && swipe.distance > 20) return true;
    }
    return false;
  }

  public static function overlaps(object:FlxBasic, ?camera:FlxCamera):Bool
  {
    if (object == null) return false;
    final targetCamera:Null<FlxCamera> = camera ?? object.camera;

    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch == null || !(touch.pressed || touch.justPressed || touch.justReleased)) continue;
      if (touch.overlaps(object, targetCamera)) return true;
    }
    #end

    #if web
    if (FlxG.mouse.pressed || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
    {
      if (FlxG.mouse.overlaps(object, targetCamera)) return true;
    }
    #elseif !mobile
    if (FlxG.mouse.overlaps(object, targetCamera)) return true;
    #end

    return false;
  }

  public static function overlapsComplex(object:FlxObject, ?camera:FlxCamera):Bool
  {
    if (object == null) return false;
    final targetCamera:FlxCamera = camera ?? object.camera;

    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch == null || !(touch.pressed || touch.justPressed || touch.justReleased)) continue;
      @:privateAccess
      if (object.overlapsPoint(touch.getWorldPosition(targetCamera, object._point), true, targetCamera)) return true;
    }
    #end

    #if web
    if (FlxG.mouse.pressed || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
    {
      @:privateAccess
      if (object.overlapsPoint(FlxG.mouse.getWorldPosition(targetCamera, object._point), true, targetCamera)) return true;
    }
    #elseif !mobile
    @:privateAccess
    if (object.overlapsPoint(FlxG.mouse.getWorldPosition(targetCamera, object._point), true, targetCamera)) return true;
    #end

    return false;
  }

  public static function pressAction(?object:FlxBasic, ?camera:FlxCamera):Bool
  {
    if (object == null) return justReleased;
    return justReleased && overlaps(object, camera);
  }
}
