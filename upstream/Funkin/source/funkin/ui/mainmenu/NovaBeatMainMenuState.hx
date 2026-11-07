package funkin.ui.mainmenu;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
import funkin.save.Save;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinCamera;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.MenuList.NavControls;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.MusicBeatState;
import funkin.ui.title.TitleState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.credits.CreditsState;
import funkin.ui.options.OptionsState;
import funkin.util.DeviceUtil;
import funkin.util.TouchUtil;
import funkin.util.TouchUtil;
import funkin.util.SwipeUtil;
#if (mobile || FEATURE_TOUCH_CONTROLS)
import funkin.util.SwipeUtil;
#end

/**
 * Native implementation of the original NovaBeat V4 menu presentation.
 *
 * This is intentionally not a reskinned FNF menu: it has its own title screen,
 * midnight-blue visual system, large two-column desktop layout, mobile tile
 * layout, custom logo/backdrop, and its own menu soundtrack and interface SFX.
 * The upstream FNF menu remains an independent style choice.
 */
class NovaBeatMainMenuState extends MusicBeatState
{
  static final ITEM_NAMES:Array<String> = [
    'STORY MODE',
    'FREEPLAY',
    'MODS',
    'OPTIONS',
    'CREDITS'
  ];

  static final ITEM_ICONS:Array<String> = ['▤', '♫', '✣', '⚙', '★'];

  static final ITEM_TITLES:Array<String> = [
    'STORY\nMODE',
    'FREEPLAY',
    'MODS',
    'OPTIONS',
    'CREDITS'
  ];

  static final ITEM_KICKERS:Array<String> = [
    'CAMPAIGN',
    'SINGLE SONG',
    'LOCAL MODS',
    'GAME PREFERENCES',
    'ABOUT THIS BUILD'
  ];

  static final ITEM_DESCRIPTIONS:Array<String> = [
    "Jump into the original Friday Night Funkin' story, keep your progress, and take on every week at your own pace.",
    'Search the song library, choose a difficulty, and jump straight into a track.',
    'Browse local mods, inspect their information, enable or disable them, and arrange load priority.',
    'Adjust your game preferences, controls, accessibility, and the menu presentation.',
    "View the people and projects behind Friday Night Funkin' and NovaBeat Engine."
  ];

  static final ITEM_SHORT_DESCRIPTIONS:Array<String> = [
    'Choose a week and continue the campaign.',
    'Pick a song and difficulty.',
    'Manage installed mods and load order.',
    'Change settings and customize the menus.',
    'Meet the people behind the engine.'
  ];

  static final ITEM_META:Array<Array<String>> = [
    ['CAMPAIGN', 'WEEK SELECT', 'DIFFICULTY'],
    ['SONG LIBRARY', 'DIFFICULTY', 'FAVORITES'],
    ['INSTALLED', 'LOCAL LIBRARY', 'LOAD ORDER'],
    ['AUDIO', 'GAMEPLAY', 'CUSTOMIZATION'],
    ['ENGINE', 'FOUNDATION', 'CREDITS']
  ];

  var uiCamera:FlxCamera;
  var interfaceLayer:FlxTypedGroup<FlxBasic>;
  var routeInterfaceObjects:Bool = false;
  var menuItems:TextMenuList;
  var showTitleOnCreate:Bool;
  var showingTitle:Bool = false;
  var transitioning:Bool = false;
  var compactLayout:Bool = false;
  var animationClock:Float = 0;

  var backgroundSprite:Null<FlxSprite>;
  var backgroundDimmer:Null<FlxSprite>;
  var titleLogo:Null<FlxSprite>;
  var titlePrompt:Null<FlxText>;
  var titleTapHint:Null<FlxText>;
  var homeAudioButton:Null<FlxText>;
  var homeOptionsButton:Null<FlxText>;
  var homeAudioHitbox:Null<FlxSprite>;
  var homeOptionsHitbox:Null<FlxSprite>;
  var menuAudioMuted:Bool = false;
  var previousMenuMusicVolume:Float = 0.82;
  var featureKicker:Null<FlxText> = null;
  var featureTitle:Null<FlxText> = null;
  var featureDescription:Null<FlxText> = null;

  var rowBackgrounds:Array<FlxSprite> = [];
  var rowIconPlates:Array<FlxSprite> = [];
  var rowAccents:Array<FlxSprite> = [];
  var rowLabels:Array<FlxText> = [];
  var rowIcons:Array<FlxText> = [];
  var rowKickers:Array<FlxText> = [];
  var rowDescriptions:Array<FlxText> = [];

  var equalizerBars:Array<FlxSprite> = [];

