package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.audio.FunkinSound;
import funkin.Preferences;
import funkin.ui.Page;
import funkin.util.SwipeUtil;
import funkin.util.TouchUtil;
import polymod.Polymod.ModMetadata;
#if (mobile || FEATURE_TOUCH_CONTROLS)
import funkin.mobile.ui.FunkinBackButton;
#end
import funkin.util.DeviceUtil;

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
  var usesTouchControls:Bool = false;
  var layoutPanels:Array<FlxSprite> = [];
  var touchActionHitboxes:Array<FlxSprite> = [];
  var touchActionLabels:Array<FlxText> = [];
  var touchActionActions:Array<String> = [];
  var mobileBackButton:Null<FlxSprite> = null;
  var mobileBackLabel:Null<FlxText> = null;
  var mobileListDragActive:Bool = false;
  var mobileListDragMoved:Bool = false;
  var mobileListDragAccumulator:Float = 0;
  var mobileNovaBeatLayout:Bool = false;
  #if (mobile || FEATURE_TOUCH_CONTROLS)
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  var heading:FlxText;
  var countText:FlxText;
  var detailTitle:FlxText;
  var detailText:FlxText;
  var statusText:FlxText;
  var helpText:FlxText;
  var emptyStateText:Null<FlxText>;
  var listHeading:FlxText;

  public function new()
  {
    super();
    buildLayout();
    refreshModList();


  }

  function goBack():Void
  {
    onExit.dispatch();
  }

  function buildLayout():Void
  {
    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    portraitLayout = height > width * 1.12;
    usesTouchControls = DeviceUtil.isMobileBrowser;
    #if mobile
    usesTouchControls = true;
    #end
    mobileNovaBeatLayout = usesTouchControls && Preferences.menuStyle == "NovaBeat";
    if (usesTouchControls)
    {
      if (mobileNovaBeatLayout)
        buildNovaBeatMobileLayout(width, height);
      else
        buildMobileLayout(width, height);
      return;
    }

    var compactLandscapeTouch:Bool = false;
    var margin:Float = portraitLayout ? 22 : 48;
    heading = addLabel(margin, compactLandscapeTouch ? 10 : 35,
      width - margin * 2, 'MODS', compactLandscapeTouch ? 20 : (portraitLayout ? 25 : 34), 0xFFFFFFFF);
    countText = addLabel(margin, compactLandscapeTouch ? 38 : 78,
      width - margin * 2, 'SCANNING LOCAL LIBRARY...', compactLandscapeTouch ? 9 : 12, 0xFF48E7FF);

    var listX:Float = margin;
    var listY:Float = compactLandscapeTouch ? 68 : (portraitLayout ? 120 : 132);
    var listW:Float = compactLandscapeTouch ? width * 0.46 : (portraitLayout ? width - margin * 2 : width * 0.48);
    var listH:Float = compactLandscapeTouch ? height - 140 : (portraitLayout ? height * 0.43 : height - 230);
    addPanel(listX, listY, listW, listH);

    rowX = listX + (compactLandscapeTouch ? 10 : 16);
    var rowHeaderHeight:Float = compactLandscapeTouch ? 36 : 48;
    rowY = listY + rowHeaderHeight;
    rowWidth = listW - (compactLandscapeTouch ? 20 : 32);
    rowHeight = compactLandscapeTouch ? 38 : (portraitLayout ? 50 : 58);
    var touchButtonHeight:Float = compactLandscapeTouch ? 26 : (portraitLayout ? 32 : 34);
    var reservedRowsHeight:Float = usesTouchControls
      ? rowHeaderHeight + touchButtonHeight + 24
      : 68;
    visibleRows = Std.int(Math.max(1, Math.floor((listH - reservedRowsHeight) / rowHeight)));

    var detailX:Float = compactLandscapeTouch ? width * 0.49 : (portraitLayout ? margin : width * 0.535);
    var detailY:Float = compactLandscapeTouch ? listY : (portraitLayout ? listY + listH + 18 : listY);
    var detailW:Float = compactLandscapeTouch ? width - detailX - margin
      : (portraitLayout ? width - margin * 2 : width - detailX - margin);
    var detailH:Float = compactLandscapeTouch ? listH
      : (portraitLayout ? Math.max(150, height - detailY - 115) : listH);
    addPanel(detailX, detailY, detailW, detailH);

    addLabel(listX + (compactLandscapeTouch ? 10 : 16), listY + (compactLandscapeTouch ? 10 : 14),
      listW - (compactLandscapeTouch ? 20 : 32), 'INSTALLED / DETECTED', compactLandscapeTouch ? 9 : 11, 0xFF48E7FF);
    detailTitle = addLabel(detailX + (compactLandscapeTouch ? 14 : 22), detailY + (compactLandscapeTouch ? 14 : 22),
      detailW - (compactLandscapeTouch ? 28 : 44), 'SELECT A MOD',
      compactLandscapeTouch ? 16 : (portraitLayout ? 18 : 24), 0xFFFFFFFF);
    detailText = addLabel(detailX + (compactLandscapeTouch ? 14 : 22),
      detailY + (compactLandscapeTouch ? 48 : (portraitLayout ? 62 : 82)),
      detailW - (compactLandscapeTouch ? 28 : 44),
      'Choose a mod to view its information and manage its enabled state.',
      compactLandscapeTouch ? 9 : 13, 0xFFB5C6E4);

    var statusY:Float = compactLandscapeTouch ? height - 58 : height - 75;
    var helpY:Float = compactLandscapeTouch ? height - 32 : height - 48;
    statusText = addLabel(margin, statusY, width - margin * 2, '', compactLandscapeTouch ? 9 : 11, 0xFF48E7FF);
    helpText = addLabel(margin, helpY, width - margin * 2,
      usesTouchControls
        ? 'TAP A MOD TO SELECT  •  USE THE BUTTONS BELOW  •  SWIPE TO SCROLL'
        : 'UP / DOWN SELECT   ENTER TOGGLE   WHEEL SCROLL   LEFT / RIGHT LOAD PRIORITY   R RESCAN   ESC BACK',
      compactLandscapeTouch ? 7 : (portraitLayout ? 8 : 9), 0xFF8DA8D8);

    if (usesTouchControls)
      layoutTouchActions(rowX, listY + listH - touchButtonHeight - 8, rowWidth, touchButtonHeight);
  }

  function mobileModActionsEnabled():Bool
  {
    #if web
    return false;
    #else
    return true;
    #end
  }

  /**
   * NovaBeat's mobile Mod Library is a dedicated full-screen list, not a
   * compressed two-pane desktop manager. The installed mod cards own the
   * space; details become an intentional empty-state message when the list
   * has nothing to show.
   */
  function buildNovaBeatMobileLayout(width:Float, height:Float):Void
  {
    portraitLayout = height > width * 1.12;
    var margin:Float = portraitLayout ? 18 : 22;
    heading = addLabel(margin, 13, width - 160, 'MOD LIBRARY', portraitLayout ? 28 : 25, 0xFFFFFFFF);
    countText = addLabel(margin, 49, width - margin * 2, 'CHECKING YOUR MOD LIBRARY...', 11, 0xFF54DDF4);

    mobileBackButton = new FlxSprite(width - 132, 12);
    mobileBackButton.makeGraphic(116, 46, 0xFF183B59);
    mobileBackButton.scrollFactor.set();
    add(mobileBackButton);
    mobileBackLabel = new FlxText(width - 128, 27, 108, 'BACK', 14);
    mobileBackLabel.setFormat(Paths.font('vcr.ttf'), 14, 0xFFFFFFFF, FlxTextAlign.CENTER);
    mobileBackLabel.scrollFactor.set();
    add(mobileBackLabel);

    var panelY:Float = portraitLayout ? 94 : 82;
    var panelHeight:Float = Math.max(150, height - panelY - 48);
    var panelWidth:Float = width - margin * 2;
    addPanel(margin, panelY, panelWidth, panelHeight);

    var innerX:Float = margin + 16;
    var innerWidth:Float = panelWidth - 32;
    listHeading = addLabel(innerX + 2, panelY + 16, innerWidth - 4,
      mobileModActionsEnabled() ? 'INSTALLED MODS' : 'YOUR MOD LIBRARY',
      15, 0xFF54DDF4);
    statusText = addLabel(innerX + 2, panelY + 39, innerWidth - 4, '', 9, 0xFF9DB7D8);

    rowX = innerX + 2;
    rowY = panelY + 63;
    rowWidth = innerWidth - 4;
    rowHeight = portraitLayout ? 102 : 88;

    var actionDockHeight:Float = mobileModActionsEnabled() ? 90 : 0;
    var listBottom:Float = panelY + panelHeight - 14 - actionDockHeight;
    visibleRows = Std.int(Math.max(1, Math.floor((listBottom - rowY) / rowHeight)));
    if (mobileModActionsEnabled())
    {
      var actionY:Float = panelY + panelHeight - actionDockHeight - 8;
      layoutMobileTouchActions(innerX, actionY, innerWidth, 38, 8, portraitLayout);
    }

    detailTitle = addLabel(rowX + 10, rowY + 54, rowWidth - 20, '', 20, 0xFFFFFFFF);
    detailTitle.alignment = FlxTextAlign.CENTER;
    detailTitle.autoSize = false;
    detailTitle.fieldWidth = rowWidth - 20;

    detailText = addLabel(rowX + 20, rowY + 98, rowWidth - 40, '', 14, 0xFFB8CBE6);
    detailText.alignment = FlxTextAlign.CENTER;
    detailText.wordWrap = true;
    detailText.autoSize = false;
    detailText.fieldWidth = rowWidth - 40;
    detailText.fieldHeight = Math.max(80, listBottom - rowY - 112);

    helpText = addLabel(margin, height - 28, width - margin * 2,
      mobileModActionsEnabled()
        ? 'TAP A MOD CARD  •  DRAG TO BROWSE  •  ACTIONS BELOW'
        : 'BROWSER BUILDS CANNOT SCAN LOCAL MOD FOLDERS',
      9, 0xFF91A9CC);
  }

  function buildMobileLayout(width:Float, height:Float):Void
  {
    // NovaBeat mobile uses a dedicated single-column library screen. It is
    // intentionally not a scaled copy of the desktop two-pane manager.
    portraitLayout = height > width * 1.12;
    var margin:Float = 16;
    heading = addLabel(margin, 14, width - 150, 'MOD LIBRARY', portraitLayout ? 25 : 23, 0xFFFFFFFF);
    countText = addLabel(margin, 48, width - margin * 2, 'CHECKING YOUR MOD LIBRARY...', 11, 0xFF54DDF4);

    mobileBackButton = new FlxSprite(width - 126, 12);
    mobileBackButton.makeGraphic(110, 42, 0xFF183B59);
    mobileBackButton.scrollFactor.set();
    add(mobileBackButton);
    mobileBackLabel = new FlxText(width - 122, 25, 102, 'BACK', 13);
    mobileBackLabel.setFormat(Paths.font('vcr.ttf'), 13, 0xFFFFFFFF, FlxTextAlign.CENTER);
    mobileBackLabel.scrollFactor.set();
    add(mobileBackLabel);

    var panelY:Float = 82;
    var panelHeight:Float = Math.max(180, height - 118);
    addPanel(margin, panelY, width - margin * 2, panelHeight);

    var innerX:Float = margin + 14;
    var innerWidth:Float = width - margin * 2 - 28;
    var summaryY:Float = panelY + 14;
    var summaryHeight:Float = portraitLayout ? 112 : 92;
    addPanel(innerX, summaryY, innerWidth, summaryHeight);

    detailTitle = addLabel(innerX + 14, summaryY + 12, innerWidth - 28, 'YOUR MOD LIBRARY', 16, 0xFFFFFFFF);
    detailText = addLabel(innerX + 14, summaryY + 40, innerWidth - 28,
      'Mods you install will appear here. You can review them and manage their load order.',
      11, 0xFFB8CBE6);
    detailText.wordWrap = true;
    detailText.autoSize = false;
    detailText.fieldHeight = summaryHeight - 46;
    statusText = addLabel(innerX + 14, summaryY + summaryHeight - 20, innerWidth - 28, '', 9, 0xFF54DDF4);

    listHeading = addLabel(innerX + 2, summaryY + summaryHeight + 18, innerWidth - 4,
      mobileModActionsEnabled() ? 'INSTALLED MODS' : 'LOCAL MODS ARE NOT AVAILABLE IN THIS BROWSER',
      11, 0xFF54DDF4);
    rowX = innerX;
    rowY = summaryY + summaryHeight + 44;
    rowWidth = innerWidth;
    rowHeight = portraitLayout ? 78 : 74;
    var actionDockHeight:Float = mobileModActionsEnabled() ? 76 : 0;
    var listBottom:Float = panelY + panelHeight - 18 - actionDockHeight;
    visibleRows = Std.int(Math.max(1, Math.floor((listBottom - rowY) / rowHeight)));
    if (mobileModActionsEnabled())
    {
      var actionY:Float = panelY + panelHeight - actionDockHeight - 8;
      layoutMobileTouchActions(innerX, actionY, innerWidth, 30, 6, portraitLayout);
    }

    helpText = addLabel(margin, height - 22, width - margin * 2,
      mobileModActionsEnabled()
        ? 'TAP A CARD  •  DRAG TO SCROLL  •  USE THE ACTIONS BELOW  •  BACK'
        : 'BROWSER BUILDS CANNOT READ LOCAL MOD FOLDERS  •  BACK TO RETURN',
      9, 0xFF91A9CC);
  }

  function layoutMobileTouchActions(x:Float, y:Float, width:Float, height:Float, gap:Float, portrait:Bool):Void
  {
    var labels:Array<String> = ['ENABLE / DISABLE', 'MOVE UP', 'MOVE DOWN', 'RESCAN'];
    var actions:Array<String> = ['toggle', 'priorityUp', 'priorityDown', 'rescan'];
    // Two broad columns in every mobile orientation keep the controls thumb-sized.
    var columns:Int = 2;
    var labelSize:Int = 12;
    var buttonWidth:Float = (width - gap) / columns;

    for (index in 0...labels.length)
    {
      var column:Int = index % columns;
      var row:Int = Std.int(index / columns);
      var buttonX:Float = x + column * (buttonWidth + gap);
      var buttonY:Float = y + row * (height + gap);
      var button:FlxSprite;
      var label:FlxText;
      if (index >= touchActionHitboxes.length)
      {
        button = new FlxSprite(buttonX, buttonY);
        button.makeGraphic(Std.int(buttonWidth), Std.int(height), 0xFF183D5A);
        button.scrollFactor.set();
        add(button);
        touchActionHitboxes.push(button);

        label = new FlxText(buttonX + 6, buttonY + (height - labelSize) * 0.5, buttonWidth - 12, labels[index], labelSize);
        label.setFormat(Paths.font('vcr.ttf'), labelSize, 0xFFEAF6FF, FlxTextAlign.CENTER);
        label.scrollFactor.set();
        add(label);
        touchActionLabels.push(label);
        touchActionActions.push(actions[index]);
      }
      else
      {
        button = touchActionHitboxes[index];
        label = touchActionLabels[index];
        button.setPosition(buttonX, buttonY);
        button.makeGraphic(Std.int(buttonWidth), Std.int(height), 0xFF183D5A);
        label.setPosition(buttonX + 6, buttonY + (height - labelSize) * 0.5);
        label.fieldWidth = buttonWidth - 12;
        label.text = labels[index];
        label.setFormat(Paths.font('vcr.ttf'), labelSize, 0xFFEAF6FF, FlxTextAlign.CENTER);
      }
    }
  }

  function layoutTouchActions(x:Float, y:Float, width:Float, height:Float):Void
  {
    layoutMobileTouchActions(x, y, width, height, 5, false);
  }

  function performTouchAction(action:String):Void
  {
    switch (action)
    {
      case 'toggle':
        toggleSelectedMod();
      case 'priorityUp':
        moveSelectedMod(-1);
      case 'priorityDown':
        moveSelectedMod(1);
      case 'rescan':
        refreshModList();
    }
  }

  function refreshModList():Void
  {
    #if web
    // Browsers cannot inspect the game's local mods directory. Keep the page navigable
    // and explain the limitation instead of presenting it as an empty or broken library.
    detectedMods = [];
    selectedIndex = 0;
    countText.text = 'BROWSER BUILD • LOCAL MOD SCANNING UNAVAILABLE';
    statusText.text = 'BROWSER BUILD  •  LOCAL MOD FOLDER ACCESS IS RESTRICTED';
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
      if (!mobileNovaBeatLayout)
      {
        #if web
        emptyStateText = addLabel(rowX, rowY + 8, rowWidth, 'LOCAL MOD SCANNING IS UNAVAILABLE IN THIS BROWSER BUILD', 11, 0xFFB5C6E4);
        #else
        emptyStateText = addLabel(rowX, rowY + 20, rowWidth, 'NO MODS FOUND', 18, 0xFFFFFFFF);
        #end
      }
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

      var marker:String = enabled ? '[ENABLED]' : '[DISABLED]';
      var rowFontSize:Int = mobileNovaBeatLayout
        ? (portraitLayout ? 16 : 14)
        : (usesTouchControls ? 13 : (portraitLayout ? 13 : 16));
      var rowText:String;
      if (usesTouchControls)
      {
        var author:String = metadataValue(mod, 'author', 'Unknown author');
        var description:String = metadataValue(mod, 'description', 'No description provided.');
        var maxDescriptionLength:Int = mobileNovaBeatLayout ? 56 : 72;
        if (description.length > maxDescriptionLength)
          description = description.substr(0, maxDescriptionLength - 3) + '...';
        rowText = marker + '  •  v' + Std.string(mod.modVersion)
          + '\n' + mod.title
          + '\n' + author + '  —  ' + description;
      }
      else
      {
        rowText = (enabled ? '[ON]  ' : '[OFF] ') + mod.title;
      }
      var row:ModMenuItem = new ModMenuItem(rowX + 12, y + (usesTouchControls ? 6 : (rowHeight - rowFontSize - 4) * 0.5),
        rowWidth - 24, rowText, rowFontSize, modIndex);
      row.setFormat(Paths.font('vcr.ttf'), rowFontSize,
        modIndex == selectedIndex ? 0xFF48E7FF : 0xFFD5E1F6, FlxTextAlign.LEFT);
      if (usesTouchControls)
      {
        row.wordWrap = true;
        row.autoSize = false;
        row.fieldHeight = rowHeight - (mobileNovaBeatLayout ? 14 : 10);
      }
      add(row);
      rows.push(row);
    }
  }

  function renderDetails():Void
  {
    if (mobileNovaBeatLayout)
    {
      if (detectedMods.length == 0)
      {
        detailTitle.visible = true;
        detailText.visible = true;
        #if web
        detailTitle.text = 'BROWSER BUILD LIMITATION';
        detailText.text = 'This browser cannot scan your device storage for installed mod folders. The Mod Library is available here, but local mod management requires the Android or Windows build.';
        #else
        detailTitle.text = 'YOUR LIBRARY IS EMPTY';
        detailText.text = 'Add a Polymod-compatible mod folder to the game, then use RESCAN to find it. Installed mods will appear here as full-size cards you can manage.';
        #end
        detailTitle.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFFFF, FlxTextAlign.CENTER);
        detailText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFB8CBE6, FlxTextAlign.CENTER);
      }
      else
      {
        // Each card already shows the selected mod's author, version, and
        // description. Keep the separate empty-state message out of the list.
        detailTitle.visible = false;
        detailText.visible = false;
      }
      return;
    }

    if (detectedMods.length == 0)
    {
      #if web
      detailTitle.text = usesTouchControls ? 'NO MODS TO DISPLAY YET' : 'BROWSER BUILD LIMITATION';
      detailText.text = usesTouchControls
        ? 'This browser build cannot scan your device storage for mod folders. Your library will appear here when browser-based mod importing is supported. You can return to the main menu with the BACK button above.'
        : 'Web browsers cannot read the game\'s local mods folder. Use the Windows or Android build to detect, enable, and load installed mods.';
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
    detailText.text = usesTouchControls
      ? 'AUTHOR: ' + author
        + '\nVERSION: ' + Std.string(mod.modVersion)
        + '\nSTATUS: ' + (enabled ? 'ENABLED' : 'DISABLED')
        + '\n\n' + description
      : 'AUTHOR: ' + author
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

    var changedSelection:Bool = selectedIndex != index;
    selectedIndex = index;
    renderRows();
    renderDetails();

    if (changedSelection)
    {
      var soundName:String = Preferences.menuStyle == "NovaBeat" ? "novabeat/select" : "scrollMenu";
      FunkinSound.playOnce(Paths.sound(soundName), 0.4);
    }
  }

  inline function mobilePointerOverlaps(sprite:FlxSprite):Bool
  {
    if (TouchUtil.overlaps(sprite)) return true;
    #if web
    if (DeviceUtil.isMobileBrowser
      && (FlxG.mouse.justPressed || FlxG.mouse.pressed || FlxG.mouse.justReleased))
      return FlxG.mouse.overlaps(sprite);
    #end
    return false;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!enabled) return;

    // Always provide a keyboard exit in the browser, including mobile
    // browsers where the HTML5 build is not compiled with the native mobile flag.
    if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
    {
      FunkinSound.playOnce(Paths.sound(Preferences.menuStyle == "NovaBeat" ? "novabeat/back" : "cancelMenu"));
      onExit.dispatch();
      return;
    }

    // HTML5 mobile browsers are detected at runtime, so this must not be
    // hidden behind the native mobile compile flags. Otherwise the visible
    // BACK target is drawn but can never receive a tap in the web build.
    // Use release-overlap directly; pressAction has a 200ms age filter.
    final mobilePointerReleased:Bool = TouchUtil.justReleased
      || (DeviceUtil.isMobileBrowser && FlxG.mouse.justReleased);
    final mobileBackTapped:Bool = mobileBackButton != null
      && ((TouchUtil.justReleased && TouchUtil.overlaps(mobileBackButton))
        || (DeviceUtil.isMobileBrowser && FlxG.mouse.justReleased && FlxG.mouse.overlaps(mobileBackButton)));

    if (usesTouchControls && mobilePointerReleased && mobileBackTapped)
    {
      FunkinSound.playOnce(Paths.sound(Preferences.menuStyle == "NovaBeat" ? "novabeat/back" : "cancelMenu"));
      onExit.dispatch();
      return;
    }

    if (FlxG.keys.justPressed.R) refreshModList();

    // Runtime-detected HTML5 touch devices need the same pointer handling
    // as native mobile builds. Keep this outside compile-time mobile flags.
    var listDragReleased:Bool = false;
    if (usesTouchControls)
    {
      var pointer:Dynamic = TouchUtil.touch;
      final mobilePointerPressed:Bool = TouchUtil.justPressed
        || (DeviceUtil.isMobileBrowser && FlxG.mouse.justPressed);
      final mobilePointerDown:Bool = TouchUtil.pressed
        || (DeviceUtil.isMobileBrowser && FlxG.mouse.pressed);
      if (mobilePointerPressed && pointer != null)
      {
        mobileListDragActive = false;
        mobileListDragMoved = false;
        mobileListDragAccumulator = 0;
        for (background in rowBackgrounds)
        {
          if (mobilePointerOverlaps(background))
          {
            mobileListDragActive = true;
            break;
          }
        }
      }

      if (mobileListDragActive && mobilePointerDown && pointer != null)
      {
        var deltaY:Float = pointer.deltaViewY;
        if (Math.isFinite(deltaY) && Math.abs(deltaY) > 1)
        {
          mobileListDragAccumulator -= deltaY;
          mobileListDragMoved = mobileListDragMoved || Math.abs(mobileListDragAccumulator) > 12;
          var rowStep:Float = Math.max(36, rowHeight * 0.55);
          while (mobileListDragAccumulator >= rowStep)
          {
            selectMod(selectedIndex + 1, false);
            mobileListDragAccumulator -= rowStep;
          }
          while (mobileListDragAccumulator <= -rowStep)
          {
            selectMod(selectedIndex - 1, false);
            mobileListDragAccumulator += rowStep;
          }
        }
      }

      if (mobilePointerReleased && mobileListDragActive)
      {
        listDragReleased = mobileListDragMoved;
        mobileListDragActive = false;
        mobileListDragMoved = false;
        mobileListDragAccumulator = 0;
      }

      var touchActionHandled:Bool = false;
      if (!listDragReleased)
      {
        for (index in 0...touchActionHitboxes.length)
        {
          if (mobilePointerReleased && mobilePointerOverlaps(touchActionHitboxes[index]))
          {
            performTouchAction(touchActionActions[index]);
            touchActionHandled = true;
            break;
          }
        }
      }

      if (!touchActionHandled && !listDragReleased)
      {
        for (index in 0...rowBackgrounds.length)
        {
          if (mobilePointerReleased && mobilePointerOverlaps(rowBackgrounds[index]))
          {
            selectMod(firstVisibleIndex + index, false);
            break;
          }
        }
      }
    }

    if (detectedMods.length > 0)
    {
      if (controls.UI_UP_P || (!mobileListDragActive && SwipeUtil.swipeUp))
        selectMod(selectedIndex - 1, false);
      if (controls.UI_DOWN_P || (!mobileListDragActive && SwipeUtil.swipeDown))
        selectMod(selectedIndex + 1, false);
      if (controls.ACCEPT_P || FlxG.keys.justPressed.SPACE) toggleSelectedMod();
      if (controls.UI_LEFT_P) moveSelectedMod(-1);
      if (controls.UI_RIGHT_P) moveSelectedMod(1);
    }
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    if (usesTouchControls)
    {
      if (mobileNovaBeatLayout)
        layoutNovaBeatMobileViewport(width, height);
      else
        layoutMobileViewport(width, height);
      return;
    }
    portraitLayout = height > width * 1.12;
    var compactLandscapeTouch:Bool = usesTouchControls && !portraitLayout && height < 520;
    var margin:Float = compactLandscapeTouch ? 20 : (portraitLayout ? 22 : 48);

    heading.setPosition(margin, compactLandscapeTouch ? 10 : 35);
    heading.fieldWidth = width - margin * 2;
    heading.size = compactLandscapeTouch ? 20 : (portraitLayout ? 25 : 34);
    countText.setPosition(margin, compactLandscapeTouch ? 38 : 78);
    countText.fieldWidth = width - margin * 2;

    var listX:Float = margin;
    var listY:Float = compactLandscapeTouch ? 68 : (portraitLayout ? 120 : 132);
    var listW:Float = compactLandscapeTouch ? width * 0.46 : (portraitLayout ? width - margin * 2 : width * 0.48);
    var listH:Float = compactLandscapeTouch ? height - 140 : (portraitLayout ? height * 0.43 : height - 230);
    var detailX:Float = compactLandscapeTouch ? width * 0.49 : (portraitLayout ? margin : width * 0.535);
    var detailY:Float = compactLandscapeTouch ? listY : (portraitLayout ? listY + listH + 18 : listY);
    var detailW:Float = compactLandscapeTouch ? width - detailX - margin
      : (portraitLayout ? width - margin * 2 : width - detailX - margin);
    var detailH:Float = compactLandscapeTouch ? listH
      : (portraitLayout ? Math.max(150, height - detailY - 115) : listH);

    if (layoutPanels.length >= 4)
    {
      layoutPanels[0].setPosition(listX, listY);
      layoutPanels[0].makeGraphic(Std.int(listW), Std.int(listH), 0xFF4269B5);
      layoutPanels[1].setPosition(listX + 2, listY + 2);
      layoutPanels[1].makeGraphic(Std.int(listW - 4), Std.int(listH - 4), 0xF0061028);
      layoutPanels[2].setPosition(detailX, detailY);
      layoutPanels[2].makeGraphic(Std.int(detailW), Std.int(detailH), 0xFF4269B5);
      layoutPanels[3].setPosition(detailX + 2, detailY + 2);
      layoutPanels[3].makeGraphic(Std.int(detailW - 4), Std.int(detailH - 4), 0xF0061028);
    }

    var rowHeaderHeight:Float = compactLandscapeTouch ? 36 : 48;
    rowX = listX + (compactLandscapeTouch ? 10 : 16);
    rowY = listY + rowHeaderHeight;
    rowWidth = listW - (compactLandscapeTouch ? 20 : 32);
    rowHeight = compactLandscapeTouch ? 38 : (portraitLayout ? 50 : 58);
    var touchButtonHeight:Float = compactLandscapeTouch ? 26 : (portraitLayout ? 32 : 34);
    var reservedRowsHeight:Float = usesTouchControls
      ? rowHeaderHeight + touchButtonHeight + 24
      : 68;
    visibleRows = Std.int(Math.max(1, Math.floor((listH - reservedRowsHeight) / rowHeight)));

    detailTitle.setPosition(detailX + (compactLandscapeTouch ? 14 : 22),
      detailY + (compactLandscapeTouch ? 14 : 22));
    detailTitle.fieldWidth = detailW - (compactLandscapeTouch ? 28 : 44);
    detailTitle.size = compactLandscapeTouch ? 16 : (portraitLayout ? 18 : 24);
    detailText.setPosition(detailX + (compactLandscapeTouch ? 14 : 22),
      detailY + (compactLandscapeTouch ? 48 : (portraitLayout ? 62 : 82)));
    detailText.fieldWidth = detailW - (compactLandscapeTouch ? 28 : 44);
    detailText.size = compactLandscapeTouch ? 9 : 13;

    var statusY:Float = compactLandscapeTouch ? height - 58 : height - 75;
    var helpY:Float = compactLandscapeTouch ? height - 32 : height - 48;
    statusText.setPosition(margin, statusY);
    statusText.fieldWidth = width - margin * 2;
    helpText.setPosition(margin, helpY);
    helpText.fieldWidth = width - margin * 2;
    helpText.size = compactLandscapeTouch ? 7 : (portraitLayout ? 8 : 9);
    helpText.text = usesTouchControls
      ? 'TAP A MOD TO SELECT  •  USE THE BUTTONS BELOW  •  SWIPE TO SCROLL'
      : 'UP / DOWN SELECT   ENTER TOGGLE   WHEEL SCROLL   LEFT / RIGHT LOAD PRIORITY   R RESCAN   ESC BACK';

    if (usesTouchControls)
      layoutTouchActions(rowX, listY + listH - touchButtonHeight - 8, rowWidth, touchButtonHeight);

    renderRows();
    renderDetails();
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, 18);
    #end
  }

  function layoutNovaBeatMobileViewport(width:Int, height:Int):Void
  {
    portraitLayout = height > width * 1.12;
    var margin:Float = portraitLayout ? 18 : 22;
    heading.setPosition(margin, 13);
    heading.fieldWidth = width - 160;
    heading.size = portraitLayout ? 28 : 25;
    countText.setPosition(margin, 49);
    countText.fieldWidth = width - margin * 2;

    if (mobileBackButton != null)
    {
      mobileBackButton.setPosition(width - 132, 12);
      mobileBackButton.makeGraphic(116, 46, 0xFF183B59);
      mobileBackLabel.setPosition(width - 128, 27);
      mobileBackLabel.fieldWidth = 108;
    }

    var panelY:Float = portraitLayout ? 94 : 82;
    var panelHeight:Float = Math.max(150, height - panelY - 48);
    var panelWidth:Float = width - margin * 2;
    var innerX:Float = margin + 16;
    var innerWidth:Float = panelWidth - 32;

    if (layoutPanels.length >= 2)
    {
      layoutPanels[0].setPosition(margin, panelY);
      layoutPanels[0].makeGraphic(Std.int(panelWidth), Std.int(panelHeight), 0xFF4269B5);
      layoutPanels[1].setPosition(margin + 2, panelY + 2);
      layoutPanels[1].makeGraphic(Std.int(panelWidth - 4), Std.int(panelHeight - 4), 0xF0061028);
    }

    listHeading.setPosition(innerX + 2, panelY + 16);
    listHeading.fieldWidth = innerWidth - 4;
    statusText.setPosition(innerX + 2, panelY + 39);
    statusText.fieldWidth = innerWidth - 4;

    rowX = innerX + 2;
    rowY = panelY + 63;
    rowWidth = innerWidth - 4;
    rowHeight = portraitLayout ? 102 : 88;
    var actionDockHeight:Float = mobileModActionsEnabled() ? 90 : 0;
    var listBottom:Float = panelY + panelHeight - 14 - actionDockHeight;
    visibleRows = Std.int(Math.max(1, Math.floor((listBottom - rowY) / rowHeight)));
    if (mobileModActionsEnabled())
    {
      var actionY:Float = panelY + panelHeight - actionDockHeight - 8;
      layoutMobileTouchActions(innerX, actionY, innerWidth, 38, 8, portraitLayout);
    }

    detailTitle.setPosition(rowX + 10, rowY + 54);
    detailTitle.fieldWidth = rowWidth - 20;
    detailTitle.size = 20;
    detailText.setPosition(rowX + 20, rowY + 98);
    detailText.fieldWidth = rowWidth - 40;
    detailText.fieldHeight = Math.max(80, listBottom - rowY - 112);
    detailText.size = 14;

    helpText.setPosition(margin, height - 28);
    helpText.fieldWidth = width - margin * 2;

    renderRows();
    renderDetails();
  }

  function layoutMobileViewport(width:Int, height:Int):Void
  {
    portraitLayout = height > width * 1.12;
    var margin:Float = 16;
    heading.setPosition(margin, 14);
    heading.fieldWidth = width - 150;
    heading.size = portraitLayout ? 25 : 23;
    countText.setPosition(margin, 48);
    countText.fieldWidth = width - margin * 2;

    if (mobileBackButton != null)
    {
      mobileBackButton.setPosition(width - 126, 12);
      mobileBackLabel.setPosition(width - 122, 25);
    }

    var panelY:Float = 82;
    var panelHeight:Float = Math.max(180, height - 118);
    var panelWidth:Float = width - margin * 2;
    var innerX:Float = margin + 14;
    var innerWidth:Float = panelWidth - 28;
    var summaryY:Float = panelY + 14;
    var summaryHeight:Float = portraitLayout ? 112 : 92;

    if (layoutPanels.length >= 4)
    {
      layoutPanels[0].setPosition(margin, panelY);
      layoutPanels[0].makeGraphic(Std.int(panelWidth), Std.int(panelHeight), 0xFF4269B5);
      layoutPanels[1].setPosition(margin + 2, panelY + 2);
      layoutPanels[1].makeGraphic(Std.int(panelWidth - 4), Std.int(panelHeight - 4), 0xF0061028);
      layoutPanels[2].setPosition(innerX, summaryY);
      layoutPanels[2].makeGraphic(Std.int(innerWidth), Std.int(summaryHeight), 0xFF285A82);
      layoutPanels[3].setPosition(innerX + 2, summaryY + 2);
      layoutPanels[3].makeGraphic(Std.int(innerWidth - 4), Std.int(summaryHeight - 4), 0xF0132845);
    }

    detailTitle.setPosition(innerX + 14, summaryY + 12);
    detailTitle.fieldWidth = innerWidth - 28;
    detailTitle.size = 16;
    detailText.setPosition(innerX + 14, summaryY + 40);
    detailText.fieldWidth = innerWidth - 28;
    detailText.fieldHeight = summaryHeight - 46;
    detailText.size = 11;
    statusText.setPosition(innerX + 14, summaryY + summaryHeight - 20);
    statusText.fieldWidth = innerWidth - 28;

    listHeading.setPosition(innerX + 2, summaryY + summaryHeight + 18);
    listHeading.fieldWidth = innerWidth - 4;
    rowX = innerX;
    rowY = summaryY + summaryHeight + 44;
    rowWidth = innerWidth;
    rowHeight = portraitLayout ? 78 : 74;
    var actionDockHeight:Float = mobileModActionsEnabled() ? 76 : 0;
    var listBottom:Float = panelY + panelHeight - 18 - actionDockHeight;
    visibleRows = Std.int(Math.max(1, Math.floor((listBottom - rowY) / rowHeight)));
    if (mobileModActionsEnabled())
    {
      var actionY:Float = panelY + panelHeight - actionDockHeight - 8;
      layoutMobileTouchActions(innerX, actionY, innerWidth, 30, 6, portraitLayout);
    }

    helpText.setPosition(margin, height - 22);
    helpText.fieldWidth = width - margin * 2;
    helpText.size = 9;

    renderRows();
    renderDetails();
  }

  function addPanel(x:Float, y:Float, width:Float, height:Float):Void
  {
    var border:FlxSprite = new FlxSprite(x, y);
    border.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), 0xFF4269B5);
    add(border);
    layoutPanels.push(border);
    var fill:FlxSprite = new FlxSprite(x + 2, y + 2);
    fill.makeGraphic(Std.int(Math.max(1, width - 4)), Std.int(Math.max(1, height - 4)), 0xF0061028);
    add(fill);
    layoutPanels.push(fill);
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
