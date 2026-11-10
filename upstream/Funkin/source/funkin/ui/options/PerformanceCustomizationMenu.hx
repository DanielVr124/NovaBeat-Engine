package funkin.ui.options;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.save.Save;
import funkin.ui.AtlasText;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.MenuList.NavControls;
import funkin.util.SwipeUtil;
import funkin.util.DeviceUtil;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end

/**
 * Performance settings available from the shared Customization category.
 * Both menu themes use their own visual treatment while sharing the same
 * save data and performance controls.
 */
class PerformanceCustomizationMenu extends Page<OptionsState.OptionsMenuPageName>
{
  static final PRESETS:Array<String> = ["High", "Balanced", "Low", "Custom"];
  static final LABELS:Array<String> = [
    'PERFORMANCE PRESET',
    'NOTE SPLASHES',
    'STAGE ANIMATIONS',
    'STAGE SHADERS',
    'CAMERA BOPS'
  ];

  var items:TextMenuList;
  var descriptions:Array<String> = [];
  var menuCamera:FlxCamera;
  var hudCamera:FlxCamera;
  var camFollow:FlxObject;
  var itemDesc:FlxText;
  var itemDescBox:FunkinSprite;
  var fnfValueLabels:Array<AtlasText> = [];
  var optionRows:Array<TextMenuItem> = [];
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  public function new()
  {
    super();
    buildFNFLayout();
  }

