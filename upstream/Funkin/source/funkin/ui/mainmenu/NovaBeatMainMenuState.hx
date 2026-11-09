package funkin.ui.mainmenu;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
import funkin.save.Save;
import funkin.audio.FunkinSound;
import funkin.modding.ExperienceManager;
import funkin.graphics.FunkinCamera;
import funkin.graphics.shaders.NovaBeatEdgeDissolveShader;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.MenuList.NavControls;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.MusicBeatState;
import funkin.ui.title.TitleState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.credits.CreditsState;
import funkin.input.Cursor;
import funkin.ui.options.OptionsState;
import funkin.util.DeviceUtil;
import funkin.util.TouchUtil;
import funkin.util.SwipeUtil;

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
    'OPTIONS',
    'MODS'
  ];

  static final ITEM_ICONS:Array<String> = ['▶', '♫', '⚙', '✦'];

  static final ITEM_TITLES:Array<String> = [
    'STORY MODE',
    'FREEPLAY',
    'OPTIONS',
    'MODS'
  ];



  var uiCamera:FlxCamera;
  var interfaceLayer:FlxTypedGroup<FlxBasic>;
  var routeInterfaceObjects:Bool = false;
  var menuItems:TextMenuList;
  // Indexes into the menu content arrays, kept separate for callback mapping.
  var visibleItemIndexes:Array<Int> = [];
  var showTitleOnCreate:Bool;
  var showingTitle:Bool = false;
  var transitioning:Bool = false;
  var compactLayout:Bool = false;
  var animationClock:Float = 0;

  var backgroundSprite:Null<FlxSprite>;
  var backgroundDimmer:Null<FlxSprite>;
  var titleLogo:Null<FlxSprite>;
  var titlePrompt:Null<FlxSprite>;
  var whiteFlashOverlay:Null<FlxSprite>;
  var titleLogoDissolveShader:Null<NovaBeatEdgeDissolveShader>;
  var titlePromptDissolveShader:Null<NovaBeatEdgeDissolveShader>;
  var menuEntrancePending:Bool = false;
  var homeAudioButton:Null<FlxText>;
  var homeOptionsButton:Null<FlxText>;
  var homeAudioHitbox:Null<FlxSprite>;
  var homeOptionsHitbox:Null<FlxSprite>;
  var menuAudioMuted:Bool = false;
  var previousMenuMusicVolume:Float = 0.82;
  var featureTitle:Null<FlxText> = null;
  var menuScrollCamera:Null<FlxCamera> = null;
  var menuScrollCardHeight:Float = 0;
  var menuScrollStep:Float = 0;
  var menuScrollViewportHeight:Float = 0;
  var menuScrollViewportTop:Float = 0;
  var rowTapTargets:Array<FlxObject> = [];
  var rowBorders:Array<FlxSprite> = [];

  var rowBackgrounds:Array<FlxSprite> = [];
  var rowIconPlates:Array<FlxSprite> = [];
  var rowAccents:Array<FlxSprite> = [];
  var rowLabels:Array<FlxText> = [];
  var rowIcons:Array<FlxText> = [];
  // NovaBeat-only artwork atlas for the custom Story Mode menu card.
  var rowArtwork:Array<FlxSprite> = [];

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
    Cursor.hide();
    FlxG.cameras.reset(new FunkinCamera('novaBeatMainMenu'));
    uiCamera = new FunkinCamera('novaBeatMenuUI');
    FlxG.cameras.add(uiCamera, false);
    uiCamera.bgColor = 0x00000000;

    super.create();

    interfaceLayer = new FlxTypedGroup<FlxBasic>();
    interfaceLayer.cameras = [uiCamera];
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
    if (menuScrollCamera != null)
    {
      // CameraFrontEnd.remove destroys the camera by default.
      FlxG.cameras.remove(menuScrollCamera);
      menuScrollCamera = null;
    }
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
    whiteFlashOverlay = null;
    titleLogoDissolveShader = null;
    titlePromptDissolveShader = null;
    menuEntrancePending = false;
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
    rowArtwork = [];
    equalizerBars = [];
    featureTitle = null;
    menuScrollCardHeight = 0;
    menuScrollStep = 0;
    menuScrollViewportHeight = 0;
    menuScrollViewportTop = 0;
    rowTapTargets = [];
    rowBorders = [];

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

    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image('Bg'));
    var backgroundScale:Float = Math.max(width / background.width, height / background.height);
    background.scale.set(backgroundScale, backgroundScale);
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    background.cameras = [uiCamera];
    background.color = FlxColor.WHITE;
    background.zIndex = -100;
    backgroundSprite = background;
    add(background);

    backgroundDimmer = addSolid(0, 0, width, height, 0xE5070416);
    backgroundDimmer.zIndex = -90;
    backgroundDimmer.alpha = backgroundDimmerAlpha();

    var leftBeam:FlxSprite = addRoundRect(width * 0.50, -height * 0.18, width * 0.055, height * 1.22,
      32, 32, 0xFFB44DFF);
    leftBeam.angle = 17;
    leftBeam.alpha = 0.10;
    leftBeam.zIndex = -80;

    var rightBeam:FlxSprite = addRoundRect(width * 0.80, -height * 0.16, width * 0.045, height * 1.18,
      26, 26, 0xFF7B48FF);
    rightBeam.angle = -14;
    rightBeam.alpha = 0.09;
    rightBeam.zIndex = -80;

    var bottomShade:FlxSprite = addSolid(0, height * 0.76, width, height * 0.24, 0xA3030615);
    bottomShade.zIndex = -70;

    var graffitiStar:FlxText = addLabel(width * 0.79, height * 0.12, 90, '✦', 66, 0xFFB968FF,
      FlxTextAlign.CENTER, 'Arial');
    graffitiStar.alpha = 0.44;
    graffitiStar.angle = -12;
    var graffitiSpark:FlxText = addLabel(width * 0.56, height * 0.70, 54, '✧', 42, 0xFFEE7BFF,
      FlxTextAlign.CENTER, 'Arial');
    graffitiSpark.alpha = 0.42;
  }

  function buildTitleScreen():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;
    var portraitLayout:Bool = height > width * 1.12;

    // Flash only the backdrop. The same backgroundSprite remains underneath
    // the title screen and main menu, with no replacement or movement.
    var flash:FlxSprite = addSolid(0, 0, width, height, FlxColor.WHITE);
    flash.alpha = 0;
    flash.zIndex = -50;
    whiteFlashOverlay = flash;

    // Use Claude's animated Bumpin atlas in NovaBeat itself (not only the
    // original FNF title state). Keep the atlas colors un-tinted.
    var logo:FlxSprite = new FlxSprite();
    logo.frames = Paths.getSparrowAtlas('logoBumpin');
    logo.animation.addByPrefix('idle', 'logo bumpin', 24, true);
    logo.animation.play('idle', true);
    titleLogoDissolveShader = new NovaBeatEdgeDissolveShader();
    titleLogoDissolveShader.updateFrame(logo.frame);
    logo.shader = titleLogoDissolveShader;
    logo.antialiasing = true;
    var maxLogoWidth:Float = width * (portraitLayout ? 0.90 : 0.82) * interfaceScale();
    var maxLogoHeight:Float = height * (portraitLayout ? 0.27 : 0.30) * interfaceScale();
    var logoFit:Float = Math.max(0.01, Math.min(maxLogoWidth / logo.width, maxLogoHeight / logo.height));
    logo.setGraphicSize(Std.int(logo.width * logoFit), Std.int(logo.height * logoFit));
    logo.updateHitbox();
    logo.x = Math.round((width - logo.width) * 0.5);
    logo.y = height * 0.27 - logo.height * 0.5;
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];
    titleLogo = logo;
    add(logo);

    // The supplied atlas contains two idle frames and a two-frame pressed state.
    var prompt:FlxSprite = new FlxSprite();
    prompt.frames = Paths.getSparrowAtlas('titleEnter');
    prompt.animation.addByPrefix('idle', 'ENTER IDLE', 12, true);
    prompt.animation.addByPrefix('pressed', 'ENTER PRESSED', 24, false);
    prompt.animation.play('idle', true);
    titlePromptDissolveShader = new NovaBeatEdgeDissolveShader();
    titlePromptDissolveShader.updateFrame(prompt.frame);
    prompt.shader = titlePromptDissolveShader;
    prompt.updateHitbox();

    var promptMaxWidth:Float = width * 0.82;
    var promptMaxHeight:Float = height * 0.18;
    var promptScale:Float = Math.min(promptMaxWidth / Math.max(1, prompt.width),
      promptMaxHeight / Math.max(1, prompt.height));
    prompt.setGraphicSize(Std.int(prompt.width * promptScale), Std.int(prompt.height * promptScale));
    prompt.updateHitbox();
    prompt.x = Math.round((width - prompt.width) * 0.5);
    prompt.y = height * (portraitLayout ? 0.83 : 0.79);
    prompt.antialiasing = true;
    prompt.scrollFactor.set();
    prompt.cameras = [uiCamera];
    titlePrompt = prompt;
    add(prompt);
  }

  function beginMenuTransition():Void
  {
    if (!showingTitle || transitioning) return;

    transitioning = true;
    playSfx('enter', 0.8);

    // Both title elements dissolve from their outside edges toward the center.
    // Sharing one duration keeps the logo and prompt moving together.
    if (titleLogoDissolveShader != null)
    {
      titleLogoDissolveShader.progress = 0;
      if (titleLogo != null) titleLogoDissolveShader.updateFrame(titleLogo.frame);
      FlxTween.tween(titleLogoDissolveShader, {progress: 1}, 0.58, {ease: FlxEase.linear});
    }

    if (titlePromptDissolveShader != null)
    {
      if (titlePrompt != null) titlePrompt.animation.play('pressed', true);
      titlePromptDissolveShader.progress = 0;
      if (titlePrompt != null) titlePromptDissolveShader.updateFrame(titlePrompt.frame);
      FlxTween.tween(titlePromptDissolveShader, {progress: 1}, 0.58, {ease: FlxEase.linear});
    }

    // A brief white flash is composited over the backdrop only, then fades
    // away to reveal the exact same background image beneath it.
    if (whiteFlashOverlay != null)
    {
      whiteFlashOverlay.alpha = 0;
      FlxTween.tween(whiteFlashOverlay, {alpha: 0.98}, 0.18, {ease: FlxEase.quadOut});
      FlxTimer.wait(0.18, function()
      {
        if (whiteFlashOverlay != null)
          FlxTween.tween(whiteFlashOverlay, {alpha: 0}, 0.70, {ease: FlxEase.sineInOut});
      });
    }

    // Build the main menu while the flash finishes fading. The button
    // tweens overlap to form one quick cascade from beyond the left edge.
    FlxTimer.wait(0.58, function()
    {
      removeTitleScreen();
      showingTitle = false;
      menuEntrancePending = true;
      buildInterface();
      addNovaBeatMobileBackButton();
    });

    FlxTimer.wait(0.92, function()
    {
      if (whiteFlashOverlay != null)
      {
        remove(whiteFlashOverlay, true);
        whiteFlashOverlay = null;
      }
    });

    // Four buttons finish their staggered slide in about 1.25 seconds.
    FlxTimer.wait(1.30, function()
    {
      transitioning = false;
    });
  }

  function removeTitleScreen():Void
  {
    if (titlePrompt != null) remove(titlePrompt, true);
    if (titleLogo != null) remove(titleLogo, true);
    titlePrompt = null;
    titleLogo = null;
    titlePromptDissolveShader = null;
    titleLogoDissolveShader = null;
  }

    function buildInterface():Void
  {
    var screenW:Int = FlxG.width;
    var screenH:Int = FlxG.height;
    var portraitLayout:Bool = screenH > screenW * 1.12;
    compactLayout = DeviceUtil.isMobileBrowser || screenW < 950 || portraitLayout;

    if (backgroundSprite == null) buildBackdrop();

    var margin:Float = portraitLayout ? Math.max(16, screenW * 0.035) : Math.max(24, screenW * 0.035);
    buildTopBar(margin);

    var frameX:Float = margin;
    var frameY:Float = screenH * (portraitLayout ? 0.205 : 0.19);
    var frameW:Float = portraitLayout ? screenW - margin * 2 : screenW * (compactLayout ? 0.54 : 0.47);
    var frameH:Float = screenH * (portraitLayout ? 0.43 : 0.67);
    if (DeviceUtil.isMobileBrowser && !portraitLayout)
    {
      frameY = screenH * 0.16;
      frameH = screenH * 0.70;
      frameW = screenW * 0.53;
    }

    addPanel(frameX, frameY, frameW, frameH, 0xFFB75CFF);
    var navX:Float = frameX + (portraitLayout ? 12 : 28);
    var navW:Float = frameW - (portraitLayout ? 24 : 56);

    addLabel(navX + 4, frameY + 16, navW - 8, 'SELECT A MODE', compactLayout ? 20 : 27,
      0xFFFFFFFF, FlxTextAlign.LEFT, Paths.font('vcr.ttf'));

    var listTop:Float = frameY + (portraitLayout ? 58 : 72);
    var listBottom:Float = frameY + frameH - (portraitLayout ? 20 : 28);
    buildMenuList(navX, listTop, navW, listBottom - listTop, true);

    var hint:String = DeviceUtil.isMobileBrowser
      ? 'TAP AN OPTION TO OPEN'
      : 'UP / DOWN  SELECT     ENTER  CONFIRM     ESC  BACK';
    addLabel(frameX + 16, screenH - 28, Math.max(1, frameW - 32), hint, compactLayout ? 9 : 11,
      0xFFE0C9FF, FlxTextAlign.LEFT, Paths.font('vcr.ttf'));

    if (!portraitLayout)
      addLabel(screenW * 0.62, screenH * 0.12, screenW * 0.32, 'THE STAGE IS YOURS',
        compactLayout ? 15 : 19, 0xFFE2BDFF, FlxTextAlign.CENTER, Paths.font('vcr.ttf'));
  }

  function buildTopBar(margin:Float):Void
  {
    var portraitLayout:Bool = FlxG.height > FlxG.width * 1.12;
    var logo:FlxSprite = titleLogo;
    if (logo == null)
    {
      logo = new FlxSprite().loadGraphic(Paths.image('novabeat/title-logo'));
      logo.scrollFactor.set();
      logo.cameras = [uiCamera];
      logo.color = 0xFFF1D9FF;
      titleLogo = logo;
      add(logo);
    }

    logo.setGraphicSize(0, Std.int((portraitLayout ? 48 : 76) * interfaceScale()));
    logo.updateHitbox();
    logo.setPosition(margin, 10);

    var buttonSize:Float = portraitLayout ? 38 : 46;
    var buttonY:Float = 18;
    var audioX:Float = FlxG.width - margin - buttonSize;
    homeAudioButton = addLabel(audioX, buttonY, buttonSize, menuAudioMuted ? '♪' : '♫',
      buttonSize > 42 ? 25 : 21, 0xFFF0D7FF, FlxTextAlign.CENTER, 'Arial');
    addRoundRect(audioX, buttonY - 3, buttonSize, buttonSize, 13, 13, 0xD20A0719);
    homeAudioHitbox = addSolid(audioX, buttonY - 3, buttonSize, buttonSize, 0x00000000);
    homeOptionsButton = null;
    homeOptionsHitbox = null;
    bringToFront(homeAudioButton);
  }

  function bringToFront(sprite:FlxSprite):Void
  {
    remove(sprite, false);
    add(sprite);
  }

  function buildMenuList(x:Float, y:Float, width:Float, height:Float, tileLayout:Bool):Void
  {
    visibleItemIndexes = [0, 1, 2, 3];

    var mobileLandscape:Bool = DeviceUtil.isMobileBrowser && FlxG.height <= FlxG.width * 1.12;
    var portraitLayout:Bool = FlxG.height > FlxG.width * 1.12;
    var gap:Float = portraitLayout ? 8 : (mobileLandscape ? 8 : (compactLayout ? 10 : 13));
    var buttonW:Float = Math.max(1, width - gap * 2);
    var buttonH:Float;

    if (mobileLandscape)
      buttonH = Math.max(44, Math.min(62, (height - gap * 3) / 4));
    else if (portraitLayout)
      buttonH = Math.max(54, Math.min(82, (height - gap * 3) / 4));
    else
      buttonH = Math.max(74, Math.min(104, (height - gap * 3) / 4));

    menuScrollViewportTop = y;
    menuScrollCamera = new FlxCamera(0, Std.int(y), Std.int(FlxG.width), Std.int(Math.max(1, height)));
    menuScrollCamera.bgColor = FlxColor.TRANSPARENT;
    menuScrollCamera.scroll.set(0, 0);
    FlxG.cameras.add(menuScrollCamera, false);
    menuScrollViewportHeight = height;
    menuScrollCardHeight = buttonH;
    menuScrollStep = buttonH + gap;

    menuItems = new TextMenuList(NavControls.Vertical);
    menuItems.cameras = [menuScrollCamera];
    menuItems.ignoreTouchPointerSelection = DeviceUtil.isMobileBrowser;
    menuItems.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;

    var iconPlateSize:Float = Math.min(buttonH - 12, portraitLayout ? 58 : (mobileLandscape ? 46 : 72));
    var iconFontSize:Int = mobileLandscape ? 22 : (portraitLayout ? 29 : 34);
    var labelFontSize:Int = mobileLandscape ? 16 : (portraitLayout ? 19 : 24);

    for (index in 0...visibleItemIndexes.length)
    {
      var menuIndex:Int = visibleItemIndexes[index];
      var itemX:Float = x + gap;
      var itemY:Float = index * menuScrollStep;

      var border:FlxSprite = addRoundRect(itemX - 3, itemY - 3, buttonW + 6, buttonH + 6,
        19, 19, 0xFFB968FF, menuScrollCamera);
      border.alpha = 0.16;
      rowBorders.push(border);

      var panel:FlxSprite = addRoundRect(itemX, itemY, buttonW, buttonH, 16, 16,
        0xFF100B1C, menuScrollCamera);
      panel.alpha = 0.96;
      rowBackgrounds.push(panel);

      var tapTarget:FlxObject = new FlxObject(itemX, y + itemY, buttonW, buttonH);
      tapTarget.active = false;
      add(tapTarget);
      rowTapTargets.push(tapTarget);

      var accent:FlxSprite = addRoundRect(itemX + 2, itemY + 12, 5, buttonH - 24,
        3, 3, 0xFFCE74FF, menuScrollCamera);
      accent.alpha = 0.58;
      rowAccents.push(accent);

      var item:TextMenuItem = menuItems.createItem(itemX, itemY, ITEM_NAMES[menuIndex], AtlasFont.BOLD, makeCallback(menuIndex));
      item.cameras = [menuScrollCamera];
      item.makeGraphic(Std.int(buttonW), Std.int(buttonH), FlxColor.TRANSPARENT);
      item.setPosition(itemX, itemY);
      item.origin.set(0, 0);
      item.offset.set(0, 0);
      item.updateHitbox();
      item.scrollFactor.set();
      item.atlasText.alpha = 0;
      item.atlasText.visible = false;

      var iconX:Float = itemX + 15;
      var iconY:Float = itemY + (buttonH - iconPlateSize) * 0.5;
      var iconPlate:FlxSprite = addRoundRect(iconX, iconY, iconPlateSize, iconPlateSize,
        12, 12, 0xFF241333, menuScrollCamera);
      iconPlate.alpha = 0.98;
      rowIconPlates.push(iconPlate);

      var icon:FlxText = addLabel(iconX, iconY, iconPlateSize, ITEM_ICONS[menuIndex],
        iconFontSize, 0xFFCF8AFF, FlxTextAlign.CENTER, 'Arial', menuScrollCamera);
      icon.autoSize = false;
      icon.fieldWidth = iconPlateSize;
      icon.height = iconPlateSize;
      icon.scrollFactor.set();
      rowIcons.push(icon);

      var labelX:Float = iconX + iconPlateSize + 18;
      var labelWidth:Float = buttonW - (labelX - itemX) - 18;
      var title:String = ITEM_TITLES[menuIndex];
      var titleHeight:Float = Math.min(buttonH - 8, labelFontSize + 18);
      var titleY:Float = itemY + (buttonH - titleHeight) * 0.5;
      var label:FlxText = addLabel(labelX, titleY, labelWidth, title,
        labelFontSize, 0xFFF1E8FF, FlxTextAlign.LEFT, Paths.font('vcr.ttf'), menuScrollCamera);
      label.autoSize = false;
      label.wordWrap = false;
      label.fieldWidth = labelWidth;
      label.height = titleHeight;
      label.scrollFactor.set();
      rowLabels.push(label);

      // The first NovaBeat menu entry uses the user-provided Sparrow atlas.
      // Keep the existing card panel as a fallback/backplate, but hide the
      // generic icon and label so the custom artwork is the visible control.
      if (menuIndex == 0)
      {
        iconPlate.alpha = 0;
        icon.alpha = 0;
        label.alpha = 0;

        var storyArtwork:FlxSprite = new FlxSprite();
        storyArtwork.frames = Paths.getSparrowAtlas('story_mode_sheet');
        storyArtwork.animation.addByPrefix('idle', 'story mode idle', 24, true);
        storyArtwork.animation.addByPrefix('selected', 'story mode selected', 24, true);
        storyArtwork.animation.addByPrefix('click', 'story mode click', 24, false);
        storyArtwork.animation.play('idle', true);
        var artworkScale:Float = Math.min(buttonW / storyArtwork.width, buttonH / storyArtwork.height);
        storyArtwork.setGraphicSize(Std.int(storyArtwork.width * artworkScale), Std.int(storyArtwork.height * artworkScale));
        storyArtwork.updateHitbox();
        storyArtwork.setPosition(itemX + (buttonW - storyArtwork.width) * 0.5,
          itemY + (buttonH - storyArtwork.height) * 0.5);
        storyArtwork.antialiasing = true;
        storyArtwork.scrollFactor.set();
        storyArtwork.cameras = [menuScrollCamera];
        add(storyArtwork);
        rowArtwork.push(storyArtwork);
      }

        if (Save.instance.options.menuEntryAnimations && !Save.instance.options.menuReduceMotion)
      {
        var delay:Float = index * (menuEntrancePending ? 0.065 : 0.075);
        var duration:Float = menuEntrancePending ? 0.50 : 0.30;
        var startX:Float = menuEntrancePending ? -buttonW - 48 : itemX - 34;
        var shift:Float = startX - itemX;

        border.x += shift;
        panel.x += shift;
        accent.x += shift;
        iconPlate.x += shift;
        icon.x += shift;
        label.x += shift;
        item.x += shift;

        if (menuEntrancePending && menuIndex == 0 && rowArtwork.length > 0)
          rowArtwork[rowArtwork.length - 1].x += shift;

        if (!menuEntrancePending)
        {
          border.alpha = 0;
          panel.alpha = 0;
          accent.alpha = 0;
          iconPlate.alpha = 0;
          icon.alpha = 0;
          label.alpha = 0;
        }

        FlxTween.tween(border, {x: itemX - 3}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        FlxTween.tween(panel, {x: itemX}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        FlxTween.tween(accent, {x: itemX + 2}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        FlxTween.tween(iconPlate, {x: iconX, alpha: menuIndex == 0 ? 0 : 0.98}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        FlxTween.tween(icon, {x: iconX, alpha: menuIndex == 0 ? 0 : 1}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        FlxTween.tween(label, {x: labelX, alpha: menuIndex == 0 ? 0 : 1}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        FlxTween.tween(item, {x: itemX}, duration, {ease: FlxEase.quadOut, startDelay: delay});

        if (menuEntrancePending && menuIndex == 0 && rowArtwork.length > 0)
        {
          var artwork:FlxSprite = rowArtwork[rowArtwork.length - 1];
          var artworkTargetX:Float = artwork.x - shift;
          FlxTween.tween(artwork, {x: artworkTargetX}, duration, {ease: FlxEase.quadOut, startDelay: delay});
        }
      }
    }

    menuItems.onChange.add(function(selected:TextMenuItem)
    {
      updateSelection(menuItems.selectedIndex);
    });

    add(menuItems);
    syncMenuTapTargets();
    updateSelection(0);
    menuEntrancePending = false;
  }

  function buildFeaturePanel(x:Float, y:Float, width:Float, height:Float):Void
  {
    addPanel(x, y, width, height, 0xFF6982C4);

    // Draw the animated bars first so every panel label, pill, and accent sits above them.
    if (Save.instance.options.menuShowEqualizer)
    {
      buildEqualizer(x + 34, y + height - 136, width - 68);
    }

    // Keep the feature panel clean, showing the selected title only.
    featureTitle = addLabel(x + 34, y + 104, width - 68, ITEM_NAMES[0], 28, 0xFFF4F7FF, FlxTextAlign.LEFT, 'Arial Black');

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
    if (index < 0 || index >= visibleItemIndexes.length) return;

    for (i in 0...visibleItemIndexes.length)
    {
      var selected:Bool = i == index;
      if (i < rowBorders.length)
      {
        rowBorders[i].alpha = selected ? 0.96 : 0.12;
        rowBorders[i].color = selected ? 0xFFE38CFF : 0xFF8C4CC7;
      }
      if (i < rowBackgrounds.length)
      {
        rowBackgrounds[i].color = selected ? 0xFF25133A : 0xFF100B1C;
        rowBackgrounds[i].alpha = selected ? 1.0 : 0.88;
      }
      if (i < rowIconPlates.length)
      {
        rowIconPlates[i].color = selected ? 0xFF3B1B58 : 0xFF241333;
        rowIconPlates[i].alpha = selected ? 1.0 : 0.90;
      }
      if (i < rowAccents.length)
      {
        rowAccents[i].color = selected ? 0xFFE077FF : 0xFF9B54D0;
        rowAccents[i].alpha = selected ? 1.0 : 0.42;
      }
      if (i < rowLabels.length)
        rowLabels[i].color = selected ? 0xFFFFFFFF : 0xFFD5C4E8;
      if (i < rowIcons.length)
        rowIcons[i].color = selected ? 0xFFFFA4FF : 0xFFB783D9;
      if (i == 0 && rowArtwork.length > 0 && rowArtwork[0] != null)
        rowArtwork[0].animation.play(selected ? 'selected' : 'idle', true);
    }

    var selectedMenuIndex:Int = visibleItemIndexes[index];
    if (featureTitle != null) featureTitle.text = ITEM_NAMES[selectedMenuIndex];
    scrollMenuSelectionIntoView(index);
  }

  function scrollMenuSelectionIntoView(index:Int):Void
  {
    if (menuScrollCamera == null || menuScrollStep <= 0) return;
    var target:Float = menuScrollCamera.scroll.y;
    var itemTop:Float = index * menuScrollStep;
    var itemBottom:Float = itemTop + menuScrollCardHeight;
    if (itemTop < target)
      target = itemTop;
    else if (itemBottom > target + menuScrollViewportHeight)
      target = itemBottom - menuScrollViewportHeight;
    var totalHeight:Float = visibleItemIndexes.length * menuScrollStep;
    var maxScroll:Float = Math.max(0, totalHeight - menuScrollViewportHeight);
    target = Math.max(0, Math.min(maxScroll, target));
    if (Math.abs(target - menuScrollCamera.scroll.y) < 1) return;
    FlxTween.cancelTweensOf(menuScrollCamera.scroll);
    FlxTween.tween(menuScrollCamera.scroll, {y: target}, 0.24, {ease: FlxEase.quadOut});
  }

  function syncMenuTapTargets():Void
  {
    if (menuScrollCamera == null || rowTapTargets.length == 0) return;

    final viewportTop:Float = menuScrollViewportTop;
    final viewportBottom:Float = viewportTop + menuScrollViewportHeight;
    final scrollY:Float = menuScrollCamera.scroll.y;

    for (index in 0...rowTapTargets.length)
    {
      if (index >= rowBackgrounds.length) continue;
      final card:FlxSprite = rowBackgrounds[index];
      final target:FlxObject = rowTapTargets[index];
      final cardScreenTop:Float = viewportTop + card.y - scrollY;
      final visibleTop:Float = Math.max(viewportTop, cardScreenTop);
      final visibleBottom:Float = Math.min(viewportBottom, cardScreenTop + card.height);
      final visibleHeight:Float = visibleBottom - visibleTop;

      target.visible = visibleHeight > 0;
      if (target.visible)
      {
        target.setPosition(card.x, visibleTop);
        target.setSize(card.width, visibleHeight);
      }
    }
  }

  function handleMobileMenuCardInput():Void
  {
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (!DeviceUtil.isMobileBrowser || menuItems == null || menuItems.busy) return;

    for (index in 0...rowTapTargets.length)
    {
      final target:FlxObject = rowTapTargets[index];
      if (!target.exists || !target.visible) continue;

      var tapped:Bool = TouchUtil.pressAction(target, uiCamera, false);
      #if web
      if (!tapped && FlxG.mouse.justReleased)
        tapped = FlxG.mouse.overlaps(target, uiCamera);
      #end

      if (!tapped || SwipeUtil.justSwipedAny) continue;

      menuItems.selectItem(index);
      playSfx('select', 0.45);
      menuItems.accept();
      return;
    }
    #end
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    syncMenuTapTargets();

    if (FlxG.mouse.visible) Cursor.hide();

    if (showingTitle)
    {
      updateTitleDissolveFrameInfo();
      var pressed:Bool = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;
      var gamepad = FlxG.gamepads.lastActive;
      if (gamepad != null && (gamepad.justPressed.START || gamepad.justPressed.ACCEPT)) pressed = true;
      // Use the same release-based mobile confirm used by the original FNF menus.
      #if (mobile || FEATURE_TOUCH_CONTROLS)
      var touchPressAction:Bool = TouchUtil.pressAction();
      #if web
      touchPressAction = touchPressAction || (DeviceUtil.isMobileBrowser && FlxG.mouse.justReleased);
      #end
      if (DeviceUtil.isMobileBrowser && touchPressAction && !SwipeUtil.justSwipedAny) pressed = true;
      #end

      if (pressed) beginMenuTransition();
      return;
    }

    if (transitioning) return;

    handleHeaderPointerInput();
    handleMobileMenuCardInput();

    // Mobile swipes and desktop mouse-wheel input move the selected row; the
    // selection handler eases the clipped list camera to keep that row visible.
    if (menuItems != null && !menuItems.busy)
    {
      if (DeviceUtil.isMobileBrowser && SwipeUtil.justSwipedUp)
        menuItems.selectItem(Std.int(Math.min(menuItems.length - 1, menuItems.selectedIndex + 1)));
      else if (DeviceUtil.isMobileBrowser && SwipeUtil.justSwipedDown)
        menuItems.selectItem(Std.int(Math.max(0, menuItems.selectedIndex - 1)));
      var wheelAmount:Int = Math.round(FlxG.mouse.deltaWheel.y);
      if (wheelAmount != 0)
      {
        var nextIndex:Int = menuItems.selectedIndex - wheelAmount;
        menuItems.selectItem(Std.int(Math.max(0, Math.min(menuItems.length - 1, nextIndex))));
      }
    }

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

    if (!transitioning && !options.menuReduceMotion && options.menuAnimatedBackground && backgroundSprite != null)
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
      addBackButton(18, FlxG.height - 78, FlxColor.WHITE, goBackToTitle, 1.0);
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
    if (!DeviceUtil.isMobileBrowser) return;

    var optionsPressed:Bool = false;
    if (homeOptionsHitbox != null)
    {
      optionsPressed = TouchUtil.pressAction(homeOptionsHitbox, uiCamera);
      #if web
      if (!optionsPressed && FlxG.mouse.justReleased)
        optionsPressed = FlxG.mouse.overlaps(homeOptionsHitbox, uiCamera);
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
      audioPressed = TouchUtil.pressAction(homeAudioHitbox, uiCamera);
      #if web
      if (!audioPressed && FlxG.mouse.justReleased)
        audioPressed = FlxG.mouse.overlaps(homeAudioHitbox, uiCamera);
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
          if (rowArtwork.length > 0 && rowArtwork[0] != null)
          {
            rowArtwork[0].animation.play('click', true);
            FlxTimer.wait(0.18, function() FlxG.switchState(() -> new StoryMenuState()));
          }
          else
          {
            FlxG.switchState(() -> new StoryMenuState());
          }
        case 1:
          openSubState(new FreeplayState({
            character: FreeplayState.rememberedCharacterId,
            psychOnly: ExperienceManager.hasActivePsychSongs()
          }));
          persistentUpdate = false;
        case 2:
          openOptions();
        case 3:
          FlxG.switchState(() -> new NovaBeatModsMenuState());
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

  function addRoundRect(
    x:Float,
    y:Float,
    width:Float,
    height:Float,
    radiusX:Float,
    radiusY:Float,
    color:FlxColor,
    camera:FlxCamera = null
  ):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
    // FlxSpriteUtil draws into sprite.pixels; a fresh FlxSprite has no bitmap yet.
    // Allocate a transparent buffer before drawing, preserving the rounded-corner shape.
    sprite.makeGraphic(Std.int(Math.max(1, Math.ceil(width))), Std.int(Math.max(1, Math.ceil(height))), FlxColor.TRANSPARENT);
    FlxSpriteUtil.drawRoundRect(sprite, 0, 0, width, height, radiusX, radiusY, color);
    // All rounded panels/plates are backgrounds. Keep their render depth
    // below labels, icons, and transparent menu hit targets.
    sprite.zIndex = -10;
    sprite.scrollFactor.set();
    sprite.cameras = [camera == null ? uiCamera : camera];
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
    fontName:String = 'Arial',
    camera:FlxCamera = null
  ):FlxText
  {
    var scaledSize:Int = Std.int(Math.max(8, size * interfaceScale() * (Save.instance.options.menuLargeText ? 1.12 : 1.0)));
    var label:FlxText = new FlxText(x, y, width, value, scaledSize);
    if (fontName == Paths.font('vcr.ttf'))
    {
      label.setFormat(fontName, scaledSize, color, alignment, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
      label.borderSize = Math.max(2, scaledSize * 0.08);
    }
    else
    {
      label.setFormat(fontName, scaledSize, color, alignment, null, FlxColor.TRANSPARENT, false);
    }
    label.scrollFactor.set();
    label.cameras = [camera == null ? uiCamera : camera];
    add(label);
    return label;
  }

  function updateTitleDissolveFrameInfo():Void
  {
    if (titleLogoDissolveShader != null && titleLogo != null)
      titleLogoDissolveShader.updateFrame(titleLogo.frame);

    if (titlePromptDissolveShader != null && titlePrompt != null)
      titlePromptDissolveShader.updateFrame(titlePrompt.frame);
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
