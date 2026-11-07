package funkin.ui.mainmenu;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinCamera;
import funkin.util.DeviceUtil;
import funkin.util.TouchUtil;
import funkin.Preferences;
import funkin.modding.ExperienceManager;
import funkin.modding.ExperienceManager.ExperienceInfo;
import funkin.ui.MusicBeatState;
import funkin.ui.title.TitleState;

#if sys
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * In-game startup selector. This is not a separate launcher.
 */
class ExperienceLibraryState extends MusicBeatState
{
  var experiences:Array<ExperienceInfo> = [];
  var selectedIndex:Int = 0;
  var visibleRows:Int = 1;
  var rowHeight:Float = 82;
  var listX:Float = 0;
  var listY:Float = 0;
  var listWidth:Float = 0;
  var listHeight:Float = 0;
  var firstVisibleIndex:Int = 0;
  var scrollDirection:Int = 0;

  var layoutObjects:Array<FlxBasic> = [];
  var rowObjects:Array<FlxBasic> = [];
  var statusText:Null<FlxText> = null;
  var usesTouchControls:Bool = false;
  var rowHitboxes:Array<FlxSprite> = [];
  var touchButtonHitboxes:Array<FlxSprite> = [];
  var touchButtonActions:Array<String> = [];

  var touchGestureActive:Bool = false;
  var touchGestureStartX:Float = 0;
  var touchGestureStartY:Float = 0;
  var touchGestureLastY:Float = 0;
  var touchGestureStartSelected:Int = 0;
  var touchGestureStartedInList:Bool = false;
  var touchGestureDragged:Bool = false;

  override public function create():Void
  {
    FlxG.keys.enabled = true;
    FlxG.cameras.reset(new FunkinCamera("experienceLibrary"));
    super.create();

    // The experience library is a launcher, not the boot sequence.
    // Keep menu music silent here; TitleState starts the selected theme when
    // the randomized startup text sequence begins.
    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.stop();
      FlxG.sound.music.kill();
      FlxG.sound.music = null;
    }

