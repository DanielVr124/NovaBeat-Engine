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
    panel.makeGraphic(Std.int(width - margin * 2), Std.int(panelHeight), panelColor);
    add(panel);

    var brand:FlxText = makeLabel(margin + 20, 20, width - margin * 2 - 40, "NOVABEAT ENGINE", 11, accentColor);
    add(brand);

    var heading:FlxText = makeLabel(margin + 20, 44, width - margin * 2 - 40, "MOBILE", 27, FlxColor.WHITE);
    add(heading);

    var intro:FlxText = makeLabel(margin + 22, panelTop + 18, width - margin * 2 - 44,
      "DEVICE & TOUCH EXPERIENCE", 11, accentColor);
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
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 92, 16, FlxColor.WHITE, goBack, 1.0, true);
    add(backButton);
    #end

    if (Save.instance.mobileOptions.lockCurrentOrientation && !MobileOrientationUtil.isCurrentlyLocked)
      statusText.text = "SAVED LOCK • TAP THE ROW TO REAPPLY AFTER RELOAD";
    else if (!MobileOrientationUtil.isSupported())
      statusText.text = MobileOrientationUtil.getUnavailableMessage().toUpperCase();
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
    label.setFormat(Paths.font("vcr.ttf"), size, color, FlxTextAlign.LEFT);
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
