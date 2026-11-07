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
    var rowWidth:Float = width - margin * 2 - 36;
    var rowHeight:Float = Math.max(56, Math.min(72, height * 0.082));
    var rowY:Float = centeredRowsTop(panelTop, panelHeight, rowHeight);

    rowBackground = new FlxSprite(rowX, rowY);
    rowBackground.makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
    add(rowBackground);

    rowAccent = new FlxSprite(rowX, rowY + 7);
    rowAccent.makeGraphic(4, Std.int(rowHeight - 14), accentColor);
    add(rowAccent);


    items = new TextMenuList(NavControls.Vertical);
    items.cameras = [FlxG.camera];
    items.acceptOnTouchSelection = novaBeatLayout;

    var orientationItem:TextMenuItem = items.createItem(rowX + 6, rowY + 4,
      "LOCK CURRENT ORIENTATION", AtlasFont.BOLD, toggleOrientationLock);
    orientationItem.fireInstantly = true;
    orientationItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    orientationItem.updateHitbox();
    orientationItem.atlasText.visible = false;


    add(items);

    rowLabel = makeLabel(rowX + 18, rowY + 8, rowWidth * 0.66, "LOCK CURRENT ORIENTATION", 14, 0xFFB9C8E3);
    add(rowLabel);

    valueLabel = makeLabel(rowX + rowWidth * 0.72, rowY + 8, rowWidth * 0.24, "OFF", 14, accentColor);
    valueLabel.alignment = FlxTextAlign.RIGHT;
    add(valueLabel);


    descriptionText = makeLabel(rowX + 4, rowY + rowHeight + 18, rowWidth - 8,
      "Keep the phone in its current orientation. Turn this off to allow automatic rotation again.",
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
    var rowWidth:Float = width - margin * 2 - 36;
    var rowHeight:Float = Math.max(56, Math.min(72, height * 0.082));
    var rowY:Float = centeredRowsTop(panelTop, panelHeight, rowHeight);
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


    var orientationItem:TextMenuItem = items.members[0];
    orientationItem.setPosition(rowX + 6, rowY + 4);
    orientationItem.makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
    orientationItem.updateHitbox();


    rowLabel.setPosition(rowX + 18, rowY + 8);
    rowLabel.fieldWidth = rowWidth * 0.66;
    valueLabel.setPosition(rowX + rowWidth * 0.72, rowY + 8);
    valueLabel.fieldWidth = rowWidth * 0.24;


    descriptionText.setPosition(rowX + 4, rowY + rowHeight + 18);
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

  function centeredRowsTop(panelTop:Float, panelHeight:Float, rowHeight:Float):Float
  {
    var availableTop:Float = panelTop + 58;
    var availableBottom:Float = panelTop + panelHeight - 58;
    var availableHeight:Float = Math.max(0, availableBottom - availableTop);
    // Center the orientation row and its explanation as one content block.
    var contentHeight:Float = rowHeight + 72;
    return availableTop + Math.max(0, (availableHeight - contentHeight) * 0.5);
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

  function updateRowHighlight():Void
  {
    var selected:Bool = items != null && items.selectedIndex == 0;

    rowBackground.color = selected ? 0xFF123B5C : 0xFF0D1935;
    rowBackground.alpha = selected ? 1.0 : 0.82;
    rowAccent.alpha = selected ? 1.0 : 0.4;
    rowLabel.color = selected ? FlxColor.WHITE : 0xFFB9C8E3;
  }

  function updateDescription():Void
  {
    if (descriptionText == null || items == null) return;

    descriptionText.text = "Keep the phone in its current orientation. Turn this off to allow automatic rotation again.";
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

  override function destroy():Void
  {
    super.destroy();
  }
}
