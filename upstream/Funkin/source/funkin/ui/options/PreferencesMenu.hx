package funkin.ui.options;

import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxPoint;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.Page;
import funkin.audio.FunkinSound;
import funkin.ui.title.TitleState;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.options.items.CheckboxPreferenceItem;
import funkin.ui.options.items.NumberPreferenceItem;
import funkin.ui.options.items.EnumPreferenceItem;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
#if mobile
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.ui.FunkinHitbox.FunkinHitboxControlSchemes;
import funkin.util.TouchUtil;
import funkin.util.SwipeUtil;
#end
import funkin.util.HapticUtil;
import lime.ui.WindowVSyncMode;

class PreferencesMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var items:TextMenuList;
  var preferenceItems:FlxTypedSpriteGroup<FlxSprite>;
  var preferenceDesc:Array<String> = [];
  var itemDesc:FlxText;
  var itemDescBox:FunkinSprite;
  var menuCamera:FlxCamera;
  var hudCamera:FlxCamera;
  var camFollow:FlxObject;
  var novaBeatStyle:Bool = false;
  var novaBeatRowLayer:FlxTypedSpriteGroup<FlxSprite>;
  var novaBeatLabelLayer:FlxTypedSpriteGroup<FlxSprite>;
  var novaBeatRowBackgrounds:Array<FlxSprite> = [];
  var novaBeatRowAccents:Array<FlxSprite> = [];
  var novaBeatRowLabels:Array<FlxText> = [];

  public function new()
  {
    super();

    novaBeatStyle = Preferences.menuStyle == "NovaBeat";
    menuCamera = new FunkinCamera('prefMenu');
    FlxG.cameras.add(menuCamera, false);
    menuCamera.bgColor = 0x0;

    hudCamera = new FlxCamera();
    FlxG.cameras.add(hudCamera, false);
    hudCamera.bgColor = 0x0;

    camera = menuCamera;
    NovaBeatOptionsChrome.apply(this, 'PREFERENCES', menuCamera);

    // Draw the NovaBeat row panels before the interactive menu items.
    add(novaBeatRowLayer = new FlxTypedSpriteGroup<FlxSprite>());
    novaBeatRowLayer.cameras = [menuCamera];
    add(items = new TextMenuList());
    items.cameras = [menuCamera];
    add(preferenceItems = new FlxTypedSpriteGroup<FlxSprite>());
    preferenceItems.cameras = [menuCamera];
    add(novaBeatLabelLayer = new FlxTypedSpriteGroup<FlxSprite>());
    novaBeatLabelLayer.cameras = [menuCamera];

    add(itemDescBox = new FunkinSprite());
    itemDescBox.cameras = [hudCamera];

    add(itemDesc = new FlxText(0, 0, 1180, null, 32));
    itemDesc.cameras = [hudCamera];

    createPrefItems();
    createPrefDescription();
    updateNovaBeatRows();

    camFollow = new FlxObject(FlxG.width / 2, 0, 140, 70);

    menuCamera.follow(camFollow, null, 0.085);
    var margin = 160;
    menuCamera.deadzone.set(0, margin, menuCamera.width, menuCamera.height - margin * 2);
    menuCamera.minScrollY = 0;

    items.onChange.add(function(selected)
    {
      itemDesc.text = preferenceDesc[items.selectedIndex];
      updateNovaBeatRows();
    });

    #if FEATURE_TOUCH_CONTROLS
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
    add(backButton);
    #end
  }

  /**
   * Create the description for preferences.
   */
  function createPrefDescription():Void
  {
    itemDesc.text = preferenceDesc[items.selectedIndex];
    itemDesc.scrollFactor.set();

    if (novaBeatStyle)
    {
      var margin:Float = Math.max(20, FlxG.width * 0.035);
      itemDescBox.makeSolidColor(1, 1, 0xFF0D1935);
      itemDescBox.alpha = 0.96;
      itemDesc.setFormat(Paths.font('vcr.ttf'), 13, 0xFFB7C9E8, FlxTextAlign.LEFT);
      itemDesc.x = margin + 18;
      itemDesc.y = FlxG.height - 82;
      itemDesc.width = FlxG.width - margin * 2 - 36;
      itemDesc.height = 42;
      itemDesc.wordWrap = true;
      itemDesc.autoSize = false;
      itemDescBox.setPosition(margin + 10, FlxG.height - 94);
      itemDescBox.setGraphicSize(Std.int(FlxG.width - margin * 2 - 20), 64);
      itemDescBox.updateHitbox();
      return;
    }

    itemDescBox.makeSolidColor(1, 1, FlxColor.BLACK);
    itemDescBox.alpha = 0.6;
    itemDesc.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE,
      FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    itemDesc.borderSize = 3;
    itemDesc.screenCenter();
    itemDesc.y += 270;
    itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
    itemDescBox.setGraphicSize(Std.int(itemDesc.width + 20), Std.int(itemDesc.height + 25));
    itemDescBox.updateHitbox();
  }

  /**
   * Create the menu items for each of the preferences.
   */
  function createPrefItems():Void
  {
    createPrefItemEnum('Menu Style', 'Choose the main-menu presentation. The matching menu soundtrack switches immediately; the selected layout is used when you return to the main menu.', [
      "Original FNF" => "Original FNF",
      "NovaBeat" => "NovaBeat"
    ], function(key:String, value:String):Void
    {
      var previousStyle:String = Preferences.menuStyle;
      Preferences.menuStyle = value;

      // Re-enter the title flow with the selected presentation. This refreshes
      // the complete menu immediately without restarting the game.
      if (previousStyle != value)
      {
        if (value == "Original FNF")
        {
          var startedTrack:Bool = FunkinSound.playMusic('freakyMenu', {
            startingVolume: 0.0,
            overrideExisting: true,
            restartTrack: false,
            persist: true,
            mapTimeChanges: false
          });
          if (startedTrack && FlxG.sound.music != null)
            FlxG.sound.music.fadeIn(0.45, 0.0, 0.82);
        }

        FlxG.switchState(() -> new TitleState());
      }
    }, Preferences.menuStyle);

  #if FEATURE_NAUGHTYNESS
    createPrefItemCheckbox('Naughtyness', 'When enabled, raunchy content (such as swearing, etc.) is displayed.', function(value:Bool):Void
    {
      Preferences.naughtyness = value;
    }, Preferences.naughtyness);
    #end
    createPrefItemCheckbox('Downscroll', 'When enabled, notes move downwards toward the strumline at the bottom of the screen.', function(value:Bool):Void
    {
      Preferences.downscroll = value;
    },
      Preferences.downscroll, #if mobile ControlsHandler.hasExternalInputDevice
      || Preferences.controlsScheme != FunkinHitboxControlSchemes.Arrows #end);
    createPrefItemPercentage('Strumline Background', 'Show a semi-transparent background behind the strumline.', function(value:Int):Void
    {
      Preferences.strumlineBackgroundOpacity = value;
    }, Preferences.strumlineBackgroundOpacity);
    #if FEATURE_HAPTICS
    createPrefItemEnum('Haptics', 'When enabled, the game plays haptic feedback effects.', [
      "All" => HapticsMode.ALL,
      "Notes Only" => HapticsMode.NOTES_ONLY,
      "None" => HapticsMode.NONE,
    ], function(key:String, value:HapticsMode):Void
    {
      Preferences.hapticsMode = value;
    }, switch (Preferences.hapticsMode)
      {
        case HapticsMode.NOTES_ONLY:
          "Notes Only";
        case HapticsMode.NONE:
          "None";
        default:
          "All";
      });
    createPrefItemNumber('Haptics Intensity', 'Intensity multiplier for all haptic feedback effects.', function(value:Float)
    {
      Preferences.hapticsIntensityMultiplier = value;
    }, null, Preferences.hapticsIntensityMultiplier, 0.1, 5, 0.1, 1);
    #end
    createPrefItemCheckbox('Flashing Lights', 'When disabled, flashing effects are dampened. Useful for people with photosensitive epilepsy.',
      function(value:Bool):Void
      {
        Preferences.flashingLights = value;
      }, Preferences.flashingLights);
    createPrefItemCheckbox('Camera Zooms', 'When enabled, the camera bounces during songs.', function(value:Bool):Void
    {
      Preferences.zoomCamera = value;
    }, Preferences.zoomCamera);
    createPrefItemCheckbox('Subtitles', 'When enabled, subtitles appear during some songs and cutscenes.', function(value:Bool):Void
    {
      Preferences.subtitles = value;
    }, Preferences.subtitles);
    #if FEATURE_DEBUG_DISPLAY
    // note: technically we can do DebugDisplayMode.Advanced => DebugDisplayMode.Advanced, etc. here, but that's a bit headache inducing.
    createPrefItemEnum('Debug Display', 'When enabled, FPS and other debug stats are displayed.', [
      "Advanced" => DebugDisplayMode.Advanced,
      "Simple" => DebugDisplayMode.Simple,
      "Off" => DebugDisplayMode.Off
    ], (key:String, value:DebugDisplayMode) ->
      {
        Preferences.debugDisplay = value;
      }, Preferences.debugDisplay);
    createPrefItemPercentage('Debug Display BG', "Adjust the debug display's background opacity.", function(value:Int):Void
    {
      Preferences.debugDisplayBGOpacity = value;
    }, Preferences.debugDisplayBGOpacity);
    #end
    #if !mobile
    createPrefItemCheckbox('Pause on Unfocus', 'When enabled, the game automatically pauses when losing focus.', function(value:Bool):Void
    {
      Preferences.autoPause = value;
    }, Preferences.autoPause);
    createPrefItemCheckbox('Launch in Fullscreen', 'When enabled, the game automatically starts up in fullscreen mode.', function(value:Bool):Void
    {
      Preferences.autoFullscreen = value;
    }, Preferences.autoFullscreen);
    #end

    // disable on mobile and web since it barely has any effect
    #if !(mobile || web)
    createPrefItemEnum('VSync', "When enabled, the game attempts to match the framerate with your monitor's refresh rate.", [
      "Off" => WindowVSyncMode.OFF,
      "On" => WindowVSyncMode.ON,
      "Adaptive" => WindowVSyncMode.ADAPTIVE,
    ], function(key:String, value:WindowVSyncMode):Void
    {
      trace("Setting vsync mode to " + key);
      Preferences.vsyncMode = value;
    }, switch (Preferences.vsyncMode)
      {
        case WindowVSyncMode.OFF:
          "Off";
        case WindowVSyncMode.ON:
          "On";
        case WindowVSyncMode.ADAPTIVE:
          "Adaptive";
      });
    createPrefItemCheckbox('Unlocked Framerate', 'When enabled, the framerate is unlocked.\nThis setting is mutually exclusive with FPS.',
      function(value:Bool):Void
      {
        Preferences.unlockedFramerate = value;
      }, Preferences.unlockedFramerate);
    createPrefItemNumber('FPS', 'The maximum framerate that the game targets.\nThis setting is mutually exclusive with Unlocked Framerate.',
      function(value:Float)
      {
        Preferences.framerate = Std.int(value);
      }, null, Preferences.framerate, 30, 500, 5, 0);
    #end

    #if FEATURE_SCREENSHOTS
    createPrefItemCheckbox('Hide Mouse', 'When enabled, the mouse is hidden while taking a screenshot.', function(value:Bool):Void
    {
      Preferences.shouldHideMouse = value;
    }, Preferences.shouldHideMouse);
    createPrefItemCheckbox('Fancy Preview', 'When enabled, a preview is shown after taking a screenshot.', function(value:Bool):Void
    {
      Preferences.fancyPreview = value;
    }, Preferences.fancyPreview);
    createPrefItemCheckbox('Preview on Save', 'When enabled, the preview is only shown after a screenshot is saved.', function(value:Bool):Void
    {
      Preferences.previewOnSave = value;
    }, Preferences.previewOnSave);
    #end

    #if FEATURE_DISCORD_RPC
    createPrefItemCheckbox('Discord RPC', 'Toggles Discord RPC.', function(value:Bool):Void
    {
      Preferences.enabledDiscordRPC = value;
    }, Preferences.enabledDiscordRPC);
    #end
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    // Positions the camera to the selected item.
    if (items != null && items.selectedItem != null) camFollow.y = items.selectedItem.y;

    if (novaBeatStyle)
    {
      updateNovaBeatRows();
      return;
    }

    // Indent the selected item.
    items.forEach(function(daItem:TextMenuItem)
    {
      var thyOffset:Int = 0;
      // Initializing thy text width (if thou text present)
      var thyTextWidth:Int = 0;
      switch (Type.typeof(daItem))
      {
        case TClass(CheckboxPreferenceItem):
          thyTextWidth = 0;
          thyOffset = 0;
        case TClass(EnumPreferenceItem):
          thyTextWidth = cast(daItem, EnumPreferenceItem<Dynamic>).lefthandText.getWidth();
          thyOffset = 0 + thyTextWidth - 75;
        case TClass(NumberPreferenceItem):
          thyTextWidth = cast(daItem, NumberPreferenceItem).lefthandText.getWidth();
          thyOffset = 0 + thyTextWidth - 75;
        default:
          // Huh?
      }

      if (items.selectedItem == daItem)
      {
        thyOffset += 150;
      }
      else
      {
        thyOffset += 120;
      }

      daItem.x = thyOffset + funkin.ui.FullScreenScaleMode.gameNotchSize.x;
    });
  }

  // - Preference item creation methods -
  // Should be moved into a separate PreferenceItems class but you can't access PreferencesMenu.items and PreferencesMenu.preferenceItems from outside.

  /**
   * Creates a pref item that works with booleans
   * @param onChange Gets called every time the player changes the value; use this to apply the value
   * @param defaultValue The value that is loaded in when the pref item is created (usually your Preferences.settingVariable)
   */
  function createPrefItemCheckbox(prefName:String, prefDesc:String, onChange:Bool->Void, defaultValue:Bool, available:Bool = true):Void
  {
    var itemY:Float = preferenceItemY(items.length);
    var checkbox:CheckboxPreferenceItem = new CheckboxPreferenceItem(funkin.ui.FullScreenScaleMode.gameNotchSize.x, itemY - 30,
      defaultValue, available);

    var item:TextMenuItem = items.createItem(0, itemY, prefName, AtlasFont.BOLD, function()
    {
      var value = !checkbox.currentValue;
      onChange(value);
      checkbox.currentValue = value;
    }, false, available);

    preferenceItems.add(checkbox);
    preferenceDesc.push(prefDesc);

    if (novaBeatStyle)
    {
      var index:Int = items.length - 1;
      styleNovaBeatPreferenceItem(item, prefName, index);
      var rowX:Float = novaBeatRowX();
      var rowW:Float = novaBeatRowWidth();
      var rowY:Float = novaBeatRowY(index);
      checkbox.x = rowX + rowW - checkbox.width - 22;
      checkbox.y = rowY + (54 - checkbox.height) * 0.5;
      checkbox.color = 0xFF48E7FF;
    }
  }

  /**
   * Creates a pref item that works with general numbers
   * @param onChange Gets called every time the player changes the value; use this to apply the value
   * @param valueFormatter Will get called every time the game needs to display the float value; use this to change how the displayed value looks
   * @param defaultValue The value that is loaded in when the pref item is created (usually your Preferences.settingVariable)
   * @param min Minimum value (example: 0)
   * @param max Maximum value (example: 10)
   * @param step The value to increment/decrement by (default = 0.1)
   * @param precision Rounds decimals up to a `precision` amount of digits (ex: 4 -> 0.1234, 2 -> 0.12)
   */
  function createPrefItemNumber(prefName:String, prefDesc:String, onChange:Float->Void, ?valueFormatter:Float->String, defaultValue:Float, min:Float,
      max:Float, step:Float = 0.1, precision:Int):Void
  {
    var item = new NumberPreferenceItem(funkin.ui.FullScreenScaleMode.gameNotchSize.x, preferenceItemY(items.length), prefName, defaultValue, min, max, step,
      precision, onChange, valueFormatter);
    items.addItem(prefName, item);
    preferenceItems.add(item.lefthandText);
    preferenceDesc.push(prefDesc);
    if (novaBeatStyle)
    {
      var index:Int = items.length - 1;
      styleNovaBeatPreferenceItem(item, prefName, index);
      item.lefthandText.x = novaBeatRowX() + novaBeatRowWidth() - 190;
      item.lefthandText.y = novaBeatRowY(index) + 15;
      item.lefthandText.color = 0xFF48E7FF;
    }
  }

  /**
   * Creates a pref item that works with number percentages
   * @param onChange Gets called every time the player changes the value; use this to apply the value
   * @param defaultValue The value that is loaded in when the pref item is created (usually your Preferences.settingVariable)
   * @param min Minimum value (default = 0)
   * @param max Maximum value (default = 100)
   */
  function createPrefItemPercentage(prefName:String, prefDesc:String, onChange:Int->Void, defaultValue:Int, min:Int = 0, max:Int = 100):Void
  {
    var newCallback = function(value:Float)
    {
      onChange(Std.int(value));
    };
    var formatter = function(value:Float)
    {
      return '${value}%';
    };
    var item = new NumberPreferenceItem(funkin.ui.FullScreenScaleMode.gameNotchSize.x, preferenceItemY(items.length), prefName, defaultValue, min, max, 10, 0,
      newCallback, formatter);
    items.addItem(prefName, item);
    preferenceItems.add(item.lefthandText);
    preferenceDesc.push(prefDesc);
    if (novaBeatStyle)
    {
      var index:Int = items.length - 1;
      styleNovaBeatPreferenceItem(item, prefName, index);
      item.lefthandText.x = novaBeatRowX() + novaBeatRowWidth() - 190;
      item.lefthandText.y = novaBeatRowY(index) + 15;
      item.lefthandText.color = 0xFF48E7FF;
    }
  }

  /**
   * Creates a pref item that works with enums
   * @param values Maps enum values to display strings _(ex: `NoteHitSoundType.PingPong => "Ping pong"`)_
   * @param onChange Gets called every time the player changes the value; use this to apply the value
   * @param defaultValue The value that is loaded in when the pref item is created (usually your Preferences.settingVariable)
   */
  function createPrefItemEnum<T>(prefName:String, prefDesc:String, values:Map<String, T>, onChange:String->T->Void, defaultKey:String):Void
  {
    var item = new EnumPreferenceItem<T>(funkin.ui.FullScreenScaleMode.gameNotchSize.x, preferenceItemY(items.length), prefName, values, defaultKey, onChange);
    items.addItem(prefName, item);
    preferenceItems.add(item.lefthandText);
    preferenceDesc.push(prefDesc);
    if (novaBeatStyle)
    {
      var index:Int = items.length - 1;
      styleNovaBeatPreferenceItem(item, prefName, index);
      item.lefthandText.x = novaBeatRowX() + novaBeatRowWidth() - 190;
      item.lefthandText.y = novaBeatRowY(index) + 15;
      item.lefthandText.color = 0xFF48E7FF;
    }
  }

  function novaBeatRowX():Float
  {
    return Math.max(20, FlxG.width * 0.035) + 18;
  }

  function novaBeatRowWidth():Float
  {
    return FlxG.width - Math.max(20, FlxG.width * 0.035) * 2 - 36;
  }

  function novaBeatRowY(index:Int):Float
  {
    return 84 + index * 62;
  }

  function styleNovaBeatPreferenceItem(item:TextMenuItem, prefName:String, index:Int):Void
  {
    var rowX:Float = novaBeatRowX();
    var rowY:Float = novaBeatRowY(index);
    var rowW:Float = novaBeatRowWidth();

    var background:FunkinSprite = new FunkinSprite(rowX, rowY);
    background.makeSolidColor(Std.int(rowW), 54, 0xFF0D1935);
    background.cameras = [menuCamera];
    novaBeatRowLayer.add(background);
    novaBeatRowBackgrounds.push(background);

    var accent:FunkinSprite = new FunkinSprite(rowX, rowY + 7);
    accent.makeSolidColor(4, 40, 0xFF48E7FF);
    accent.cameras = [menuCamera];
    novaBeatRowLayer.add(accent);
    novaBeatRowAccents.push(accent);

    var label:FlxText = new FlxText(rowX + 18, rowY + 17, rowW - 230, prefName, 15);
    label.setFormat(Paths.font('vcr.ttf'), 15, 0xFFB9C8E3, FlxTextAlign.LEFT);
    label.cameras = [menuCamera];
    novaBeatLabelLayer.add(label);
    novaBeatRowLabels.push(label);

    item.x = rowX + 8;
    item.y = rowY + 5;
    item.makeGraphic(Std.int(rowW - 16), 44, FlxColor.TRANSPARENT);
    item.updateHitbox();
    item.atlasText.visible = false;
  }

  function updateNovaBeatRows():Void
  {
    for (index in 0...novaBeatRowBackgrounds.length)
    {
      var selected:Bool = index == items.selectedIndex;
      novaBeatRowBackgrounds[index].color = selected ? 0xFF123B5C : 0xFF0D1935;
      novaBeatRowBackgrounds[index].alpha = selected ? 1.0 : 0.82;
      novaBeatRowAccents[index].alpha = selected ? 1.0 : 0.42;
      novaBeatRowLabels[index].color = selected ? FlxColor.WHITE : 0xFFB9C8E3;
    }
  }

  function preferenceItemY(index:Int):Float
  {
    return novaBeatStyle ? novaBeatRowY(index) + 5 : 30 + index * 120;
  }

  override function exit():Void
  {
    camFollow.setPosition(640, 30);
    menuCamera.snapToTarget();
    super.exit();
  }
}
