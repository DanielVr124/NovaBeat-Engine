package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
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

class MobileCustomizationMenu extends Page<OptionsState.OptionsMenuPageName>
{
  static final CONTROL_SCHEMES:Array<String> = [
    FunkinHitboxControlSchemes.Arrows,
    FunkinHitboxControlSchemes.FourLanes,
    FunkinHitboxControlSchemes.DoubleThumbTriangle,
    FunkinHitboxControlSchemes.DoubleThumbSquare,
    FunkinHitboxControlSchemes.DoubleThumbDPad
  ];

  var items:TextMenuList;
  var rowItems:Array<TextMenuItem> = [];
  var rowBackgrounds:Array<FlxSprite> = [];
  var rowAccents:Array<FlxSprite> = [];
  var rowLabels:Array<FlxText> = [];
  var valueLabels:Array<FlxText> = [];
  var panelBackground:FlxSprite;
  var brandLabel:FlxText;
  var headingLabel:FlxText;
  var introLabel:FlxText;
  var descriptionText:FlxText;
  var statusText:FlxText;
  var novaBeatLayout:Bool = false;
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  public function new()
  {
    super();
    novaBeatLayout = Preferences.menuStyle == "NovaBeat";
    panelBackground = new FlxSprite();
    add(panelBackground);
    brandLabel = makeLabel(0, 0, 100, "NOVABEAT ENGINE", 11, novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE);
    add(brandLabel);
    headingLabel = makeLabel(0, 0, 100, "MOBILE", 27, FlxColor.WHITE);
    add(headingLabel);
    introLabel = makeLabel(0, 0, 100, "DEVICE & TOUCH EXPERIENCE", 11, novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE);
    add(introLabel);

    items = new TextMenuList(NavControls.Vertical);
    items.cameras = [FlxG.camera];
    items.acceptOnTouchSelection = true;

    for (index in 0...2)
    {
      var itemIndex:Int = index;
      var labelText:String = index == 0 ? "MOBILE CONTROLS LAYOUT" : "LOCK CURRENT ORIENTATION";
      var item:TextMenuItem = items.createItem(0, 0, labelText, AtlasFont.BOLD, function()
      {
        if (itemIndex == 0) cycleControlScheme(1);
        else toggleOrientationLock();
      });
      item.fireInstantly = true;
      item.makeGraphic(1, 1, FlxColor.TRANSPARENT);
      item.updateHitbox();
      item.atlasText.visible = false;
      rowItems.push(item);

      var background:FlxSprite = new FlxSprite();
      background.makeGraphic(1, 1, 0xFF0D1935);
      add(background);
      rowBackgrounds.push(background);

      var accent:FlxSprite = new FlxSprite();
      accent.makeGraphic(4, 24, novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE);
      add(accent);
      rowAccents.push(accent);

      var label:FlxText = makeLabel(0, 0, 100, labelText, 14, 0xFFB9C8E3);
      add(label);
      rowLabels.push(label);

      var value:FlxText = makeLabel(0, 0, 100, "", 14, novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE);
      value.alignment = FlxTextAlign.RIGHT;
      add(value);
      valueLabels.push(value);
    }

    add(items);
    descriptionText = makeLabel(0, 0, 100, "", 12, novaBeatLayout ? 0xFFB6C7E5 : FlxColor.WHITE);
    descriptionText.wordWrap = true;
    descriptionText.autoSize = false;
    add(descriptionText);
    statusText = makeLabel(0, 0, 100, "TAP A ROW TO CHANGE   •   ESC BACK", 9,
      novaBeatLayout ? 0xFF8DA8D8 : 0xFFCCCCCC);
    add(statusText);

    items.onChange.add(function(selected:TextMenuItem)
    {
      updateRowHighlights();
      updateDescription();
    });

    layoutElements(FlxG.width, FlxG.height);
    updateValues();
    updateRowHighlights();
    updateDescription();

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 92, FlxG.height - 92,
        FlxColor.WHITE, goBack, 1.0, true);
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
    layoutElements(width, height);
  }

  function layoutElements(width:Int, height:Int):Void
  {
    var compact:Bool = height < 420;
    var margin:Float = Math.max(16, width * 0.04);
    var panelTop:Float = compact ? 80 : 100;
    var panelHeight:Float = Math.max(160, height - (compact ? 100 : 142));
    var panelWidth:Float = Math.max(1, width - margin * 2);
    var accentColor:FlxColor = novaBeatLayout ? 0xFF48E7FF : FlxColor.WHITE;

    panelBackground.setPosition(margin, panelTop);
    panelBackground.makeGraphic(Std.int(panelWidth), Std.int(panelHeight),
      novaBeatLayout ? 0xC9091833 : 0xB8000000);
    brandLabel.setPosition(margin + 18, compact ? 8 : 20);
    brandLabel.fieldWidth = panelWidth - 36;
    headingLabel.setPosition(margin + 18, compact ? 30 : 44);
    headingLabel.fieldWidth = panelWidth - 36;
    headingLabel.size = compact ? 22 : 27;
    introLabel.setPosition(margin + 20, panelTop + (compact ? 14 : 18));
    introLabel.fieldWidth = panelWidth - 40;

    var contentTop:Float = panelTop + (compact ? 50 : 72);
    var statusY:Float = panelTop + panelHeight - (compact ? 24 : 34);
    var descriptionReserve:Float = compact ? 48 : 62;
    var usableBottom:Float = statusY - descriptionReserve;
    var minRowHeight:Float = compact ? 42 : 52;
    var maxRowHeight:Float = compact ? 56 : 74;
    var rowHeight:Float = Math.max(minRowHeight, Math.min(maxRowHeight, (usableBottom - contentTop - 12) / 2));
    var groupHeight:Float = rowHeight * 2 + 12;
    var availableHeight:Float = Math.max(groupHeight, usableBottom - contentTop);
    var rowStart:Float = contentTop + Math.max(0, (availableHeight - groupHeight) * 0.5);
    var rowWidth:Float = panelWidth - 32;
    var rowX:Float = margin + 16;

    for (index in 0...rowItems.length)
    {
      var y:Float = rowStart + index * (rowHeight + 12);
      rowBackgrounds[index].setPosition(rowX, y);
      rowBackgrounds[index].makeGraphic(Std.int(rowWidth), Std.int(rowHeight), 0xFF0D1935);
      rowAccents[index].setPosition(rowX, y + 7);
      rowAccents[index].makeGraphic(4, Std.int(Math.max(18, rowHeight - 14)), accentColor);
      rowItems[index].setPosition(rowX + 6, y + 4);
      rowItems[index].makeGraphic(Std.int(rowWidth - 12), Std.int(rowHeight - 8), FlxColor.TRANSPARENT);
      rowItems[index].updateHitbox();

      rowLabels[index].setPosition(rowX + 18, y + Math.max(8, (rowHeight - rowLabels[index].height) * 0.5));
      rowLabels[index].fieldWidth = rowWidth * 0.66;
      rowLabels[index].size = compact ? 12 : 14;
      valueLabels[index].setPosition(rowX + rowWidth * 0.70, y + Math.max(8, (rowHeight - valueLabels[index].height) * 0.5));
      valueLabels[index].fieldWidth = rowWidth * 0.26;
      valueLabels[index].size = compact ? 12 : 14;
    }

    var descriptionY:Float = rowStart + groupHeight + 10;
    descriptionText.setPosition(rowX + 4, descriptionY);
    descriptionText.fieldWidth = rowWidth - 8;
    descriptionText.size = compact ? 10 : 12;
    statusText.setPosition(rowX + 4, statusY);
    statusText.fieldWidth = rowWidth - 8;

    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
    updateRowHighlights();
    updateDescription();
  }

  function cycleControlScheme(direction:Int):Void
  {
    var currentIndex:Int = CONTROL_SCHEMES.indexOf(Preferences.controlsScheme);
    if (currentIndex < 0) currentIndex = 0;
    var nextIndex:Int = (currentIndex + direction + CONTROL_SCHEMES.length) % CONTROL_SCHEMES.length;
    Preferences.controlsScheme = CONTROL_SCHEMES[nextIndex];
    updateValues();
    statusText.text = "CONTROL LAYOUT SAVED • APPLIES WHEN THE NEXT SONG STARTS";
  }

  function toggleOrientationLock():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var saved:Bool = Save.instance.mobileOptions.lockCurrentOrientation;
    var targetValue:Bool = !(saved && MobileOrientationUtil.isCurrentlyLocked);
    if (!targetValue && !MobileOrientationUtil.isCurrentlyLocked && saved) targetValue = true;

    MobileOrientationUtil.setLocked(targetValue, function(success:Bool):Void
    {
      if (success)
      {
        Save.instance.mobileOptions.lockCurrentOrientation = targetValue;
        Save.system.flush();
        statusText.text = targetValue ? "CURRENT ORIENTATION LOCKED" : "AUTOMATIC ROTATION RESTORED";
        updateValues();
      }
      else statusText.text = MobileOrientationUtil.getUnavailableMessage().toUpperCase();
    });
    #else
    statusText.text = "MOBILE ORIENTATION SETTINGS ARE UNAVAILABLE IN THIS BUILD";
    #end
  }

  function updateValues():Void
  {
    var schemeIndex:Int = CONTROL_SCHEMES.indexOf(Preferences.controlsScheme);
    if (schemeIndex < 0) schemeIndex = 0;
    valueLabels[0].text = CONTROL_SCHEMES[schemeIndex].toUpperCase();

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var enabled:Bool = Save.instance.mobileOptions.lockCurrentOrientation;
    valueLabels[1].text = enabled ? "ON" : "OFF";
    valueLabels[1].color = enabled ? 0xFF6FE8FF : (novaBeatLayout ? 0xFF48BBD4 : FlxColor.WHITE);
    #else
    valueLabels[1].text = "N/A";
    valueLabels[1].color = FlxColor.GRAY;
    #end
  }

  function updateRowHighlights():Void
  {
    if (items == null) return;
    for (index in 0...rowBackgrounds.length)
    {
      var selected:Bool = items.selectedIndex == index;
      rowBackgrounds[index].color = selected ? 0xFF123B5C : 0xFF0D1935;
      rowBackgrounds[index].alpha = selected ? 1.0 : 0.82;
      rowAccents[index].alpha = selected ? 1.0 : 0.4;
      rowLabels[index].color = selected ? FlxColor.WHITE : 0xFFB9C8E3;
    }
  }

  function updateDescription():Void
  {
    if (items == null) return;
    descriptionText.text = items.selectedIndex == 0
      ? "Choose the on-screen rhythm-button layout. All five original mobile layouts are available; changes apply the next time a song starts."
      : "Keep the phone in its current orientation. Turn this off to allow automatic rotation again.";
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
}
