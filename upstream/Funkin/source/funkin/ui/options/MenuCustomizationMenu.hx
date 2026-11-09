package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.Preferences;
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
 * Dedicated NovaBeat visual customization page.
 * Visible strings are rendered with the VCR font rather than the upstream
 * bitmap-font atlas, while invisible list items preserve native menu input.
 */
class MenuCustomizationMenu extends Page<OptionsState.OptionsMenuPageName>
{
  static final ACCENTS:Array<String> = ["cyan", "violet", "magenta", "ice"];
  static final DENSITIES:Array<String> = ["compact", "comfortable", "spacious"];
  static final LABELS:Array<String> = [
    'ACCENT COLOUR',
    'BACKGROUND INTENSITY',
    'PANEL GLOW',
    'EQUALIZER STRIP',
    'INTERFACE SCALE',
    'MENU DENSITY',
    'REDUCE MOTION',
    'ANIMATED BACKGROUND',
    'MENU ENTRY ANIMATIONS',
    'AUDIO-REACTIVE VISUALIZER',
    'REDUCE FLASHING',
    'LARGER MENU TEXT'
  ];

  var items:TextMenuList;
  var novaBeatLayout:Bool = true;
  var descriptions:Array<String> = [];
  var descriptionText:FlxText;
  var statusText:FlxText;
  var menuCamera:FlxCamera;
  var hudCamera:FlxCamera;
  var camFollow:FlxObject;
  var itemDesc:FlxText;
  var itemDescBox:FunkinSprite;
  var fnfValueLabels:Array<AtlasText> = [];
  var optionRows:Array<TextMenuItem> = [];
  var rowLabels:Array<FlxText> = [];
  var rowValues:Array<FlxText> = [];
  var rowBackgrounds:Array<FlxSprite> = [];
  var rowAccents:Array<FlxSprite> = [];
  var rowHeight:Float = 42;
  var rightSideLayout:Bool = false;
  var listX:Float = 0;
  var listY:Float = 0;
  var listW:Float = 0;
  var valueColumnX:Float = 0;
  var panelBackgrounds:Array<FlxSprite> = [];
  var headerLabels:Array<FlxText> = [];
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  public function new()
  {
    super();
    novaBeatLayout = Preferences.menuStyle == "NovaBeat";
    if (novaBeatLayout) buildNovaBeatLayout();
    else buildFNFLayout();
  }

