package funkin.mobile.util;

#if web
import js.Browser;
#end

/**
 * Keeps a phone screen awake while a song is active in a mobile browser.
 *
 * Native Android/iOS builds continue using Lime's native screen-timeout
 * handling. Browsers use the Screen Wake Lock API when it is available.
 */
class MobileWakeLockUtil
{
  #if web
  static var gameplayActive:Bool = false;
  static var requestPending:Bool = false;
  static var visibilityListenerRegistered:Bool = false;
  static var activeWakeLock:Dynamic = null;
  #end

  /**
   * Enables or disables the screen wake lock for gameplay.
   * Unsupported browsers safely do nothing.
   */
  public static function setGameplayActive(active:Bool):Void
  {
    #if web
    gameplayActive = active;

    if (active)
    {
      installVisibilityListener();
      requestWakeLock();
    }
    else
    {
      releaseWakeLock();
    }
    #end
  }

  #if web
  static function installVisibilityListener():Void
  {
    if (visibilityListenerRegistered) return;

    final document:Dynamic = Browser.document;
    final addEventListener:Dynamic = Reflect.field(document, "addEventListener");
    if (addEventListener == null) return;

    final listener:Dynamic = function(_:Dynamic):Void
    {
      if (!gameplayActive) return;

      if (isDocumentVisible())
      {
        requestWakeLock();
      }
      else
      {
        releaseWakeLock();
      }
    };

    Reflect.callMethod(document, addEventListener, ["visibilitychange", listener]);
    visibilityListenerRegistered = true;
  }

  static function isDocumentVisible():Bool
  {
    return Reflect.field(Browser.document, "visibilityState") == "visible";
  }

  static function requestWakeLock():Void
  {
    if (!gameplayActive || !isDocumentVisible() || activeWakeLock != null || requestPending) return;

    final navigator:Dynamic = Browser.navigator;
    final wakeLockApi:Dynamic = Reflect.field(navigator, "wakeLock");
    final requestMethod:Dynamic = wakeLockApi == null ? null : Reflect.field(wakeLockApi, "request");
    if (requestMethod == null) return;

    requestPending = true;

    try
    {
      final promise:Dynamic = Reflect.callMethod(wakeLockApi, requestMethod, ["screen"]);
      final thenMethod:Dynamic = promise == null ? null : Reflect.field(promise, "then");

      if (thenMethod == null)
      {
        requestPending = false;
        return;
      }

      final onSuccess:Dynamic = function(sentinel:Dynamic):Void
      {
        requestPending = false;

        if (!gameplayActive || !isDocumentVisible())
        {
          releaseSentinel(sentinel);
          return;
        }

        activeWakeLock = sentinel;

        final addEventListener:Dynamic = Reflect.field(sentinel, "addEventListener");
        if (addEventListener != null)
        {
          final onRelease:Dynamic = function(_:Dynamic):Void
          {
            if (activeWakeLock == sentinel) activeWakeLock = null;
            if (gameplayActive && isDocumentVisible()) requestWakeLock();
          };

          Reflect.callMethod(sentinel, addEventListener, ["release", onRelease]);
        }
      };

      final onFailure:Dynamic = function(_:Dynamic):Void
      {
        requestPending = false;
      };

      Reflect.callMethod(promise, thenMethod, [onSuccess, onFailure]);
    }
    catch (error:Dynamic)
    {
      requestPending = false;
    }
  }

  static function releaseWakeLock():Void
  {
    final sentinel:Dynamic = activeWakeLock;
    activeWakeLock = null;
    releaseSentinel(sentinel);
  }

  static function releaseSentinel(sentinel:Dynamic):Void
  {
    if (sentinel == null) return;

    final releaseMethod:Dynamic = Reflect.field(sentinel, "release");
    if (releaseMethod == null) return;

    try
    {
      Reflect.callMethod(sentinel, releaseMethod, []);
    }
    catch (error:Dynamic)
    {
      // Wake locks may already have been released by the browser.
    }
  }
  #end
}
