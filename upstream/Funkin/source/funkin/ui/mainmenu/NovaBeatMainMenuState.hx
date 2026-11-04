package funkin.ui.mainmenu;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.save.Save;
import flixel.text.FlxText;
import flixel.util.FlxColor;
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

/**
 * The optional NovaBeat presentation for the game's main menu.
 *
 * The original FNF title screen and main menu remain the default. This state
 * is entered only when the player chooses NovaBeat in Preferences.
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

  static final ITEM_TITLES:Array<String> = [
    'STORY MODE',
    'FREEPLAY',
    'MOD MANAGER',
    'OPTIONS',
    'CREDITS'
  ];

  static final ITEM_DESCRIPTIONS:Array<String> = [
    'Continue the original Friday Night Funkin\' story, choose a week, and play through the campaign.',
    'Jump straight into the song library. Search for a track and choose your preferred difficulty.',
    'Browse the local Polymod library, inspect mod information, enable or disable mods, and arrange load priority.',
    'Adjust your game preferences, controls, accessibility, and the menu presentation.',
    'View the people and projects behind Friday Night Funkin\' and NovaBeat Engine.'
  ];

  var uiCamera:FlxCamera;
  var menuItems:TextMenuList;
  var rowBackgrounds:Array<FlxSprite> = [];
  var featureTitle:Null<FlxText>;
  var featureDescription:Null<FlxText>;
  var featureKicker:Null<FlxText>;
  var compactLayout:Bool = false;
  var backgroundSprite:Null<FlxSprite>;
  var animationClock:Float = 0;
  var equalizerBars:Array<FlxSprite> = [];
  var equalizerBaseY:Array<Float> = [];
  var equalizerBaseHeight:Array<Float> = [];

  override function create():Void
  {
    FlxG.cameras.reset(new FunkinCamera('novaBeatMainMenu'));
    uiCamera = new FunkinCamera('novaBeatMenuUI');
    FlxG.cameras.add(uiCamera, false);
    uiCamera.bgColor = 0x00000000;

    super.create();

    FunkinSound.playMusic('freakyMenu', {
      overrideExisting: true,
      restartTrack: false,
      persist: true
    });

    buildInterface();
  }

  function buildInterface():Void
  {
    final screenW:Int = FlxG.width;
    final screenH:Int = FlxG.height;
    compactLayout = screenW < 950 || screenH > screenW * 1.12;

    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    backgroundSprite = background;
    background.setGraphicSize(Std.int(screenW * 1.12));
    background.updateHitbox();
    background.screenCenter();
    background.color = 0xFF263D78;
    background.alpha = backgroundIntensityAlpha();
    background.scrollFactor.set();
    background.cameras = [uiCamera];
    add(background);

    addSolid(0, 0, screenW, screenH, 0xD9070B1D);

    var margin:Float = compactLayout ? Math.max(22, screenW * 0.035) : screenW * 0.042;
    addLabel(margin, Math.max(20, screenH * 0.035), screenW * 0.65, 'NOVABEAT ENGINE', compactLayout ? 22 : 30, 0xFFF1F7FF);
    addLabel(margin, Math.max(53, screenH * 0.085), screenW * 0.75, 'YOUR GAME. YOUR WAY.', 11, accentColor());

    var navX:Float = margin;
    var navY:Float = compactLayout ? Math.max(96, screenH * 0.18) : screenH * 0.16;
    var navW:Float = compactLayout ? screenW - margin * 2 : screenW * 0.445;
    var navH:Float = screenH - navY - Math.max(28, screenH * 0.055);

    addPanel(navX, navY, navW, navH);
    addLabel(navX + 25, navY + 20, navW - 50, 'MAIN MENU', compactLayout ? 20 : 25, 0xFFF4F7FF);

    if (!compactLayout)
    {
      var featureX:Float = screenW * 0.515;
      var featureY:Float = navY;
      var featureW:Float = screenW - featureX - margin;
      var featureH:Float = navH;
      addPanel(featureX, featureY, featureW, featureH);
      featureKicker = addLabel(featureX + 34, featureY + 42, featureW - 68, 'NOVABEAT ENGINE', 12, 0xFF48E7FF);
      featureTitle = addLabel(featureX + 34, featureY + 100, featureW - 68, 'STORY MODE', 38, 0xFFFFFFFF);
      featureDescription = addLabel(featureX + 34, featureY + 162, featureW - 68, ITEM_DESCRIPTIONS[0], 16, 0xFFB6C7E5);
      addLabel(featureX + 34, featureY + featureH - 85, featureW - 68, 'CAMPAIGN     WEEK SELECT     DIFFICULTY', 10, 0xFF8DA8D8);
      if (Save.instance.options.menuShowEqualizer && Save.instance.options.menuAudioVisualizer)
      buildEqualizer(featureX + 34, featureY + featureH - 55, featureW - 68);
      addLabel(featureX + 34, featureY + featureH - 22, featureW - 68, 'SELECT AN OPTION TO EXPLORE', 9, 0xFF8297C2);
    }

    var buttonW:Float;
    var buttonH:Float;
    var buttonGap:Float;
    var firstX:Float;
    var firstY:Float;

    if (compactLayout)
    {
      buttonGap = Math.max(7, screenW * 0.018) * densityMultiplier();
      buttonW = (navW - 3 * buttonGap) / 2;
      buttonH = Math.max(54, Math.min(100, (navH - 118) / 3));
      firstX = navX + buttonGap;
      firstY = navY + 68;
    }
    else
    {
      buttonGap = Math.max(9, screenH * 0.018) * densityMultiplier();
      buttonW = navW - 48;
      buttonH = Math.min(82, (navH - 190 - buttonGap * 4) / 5);
      buttonH = Math.max(48, buttonH);
      firstX = navX + 24;
      firstY = navY + 92;
    }

    menuItems = new TextMenuList(compactLayout ? NavControls.Columns(2) : NavControls.Vertical);
    menuItems.cameras = [uiCamera];

    for (index in 0...ITEM_NAMES.length)
    {
      var col:Int = compactLayout ? index % 2 : 0;
      var row:Int = compactLayout ? Std.int(index / 2) : index;
      var x:Float = compactLayout ? firstX + col * (buttonW + buttonGap) : firstX;
      var y:Float = compactLayout ? firstY + row * (buttonH + buttonGap) : firstY + row * (buttonH + buttonGap);

      var rowBg:FlxSprite = addSolid(x, y, buttonW, buttonH, 0xFF0D1935);
      rowBg.alpha = 0.88;
      rowBackgrounds.push(rowBg);

      var accent:FlxSprite = addSolid(x, y, 4, buttonH, accentColor());
      accent.alpha = 0.6;
      rowBackgrounds.push(accent);

      var item:TextMenuItem = menuItems.createItem(x, y, ITEM_NAMES[index], AtlasFont.BOLD, makeCallback(index));
      item.cameras = [uiCamera];
      item.makeGraphic(Std.int(buttonW), Std.int(buttonH), FlxColor.TRANSPARENT);
      item.updateHitbox();
      item.scrollFactor.set();
      item.atlasText.x += compactLayout ? 12 : 20;
      item.atlasText.y += (buttonH - item.atlasText.height) * 0.5;
      var textScale:Float = Save.instance.options.menuInterfaceScale / 100;
      if (Save.instance.options.menuLargeText) textScale *= 1.12;
      item.atlasText.scale.set((compactLayout ? 0.78 : 0.92) * textScale, (compactLayout ? 0.78 : 0.92) * textScale);
      item.atlasText.updateHitbox();

      if (Save.instance.options.menuEntryAnimations && !Save.instance.options.menuReduceMotion)
      {
        var finalRowAlpha:Float = rowBg.alpha;
        var finalAccentAlpha:Float = accent.alpha;
        rowBg.alpha = 0;
        accent.alpha = 0;
        item.alpha = 0;
        FlxTween.tween(rowBg, {alpha: finalRowAlpha}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(accent, {alpha: finalAccentAlpha}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
        FlxTween.tween(item, {alpha: 1}, 0.28, {ease: FlxEase.quadOut, startDelay: index * 0.045});
      }
    }

    menuItems.onChange.add(function(selected:TextMenuItem)
    {
      updateSelection(menuItems.selectedIndex);
    });
    add(menuItems);
    updateSelection(0);

    if (compactLayout)
    {
      addLabel(margin, navY + navH - 30, navW - 20, 'TAP A TILE TO SELECT   •   ENTER TO OPEN', 9, 0xFF8DA8D8);
    }
    else
    {
      addLabel(margin, screenH - 25, screenW - margin * 2, 'UP / DOWN   NAVIGATE       ENTER   SELECT', 10, 0xFF8DA8D8);
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var options = Save.instance.options;
    if (options.menuReduceMotion) return;

    if (options.menuAnimatedBackground && backgroundSprite != null)
    {
      animationClock += elapsed;
      backgroundSprite.alpha = backgroundIntensityAlpha() + Math.sin(animationClock * 0.45) * 0.025;
    }

    if (options.menuAudioVisualizer)
    {
      if (animationClock == 0) animationClock = elapsed;
      for (index in 0...equalizerBars.length)
      {
        var scale:Float = 0.65 + (Math.sin(animationClock * 2.2 + index * 0.62) + 1) * 0.19;
        var bar:FlxSprite = equalizerBars[index];
        bar.scale.y = scale;
        bar.y = equalizerBaseY[index] + equalizerBaseHeight[index] * (1 - scale);
      }
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
        case 2:
          OptionsState.openModsOnStart = true;
          FlxG.switchState(() -> new OptionsState());
        case 3:
          FlxG.switchState(() -> new OptionsState());
        case 4:
          FlxG.switchState(() -> new CreditsState());
        default:
      }
    };
  }

  function updateSelection(index:Int):Void
  {
    for (i in 0...ITEM_NAMES.length)
    {
      var rowIndex:Int = i * 2;
      if (rowIndex + 1 >= rowBackgrounds.length) continue;
      var selected:Bool = i == index;
      rowBackgrounds[rowIndex].color = selected ? 0xFF164B78 : 0xFF0D1935;
      rowBackgrounds[rowIndex].alpha = selected ? 1 : 0.82;
      rowBackgrounds[rowIndex + 1].color = selected ? accentColor() : 0xFF267CFF;
      rowBackgrounds[rowIndex + 1].alpha = selected ? 1 : 0.38;
      menuItems.members[i].atlasText.color = selected ? FlxColor.WHITE : 0xFFB8C7E2;
    }

    if (featureTitle != null && featureDescription != null && featureKicker != null)
    {
      featureTitle.text = ITEM_TITLES[index];
      featureDescription.text = ITEM_DESCRIPTIONS[index];
      featureKicker.text = switch (index)
      {
        case 0: 'CAMPAIGN';
        case 1: 'SINGLE SONG';
        case 2: 'LOCAL MODS';
        case 3: 'GAME PREFERENCES';
        case 4: 'ABOUT THIS BUILD';
        default: 'NOVABEAT ENGINE';
      };
    }
  }

  function densityMultiplier():Float
  {
    return switch (Save.instance.options.menuDensity)
    {
      case "compact": 0.72;
      case "spacious": 1.32;
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

  function backgroundIntensityAlpha():Float
  {
    return 0.26 + (Save.instance.options.menuBackgroundIntensity / 125) * 0.22;
  }

  function addPanel(x:Float, y:Float, width:Float, height:Float):Void
  {
    var border:FlxSprite = addSolid(x, y, width, height, accentColor());
    border.alpha = Math.min(1, 0.25 + Save.instance.options.menuPanelGlow / 150 * 0.75);
    addSolid(x + 2, y + 2, width - 4, height - 4, 0xF0061028);
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

  function addLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor):FlxText
  {
    var label:FlxText = new FlxText(x, y, width, value, size);
    if (Save.instance.options.menuLargeText) size = Std.int(size * 1.12);
    label.setFormat(Paths.font('vcr.ttf'), size, color, FlxTextAlign.LEFT);
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
      var bar:FlxSprite = addSolid(x + index * (barWidth + gap), y + 76 - height, barWidth, height, index % 7 == 0 ? 0xFF8C48FF : accentColor());
      bar.alpha = 0.72;
      equalizerBars.push(bar);
      equalizerBaseY.push(bar.y);
      equalizerBaseHeight.push(height);
    }
  }
}
