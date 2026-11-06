package funkin.util;

#if html5
import js.Browser;
#end

/**
 * Adds a small browser-only fullscreen control.
 * The control is hidden while the document is already fullscreen.
 */
class BrowserFullscreenButton
{
  #if html5
  static var button:Dynamic;

  public static function initialize():Void
  {
    if (button != null || Browser.document == null || Browser.document.body == null) return;

    var document:Dynamic = Browser.document;
    var root:Dynamic = document.documentElement;
    if (root == null) return;

    var request:Dynamic = getFullscreenRequest(root);
    // Do not display a control that the current browser cannot actually use.
    if (request == null) return;

    button = document.createElement("button");
    button.textContent = "⛶ Fullscreen";
    button.setAttribute("type", "button");
    button.setAttribute("aria-label", "Enter fullscreen");
    button.setAttribute("title", "Enter fullscreen");
    button.style.cssText = "position:fixed;right:calc(14px + env(safe-area-inset-right, 0px));bottom:calc(14px + env(safe-area-inset-bottom, 0px));z-index:2147483647;padding:10px 14px;border:1px solid rgba(255,255,255,.35);border-radius:9px;background:rgba(20,20,24,.88);color:#fff;font:600 14px Arial,sans-serif;line-height:1.2;cursor:pointer;box-shadow:0 2px 10px rgba(0,0,0,.35);touch-action:manipulation;";
    button.style.display = "none";
    document.body.appendChild(button);

    var refreshVisibility = function(?event:Dynamic):Void
    {
      var active:Bool = document.fullscreenElement != null
        || document.webkitFullscreenElement != null
        || document.mozFullScreenElement != null
        || document.msFullscreenElement != null;
      button.style.display = active ? "none" : "block";
    };

    button.addEventListener("click", function(?event:Dynamic):Void
    {
      var fullscreenRequest:Dynamic = getFullscreenRequest(root);
      if (fullscreenRequest == null) return;
      try
      {
        var result:Dynamic = Reflect.callMethod(root, fullscreenRequest, []);
        // Some browsers return a promise; swallow rejection if fullscreen is denied.
        if (result != null && Reflect.field(result, "catch") != null)
        {
          Reflect.callMethod(result, Reflect.field(result, "catch"), [function(error:Dynamic):Void {}]);
        }
      }
      catch (error:Dynamic)
      {
        trace("Browser fullscreen request was rejected: " + error);
      }
      refreshVisibility();
    });

    document.addEventListener("fullscreenchange", refreshVisibility);
    document.addEventListener("webkitfullscreenchange", refreshVisibility);
    document.addEventListener("mozfullscreenchange", refreshVisibility);
    document.addEventListener("MSFullscreenChange", refreshVisibility);
    refreshVisibility();
  }

  static function getFullscreenRequest(root:Dynamic):Dynamic
  {
    return Reflect.field(root, "requestFullscreen")
      ?? Reflect.field(root, "webkitRequestFullscreen")
      ?? Reflect.field(root, "mozRequestFullScreen")
      ?? Reflect.field(root, "msRequestFullscreen");
  }
  #end
}
