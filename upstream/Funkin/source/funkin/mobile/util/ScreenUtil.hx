package funkin.mobile.util;

#if web
import js.Browser;
#end
#if ios
import funkin.external.apple.ScreenUtil as NativeScreenUtil;
#elseif android
import funkin.external.android.ScreenUtil as NativeScreenUtil;
#end
import lime.system.System;
import lime.app.Application;
import openfl.geom.Rectangle;

/**
 * A Utility class to get mobile screen related informations.
 */
@:unreflective
class ScreenUtil
{
  #if web
  // Browser-safe-area support for the HTML5 phone test build.
  /**
   * Read the browser's CSS safe-area insets in CSS pixels.
   * The returned array is ordered [left, top, right, bottom].
   *
   * viewport-fit=cover is applied at runtime so mobile browsers expose the
   * env(safe-area-inset-*) values instead of keeping the page inside a
   * pre-inset viewport.
   */
  public static function getSafeAreaInsets():Array<Float>
  {
    ensureViewportFitCover();

    final document:Dynamic = Browser.document;
    final body:Dynamic = Reflect.field(document, "body");
    if (body == null) return [0, 0, 0, 0];

    final createElement:Dynamic = Reflect.field(document, "createElement");
    final probe:Dynamic = Reflect.callMethod(document, createElement, ["div"]);
    final style:Dynamic = Reflect.field(probe, "style");
    Reflect.setField(style, "cssText",
      "position:fixed;visibility:hidden;pointer-events:none;"
      + "padding-left:env(safe-area-inset-left);"
      + "padding-top:env(safe-area-inset-top);"
      + "padding-right:env(safe-area-inset-right);"
      + "padding-bottom:env(safe-area-inset-bottom);");

    Reflect.callMethod(body, Reflect.field(body, "appendChild"), [probe]);
    final getComputedStyle:Dynamic = Reflect.field(Browser.window, "getComputedStyle");
    final computed:Dynamic = Reflect.callMethod(Browser.window, getComputedStyle, [probe]);

    final left:Float = parseCssPixels(Reflect.field(computed, "paddingLeft"));
    final top:Float = parseCssPixels(Reflect.field(computed, "paddingTop"));
    final right:Float = parseCssPixels(Reflect.field(computed, "paddingRight"));
    final bottom:Float = parseCssPixels(Reflect.field(computed, "paddingBottom"));

    Reflect.callMethod(body, Reflect.field(body, "removeChild"), [probe]);
    return [left, top, right, bottom];
  }

  static var viewportFitConfigured:Bool = false;

  static function ensureViewportFitCover():Void
  {
    if (viewportFitConfigured) return;
    viewportFitConfigured = true;

    final document:Dynamic = Browser.document;
    var viewport:Dynamic = document.querySelector('meta[name="viewport"]');
    if (viewport == null)
    {
      viewport = document.createElement("meta");
      viewport.setAttribute("name", "viewport");
      viewport.setAttribute("content", "width=device-width, initial-scale=1, viewport-fit=cover");
      final head:Dynamic = Reflect.field(document, "head");
      if (head != null) Reflect.callMethod(head, Reflect.field(head, "appendChild"), [viewport]);
      return;
    }

    final contentValue:Dynamic = viewport.getAttribute("content");
    var content:String = contentValue == null ? "" : Std.string(contentValue);
    if (content.length == 0)
    {
      content = "width=device-width, initial-scale=1, viewport-fit=cover";
    }
    else if (content.indexOf("viewport-fit") < 0)
    {
      content += ", viewport-fit=cover";
    }
    else
    {
      content = StringTools.replace(content, "viewport-fit=auto", "viewport-fit=cover");
      content = StringTools.replace(content, "viewport-fit=contain", "viewport-fit=cover");
    }
    viewport.setAttribute("content", content);
  }

  static function parseCssPixels(value:Dynamic):Float
  {
    final parsed:Float = Std.parseFloat(value == null ? "0" : Std.string(value));
    return Math.isNaN(parsed) || parsed < 0 ? 0 : parsed;
  }
  #end

