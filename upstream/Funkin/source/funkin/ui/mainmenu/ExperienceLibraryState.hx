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

    experiences = ExperienceManager.scanInstalled();
    selectSavedExperience();
    buildLayout();

    FunkinSound.playMusic("freakyMenu", {
      overrideExisting: true,
      restartTrack: false,
      persist: true,
      mapTimeChanges: false
    });
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
    rowHeight = portrait ? 88 : 82;
    var rowGap:Float = 9;
    visibleRows = Std.int(Math.max(1, Math.floor((listHeight + rowGap) / (rowHeight + rowGap))));
    firstVisibleIndex = 0;

    var statusY:Float = usesTouchControls ? panelY + panelHeight - 119 : panelY + panelHeight - 32;
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
    var primaryY:Float = panelY + panelHeight - 78;
    var secondaryY:Float = panelY + panelHeight - 39;
    var gap:Float = 7;
    var launchWidth:Float = (listWidth - gap) * 0.62;
    addTouchButton(listX, primaryY, launchWidth, 32, "LAUNCH SELECTED", "launch", true);
    addTouchButton(listX + launchWidth + gap, primaryY, listWidth - launchWidth - gap, 32, "ORIGINAL FNF", "official", false);

    var smallGap:Float = 5;
    var smallWidth:Float = (listWidth - smallGap * 3) / 4;
    addTouchButton(listX, secondaryY, smallWidth, 26, "TOGGLE", "toggle", false);
    addTouchButton(listX + smallWidth + smallGap, secondaryY, smallWidth, 26, "TYPE", "type", false);
    addTouchButton(listX + (smallWidth + smallGap) * 2, secondaryY, smallWidth, 26, "TARGET", "target", false);
    addTouchButton(listX + (smallWidth + smallGap) * 3, secondaryY, smallWidth, 26, "RESCAN", "rescan", false);
  }

  function addTouchButton(x:Float, y:Float, width:Float, height:Float, label:String, action:String, highlighted:Bool):Void
  {
    var borderColor:FlxColor = highlighted ? 0xFF56D8F1 : 0xFF414955;
    var fillColor:FlxColor = highlighted ? 0xFF172D38 : 0xFF20252D;
    var hitbox:FlxSprite = addRoundRect(x, y, width, height, 9, 9, borderColor);
    addTracked(hitbox, false);
    addTracked(addRoundRect(x + 1, y + 1, width - 2, height - 2, 8, 8, fillColor), false);

    var textSize:Int = height <= 26 ? 7 : 8;
    var labelText:FlxText = new FlxText(x + 2, y + (height - textSize) / 2 - 1, width - 4, label, textSize);
    labelText.setFormat(Paths.font("vcr.ttf"), textSize, 0xFFF1F5FA, FlxTextAlign.CENTER);
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
    adjustScrollWindow();
    var rowGap:Float = 9;

    for (visibleIndex in 0...visibleRows)
    {
      var experienceIndex:Int = firstVisibleIndex + visibleIndex;
      if (experienceIndex >= experiences.length) break;

      var info:ExperienceInfo = experiences[experienceIndex];
      var y:Float = listY + visibleIndex * (rowHeight + rowGap);
      var selected:Bool = experienceIndex == selectedIndex;
      var borderColor:FlxColor = selected ? 0xFF56D8F1 : 0xFF343941;

      var rowHitbox:FlxSprite = addRoundRect(listX, y, listWidth, rowHeight, 16, 16, borderColor);
      addTracked(rowHitbox, true);
      rowHitboxes.push(rowHitbox);
      addTracked(addRoundRect(listX + 2, y + 2, listWidth - 4, rowHeight - 4, 14, 14, selected ? 0xFF1A2731 : 0xFF191C21), true);

      var iconSize:Float = portrait ? 58 : 56;
      var iconX:Float = listX + 13;
      var iconY:Float = y + (rowHeight - iconSize) / 2;
      addTracked(addRoundRect(iconX, iconY, iconSize, iconSize, 11, 11, 0xFF303640), true);
      addExperienceIcon(info, iconX + 3, iconY + 3, iconSize - 6);

      var textX:Float = iconX + iconSize + 15;
      var textWidth:Float = listWidth - (textX - listX) - 18;
      addRowLabel(textX, y + 9, textWidth, info.title, portrait ? 14 : 16, selected ? 0xFFFFFFFF : 0xFFE1E5EC);
      addRowLabel(textX, y + 33, textWidth, shorten(info.description, 105), portrait ? 9 : 10, 0xFFB1B8C5);

      var detail:String = info.engineLabel + "  •  " + packageTypeLabel(info.packageType);
      if (info.packageType == ExperienceManager.PACKAGE_EXTENSION)
        detail += "  →  " + ExperienceManager.experienceTitle(info.ownerId, experiences);
      if (!info.isOfficial) detail += info.enabled ? "  •  ENABLED" : "  •  DISABLED";
      if (!info.launchable) detail += "  •  DETECTED, NOT YET SUPPORTED";
      addRowLabel(textX, y + 58, textWidth, detail, 8, info.launchable ? 0xFF70D9F0 : 0xFFFFB86B);
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

  function pointerOver(sprite:FlxSprite):Bool
  {
    if (sprite == null) return false;

    // Prefer a real FlxTouch / Quest pointer when one is present. Browsers
    // that expose only a synthesized mouse event still use the mouse fallback.
    var touchOver:Bool = TouchUtil.overlaps(sprite, sprite.camera)
      || TouchUtil.overlapsComplex(sprite, sprite.camera);
    #if web
    return touchOver || FlxG.mouse.overlaps(sprite, sprite.camera);
    #else
    return touchOver;
    #end
  }

  function handleTouchInput():Void
  {
    if (!usesTouchControls) return;

    var pointer:Dynamic = TouchUtil.touch;
    // On HTML5, some browsers expose only the synthesized mouse stream.
    // Use that stream as the gesture pointer when there is no active FlxTouch.
    #if web
    var touchContactActive:Bool = pointer != null
      && (TouchUtil.pressed || TouchUtil.justPressed || TouchUtil.justReleased);
    var browserMouseEvent:Bool = FlxG.mouse.justPressed || FlxG.mouse.pressed || FlxG.mouse.justReleased;
    if (!touchContactActive && browserMouseEvent) pointer = FlxG.mouse;
    #end
    if (pointer == null) return;

    // Treat browser touch and synthesized mouse events as the same gesture.
    // Using both release signals avoids dropping taps on Android browsers
    // that emit only one of the two event streams.
    var justPressed:Bool = TouchUtil.justPressed || FlxG.mouse.justPressed;
    var pressed:Bool = TouchUtil.pressed || FlxG.mouse.pressed;
    var justReleased:Bool = TouchUtil.justReleased || FlxG.mouse.justReleased;

    if (justPressed)
    {
      touchGestureActive = true;
      touchGestureStartX = pointer.x;
      touchGestureStartY = pointer.y;
      touchGestureLastY = touchGestureStartY;
      touchGestureStartSelected = selectedIndex;
      touchGestureStartedInList = touchGestureStartX >= listX
        && touchGestureStartX <= listX + listWidth
        && touchGestureStartY >= listY
        && touchGestureStartY <= listY + listHeight;
      touchGestureDragged = false;
    }

    if (touchGestureActive && pressed)
    {
      var pointerX:Float = pointer.x;
      var pointerY:Float = pointer.y;
      if (Math.abs(pointerX - touchGestureStartX) > 24 || Math.abs(pointerY - touchGestureStartY) > 24)
        touchGestureDragged = true;
      touchGestureLastY = pointerY;
    }

    if (justReleased && !touchGestureActive)
    {
      // Recover a browser tap whose touch-down event was swallowed by the
      // address bar / pointer layer. A release directly over a visible action
      // or row should still do something instead of appearing unresponsive.
      var actionFound:Bool = false;
      for (index in 0...touchButtonHitboxes.length)
      {
        if (pointerOver(touchButtonHitboxes[index]))
        {
          performTouchAction(touchButtonActions[index]);
          actionFound = true;
          break;
        }
      }

      if (!actionFound)
      {
        for (index in 0...rowHitboxes.length)
        {
          if (pointerOver(rowHitboxes[index]))
          {
            selectExperience(firstVisibleIndex + index);
            break;
          }
        }
      }
      return;
    }

    if (touchGestureActive && justReleased)
    {
      var releaseY:Float = pointer.y;
      var deltaY:Float = releaseY - touchGestureStartY;
      if (touchGestureStartedInList && Math.abs(deltaY) > 28)
      {
        var rowsToMove:Int = Std.int(Math.max(1, Math.round(Math.abs(deltaY) / ((rowHeight + 9) * 0.72))));
        selectExperience(touchGestureStartSelected + (deltaY < 0 ? rowsToMove : -rowsToMove));
      }
      else if (!touchGestureDragged)
      {
        var actionFound:Bool = false;
        for (index in 0...touchButtonHitboxes.length)
        {
          if (pointerOver(touchButtonHitboxes[index]))
          {
            performTouchAction(touchButtonActions[index]);
            actionFound = true;
            break;
          }
        }

        if (!actionFound)
        {
          for (index in 0...rowHitboxes.length)
          {
            if (pointerOver(rowHitboxes[index]))
            {
              selectExperience(firstVisibleIndex + index);
              break;
            }
          }
        }
      }

      touchGestureActive = false;
      touchGestureDragged = false;
    }
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
