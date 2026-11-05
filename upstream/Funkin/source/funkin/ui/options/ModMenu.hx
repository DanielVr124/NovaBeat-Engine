package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.ui.Page;
import funkin.util.SwipeUtil;
import funkin.util.TouchUtil;
import polymod.Polymod.ModMetadata;
#if mobile
import funkin.mobile.ui.FunkinBackButton;
#end

/**
 * A real Polymod manager page.
 *
 * Enable state and load priority are stored in the existing save data and
 * consumed by PolymodHandler on the next game launch. This page never claims
 * that an on-disk mod is loaded before the engine has restarted.
 */
class ModMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var detectedMods:Array<ModMetadata> = [];
  var rows:Array<ModMenuItem> = [];
  var rowBackgrounds:Array<FlxSprite> = [];
  var selectedIndex:Int = 0;
  var firstVisibleIndex:Int = 0;
  var visibleRows:Int = 0;
  var rowX:Float = 0;
  var rowY:Float = 0;
  var rowWidth:Float = 0;
  var rowHeight:Float = 56;
  var portraitLayout:Bool = false;

  var heading:FlxText;
  var countText:FlxText;
  var detailTitle:FlxText;
  var detailText:FlxText;
  var statusText:FlxText;
  var helpText:FlxText;
  var emptyStateText:Null<FlxText>;

  public function new()
  {
    super();
    buildLayout();
    refreshModList();

    #if mobile
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 150, FlxG.height - 125, FlxColor.WHITE, goBack, 1.0, true);
    add(backButton);
    #end
  }

  function goBack():Void
  {
    onExit.dispatch();
  }

  function buildLayout():Void
  {
    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    portraitLayout = height > width;

    var margin:Float = portraitLayout ? 22 : 48;
    heading = addLabel(margin, 35, width - margin * 2, 'MOD MANAGER', portraitLayout ? 25 : 34, 0xFFFFFFFF);
    countText = addLabel(margin, 78, width - margin * 2, 'SCANNING LOCAL LIBRARY...', 12, 0xFF48E7FF);

    var listX:Float = margin;
    var listY:Float = portraitLayout ? 120 : 132;
    var listW:Float = portraitLayout ? width - margin * 2 : width * 0.48;
    var listH:Float = portraitLayout ? height * 0.43 : height - 230;
    addPanel(listX, listY, listW, listH);

    rowX = listX + 16;
    rowY = listY + 48;
    rowWidth = listW - 32;
    rowHeight = portraitLayout ? 50 : 58;
    visibleRows = Std.int(Math.max(1, Math.floor((listH - 68) / rowHeight)));

    var detailX:Float = portraitLayout ? margin : width * 0.535;
    var detailY:Float = portraitLayout ? listY + listH + 18 : listY;
    var detailW:Float = portraitLayout ? width - margin * 2 : width - detailX - margin;
    var detailH:Float = portraitLayout ? Math.max(150, height - detailY - 115) : listH;
    addPanel(detailX, detailY, detailW, detailH);

    addLabel(listX + 16, listY + 14, listW - 32, 'INSTALLED / DETECTED', 11, 0xFF48E7FF);
    detailTitle = addLabel(detailX + 22, detailY + 22, detailW - 44, 'SELECT A MOD', portraitLayout ? 18 : 24, 0xFFFFFFFF);
    detailText = addLabel(detailX + 22, detailY + (portraitLayout ? 62 : 82), detailW - 44,
      'Choose a mod to view its information and manage its enabled state.', 13, 0xFFB5C6E4);

    statusText = addLabel(margin, height - 75, width - margin * 2, '', 11, 0xFF48E7FF);
    helpText = addLabel(margin, height - 48, width - margin * 2,
      portraitLayout ? 'TAP A MOD TO SELECT  •  TAP AGAIN OR ACCEPT TO TOGGLE  •  SWIPE TO SCROLL' :
      'UP / DOWN SELECT   ENTER TOGGLE   LEFT / RIGHT LOAD PRIORITY   R RESCAN   ESC BACK', 9, 0xFF8DA8D8);
  }

  function refreshModList():Void
  {
    #if web
    // Browsers cannot inspect the game's local mods directory. Keep the page navigable
    // and explain the limitation instead of presenting it as an empty or broken library.
    detectedMods = [];
    selectedIndex = 0;
    countText.text = 'BROWSER BUILD • LOCAL MOD SCANNING UNAVAILABLE';
    statusText.text = 'Use the Windows or Android build to detect and manage local mods. Press ESC to return.';
    renderRows();
    renderDetails();
    return;
    #else
    #if sys
    detectedMods = PolymodHandler.getAllMods();
    #else
    detectedMods = [];
    #end

    var loadOrder:Array<String> = Save.instance.enabledModDirs.value.copy();
    detectedMods.sort(function(a:ModMetadata, b:ModMetadata):Int
    {
      var aIndex:Int = loadOrder.indexOf(a.dirName);
      var bIndex:Int = loadOrder.indexOf(b.dirName);
      if (aIndex >= 0 && bIndex >= 0) return aIndex - bIndex;
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      return Reflect.compare(a.title, b.title);
    });

    if (selectedIndex >= detectedMods.length) selectedIndex = detectedMods.length - 1;
    if (selectedIndex < 0) selectedIndex = 0;

    countText.text = detectedMods.length + ' MOD(S) FOUND  •  ' + loadOrder.length + ' ENABLED';
    statusText.text = 'Changes are saved immediately. Restart the game to reload enabled mods and their assets.';
    renderRows();
    renderDetails();
    #end
  }

  function renderRows():Void
  {
    for (row in rows) remove(row, true);
    for (background in rowBackgrounds) remove(background, true);
    if (emptyStateText != null)
    {
      remove(emptyStateText, true);
      emptyStateText = null;
    }
    rows = [];
    rowBackgrounds = [];

    if (detectedMods.length == 0)
    {
      #if web
      emptyStateText = addLabel(rowX, rowY + 20, rowWidth, 'LOCAL MOD SCANNING IS UNAVAILABLE IN THIS BROWSER BUILD', 11, 0xFFB5C6E4);
      #else
      emptyStateText = addLabel(rowX, rowY + 20, rowWidth, 'NO MODS FOUND', 18, 0xFFFFFFFF);
      #end
      return;
    }

    firstVisibleIndex = Std.int(Math.max(0, Math.min(selectedIndex, detectedMods.length - visibleRows)));

    for (visibleIndex in 0...visibleRows)
    {
      var modIndex:Int = firstVisibleIndex + visibleIndex;
      if (modIndex >= detectedMods.length) break;

      var mod:ModMetadata = detectedMods[modIndex];
      var enabled:Bool = Save.instance.enabledModDirs.value.indexOf(mod.dirName) != -1;
      var y:Float = rowY + visibleIndex * rowHeight;

      var bg:FlxSprite = new FlxSprite(rowX, y);
      bg.makeGraphic(Std.int(rowWidth), Std.int(rowHeight - 7), modIndex == selectedIndex ? 0xFF164B78 : 0xFF0D1935);
      bg.alpha = modIndex == selectedIndex ? 1 : 0.88;
      add(bg);
      rowBackgrounds.push(bg);

      var marker:String = enabled ? '[ON]  ' : '[OFF] ';
      var row:ModMenuItem = new ModMenuItem(rowX + 10, y + 10, rowWidth - 20, marker + mod.title, portraitLayout ? 13 : 16, modIndex);
      row.setFormat(Paths.font('vcr.ttf'), portraitLayout ? 13 : 16, modIndex == selectedIndex ? 0xFF48E7FF : 0xFFD5E1F6, FlxTextAlign.LEFT);
      add(row);
      rows.push(row);
    }
  }

  function renderDetails():Void
  {
    if (detectedMods.length == 0)
    {
      #if web
      detailTitle.text = 'BROWSER BUILD LIMITATION';
      detailText.text = 'Web browsers cannot read the game\'s local mods folder. Use the Windows or Android build to detect, enable, and load installed mods.';
      #else
      detailTitle.text = 'NO MODS INSTALLED';
      detailText.text = 'Put a Polymod-compatible mod folder inside the game mods folder, then press R to scan again.\n\nThe manager will show detected mods here.';
      #end
      return;
    }

    var mod:ModMetadata = detectedMods[selectedIndex];
    var enabled:Bool = Save.instance.enabledModDirs.value.indexOf(mod.dirName) != -1;
    var author:String = metadataValue(mod, 'author', 'Unknown author');
    var description:String = metadataValue(mod, 'description', 'No description was provided.');
    detailTitle.text = mod.title;
    detailText.text = 'AUTHOR: ' + author
      + '\nVERSION: ' + Std.string(mod.modVersion)
      + '\nID: ' + mod.id
      + '\nFOLDER: ' + mod.dirName
      + '\nSTATUS: ' + (enabled ? 'ENABLED' : 'DISABLED')
      + '\n\n' + description
      + '\n\nACCEPT / SPACE: ' + (enabled ? 'DISABLE MOD' : 'ENABLE MOD')
      + '\nLEFT / RIGHT: CHANGE LOAD PRIORITY';
  }

  function metadataValue(mod:ModMetadata, field:String, fallback:String):String
  {
    var value:Dynamic = Reflect.field(mod, field);
    if (value == null || Std.string(value).length == 0) return fallback;
    return Std.string(value);
  }

  function toggleSelectedMod():Void
  {
    if (selectedIndex < 0 || selectedIndex >= detectedMods.length) return;

    var mod:ModMetadata = detectedMods[selectedIndex];
    var enabledDirs:Array<String> = Save.instance.enabledModDirs.value.copy();
    var index:Int = enabledDirs.indexOf(mod.dirName);

    if (index >= 0)
    {
      enabledDirs.splice(index, 1);
      statusText.text = 'DISABLED ' + mod.title + '  •  RESTART TO APPLY';
    }
    else
    {
      enabledDirs.push(mod.dirName);
      statusText.text = 'ENABLED ' + mod.title + '  •  RESTART TO APPLY';
    }

    Save.instance.enabledModDirs.value = enabledDirs;
    countText.text = detectedMods.length + ' MOD(S) FOUND  •  ' + enabledDirs.length + ' ENABLED';
    renderRows();
    renderDetails();
  }

  function moveSelectedMod(direction:Int):Void
  {
    if (selectedIndex < 0 || selectedIndex >= detectedMods.length) return;

    var mod:ModMetadata = detectedMods[selectedIndex];
    var order:Array<String> = Save.instance.enabledModDirs.value.copy();
    var current:Int = order.indexOf(mod.dirName);

    if (current < 0)
    {
      statusText.text = 'ENABLE THIS MOD BEFORE CHANGING ITS LOAD PRIORITY.';
      return;
    }

    var target:Int = current + direction;
    if (target < 0 || target >= order.length)
    {
      statusText.text = 'THIS MOD IS ALREADY AT THAT END OF THE LOAD ORDER.';
      return;
    }

    var other:String = order[target];
    order[target] = order[current];
    order[current] = other;
    Save.instance.enabledModDirs.value = order;

    statusText.text = 'LOAD PRIORITY SAVED  •  RESTART TO APPLY';
    refreshModList();
  }

  function selectMod(index:Int, toggleIfAlreadySelected:Bool):Void
  {
    if (index < 0 || index >= detectedMods.length) return;

    if (toggleIfAlreadySelected && selectedIndex == index)
    {
      toggleSelectedMod();
      return;
    }

    selectedIndex = index;
    renderRows();
    renderDetails();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!enabled) return;

    if (FlxG.keys.justPressed.R) refreshModList();

    if (detectedMods.length > 0)
    {
      if (controls.UI_UP_P || SwipeUtil.swipeUp) selectMod(selectedIndex - 1, false);
      if (controls.UI_DOWN_P || SwipeUtil.swipeDown) selectMod(selectedIndex + 1, false);
      if (controls.ACCEPT_P || FlxG.keys.justPressed.SPACE) toggleSelectedMod();
      if (controls.UI_LEFT_P) moveSelectedMod(-1);
      if (controls.UI_RIGHT_P) moveSelectedMod(1);

      for (row in rows)
      {
        if (TouchUtil.pressAction(row))
        {
          selectMod(row.modIndex, true);
          break;
        }
      }
    }
  }

  function addPanel(x:Float, y:Float, width:Float, height:Float):Void
  {
    var border:FlxSprite = new FlxSprite(x, y);
    border.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), 0xFF4269B5);
    add(border);

    var fill:FlxSprite = new FlxSprite(x + 2, y + 2);
    fill.makeGraphic(Std.int(Math.max(1, width - 4)), Std.int(Math.max(1, height - 4)), 0xF0061028);
    add(fill);
  }

  function addLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(Paths.font('vcr.ttf'), size, color, FlxTextAlign.LEFT);
    add(label);
    return label;
  }
}

class ModMenuItem extends FlxText
{
  public var modIndex:Int;

  public function new(x:Float, y:Float, width:Float, text:String, size:Int, modIndex:Int)
  {
    super(x, y, width, text, size);
    this.modIndex = modIndex;
  }
}