  public function new(showTitle:Bool = false)
  {
    super();
    showTitleOnCreate = showTitle;
  }

  override function create():Void
  {
    // Story/Options can disable raw keyboard input before switching states.
    FlxG.keys.enabled = true;
    FlxG.cameras.reset(new FunkinCamera('novaBeatMainMenu'));
    uiCamera = new FunkinCamera('novaBeatMenuUI');
    FlxG.cameras.add(uiCamera, false);
    uiCamera.bgColor = 0x00000000;

    super.create();

    interfaceLayer = new FlxTypedGroup<FlxBasic>();
    interfaceLayer.cameras = [uiCamera];
    interfaceLayer.scrollFactor.set(0, 0);
    super.add(interfaceLayer);
    routeInterfaceObjects = true;

    showingTitle = showTitleOnCreate;
    // A Freeplay substate owns input while it is open. Do not let the
    // underlying main-menu handler process the same key presses.
    persistentUpdate = subState == null;
    persistentDraw = true;

    if (showTitleOnCreate)
    {
      // Continue the NovaBeat theme from the experience selector when it is
      // already playing. If another style's track is active, replace it now.
      playMenuTheme(false, 0.82);
      buildBackdrop();
      buildTitleScreen();
    }
    else
    {
      playMenuTheme(false, 0.82);
      buildInterface();
      addNovaBeatMobileBackButton();
    }
  }

  override public function add(Object:FlxBasic):FlxBasic
  {
    if (routeInterfaceObjects && interfaceLayer != null && Object != interfaceLayer) return interfaceLayer.add(Object);
    return super.add(Object);
  }

  override public function remove(Object:FlxBasic, Splice:Bool = false):FlxBasic
  {
    if (routeInterfaceObjects && interfaceLayer != null && Object != interfaceLayer && interfaceLayer.members.contains(Object))
      return interfaceLayer.remove(Object, Splice);
    return super.remove(Object, Splice);
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (interfaceLayer == null || transitioning) return;

    var selectedIndex:Int = menuItems == null ? 0 : menuItems.selectedIndex;
    for (child in interfaceLayer.members.copy())
    {
      if (child == null) continue;
      FlxTween.cancelTweensOf(child);
      child.destroy();
    }
    interfaceLayer.clear();

    backgroundSprite = null;
    backgroundDimmer = null;
    titleLogo = null;
    titlePrompt = null;
    titleTapHint = null;
    homeAudioButton = null;
    homeOptionsButton = null;
    homeAudioHitbox = null;
    homeOptionsHitbox = null;
    menuItems = null;
    rowBackgrounds = [];
    rowIconPlates = [];
    rowAccents = [];
    rowLabels = [];
    rowIcons = [];
    rowKickers = [];
    rowDescriptions = [];
    equalizerBars = [];
    featureKicker = null;
    featureTitle = null;
    featureDescription = null;

    buildBackdrop();
    if (showingTitle)
    {
      buildTitleScreen();
    }
    else
    {
      buildInterface();
      if (menuItems != null && menuItems.length > 0)
      {
        menuItems.selectItem(Std.int(Math.max(0, Math.min(selectedIndex, menuItems.length - 1))));
        updateSelection(menuItems.selectedIndex);
      }
      addNovaBeatMobileBackButton();
    }
  }

