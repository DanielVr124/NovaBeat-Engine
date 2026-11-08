package funkin.util;

#if web
import js.Browser;
#end
import lime.system.System;

class DeviceUtil
{
  // Browser capability checks are used by menu update loops. Cache the
  // stable user-agent/pointer result instead of calling matchMedia every frame.
  static var cachedIsQuestBrowser:Null<Bool> = null;
  static var cachedIsMobileBrowser:Null<Bool> = null;
  /**
   * Whether the current HTML5 browser is running on a Meta Quest headset.
   *
   * Quest Browser uses a desktop-like Linux user agent in its default mode,
   * so normal Android/mobile checks do not identify it.
   */
  public static var isQuestBrowser(get, never):Bool;

  static function get_isQuestBrowser():Bool
  {
    if (cachedIsQuestBrowser != null) return cachedIsQuestBrowser ?? false;

    #if web
    final userAgent:String = Browser.navigator.userAgent.toLowerCase();
    cachedIsQuestBrowser = userAgent.indexOf("oculusbrowser") >= 0
      || userAgent.indexOf("quest") >= 0
      || userAgent.indexOf("mobile vr") >= 0;
    #else
    cachedIsQuestBrowser = false;
    #end

    return cachedIsQuestBrowser ?? false;
  }

  /**
   * Whether the current target should use mobile-friendly menu layouts.
   * Includes native mobile targets and mobile/Quest browsers in the HTML5 build.
   */
  public static var isMobileBrowser(get, never):Bool;

  static function get_isMobileBrowser():Bool
  {
    if (cachedIsMobileBrowser != null) return cachedIsMobileBrowser ?? false;

    #if mobile
    cachedIsMobileBrowser = true;
    #elseif web
    final userAgent:String = Browser.navigator.userAgent.toLowerCase();
    final platform:String = Std.string(Reflect.field(Browser.navigator, "platform"));
    final maxTouchPoints:Int = Std.parseInt(Std.string(Reflect.field(Browser.navigator, "maxTouchPoints"))) ?? 0;
    final isIPadOS:Bool = platform == "MacIntel" && maxTouchPoints > 1;

    // maxTouchPoints is only a capability flag: many Windows laptops and
    // desktop monitors have touchscreens. Require a coarse primary pointer
    // and no fine pointer before treating an otherwise unidentified browser
    // as mobile. A connected mouse/trackpad therefore keeps a desktop browser
    // on the desktop menu/input path.
    final userAgentData:Dynamic = Reflect.field(Browser.navigator, "userAgentData");
    final userAgentDataMobile:Bool = userAgentData != null && Reflect.field(userAgentData, "mobile") == true;
    final hasCoarsePointer:Bool = Browser.window.matchMedia("(pointer: coarse)").matches;
    final hasFinePointer:Bool = Browser.window.matchMedia("(any-pointer: fine)").matches;
    final hasTouchOnlyPrimary:Bool = maxTouchPoints > 0 && hasCoarsePointer && !hasFinePointer;

    cachedIsMobileBrowser = isQuestBrowser
      || userAgent.indexOf("android") >= 0
      || userAgent.indexOf("iphone") >= 0
      || userAgent.indexOf("ipad") >= 0
      || userAgent.indexOf("ipod") >= 0
      || userAgent.indexOf("mobile") >= 0
      || isIPadOS
      || userAgentDataMobile
      || hasTouchOnlyPrimary;
    #else
    cachedIsMobileBrowser = false;
    #end

    return cachedIsMobileBrowser ?? false;
  }

  // --- iPhone Number Detection ---
  #if ios
  public static var iPhoneNumber(get, never):Int;

  private static function get_iPhoneNumber():Int
  {
    // TODO: Add ipad detection gah
    if (!model.startsWith('iPhone')) return 0; // Not an iPhone, must be an ipad!!

    return switch (model)
    {
      // iPhone 12 Series
      case 'iPhone13,1':
        12;
      case 'iPhone13,2':
        12;
      case 'iPhone13,3':
        12;
      case 'iPhone13,4':
        12;

      // iPhone 13 Series
      case 'iPhone14,4':
        13;
      case 'iPhone14,5':
        13;
      case 'iPhone14,2':
        13;
      case 'iPhone14,3':
        13;

      // iPhone 14 Series
      case 'iPhone14,7':
        14;
      case 'iPhone14,8':
        14;
      case 'iPhone15,2':
        14;
      case 'iPhone15,3':
        14;

      // iPhone 15 Series
      case 'iPhone15,4':
        15;
      case 'iPhone15,5':
        15;
      case 'iPhone16,1':
        15;
      case 'iPhone16,2':
        15;

      // iPhone 16 Series
      case 'iPhone17,1':
        16;
      case 'iPhone17,5':
        16;
      case 'iPhone17,4':
        16;
      case 'iPhone17,3':
        16;
      case 'iPhone17,2':
        16;

      // Unknown or newer model fallback
      default:
        final parts = model.substr(6).split(',');
        if (parts.length == 2)
        {
          final major = Std.parseInt(parts[0]);
          final minor = Std.parseInt(parts[1]);
          if (major != null && minor != null)
          {
            if (major > 17 || (major == 17 && minor > 5))
            {
              return 100; // future device
            }
          }
        }
        return 0; // obsolete or unknown
    }
  }
  #end

  // --- General Device Info ---
  public static var osVersion(get, null):String;

  static function get_osVersion():String
  {
    return System.platformVersion;
  }

  public static var vendor(get, null):String;

  static function get_vendor():String
  {
    return System.deviceVendor;
  }

  public static var model(get, null):String;

  static function get_model():String
  {
    return System.deviceModel;
  }
}