    experiences = ExperienceManager.scanInstalled();
    selectSavedExperience();
    buildLayout();
  }

  function selectSavedExperience():Void
  {
    var savedId:String = ExperienceManager.getSavedExperienceId();
    for (index in 0...experiences.length)
    {
      if (experiences[index].id == savedId)
      {
        selectedIndex = index;
        return;
      }
    }
    selectedIndex = 0;
  }

  function buildLayout():Void
  {
    // Keep the FNF-style selector unchanged. The redesigned library is only
    // used by NovaBeat mode and does not replace or restyle the FNF menu.
    if (Preferences.menuStyle == "NovaBeat")
      buildNovaBeatLayout();
    else
      buildClassicLayout();
  }

  function buildNovaBeatLayout():Void
  {
    clearObjects(layoutObjects);
    clearObjects(rowObjects);
    rowHitboxes.resize(0);

    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    var portrait:Bool = height > width * 1.12;
    usesTouchControls = DeviceUtil.isMobileBrowser;
    touchButtonHitboxes.resize(0);
    touchButtonActions.resize(0);
    touchGestureActive = false;

    var compactTouchLayout:Bool = usesTouchControls && !portrait && height < 500;
    var margin:Float = usesTouchControls ? (portrait ? 14 : 22) : (portrait ? 22 : 42);

    // Full-bleed NovaBeat artwork replaces the old flat grey selector.
    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image("novabeat/menu-background"));
    var backgroundScale:Float = Math.max(width / Math.max(1, background.width), height / Math.max(1, background.height)) * 1.08;
    background.scale.set(backgroundScale, backgroundScale);
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    background.alpha = 0.72;
    addTracked(background, false);
    addTracked(addSolid(0, 0, width, height, 0xB8050A1B), false);

    var logo:FlxSprite = new FlxSprite(margin, 12).loadGraphic(Paths.image("novabeat/title-logo"));
    logo.setGraphicSize(0, portrait ? 38 : 48);
    logo.updateHitbox();
    logo.scrollFactor.set();
    addTracked(logo, false);

    var titleY:Float = portrait ? 51 : 60;
    addLabel(margin + 2, titleY, width - margin * 2, "GAME LIBRARY",
      portrait ? 25 : 32, 0xFFF4F7FF, false);
    addLabel(margin + 3, titleY + (portrait ? 30 : 38), width - margin * 2,
      "CHOOSE AN EXPERIENCE TO PLAY", 9, 0xFF68DFF7, false);

    var panelX:Float = margin;
    var panelY:Float = portrait ? 106 : (compactTouchLayout ? 90 : 122);
    var panelWidth:Float = width - margin * 2;
    var panelHeight:Float = height - panelY - (usesTouchControls ? (compactTouchLayout ? 52 : 66) : 72);

    addTracked(addRoundRect(panelX, panelY, panelWidth, panelHeight, 22, 22, 0xFF3B8FB4), false);
    addTracked(addRoundRect(panelX + 2, panelY + 2, panelWidth - 4, panelHeight - 4, 20, 20, 0xE9081429), false);
    addTracked(addRoundRect(panelX + 9, panelY + 9, panelWidth - 18, panelHeight - 18, 15, 15, 0x321D5B82), false);

    var inset:Float = portrait ? 12 : 18;
    listX = panelX + inset;
    listY = panelY + (compactTouchLayout ? 46 : 54);
    listWidth = panelWidth - inset * 2;
    rowHeight = portrait ? 88 : (compactTouchLayout ? 58 : (height < 500 ? 68 : 82));
    var rowGap:Float = 9;
    listHeight = panelHeight - (usesTouchControls ? (compactTouchLayout ? 150 : 174) : 88);
    visibleRows = Std.int(Math.max(1, Math.floor((listHeight + rowGap) / (rowHeight + rowGap))));
    firstVisibleIndex = 0;

    addLabel(listX + 2, panelY + 19, listWidth * 0.65, "AVAILABLE EXPERIENCES",
      10, 0xFF66DDF5, false);
    addLabel(listX + listWidth * 0.65, panelY + 19, listWidth * 0.35,
      Std.string(experiences.length) + (experiences.length == 1 ? " EXPERIENCE" : " EXPERIENCES"),
      8, 0xFF9AAFD0, false);

    var statusY:Float = panelY + panelHeight - (usesTouchControls ? (compactTouchLayout ? 90 : 111) : 34);
    statusText = addLabel(panelX + 16, statusY, panelWidth - 32, "",
      usesTouchControls ? 9 : 10, 0xFF72DDF5, false);

    if (usesTouchControls)
      buildTouchControls(panelX, panelY, panelWidth, panelHeight);

    var footer:String = usesTouchControls
      ? "TAP A CARD TO SELECT  •  TAP AGAIN OR PLAY SELECTED"
      : (portrait
        ? "UP / DOWN SELECT     ENTER PLAY     E ENABLE     TAB TYPE     ESC ORIGINAL FNF"
        : "UP / DOWN SELECT     ENTER PLAY     E ENABLE / DISABLE     TAB PACKAGE TYPE     T TARGET     R RESCAN     ESC ORIGINAL FNF");
    addLabel(margin + 4, height - 22, width - margin * 2 - 8,
      footer, 8, 0xFF9AAED0, false);

    renderRows();
    updateStatus();
  }

  function buildClassicLayout():Void
  {
    clearObjects(layoutObjects);
    clearObjects(rowObjects);

    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    var portrait:Bool = height > width * 1.12;
    usesTouchControls = DeviceUtil.isMobileBrowser;
    touchButtonHitboxes.resize(0);
    touchButtonActions.resize(0);
    var margin:Float = usesTouchControls ? (portrait ? 14 : 24) : (portrait ? 14 : 42);
    var panelX:Float = margin;
    var panelY:Float = portrait ? 84 : 82;
    var panelWidth:Float = width - margin * 2;
    var panelHeight:Float = height - panelY - (usesTouchControls ? 124 : (portrait ? 106 : 100));

    addTracked(addSolid(0, 0, width, height, 0xFF050608), false);
    addTracked(addRoundRect(panelX, panelY, panelWidth, panelHeight, 26, 26, 0xFF22252A), false);
    addTracked(addRoundRect(panelX + 2, panelY + 2, panelWidth - 4, panelHeight - 4, 24, 24, 0xFF101216), false);

    addLabel(margin + 8, portrait ? 16 : 14, panelWidth - 16, "GAME LIBRARY", portrait ? 24 : 30, 0xFFFFFFFF, false);
    addLabel(margin + 8, portrait ? 49 : 48, panelWidth - 16, "SELECT AN EXPERIENCE", 10, 0xFF98A1B4, false);

    var inset:Float = portrait ? 9 : 16;
    listX = panelX + inset;
    listY = panelY + (portrait ? 12 : 16);
    listWidth = panelWidth - inset * 2;
    listHeight = panelHeight - (usesTouchControls ? 143 : (portrait ? 68 : 64));
    // Keep a compact row on short landscape phones so the row, status line,
    // and touch buttons never overlap one another.
    var compactTouchLayout:Bool = usesTouchControls && !portrait && height < 500;
    rowHeight = portrait ? 88 : (compactTouchLayout ? 56 : 82);
    var rowGap:Float = 9;
    visibleRows = Std.int(Math.max(1, Math.floor((listHeight + rowGap) / (rowHeight + rowGap))));
    firstVisibleIndex = 0;

    var statusY:Float = usesTouchControls ? panelY + panelHeight - 98 : panelY + panelHeight - 32;
    statusText = addLabel(panelX + 16, statusY, panelWidth - 32, "", 9, 0xFF86DFFF, false);
    var footer:String = usesTouchControls
      ? "TAP TO SELECT  •  SWIPE TO SCROLL  •  LAUNCH SELECTED"
      : (portrait
        ? "UP/DOWN SELECT   ENTER LAUNCH   E ENABLE   TAB TYPE   T TARGET   ESC FNF"
        : "UP / DOWN SELECT     ENTER LAUNCH     E ENABLE/DISABLE     TAB PACKAGE TYPE     T EXTENSION TARGET     R RESCAN     ESC FNF");
    addLabel(margin + 8, height - (portrait ? 16 : 18), width - margin * 2 - 16,
      footer, 8, 0xFF929BAE, false);

    if (usesTouchControls) buildTouchControls(panelX, panelY, panelWidth, panelHeight);

    renderRows();
    updateStatus();
  }

  function buildTouchControls(panelX:Float, panelY:Float, panelWidth:Float, panelHeight:Float):Void
  {
    var portrait:Bool = FlxG.height > FlxG.width * 1.12;
    var compact:Bool = !portrait && FlxG.height < 500;
    var primaryHeight:Float = portrait ? 42 : (compact ? 34 : 40);
    var secondaryHeight:Float = portrait ? 34 : (compact ? 28 : 32);
    var primaryY:Float = panelY + panelHeight - (primaryHeight + secondaryHeight + 17);
    var secondaryY:Float = panelY + panelHeight - secondaryHeight - 9;
    var gap:Float = 7;
    var launchWidth:Float = (listWidth - gap) * 0.62;

    addTouchButton(listX, primaryY, launchWidth, primaryHeight, "PLAY SELECTED", "launch", true);
    addTouchButton(listX + launchWidth + gap, primaryY, listWidth - launchWidth - gap, primaryHeight, "ORIGINAL FNF", "official", false);

    var smallGap:Float = 5;
    var smallWidth:Float = (listWidth - smallGap * 3) / 4;
    addTouchButton(listX, secondaryY, smallWidth, secondaryHeight, "ENABLE", "toggle", false);
    addTouchButton(listX + smallWidth + smallGap, secondaryY, smallWidth, secondaryHeight, "TYPE", "type", false);
    addTouchButton(listX + (smallWidth + smallGap) * 2, secondaryY, smallWidth, secondaryHeight, "TARGET", "target", false);
    addTouchButton(listX + (smallWidth + smallGap) * 3, secondaryY, smallWidth, secondaryHeight, "RESCAN", "rescan", false);
  }

  function addTouchButton(x:Float, y:Float, width:Float, height:Float, label:String, action:String, highlighted:Bool):Void
  {
    var novaBeatStyle:Bool = Preferences.menuStyle == "NovaBeat";
    var borderColor:FlxColor = highlighted
      ? (novaBeatStyle ? 0xFF55DDF5 : 0xFF56D8F1)
      : (novaBeatStyle ? 0xFF355574 : 0xFF414955);
    var fillColor:FlxColor = highlighted
      ? (novaBeatStyle ? 0xFF123A55 : 0xFF172D38)
      : (novaBeatStyle ? 0xFF111F36 : 0xFF20252D);
    var hitbox:FlxSprite = addRoundRect(x, y, width, height, 9, 9, borderColor);
    addTracked(hitbox, false);
    addTracked(addRoundRect(x + 1, y + 1, width - 2, height - 2, 8, 8, fillColor), false);

    var textSize:Int = height <= 30 ? 8 : 10;
    var labelText:FlxText = new FlxText(x + 2, y + (height - textSize) * 0.5 - 1, width - 4, label, textSize);
    labelText.setFormat(Paths.font("vcr.ttf"), textSize,
      novaBeatStyle ? 0xFFF1F7FF : 0xFFF1F5FA, FlxTextAlign.CENTER);
    labelText.scrollFactor.set();
    add(labelText);
    layoutObjects.push(labelText);

    touchButtonHitboxes.push(hitbox);
    touchButtonActions.push(action);
  }

  function renderRows():Void
  {
    clearObjects(rowObjects);
    rowHitboxes.resize(0);
    if (experiences.length == 0) return;

    var portrait:Bool = FlxG.height > FlxG.width * 1.12;
    var novaBeatStyle:Bool = Preferences.menuStyle == "NovaBeat";
    adjustScrollWindow();
    var rowGap:Float = 9;

    for (visibleIndex in 0...visibleRows)
    {
      var experienceIndex:Int = firstVisibleIndex + visibleIndex;
      if (experienceIndex >= experiences.length) break;

      var info:ExperienceInfo = experiences[experienceIndex];
      var y:Float = listY + visibleIndex * (rowHeight + rowGap);
      var selected:Bool = experienceIndex == selectedIndex;
      var borderColor:FlxColor = selected
        ? (novaBeatStyle ? 0xFF5ADDF5 : 0xFF56D8F1)
        : (novaBeatStyle ? 0xFF263D5C : 0xFF343941);

      var rowHitbox:FlxSprite = addRoundRect(listX, y, listWidth, rowHeight, 16, 16, borderColor);
      addTracked(rowHitbox, true);
      rowHitboxes.push(rowHitbox);
      var cardFill:FlxColor = selected
        ? (novaBeatStyle ? 0xFF172C47 : 0xFF1A2731)
        : (novaBeatStyle ? 0xE90B172C : 0xFF191C21);
      addTracked(addRoundRect(listX + 2, y + 2, listWidth - 4, rowHeight - 4, 14, 14, cardFill), true);

      if (novaBeatStyle)
        addTracked(addRoundRect(listX + 8, y + 12, 4, rowHeight - 24, 3, 3,
          selected ? 0xFF5ADDF5 : 0xFF2C75AB), true);

      var compactTouchRow:Bool = usesTouchControls && !portrait && FlxG.height < 500;
      var iconSize:Float = compactTouchRow ? 40 : (portrait ? 58 : 56);
      var iconX:Float = listX + 15;
      var iconY:Float = y + (rowHeight - iconSize) / 2;
      var iconPlateColor:FlxColor = selected && novaBeatStyle ? 0xFF1D4D6C : 0xFF303640;
      addTracked(addRoundRect(iconX, iconY, iconSize, iconSize, 11, 11, iconPlateColor), true);
      addExperienceIcon(info, iconX + 3, iconY + 3, iconSize - 6);

      var textX:Float = iconX + iconSize + 15;
      var textWidth:Float = listWidth - (textX - listX) - 18;
      var detail:String = info.isOfficial
        ? "BASE GAME  •  DEFAULT EXPERIENCE  •  " + info.engineLabel
        : info.engineLabel + "  •  " + packageTypeLabel(info.packageType);
      if (!info.isOfficial && info.packageType == ExperienceManager.PACKAGE_EXTENSION)
        detail += "  →  " + ExperienceManager.experienceTitle(info.ownerId, experiences);
      if (!info.isOfficial) detail += info.enabled ? "  •  ENABLED" : "  •  DISABLED";
      if (!info.launchable) detail += "  •  NOT YET SUPPORTED";

      if (compactTouchRow)
      {
        addRowLabel(textX, y + 6, textWidth, info.title, 12, selected ? 0xFFFFFFFF : 0xFFE1E5EC);
        addRowLabel(textX, y + 24, textWidth, shorten(info.description, 68), 7, 0xFFB1B8C5);
        addRowLabel(textX, y + 40, textWidth, detail, 7, info.launchable ? 0xFF70D9F0 : 0xFFFFB86B);
      }
      else
      {
        addRowLabel(textX, y + 9, textWidth, info.title, portrait ? 14 : 16,
          selected ? 0xFFFFFFFF : 0xFFE1E5EC);
        addRowLabel(textX, y + 33, textWidth, shorten(info.description, 105), portrait ? 9 : 10, 0xFFB1B8C5);
        addRowLabel(textX, y + 58, textWidth, detail, 8,
          info.launchable ? (novaBeatStyle ? 0xFF69DFF7 : 0xFF70D9F0) : 0xFFFFB86B);
      }
    }
  }

  function shorten(value:String, maxLength:Int):String
  {
    if (value.length <= maxLength) return value;
    return value.substr(0, maxLength - 3) + "...";
  }

  function addExperienceIcon(info:ExperienceInfo, x:Float, y:Float, size:Float):Void
  {
    var loaded:Bool = false;
    #if sys
    if (info.iconPath != null && FileSystem.exists(info.iconPath))
    {
      try
      {
        var bitmap:BitmapData = BitmapData.fromBytes(File.getBytes(info.iconPath));
        var icon:FlxSprite = new FlxSprite(x, y);
        icon.loadGraphic(bitmap);
        icon.setGraphicSize(Std.int(size), Std.int(size));
        icon.updateHitbox();
        icon.scrollFactor.set();
        addTracked(icon, true);
        loaded = true;
      }
      catch (error:Dynamic)
      {
        trace("Could not load experience icon: " + Std.string(error));
      }
    }
    #end

    if (!loaded)
    {
      var label:String = info.isOfficial ? "FNF" : info.title.substr(0, 1).toUpperCase();
      addRowLabel(x, y + size * 0.22, size, label, info.isOfficial ? 16 : 24, 0xFFE7EDF6, true);
    }
  }

  function packageTypeLabel(value:String):String
  {
    return switch (value)
    {
      case ExperienceManager.PACKAGE_STANDALONE: "STANDALONE";
      case ExperienceManager.PACKAGE_EXTENSION: "CONTENT EXTENSION";
      default: "UNCLASSIFIED";
    };
  }

  function updateStatus(?message:String):Void
  {
    if (statusText == null) return;
    if (message != null)
    {
      statusText.text = message;
      return;
    }

    var info:ExperienceInfo = experiences.length > 0 ? experiences[selectedIndex] : null;
    if (info == null)
    {
      statusText.text = "No installed experience was found.";
      return;
    }
    if (!info.isOfficial && !info.enabled)
      statusText.text = usesTouchControls ? "DISABLED: TAP TOGGLE TO ENABLE THIS PACKAGE." : "DISABLED: PRESS E TO ENABLE THIS PACKAGE.";
    else if (info.packageType == ExperienceManager.PACKAGE_EXTENSION)
      statusText.text = "CONTENT EXTENSION: LAUNCH ITS ASSIGNED EXPERIENCE.";
    else if (info.packageType == ExperienceManager.PACKAGE_UNCLASSIFIED)
      statusText.text = usesTouchControls ? "UNCLASSIFIED: TAP TYPE TO CHOOSE A PACKAGE TYPE." : "UNCLASSIFIED: PRESS TAB TO CHOOSE A PACKAGE TYPE.";
    else if (info.launchable)
      statusText.text = usesTouchControls ? "SELECTED: " + info.title + "  •  TAP LAUNCH SELECTED" : "SELECTED: " + info.title + "    •    ENTER TO LAUNCH";
    else
      statusText.text = info.explanation;
  }

  function selectExperience(index:Int):Void
  {
    if (experiences.length == 0) return;
    var next:Int = Std.int(Math.max(0, Math.min(experiences.length - 1, index)));
    if (next == selectedIndex) return;
    var previousFirst:Int = firstVisibleIndex;
    selectedIndex = next;
    adjustScrollWindow();
    scrollDirection = firstVisibleIndex > previousFirst ? 1 : (firstVisibleIndex < previousFirst ? -1 : 0);
    renderRows();
    scrollDirection = 0;
    updateStatus();
    FunkinSound.playOnce(Paths.sound("scrollMenu"), 0.4);
  }

  function adjustScrollWindow():Void
  {
    if (selectedIndex < firstVisibleIndex)
      firstVisibleIndex = selectedIndex;
    else if (selectedIndex >= firstVisibleIndex + visibleRows)
      firstVisibleIndex = selectedIndex - visibleRows + 1;

    var maxFirst:Int = Std.int(Math.max(0, experiences.length - visibleRows));
    firstVisibleIndex = Std.int(Math.max(0, Math.min(firstVisibleIndex, maxFirst)));
  }

  function launchExperience(info:ExperienceInfo):Void
  {
    var error:Null<String> = ExperienceManager.activate(info);
    if (error != null)
    {
      updateStatus(error);
      FunkinSound.playOnce(Paths.sound("cancelMenu"));
      return;
    }

    // The Mod Library is the game's startup entry point. The stock title
    // intro normally runs only once per process, so clear its session flag
    // here to ensure the randomized black-screen intro plays after launch.
    // [web-build] Verify this startup handoff in the HTML5 browser build.
    TitleState.initialized = false;
    FlxG.switchState(() -> new TitleState());
  }

  function launchOfficialExperience():Void
  {
    for (info in experiences)
    {
      if (info.isOfficial)
      {
        launchExperience(info);
        return;
      }
    }
  }

  // Accept both FlxTouch and the HTML5 compatibility mouse pointer.
  // Some mobile browsers emit the release on the mouse pointer even when the
  // press began as a touch, so neither input stream is allowed to suppress the other.
  function pointerOverAt(sprite:FlxSprite, pointer:Dynamic):Bool
  {
    if (sprite == null || pointer == null) return false;
    return pointer.overlaps(sprite, sprite.camera);
  }

  function handleTapAt(pointer:Dynamic):Bool
  {
    if (pointer == null) return false;

    for (index in 0...touchButtonHitboxes.length)
    {
      if (pointerOverAt(touchButtonHitboxes[index], pointer))
      {
        performTouchAction(touchButtonActions[index]);
        return true;
      }
    }

    for (index in 0...rowHitboxes.length)
    {
      if (pointerOverAt(rowHitboxes[index], pointer))
      {
        handleTouchRowTap(firstVisibleIndex + index);
        return true;
      }
    }
    return false;
  }

  function handleTouchInput():Void
  {
    #if web
    var pointerInputEnabled:Bool = true;
    #else
    var pointerInputEnabled:Bool = usesTouchControls;
    #end
    if (!pointerInputEnabled) return;

    var touchPointer:Dynamic = TouchUtil.touch;
    var touchJustPressed:Bool = TouchUtil.justPressed;
    var touchPressed:Bool = TouchUtil.pressed;
    var touchJustReleased:Bool = TouchUtil.justReleased;
    var mouseJustPressed:Bool = FlxG.mouse.justPressed;
    var mousePressed:Bool = FlxG.mouse.pressed;
    var mouseJustReleased:Bool = FlxG.mouse.justReleased;

    if (touchJustPressed || mouseJustPressed)
    {
      var pressPointer:Dynamic = touchJustPressed && touchPointer != null ? touchPointer : FlxG.mouse;
      touchGestureActive = true;
      touchGestureStartX = pressPointer.x;
      touchGestureStartY = pressPointer.y;
      touchGestureStartSelected = selectedIndex;
      touchGestureStartedInList = touchGestureStartX >= listX
        && touchGestureStartX <= listX + listWidth
        && touchGestureStartY >= listY
        && touchGestureStartY <= listY + listHeight;
      touchGestureDragged = false;
    }

    if (touchGestureActive && (touchPressed || mousePressed))
    {
      var movePointer:Dynamic = touchPressed && touchPointer != null ? touchPointer : FlxG.mouse;
      if (Math.abs(movePointer.x - touchGestureStartX) > 24
        || Math.abs(movePointer.y - touchGestureStartY) > 24)
        touchGestureDragged = true;
      touchGestureLastY = movePointer.y;
    }

    if (!(touchJustReleased || mouseJustReleased)) return;

    var releasePointer:Dynamic = touchJustReleased && touchPointer != null ? touchPointer : FlxG.mouse;
    var releaseY:Float = releasePointer == null ? touchGestureStartY : releasePointer.y;
    var deltaY:Float = releaseY - touchGestureStartY;

    if (touchGestureActive && touchGestureStartedInList && Math.abs(deltaY) > 28)
    {
      var rowsToMove:Int = Std.int(Math.max(1, Math.round(Math.abs(deltaY) / ((rowHeight + 9) * 0.72))));
      selectExperience(touchGestureStartSelected + (deltaY < 0 ? rowsToMove : -rowsToMove));
    }
    else if (!touchGestureActive || !touchGestureDragged)
    {
      var handled:Bool = false;
      // Test both pointer locations: the browser's synthetic mouse release can
      // land on a valid button even when the FlxTouch list has already emptied.
      if (touchJustReleased && touchPointer != null)
        handled = handleTapAt(touchPointer);
      if (!handled && mouseJustReleased)
        handled = handleTapAt(FlxG.mouse);
      if (!handled && touchJustReleased && touchPointer == null)
        handleTapAt(FlxG.mouse);
    }

    touchGestureActive = false;
    touchGestureDragged = false;
  }

  /**
   * The official Base Game is selected by default. Tapping an already-selected
   * row should launch it instead of appearing to ignore the tap. A first tap
   * on another package selects it; tapping that selected row again launches it.
   */
  function handleTouchRowTap(index:Int):Void
  {
    if (index < 0 || index >= experiences.length) return;
    if (index == selectedIndex)
    {
      launchExperience(experiences[index]);
      return;
    }
    selectExperience(index);
  }

  function performTouchAction(action:String):Void
  {
    switch (action)
    {
      case "launch":
        if (experiences.length > 0) launchExperience(experiences[selectedIndex]);
        else updateStatus("NO INSTALLED EXPERIENCE WAS FOUND.");
      case "official":
        launchOfficialExperience();
      case "toggle":
        toggleSelectedPackage();
      case "type":
        cycleSelectedPackageType();
      case "target":
        cycleSelectedExtensionOwner();
      case "rescan":
        rescanExperiences();
    }
  }

  function toggleSelectedPackage():Void
  {
    if (experiences.length == 0) return;
    var info:ExperienceInfo = experiences[selectedIndex];
    if (info.isOfficial)
    {
      updateStatus("THE OFFICIAL FNF EXPERIENCE CANNOT BE DISABLED.");
      return;
    }
    var enabled:Bool = ExperienceManager.setPackageEnabled(info);
    experiences = ExperienceManager.scanInstalled();
    selectById(info.id);
    renderRows();
    updateStatus(enabled ? "PACKAGE ENABLED." : "PACKAGE DISABLED.");
  }

  function cycleSelectedPackageType():Void
  {
    if (experiences.length == 0) return;
    var info:ExperienceInfo = experiences[selectedIndex];
    if (info.isOfficial)
    {
      updateStatus("THE OFFICIAL FNF EXPERIENCE DOES NOT NEED A PACKAGE TYPE.");
      return;
    }
    var nextType:String = ExperienceManager.cyclePackageType(info);
    experiences = ExperienceManager.scanInstalled();
    selectById(info.id);
    renderRows();
    updateStatus("PACKAGE TYPE SAVED: " + packageTypeLabel(nextType));
  }

  function cycleSelectedExtensionOwner():Void
  {
    if (experiences.length == 0) return;
    var info:ExperienceInfo = experiences[selectedIndex];
    if (info.isOfficial || info.packageType != ExperienceManager.PACKAGE_EXTENSION)
    {
      updateStatus("SELECT A CONTENT EXTENSION TO CHANGE ITS TARGET.");
      return;
    }
    var ownerId:String = ExperienceManager.cycleExtensionOwner(info, experiences);
    experiences = ExperienceManager.scanInstalled();
    selectById(info.id);
    renderRows();
    updateStatus("EXTENSION TARGET: " + ExperienceManager.experienceTitle(ownerId, experiences));
  }

  function rescanExperiences():Void
  {
    var previousId:String = experiences.length > 0 ? experiences[selectedIndex].id : "";
    experiences = ExperienceManager.scanInstalled();
    if (previousId != "") selectById(previousId) else selectedIndex = 0;
    renderRows();
    updateStatus("MOD LIBRARY RESCANNED.");
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    handleTouchInput();
    if (experiences.length == 0) return;

    if (FlxG.keys.justPressed.UP) selectExperience(selectedIndex - 1);
    if (FlxG.keys.justPressed.DOWN) selectExperience(selectedIndex + 1);

    if (FlxG.keys.justPressed.E) toggleSelectedPackage();

    if (FlxG.keys.justPressed.TAB) cycleSelectedPackageType();

    if (FlxG.keys.justPressed.T) cycleSelectedExtensionOwner();

    if (FlxG.keys.justPressed.R) rescanExperiences();

    if (FlxG.keys.justPressed.ENTER) launchExperience(experiences[selectedIndex]);
    if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) launchOfficialExperience();
  }

  function selectById(id:String):Void
  {
    for (index in 0...experiences.length)
    {
      if (experiences[index].id == id)
      {
        selectedIndex = index;
        return;
      }
    }
    selectedIndex = 0;
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width > 0 && height > 0) buildLayout();
  }

  function addLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor, row:Bool):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(Paths.font("vcr.ttf"), size, color, FlxTextAlign.LEFT);
    label.scrollFactor.set();
    add(label);
    if (row) rowObjects.push(label) else layoutObjects.push(label);
    return label;
  }

  function addRowLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor, centered:Bool = false):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(Paths.font("vcr.ttf"), size, color, centered ? FlxTextAlign.CENTER : FlxTextAlign.LEFT);
    label.scrollFactor.set();
    add(label);
    rowObjects.push(label);
    return label;
  }

  function addRoundRect(x:Float, y:Float, width:Float, height:Float, radiusX:Float, radiusY:Float, color:FlxColor):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
    sprite.makeGraphic(Std.int(Math.max(1, Math.ceil(width))), Std.int(Math.max(1, Math.ceil(height))), FlxColor.TRANSPARENT);
    FlxSpriteUtil.drawRoundRect(sprite, 0, 0, width, height, radiusX, radiusY, color);
    sprite.scrollFactor.set();
    return sprite;
  }

  function addSolid(x:Float, y:Float, width:Float, height:Float, color:FlxColor):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
    sprite.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), color);
    sprite.scrollFactor.set();
    return sprite;
  }

  function addTracked(object:FlxBasic, row:Bool):Void
  {
    if (row && scrollDirection != 0 && Std.isOfType(object, FlxSprite))
    {
      var sprite:FlxSprite = cast object;
      var targetY:Float = sprite.y;
      sprite.y += scrollDirection * 22;
      sprite.alpha = 0;
      FlxTween.tween(sprite, {y: targetY, alpha: 1}, 0.16, {ease: FlxEase.quadOut});
    }
    add(object);
    if (row) rowObjects.push(object) else layoutObjects.push(object);
  }

  function clearObjects(objects:Array<FlxBasic>):Void
  {
    for (object in objects)
    {
      if (Std.isOfType(object, FlxSprite)) FlxTween.cancelTweensOf(cast object);
      remove(object, true);
    }
    objects.resize(0);
  }
}
