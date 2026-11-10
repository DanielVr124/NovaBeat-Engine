package funkin.ui.options;

import funkin.ui.Page.PageName;
import funkin.ui.transition.LoadingState;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import flixel.FlxG;
import flixel.math.FlxPoint;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.util.FlxSignal;
import funkin.audio.FunkinSound;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.graphics.shaders.HSVShader;
import funkin.input.Controls;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end
#if (mobile || FEATURE_TOUCH_CONTROLS)
import funkin.util.TouchUtil;
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.ui.options.ControlsSchemeMenu;
#end
import funkin.util.DeviceUtil;
#if FEATURE_MOBILE_IAP
import funkin.mobile.util.InAppPurchasesUtil;
#end
import flixel.util.FlxColor;

/**
 * The main options menu
 * It mainly is controlled via the "optionsCodex" object,
 * which handles paging and going to the different submenus
 */
class OptionsState extends MusicBeatState
{
  /**
   * Instance of the OptionsState
   */
  public static var instance:OptionsState;

  var optionsCodex:Codex<OptionsMenuPageName>;

  public var drumsBG:FunkinSound;
  var menuBackground:Null<FlxSprite> = null;

  public static var rememberedSelectedIndex:Int = 0;

  override function create():Void
  {
    instance = this;

    persistentUpdate = true;

    drumsBG = FunkinSound.load(Paths.music('offsetsLoop/drumsLoop'), 0, true, false, false, false);

    var menuBG = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    menuBackground = menuBG;
    var hsv = new HSVShader(-0.6, 0.9, 3.6);
    menuBG.shader = hsv;
    menuBG.setGraphicSize(Std.int(FlxG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

    optionsCodex = new Codex<OptionsMenuPageName>(Options);
    add(optionsCodex);

    var options:OptionsMenu = optionsCodex.addPage(Options, new OptionsMenu());
    var preferences:PreferencesMenu = optionsCodex.addPage(Preferences, new PreferencesMenu());
    var controls:ControlsMenu = optionsCodex.addPage(Controls, new ControlsMenu());
    #if FEATURE_LAG_ADJUSTMENT
    var offsets:OffsetMenu = optionsCodex.addPage(Offsets, new OffsetMenu());
    #end
    var saveData:SaveDataMenu = optionsCodex.addPage(SaveData, new SaveDataMenu());
    var customization:CustomizationMenu = optionsCodex.addPage(Customization, new CustomizationMenu());
    var performance:PerformanceCustomizationMenu = optionsCodex.addPage(Performance, new PerformanceCustomizationMenu());
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var mobileCustomization:MobileCustomizationMenu = optionsCodex.addPage(Mobile, new MobileCustomizationMenu());
    #end


    options.addSaveDataOptionsItem(saveData);
    options.addExitItem();

    if (options.hasMultipleOptions())
    {
      options.onExit.add(exitToMainMenu);
      controls.onExit.add(exitControls);
      preferences.onExit.add(optionsCodex.switchPage.bind(Options));
      #if FEATURE_LAG_ADJUSTMENT
      offsets.onExit.add(exitOffsets);
      #end
      saveData.onExit.add(optionsCodex.switchPage.bind(Options));
      customization.onExit.add(optionsCodex.switchPage.bind(Options));
      performance.onExit.add(optionsCodex.switchPage.bind(Customization));
      #if (mobile || FEATURE_TOUCH_CONTROLS)
      mobileCustomization.onExit.add(optionsCodex.switchPage.bind(Customization));
      #end

    }
    else
    {
      // No need to show Options page
      #if (mobile || FEATURE_TOUCH_CONTROLS)
      if (DeviceUtil.isMobileBrowser)
      {
        preferences.onExit.add(exitToMainMenu);
        optionsCodex.setPage(Preferences);
      }
      else
      {
        controls.onExit.add(exitToMainMenu);
        optionsCodex.setPage(Controls);
      }
      #else
      controls.onExit.add(exitToMainMenu);
      optionsCodex.setPage(Controls);
      #end
    }

    super.create();

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (DeviceUtil.isMobileBrowser)
    {
      addHitbox();
      hitbox.visible = false;
    }
    #end
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    if (menuBackground != null)
    {
      menuBackground.setGraphicSize(Std.int(width * 1.1));
      menuBackground.updateHitbox();
      menuBackground.screenCenter();
    }
  }

  function exitOffsets():Void
  {
    if (drumsBG.volume > 0)
    {
      drumsBG.fadeOut(0.5, 0);
    }
    FlxG.sound.music.fadeOut(0.5, 0, function(tw)
    {
      FunkinSound.playMusic('freakyMenu', {
        startingVolume: 0,
        overrideExisting: true,
        restartTrack: true,
        persist: true,
        mapTimeChanges: false
      });
      FlxG.sound.music.fadeIn(0.5, 1);
    });
    optionsCodex.switchPage(Options);
  }

  function exitControls():Void
  {
    // Apply any changes to the controls.
    PlayerSettings.reset();
    PlayerSettings.init();

    optionsCodex.switchPage(Options);
  }

  function exitToMainMenu():Void
  {
    optionsCodex.currentPage.enabled = false;
    // TODO: Animate this transition?
    FlxG.keys.enabled = false;
    FlxG.switchState(() -> new MainMenuState());
  }
}

/**
 * Our default Page when we enter the OptionsState, a bit of the root
 */
class OptionsMenu extends Page<OptionsMenuPageName>
{
  var items:TextMenuList;
  #if FEATURE_TOUCH_CONTROLS
  var backButton:FunkinBackButton;
  var goingBack:Bool = false;
  #end

  var camFocusPoint:FlxObject;
  final CAMERA_MARGIN:Int = 150;

  public function new()
  {
    super();

    add(items = new TextMenuList());
    // FNF options/submenus should activate on the first mobile tap rather
    // than requiring a select-then-confirm double tap.
    items.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;

    createItem('PREFERENCES', function() codex.switchPage(Preferences));
    createItem('CUSTOMIZATION', function() codex.switchPage(Customization));
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (!DeviceUtil.isMobileBrowser || ControlsHandler.hasExternalInputDevice)
    #end
    createItem('CONTROLS', function() codex.switchPage(Controls));
    #if FEATURE_LAG_ADJUSTMENT
    createItem('LAG ADJUSTMENT', function()
    {
      var switchToOffsets = function()
      {
        FunkinSound.playMusic('offsetsLoop', {
          startingVolume: 0,
          overrideExisting: true,
          restartTrack: true,
          loop: true
        });
        OptionsState.instance.drumsBG.play(true);
        FlxG.sound.music.fadeIn(1, 1);
        codex.switchPage(Offsets);
      };

      if (FlxG.sound.music != null)
      {
        FlxG.sound.music.fadeOut(0.5, 0, function(tw)
        {
          switchToOffsets();
        });
      }
      else
      {
        switchToOffsets();
      }
    });
    #end
    #if FEATURE_MOBILE_IAP
    createItem('RESTORE PURCHASES', function()
    {
      InAppPurchasesUtil.restorePurchases();
    });
    #end
    #if android
    createItem('OPEN DATA FOLDER', function()
    {
      funkin.external.android.DataFolderUtil.openDataFolder();
    });
    #end
    #if FEATURE_NEWGROUNDS
    if (NewgroundsClient.instance.isLoggedIn())
    {
      createItem('LOGOUT OF NG', function()
      {
        NewgroundsClient.instance.logout(function()
        {
          FlxG.resetState();
        }, function()
        {
          FlxG.log.warn('Newgrounds logout failed!');
        });
      });
    }
    else
    {
      createItem('LOGIN TO NG', function()
      {
        NewgroundsClient.instance.login(function()
        {
          FlxG.resetState();
        }, function()
        {
          FlxG.log.warn('Newgrounds login failed!');
        });
      });
    }
    #end

    camFocusPoint = new FlxObject(0, 0, 140, 70);
    add(camFocusPoint);

    #if FEATURE_TOUCH_CONTROLS
    FlxG.touches.swipeThreshold.y = 100;
    #end
  }

  public function addSaveDataOptionsItem(saveDataMenu:SaveDataMenu):Void
  {
    if (saveDataMenu.hasMultipleOptions())
    {
      createItem('SAVE DATA OPTIONS', function()
      {
        codex.switchPage(SaveData);
      });
    }
    else
    {
      createItem('CLEAR SAVE DATA', saveDataMenu.openSaveDataPrompt);
    }
  }

  public function addExitItem():Void
  {
    #if NO_FEATURE_TOUCH_CONTROLS
    createItem('EXIT', exit);
    #else
    if (DeviceUtil.isMobileBrowser)
    {
      backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
      backButton.onConfirmStart.add(function()
      {
        items.busy = true;
        goingBack = true;
        backButton.active = true;
      });
      add(backButton);
    }
    else
    {
      createItem('EXIT', exit);
    }
    #end
  }

  function onMenuChange(selected:TextMenuItem):Void
  {
    camFocusPoint.y = selected.y;
  }

  function createItem(name:String, callback:Void->Void, fireInstantly = false):TextMenuItem
  {
    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;

    // Keep the original FNF Options list centered and vertically spaced on
    // both portrait and landscape viewports.
    var portrait:Bool = height > width * 1.12;
    var startY:Float = portrait ? height * 0.19 : 100;
    var gap:Float = portrait ? Math.min(78, (height * 0.60) / Math.max(1, items.length)) : 100;
    for (index in 0...items.members.length)
    {
      var item:TextMenuItem = items.members[index];
      item.y = startY + index * gap;
      item.x = 0;
      item.screenCenter(X);
    }
    if (camFocusPoint != null && items.selectedItem != null) camFocusPoint.y = items.selectedItem.y;
    FlxG.camera.deadzone.set(0, portrait ? height * 0.16 : CAMERA_MARGIN / 2,
      width, portrait ? height * 0.66 : height - CAMERA_MARGIN + 40);

    #if FEATURE_TOUCH_CONTROLS
    if (backButton != null)
      backButton.setPosition(width - backButton.width - 18, height - backButton.height - 18);
    #end
  }

  override function update(elapsed:Float):Void
  {
    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    #if FEATURE_TOUCH_CONTROLS
    if (backButton != null) backButton.active = (!goingBack) ? !items.busy : true;
    #end
    super.update(elapsed);
  }

  override function set_enabled(value:Bool):Bool
  {
    items.enabled = value;
    return super.set_enabled(value);
  }

  public function hasMultipleOptions():Bool
  {
    return items.length > 2;
  }
}

enum abstract OptionsMenuPageName(String) to PageName
{
  public var Options = 'options';
  public var Controls = 'controls';
  public var Colors = 'colors';
  public var Customization = 'customization';
  public var Performance = 'performance';
  #if (mobile || FEATURE_TOUCH_CONTROLS)
  public var Mobile = 'mobileCustomization';
  #end

  public var Preferences = 'preferences';
  public var Offsets = 'offsets';
  public var SaveData = 'saveData';
}
