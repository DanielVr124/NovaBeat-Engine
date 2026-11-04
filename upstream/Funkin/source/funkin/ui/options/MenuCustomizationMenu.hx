package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.save.Save;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
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
  var rowHeight:Float = 48;
  var compactLayout:Bool = false;

  public function new()
  {
    super();

    compactLayout = FlxG.height > FlxG.width;
    rowHeight = Math.max(22, Math.min(compactLayout ? 42 : 52, (FlxG.height - 205) / LABELS.length));

    var margin:Float = compactLayout ? 20 : 46;
    add(makeLabel(margin, 22, FlxG.width - margin * 2, 'NOVABEAT CUSTOMIZATION', compactLayout ? 23 : 30, 0xFFFFFFFF));
    add(makeLabel(margin, 58, FlxG.width - margin * 2,
      'These settings only change the NovaBeat menu. Original FNF remains untouched.', 11, 0xFF48E7FF));

    items = new TextMenuList();
    var listX:Float = margin + 12;
    var listY:Float = 96;
    var listW:Float = FlxG.width - margin * 2 - 24;

    var panel:FlxSprite = new FlxSprite(margin, listY - 8);
    panel.makeGraphic(Std.int(FlxG.width - margin * 2), Std.int(rowHeight * LABELS.length + 18), 0xFF4269B5);
    add(panel);

    var panelFill:FlxSprite = new FlxSprite(margin + 2, listY - 6);
    panelFill.makeGraphic(Std.int(FlxG.width - margin * 2 - 4), Std.int(rowHeight * LABELS.length + 14), 0xF0061028);
    add(panelFill);

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
      var y:Float = listY + index * rowHeight;
      var row:FlxSprite = new FlxSprite(listX, y);
      row.makeGraphic(Std.int(listW), Std.int(Math.max(1, rowHeight - 2)), index % 2 == 0 ? 0xFF0C1730 : 0xFF111F3D);
      add(row);

      var item:TextMenuItem = items.createItem(listX + 10, y + 2, LABELS[index], AtlasFont.BOLD, function()
      {
        activate(itemIndex);
      });
      item.makeGraphic(Std.int(listW - 20), Std.int(Math.max(1, rowHeight - 4)), FlxColor.TRANSPARENT);
      item.updateHitbox();
      var textScale:Float = Math.max(0.35, Math.min(compactLayout ? 0.46 : 0.64, (rowHeight - 4) / 32));
      item.atlasText.scale.set(textScale, textScale);
      item.atlasText.updateHitbox();
      item.atlasText.x = listX + 15;
      item.atlasText.y = y + (rowHeight - item.atlasText.height) * 0.5;
      optionRows.push(item);
    }

    items.onChange.add(function(selected:TextMenuItem)
    {
      if (items.selectedIndex >= 0 && items.selectedIndex < descriptions.length && descriptionText != null)
        descriptionText.text = descriptions[items.selectedIndex];
    });

    add(items);
    descriptionText = makeLabel(margin, FlxG.height - 82, FlxG.width - margin * 2, descriptions[0], 11, 0xFFB6C7E5);
    add(descriptionText);

    statusText = makeLabel(margin, FlxG.height - 42, FlxG.width - margin * 2,
      'LEFT / RIGHT ADJUST   •   ENTER TO CHANGE   •   BACK TO RETURN', 9, 0xFF8DA8D8);
    add(statusText);

    refreshLabels();

    #if mobile
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 130, FlxG.height - 125, FlxColor.WHITE, goBack, 1.0, true);
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
      optionRows[index].atlasText.updateHitbox();
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

    if (controls.UI_LEFT_P) adjustSelected(-1);
    if (controls.UI_RIGHT_P) adjustSelected(1);
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
