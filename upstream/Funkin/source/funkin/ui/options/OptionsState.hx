package funkin.ui.options;

import funkin.ui.Page.PageName;
import funkin.ui.transition.LoadingState;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import flixel.math.FlxPoint;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.util.FlxSignal;
import funkin.audio.FunkinSound;
import funkin.Preferences;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.graphics.shaders.HSVShader;
import funkin.input.Controls;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end
#if mobile
import funkin.util.TouchUtil;
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.ui.options.ControlsSchemeMenu;
#end
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

  public static var rememberedSelectedIndex:Int = 0;

  override function create():Void
  {
    instance = this;

    persistentUpdate = true;

    drumsBG = FunkinSound.load(Paths.music('offsetsLoop/drumsLoop'), 0, true, false, false, false);

    var novaBeatStyle:Bool = Preferences.menuStyle == "NovaBeat";
    var menuBG = new FlxSprite().loadGraphic(Paths.image(novaBeatStyle ? 'novabeat/menu-background' : 'menuBG'));
    if (novaBeatStyle)
    {
      var bgScale:Float = Math.max(FlxG.width / menuBG.width, FlxG.height / menuBG.height);
      menuBG.scale.set(bgScale, bgScale);
    }
    else
    {
      var hsv = new HSVShader(-0.6, 0.9, 3.6);
      menuBG.shader = hsv;
      menuBG.setGraphicSize(Std.int(FlxG.width * 1.1));
    }
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

    if (novaBeatStyle)
    {
      var dimmer:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99040A1A);
      dimmer.scrollFactor.set();
      add(dimmer);
    }

    optionsCodex = new Codex<OptionsMenuPageName>(Options);
    add(optionsCodex);

    var options:OptionsMenu = optionsCodex.addPage(Options, new OptionsMenu());
    var preferences:PreferencesMenu = optionsCodex.addPage(Preferences, new PreferencesMenu());
    var controls:ControlsMenu = optionsCodex.addPage(Controls, new ControlsMenu());
    #if FEATURE_LAG_ADJUSTMENT
    var offsets:OffsetMenu = optionsCodex.addPage(Offsets, new OffsetMenu());
    #end
    var saveData:SaveDataMenu = optionsCodex.addPage(SaveData, new SaveDataMenu());
    var menuCustomization:MenuCustomizationMenu = optionsCodex.addPage(MenuCustomization, new MenuCustomizationMenu());

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
      menuCustomization.onExit.add(optionsCodex.switchPage.bind(Options));
    }
    else
    {
      // No need to show Options page
      #if mobile
      preferences.onExit.add(exitToMainMenu);
      optionsCodex.setPage(Preferences);
      #else
      controls.onExit.add(exitToMainMenu);
      optionsCodex.setPage(Controls);
      #end
    }

    super.create();

    if (novaBeatStyle)
    {
      FunkinSound.playMusic('novabeat-menu', {
        overrideExisting: true,
        restartTrack: false,
        persist: true,
        mapTimeChanges: false
      });
    }

    #if mobile
    addHitbox();
    hitbox.visible = false;
    #end
  }

  function exitOffsets():Void
  {
    if (drumsBG.volume > 0)
    {
      drumsBG.fadeOut(0.5, 0);
    }
    FlxG.sound.music.fadeOut(0.5, 0, function(tw)
    {
      FunkinSound.playMusic(Preferences.menuStyle == "NovaBeat" ? 'novabeat-menu' : 'freakyMenu', {
        startingVolume: 0,
        overrideExisting: true,
        restartTrack: Preferences.menuStyle != "NovaBeat",
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

  /**
   * Camera focus point
   */
  var camFocusPoint:FlxObject;

  final CAMERA_MARGIN:Int = 150;

  public function new()
  {
    super();

    if (Preferences.menuStyle == "NovaBeat")
    {
      var margin:Float = FlxG.width * 0.055;
      var infoPanel:FlxSprite = new FlxSprite(margin, 92);
      infoPanel.makeGraphic(Std.int(FlxG.width * 0.37), Std.int(FlxG.height - 150), 0xC9091833);
      add(infoPanel);

      var brand:FlxText = new FlxText(margin + 28, 142, FlxG.width * 0.31, 'NOVABEAT ENGINE', 12);
      brand.setFormat(Paths.font('vcr.ttf'), 12, 0xFF48E7FF);
      add(brand);

      var heading:FlxText = new FlxText(margin + 28, 178, FlxG.width * 0.31, 'OPTIONS', 36);
      heading.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE);
      add(heading);

      var helper:FlxText = new FlxText(margin + 28, 238, FlxG.width * 0.30,
        'Fine-tune your game, controls, accessibility, and NovaBeat presentation.', 14);
      helper.setFormat(Paths.font('vcr.ttf'), 14, 0xFFB7C9E8);
      helper.wordWrap = true;
      add(helper);
    }

    add(items = new TextMenuList());

    createItem('PREFERENCES', function() codex.switchPage(Preferences));
    createItem('CUSTOMIZATION', function() codex.switchPage(MenuCustomization));
    #if mobile
    if (ControlsHandler.hasExternalInputDevice)
    #end
    createItem('CONTROLS', function() codex.switchPage(Controls));
    // createItem("CONTROL SCHEMES", function() {
    //   FlxG.state.openSubState(new ControlsSchemeMenu());
    // });
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
          // Reset the options menu when logout succeeds.
          // This means the login option will be displayed.
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
          // Reset the options menu when login succeeds.
          // This means the logout option will be displayed.
          // NOTE: If the user presses login and opens the browser,
          // then navigates the UI
          FlxG.resetState();
        }, function()
        {
          FlxG.log.warn('Newgrounds login failed!');
        });
      });
    }
    #end

    // Create an object for the camera to track.
    camFocusPoint = new FlxObject(0, 0, 140, 70);
    add(camFocusPoint);

    if (Preferences.menuStyle == "NovaBeat")
    {
      var startY:Float = Math.max(110, (FlxG.height - items.length * 62) * 0.5);
      for (index in 0...items.length)
      {
        var item:TextMenuItem = items.members[index];
        item.x = FlxG.width * 0.52;
        item.y = startY + index * 62;
        item.atlasText.color = 0xFFE4ECFF;
      }
    }
    else
    {
      // Follow the camera focus as we scroll for the original FNF options screen.
      FlxG.camera.follow(camFocusPoint, null, 0.085);
      FlxG.camera.deadzone.set(0, CAMERA_MARGIN / 2, FlxG.camera.width, FlxG.camera.height - CAMERA_MARGIN + 40);
      FlxG.camera.minScrollY = -CAMERA_MARGIN / 2;
      items.onChange.add(onMenuChange);
      onMenuChange(items.members[0]);
    }

    items.selectItem(OptionsState.rememberedSelectedIndex);
    #if FEATURE_TOUCH_CONTROLS
    FlxG.touches.swipeThreshold.y = 100;
    #end
  }

  public function addSaveDataOptionsItem(saveDataMenu:SaveDataMenu):Void
  {
    // no need to show an entire new menu for just one option
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
    backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
    backButton.onConfirmStart.add(function()
    {
      items.busy = true;
      goingBack = true;
      backButton.active = true;
    });
    add(backButton);
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

  override function update(elapsed:Float):Void
  {
    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    #if FEATURE_TOUCH_CONTROLS
    backButton.active = (!goingBack) ? !items.busy : true;
    #end
    super.update(elapsed);
  }

  override function set_enabled(value:Bool):Bool
  {
    items.enabled = value;
    return super.set_enabled(value);
  }

  /**
   * True if this page has multiple options, excluding the exit option.
   * If false, there's no reason to ever show this page.
   */
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
  public var MenuCustomization = 'menuCustomization';
  public var Preferences = 'preferences';
  public var Offsets = 'offsets';
  public var SaveData = 'saveData';
}
