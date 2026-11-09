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
#if web
import js.Browser;
#end
#if web
import funkin.util.DeviceUtil;
#end

/**
 * Utility class for handling touch input within the FlxG context.
 */
class TouchUtil
{
  #if web
  // Mobile HTML5 browsers can remove a FlxTouch before the game update sees
  // its release. Track Pointer Events at the browser boundary so menu input
  // does not depend on the lifetime of a FlxTouch object.
  static var browserPointerInitialized:Bool = false;
  static var browserPointerAvailable:Bool = false;
  static var browserPointerDown:Bool = false;
  static var browserPointerMoved:Bool = false;
  static var browserPointerId:Int = -1;
  static var browserPointerStartX:Float = 0;
  static var browserPointerStartY:Float = 0;
  static var browserPointerGameY:Float = 0;
  static var browserPointerClientX:Float = 0;
  static var browserPointerClientY:Float = 0;
  static var browserPointerDeltaY:Float = 0;
  static var browserPointerReleaseIsTap:Bool = false;
  static var browserPointerReleaseSerial:Int = 0;
  static var browserPointerConsumedSerial:Int = 0;

  static function ensureBrowserPointerBridge():Void
  {
    if (browserPointerInitialized) return;
    browserPointerInitialized = true;

    if (!DeviceUtil.isMobileBrowser) return;

    browserPointerAvailable = Reflect.field(Browser.window, "PointerEvent") != null;
    if (!browserPointerAvailable) return;

    Browser.window.addEventListener("pointerdown", function(event)
    {
      final pointer:Dynamic = event;
      if (browserPointerDown) return;

      final pointerType:String = Std.string(Reflect.field(pointer, "pointerType"));
      if (pointerType != "touch" && pointerType != "pen" && pointerType != "mouse") return;

      final clientX:Float = browserPointerNumber(pointer, "clientX");
      final clientY:Float = browserPointerNumber(pointer, "clientY");
      if (!updateBrowserPointerPosition(clientX, clientY)) return;

      browserPointerId = Std.int(browserPointerNumber(pointer, "pointerId"));
      browserPointerStartX = clientX;
      browserPointerStartY = clientY;
      browserPointerGameY = FlxG.mouse.gameY;
      browserPointerDeltaY = 0;
      browserPointerMoved = false;
      browserPointerDown = true;
      browserPointerReleaseIsTap = false;
    }, true);

    Browser.window.addEventListener("pointermove", function(event)
    {
      final pointer:Dynamic = event;
      if (!browserPointerDown || Std.int(browserPointerNumber(pointer, "pointerId")) != browserPointerId) return;

      final clientX:Float = browserPointerNumber(pointer, "clientX");
      final clientY:Float = browserPointerNumber(pointer, "clientY");
      if (!updateBrowserPointerPosition(clientX, clientY))
      {
        browserPointerMoved = true;
        return;
      }

      final nextY:Float = FlxG.mouse.gameY;
      browserPointerDeltaY += nextY - browserPointerGameY;
      browserPointerGameY = nextY;

      final dx:Float = clientX - browserPointerStartX;
      final dy:Float = clientY - browserPointerStartY;
      if ((dx * dx) + (dy * dy) >= 324) browserPointerMoved = true;
    }, true);

    Browser.window.addEventListener("pointerup", function(event)
    {
      final pointer:Dynamic = event;
      if (!browserPointerDown || Std.int(browserPointerNumber(pointer, "pointerId")) != browserPointerId) return;

      final clientX:Float = browserPointerNumber(pointer, "clientX");
      final clientY:Float = browserPointerNumber(pointer, "clientY");
      if (updateBrowserPointerPosition(clientX, clientY))
      {
        final releaseY:Float = FlxG.mouse.gameY;
        browserPointerDeltaY += releaseY - browserPointerGameY;
        browserPointerGameY = releaseY;
      }
      else
      {
        browserPointerMoved = true;
      }

      final dx:Float = clientX - browserPointerStartX;
      final dy:Float = clientY - browserPointerStartY;
      if ((dx * dx) + (dy * dy) >= 324) browserPointerMoved = true;

      browserPointerDown = false;
      browserPointerReleaseIsTap = !browserPointerMoved;
      browserPointerReleaseSerial++;
      browserPointerId = -1;
    }, true);

    Browser.window.addEventListener("pointercancel", function(event)
    {
      final pointer:Dynamic = event;
      if (!browserPointerDown || Std.int(browserPointerNumber(pointer, "pointerId")) != browserPointerId) return;
      browserPointerDown = false;
      browserPointerMoved = true;
      browserPointerReleaseIsTap = false;
      browserPointerId = -1;
      browserPointerDeltaY = 0;
    }, true);
  }

