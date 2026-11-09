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
  var backgroundDimmer:Null<FlxSprite> = null;
  var isNovaBeatStyle:Bool = false;

  public static var rememberedSelectedIndex:Int = 0;

  override function create():Void
  {
    instance = this;

    persistentUpdate = true;

    drumsBG = FunkinSound.load(Paths.music('offsetsLoop/drumsLoop'), 0, true, false, false, false);

    var novaBeatStyle:Bool = funkin.Preferences.menuStyle == "NovaBeat";
    isNovaBeatStyle = novaBeatStyle;
    var menuBG = new FlxSprite().loadGraphic(Paths.image(novaBeatStyle ? 'novabeat/menu-background' : 'menuBG'));
    menuBackground = menuBG;
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
      backgroundDimmer = dimmer;
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
    var customization:CustomizationMenu = optionsCodex.addPage(Customization, new CustomizationMenu());
    var menuCustomization:MenuCustomizationMenu = optionsCodex.addPage(MenuCustomization, new MenuCustomizationMenu());
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
      menuCustomization.onExit.add(optionsCodex.switchPage.bind(Customization));
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

    if (novaBeatStyle)
    {
      FunkinSound.playMusic('novabeat-menu', {
        overrideExisting: true,
        restartTrack: false,
        persist: true,
        mapTimeChanges: false
      });
    }

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
      if (isNovaBeatStyle)
      {
        var scale:Float = Math.max(width / Math.max(1, menuBackground.frameWidth), height / Math.max(1, menuBackground.frameHeight));
        menuBackground.scale.set(scale, scale);
      }
      else menuBackground.setGraphicSize(Std.int(width * 1.1));
      menuBackground.updateHitbox();
      menuBackground.screenCenter();
    }
    if (backgroundDimmer != null)
    {
      backgroundDimmer.makeGraphic(width, height, 0x99040A1A);
      backgroundDimmer.setPosition(0, 0);
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
      FunkinSound.playMusic(funkin.Preferences.menuStyle == "NovaBeat" ? 'novabeat-menu' : 'freakyMenu', {
        startingVolume: 0,
        overrideExisting: true,
        restartTrack: funkin.Preferences.menuStyle != "NovaBeat",
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

  var novaBeatLayout:Bool = false;
  var novaBeatListX:Float = 0;
  var novaBeatListY:Float = 0;
  var novaBeatListWidth:Float = 0;
  var novaBeatRowHeight:Float = 52;
  var novaBeatDescription:Null<FlxText> = null;
  var novaBeatRowBackgrounds:Array<FlxSprite> = [];
  var novaBeatRowAccents:Array<FlxSprite> = [];
  var novaBeatRowLabels:Array<FlxText> = [];

  public function new()
  {
    super();

    novaBeatLayout = funkin.Preferences.menuStyle == "NovaBeat";
    if (novaBeatLayout) buildNovaBeatLayout();

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

    if (novaBeatLayout)
    {
      items.onChange.add(updateNovaBeatSelection);
      layoutNovaBeatItems();
      items.selectItem(0);
      updateNovaBeatSelection(items.members[0]);
    }
    else
    {
      FlxG.camera.follow(camFocusPoint, null, 0.085);
      FlxG.camera.deadzone.set(0, CAMERA_MARGIN / 2, FlxG.camera.width, FlxG.camera.height - CAMERA_MARGIN + 40);
      items.onChange.add(onMenuChange);
      onMenuChange(items.members[0]);
    }

    #if FEATURE_TOUCH_CONTROLS
    FlxG.touches.swipeThreshold.y = 100;
    #end
  }

  function buildNovaBeatLayout():Void
  {
    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    var margin:Float = Math.max(20, width * 0.045);
    var panelTop:Float = 96;
    var panelHeight:Float = Math.max(170, height - 124);
    var compactLayout:Bool = width < 950 || height > width * 1.12;

    if (compactLayout)
    {
      var panel:FlxSprite = new FlxSprite(margin, panelTop);
      panel.makeGraphic(Std.int(width - margin * 2), Std.int(panelHeight), 0xC9091833);
      add(panel);

      var brand:FlxText = new FlxText(margin + 20, 18, width - margin * 2 - 40, 'NOVABEAT ENGINE', 11);
      brand.setFormat(Paths.font('vcr.ttf'), 11, 0xFF48E7FF);
      add(brand);

      var heading:FlxText = new FlxText(margin + 20, 42, width - margin * 2 - 40, 'OPTIONS', 27);
      heading.setFormat(Paths.font('vcr.ttf'), 27, FlxColor.WHITE);
      add(heading);

      var intro:FlxText = new FlxText(margin + 22, panelTop + 16, width - margin * 2 - 44,
        'SELECT A SECTION', 11);
      intro.setFormat(Paths.font('vcr.ttf'), 11, 0xFF48E7FF);
      add(intro);

      novaBeatDescription = new FlxText(margin + 22, panelTop + 42, width - margin * 2 - 44,
        'Choose a section to adjust preferences, controls, and the NovaBeat presentation.', 11);
      novaBeatDescription.setFormat(Paths.font('vcr.ttf'), 11, 0xFFB7C9E8);
      novaBeatDescription.visible = false;
      novaBeatDescription.wordWrap = true;
      novaBeatDescription.autoSize = false;
      add(novaBeatDescription);

      novaBeatListX = margin + 16;
      novaBeatListY = panelTop + 102;
      novaBeatListWidth = width - margin * 2 - 32;

      var footer:FlxText = new FlxText(margin + 20, height - 28, width - margin * 2 - 40,
        'UP / DOWN SELECT   •   ENTER OPEN   •   ESC BACK', 9);
      footer.setFormat(Paths.font('vcr.ttf'), 9, 0xFF8297C2);
      add(footer);
    }
    else
    {
      var leftWidth:Float = width * 0.36;
      var rightX:Float = width * 0.435;
      var rightWidth:Float = width * 0.515;

      var leftPanel:FlxSprite = new FlxSprite(margin, panelTop);
      leftPanel.makeGraphic(Std.int(leftWidth), Std.int(panelHeight), 0xC9091833);
      add(leftPanel);

      var rightPanel:FlxSprite = new FlxSprite(rightX, panelTop);
      rightPanel.makeGraphic(Std.int(rightWidth), Std.int(panelHeight), 0xC9091833);
      add(rightPanel);

      var brand:FlxText = new FlxText(margin + 28, 25, leftWidth - 48, 'NOVABEAT ENGINE', 12);
      brand.setFormat(Paths.font('vcr.ttf'), 12, 0xFF48E7FF);
      add(brand);

      var heading:FlxText = new FlxText(margin + 28, 54, leftWidth - 48, 'OPTIONS', 34);
      heading.setFormat(Paths.font('vcr.ttf'), 34, FlxColor.WHITE);
      add(heading);

      var intro:FlxText = new FlxText(margin + 28, panelTop + 34, leftWidth - 56,
        'MAKE THE GAME FEEL RIGHT.', 15);
      intro.setFormat(Paths.font('vcr.ttf'), 15, 0xFF48E7FF);
      add(intro);

      novaBeatDescription = new FlxText(margin + 28, panelTop + 84, leftWidth - 56,
        'Choose a section to adjust preferences, controls, and the NovaBeat presentation.', 15);
      novaBeatDescription.setFormat(Paths.font('vcr.ttf'), 15, 0xFFB7C9E8);
      novaBeatDescription.visible = false;
      novaBeatDescription.wordWrap = true;
      novaBeatDescription.autoSize = false;
      add(novaBeatDescription);

      var footer:FlxText = new FlxText(margin + 28, panelTop + panelHeight - 55, leftWidth - 56,
        'UP / DOWN   SELECT\nENTER   OPEN   •   ESC   BACK', 11);
      footer.setFormat(Paths.font('vcr.ttf'), 11, 0xFF8297C2);
      add(footer);

      novaBeatListX = rightX + 24;
      novaBeatListY = panelTop + 26;
      novaBeatListWidth = rightWidth - 48;
    }

    novaBeatRowHeight = 52;
  }

  function layoutNovaBeatItems():Void
  {
    if (!novaBeatLayout || items.length <= 0) return;

    var count:Int = items.length;
    var bottomReserve:Float = 30;
    novaBeatRowHeight = Math.min(58, (FlxG.height - novaBeatListY - bottomReserve) / count);
    novaBeatRowHeight = Math.max(30, novaBeatRowHeight);

    for (index in 0...count)
    {
      var y:Float = novaBeatListY + index * novaBeatRowHeight;
      var item:TextMenuItem = items.members[index];
      item.x = novaBeatListX + 8;
      item.y = y + 3;
      item.setGraphicSize(Std.int(novaBeatListWidth - 16), Std.int(novaBeatRowHeight - 6));
      item.updateHitbox();

      if (index < novaBeatRowBackgrounds.length)
      {
        novaBeatRowBackgrounds[index].x = novaBeatListX;
        novaBeatRowBackgrounds[index].y = y;
        novaBeatRowBackgrounds[index].setGraphicSize(Std.int(novaBeatListWidth), Std.int(novaBeatRowHeight - 5));
        novaBeatRowBackgrounds[index].updateHitbox();

        novaBeatRowAccents[index].x = novaBeatListX;
        novaBeatRowAccents[index].y = y + 7;
        novaBeatRowAccents[index].setGraphicSize(4, Std.int(novaBeatRowHeight - 19));
        novaBeatRowAccents[index].updateHitbox();

        novaBeatRowLabels[index].x = novaBeatListX + 20;
        novaBeatRowLabels[index].y = y + (novaBeatRowHeight - novaBeatRowLabels[index].height) * 0.5;
        novaBeatRowLabels[index].width = novaBeatListWidth - 42;
      }
    }
    updateNovaBeatRows();
  }

  function updateNovaBeatSelection(selected:TextMenuItem):Void
  {
    // Selection is conveyed by the highlighted row; NovaBeat does not show
    // a changing description block above the menu.
    updateNovaBeatRows();
  }

  function updateNovaBeatRows():Void
  {
    for (index in 0...novaBeatRowLabels.length)
    {
      var selected:Bool = index == items.selectedIndex;
      novaBeatRowBackgrounds[index].color = selected ? 0xFF123B5C : 0xFF0D1935;
      novaBeatRowBackgrounds[index].alpha = selected ? 1.0 : 0.78;
      novaBeatRowAccents[index].alpha = selected ? 1.0 : 0.36;
      novaBeatRowLabels[index].color = selected ? FlxColor.WHITE : 0xFFB9C8E3;
    }
  }

  function novaBeatDescriptionFor(name:String):String
  {
    return switch (name)
    {
      case 'PREFERENCES': 'Audio, gameplay, accessibility, and general engine preferences live here.';
      case 'CUSTOMIZATION': 'Open the customization categories for the NovaBeat menu and other menu styles.';
      case 'CONTROLS': 'View and remap your keyboard, controller, and supported input bindings.';
      case 'LAG ADJUSTMENT': 'Calibrate audio and visual timing to match your display and speakers.';
      case 'RESTORE PURCHASES': 'Restore supported purchases linked to your platform account.';
      case 'OPEN DATA FOLDER': 'Open the local game data folder to manage supported files.';
      case 'LOGIN TO NG': 'Connect to your Newgrounds account for supported online features.';
      case 'LOGOUT OF NG': 'Sign out of the currently connected Newgrounds account.';
      case 'SAVE DATA OPTIONS': 'Manage save slots and other save-data actions.';
      case 'CLEAR SAVE DATA': 'Clear the current save data after reviewing the confirmation prompt.';
      case 'EXIT': 'Return to the main menu.';
      default: 'Open this section to view its available settings.';
    };
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
    layoutNovaBeatItems();
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
    layoutNovaBeatItems();
  }

  function onMenuChange(selected:TextMenuItem):Void
  {
    camFocusPoint.y = selected.y;
  }

  function createItem(name:String, callback:Void->Void, fireInstantly = false):TextMenuItem
  {
    if (novaBeatLayout)
    {
      var index:Int = items.length;
      var y:Float = novaBeatListY + index * novaBeatRowHeight;
      var item:TextMenuItem = items.createItem(novaBeatListX + 8, y + 3, name, BOLD, callback);
      item.fireInstantly = fireInstantly;
      item.makeGraphic(Std.int(novaBeatListWidth - 16), Std.int(novaBeatRowHeight - 6), FlxColor.TRANSPARENT);
      item.updateHitbox();
      item.atlasText.visible = false;

      var rowBg:FlxSprite = new FlxSprite(novaBeatListX, y);
      rowBg.makeGraphic(Std.int(novaBeatListWidth), Std.int(novaBeatRowHeight - 5), 0xFF0D1935);
      add(rowBg);
      novaBeatRowBackgrounds.push(rowBg);

      var accent:FlxSprite = new FlxSprite(novaBeatListX, y + 7);
      accent.makeGraphic(4, Std.int(novaBeatRowHeight - 19), 0xFF48E7FF);
      add(accent);
      novaBeatRowAccents.push(accent);

      var fontSize:Int = Std.int(Math.max(11, Math.min(18, novaBeatRowHeight * 0.34)));
      var label:FlxText = new FlxText(novaBeatListX + 20, y + 8, novaBeatListWidth - 42, name, fontSize);
      label.setFormat(Paths.font('vcr.ttf'), fontSize, 0xFFB9C8E3, FlxTextAlign.LEFT);
      add(label);
      novaBeatRowLabels.push(label);

      layoutNovaBeatItems();
      return item;
    }

    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    if (novaBeatLayout)
    {
      var margin:Float = Math.max(18, width * 0.045);
      var panelTop:Float = 96;
      novaBeatListX = margin + 16;
      novaBeatListY = panelTop + (height > width * 1.12 ? 128 : 102);
      novaBeatListWidth = width - margin * 2 - 32;
      if (novaBeatDescription != null)
      {
        novaBeatDescription.x = margin + 22;
        novaBeatDescription.y = panelTop + 42;
        novaBeatDescription.fieldWidth = width - margin * 2 - 44;
        novaBeatDescription.size = height > width * 1.12 ? 10 : 12;
      }
      layoutNovaBeatItems();
    }
    else
    {
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
    }
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
  public var MenuCustomization = 'menuCustomization';
  public var Performance = 'performance';
  #if (mobile || FEATURE_TOUCH_CONTROLS)
  public var Mobile = 'mobileCustomization';
  #end

  public var Preferences = 'preferences';
  public var Offsets = 'offsets';
  public var SaveData = 'saveData';
}
