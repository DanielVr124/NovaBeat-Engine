package funkin.ui.options;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.save.Save;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.MenuList.NavControls;
import funkin.util.SwipeUtil;
import funkin.ui.AtlasText.AtlasFont;
#if mobile
import funkin.mobile.ui.FunkinBackButton;
#end

/**
 * Dedicated, persistent visual customization for the optional NovaBeat menu.
 * This is deliberately separate from the Menu Style preference.
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
  var descriptions:Array<String> = [];
  var descriptionText:FlxText;
  var statusText:FlxText;
  var optionRows:Array<TextMenuItem> = [];
  var rowWidths:Array<Float> = [];
  var rowScales:Array<Float> = [];
  var rowHeight:Float = 48;
  var compactLayout:Bool = false;
  var twoColumnLayout:Bool = false;

  public function new()
  {
    super();

    compactLayout = FlxG.width < 950 || FlxG.height > FlxG.width * 1.12;
    twoColumnLayout = FlxG.width > FlxG.height && FlxG.height < 560;

    var margin:Float = compactLayout ? 20 : 46;
    var headerWidth:Float = FlxG.width - margin * 2;
    #if mobile
    headerWidth = Math.max(100, headerWidth - 100);
    #end

    add(makeLabel(margin, 22, headerWidth, 'NOVABEAT CUSTOMIZATION', compactLayout ? 23 : 30, 0xFFFFFFFF));
    add(makeLabel(margin, 58, headerWidth,
      'These settings only change the NovaBeat menu. Original FNF remains untouched.', 11, 0xFF48E7FF));

    var listX:Float = margin + 12;
    var listY:Float = 96;
    var listW:Float = FlxG.width - margin * 2 - 24;
    var columnGap:Float = twoColumnLayout ? 10 : 0;
    var columnCount:Int = twoColumnLayout ? 2 : 1;
    var rowCount:Int = twoColumnLayout ? Std.int(Math.ceil(LABELS.length / 2)) : LABELS.length;
    var cellWidth:Float = (listW - columnGap * (columnCount - 1)) / columnCount;
    var footerReserve:Float = 106;
    rowHeight = Math.max(twoColumnLayout ? 22 : 20,
      Math.min(compactLayout ? 42 : 52, (FlxG.height - listY - footerReserve) / rowCount));

    items = new TextMenuList(twoColumnLayout ? NavControls.Columns(2) : NavControls.Vertical);

    descriptions = [
      'Choose the main NovaBeat highlight and selection colour.',
      'Adjust the visual strength behind the menu panels. Use LEFT / RIGHT to change it.',
      'Control the intensity of the panel edge and highlight glow.',
      'Show or hide the decorative equalizer strip.',
      'Scale the NovaBeat menu interface from 85% to 115%.',
      'Choose compact, comfortable, or spacious menu entry spacing.',
      'Reduce menu movement and animated accents.',
      'Allow ambient background movement and particles.',
      'Enable menu entry and selection animations.',
      'Show the animated equalizer visualizer.',
      'Reduce strong flashes and high-contrast pulses.',
      'Increase the size of navigation labels and headings.'
    ];

    for (index in 0...LABELS.length)
    {
      var itemIndex:Int = index;
      var column:Int = twoColumnLayout ? index % 2 : 0;
      var rowIndex:Int = twoColumnLayout ? Std.int(index / 2) : index;
      var itemX:Float = listX + column * (cellWidth + columnGap);
      var y:Float = listY + rowIndex * rowHeight;

      var item:TextMenuItem = items.createItem(itemX + 10, y + 2, LABELS[index], AtlasFont.BOLD, function()
      {
        activate(itemIndex);
      });
      item.makeGraphic(Std.int(cellWidth - 20), Std.int(Math.max(1, rowHeight - 4)), FlxColor.TRANSPARENT);
      item.updateHitbox();
      var textScale:Float = Math.max(0.35, Math.min(compactLayout ? 0.46 : 0.64, (rowHeight - 4) / 32));
      item.atlasText.scale.set(textScale, textScale);
      item.atlasText.updateHitbox();
      item.atlasText.x = itemX + 15;
      item.atlasText.y = y + (rowHeight - item.atlasText.height) * 0.5;
      optionRows.push(item);
      rowWidths.push(cellWidth - 20);
      rowScales.push(textScale);
    }

    items.onChange.add(function(selected:TextMenuItem)
    {
      if (items.selectedIndex >= 0 && items.selectedIndex < descriptions.length && descriptionText != null)
        descriptionText.text = descriptions[items.selectedIndex];
    });

    add(items);
    descriptionText = makeLabel(margin, FlxG.height - 82, FlxG.width - margin * 2, descriptions[0], 11, 0xFFB6C7E5);
    add(descriptionText);

    #if mobile
    statusText = makeLabel(margin, FlxG.height - 42, FlxG.width - margin * 2,
      'TAP TO INCREASE   •   SWIPE LEFT / RIGHT TO ADJUST   •   BACK TO RETURN', 9, 0xFF8DA8D8);
    #else
    statusText = makeLabel(margin, FlxG.height - 42, FlxG.width - margin * 2,
      'LEFT / RIGHT ADJUST   •   ENTER TO CHANGE   •   BACK TO RETURN', 9, 0xFF8DA8D8);
    #end
    add(statusText);

    refreshLabels();

    #if mobile
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 92, 16, FlxColor.WHITE, goBack, 1.0, true);
    add(backButton);
    #end
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
    statusText.text = 'SAVED  •  CHANGES APPLY THE NEXT TIME THE NOVABEAT MENU OPENS';
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

    for (index in 0...optionRows.length)
    {
      var itemIndex:Int = index;
      var displayLabel:String = LABELS[index] + '   < ' + values[index] + ' >';
      optionRows[index].setItem(displayLabel, function()
      {
        activate(itemIndex);
      });
      optionRows[index].atlasText.text = displayLabel;
      // TextMenuItem.setItem() resets the bitmap font scaling; reapply after refresh.
      optionRows[index].atlasText.scale.set(rowScales[index], rowScales[index]);
      optionRows[index].atlasText.updateHitbox();

      // TextMenuItem.setItem() resets the transparent sprite hitbox to the
      // text's size. Restore the full row so tapping anywhere on the row works.
      optionRows[index].width = rowWidths[index];
      optionRows[index].height = rowHeight - 4;
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

  function goBack():Void
  {
    onExit.dispatch();
  }

  function makeLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(Paths.font('vcr.ttf'), size, color);
    label.scrollFactor.set();
    return label;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!enabled || optionRows.length == 0) return;

    if (controls.UI_LEFT_P || SwipeUtil.swipeLeft) adjustSelected(-1);
    if (controls.UI_RIGHT_P || SwipeUtil.swipeRight) adjustSelected(1);
  }

  function adjustSelected(direction:Int):Void
  {
    switch (items.selectedIndex)
    {
      case 1: adjustValue(1, direction * 5);
      case 2: adjustValue(2, direction * 5);
      case 4: adjustValue(4, direction);
      default: return;
    }

    Save.system.flush();
    refreshLabels();
    statusText.text = 'SAVED  •  CHANGES APPLY THE NEXT TIME THE NOVABEAT MENU OPENS';
  }
}