  static function browserPointerNumber(source:Dynamic, field:String):Float
  {
    final value:Dynamic = Reflect.field(source, field);
    return value == null ? 0 : Std.parseFloat(Std.string(value));
  }

  static function updateBrowserPointerPosition(clientX:Float, clientY:Float):Bool
  {
    var canvas:Dynamic = Browser.document.querySelector("#openfl-content canvas");
    if (canvas == null) canvas = Browser.document.querySelector("canvas");
    if (canvas == null) return false;

    final rect:Dynamic = canvas.getBoundingClientRect();
    final left:Float = browserPointerNumber(rect, "left");
    final top:Float = browserPointerNumber(rect, "top");
    final width:Float = browserPointerNumber(rect, "width");
    final height:Float = browserPointerNumber(rect, "height");
    if (width <= 0 || height <= 0) return false;
    if (clientX < left || clientY < top || clientX > left + width || clientY > top + height) return false;

    browserPointerClientX = clientX;
    browserPointerClientY = clientY;
    final gameX:Float = ((clientX - left) / width) * FlxG.width;
    final gameY:Float = ((clientY - top) / height) * FlxG.height;
    final scaleX:Float = FlxG.scaleMode.scale.x;
    final scaleY:Float = FlxG.scaleMode.scale.y;

    // FlxPointer exposes this method specifically for supplying raw screen
    // coordinates from an external pointer source.
    FlxG.mouse.setRawPositionUnsafe(gameX * scaleX, gameY * scaleY);
    return true;
  }

  public static function browserPointerBridgeAvailable():Bool
  {
    ensureBrowserPointerBridge();
    return browserPointerAvailable;
  }

  public static function browserPointerIsDown():Bool
  {
    ensureBrowserPointerBridge();
    return browserPointerAvailable && browserPointerDown;
  }

  public static function browserPointerHasDragged():Bool
  {
    ensureBrowserPointerBridge();
    return browserPointerAvailable && browserPointerMoved;
  }

  /**
   * Tests where the current browser pointer gesture began. This is used by
   * scrollable screens to begin a drag only when the finger starts on the list.
   */
  public static function browserPointerPressedOn(object:FlxBasic, ?camera:FlxCamera):Bool
  {
    ensureBrowserPointerBridge();
    if (!browserPointerAvailable || !browserPointerDown || object == null) return false;

    final currentX:Float = browserPointerClientX;
    final currentY:Float = browserPointerClientY;
    if (!updateBrowserPointerPosition(browserPointerStartX, browserPointerStartY)) return false;
    final pressedOnObject:Bool = FlxG.mouse.overlaps(object, camera);
    updateBrowserPointerPosition(currentX, currentY);
    return pressedOnObject;
  }

  public static function consumeBrowserPointerDeltaY():Float
  {
    ensureBrowserPointerBridge();
    final delta:Float = browserPointerDeltaY;
    browserPointerDeltaY = 0;
    return delta;
  }