  function buildFNFLayout():Void
  {
    menuCamera = new FunkinCamera('performanceCustomizationFNF');
    FlxG.cameras.add(menuCamera, false);
    menuCamera.bgColor = 0x0;
    hudCamera = new FlxCamera();
    FlxG.cameras.add(hudCamera, false);
    hudCamera.bgColor = 0x0;
    camera = menuCamera;

    items = new TextMenuList(NavControls.Vertical);
    items.cameras = [menuCamera];
    items.acceptOnTouchSelection = false;
    add(items);

    descriptions = [
      'Choose a graphics preset. Custom is selected automatically when you change an individual option.',
      'Display the animated splash effect when notes are hit. Turning this off reduces extra sprite and draw work.',
      'Animate background stage props. Character and note animations remain unchanged.',
      'Allow stage scripts to apply full-stage shader effects. Some mod stages may look different with this disabled.',
      'Enable beat-synchronized camera and HUD zooms. Rhythm timing is never changed.'
    ];

    for (index in 0...LABELS.length)
    {
      var itemIndex:Int = index;
      var itemY:Float = 30 + index * 120;
      var item:TextMenuItem = items.createItem(0, itemY, LABELS[index], AtlasFont.BOLD, function()
      {
        activate(itemIndex);
      });
      item.fireInstantly = true;
      optionRows.push(item);

      var value:AtlasText = new AtlasText(0, itemY, '', AtlasFont.DEFAULT);
      value.cameras = [menuCamera];
      fnfValueLabels.push(value);
      add(value);
    }

    itemDescBox = new FunkinSprite();
    itemDescBox.makeSolidColor(1, 1, FlxColor.BLACK);
    itemDescBox.alpha = 0.6;
    itemDescBox.cameras = [hudCamera];
    add(itemDescBox);

    itemDesc = new FlxText(0, 0, 1180, null, 32);
    itemDesc.cameras = [hudCamera];
    itemDesc.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.CENTER,
      FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    itemDesc.borderSize = 3;
    itemDesc.text = descriptions[0];
    itemDesc.screenCenter();
    itemDesc.y += 270;
    itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
    itemDescBox.setGraphicSize(Std.int(itemDesc.width + 20), Std.int(itemDesc.height + 25));
    itemDescBox.updateHitbox();
    add(itemDesc);

    camFollow = new FlxObject(FlxG.width / 2, 30, 140, 70);
    menuCamera.follow(camFollow, null, 0.085);
    menuCamera.deadzone.set(0, 160, menuCamera.width, menuCamera.height - 320);
    menuCamera.minScrollY = 0;
    items.onChange.add(function(selected:TextMenuItem)
    {
      itemDesc.text = descriptions[items.selectedIndex];
      layoutFNFItems();
    });

    refreshLabels();
    layoutFNFItems();

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, goBack, 1.0);
      add(responsiveBackButton);
    }
    #end
  }

  function activate(index:Int):Void
  {
    var options = Save.instance.options;
    switch (index)
    {
      case 0:
        var current:Int = PRESETS.indexOf(options.performancePreset);
        if (current < 0) current = 0;
        applyPreset(PRESETS[(current + 1) % PRESETS.length]);
      case 1:
        options.performanceNoteSplashes = !options.performanceNoteSplashes;
        options.performancePreset = "Custom";
      case 2:
        options.performanceStageAnimations = !options.performanceStageAnimations;
        options.performancePreset = "Custom";
      case 3:
        options.performanceStageShaders = !options.performanceStageShaders;
        options.performancePreset = "Custom";
      case 4:
        options.performanceCameraBops = !options.performanceCameraBops;
        options.performancePreset = "Custom";
      default:
        return;
    }

    Save.system.flush();
    refreshLabels();
  }

  function applyPreset(preset:String):Void
  {
    var options = Save.instance.options;
    options.performancePreset = preset;

    switch (preset)
    {
      case "High":
        options.performanceNoteSplashes = true;
        options.performanceStageAnimations = true;
        options.performanceStageShaders = true;
        options.performanceCameraBops = true;
      case "Balanced":
        options.performanceNoteSplashes = true;
        options.performanceStageAnimations = true;
        options.performanceStageShaders = false;
        options.performanceCameraBops = true;
      case "Low":
        options.performanceNoteSplashes = false;
        options.performanceStageAnimations = false;
        options.performanceStageShaders = false;
        options.performanceCameraBops = false;
      case "Custom":
        // Keep the current individual values.
      default:
        options.performancePreset = "High";
        applyPreset("High");
    }
  }

  function refreshLabels():Void
  {
    var options = Save.instance.options;
    var values:Array<String> = [
      options.performancePreset.toUpperCase(),
      options.performanceNoteSplashes ? 'ON' : 'OFF',
      options.performanceStageAnimations ? 'ON' : 'OFF',
      options.performanceStageShaders ? 'ON' : 'OFF',
      options.performanceCameraBops ? 'ON' : 'OFF'
    ];

    for (index in 0...fnfValueLabels.length) fnfValueLabels[index].text = values[index];
    layoutFNFItems();
  }

  function layoutFNFItems():Void
  {
    if (items == null || fnfValueLabels.length != optionRows.length) return;

    for (index in 0...optionRows.length)
    {
      var item:TextMenuItem = optionRows[index];
      var value:AtlasText = fnfValueLabels[index];
      var valueWidth:Int = value.getWidth();
      var portrait:Bool = FlxG.height > FlxG.width * 1.12;
      var notch:Float = funkin.ui.FullScreenScaleMode.gameNotchSize.x;
      var leftMargin:Float = portrait ? Math.max(18, notch + 18) : Math.max(24, notch + 120);
      var selectedIndent:Float = items.selectedIndex == index ? (portrait ? 18 : 30) : 0;

      item.x = leftMargin + selectedIndent;
      value.x = FlxG.width - valueWidth - Math.max(24, notch + 24);
      value.y = item.y;
    }
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    var portrait:Bool = height > width * 1.12;
    var top:Float = portrait ? 76 : 30;
    var rowGap:Float = portrait ? Math.min(72, (height * 0.60) / Math.max(1, optionRows.length)) : 120;
    for (index in 0...optionRows.length) optionRows[index].y = top + index * rowGap;
    if (itemDesc != null)
    {
      itemDesc.setPosition(18, height - (portrait ? 116 : 200));
      itemDesc.fieldWidth = width - 36;
      itemDesc.size = portrait ? 18 : 32;
      itemDesc.alignment = FlxTextAlign.CENTER;
      itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
      itemDescBox.setGraphicSize(Std.int(itemDesc.width + 20), Std.int(itemDesc.height + 22));
      itemDescBox.updateHitbox();
    }
    if (camFollow != null && items != null && items.selectedItem != null) camFollow.y = items.selectedItem.y;
    layoutFNFItems();
    if (menuCamera != null) menuCamera.setSize(width, height);
    if (hudCamera != null) hudCamera.setSize(width, height);
    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
  }

  function goBack():Void
  {
    onExit.dispatch();
  }

  function makeLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(Paths.font('vcr.ttf'), size, color, FlxTextAlign.LEFT);
    label.scrollFactor.set();
    return label;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (camFollow != null && items != null && items.selectedItem != null)
    {
      camFollow.y = items.selectedItem.y;
      layoutFNFItems();
    }

    if (!enabled || optionRows.length == 0) return;

    #end

    if (controls.UI_LEFT_P || SwipeUtil.swipeLeft) adjustSelected(-1);
    if (controls.UI_RIGHT_P || SwipeUtil.swipeRight) adjustSelected(1);
  }

  function adjustSelected(direction:Int):Void
  {
    var index:Int = items.selectedIndex;
    if (index == 0)
    {
      var current:Int = PRESETS.indexOf(Save.instance.options.performancePreset);
      if (current < 0) current = 0;
      var next:Int = (current + direction + PRESETS.length) % PRESETS.length;
      applyPreset(PRESETS[next]);
    }
    else
    {
      activate(index);
      return;
    }

    Save.system.flush();
    refreshLabels();
  }

  override function destroy():Void
  {
    super.destroy();
    if (menuCamera != null && FlxG.cameras.list.contains(menuCamera)) FlxG.cameras.remove(menuCamera);
    if (hudCamera != null && FlxG.cameras.list.contains(hudCamera)) FlxG.cameras.remove(hudCamera);
  }
}
