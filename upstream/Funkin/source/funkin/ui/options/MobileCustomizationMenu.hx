package funkin.ui.options;

import flixel.FlxG;
import flixel.util.FlxColor;
import funkin.Preferences;
import funkin.mobile.ui.FunkinHitbox.FunkinHitboxControlSchemes;
import funkin.mobile.util.MobileOrientationUtil;
import funkin.save.Save;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.MenuList.NavControls;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.util.DeviceUtil;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end

/**
 * Mobile options using the original FNF text-list presentation.
 * The control layouts and orientation setting remain available without
 * injecting a separate NovaBeat panel or row design into the options menu.
 */
class MobileCustomizationMenu extends Page<OptionsState.OptionsMenuPageName>
{
  static final CONTROL_SCHEMES:Array<String> = [
    FunkinHitboxControlSchemes.Arrows,
    FunkinHitboxControlSchemes.FourLanes,
    FunkinHitboxControlSchemes.DoubleThumbDPad,
    FunkinHitboxControlSchemes.DoubleThumbTriangle,
    FunkinHitboxControlSchemes.DoubleThumbSquare
  ];

  var items:TextMenuList;
  var controlSchemeItem:TextMenuItem;
  var orientationLockItem:TextMenuItem;
  var controlSchemeLabel:String;
  var orientationLockLabel:String;
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  public function new()
  {
    super();

    items = new TextMenuList(NavControls.Vertical);
    items.cameras = [FlxG.camera];
    items.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;
    add(items);

    controlSchemeLabel = "MOBILE CONTROLS";
    controlSchemeItem = items.createItem(0, 120, controlSchemeLabel, AtlasFont.BOLD, function()
    {
      cycleControlScheme(1);
    });
    controlSchemeItem.fireInstantly = true;

    orientationLockLabel = "LOCK ORIENTATION";
    orientationLockItem = items.createItem(0, 230, orientationLockLabel, AtlasFont.BOLD, function()
    {
      toggleOrientationLock();
    });
    orientationLockItem.fireInstantly = true;

    updateValues();
    layoutItems(FlxG.width, FlxG.height);

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 92, FlxG.height - 92,
        FlxColor.WHITE, goBack, 1.0, true);
      add(responsiveBackButton);
    }
    #end
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    layoutItems(width, height);
  }

  function layoutItems(width:Int, height:Int):Void
  {
    if (items == null || width <= 0 || height <= 0) return;

    var portrait:Bool = height > width * 1.12;
    var top:Float = portrait ? height * 0.30 : height * 0.22;
    var gap:Float = portrait ? Math.min(110, height * 0.18) : 110;

    for (index in 0...items.members.length)
    {
      var item:TextMenuItem = items.members[index];
      if (item == null) continue;
      item.x = 0;
      item.y = top + index * gap;
      item.screenCenter(X);
    }

    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
  }

  function cycleControlScheme(direction:Int):Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var currentIndex:Int = CONTROL_SCHEMES.indexOf(Preferences.controlsScheme);
    if (currentIndex < 0) currentIndex = 0;
    var nextIndex:Int = (currentIndex + direction + CONTROL_SCHEMES.length) % CONTROL_SCHEMES.length;
    Preferences.controlsScheme = CONTROL_SCHEMES[nextIndex];
    updateValues();
    #end
  }

  function toggleOrientationLock():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (!MobileOrientationUtil.isSupported()) return;

    var saved:Bool = Save.instance.mobileOptions.lockCurrentOrientation;
    var targetValue:Bool = !(saved && MobileOrientationUtil.isCurrentlyLocked);
    if (!targetValue && !MobileOrientationUtil.isCurrentlyLocked && saved) targetValue = true;

    MobileOrientationUtil.setLocked(targetValue, function(success:Bool):Void
    {
      if (success)
      {
        Save.instance.mobileOptions.lockCurrentOrientation = targetValue;
        Save.system.flush();
        updateValues();
      }
    });
    #end
  }

  function updateValues():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var schemeIndex:Int = CONTROL_SCHEMES.indexOf(Preferences.controlsScheme);
    if (schemeIndex < 0) schemeIndex = 0;
    var schemeLabel:String = "MOBILE CONTROLS: " + CONTROL_SCHEMES[schemeIndex].toUpperCase();
    var orientationValue:String = !MobileOrientationUtil.isSupported()
      ? "UNAVAILABLE"
      : (Save.instance.mobileOptions.lockCurrentOrientation ? "ON" : "OFF");
    #else
    var schemeLabel:String = "MOBILE CONTROLS: UNAVAILABLE";
    var orientationValue:String = "UNAVAILABLE";
    #end

    var nextOrientationLabel:String = "LOCK ORIENTATION: " + orientationValue;
    if (schemeLabel != controlSchemeLabel)
    {
      items.resetItem(controlSchemeLabel, schemeLabel, function()
      {
        cycleControlScheme(1);
      });
      controlSchemeLabel = schemeLabel;
    }
    if (nextOrientationLabel != orientationLockLabel)
    {
      items.resetItem(orientationLockLabel, nextOrientationLabel, function()
      {
        toggleOrientationLock();
      });
      orientationLockLabel = nextOrientationLabel;
    }

    layoutItems(FlxG.width, FlxG.height);
  }

  function goBack():Void
  {
    onExit.dispatch();
  }
}
