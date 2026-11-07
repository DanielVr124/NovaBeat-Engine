package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.Preferences;
import funkin.mobile.util.MobileOrientationUtil;
import funkin.mobile.ui.options.ControlsSchemeMenu;
import funkin.mobile.ui.FunkinHitbox.FunkinHitboxControlSchemes;
import funkin.save.Save;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.MenuList.NavControls;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.util.SwipeUtil;
import funkin.util.DeviceUtil;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end

class MobileCustomizationMenu extends Page<OptionsState.OptionsMenuPageName>
{
  static final AVAILABLE_CONTROL_SCHEMES:Array<String> = [
    FunkinHitboxControlSchemes.Arrows,
    FunkinHitboxControlSchemes.FourLanes,
    FunkinHitboxControlSchemes.DoubleThumbTriangle,
    FunkinHitboxControlSchemes.DoubleThumbSquare,
    FunkinHitboxControlSchemes.DoubleThumbDPad
  ];

  var items:TextMenuList;
  var rowBackground:FlxSprite;
  var rowAccent:FlxSprite;
  var controlsRowBackground:FlxSprite;
  var controlsRowAccent:FlxSprite;
  var rowLabel:FlxText;
  var valueLabel:FlxText;
  var controlsSchemeLabel:FlxText;
  var controlsSchemeValue:FlxText;
  var descriptionText:FlxText;
  var statusText:FlxText;
  var novaBeatLayout:Bool = true;
  var panelBackground:Null<FlxSprite> = null;
  var brandLabel:Null<FlxText> = null;
  var headingLabel:Null<FlxText> = null;
  var introLabel:Null<FlxText> = null;
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  public function new()
  {
    super();

    novaBeatLayout = Preferences.menuStyle == "NovaBeat";

    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    var margin:Float = Math.max(18, width * 0.04);
    var panelTop:Float = 104;
    var panelHeight:Float = Math.max(190, height - 142);
    var panelColor:FlxColor = novaBeatLayout ? 0xC9091833 : 0xB8000000;
    var accentColor:FlxColor = novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE;

    var panel:FlxSprite = new FlxSprite(margin, panelTop);
    panelBackground = panel;
    panel.makeGraphic(Std.int(width - margin * 2), Std.int(panelHeight), panelColor);
    add(panel);

    var brand:FlxText = makeLabel(margin + 20, 20, width - margin * 2 - 40, "NOVABEAT ENGINE", 11, accentColor);
    brandLabel = brand;
    add(brand);

    var heading:FlxText = makeLabel(margin + 20, 44, width - margin * 2 - 40, "MOBILE", 27, FlxColor.WHITE);
    headingLabel = heading;
    add(heading);

    var intro:FlxText = makeLabel(margin + 22, panelTop + 18, width - margin * 2 - 44,
      "DEVICE & TOUCH EXPERIENCE", 11, accentColor);
    introLabel = intro;
    add(intro);

    var rowX:Float = margin + 18;
    var rowY:Float = panelTop + 66;
    var rowWidth:Float = width - margin * 2 - 36;
    var rowHeight:Float = Math.max(56, Math.min(72, height * 0.082));
    var controlsRowY:Float = rowY + rowHeight + 14;

    rowBackground = new FlxSprite(rowX, rowY);
    rowBackground.makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
    add(rowBackground);

    rowAccent = new FlxSprite(rowX, rowY + 7);
    rowAccent.makeGraphic(4, Std.int(rowHeight - 14), accentColor);
    add(rowAccent);

    controlsRowBackground = new FlxSprite(rowX, controlsRowY);
    controlsRowBackground.makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
    add(controlsRowBackground);

    controlsRowAccent = new FlxSprite(rowX, controlsRowY + 7);
    controlsRowAccent.makeGraphic(4, Std.int(rowHeight - 14), accentColor);
    add(controlsRowAccent);

    items = new TextMenuList(NavControls.Vertical);

    var orientationItem:TextMenuItem = items.createItem(rowX + 6, rowY + 4,
      "LOCK CURRENT ORIENTATION", AtlasFont.BOLD, toggleOrientationLock);
    orientationItem.fireInstantly = true;
    orientationItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    orientationItem.updateHitbox();
    orientationItem.atlasText.visible = false;

    var controlsSchemeItem:TextMenuItem = items.createItem(rowX + 6, controlsRowY + 4,
      "TOUCH CONTROL SCHEME", AtlasFont.BOLD, openControlsSchemeMenu);
    controlsSchemeItem.fireInstantly = true;
    controlsSchemeItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    controlsSchemeItem.updateHitbox();
    controlsSchemeItem.atlasText.visible = false;

    add(items);

    rowLabel = makeLabel(rowX + 18, rowY + 8, rowWidth * 0.66, "LOCK CURRENT ORIENTATION", 14, 0xFFB9C8E3);
    add(rowLabel);

    valueLabel = makeLabel(rowX + rowWidth * 0.72, rowY + 8, rowWidth * 0.24, "OFF", 14, accentColor);
    valueLabel.alignment = FlxTextAlign.RIGHT;
    add(valueLabel);

    controlsSchemeLabel = makeLabel(rowX + 18, controlsRowY + 8, rowWidth * 0.60, "TOUCH CONTROL SCHEME", 14, 0xFFB9C8E3);
    add(controlsSchemeLabel);

    controlsSchemeValue = makeLabel(rowX + rowWidth * 0.66, controlsRowY + 8, rowWidth * 0.30, "ARROWS", 13, accentColor);
    controlsSchemeValue.alignment = FlxTextAlign.RIGHT;
    add(controlsSchemeValue);

    descriptionText = makeLabel(rowX + 4, controlsRowY + rowHeight + 18, rowWidth - 8,
      "Choose one of the five original FNF touch layouts. Tap this row to preview them, or use left and right to cycle.",
      12, novaBeatLayout ? 0xFFB6C7E5 : FlxColor.WHITE);
    descriptionText.wordWrap = true;
    descriptionText.autoSize = false;
    add(descriptionText);

    statusText = makeLabel(rowX + 4, panelTop + panelHeight - 42, rowWidth - 8,
      "TAP A ROW TO CHANGE   •   ESC BACK", 9, novaBeatLayout ? 0xFF8DA8D8 : 0xFFCCCCCC);
    add(statusText);

    items.onChange.add(function(selected:TextMenuItem)
    {
      updateRowHighlight();
      updateDescription();
    });
    updateValue();
    updateControlsSchemeValue();
    updateRowHighlight();
    updateDescription();

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 92, FlxG.height - 92, FlxColor.WHITE, goBack, 1.0, true);
      add(responsiveBackButton);
    }
    #end

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (Save.instance.mobileOptions.lockCurrentOrientation && !MobileOrientationUtil.isCurrentlyLocked)
      statusText.text = "SAVED LOCK • TAP THE ROW TO REAPPLY AFTER RELOAD";
    else if (!MobileOrientationUtil.isSupported())
      statusText.text = MobileOrientationUtil.getUnavailableMessage().toUpperCase();
    #else
    statusText.text = "MOBILE SETTINGS ARE UNAVAILABLE IN THIS BUILD";
    #end
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;

    var margin:Float = Math.max(18, width * 0.04);
    var panelTop:Float = 104;
    var panelHeight:Float = Math.max(190, height - 142);
    var rowX:Float = margin + 18;
    var rowY:Float = panelTop + 66;
    var rowWidth:Float = width - margin * 2 - 36;
    var rowHeight:Float = Math.max(56, Math.min(72, height * 0.082));
    var controlsRowY:Float = rowY + rowHeight + 14;
    var portrait:Bool = height > width * 1.12;

    if (panelBackground != null)
    {
      panelBackground.setPosition(margin, panelTop);
      panelBackground.makeGraphic(Std.int(width - margin * 2), Std.int(panelHeight), novaBeatLayout ? 0xC9091833 : 0xB8000000);
    }
    if (brandLabel != null)
    {
      brandLabel.setPosition(margin + 20, 20);
      brandLabel.fieldWidth = width - margin * 2 - 40;
    }
    if (headingLabel != null)
    {
      headingLabel.setPosition(margin + 20, 44);
      headingLabel.fieldWidth = width - margin * 2 - 40;
      headingLabel.size = portrait ? 24 : 27;
    }
    if (introLabel != null)
    {
      introLabel.setPosition(margin + 22, panelTop + 18);
      introLabel.fieldWidth = width - margin * 2 - 44;
    }

    rowBackground.setPosition(rowX, rowY);
    rowBackground.makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
    rowAccent.setPosition(rowX, rowY + 7);
    rowAccent.makeGraphic(4, Std.int(rowHeight - 14), novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE);

    controlsRowBackground.setPosition(rowX, controlsRowY);
    controlsRowBackground.makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
    controlsRowAccent.setPosition(rowX, controlsRowY + 7);
    controlsRowAccent.makeGraphic(4, Std.int(rowHeight - 14), novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE);

    var orientationItem:TextMenuItem = items.members[0];
    orientationItem.setPosition(rowX + 6, rowY + 4);
    orientationItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    orientationItem.updateHitbox();

    var controlsSchemeItem:TextMenuItem = items.members[1];
    controlsSchemeItem.setPosition(rowX + 6, controlsRowY + 4);
    controlsSchemeItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    controlsSchemeItem.updateHitbox();

    rowLabel.setPosition(rowX + 18, rowY + 8);
    rowLabel.fieldWidth = rowWidth * 0.66;
    valueLabel.setPosition(rowX + rowWidth * 0.72, rowY + 8);
    valueLabel.fieldWidth = rowWidth * 0.24;

    controlsSchemeLabel.setPosition(rowX + 18, controlsRowY + 8);
    controlsSchemeLabel.fieldWidth = rowWidth * 0.60;
    controlsSchemeValue.setPosition(rowX + rowWidth * 0.66, controlsRowY + 8);
    controlsSchemeValue.fieldWidth = rowWidth * 0.30;
    controlsSchemeValue.size = portrait ? 11 : 13;

    descriptionText.setPosition(rowX + 4, controlsRowY + rowHeight + 18);
    descriptionText.fieldWidth = rowWidth - 8;
    descriptionText.size = portrait ? 12 : 13;
    statusText.setPosition(rowX + 4, panelTop + panelHeight - 42);
    statusText.fieldWidth = rowWidth - 8;

    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end

    updateRowHighlight();
    updateDescription();
  }

  function toggleOrientationLock():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var saved:Bool = Save.instance.mobileOptions.lockCurrentOrientation;
    var targetValue:Bool = !(saved && MobileOrientationUtil.isCurrentlyLocked);

    if (!targetValue && !MobileOrientationUtil.isCurrentlyLocked && saved)
    {
      // On browser reload the saved preference still needs an explicit user
      // gesture, so one tap reapplies it; the next tap will release it.
      targetValue = true;
    }

    MobileOrientationUtil.setLocked(targetValue, function(success:Bool):Void
    {
      if (success)
      {
        Save.instance.mobileOptions.lockCurrentOrientation = targetValue;
        Save.system.flush();
        statusText.text = targetValue ? "CURRENT ORIENTATION LOCKED" : "AUTOMATIC ROTATION RESTORED";
        updateValue();
      }
      else
      {
        statusText.text = MobileOrientationUtil.getUnavailableMessage().toUpperCase();
      }
    });
    #else
    statusText.text = "MOBILE ORIENTATION SETTINGS ARE UNAVAILABLE IN THIS BUILD";
    #end
  }

  function openControlsSchemeMenu():Void
  {
    FlxG.state.openSubState(new ControlsSchemeMenu(function():Void
    {
      updateControlsSchemeValue();
      updateDescription();
      statusText.text = "CONTROL SCHEME SAVED";
    }));
  }

  function cycleControlsScheme(direction:Int):Void
  {
    if (AVAILABLE_CONTROL_SCHEMES.length == 0 || direction == 0) return;

    var index:Int = AVAILABLE_CONTROL_SCHEMES.indexOf(Preferences.controlsScheme);
    if (index < 0) index = 0;
    index = (index + direction + AVAILABLE_CONTROL_SCHEMES.length) % AVAILABLE_CONTROL_SCHEMES.length;

    Preferences.controlsScheme = AVAILABLE_CONTROL_SCHEMES[index];
    updateControlsSchemeValue();
    statusText.text = "CONTROL SCHEME: " + schemeDisplayName(Preferences.controlsScheme);
  }

  function schemeDisplayName(scheme:String):String
  {
    return switch (scheme)
    {
      case FunkinHitboxControlSchemes.Arrows: "ARROWS";
      case FunkinHitboxControlSchemes.FourLanes: "FOUR LANES";
      case FunkinHitboxControlSchemes.DoubleThumbTriangle: "TRIANGLE";
      case FunkinHitboxControlSchemes.DoubleThumbSquare: "SQUARE";
      case FunkinHitboxControlSchemes.DoubleThumbDPad: "D-PAD";
      default: scheme.toUpperCase();
    };
  }

  function updateValue():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var enabled:Bool = Save.instance.mobileOptions.lockCurrentOrientation;
    valueLabel.text = enabled ? "ON" : "OFF";
    valueLabel.color = enabled ? 0xFF6FE8FF : (novaBeatLayout ? 0xFF48BBD4 : FlxColor.WHITE);
    #else
    valueLabel.text = "N/A";
    valueLabel.color = FlxColor.GRAY;
    #end
  }

  function updateControlsSchemeValue():Void
  {
    controlsSchemeValue.text = schemeDisplayName(Preferences.controlsScheme);
  }

  function updateRowHighlight():Void
  {
    var selectedOrientation:Bool = items != null && items.selectedIndex == 0;
    var selectedScheme:Bool = items != null && items.selectedIndex == 1;

    rowBackground.color = selectedOrientation ? 0xFF123B5C : 0xFF0D1935;
    rowBackground.alpha = selectedOrientation ? 1.0 : 0.82;
    rowAccent.alpha = selectedOrientation ? 1.0 : 0.4;
    rowLabel.color = selectedOrientation ? FlxColor.WHITE : 0xFFB9C8E3;

    controlsRowBackground.color = selectedScheme ? 0xFF123B5C : 0xFF0D1935;
    controlsRowBackground.alpha = selectedScheme ? 1.0 : 0.82;
    controlsRowAccent.alpha = selectedScheme ? 1.0 : 0.4;
    controlsSchemeLabel.color = selectedScheme ? FlxColor.WHITE : 0xFFB9C8E3;
    controlsSchemeValue.color = selectedScheme ? 0xFF48E7FF : (novaBeatLayout ? 0xFF48BBD4 : FlxColor.WHITE);
  }

  function updateDescription():Void
  {
    if (descriptionText == null || items == null) return;

    if (items.selectedIndex == 0)
    {
      descriptionText.text = "Keep the phone in its current orientation. Turn this off to allow automatic rotation again.";
    }
    else
    {
      descriptionText.text = "Choose one of the five original FNF touch layouts. Tap this row to preview them, or use left and right to cycle.";
    }
  }

  function goBack():Void
  {
    onExit.dispatch();
  }

  function makeLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(novaBeatLayout ? "Arial" : Paths.font("vcr.ttf"), size, color, FlxTextAlign.LEFT);
    label.scrollFactor.set();
    return label;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!enabled || items == null) return;

    // Keep the original FNF mobile swipe recognizer for every menu style.
    var movedLeft:Bool = controls.UI_LEFT_P || SwipeUtil.swipeLeft;
    var movedRight:Bool = controls.UI_RIGHT_P || SwipeUtil.swipeRight;

    if (movedLeft || movedRight)
    {
      var direction:Int = movedLeft ? -1 : 1;
      if (items.selectedIndex == 0) toggleOrientationLock();
      else cycleControlsScheme(direction);
    }
  }

  override function destroy():Void
  {
    super.destroy();
  }
}
