// Hey!! Slight note from little me, Zack, I got rid of the for loops because essentially the functions
// just return the first touch they find back then. Now it looks more clean but the descriptions
// for some variables are inaccurate. Well they were already inaccurate but still.
// - Zack xoxo
//
// Another slight note from little me, it turns out it WAS accurate,
// I just my ass during clean up just completely forgot. My fault!!
// I gotta focus on multi-touch next time.
// Easy to fix but I'll tackle it for later.
// - Zack
package funkin.util;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end
import flixel.input.mouse.FlxMouse;
import flixel.math.FlxPoint;

/**
 * Utility class for handling touch input within the FlxG context.
 */
class TouchUtil
{
  /**
   * Indicates if any touch is currently pressed.
   */
  public static var pressed(get, never):Bool;

  /**
   * Indicates if any touch was just pressed this frame.
   */
  public static var justPressed(get, never):Bool;

  /**
   * Indicates if any touch was just released this frame.
   */
  public static var justReleased(get, never):Bool;

  /**
   * Indicates if any touch is released this frame.
   */
  public static var released(get, never):Bool;

  /**
   * Indicates if any touch is moved this frame.
   */
  public static var justMoved(get, never):Bool;

  /** Whether a real FlxTouch contact is currently down or was just pressed. */
  public static var hasActiveTouchContact(get, never):Bool;

  #if mobile
  /**
   * The first touch in the FlxG.touches list.
   */
  public static var touch(get, never):FlxTouch;
  #elseif web
  /** The active browser touch or the mouse pointer when no touch is active. */
  public static var touch(get, never):Dynamic;
  #else
  public static var touch(get, never):FlxMouse;
  #end

