package funkin.ui.mainmenu;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
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
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.MenuList.NavControls;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.ui.MusicBeatState;
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

  // Each supplied button atlas is a 543x724 frame. These normalized bounds
  // describe the visible button artwork inside that transparent frame, and
  // are shared by layout, desktop item hitboxes, and mobile touch targets.
  static inline final MENU_BUTTON_FRAME_WIDTH:Float = 543;
  static inline final MENU_BUTTON_FRAME_HEIGHT:Float = 724;
  static inline final MENU_BUTTON_ART_LEFT:Float = 0.02;
  static inline final MENU_BUTTON_ART_TOP:Float = 0.34;
  static inline final MENU_BUTTON_ART_WIDTH:Float = 0.96;
  static inline final MENU_BUTTON_ART_HEIGHT:Float = 0.32;
  static inline final MENU_BUTTON_HEIGHT_RATIO:Float = 0.22;



  var uiCamera:FlxCamera;
  var interfaceLayer:FlxTypedGroup<FlxBasic>;
  var routeInterfaceObjects:Bool = false;
  var menuItems:TextMenuList;
  // Indexes into the menu content arrays, kept separate for callback mapping.
  var visibleItemIndexes:Array<Int> = [];
  var showTitleOnCreate:Bool;
  var showingTitle:Bool = false;
  var titleInputCooldown:Float = 0;
  var compactLayout:Bool = false;
  var animationClock:Float = 0;

  var backgroundSprite:Null<FlxSprite>;
  var backgroundDimmer:Null<FlxSprite>;
  var titleLogo:Null<FlxSprite>;
  var titlePrompt:Null<FlxSprite>;
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

  public function new(showTitle:Bool = false, returningFromMenu:Bool = false)
  {
    super();
    showTitleOnCreate = showTitle;
    // The confirm/back input that created this state must not also dismiss
    // the title screen. Require a fresh input after this short handoff guard.
    titleInputCooldown = returningFromMenu ? 0.75 : 0.0;
  }

  override function create():Void
  {
    // Story/Options can disable raw keyboard input before switching states.
    FlxG.keys.enabled = true;
    Cursor.hide();
    // Use the same screen-transition pair as the original FNF main menu.
    transIn = FlxTransitionableState.defaultTransIn;
    transOut = FlxTransitionableState.defaultTransOut;
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
    if (interfaceLayer == null) return;

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

    // This is the supplied NovaBeat background, staged under its own namespace.
    // Never fall back to the original FNF "Bg" asset or modify it.
    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image('novabeat/Bg'));
    var backgroundScale:Float = Math.max(width / background.width, height / background.height);
    background.scale.set(backgroundScale, backgroundScale);
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    background.cameras = [uiCamera];
    background.color = FlxColor.WHITE;
    background.zIndex = -100;
    backgroundSprite = background;
    backgroundDimmer = null;
    add(background);
  }

  function buildTitleScreen():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;
    var portraitLayout:Bool = height > width * 1.12;

    // The same background remains visible at identical scale, position and
    // brightness for the entire title-to-menu transition. No flash overlay.
    // Load the NovaBeat Bumpin atlas from its own namespace. This prevents
    // the original FNF logo atlas from being replaced or modified.
    var logo:FlxSprite = new FlxSprite();
    logo.frames = Paths.getSparrowAtlas('novabeat/logoBumpin');
    logo.animation.addByPrefix('idle', 'logo bumpin', 6, true);
    logo.animation.play('idle', true);
    logo.antialiasing = true;
    // The reference uses a large, dominant Bumpin mark. Fit by both axes
    // while preserving the atlas aspect ratio; never stretch or crop it.
    var maxLogoWidth:Float = width * (portraitLayout ? 0.94 : 0.96) * interfaceScale();
    var maxLogoHeight:Float = height * (portraitLayout ? 0.48 : 0.63) * interfaceScale();
    var logoFit:Float = Math.max(0.01, Math.min(maxLogoWidth / logo.width, maxLogoHeight / logo.height));
    logo.setGraphicSize(Std.int(logo.width * logoFit), Std.int(logo.height * logoFit));
    logo.updateHitbox();
    logo.x = Math.round((width - logo.width) * 0.5);
    logo.y = height * (portraitLayout ? 0.31 : 0.36) - logo.height * 0.5;
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];
    titleLogo = logo;
    add(logo);

    // Use the requested press-enter atlas. Frame 0000 is the static idle
    // frame; frames 0001-0003 are played once as the pressed animation.
    var prompt:FlxSprite = new FlxSprite();
    prompt.frames = Paths.getSparrowAtlas('novabeat/press-enter');
    prompt.animation.addByIndices('idle', 'pressEnter', [0], '', 12, true);
    prompt.animation.play('idle', true);
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
    if (!showingTitle) return;

    // Match FNF's state-to-state handoff instead of cutting directly between
    // the title and menu. Both states use the standard FNF transition pair.
    playSfx('enter', 0.8);
    FlxG.switchState(() -> new NovaBeatMainMenuState(false));
  }

  function removeTitleScreen():Void
  {
    if (titlePrompt != null) remove(titlePrompt, true);
    if (titleLogo != null) remove(titleLogo, true);
    titlePrompt = null;
    titleLogo = null;
  }

  function buildInterface():Void
  {
    var screenW:Int = FlxG.width;
    var screenH:Int = FlxG.height;
    var portraitLayout:Bool = screenH > screenW * 1.12;
    compactLayout = DeviceUtil.isMobileBrowser || screenW < 950 || portraitLayout;

    if (backgroundSprite == null) buildBackdrop();

    var margin:Float = Math.max(18, screenW * 0.035);
    buildTopBar(margin);

    if (portraitLayout)
    {
      // In portrait, keep the brand above a full-width vertical button stack.
      buildMenuBrandLogo(screenW, screenH, true);
      // Reserve a clear bottom-right corner for the mobile Back control.
      // The previous 70%-height list extended behind the Back button and
      // let the last menu tile compete with its hitbox on portrait screens.
      buildMenuList(screenW * 0.07, screenH * 0.24, screenW * 0.86, screenH * 0.60, false);
    }
    else
    {
      // Landscape uses the same vertical navigation on the left, leaving the
      // right side open for the large Bumpin brand mark.
      buildMenuBrandLogo(screenW, screenH, false);
      buildMenuList(screenW * 0.045, screenH * 0.04, screenW * 0.42, screenH * 0.92, false);
    }
  }

  function buildMenuBrandLogo(screenW:Float, screenH:Float, portraitLayout:Bool):Void
  {
    var logo:FlxSprite = new FlxSprite();
    logo.frames = Paths.getSparrowAtlas('novabeat/logoBumpin');
    logo.animation.addByPrefix('idle', 'logo bumpin', 6, true);
    logo.animation.play('idle', true);
    logo.antialiasing = true;
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];

    var maxWidth:Float = screenW * (portraitLayout ? 0.80 : 0.46);
    var maxHeight:Float = screenH * (portraitLayout ? 0.16 : 0.38);
    var scale:Float = Math.min(maxWidth / Math.max(1, logo.width), maxHeight / Math.max(1, logo.height));
    logo.scale.set(scale, scale);
    logo.updateHitbox();

    if (portraitLayout)
    {
      logo.x = (screenW - logo.width) * 0.5;
      logo.y = screenH * 0.065;
    }
    else
    {
      logo.x = screenW * 0.53 + (screenW * 0.42 - logo.width) * 0.5;
      logo.y = screenH * 0.47 - logo.height * 0.5;
    }
    add(logo);
  }

  function buildTopBar(margin:Float):Void
  {
    var buttonSize:Float = FlxG.height > FlxG.width * 1.12 ? 38 : 46;
    var buttonX:Float = FlxG.width - margin - buttonSize;
    var buttonY:Float = Math.max(14, FlxG.height * 0.025);

    homeAudioButton = addLabel(buttonX, buttonY, buttonSize, menuAudioMuted ? '♪' : '♫',
      buttonSize > 42 ? 25 : 21, 0xFFFFFFFF, FlxTextAlign.CENTER, 'Arial');
    homeAudioHitbox = addSolid(buttonX, buttonY, buttonSize, buttonSize, 0x00000000);
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
    // The reference's navigation order is Story, Freeplay, Mods, Options.
    // Item IDs remain mapped to the existing gameplay callbacks.
    visibleItemIndexes = [0, 1, 3, 2];

    final frameWidth:Float = MENU_BUTTON_FRAME_WIDTH;
    final frameHeight:Float = MENU_BUTTON_FRAME_HEIGHT;
    final artLeft:Float = MENU_BUTTON_ART_LEFT;
    final artTop:Float = MENU_BUTTON_ART_TOP;
    final artWidth:Float = MENU_BUTTON_ART_WIDTH;
    final artHeight:Float = MENU_BUTTON_ART_HEIGHT;
    final artAspect:Float = (frameWidth * artWidth) / (frameHeight * artHeight);

    var gap:Float = Math.max(6, Math.min(18, FlxG.height * 0.012));
    var availableArtHeight:Float = Math.max(1, (height - gap * 3) / 4);
    // Match the supplied reference proportions at the 1280x720 design size,
    // then scale proportionally with the viewport while preserving the art ratio.
    var targetArtHeight:Float = Math.min(height * MENU_BUTTON_HEIGHT_RATIO, availableArtHeight);
    var targetArtWidth:Float = targetArtHeight * artAspect;
    var maxArtWidth:Float = Math.max(1, width * 0.96);
    if (targetArtWidth > maxArtWidth)
    {
      targetArtWidth = maxArtWidth;
      targetArtHeight = targetArtWidth / artAspect;
    }

    var buttonScale:Float = targetArtWidth / (frameWidth * artWidth);
    var scaledFrameWidth:Float = frameWidth * buttonScale;
    var scaledFrameHeight:Float = frameHeight * buttonScale;
    var listHeight:Float = targetArtHeight * 4 + gap * 3;
    var firstArtY:Float = y + Math.max(0, (height - listHeight) * 0.5);
    var firstArtX:Float = x + (width - targetArtWidth) * 0.5;

    menuScrollCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
    menuScrollCamera.bgColor = FlxColor.TRANSPARENT;
    menuScrollCamera.scroll.set(0, 0);
    FlxG.cameras.add(menuScrollCamera, false);
    menuScrollViewportTop = 0;
    menuScrollViewportHeight = FlxG.height;
    menuScrollCardHeight = targetArtHeight;
    menuScrollStep = targetArtHeight + gap;

    menuItems = new TextMenuList(NavControls.Vertical);
    menuItems.cameras = [menuScrollCamera];
    menuItems.ignoreTouchPointerSelection = DeviceUtil.isMobileBrowser;
    menuItems.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;

    var atlasPaths:Array<String> = [
      'novabeat/story-mode-button',
      'novabeat/freeplay-button',
      'novabeat/options-button',
      'novabeat/mods-button'
    ];
    var framePrefixes:Array<String> = ['storymode', 'freeplay', 'options', 'mods'];

    for (index in 0...visibleItemIndexes.length)
    {
      var menuIndex:Int = visibleItemIndexes[index];
      var artX:Float = firstArtX;
      var artY:Float = firstArtY + index * menuScrollStep;
      var spriteX:Float = artX - scaledFrameWidth * artLeft;
      var spriteY:Float = artY - scaledFrameHeight * artTop;

      var button:FlxSprite = new FlxSprite();
      button.frames = Paths.getSparrowAtlas(atlasPaths[menuIndex]);
      var prefix:String = framePrefixes[menuIndex];
      button.animation.addByIndices('idle', prefix, [0], '', 24, true);
      button.animation.addByIndices('selected', prefix, [1], '', 24, true);
      button.animation.addByIndices('pressed', prefix, [2, 3], '', 24, false);
      button.animation.play('idle', true);
      button.scale.set(buttonScale, buttonScale);
      button.updateHitbox();
      button.setPosition(spriteX, spriteY);
      button.antialiasing = true;
      button.scrollFactor.set();
      button.cameras = [menuScrollCamera];
      add(button);
      rowArtwork.push(button);

      var tapTarget:FlxObject = new FlxObject(artX, artY, targetArtWidth, targetArtHeight);
      tapTarget.active = false;
      tapTarget.scrollFactor.set();
      tapTarget.cameras = [uiCamera];
      add(tapTarget);
      rowTapTargets.push(tapTarget);

      var item:TextMenuItem = menuItems.createItem(artX, artY, ITEM_NAMES[menuIndex], AtlasFont.BOLD, makeCallback(menuIndex));
      item.cameras = [menuScrollCamera];
      item.makeGraphic(Std.int(Math.ceil(targetArtWidth)), Std.int(Math.ceil(targetArtHeight)), FlxColor.TRANSPARENT);
      item.setPosition(artX, artY);
      item.origin.set(0, 0);
      item.offset.set(0, 0);
      item.updateHitbox();
      item.scrollFactor.set();
      item.atlasText.alpha = 0;
      item.atlasText.visible = false;

    }

    menuItems.onChange.add(function(selected:TextMenuItem)
    {
      updateSelection(menuItems.selectedIndex);
    });

    add(menuItems);
    syncMenuTapTargets();
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

    for (i in 0...rowArtwork.length)
    {
      if (rowArtwork[i] == null) continue;
      rowArtwork[i].animation.play(i == index ? 'selected' : 'idle', true);
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
      if (index >= rowArtwork.length) continue;
      final button:FlxSprite = rowArtwork[index];
      final target:FlxObject = rowTapTargets[index];

      // The touch target tracks the visible artwork, not the full transparent
      // atlas frame. Use the same normalized bounds used to place and scale it.
      final artLeft:Float = button.x + button.width * MENU_BUTTON_ART_LEFT;
      final artTop:Float = button.y + button.height * MENU_BUTTON_ART_TOP;
      final artRight:Float = artLeft + button.width * MENU_BUTTON_ART_WIDTH;
      final artBottom:Float = artTop + button.height * MENU_BUTTON_ART_HEIGHT;
      final screenTop:Float = viewportTop + artTop - scrollY;
      final screenBottom:Float = viewportTop + artBottom - scrollY;
      final clippedLeft:Float = Math.max(0, artLeft);
      final clippedRight:Float = Math.min(FlxG.width, artRight);
      final clippedTop:Float = Math.max(viewportTop, screenTop);
      final clippedBottom:Float = Math.min(viewportBottom, screenBottom);
      final clippedWidth:Float = clippedRight - clippedLeft;
      final clippedHeight:Float = clippedBottom - clippedTop;

      target.visible = clippedWidth > 0 && clippedHeight > 0;
      if (target.visible)
      {
        target.setPosition(clippedLeft, clippedTop);
        target.setSize(clippedWidth, clippedHeight);
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
      if (titleInputCooldown > 0)
      {
        titleInputCooldown = Math.max(0, titleInputCooldown - elapsed);
        return;
      }
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
    {
      // Anchor to the actual viewport, leaving a clean inset from both edges.
      // On very narrow/short mobile viewports, scale the control down first so
      // the visible button and its own hitbox remain entirely on-screen.
      var marginX:Float = Math.max(12, Math.min(28, Math.min(FlxG.width, FlxG.height) * 0.035));
      var marginY:Float = marginX;
      addBackButton(0, 0, FlxColor.WHITE, goBackToTitle, 1.0);
      if (backButton != null)
      {
        backButton.scrollFactor.set();
        // Use the same screen-space camera as the NovaBeat UI so the bottom-right
        // anchor and hit area follow the actual mobile viewport.
        backButton.cameras = [uiCamera];
        var availableWidth:Float = Math.max(1, FlxG.width - marginX * 2);
        var availableHeight:Float = Math.max(1, FlxG.height - marginY * 2);
        var fitScale:Float = Math.min(1.0,
          Math.min(availableWidth / Math.max(1, backButton.width), availableHeight / Math.max(1, backButton.height)));
        if (fitScale < 1.0)
        {
          backButton.scale.set(backButton.scale.x * fitScale, backButton.scale.y * fitScale);
          backButton.updateHitbox();
        }

        var backX:Float = FlxG.width - backButton.width - marginX;
        var backY:Float = FlxG.height - backButton.height - marginY;
        backButton.setPosition(Math.max(marginX, backX), Math.max(marginY, backY));
      }
    }
    #end
  }

  function goBackToTitle():Void
  {
    // The mobile browser's pointer bridge retains a completed tap until a UI
    // surface consumes it. FunkinBackButton handles the same release through
    // FlxMouse, so consume its queued copy before the title screen can mistake
    // it for a fresh Enter press.
    #if web
    if (DeviceUtil.isMobileBrowser) TouchUtil.pressAction();
    #end

    playSfx('back', 0.7);
    FlxG.switchState(() -> new NovaBeatMainMenuState(true, true));
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
      var visualIndex:Int = visibleItemIndexes.indexOf(index);
      if (visualIndex >= 0 && visualIndex < rowArtwork.length && rowArtwork[visualIndex] != null)
        rowArtwork[visualIndex].animation.play('pressed', true);

      switch (index)
      {
        case 0:
          FlxTimer.wait(0.18, function() FlxG.switchState(() -> new StoryMenuState()));
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
