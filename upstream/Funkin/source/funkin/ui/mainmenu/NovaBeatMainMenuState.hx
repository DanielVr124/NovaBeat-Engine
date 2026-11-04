package funkin.ui.mainmenu;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxTextAlign;
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
import funkin.ui.story.StoryMenuState;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.credits.CreditsState;
import funkin.ui.options.OptionsState;
#if mobile
import funkin.util.TouchUtil;
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
    'MOD MANAGER',
    'OPTIONS',
    'CREDITS'
  ];

  static final ITEM_ICONS:Array<String> = ['▤', '⌘', '✣', '⚙', '▣'];

  static final ITEM_TITLES:Array<String> = [
    'STORY\nMODE',
    'FREEPLAY',
    'MOD\nMANAGER',
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

  static final ITEM_META:Array<Array<String>> = [
    ['CAMPAIGN', 'WEEK SELECT', 'DIFFICULTY'],
    ['SONG LIBRARY', 'DIFFICULTY', 'FAVORITES'],
    ['INSTALLED', 'LOCAL LIBRARY', 'LOAD ORDER'],
    ['AUDIO', 'GAMEPLAY', 'CUSTOMIZATION'],
    ['ENGINE', 'FOUNDATION', 'CREDITS']
  ];

  var uiCamera:FlxCamera;
  var menuItems:TextMenuList;
  var showTitleOnCreate:Bool;
  var showingTitle:Bool = false;
  var transitioning:Bool = false;
  var compactLayout:Bool = false;
  var animationClock:Float = 0;

  var backgroundSprite:Null<FlxSprite>;
  var titleLogo:Null<FlxSprite>;
  var titlePrompt:Null<FlxText>;
  var titleTapHint:Null<FlxText>;
  var titleOptionsButton:Null<FlxText>;
  var homeAudioButton:Null<FlxText>;
  var homeOptionsButton:Null<FlxText>;

  var rowBackgrounds:Array<FlxSprite> = [];
  var rowAccents:Array<FlxSprite> = [];
  var rowLabels:Array<FlxText> = [];
  var rowIcons:Array<FlxText> = [];

  var featureTitle:Null<FlxText>;
  var featureDescription:Null<FlxText>;
  var featureKicker:Null<FlxText>;
  var featureMeta:Array<FlxText> = [];

  var equalizerBars:Array<FlxSprite> = [];
  var equalizerBaseY:Array<Float> = [];
  var equalizerBaseHeight:Array<Float> = [];

  public function new(showTitle:Bool = false)
  {
    super();
    showTitleOnCreate = showTitle;
  }

  override function create():Void
  {
    FlxG.cameras.reset(new FunkinCamera('novaBeatMainMenu'));
    uiCamera = new FunkinCamera('novaBeatMenuUI');
    FlxG.cameras.add(uiCamera, false);
    uiCamera.bgColor = 0x00000000;

    super.create();

    showingTitle = showTitleOnCreate;
    persistentUpdate = true;
    persistentDraw = true;

    if (showTitleOnCreate)
    {
      playMenuTheme(true, 0.0);
      if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(4.0, 0.0, 0.82);
      buildBackdrop();
      buildTitleScreen();
    }
    else
    {
      playMenuTheme(false, 0.82);
      buildInterface();
    }
  }

  function buildBackdrop():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;

    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image('novabeat/menu-background'));
    var backgroundScale:Float = Math.max(width / background.width, height / background.height);
    background.scale.set(backgroundScale, backgroundScale);
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    background.cameras = [uiCamera];
    backgroundSprite = background;
    add(background);

    // The V4 reference keeps the background visible but subdued behind the UI.
    addSolid(0, 0, width, height, 0x8D050817);
    addSolid(0, height * 0.72, width, height * 0.28, 0x3902081C);
  }

  function buildTitleScreen():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;
    var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('novabeat/title-logo'));
    logo.setGraphicSize(0, Std.int(height * 0.54));
    logo.updateHitbox();
    logo.x = (width - logo.width) * 0.5;
    logo.y = height * 0.43 - logo.height * 0.5;
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];
    titleLogo = logo;
    add(logo);

    titlePrompt = addLabel(0, height * 0.865, width, 'PRESS ENTER TO BEGIN', titlePromptSize(), 0xFFFFFFFF, FlxTextAlign.CENTER, 'Arial Black');
    titleTapHint = addLabel(0, height * 0.915, width, 'OR TAP ANYWHERE TO START', 12, 0xFF9FB7E6, FlxTextAlign.CENTER, 'Arial');

    addRoundRect(width - 86, 25, 48, 48, 15, 15, 0xB806102D);
    titleOptionsButton = addLabel(width - 86, 30, 48, '⚙', 24, 0xFFDCE8FF, FlxTextAlign.CENTER, 'Arial');
    titleOptionsButton.alpha = 0.9;
    titleOptionsButton.scrollFactor.set();
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
    if (titleOptionsButton != null) remove(titleOptionsButton, true);

    titleLogo = null;
    titlePrompt = null;
    titleTapHint = null;
    titleOptionsButton = null;
  }

  function buildInterface():Void
  {
    var screenW:Int = FlxG.width;
    var screenH:Int = FlxG.height;
    compactLayout = screenW < 950 || screenH > screenW * 1.12;

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
      addLabel(navX, frameY + frameH - 26, navW, 'TAP A TILE TO SELECT   •   ENTER TO OPEN', 9, 0xFF8DA8D8, FlxTextAlign.LEFT, 'Arial');
    }
  }

  function buildTopBar(margin:Float):Void
  {
    var logo:FlxSprite = new FlxSprite(margin, 12).loadGraphic(Paths.image('novabeat/title-logo'));
    logo.setGraphicSize(0, 78);
    logo.updateHitbox();
    logo.scrollFactor.set();
    logo.cameras = [uiCamera];
    add(logo);

    var buttonY:Float = 25;
    homeAudioButton = addLabel(FlxG.width - margin - 118, buttonY, 48, '♫', 25, 0xFFDCE8FF, FlxTextAlign.CENTER, 'Arial');
    homeOptionsButton = addLabel(FlxG.width - margin - 58, buttonY, 48, '⚙', 25, 0xFFDCE8FF, FlxTextAlign.CENTER, 'Arial');

    addRoundRect(FlxG.width - margin - 118, buttonY - 3, 48, 48, 15, 15, 0xB806102D);
    addRoundRect(FlxG.width - margin - 58, buttonY - 3, 48, 48, 15, 15, 0xB806102D);
    // Draw the glyphs after their button plates so they stay on top.
    bringToFront(homeAudioButton);
    bringToFront(homeOptionsButton);
  }

  function bringToFront(sprite:FlxSprite):Void
  {
    remove(sprite, false);
    add(sprite);
  }

  function buildMenuList(x:Float, y:Float, width:Float, height:Float, tileLayout:Bool):Void
  {
    var gap:Float = (tileLayout ? Math.max(8, FlxG.width * 0.018) : Math.max(9, FlxG.height * 0.018));
    gap *= densityMultiplier();

    var buttonW:Float = tileLayout ? (width - gap * 3) / 2 : width - 20;
    var buttonH:Float;
    if (tileLayout)
    {
      buttonH = Math.max(48, Math.min(78, (height - gap * 2) / 3));
    }
    else
    {
      buttonH = Math.max(54, Math.min(82, (height - gap * 4) / 5));
    }

    var firstX:Float = tileLayout ? x + gap : x + 6;
    var firstY:Float = y + (tileLayout ? 0 : 10);

    menuItems = new TextMenuList(tileLayout ? NavControls.Columns(2) : NavControls.Vertical);
    menuItems.cameras = [uiCamera];

    for (index in 0...ITEM_NAMES.length)
    {
      var column:Int = tileLayout ? index % 2 : 0;
      var row:Int = tileLayout ? Std.int(index / 2) : index;
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
      item.atlasText.alpha = 0;

      var iconSize:Int = tileLayout ? 22 : 26;
      var iconX:Float = itemX + (tileLayout ? 12 : 20);
      var iconY:Float = itemY + (buttonH - iconSize) * 0.5 - 2;
      var icon:FlxText = addLabel(iconX, iconY, 36, ITEM_ICONS[index], iconSize, 0xFF8AA1D0, FlxTextAlign.CENTER, 'Arial');
      icon.scrollFactor.set();
      rowIcons.push(icon);

      var labelX:Float = itemX + (tileLayout ? 47 : 68);
      var labelWidth:Float = buttonW - (tileLayout ? 58 : 90);
      var label:FlxText = addLabel(labelX, itemY + 4, labelWidth, ITEM_NAMES[index], tileLayout ? 13 : 20, 0xFFDBE4FA, FlxTextAlign.LEFT, 'Arial Black');
      label.y = itemY + (buttonH - label.height) * 0.5;
      label.scrollFactor.set();
      rowLabels.push(label);
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

    // Soft orbital accents and the inset feature card echo the original V4 layout.
    var orbit:FlxSprite = addSolid(x + width * 0.50, y + 24, width * 0.40, 2, 0x265D72FF);
    orbit.alpha = 0.5;
    addSolid(x + width * 0.77, y + 24, 2, height * 0.34, 0x265D72FF).alpha = 0.5;

    featureKicker = addLabel(x + 34, y + 38, width - 68, 'YOUR GAME. YOUR WAY.', 11, 0xFF8EA4DC, FlxTextAlign.LEFT, 'Arial');
    featureTitle = addLabel(x + 34, y + 78, width - 68, ITEM_TITLES[0], 54, 0xFFF8FAFF, FlxTextAlign.LEFT, 'Arial Black');
    featureDescription = addLabel(x + 34, y + 192, width - 68, ITEM_DESCRIPTIONS[0], 15, 0xFFB1BFDC, FlxTextAlign.LEFT, 'Arial');
    featureDescription.wordWrap = true;
    featureDescription.autoSize = false;

    var metaY:Float = y + height * 0.60;
    for (index in 0...ITEM_META[0].length)
    {
      var pillX:Float = x + 34 + index * 118;
      var pill:FlxSprite = addRoundRect(pillX, metaY, 108, 27, 13, 13, 0x231A2C58);
      var pillText:FlxText = addLabel(pillX + 5, metaY + 7, 98, ITEM_META[0][index], 9, 0xFFB9C9EC, FlxTextAlign.CENTER, 'Arial');
      pill.alpha = 1;
      featureMeta.push(pillText);
    }

    if (Save.instance.options.menuShowEqualizer && Save.instance.options.menuAudioVisualizer)
    {
      buildEqualizer(x + 34, y + height - 136, width - 68);
    }

    addLabel(x + 34, y + height - 28, width - 68, 'SELECT AN OPTION TO EXPLORE', 9, 0xFF7186B7, FlxTextAlign.LEFT, 'Arial');
    addLabel(x + width - 230, y + height - 28, 205, '↑  ↓  NAVIGATE   •   ENTER  SELECT', 9, 0xFF8297C2, FlxTextAlign.RIGHT, 'Arial');
  }

  function updateSelection(index:Int):Void
  {
    if (index < 0 || index >= ITEM_NAMES.length) return;

    for (i in 0...ITEM_NAMES.length)
    {
      var selected:Bool = i == index;
      if (i < rowBackgrounds.length)
      {
        rowBackgrounds[i].color = selected ? 0xFF12375A : 0xFF0D1935;
        rowBackgrounds[i].alpha = selected ? 1 : 0.84;
      }
      if (i < rowAccents.length)
      {
        rowAccents[i].color = selected ? accentColor() : 0xFF267CFF;
        rowAccents[i].alpha = selected ? 1 : 0.34;
      }
      if (i < rowLabels.length)
      {
        rowLabels[i].color = selected ? 0xFFFFFFFF : 0xFFB9C8E3;
      }
      if (i < rowIcons.length)
      {
        rowIcons[i].color = selected ? accentColor() : 0xFF8297C2;
      }
    }

    if (featureTitle != null && featureDescription != null && featureKicker != null)
    {
      featureTitle.text = ITEM_TITLES[index];
      featureDescription.text = ITEM_DESCRIPTIONS[index];
      featureKicker.text = ITEM_KICKERS[index];

      for (i in 0...featureMeta.length)
      {
        featureMeta[i].text = ITEM_META[index][i];
      }
    }

    playSfx('select', 0.30);
  }

  function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (showingTitle)
    {
      var pressed:Bool = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;
      var gamepad = FlxG.gamepads.lastActive;
      if (gamepad != null && (gamepad.justPressed.START || gamepad.justPressed.ACCEPT)) pressed = true;
      #if mobile
      if (TouchUtil.justReleased && !SwipeUtil.justSwipedAny) pressed = true;
      #end

      if (FlxG.mouse.justPressed && titleOptionsButton != null && FlxG.mouse.overlaps(titleOptionsButton))
      {
        openOptions(false);
        return;
      }

      if (pressed || FlxG.mouse.justPressed) beginMenuTransition();
      return;
    }

    animationClock += elapsed;
    var options = Save.instance.options;
    if (!options.menuReduceMotion && options.menuAnimatedBackground && backgroundSprite != null)
    {
      backgroundSprite.alpha = 0.985 + Math.sin(animationClock * 0.45) * 0.015;
    }

    if (!options.menuReduceMotion && options.menuAudioVisualizer)
    {
      for (index in 0...equalizerBars.length)
      {
        var scale:Float = 0.60 + (Math.sin(animationClock * 2.15 + index * 0.62) + 1) * 0.20;
        equalizerBars[index].scale.y = scale;
        equalizerBars[index].y = equalizerBaseY[index] + equalizerBaseHeight[index] * (1 - scale);
      }
    }

    if (FlxG.mouse.justPressed)
    {
      if (homeAudioButton != null && FlxG.mouse.overlaps(homeAudioButton))
      {
        playSfx('confirm', 0.7);
        openOptions(false);
        return;
      }
      if (homeOptionsButton != null && FlxG.mouse.overlaps(homeOptionsButton))
      {
        playSfx('confirm', 0.7);
        openOptions(false);
        return;
      }
    }

    if (controls.BACK_P)
    {
      playSfx('back', 0.7);
      FlxG.switchState(() -> new TitleState());
    }
  }

  function makeCallback(index:Int):Void->Void
  {
    return function()
    {
      playSfx('confirm', 0.7);
      switch (index)
      {
        case 0:
          FlxG.switchState(() -> new StoryMenuState());
        case 1:
          openSubState(new FreeplayState({
            character: FreeplayState.rememberedCharacterId
          }));
        case 2:
          OptionsState.openModsOnStart = true;
          openOptions(true);
        case 3:
          openOptions(false);
        case 4:
          FlxG.switchState(() -> new CreditsState());
        default:
      }
    };
  }

  function openOptions(openMods:Bool):Void
  {
    OptionsState.openModsOnStart = openMods;
    FlxG.switchState(() -> new OptionsState());
  }

  function densityMultiplier():Float
  {
    return switch (Save.instance.options.menuDensity)
    {
      case "compact": 0.78;
      case "spacious": 1.18;
      default: 1.0;
    };
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
    addRoundRect(x, y, width, height, 28, 28, borderColor);
    addRoundRect(x + 2, y + 2, width - 4, height - 4, 26, 26, 0xF0061028);
  }

  function addRoundRect(x:Float, y:Float, width:Float, height:Float, radiusX:Float, radiusY:Float, color:FlxColor):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
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
    var label:FlxText = new FlxText(x, y, width, value, size);
    label.setFormat(fontName, size, color, alignment, null, FlxColor.TRANSPARENT, false);
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
      bar.alpha = 0.78;
      equalizerBars.push(bar);
      equalizerBaseY.push(bar.y);
      equalizerBaseHeight.push(height);
    }
  }

  function playMenuTheme(restart:Bool, startingVolume:Float):Void
  {
    #if web
    var musicPath:String = Paths.file('music/novabeat-menu/novabeat-menu.ogg');
    if (restart || FlxG.sound.music == null || !FlxG.sound.music.playing)
    {
      if (FlxG.sound.music != null)
      {
        FlxG.sound.music.fadeTween?.cancel();
        FlxG.sound.music.stop();
        FlxG.sound.music.kill();
      }

      var music = FunkinSound.load(musicPath, startingVolume, true, false, true, true);
      if (music != null) FunkinSound.setMusic(music);
    }
    #else
    FunkinSound.playMusic('novabeat-menu', {
      startingVolume: startingVolume,
      overrideExisting: true,
      restartTrack: restart,
      persist: true
    });
    #end
  }

  function playSfx(name:String, volume:Float):Void
  {
    #if web
    FunkinSound.playOnce(Paths.file('sounds/novabeat/' + name + '.ogg'), volume);
    #else
    FunkinSound.playOnce(Paths.sound('novabeat/' + name), volume);
    #end
  }
}
