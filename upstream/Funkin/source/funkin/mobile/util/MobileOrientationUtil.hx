package funkin.mobile.util;

#if web
import js.Browser;
#end
#if android
import lime.system.JNI;
#end
import funkin.save.Save;
import funkin.util.DeviceUtil;

class MobileOrientationUtil
{
  static var orientationLocked:Bool = false;
  static var enteredFullscreenForLock:Bool = false;

  public static var isCurrentlyLocked(get, never):Bool;

  static function get_isCurrentlyLocked():Bool
  {
    return orientationLocked;
  }

  public static function isSupported():Bool
  {
    #if android
    return true;
    #elseif web
    if (DeviceUtil.isQuestBrowser) return false;

    var orientation:Dynamic = browserScreenOrientation();
    if (orientation == null || Reflect.field(orientation, "lock") == null) return false;

    var document:Dynamic = Browser.document;
    if (Reflect.field(document, "fullscreenElement") != null) return true;

    var root:Dynamic = Reflect.field(document, "documentElement");
    return root != null && Reflect.field(root, "requestFullscreen") != null;
    #else
    return false;
    #end
  }

  public static function getUnavailableMessage():String
  {
    #if ios
    return "iOS controls rotation through system settings in this build.";
    #elseif web
    if (DeviceUtil.isQuestBrowser) return "Orientation locking is not applicable to a VR headset.";
    return "This browser does not support orientation locking for this page.";
    #else
    return "Orientation locking is not available on this platform.";
    #end
  }

  /**
   * Native Android can reapply its saved lock at startup. Browser APIs require
   * user activation, so the user reapplies the lock from the Mobile page.
   */
  public static function restoreSavedPreference():Void
  {
    #if android
    if (Save.instance.mobileOptions.lockCurrentOrientation)
    {
      setLocked(true, function(success:Bool):Void
      {
        if (!success)
        {
          Save.instance.mobileOptions.lockCurrentOrientation = false;
          Save.system.flush();
        }
      });
    }
    #end
  }

  public static function setLocked(value:Bool, callback:Bool->Void):Void
  {
    if (!value)
    {
      #if android
      try
      {
        var method:Dynamic = JNI.createStaticMethod(
          "funkin/extensions/FNFCExtension", "setOrientationLocked", "(Z)V");
        JNI.callStatic(method, [false]);
        orientationLocked = false;
        callback(true);
      }
      catch (error:Dynamic)
      {
        trace('Could not release Android orientation lock: $error');
        callback(false);
      }
      #elseif web
      unlockBrowserOrientation(callback);
      #else
      orientationLocked = false;
      callback(true);
      #end
      return;
    }

    #if android
    try
    {
      var method:Dynamic = JNI.createStaticMethod(
        "funkin/extensions/FNFCExtension", "setOrientationLocked", "(Z)V");
      JNI.callStatic(method, [true]);
      orientationLocked = true;
      callback(true);
    }
    catch (error:Dynamic)
    {
      trace('Could not lock Android orientation: $error');
      callback(false);
    }
    #elseif web
    lockBrowserOrientation(callback);
    #else
    callback(false);
    #end
  }

  #if web
  static function browserScreenOrientation():Dynamic
  {
    var screen:Dynamic = Reflect.field(Browser.window, "screen");
    return screen == null ? null : Reflect.field(screen, "orientation");
  }

  static function observePromise(promise:Dynamic, onSuccess:Void->Void, onFailure:Void->Void):Bool
  {
    if (promise == null) return false;

    var thenMethod:Dynamic = Reflect.field(promise, "then");
    if (thenMethod == null) return false;

    Reflect.callMethod(promise, thenMethod, [
      function(_:Dynamic):Void onSuccess(),
      function(_:Dynamic):Void onFailure()
    ]);
    return true;
  }

  static function lockBrowserOrientation(callback:Bool->Void):Void
  {
    if (!isSupported())
    {
      callback(false);
      return;
    }

    var orientation:Dynamic = browserScreenOrientation();
    var document:Dynamic = Browser.document;
    var lockMethod:Dynamic = Reflect.field(orientation, "lock");

    var lockNow:Void->Void = function():Void
    {
      var mode:String = Browser.window.innerWidth >= Browser.window.innerHeight ? "landscape" : "portrait";
      var promise:Dynamic = Reflect.callMethod(orientation, lockMethod, [mode]);
      var observed:Bool = observePromise(promise, function():Void
      {
        orientationLocked = true;
        callback(true);
      }, function():Void
      {
        unlockBrowserOrientation(function(_:Bool):Void {});
        callback(false);
      });

      if (!observed)
      {
        unlockBrowserOrientation(function(_:Bool):Void {});
        callback(false);
      }
    };

    if (Reflect.field(document, "fullscreenElement") != null)
    {
      lockNow();
      return;
    }

    var root:Dynamic = Reflect.field(document, "documentElement");
    var requestFullscreen:Dynamic = root == null ? null : Reflect.field(root, "requestFullscreen");
    if (requestFullscreen == null)
    {
      callback(false);
      return;
    }

    var fullscreenPromise:Dynamic = Reflect.callMethod(root, requestFullscreen, []);
    var observed:Bool = observePromise(fullscreenPromise, function():Void
    {
      enteredFullscreenForLock = true;
      lockNow();
    }, function():Void
    {
      callback(false);
    });

    if (!observed) callback(false);
  }

  static function unlockBrowserOrientation(callback:Bool->Void):Void
  {
    var orientation:Dynamic = browserScreenOrientation();
    var unlockMethod:Dynamic = orientation == null ? null : Reflect.field(orientation, "unlock");

    if (unlockMethod != null)
    {
      try
      {
        Reflect.callMethod(orientation, unlockMethod, []);
      }
      catch (error:Dynamic)
      {
        trace('Browser orientation unlock failed: $error');
      }
    }

    if (enteredFullscreenForLock)
    {
      var document:Dynamic = Browser.document;
      var exitFullscreen:Dynamic = Reflect.field(document, "exitFullscreen");
      if (exitFullscreen != null)
      {
        try
        {
          Reflect.callMethod(document, exitFullscreen, []);
        }
        catch (error:Dynamic)
        {
          trace('Could not exit orientation-lock fullscreen: $error');
        }
      }
      enteredFullscreenForLock = false;
    }

    orientationLocked = false;
    callback(true);
  }
  #end
}
