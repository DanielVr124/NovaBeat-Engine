package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.Preferences;
import funkin.mobile.util.MobileOrientationUtil;
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
  var items:TextMenuList;
  var rowBackground:FlxSprite;
  var rowAccent:FlxSprite;
  var rowLabel:FlxText;
  var valueLabel:FlxText;
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
    var rowHeight:Float = Math.max(58, Math.min(76, height * 0.085));

    rowBackground = new FlxSprite(rowX, rowY);
    rowBackground.makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
    add(rowBackground);

    rowAccent = new FlxSprite(rowX, rowY + 7);
    rowAccent.makeGraphic(4, Std.int(rowHeight - 14), accentColor);
    add(rowAccent);

    items = new TextMenuList(NavControls.Vertical);
    var orientationItem:TextMenuItem = items.createItem(rowX + 6, rowY + 4,
      "LOCK CURRENT ORIENTATION", AtlasFont.BOLD, toggleOrientationLock);
    orientationItem.fireInstantly = true;
    orientationItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    orientationItem.updateHitbox();
    orientationItem.atlasText.visible = false;
    add(items);

    rowLabel = makeLabel(rowX + 18, rowY + 8, rowWidth * 0.68, "LOCK CURRENT ORIENTATION", 14, 0xFFB9C8E3);
    add(rowLabel);

    valueLabel = makeLabel(rowX + rowWidth * 0.72, rowY + 8, rowWidth * 0.24, "OFF", 14, accentColor);
    valueLabel.alignment = FlxTextAlign.RIGHT;
    add(valueLabel);

    descriptionText = makeLabel(rowX + 4, rowY + rowHeight + 28, rowWidth - 8,
      "Keep the phone in its current orientation. Turn this off to allow automatic rotation again.",
      12, novaBeatLayout ? 0xFFB6C7E5 : FlxColor.WHITE);
    descriptionText.wordWrap = true;
    descriptionText.autoSize = false;
    add(descriptionText);

    statusText = makeLabel(rowX + 4, panelTop + panelHeight - 42, rowWidth - 8,
      "TAP OR PRESS ENTER TO CHANGE   •   ESC BACK", 9, novaBeatLayout ? 0xFF8DA8D8 : 0xFFCCCCCC);
    add(statusText);

    items.onChange.add(function(selected:TextMenuItem)
    {
      updateRowHighlight();
    });
    updateValue();
    updateRowHighlight();

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 92, 16, FlxColor.WHITE, goBack, 1.0, true);
      add(responsiveBackButton);
    }
    #end

    if (Save.instance.mobileOptions.lockCurrentOrientation && !MobileOrientationUtil.isCurrentlyLocked)
      statusText.text = "SAVED LOCK • TAP THE ROW TO REAPPLY AFTER RELOAD";
    else if (!MobileOrientationUtil.isSupported())
      statusText.text = MobileOrientationUtil.getUnavailableMessage().toUpperCase();
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
    var rowHeight:Float = Math.max(58, Math.min(76, height * 0.085));
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
    var item:TextMenuItem = items.members[0];
    item.setPosition(rowX + 6, rowY + 4);
    item.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    item.updateHitbox();
    rowLabel.setPosition(rowX + 18, rowY + 8);
    rowLabel.fieldWidth = rowWidth * 0.68;
    valueLabel.setPosition(rowX + rowWidth * 0.72, rowY + 8);
    valueLabel.fieldWidth = rowWidth * 0.24;
    descriptionText.setPosition(rowX + 4, rowY + rowHeight + 28);
    descriptionText.fieldWidth = rowWidth - 8;
    descriptionText.size = portrait ? 12 : 13;
    statusText.setPosition(rowX + 4, panelTop + panelHeight - 42);
    statusText.fieldWidth = rowWidth - 8;
    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
  }

  function toggleOrientationLock():Void
  {
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
  }

  function updateValue():Void
  {
    var enabled:Bool = Save.instance.mobileOptions.lockCurrentOrientation;
    valueLabel.text = enabled ? "ON" : "OFF";
    valueLabel.color = enabled ? 0xFF6FE8FF : (novaBeatLayout ? 0xFF48BBD4 : FlxColor.WHITE);
    rowLabel.color = enabled ? FlxColor.WHITE : 0xFFB9C8E3;
  }

  function updateRowHighlight():Void
  {
    var selected:Bool = items != null && items.selectedIndex == 0;
    rowBackground.color = selected ? 0xFF123B5C : 0xFF0D1935;
    rowBackground.alpha = selected ? 1.0 : 0.82;
    rowAccent.alpha = selected ? 1.0 : 0.4;
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

    if (controls.UI_LEFT_P || controls.UI_RIGHT_P || SwipeUtil.swipeLeft || SwipeUtil.swipeRight)
      toggleOrientationLock();
  }

  override function destroy():Void
  {
    super.destroy();
  }
}