  /**
   * Checks if the specified object overlaps with any active touch.
   *
   * @param object The FlxBasic object to check for overlap.
   * @param camera Optional camera for the overlap check. Defaults to the object's camera.
   *
   * @return `true` if there is an overlap with any touch; `false` otherwise.
   */
  public static function overlaps(?object:FlxBasic, ?camera:FlxCamera):Bool
  {
    if (object == null) return false;

    final targetCamera:Null<FlxCamera> = camera ?? object.camera;

    #if FLX_TOUCH
    // Inspect all live contacts. A stale first touch must never hide a second
    // finger that is currently interacting with a menu control.
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch == null || !(activeTouch.pressed || activeTouch.justPressed || activeTouch.justReleased)) continue;
      if (activeTouch.overlaps(object, targetCamera)) return true;
    }
    #end

    #if web
    if (FlxG.mouse.pressed || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
    {
      if (FlxG.mouse.overlaps(object, targetCamera)) return true;
    }
    #end

    return false;
  }

  /**
   * Checks if the specified object overlaps with any active touch using precise point checks.
   *
   * @param object The FlxObject to check for overlap.
   * @param camera Optional camera for the overlap check. Defaults to all cameras of the object.
   *
   * @return `true` if there is a precise overlap with any touch; `false` otherwise.
   */
  public static function overlapsComplex(?object:FlxObject, ?camera:FlxCamera):Bool
  {
    if (object == null) return false;

    if (camera == null)
    {
      if (object.cameras == null || object.cameras.length == 0) return false;
      camera = object.cameras[0];
    }

    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch == null || !(activeTouch.pressed || activeTouch.justPressed || activeTouch.justReleased)) continue;
      @:privateAccess
      if (object.overlapsPoint(activeTouch.getWorldPosition(camera, object._point), true, camera)) return true;
    }
    #end

    #if web
    if (FlxG.mouse.pressed || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
    {
      @:privateAccess
      if (object.overlapsPoint(FlxG.mouse.getWorldPosition(camera, object._point), true, camera)) return true;
    }
    #end

    return false;
  }

  /**
   * Checks if the specified object overlaps with a specific point using precise point checks.
   *
   * @param object The FlxObject to check for overlap.
   * @param point The FlxPoint to check against the object.
   * @param inScreenSpace Whether to take scroll factors into account when checking for overlap.
   * @param camera Optional camera for the overlap check. Defaults to all cameras of the object.
   *
   * @return `true` if there is a precise overlap with the specified point; `false` otherwise.
   */
  public static function overlapsComplexPoint(?object:FlxObject, point:FlxPoint, ?inScreenSpace:Bool = false, ?camera:FlxCamera):Bool
  {
    if (object == null || point == null) return false;

    if (camera == null) camera = object.cameras[0];
    @:privateAccess
    if (object.overlapsPoint(point, inScreenSpace, camera))
    {
      point.putWeak();
      return true;
    }

    point.putWeak();

    return false;
  }

  /**
   * A helper function to check if the selection is pressed using touch.
   *
   * @param object The optional FlxBasic to check for overlap.
   * @param camera Optional camera for the overlap check. Defaults to all cameras of the object.
   * @param useOverlapsComplex If true and atleast the object is not null, the function will use complex overlaps method.
   * @return `true` if the selection was pressed.
   */
  public static function pressAction(?object:FlxBasic, ?camera:FlxCamera, useOverlapsComplex:Bool = true):Bool
  {
    if (TouchUtil.touch == null) return false;

    if (object == null && camera == null)
    {
      return justReleased;
    }
    else if (object != null)
    {
      final overlapsObject:Bool = useOverlapsComplex ? overlapsComplex(cast(object, FlxObject), camera) : overlaps(object, camera);
      return justReleased && overlapsObject;
    }

    return false;
  }

  // weird mix between "looks weird" and "looks neat" but i'll keep it for now -Zack

  @:noCompletion
  static function get_justMoved():Bool
  {
    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch != null && activeTouch.justMoved) return true;
    }
    #end
    #if web
    return FlxG.mouse.justMoved;
    #else
    return false;
    #end
  }

  @:noCompletion
  static function get_pressed():Bool
  {
    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch != null && activeTouch.pressed) return true;
    }
    #end
    #if web
    return FlxG.mouse.pressed;
    #else
    return false;
    #end
  }

  @:noCompletion
  static function get_justPressed():Bool
  {
    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch != null && activeTouch.justPressed) return true;
    }
    #end
    #if web
    return FlxG.mouse.justPressed;
    #else
    return false;
    #end
  }

  @:noCompletion
  static function get_hasActiveTouchContact():Bool
  {
    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch != null && (activeTouch.pressed || activeTouch.justPressed)) return true;
    }
    #end
    return false;
  }

  @:noCompletion
  static function get_justReleased():Bool
  {
    #if web
    // A mobile browser can emit a real touch release, a synthesized mouse
    // release, or both. Check every touch before falling back to the mouse so
    // one input stream cannot hide the release from the other.
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.justReleased) return true;
    }
    #end
    return FlxG.mouse.justReleased;
    #else
    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch != null && activeTouch.justReleased) return true;
    }
    #end
    return false;
    #end
  }

  @:noCompletion
  static function get_released():Bool
  {
    #if FLX_TOUCH
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch != null && activeTouch.released) return true;
    }
    #end
    #if web
    return FlxG.mouse.released;
    #else
    return false;
    #end
  }

  #if mobile
  @:noCompletion
  static function get_touch():FlxTouch
  {
    var pressedTouch:Null<FlxTouch> = null;
    var releasedTouch:Null<FlxTouch> = null;

    // Prefer the newest press, then any active contact, then a release frame.
    // This avoids pinning menu hit-tests to the first/stale pointer in the list.
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch == null) continue;
      if (activeTouch.justPressed) return activeTouch;
      if (pressedTouch == null && activeTouch.pressed) pressedTouch = activeTouch;
      if (releasedTouch == null && activeTouch.justReleased) releasedTouch = activeTouch;
    }

    if (pressedTouch != null) return pressedTouch;
    if (releasedTouch != null) return releasedTouch;
    return FlxG.touches.getFirst();
  }
  #elseif web
  @:noCompletion
  static function get_touch():Dynamic
  {
    // On phones and Quest, the mouse is a browser pointer transport rather
    // than a desktop cursor. Keep the native mouse cursor hidden regardless
    // of which input source is active.
    if (DeviceUtil.isMobileBrowser) FlxG.mouse.visible = false;

    #if FLX_TOUCH
    // Prefer a newly pressed real contact over older held contacts, then keep
    // the active finger selected through its release frame. Mouse remains the
    // fallback for Quest controller rays and browsers without DOM touch input.
    var pressedTouch:Null<FlxTouch> = null;
    var releasedTouch:Null<FlxTouch> = null;
    for (activeTouch in FlxG.touches.list)
    {
      if (activeTouch == null) continue;
      if (activeTouch.justPressed) return activeTouch;
      if (pressedTouch == null && activeTouch.pressed) pressedTouch = activeTouch;
      if (releasedTouch == null && activeTouch.justReleased) releasedTouch = activeTouch;
    }

    if (pressedTouch != null) return pressedTouch;
    if (releasedTouch != null) return releasedTouch;
    #end

    // Quest controller/ray clicks and browsers that only expose mouse events
    // still work through the mouse fallback when no touch contact is active.
    return FlxG.mouse;
  }
  #else
  @:noCompletion
  static function get_touch():FlxMouse
  {
    FlxG.mouse.visible = true;
    return FlxG.mouse;
  }
  #end
}