  function buildBackdrop():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;

    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image('novabeat/menu-background'));
    // Overscan the artwork so no uncovered edges appear on the title screen
    // or the main menu, including wide and portrait viewports.
    var backgroundScale:Float = Math.max(width / background.width, height / background.height) * 1.08;
    background.scale.set(backgroundScale, backgroundScale);
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    background.cameras = [uiCamera];
    backgroundSprite = background;
    add(background);

    // The V4 reference keeps the background visible but subdued behind the UI.
    backgroundDimmer = addSolid(0, 0, width, height, 0xFF050817);
    backgroundDimmer.alpha = backgroundDimmerAlpha();
    addSolid(0, height * 0.72, width, height * 0.28, 0x3902081C);
  }

  function buildTitleScreen():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;
    var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('novabeat/title-logo'));
    var portraitLayout:Bool = height > width * 1.12;
    // Give the wide NovaBeat wordmark more room while keeping it clear of the
    // screen edges. Portrait viewports use a slightly shorter title footprint.
    var maxLogoWidth:Float = width * (portraitLayout ? 0.86 : 0.88) * interfaceScale();
    var maxLogoHeight:Float = height * (portraitLayout ? 0.30 : 0.48) * interfaceScale();
    var logoFit:Float = Math.max(0.01, Math.min(maxLogoWidth / logo.width, maxLogoHeight / logo.height));
    logo.setGraphicSize(Std.int(logo.width * logoFit), Std.int(logo.height * logoFit));
    logo.updateHitbox();
    logo.x = Math.round((width - logo.width) * 0.5);
    logo.y = height * (portraitLayout ? 0.40 : 0.43) - logo.height * 0.5;
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];
    titleLogo = logo;
    add(logo);

    if (DeviceUtil.isMobileBrowser)
    {
      titleTapHint = addLabel(0, height * 0.865, width, 'TAP ANYWHERE TO BEGIN', 20, 0xFF9FB7E6, FlxTextAlign.CENTER, 'Arial');
    }
    else
    {
      titlePrompt = addLabel(0, height * 0.865, width, 'PRESS ENTER TO BEGIN', titlePromptSize(), 0xFFFFFFFF, FlxTextAlign.CENTER, 'Arial Black');
    }

  }

  function titlePromptSize():Int
  {
    return FlxG.width < 700 ? 24 : 38;
  }

  function beginMenuTransition():Void
  {
    if (!showingTitle || transitioning) return;

    transitioning = true;
    playSfx('enter', 0.8);

    if (titleLogo != null)
    {
      FlxTween.tween(titleLogo, {alpha: 0.16, y: titleLogo.y - 14}, 0.72, {ease: FlxEase.quadOut});
    }
    if (titlePrompt != null) FlxTween.tween(titlePrompt, {alpha: 0, y: titlePrompt.y + 12}, 0.32, {ease: FlxEase.quadOut});
    if (titleTapHint != null) FlxTween.tween(titleTapHint, {alpha: 0}, 0.24, {ease: FlxEase.quadOut});

    FlxTimer.wait(0.72, function()
    {
      removeTitleScreen();
      showingTitle = false;
      transitioning = false;
      buildInterface();
    });
  }

  function removeTitleScreen():Void
  {
    if (titleLogo != null) remove(titleLogo, true);
    if (titlePrompt != null) remove(titlePrompt, true);
    if (titleTapHint != null) remove(titleTapHint, true);

    titleLogo = null;
    titlePrompt = null;
    titleTapHint = null;
  }

  function buildInterface():Void
  {
    var screenW:Int = FlxG.width;
    var screenH:Int = FlxG.height;
    // Quest Browser reports a landscape desktop viewport in its default mode.
    // Force the touch-friendly tile layout for Quest/mobile browsers anyway.
    compactLayout = DeviceUtil.isMobileBrowser || screenW < 950 || screenH > screenW * 1.12;

    // Preserve the V4 full-screen composition, not the upstream menuBG scene.
    if (backgroundSprite == null) buildBackdrop();

    var margin:Float = compactLayout ? Math.max(20, screenW * 0.035) : screenW * 0.042;
    buildTopBar(margin);

    var frameX:Float = compactLayout ? margin * 0.72 : screenW * 0.042;
    var frameY:Float = compactLayout ? screenH * 0.125 : screenH * 0.16;
    var frameW:Float = screenW - frameX * 2;
    var frameH:Float = screenH - frameY - (compactLayout ? screenH * 0.03 : screenH * 0.053);

    addPanel(frameX, frameY, frameW, frameH, 0xFF537FFF);

    var navX:Float = frameX + (compactLayout ? 18 : 38);
    var navY:Float = frameY + (compactLayout ? 18 : 28);
    var navW:Float = compactLayout ? frameW - 36 : frameW * 0.445;
    addLabel(navX + (compactLayout ? 0 : 4), navY, navW, 'NOVABEAT ENGINE', 11, 0xFF48E7FF, FlxTextAlign.LEFT, 'Arial');
    addLabel(navX + (compactLayout ? 0 : 4), navY + 19, navW, 'MAIN MENU', compactLayout ? 24 : 34, 0xFFF4F7FF, FlxTextAlign.LEFT, 'Arial Black');

    var listTop:Float = navY + (compactLayout ? 70 : 84);
    var listBottom:Float = frameY + frameH - (compactLayout ? 38 : 46);

    if (!compactLayout)
    {
      var featureX:Float = frameX + frameW * 0.515;
      var featureY:Float = frameY + 24;
      var featureW:Float = frameX + frameW - margin - featureX;
      var featureH:Float = frameH - 48;

      buildFeaturePanel(featureX, featureY, featureW, featureH);
      buildMenuList(navX, listTop, navW, listBottom - listTop, false);
      addLabel(frameX + 28, screenH - 27, frameW - 56, 'UP / DOWN   NAVIGATE       ENTER   SELECT', 10, 0xFF8297C2, FlxTextAlign.LEFT, 'Arial');
    }
    else
    {
      buildMenuList(navX, listTop, navW, listBottom - listTop, true);
      var menuHint:String = DeviceUtil.isMobileBrowser
        ? 'TAP A TILE TO OPEN'
        : 'TAP A TILE TO SELECT   •   ENTER TO OPEN';
      addLabel(navX, frameY + frameH - 26, navW, menuHint, 9, 0xFF8DA8D8, FlxTextAlign.LEFT, 'Arial');
    }
  }

  function buildTopBar(margin:Float):Void
  {
    var portraitLayout:Bool = FlxG.height > FlxG.width * 1.12;
    var logo:FlxSprite = new FlxSprite(margin, 12).loadGraphic(Paths.image('novabeat/title-logo'));
    logo.setGraphicSize(0, Std.int((portraitLayout ? 54 : 78) * interfaceScale()));
    logo.updateHitbox();
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];
    add(logo);

    var buttonY:Float = 18;
    var buttonSize:Float = portraitLayout ? 40 : 48;
    var buttonGap:Float = 10;
    var audioX:Float = FlxG.width - margin - buttonSize * 2 - buttonGap;
    var optionsX:Float = FlxG.width - margin - buttonSize;
    homeAudioButton = addLabel(audioX, buttonY, buttonSize, '♫', buttonSize > 44 ? 25 : 21, 0xFFDCE8FF, FlxTextAlign.CENTER, 'Arial');
    homeOptionsButton = addLabel(optionsX, buttonY, buttonSize, '⚙', buttonSize > 44 ? 25 : 21, 0xFFDCE8FF, FlxTextAlign.CENTER, 'Arial');

    addRoundRect(audioX, buttonY - 3, buttonSize, buttonSize, 13, 13, 0xB806102D);
    addRoundRect(optionsX, buttonY - 3, buttonSize, buttonSize, 13, 13, 0xB806102D);
    // The icons have matching full-size invisible hit areas; the text glyph
    // itself is too short to be a comfortable mobile target.
    homeAudioHitbox = addSolid(audioX, buttonY - 3, buttonSize, buttonSize, 0x00000000);
    homeOptionsHitbox = addSolid(optionsX, buttonY - 3, buttonSize, buttonSize, 0x00000000);
    // Draw the glyphs after their button plates so they stay on top.
    bringToFront(homeAudioButton);
    bringToFront(homeOptionsButton);
    homeAudioButton.text = menuAudioMuted ? '♪' : '♫';
  }

  function bringToFront(sprite:FlxSprite):Void
  {
    remove(sprite, false);
    add(sprite);
  }

  function buildMenuList(x:Float, y:Float, width:Float, height:Float, tileLayout:Bool):Void
  {
    var gap:Float = (tileLayout ? Math.max(8, FlxG.width * 0.018) : Math.max(9, FlxG.height * 0.018));
    gap *= densityMultiplier() * 1.06;

    var portraitLayout:Bool = FlxG.height > FlxG.width * 1.12;
    var columns:Int = tileLayout ? (portraitLayout ? 1 : 2) : 1;
    var rows:Int = Std.int(Math.ceil(ITEM_NAMES.length / columns));
    var buttonW:Float = tileLayout ? (width - gap * (columns + 1)) / columns : width - 20;
    var buttonH:Float;
    if (tileLayout)
    {
      buttonH = Math.max(52, Math.min(portraitLayout ? 98 : 78, (height - gap * (rows - 1)) / rows));
    }
    else
    {
      buttonH = Math.max(54, Math.min(82, (height - gap * 4) / 5));
    }

    var firstX:Float = tileLayout ? x + gap : x + 6;
    var firstY:Float = y + (tileLayout ? 0 : 10);

    menuItems = new TextMenuList(tileLayout && columns > 1 ? NavControls.Columns(columns) : NavControls.Vertical);
    menuItems.cameras = [uiCamera];
    menuItems.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;

    for (index in 0...ITEM_NAMES.length)
    {
      var column:Int = tileLayout ? index % columns : 0;
      var row:Int = tileLayout ? Std.int(index / columns) : index;
      var itemX:Float = tileLayout ? firstX + column * (buttonW + gap) : firstX;
      var itemY:Float = firstY + row * (buttonH + gap);

      var panel:FlxSprite = addRoundRect(itemX, itemY, buttonW, buttonH, 14, 14, 0xFF0D1935);
      panel.alpha = 0.93;
      rowBackgrounds.push(panel);

      var accent:FlxSprite = addRoundRect(itemX, itemY + buttonH * 0.16, 4, buttonH * 0.68, 3, 3, accentColor());
      accent.alpha = 0.38;
      rowAccents.push(accent);

      var item:TextMenuItem = menuItems.createItem(itemX, itemY, ITEM_NAMES[index], AtlasFont.BOLD, makeCallback(index));
      item.cameras = [uiCamera];
      item.makeGraphic(Std.int(buttonW), Std.int(buttonH), FlxColor.TRANSPARENT);
      item.updateHitbox();
      item.scrollFactor.set();
      // Keep the upstream FNF bitmap label hidden. Its parent alpha changes
      // when selected, so alpha alone is not enough to prevent it drawing.
      item.atlasText.alpha = 0;
      item.atlasText.visible = false;

      // Use a shared badge so the menu symbols remain legible and aligned.
      var iconPlateSize:Float = tileLayout ? (portraitLayout ? 46 : 38) : 46;
      var iconX:Float = itemX + (tileLayout ? 10 : 14);
      var iconY:Float = itemY + (buttonH - iconPlateSize) * 0.5;
      var iconPlate:FlxSprite = addRoundRect(iconX, iconY, iconPlateSize, iconPlateSize, 12, 12, 0xFF142B49);
      iconPlate.alpha = 0.96;
      rowIconPlates.push(iconPlate);

      var iconSize:Int = tileLayout ? (portraitLayout ? 23 : 21) : 25;
      var icon:FlxText = addLabel(iconX, iconY + 1, iconPlateSize, ITEM_ICONS[index], iconSize, 0xFF8AA1D0, FlxTextAlign.CENTER, 'Arial');
      icon.scrollFactor.set();
      icon.autoSize = false;
      icon.fieldWidth = iconPlateSize;
      icon.height = iconPlateSize - 2;
      rowIcons.push(icon);

      var labelX:Float = iconX + iconPlateSize + (tileLayout ? 10 : 14);
      var labelWidth:Float = buttonW - (labelX - itemX) - (tileLayout ? 10 : 16);
      var title:String = ITEM_TITLES[index].split('\n').join(' ');
      var titleY:Float = itemY + 7;
      var label:FlxText = addLabel(labelX, titleY, labelWidth, title, tileLayout ? (portraitLayout ? 15 : 14) : 18, 0xFFDBE4FA, FlxTextAlign.LEFT, 'Arial Black');
      label.autoSize = false;
      label.wordWrap = false;
      label.fieldWidth = labelWidth;
      label.height = tileLayout ? (portraitLayout ? 21 : 19) : 23;
      label.scrollFactor.set();
      rowLabels.push(label);

      var kickerY:Float = itemY + (tileLayout ? (portraitLayout ? 31 : 28) : 31);
      var kicker:FlxText = addLabel(labelX, kickerY, labelWidth, ITEM_KICKERS[index], tileLayout ? (portraitLayout ? 9 : 8) : 9, 0xFF48CDEB, FlxTextAlign.LEFT, 'Arial');
      kicker.autoSize = false;
      kicker.wordWrap = false;
      kicker.fieldWidth = labelWidth;
      kicker.height = 12;
      kicker.scrollFactor.set();
      rowKickers.push(kicker);

      var descriptionY:Float = itemY + (tileLayout ? (portraitLayout ? 49 : 43) : 47);
      var description:String = tileLayout ? ITEM_SHORT_DESCRIPTIONS[index] : ITEM_DESCRIPTIONS[index];
      var descriptionText:FlxText = addLabel(labelX, descriptionY, labelWidth, description, tileLayout ? (portraitLayout ? 9 : 8) : 9, 0xFFAABBDD, FlxTextAlign.LEFT, 'Arial');
      descriptionText.autoSize = false;
      descriptionText.wordWrap = true;
      descriptionText.fieldWidth = labelWidth;
      descriptionText.height = Math.max(12, buttonH - (tileLayout ? (portraitLayout ? 54 : 46) : 48));
      descriptionText.scrollFactor.set();
      rowDescriptions.push(descriptionText);

      if (Save.instance.options.menuEntryAnimations && !Save.instance.options.menuReduceMotion)
      {
        panel.alpha = 0;
        accent.alpha = 0;
        iconPlate.alpha = 0;
        icon.alpha = 0;
        label.alpha = 0;
        kicker.alpha = 0;
        descriptionText.alpha = 0;
        FlxTween.tween(panel, {alpha: 0.93}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(accent, {alpha: 0.38}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(iconPlate, {alpha: 0.96}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(icon, {alpha: 1}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(label, {alpha: 1}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(kicker, {alpha: 1}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(descriptionText, {alpha: 1}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
      }
    }

    menuItems.onChange.add(function(selected:TextMenuItem)
    {
      updateSelection(menuItems.selectedIndex);
    });

    add(menuItems);
    updateSelection(0);
  }

  function buildFeaturePanel(x:Float, y:Float, width:Float, height:Float):Void
  {
    addPanel(x, y, width, height, 0xFF6982C4);

    // Draw the animated bars first so every panel label, pill, and accent sits above them.
    if (Save.instance.options.menuShowEqualizer)
    {
      buildEqualizer(x + 34, y + height - 136, width - 68);
    }

    // Present useful details for the selected section on desktop layouts.
    featureKicker = addLabel(x + 34, y + 104, width - 68, ITEM_KICKERS[0], 10, 0xFF48E7FF, FlxTextAlign.LEFT, 'Arial');
    featureTitle = addLabel(x + 34, y + 126, width - 68, ITEM_NAMES[0], 28, 0xFFF4F7FF, FlxTextAlign.LEFT, 'Arial Black');
    featureDescription = addLabel(x + 34, y + 174, width - 68, ITEM_DESCRIPTIONS[0], 15, 0xFFD0DCF3, FlxTextAlign.LEFT, 'Arial');
    featureDescription.autoSize = false;
    featureDescription.wordWrap = true;
    featureDescription.fieldWidth = width - 68;
    featureDescription.height = Math.min(112, Math.max(72, height * 0.28));

    var orbit:FlxSprite = addSolid(x + width * 0.50, y + 24, width * 0.40, 2, 0x265D72FF);
    orbit.alpha = 0.5;
    addSolid(x + width * 0.77, y + 24, 2, height * 0.34, 0x265D72FF).alpha = 0.5;
    var visualAccent:FlxSprite = addRoundRect(x + 34, y + 38, width * 0.34, 5, 3, 3, accentColor());
    visualAccent.alpha = 0.85;
    addRoundRect(x + 34, y + 56, width * 0.21, 3, 2, 2, 0xFF8297C2).alpha = 0.5;
    addRoundRect(x + 34, y + 68, width * 0.27, 3, 2, 2, 0xFF8297C2).alpha = 0.3;
  }

  function updateSelection(index:Int):Void
  {
    if (index < 0 || index >= ITEM_NAMES.length) return;

    for (i in 0...ITEM_NAMES.length)
    {
      var selected:Bool = i == index;
      if (i < rowBackgrounds.length)
      {
        rowBackgrounds[i].color = selected
          ? (Save.instance.options.menuReduceFlashing ? 0xFF10283D : 0xFF12375A)
          : 0xFF0D1935;
        rowBackgrounds[i].alpha = selected ? 1 : 0.84;
      }
      if (i < rowIconPlates.length)
      {
        rowIconPlates[i].color = selected ? 0xFF1A4261 : 0xFF142B49;
        rowIconPlates[i].alpha = selected ? 1.0 : 0.88;
      }
      if (i < rowAccents.length)
      {
        rowAccents[i].color = selected ? accentColor() : 0xFF267CFF;
        rowAccents[i].alpha = selected ? (Save.instance.options.menuReduceFlashing ? 0.58 : 1) : 0.34;
      }
      if (i < rowLabels.length)
      {
        rowLabels[i].color = selected ? 0xFFFFFFFF : 0xFFB9C8E3;
      }
      if (i < rowIcons.length)
      {
        rowIcons[i].color = selected ? accentColor() : 0xFF8297C2;
      }
      if (i < rowKickers.length)
      {
        rowKickers[i].color = selected ? 0xFF65E8FF : 0xFF48A9C4;
      }
      if (i < rowDescriptions.length)
      {
        rowDescriptions[i].color = selected ? 0xFFDCEBFF : 0xFF9AAAC7;
      }
    }

    if (featureKicker != null) featureKicker.text = ITEM_KICKERS[index];
    if (featureTitle != null) featureTitle.text = ITEM_NAMES[index];
    if (featureDescription != null) featureDescription.text = ITEM_DESCRIPTIONS[index];

    // MenuTypedList owns navigation sounds for keyboard, controller, and mouse.
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (showingTitle)
    {
      var pressed:Bool = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;
      var gamepad = FlxG.gamepads.lastActive;
      if (gamepad != null && (gamepad.justPressed.START || gamepad.justPressed.ACCEPT)) pressed = true;
      // Use the same release-based mobile confirm used by the original FNF menus.
      #if (mobile || FEATURE_TOUCH_CONTROLS)
      if (DeviceUtil.isMobileBrowser && TouchUtil.pressAction() && !SwipeUtil.justSwipedAny) pressed = true;
      #end

      if (pressed) beginMenuTransition();
      return;
    }

    handleHeaderPointerInput();

    #if !mobile
    // Fallback to raw desktop keys when a custom binding is absent.
    // Avoid double movement if the standard control binding fired too.
    if (menuItems != null && !menuItems.busy)
    {
      if (FlxG.keys.justPressed.UP && !controls.UI_UP_P)
        menuItems.selectItem(menuItems.selectedIndex - 1 < 0 ? menuItems.length - 1 : menuItems.selectedIndex - 1);
      else if (FlxG.keys.justPressed.DOWN && !controls.UI_DOWN_P)
        menuItems.selectItem(menuItems.selectedIndex + 1 >= menuItems.length ? 0 : menuItems.selectedIndex + 1);

      if ((FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) && !controls.ACCEPT_P)
        menuItems.accept();
    }
    #end

    animationClock += elapsed;
    var options = Save.instance.options;
    if (backgroundDimmer != null) backgroundDimmer.alpha = backgroundDimmerAlpha();

    if (!options.menuReduceMotion && options.menuAnimatedBackground && backgroundSprite != null)
    {
      backgroundSprite.alpha = 0.985 + Math.sin(animationClock * 0.45) * 0.015;
    }

    if (!options.menuReduceMotion && options.menuShowEqualizer && options.menuAudioVisualizer)
    {
      for (index in 0...equalizerBars.length)
      {
        var scale:Float = 0.60 + (Math.sin(animationClock * 2.15 + index * 0.62) + 1) * 0.20;
        // Each bar scales from its bottom edge, keeping the baseline in place.
        equalizerBars[index].scale.y = scale;
      }
    }

    if (controls.BACK_P) goBackToTitle();
  }

  /**
   * Handles the two large header actions on the NovaBeat menu. Their hitboxes
   * cover the full icon plates so a finger does not have to hit the glyph.
   */
  function addNovaBeatMobileBackButton():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (DeviceUtil.isMobileBrowser)
      addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, goBackToTitle, 1.0);
    #end
  }

  function goBackToTitle():Void
  {
    if (transitioning) return;
    playSfx('back', 0.7);
    FlxG.switchState(() -> new TitleState());
  }

  function handleHeaderPointerInput():Void
  {
    var optionsPressed:Bool = false;
    if (homeOptionsHitbox != null)
    {
      #if mobile
      optionsPressed = TouchUtil.pressAction(homeOptionsHitbox, uiCamera);
      #elseif web
      optionsPressed = DeviceUtil.isMobileBrowser
        ? TouchUtil.pressAction(homeOptionsHitbox, uiCamera)
        : (FlxG.mouse.justPressed && FlxG.mouse.overlaps(homeOptionsHitbox, uiCamera));
      #else
      optionsPressed = FlxG.mouse.justPressed && FlxG.mouse.overlaps(homeOptionsHitbox, uiCamera);
      #end
    }

    if (optionsPressed)
    {
      playSfx('confirm', 0.8);
      openOptions();
      return;
    }

    var audioPressed:Bool = false;
    if (homeAudioHitbox != null)
    {
      #if mobile
      audioPressed = TouchUtil.pressAction(homeAudioHitbox, uiCamera);
      #elseif web
      audioPressed = DeviceUtil.isMobileBrowser
        ? TouchUtil.pressAction(homeAudioHitbox, uiCamera)
        : (FlxG.mouse.justPressed && FlxG.mouse.overlaps(homeAudioHitbox, uiCamera));
      #else
      audioPressed = FlxG.mouse.justPressed && FlxG.mouse.overlaps(homeAudioHitbox, uiCamera);
      #end
    }

    if (audioPressed)
    {
      final music = FlxG.sound.music;
      if (music == null) return;

      if (menuAudioMuted)
      {
        music.volume = previousMenuMusicVolume;
        menuAudioMuted = false;
      }
      else
      {
        previousMenuMusicVolume = music.volume;
        music.volume = 0.0;
        menuAudioMuted = true;
      }

      if (homeAudioButton != null) homeAudioButton.text = menuAudioMuted ? '♪' : '♫';
      playSfx('select', 0.45);
    }
  }

  function makeCallback(index:Int):Void->Void
  {
    return function()
    {
      switch (index)
      {
        case 0:
          FlxG.switchState(() -> new StoryMenuState());
        case 1:
          openSubState(new FreeplayState({
            character: FreeplayState.rememberedCharacterId
          }));
          persistentUpdate = false;
        case 2:
          FlxG.switchState(() -> new NovaBeatModsMenuState());
        case 3:
          openOptions();
        case 4:
          FlxG.switchState(() -> new CreditsState());
        default:
      }
    };
  }

  function openOptions():Void
  {
    FlxG.switchState(() -> new OptionsState());
  }

  function interfaceScale():Float
  {
    return Math.max(0.85, Math.min(1.15, Save.instance.options.menuInterfaceScale / 100));
  }

  function backgroundDimmerAlpha():Float
  {
    // Keep the original V4 look at the default value (100), then let
    // lower values darken the artwork and higher values reveal more of it.
    return 0.553 - ((Save.instance.options.menuBackgroundIntensity - 100) / 60) * 0.56;
  }

  function densityMultiplier():Float
  {
    var density:Float = switch (Save.instance.options.menuDensity)
    {
      case "compact": 0.78;
      case "spacious": 1.18;
      default: 1.0;
    };
    return density * interfaceScale();
  }

  function accentColor():FlxColor
  {
    return switch (Save.instance.options.menuAccent)
    {
      case "violet": 0xFFB46CFF;
      case "magenta": 0xFFFF65C9;
      case "ice": 0xFFF3FFFF;
      default: 0xFF48E7FF;
    };
  }

  function addPanel(x:Float, y:Float, width:Float, height:Float, borderColor:FlxColor):Void
  {
    var border:FlxSprite = addRoundRect(x, y, width, height, 28, 28, borderColor);
    border.alpha = Math.max(0, Math.min(1, Save.instance.options.menuPanelGlow / 100));
    addRoundRect(x + 2, y + 2, width - 4, height - 4, 26, 26, 0xF0061028);
  }

  function addRoundRect(x:Float, y:Float, width:Float, height:Float, radiusX:Float, radiusY:Float, color:FlxColor):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
    // FlxSpriteUtil draws into sprite.pixels; a fresh FlxSprite has no bitmap yet.
    // Allocate a transparent buffer before drawing, preserving the rounded-corner shape.
    sprite.makeGraphic(Std.int(Math.max(1, Math.ceil(width))), Std.int(Math.max(1, Math.ceil(height))), FlxColor.TRANSPARENT);
    FlxSpriteUtil.drawRoundRect(sprite, 0, 0, width, height, radiusX, radiusY, color);
    sprite.scrollFactor.set();
    sprite.cameras = [uiCamera];
    add(sprite);
    return sprite;
  }

  function addSolid(x:Float, y:Float, width:Float, height:Float, color:FlxColor):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
    sprite.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), color);
    sprite.scrollFactor.set();
    sprite.cameras = [uiCamera];
    add(sprite);
    return sprite;
  }

  function addLabel(
    x:Float,
    y:Float,
    width:Float,
    value:String,
    size:Int,
    color:FlxColor,
    alignment:FlxTextAlign = FlxTextAlign.LEFT,
    fontName:String = 'Arial'
  ):FlxText
  {
    var scaledSize:Int = Std.int(Math.max(8, size * interfaceScale() * (Save.instance.options.menuLargeText ? 1.12 : 1.0)));
    var label:FlxText = new FlxText(x, y, width, value, scaledSize);
    label.setFormat(fontName, scaledSize, color, alignment, null, FlxColor.TRANSPARENT, false);
    label.scrollFactor.set();
    label.cameras = [uiCamera];
    add(label);
    return label;
  }

  function buildEqualizer(x:Float, y:Float, width:Float):Void
  {
    var count:Int = 28;
    var gap:Float = 5;
    var barWidth:Float = Math.max(2, (width - (count - 1) * gap) / count);

    for (index in 0...count)
    {
      var height:Float = 14 + (index * 17 % 74);
      var color:FlxColor = index % 7 == 0 ? 0xFF8C48FF : 0xFF43DFFF;
      var bar:FlxSprite = addSolid(x + index * (barWidth + gap), y + 76 - height, barWidth, height, color);
      bar.origin.set(bar.width * 0.5, bar.height);
      bar.alpha = 0.78;
      equalizerBars.push(bar);
    }
  }

  function playMenuTheme(restart:Bool, startingVolume:Float):Void
  {
    // Paths.music selects MP3 on web and OGG on native targets.
    // Browser builds generate MP3 variants from the source OGG files.
    // FunkinSound detects an already-playing matching asset and leaves it
    // alone; a different active track is replaced. This avoids both silence
    // during the title handoff and unnecessary music restarts.
    FunkinSound.playMusic('novabeat-menu', {
      startingVolume: startingVolume,
      overrideExisting: true,
      restartTrack: restart,
      persist: true,
      mapTimeChanges: false
    });
  }

  function playSfx(name:String, volume:Float):Void
  {
    // Paths.sound selects the correct platform extension for this target.
    FunkinSound.playOnce(Paths.sound('novabeat/' + name), volume);
  }
}
