package funkin.util;

#if web
import js.Browser;
#end
import lime.system.System;

class DeviceUtil
{
  /**
   * Whether the current HTML5 browser is running on a Meta Quest headset.
   *
   * Quest Browser uses a desktop-like Linux user agent in its default mode,
   * so normal Android/mobile checks do not identify it.
   */
  public static var isQuestBrowser(get, never):Bool;

  static function get_isQuestBrowser():Bool
  {
    #if web
    final userAgent:String = Browser.navigator.userAgent.toLowerCase();
    return userAgent.indexOf("oculusbrowser") >= 0
      || userAgent.indexOf("quest") >= 0
      || userAgent.indexOf("mobile vr") >= 0;
    #else
    return false;
    #end
  }

  /**
   * Whether the current target should use mobile-friendly menu layouts.
   * Includes native mobile targets and mobile/Quest browsers in the HTML5 build.
   */
  public static var isMobileBrowser(get, never):Bool;

  static function get_isMobileBrowser():Bool
  {
    #if mobile
    return true;
    #elseif web
    final userAgent:String = Browser.navigator.userAgent.toLowerCase();
    final platform:String = Std.string(Reflect.field(Browser.navigator, "platform"));
    final maxTouchPoints:Int = Std.parseInt(Std.string(Reflect.field(Browser.navigator, "maxTouchPoints"))) ?? 0;
    final isIPadOS:Bool = platform == "MacIntel" && maxTouchPoints > 1;

    // Some mobile browsers can use a desktop-style user agent (for example,
    // when "Desktop site" is enabled). Prefer the browser's explicit mobile
    // hint and primary-pointer capabilities as additional signals.
    final userAgentData:Dynamic = Reflect.field(Browser.navigator, "userAgentData");
    final userAgentDataMobile:Bool = userAgentData != null && Reflect.field(userAgentData, "mobile") == true;
    var primaryPointerIsCoarse:Bool = false;
    try
    {
      final matchMedia:Dynamic = Reflect.field(Browser.window, "matchMedia");
      if (matchMedia != null)
      {
        final pointerQuery:Dynamic = Reflect.callMethod(Browser.window, matchMedia, ["(pointer: coarse)"]);
        primaryPointerIsCoarse = pointerQuery != null && Reflect.field(pointerQuery, "matches") == true;
      }
    }
    catch (error:Dynamic)
    {
      primaryPointerIsCoarse = false;
    }
    final hasTouchFirstPointer:Bool = maxTouchPoints > 0 && primaryPointerIsCoarse;

    return isQuestBrowser
      || userAgent.indexOf("android") >= 0
      || userAgent.indexOf("iphone") >= 0
      || userAgent.indexOf("ipad") >= 0
      || userAgent.indexOf("ipod") >= 0
      || userAgent.indexOf("mobile") >= 0
      || isIPadOS
      || userAgentDataMobile
      || hasTouchFirstPointer;
    #else
    return false;
    #end
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