  /**
   * Get `Rectangle` Object that contains the dimensions of the screen's Notch.
   * Scales the dimensions to return coords in pixels, not points
   * @return Rectangle
   */
  public static function getNotchRect():Rectangle
  {
    final notchRect:Rectangle = new Rectangle();

    notchRect.x = 0.0;
    notchRect.y = 0.0;

    #if android
    final rectDimensions:Array<Array<Float>> = [[], [], [], []];

    // Push all the dimensions of the cutouts into an array
    for (rect in NativeScreenUtil.getCutoutDimensions())
    {
      rectDimensions[0].push(rect.x);
      rectDimensions[1].push(rect.y);
      rectDimensions[2].push(rect.width);
      rectDimensions[3].push(rect.height);
    }

    // Put all the dimensions into the rectangle
    for (i => dimensions in rectDimensions)
    {
      for (dimension in dimensions)
      {
        switch (i)
        {
          case 0:
            notchRect.x += dimension;
          case 1:
            notchRect.y += dimension;
          case 2:
            notchRect.width += dimension;
          case 3:
            notchRect.height += dimension;
        }
      }
    }
    #elseif web
    final safeArea:Array<Float> = getSafeAreaInsets();
    final leftInset:Float = safeArea[0];
    final topInset:Float = safeArea[1];
    final rightInset:Float = safeArea[2];
    final bottomInset:Float = safeArea[3];
    final deviceWidth:Float = Browser.window.innerWidth;
    final deviceHeight:Float = Browser.window.innerHeight;

    // Represent the largest unsafe edge as a notch rectangle for systems
    // that already consume this legacy value. All four insets are exposed
    // separately through getSafeAreaInsets() for actual layout calculations.
    if (deviceWidth >= deviceHeight)
    {
      if (leftInset >= rightInset)
      {
        notchRect.width = leftInset;
        notchRect.height = deviceHeight;
      }
      else
      {
        notchRect.width = rightInset;
        notchRect.height = deviceHeight;
        notchRect.x = deviceWidth - rightInset;
      }
    }
    else if (topInset >= bottomInset)
    {
      notchRect.width = deviceWidth;
      notchRect.height = topInset;
    }
    else
    {
      notchRect.width = deviceWidth;
      notchRect.height = bottomInset;
      notchRect.y = deviceHeight - bottomInset;
    }
    #elseif ios
    var topInset:Float = -1;
    var leftInset:Float = -1;
    var rightInset:Float = -1;
    var bottomInset:Float = -1;
    var deviceWidth:Float = -1;
    var deviceHeight:Float = -1;

    NativeScreenUtil.getSafeAreaInsets(cpp.RawPointer.addressOf(topInset), cpp.RawPointer.addressOf(bottomInset), cpp.RawPointer.addressOf(leftInset),
      cpp.RawPointer.addressOf(rightInset));
    NativeScreenUtil.getScreenSize(cpp.RawPointer.addressOf(deviceWidth), cpp.RawPointer.addressOf(deviceHeight));

    // Calculate the rectangle dimensions for the notch
    // Note: iOS only spits out *insets* for "safe areas", so we can only get a broad position for the notch
    // Note: *inset* is the distance from the edge of the screen where a safe area gets defined
    // see: https://developer.apple.com/documentation/uikit/uiview/safeareainsets
    switch (lime.app.Application.current.window.display.orientation)
    {
      case LANDSCAPE: // landscape
        notchRect.width = leftInset;
        notchRect.height = deviceHeight;
      case LANDSCAPE_FLIPPED: // landscape
        notchRect.width = leftInset;
        notchRect.height = deviceHeight;
        notchRect.x = deviceWidth - rightInset;
      case PORTRAIT: // portrait
        notchRect.width = deviceWidth;
        notchRect.height = topInset;
      case PORTRAIT_FLIPPED: // portrait
        notchRect.width = deviceWidth;
        notchRect.height = bottomInset;
        notchRect.y = deviceHeight - notchRect.height; // move notchRect if we are flipped, the notch is at the bottom of screen
      default: // display orientation unknown? perhaps this occurs on desktop
    }
    #end

    return notchRect;
  }
}