  function buildNovaBeatLayout():Void
  {

    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    var compactLayout:Bool = width < 950 || height > width * 1.12;
    // This page reflows to the single-column settings list on viewport sync.
    // Build that layout immediately so no stale sidebar labels remain behind.
    rightSideLayout = false;
    var margin:Float = compactLayout ? 20 : 46;
    var panelTop:Float = 98;
    var panelHeight:Float = Math.max(170, height - 150);

    if (rightSideLayout)
    {
      var leftPanel:FlxSprite = new FlxSprite(margin, panelTop);
      leftPanel.makeGraphic(Std.int(width * 0.39), Std.int(panelHeight), 0xC9091833);
      add(leftPanel);
      panelBackgrounds.push(leftPanel);

      var rightPanel:FlxSprite = new FlxSprite(width * 0.49, panelTop);
      rightPanel.makeGraphic(Std.int(width * 0.46), Std.int(panelHeight), 0xC9091833);
      add(rightPanel);
      panelBackgrounds.push(rightPanel);
    }
    else
    {
      var panel:FlxSprite = new FlxSprite(margin, panelTop);
      panel.makeGraphic(Std.int(width - margin * 2), Std.int(panelHeight), 0xC9091833);
      add(panel);
      panelBackgrounds.push(panel);
    }

    var pageTitle:FlxText = makeLabel(margin, 22, width - margin * 2, 'CUSTOMIZATION', compactLayout ? 23 : 30, FlxColor.WHITE);
    add(pageTitle);
    headerLabels.push(pageTitle);
    listX = margin + 12;
    listW = width - margin * 2 - 24;
    var availableTop:Float = panelTop + 20;
    var availableHeight:Float = Math.max(120, height - availableTop - 74);
    rowHeight = Math.max(34, Math.min(56, availableHeight / LABELS.length));
    var settingsHeight:Float = rowHeight * LABELS.length;
    listY = availableTop + Math.max(0, (availableHeight - settingsHeight) * 0.5);
    valueColumnX = listX + listW * 0.72;

    items = new TextMenuList(NavControls.Vertical);
    // Draw and hit-test the visible NovaBeat rows through the same camera.
    items.cameras = [FlxG.camera];
    // Use MenuList's shared touch path for browser and native touch input.
    // Tapping any visible row should activate it immediately, even when it
    // is not already selected; this keeps touch behavior aligned with FNF.
    items.ignoreTouchPointerSelection = false;
    items.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;

    descriptions = [
      'Choose the primary NovaBeat highlight and selection colour.',
      'Adjust how visible the background artwork is behind the interface.',
      'Change the intensity of panel borders and accent lighting.',
      'Show or hide the decorative equalizer strip on the main menu.',
      'Scale the NovaBeat interface without changing the game resolution.',
      'Choose compact, comfortable, or spacious menu entry spacing.',
      'Reduce movement and animated accents throughout NovaBeat menus.',
      'Allow subtle ambient background animation.',
      'Enable the menu entrance and selection animations.',
      'Show the animated equalizer while menu music is playing.',
      'Reduce bright flashes and high-contrast pulses.',
      'Increase navigation label and heading sizes.'
    ];

    for (index in 0...LABELS.length)
    {
      var itemIndex:Int = index;
      var y:Float = listY + index * rowHeight;

      var rowBg:FlxSprite = new FlxSprite(listX, y);
      rowBg.makeGraphic(Std.int(listW), Std.int(rowHeight - 4), 0xFF0D1935);
      add(rowBg);
      rowBackgrounds.push(rowBg);

      var accent:FlxSprite = new FlxSprite(listX, y + 5);
      accent.makeGraphic(3, Std.int(Math.max(8, rowHeight - 14)), 0xFF48E7FF);
      add(accent);
      rowAccents.push(accent);

      var item:TextMenuItem = items.createItem(listX + 5, y + 2, LABELS[index], AtlasFont.BOLD, function()
      {
        activate(itemIndex);
      });
      item.makeGraphic(Std.int(listW - 10), Std.int(rowHeight - 6), FlxColor.TRANSPARENT);
      item.updateHitbox();
      item.cameras = [FlxG.camera];
      item.atlasText.visible = false;
      optionRows.push(item);

      var fontSize:Int = Std.int(Math.max(12, Math.min(17, rowHeight * 0.32)));
      var label:FlxText = makeLabel(listX + 13, y + 5, listW * 0.69, LABELS[index], fontSize, 0xFFB9C8E3);
      add(label);
      rowLabels.push(label);

      var value:FlxText = makeLabel(valueColumnX, y + 5, listW * 0.25, '', fontSize, 0xFF48E7FF);
      value.alignment = FlxTextAlign.RIGHT;
      add(value);
      rowValues.push(value);
    }

    items.onChange.add(function(selected:TextMenuItem)
    {
      updateRowHighlights();
    });
    add(items);

    if (rightSideLayout)
    {
      add(makeLabel(margin + 28, panelTop + 28, width * 0.32, 'VISUAL SETTINGS', 12, 0xFF48E7FF));
      descriptionText = makeLabel(margin + 28, panelTop + 86, width * 0.32,
        descriptions[0], 16, 0xFFB6C7E5);
      descriptionText.visible = false;
      add(makeLabel(margin + 28, panelTop + panelHeight - 60, width * 0.32,
        'CHANGES SAVE AUTOMATICALLY', 10, 0xFF8297C2));
    }
    else
    {
      descriptionText = makeLabel(margin + 8, height - 68, width - margin * 2 - 16,
        descriptions[0], 11, 0xFFB6C7E5);
      descriptionText.visible = false;
    }

    statusText = makeLabel(listX, height - 38, listW,
      'LEFT / RIGHT ADJUST   •   ENTER TO CHANGE   •   ESC BACK', 9, 0xFF8DA8D8);
    add(statusText);

    refreshLabels();
    updateRowHighlights();

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 92, 16, FlxColor.WHITE, goBack, 1.0, true);
      add(responsiveBackButton);
    }
    #end
  }

  function buildFNFLayout():Void
  {
    menuCamera = new FunkinCamera('menuCustomizationFNF');
    FlxG.cameras.add(menuCamera, false);
    menuCamera.bgColor = 0x0;
    hudCamera = new FlxCamera();
    FlxG.cameras.add(hudCamera, false);
    hudCamera.bgColor = 0x0;
    camera = menuCamera;

    items = new TextMenuList(NavControls.Vertical);
    // FNF-style customization uses a dedicated scrolling camera. Keep the
    // touch list and its hit targets on that same camera so taps map correctly.
    items.cameras = [menuCamera];
    // These rows advertise TAP A ROW TO CHANGE; on mobile the first tap
    // must activate the selected row in both visual themes.
    items.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;
    add(items);

    descriptions = [
      'Choose the primary NovaBeat highlight and selection colour.',
      'Adjust how visible the background artwork is behind the interface.',
      'Change the intensity of panel borders and accent lighting.',
      'Show or hide the decorative equalizer strip on the main menu.',
      'Scale the NovaBeat interface without changing the game resolution.',
      'Choose compact, comfortable, or spacious menu entry spacing.',
      'Reduce movement and animated accents throughout NovaBeat menus.',
      'Allow subtle ambient background animation.',
      'Enable the menu entrance and selection animations.',
      'Show the animated equalizer while menu music is playing.',
      'Reduce bright flashes and high-contrast pulses.',
      'Increase navigation label and heading sizes.'
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
      item.cameras = [menuCamera];
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
      responsiveBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
      add(responsiveBackButton);
    }
    #end
  }

  function layoutFNFItems():Void
  {
    if (novaBeatLayout || items == null || fnfValueLabels.length != optionRows.length) return;

    for (index in 0...optionRows.length)
    {
      var item:TextMenuItem = optionRows[index];
      var value:AtlasText = fnfValueLabels[index];
      var valueWidth:Int = value.getWidth();
      var portrait:Bool = FlxG.height > FlxG.width * 1.12;
      var notch:Float = funkin.ui.FullScreenScaleMode.gameNotchSize.x;
      var leftMargin:Float = portrait ? Math.max(18, notch + 18) : Math.max(24, notch + 120);
      var selectedIndent:Float = items.selectedIndex == index ? (portrait ? 18 : 30) : 0;

      // Keep option names in a stable left column and values against the right
      // edge. Deriving the label position from the value width pushed long
      // entries (notably MENU DENSITY) off-screen.
      item.x = leftMargin + selectedIndent;
      value.x = FlxG.width - valueWidth - Math.max(24, notch + 24);
      value.y = item.y;
    }
  }

  function activate(index:Int):Void
  {
    var options = Save.instance.options;
    switch (index)
    {
      case 0:
        var current:Int = ACCENTS.indexOf(options.menuAccent);
        options.menuAccent = ACCENTS[(current + 1 + ACCENTS.length) % ACCENTS.length];
      case 1: adjustValue(1, 10);
      case 2: adjustValue(2, 10);
      case 3: options.menuShowEqualizer = !options.menuShowEqualizer;
      case 4: adjustValue(4, 5);
      case 5:
        var current:Int = DENSITIES.indexOf(options.menuDensity);
        options.menuDensity = DENSITIES[(current + 1 + DENSITIES.length) % DENSITIES.length];
      case 6: options.menuReduceMotion = !options.menuReduceMotion;
      case 7: options.menuAnimatedBackground = !options.menuAnimatedBackground;
      case 8: options.menuEntryAnimations = !options.menuEntryAnimations;
      case 9: options.menuAudioVisualizer = !options.menuAudioVisualizer;
      case 10: options.menuReduceFlashing = !options.menuReduceFlashing;
      case 11: options.menuLargeText = !options.menuLargeText;
      default:
    }

    Save.system.flush();
    refreshLabels();
    if (statusText != null) statusText.text = 'SAVED   •   CHANGES APPLY THE NEXT TIME THE NOVABEAT MENU OPENS';
  }

  function adjustValue(index:Int, direction:Int):Void
  {
    var options = Save.instance.options;
    switch (index)
    {
      case 1:
        var next:Int = options.menuBackgroundIntensity + direction;
        options.menuBackgroundIntensity = next > 125 ? 65 : (next < 65 ? 125 : next);
      case 2:
        var next:Int = options.menuPanelGlow + direction;
        options.menuPanelGlow = next > 150 ? 0 : (next < 0 ? 150 : next);
      case 4:
        var next:Int = options.menuInterfaceScale + (direction > 0 ? 5 : -5);
        options.menuInterfaceScale = next > 115 ? 85 : (next < 85 ? 115 : next);
      default:
    }
  }

  function refreshLabels():Void
  {
    var options = Save.instance.options;
    var values:Array<String> = [
      accentName(options.menuAccent),
      options.menuBackgroundIntensity + '%',
      options.menuPanelGlow + '%',
      options.menuShowEqualizer ? 'ON' : 'OFF',
      options.menuInterfaceScale + '%',
      options.menuDensity.toUpperCase(),
      options.menuReduceMotion ? 'ON' : 'OFF',
      options.menuAnimatedBackground ? 'ON' : 'OFF',
      options.menuEntryAnimations ? 'ON' : 'OFF',
      options.menuAudioVisualizer ? 'ON' : 'OFF',
      options.menuReduceFlashing ? 'ON' : 'OFF',
      options.menuLargeText ? 'ON' : 'OFF'
    ];

    for (index in 0...rowValues.length)
    {
      rowValues[index].text = values[index];
    }
    for (index in 0...fnfValueLabels.length)
    {
      fnfValueLabels[index].text = values[index];
    }
    if (!novaBeatLayout) layoutFNFItems();
  }

  function updateRowHighlights():Void
  {
    for (index in 0...rowLabels.length)
    {
      var selected:Bool = index == items.selectedIndex;
      rowBackgrounds[index].color = selected ? 0xFF123B5C : 0xFF0D1935;
      rowBackgrounds[index].alpha = selected ? 1.0 : 0.78;
      rowAccents[index].alpha = selected ? 1.0 : 0.36;
      rowLabels[index].color = selected ? FlxColor.WHITE : 0xFFB9C8E3;
      rowValues[index].color = selected ? 0xFF6FE8FF : 0xFF48BBD4;
    }
  }

  function accentName(value:String):String
  {
    return switch (value)
    {
      case "violet": "VIOLET";
      case "magenta": "MAGENTA";
      case "ice": "ICE";
      default: "CYAN";
    };
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    var portrait:Bool = height > width * 1.12;
    var margin:Float = Math.max(16, width * 0.045);
    if (novaBeatLayout)
    {
      var panelTop:Float = 98;
      var panelHeight:Float = Math.max(170, height - 142);
      if (panelBackgrounds.length > 0)
      {
        panelBackgrounds[0].visible = true;
        panelBackgrounds[0].setPosition(margin, panelTop);
        panelBackgrounds[0].makeGraphic(Std.int(width - margin * 2), Std.int(panelHeight), 0xC9091833);
        for (i in 1...panelBackgrounds.length) panelBackgrounds[i].visible = false;
      }
      if (headerLabels.length >= 1)
      {
        headerLabels[0].setPosition(margin, 22);
        headerLabels[0].fieldWidth = width - margin * 2;
        headerLabels[0].size = portrait ? 23 : 30;
      }
      rightSideLayout = false;
      listX = margin + 12;
      listW = width - margin * 2 - 24;
      var availableTop:Float = panelTop + 20;
      var availableHeight:Float = Math.max(120, height - availableTop - 74);
      rowHeight = Math.max(34, Math.min(56, availableHeight / LABELS.length));
      var settingsHeight:Float = rowHeight * LABELS.length;
      listY = availableTop + Math.max(0, (availableHeight - settingsHeight) * 0.5);
      valueColumnX = listX + listW * 0.71;
      for (index in 0...optionRows.length)
      {
        var y:Float = listY + index * rowHeight;
        rowBackgrounds[index].setPosition(listX, y);
        rowBackgrounds[index].makeGraphic(Std.int(listW), Std.int(rowHeight - 4), 0xFF0D1935);
        rowAccents[index].setPosition(listX, y + 5);
        rowAccents[index].makeGraphic(3, Std.int(Math.max(8, rowHeight - 14)), 0xFF48E7FF);
        var item:TextMenuItem = optionRows[index];
        item.setPosition(listX + 5, y + 2);
        item.makeGraphic(Std.int(listW - 10), Std.int(rowHeight - 6), FlxColor.TRANSPARENT);
        item.updateHitbox();
        item.atlasText.visible = false;
        var fontSize:Int = Std.int(Math.max(12, Math.min(17, rowHeight * 0.32)));
        rowLabels[index].setPosition(listX + 13, y + 5);
        rowLabels[index].fieldWidth = listW * 0.67;
        rowLabels[index].setFormat(novaBeatLayout ? "Arial" : Paths.font('vcr.ttf'), fontSize,
          novaBeatLayout ? 0xFFDCEBFF : 0xFFB9C8E3, FlxTextAlign.LEFT);
        rowValues[index].setPosition(valueColumnX, y + 5);
        rowValues[index].fieldWidth = listW * 0.25;
        rowValues[index].setFormat(novaBeatLayout ? "Arial" : Paths.font('vcr.ttf'), fontSize, 0xFF48E7FF, FlxTextAlign.RIGHT);
      }
      if (descriptionText != null)
      {
        descriptionText.setPosition(margin + 8, height - 68);
        descriptionText.fieldWidth = width - margin * 2 - 16;
        descriptionText.size = portrait ? 10 : 11;
      }
      if (statusText != null)
      {
        statusText.setPosition(listX, height - 38);
        statusText.fieldWidth = listW;
      }
      refreshLabels();
      updateRowHighlights();
    }
    else
    {
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
    }
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
    label.setFormat(novaBeatLayout ? "Arial" : Paths.font('vcr.ttf'), size, color, FlxTextAlign.LEFT);
    label.scrollFactor.set();
    return label;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!novaBeatLayout && camFollow != null && items != null && items.selectedItem != null)
    {
      camFollow.y = items.selectedItem.y;
      layoutFNFItems();
    }

    if (!enabled || optionRows.length == 0) return;


    if (controls.UI_LEFT_P || SwipeUtil.swipeLeft) adjustSelected(-1);
    if (controls.UI_RIGHT_P || SwipeUtil.swipeRight) adjustSelected(1);
  }

  function adjustSelected(direction:Int):Void
  {
    switch (items.selectedIndex)
    {
      case 0:
        var current:Int = ACCENTS.indexOf(Save.instance.options.menuAccent);
        Save.instance.options.menuAccent = ACCENTS[(current + direction + ACCENTS.length) % ACCENTS.length];
      case 1: adjustValue(1, direction * 5);
      case 2: adjustValue(2, direction * 5);
      case 4: adjustValue(4, direction);
      case 5:
        var current:Int = DENSITIES.indexOf(Save.instance.options.menuDensity);
        Save.instance.options.menuDensity = DENSITIES[(current + direction + DENSITIES.length) % DENSITIES.length];
      default: return;
    }

    Save.system.flush();
    refreshLabels();
    if (statusText != null) statusText.text = 'SAVED   •   CHANGES APPLY THE NEXT TIME THE NOVABEAT MENU OPENS';
  }

  override function destroy():Void
  {
    super.destroy();
    if (menuCamera != null && FlxG.cameras.list.contains(menuCamera)) FlxG.cameras.remove(menuCamera);
    if (hudCamera != null && FlxG.cameras.list.contains(hudCamera)) FlxG.cameras.remove(hudCamera);
  }
}