  /**
   * Consume one completed, stationary browser pointer tap. The release stays
   * pending until a menu hitbox matches, so each visible menu can test its rows.
   */
  public static function consumeBrowserPointerTap(?object:FlxBasic, ?camera:FlxCamera):Bool
  {
    ensureBrowserPointerBridge();
    if (!browserPointerAvailable || browserPointerReleaseSerial == browserPointerConsumedSerial || !browserPointerReleaseIsTap) return false;

    // The regular FlxMouse update can overwrite externally supplied pointer
    // coordinates before the state update runs. Reapply the captured release
    // position immediately before checking the menu hitbox.
    if (!updateBrowserPointerPosition(browserPointerClientX, browserPointerClientY)) return false;
    if (object != null && !FlxG.mouse.overlaps(object, camera)) return false;

    browserPointerConsumedSerial = browserPointerReleaseSerial;
    return true;
  }
  #end
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

  #if mobile
  /**
   * The first touch in the FlxG.touches list.
   */
  public static var touch(get, never):FlxTouch;
  #elseif web
  /**
   * Mobile browsers use FlxTouch; desktop browsers continue to use FlxMouse.
   */
  public static var touch(get, never):Dynamic;
  #else
  /**
   * Desktop/native pointer.
   */
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
    if (object == null || touch == null) return false;

    return touch.overlaps(object, camera ?? object.camera);

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
    if (object == null || touch == null) return false;

    if (camera == null) camera = object.cameras[0];

    @:privateAccess
    return object.overlapsPoint(touch.getWorldPosition(camera, object._point), true, camera);

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
    // On mobile HTML5, use the browser's captured PointerEvent release as the
    // authoritative tap. This avoids losing taps when OpenFL removes FlxTouch
    // before the next HaxeFlixel update.
    #if web
    if (DeviceUtil.isMobileBrowser && browserPointerBridgeAvailable())
      return consumeBrowserPointerTap(object, camera);
    #end

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
  static inline function get_justMoved():Bool
  {
    #if (mobile || web)
    return touch != null && touch.justMoved;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_pressed():Bool
  {
    #if (mobile || web)
    return touch != null && touch.pressed;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_justPressed():Bool
  {
    #if (mobile || web)
    return touch != null && touch.justPressed;
    #else
    return false;
    #end
  }

  @:noCompletion
  static inline function get_justReleased():Bool
  {
    #if (mobile || web)
    return touch != null && touch.justReleased;
    #else
    return false;
    #end
  }

  @:noCompletion
  static function get_released():Bool
  {
    #if (mobile || web)
    return touch != null && touch.released;
    #else
    return false;
    #end
  }

  #if mobile
  @:noCompletion
  static function get_touch():FlxTouch
  {
    for (touch in FlxG.touches.list)
    {
      if (touch != null) return touch;
    }

    return FlxG.touches.getFirst();
  }
  #elseif web
  @:noCompletion
  static function get_touch():Dynamic
  {
    // Use actual finger touches on mobile/Quest browsers. Desktop HTML5
    // continues to expose its normal mouse pointer.
    if (DeviceUtil.isMobileBrowser)
    {
      // Prefer an active finger. Some mobile browsers remove FlxTouch before
      // the release frame and expose that event through FlxMouse instead.
      var firstTouch:Dynamic = null;
      for (touch in FlxG.touches.list)
      {
        if (touch == null) continue;

        // A live finger contact wins over synthesized mouse events. A mere
        // justMoved flag does not: browsers can leave that marker on an older
        // touch while the actual tap arrives through FlxMouse.
        if (touch.pressed || touch.justPressed || touch.justReleased) return touch;
        if (firstTouch == null && touch.justMoved) firstTouch = touch;
      }

      var retainedTouch:Dynamic = FlxG.touches.getFirst();
      if (retainedTouch != null
        && (retainedTouch.pressed || retainedTouch.justPressed || retainedTouch.justReleased))
        return retainedTouch;

      if (FlxG.mouse.pressed || FlxG.mouse.justPressed || FlxG.mouse.justReleased || FlxG.mouse.justMoved)
        return FlxG.mouse;

      return retainedTouch != null ? retainedTouch : firstTouch;
    }

    return FlxG.mouse;
  }
  #else
  @:noCompletion
  static function get_touch():FlxMouse
  {
    return FlxG.mouse;
  }
  #end
}
