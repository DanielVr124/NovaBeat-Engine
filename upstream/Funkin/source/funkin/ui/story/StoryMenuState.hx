package funkin.ui.story;

import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxSprite;
import funkin.graphics.FunkinSprite;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.FlxStringUtil;
import funkin.audio.FunkinSound;
import funkin.Preferences;
import funkin.data.story.level.LevelRegistry;
import funkin.data.song.SongRegistry;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.PlayStatePlaylist;
import funkin.play.song.Song;
import funkin.save.Save;
import funkin.save.Save.SaveScoreData;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.mainmenu.NovaBeatMainMenuState;
import funkin.ui.MusicBeatState;
import funkin.ui.transition.LoadingState;
import funkin.ui.transition.stickers.StickerSubState;
import funkin.util.MathUtil;
import funkin.util.SwipeUtil;
import funkin.util.TouchUtil;
import funkin.util.DeviceUtil;
import funkin.ui.FullScreenScaleMode;
#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end

class StoryMenuState extends MusicBeatState
{
  static final DEFAULT_BACKGROUND_COLOR:FlxColor = FlxColor.fromString('#F9CF51');
  static final BACKGROUND_Y:Int = 56;
  static final BACKGROUND_HEIGHT:Int = 400;

  var currentDifficultyId:String = 'normal';
  var currentLevelId:String = 'tutorial';
  var currentLevel:Level;
  var isLevelUnlocked:Bool;
  var currentLevelTitle:LevelTitle;
  var highScore:Int = 42069420;
  var highScoreLerp:Int = 12345678;
  var exitingMenu:Bool = false;
  var selectedLevel:Bool = false;
  var novaBeatBrowserDragActive:Bool = false;
  var novaBeatBrowserDragAccumulator:Float = 0;
  var fnfBrowserDragActive:Bool = false;
  var fnfBrowserDragAccumulator:Float = 0;
  //
  // RENDER OBJECTS
  //

  /**
   * The title of the level at the top.
   */
  var levelTitleText:FlxText;

  /**
   * The score text at the top.
   */
  var scoreText:FlxText;

  /**
   * The list of songs on the left.
   */
  var tracklistText:FlxText;

  /**
   * The titles of the levels in the middle.
   */
  var levelTitles:FlxTypedGroup<LevelTitle>;

  /**
   * The props in the center.
   */
  var levelProps:FlxTypedGroup<LevelProp>;

  /**
   * The background behind the props.
   */
  var levelBackground:FlxSprite;
  var novaBeatWeekPanel:FlxSprite;
  var baseLevelBackgroundWidth:Float = 0;
  var baseLevelBackgroundHeight:Float = 0;

  /**
   * The left arrow of the difficulty selector.
   */
  var leftDifficultyArrow:FlxSprite;

  /**
   * The right arrow of the difficulty selector.
   */
  var rightDifficultyArrow:FlxSprite;

  /**
   * The text of the difficulty selector.
   */
  var difficultySprite:FlxSprite;

  /**
   * List of available level IDs.
   */
  var levelList:Array<String> = [];

  var difficultySprites:Map<String, FlxSprite>;
  var stickerSubState:StickerSubState;

  static var rememberedLevelId:Null<String> = null;
  static var rememberedDifficulty:Null<String> = Constants.DEFAULT_DIFFICULTY;

  public function new(?stickers:StickerSubState = null)
  {
    super();

    if (stickers?.members != null)
    {
      stickerSubState = stickers;
    }
  }

  override function create():Void
  {
    super.create();

    levelList = LevelRegistry.instance.listSortedLevelIds();
    levelList = levelList.filter(function(id)
    {
      var levelData = LevelRegistry.instance.fetchEntry(id);
      if (levelData == null) return false;

      return levelData.isVisible();
    });
    if (levelList.length == 0) levelList = ['tutorial']; // Make sure there's at least one level to display.

    difficultySprites = new Map<String, FlxSprite>();

    transIn = FlxTransitionableState.defaultTransIn;
    transOut = FlxTransitionableState.defaultTransOut;

    playMenuMusic();

    if (stickerSubState != null)
    {
      this.persistentUpdate = true;
      this.persistentDraw = true;

      openSubState(stickerSubState);
      stickerSubState.degenStickers();
    }

    persistentUpdate = persistentDraw = true;

    rememberSelection();

    updateData();

    levelTitles = new FlxTypedGroup<LevelTitle>();
    // The stock FNF black mask is at zIndex 99. Week artwork belongs below
    // it so titles naturally disappear as they move above the carousel edge.
    // NovaBeat keeps its own panel/title layering.
    levelTitles.zIndex = Preferences.menuStyle == "NovaBeat" ? 15 : 98;
    add(levelTitles);

    updateBackground();

    var black:FunkinSprite = new FunkinSprite(levelBackground.x, 0).makeSolidColor(FlxG.width, Std.int(400 + levelBackground.y), FlxColor.BLACK);
    black.zIndex = levelBackground.zIndex - 1;
    add(black);

    baseLevelBackgroundWidth = levelBackground.frameWidth;
    baseLevelBackgroundHeight = levelBackground.frameHeight;
    updateNovaBeatWeekPanel(FlxG.width, FlxG.height);

    levelProps = new FlxTypedGroup<LevelProp>();
    levelProps.zIndex = 1000;
    add(levelProps);

    updateProps();

    // Keep the track list origin used by the original FNF Story Mode.
    var initialTracklistY:Float = Preferences.menuStyle == "NovaBeat"
      ? levelBackground.y + levelBackground.height + 100
      : levelBackground.x + levelBackground.height + 100;
    tracklistText = new FlxText(0, initialTracklistY, 0, 'Tracks', 32);
    tracklistText.setFormat('VCR OSD Mono', 32);
    tracklistText.alignment = CENTER;
    tracklistText.color = 0xFFE55777;
    if (Preferences.menuStyle == "NovaBeat") tracklistText.zIndex = 20;
    add(tracklistText);

    scoreText = new FlxText(Math.max(FullScreenScaleMode.gameNotchSize.x, 10), 10, 0, 'HIGH SCORE: 42069420');
    scoreText.setFormat('VCR OSD Mono', 32);
    scoreText.zIndex = Preferences.menuStyle == "NovaBeat" ? 30 : 1000;
    add(scoreText);

    levelTitleText = new FlxText(Math.max((FlxG.width * 0.7), FlxG.width - FullScreenScaleMode.gameNotchSize.x), 10, 0, 'LEVEL 1');
    levelTitleText.setFormat('VCR OSD Mono', 32, FlxColor.WHITE, RIGHT);
    levelTitleText.alpha = 0.7;
    levelTitleText.zIndex = Preferences.menuStyle == "NovaBeat" ? 30 : 1000;
    add(levelTitleText);

    buildLevelTitles();

    final useNotch:Bool = Math.max(35, FullScreenScaleMode.gameNotchSize.x) != 35;
    leftDifficultyArrow = new FlxSprite(FlxG.width - (useNotch ? (FullScreenScaleMode.gameNotchSize.x) + 410 : 410), 480);
    leftDifficultyArrow.frames = Paths.getSparrowAtlas('storymenu/ui/arrows');
    leftDifficultyArrow.animation.addByPrefix('idle', 'leftIdle0');
    leftDifficultyArrow.animation.addByPrefix('press', 'leftConfirm0');
    leftDifficultyArrow.animation.play('idle');
    if (Preferences.menuStyle == "NovaBeat") leftDifficultyArrow.zIndex = 30;
    add(leftDifficultyArrow);

    buildDifficultySprite(Constants.DEFAULT_DIFFICULTY);
    buildDifficultySprite();

    rightDifficultyArrow = new FlxSprite(FlxG.width - (useNotch ? FullScreenScaleMode.gameNotchSize.x * 1.5 : 35), leftDifficultyArrow.y);
    rightDifficultyArrow.frames = leftDifficultyArrow.frames;
    rightDifficultyArrow.animation.addByPrefix('idle', 'rightIdle0');
    rightDifficultyArrow.animation.addByPrefix('press', 'rightConfirm0');
    rightDifficultyArrow.animation.play('idle');
    if (Preferences.menuStyle == "NovaBeat") rightDifficultyArrow.zIndex = 30;
    add(rightDifficultyArrow);

    if (Preferences.menuStyle == "NovaBeat") difficultySprite.zIndex = 31;
    add(difficultySprite);

    updateText();
    changeDifficulty();
    changeLevel();
    refresh();

    #if FEATURE_DISCORD_RPC
    // Updating Discord Rich Presence
    DiscordClient.instance.setPresence({state: 'In the Menus', details: null});
    #end

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (DeviceUtil.isMobileBrowser) addBackButton(FlxG.width - 230, FlxG.height - 170, FlxColor.WHITE, goBack, 0.7);
    #end

    #if FEATURE_TOUCH_CONTROLS
    FlxG.touches.swipeThreshold.y = 100;
    #if web
    if (Preferences.menuStyle == "NovaBeat") FlxG.mouse.swipeThreshold.set(100, 100);
    #end
    #end
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    // FNF keeps its original fixed Story Mode composition. The responsive
    // full-screen layout below belongs only to the NovaBeat presentation.
    if (Preferences.menuStyle != "NovaBeat") return;
    if (width <= 0 || height <= 0 || levelBackground == null || levelTitleText == null || scoreText == null || tracklistText == null) return;

    var portrait:Bool = height > width * 1.12;
    var novaBeatStyle:Bool = Preferences.menuStyle == "NovaBeat";
    var margin:Float = Math.max(18, width * 0.045);

    // Keep the custom replacement artwork behind Story Mode, while the
    // selected menu style controls the layout of the menu elements.
    if (baseLevelBackgroundWidth <= 0) baseLevelBackgroundWidth = levelBackground.frameWidth;
    if (baseLevelBackgroundHeight <= 0) baseLevelBackgroundHeight = levelBackground.frameHeight;
    var backgroundScale:Float = Math.max(width / baseLevelBackgroundWidth, height / baseLevelBackgroundHeight);
    levelBackground.scale.set(backgroundScale, backgroundScale);
    levelBackground.updateHitbox();
    levelBackground.screenCenter();
    updateNovaBeatWeekPanel(width, height);

    if (portrait)
    {
      scoreText.setFormat('VCR OSD Mono', 19);
      scoreText.x = margin;
      scoreText.y = 14;
      scoreText.fieldWidth = width * 0.48;

      levelTitleText.setFormat('VCR OSD Mono', 20, FlxColor.WHITE, CENTER);
      levelTitleText.fieldWidth = width - margin * 2;
      levelTitleText.x = margin;
      levelTitleText.y = height * 0.13;

      tracklistText.setFormat('VCR OSD Mono', 19);
      tracklistText.fieldWidth = width - margin * 2;
      tracklistText.alignment = CENTER;
      tracklistText.x = margin;
      tracklistText.y = height * 0.76;

      var centreX:Float = width * 0.5;
      var selectorY:Float = height * 0.62;
      leftDifficultyArrow.setPosition(centreX - leftDifficultyArrow.width - 48, selectorY);
      rightDifficultyArrow.setPosition(centreX + 48, selectorY);
      if (difficultySprite != null)
      {
        difficultySprite.x = centreX - difficultySprite.width * 0.5;
        difficultySprite.y = selectorY - 15;
      }
    }
    else
    {
      // Restore the stock landscape FNF composition. NovaBeat keeps its
      // backdrop full-screen, but the text and selector stay on-screen.
      scoreText.setFormat('VCR OSD Mono', 32);
      scoreText.x = Math.max(FullScreenScaleMode.gameNotchSize.x, 10);
      scoreText.y = 10;
      scoreText.fieldWidth = 0;

      levelTitleText.setFormat('VCR OSD Mono', 32, FlxColor.WHITE, RIGHT);
      levelTitleText.fieldWidth = novaBeatStyle ? width * 0.55 : 0;
      levelTitleText.y = 10;
      levelTitleText.x = width - (levelTitleText.width + Math.max(10, FullScreenScaleMode.gameNotchSize.x));

      tracklistText.setFormat('VCR OSD Mono', 32);
      tracklistText.fieldWidth = novaBeatStyle ? width * 0.55 : 0;
      tracklistText.alignment = CENTER;
      // Original FNF keeps the track list immediately below its stock 400px week area.
      // NovaBeat uses its own full-screen composition and anchors tracks near the bottom.
      tracklistText.y = novaBeatStyle ? height * 0.76 : Math.min(BACKGROUND_Y + BACKGROUND_HEIGHT + 100, Math.max(0, height - tracklistText.height));
      tracklistText.screenCenter(X);
      tracklistText.x -= width * 0.33;

      var useNotch:Bool = Math.max(35, FullScreenScaleMode.gameNotchSize.x) != 35;
      leftDifficultyArrow.x = width - (useNotch ? FullScreenScaleMode.gameNotchSize.x + 410 : 410);
      rightDifficultyArrow.x = width - (useNotch ? FullScreenScaleMode.gameNotchSize.x * 1.5 : 35);
      leftDifficultyArrow.y = 480;
      rightDifficultyArrow.y = 480;
      if (difficultySprite != null)
      {
        difficultySprite.x = leftDifficultyArrow.x + leftDifficultyArrow.width + 10
          + (difficultySprites.get(Constants.DEFAULT_DIFFICULTY).width - difficultySprite.width) / 2;
        difficultySprite.y = leftDifficultyArrow.y - 5;
      }
    }

    repositionTitles();
    updateText();
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (backButton != null) backButton.setPosition(width - backButton.width - 18, height - backButton.height - 18);
    #end
    refresh();
  }

  function rememberSelection():Void
  {
    if (rememberedLevelId != null)
    {
      currentLevelId = rememberedLevelId;
    }
    if (rememberedDifficulty != null)
    {
      currentDifficultyId = rememberedDifficulty;
    }
  }

  function playMenuMusic():Void
  {
    if (Preferences.menuStyle == "NovaBeat")
    {
      FunkinSound.playMusic('novabeat-menu', {
        overrideExisting: true,
        restartTrack: false,
        persist: true,
        mapTimeChanges: false
      });
    }
    else
    {
      // Keep the stock FNF music parameters unchanged.
      FunkinSound.playMusic('freakyMenu', {
        overrideExisting: true,
        restartTrack: false,
        persist: true
      });
    }
  }

  function playNavigationSound():Void
  {
    var soundName:String = Preferences.menuStyle == "NovaBeat" ? "novabeat/select" : "scrollMenu";
    FunkinSound.playOnce(Paths.sound(soundName), 0.4);
  }

  function updateData():Void
  {
    currentLevel = LevelRegistry.instance.fetchEntry(currentLevelId);
    if (currentLevel == null) throw 'Could not fetch data for level: ${currentLevelId}';
    isLevelUnlocked = currentLevel == null ? false : currentLevel.isUnlocked();
  }

  function buildDifficultySprite(?diff:String):Void
  {
    if (diff == null) diff = currentDifficultyId;
    remove(difficultySprite);
    difficultySprite = difficultySprites.get(diff);
    if (difficultySprite == null)
    {
      difficultySprite = new FlxSprite(leftDifficultyArrow.x + leftDifficultyArrow.width + 10, leftDifficultyArrow.y);

      if (Assets.exists(Paths.file('images/storymenu/difficulties/${diff}.xml')))
      {
        difficultySprite.frames = Paths.getSparrowAtlas('storymenu/difficulties/${diff}');
        difficultySprite.animation.addByPrefix('idle', 'idle0', 24, true);
        if (Preferences.flashingLights) difficultySprite.animation.play('idle');
      }
      else
      {
        difficultySprite.loadGraphic(Paths.image('storymenu/difficulties/${diff}'));
      }

      difficultySprites.set(diff, difficultySprite);

      difficultySprite.x += (difficultySprites.get(Constants.DEFAULT_DIFFICULTY).width - difficultySprite.width) / 2;
    }

    // Difficulty sprites are rebuilt when the user changes difficulty.
    // Reapply the portrait NovaBeat center anchor here as well as on resize.
    if (Preferences.menuStyle == "NovaBeat" && FlxG.height > FlxG.width * 1.12)
      difficultySprite.x = (FlxG.width - difficultySprite.width) * 0.5;
    difficultySprite.alpha = 0;

    difficultySprite.y = leftDifficultyArrow.y - 15;
    var targetY:Float = leftDifficultyArrow.y + 10;
    targetY -= (difficultySprite.height - difficultySprites.get(Constants.DEFAULT_DIFFICULTY).height) / 2;
    FlxTween.tween(difficultySprite, {y: targetY, alpha: 1}, 0.07);

    if (Preferences.menuStyle == "NovaBeat") difficultySprite.zIndex = 31;
    add(difficultySprite);
  }

  function buildLevelTitles():Void
  {
    levelTitles.clear();

    for (levelIndex in 0...levelList.length)
    {
      var levelId:String = levelList[levelIndex];
      var level:Level = LevelRegistry.instance.fetchEntry(levelId);
      if (level == null || !level.isVisible()) continue;

      // TODO: Readd lock icon if unlocked is false.

      var levelTitleItem:LevelTitle = new LevelTitle(0, Std.int(levelBackground.y + levelBackground.height + 10), level);
      levelTitleItem.targetY = ((levelTitleItem.height + 20) * levelIndex);
      levelTitleItem.screenCenter(X);
      levelTitles.add(levelTitleItem);
    }
  }

  override function update(elapsed:Float):Void
  {
    Conductor.instance.update();

    highScoreLerp = Std.int(MathUtil.snap(MathUtil.smoothLerpPrecision(highScoreLerp, highScore, elapsed, 0.307), highScore, 1));

    var commaSeparated:Bool = true;
    var scoreTextValue:String = 'LEVEL SCORE: ${FlxStringUtil.formatMoney(highScoreLerp, false, commaSeparated)}';
    if (scoreText.text != scoreTextValue) scoreText.text = scoreTextValue;

    var levelTitleValue:String = currentLevel.getTitle();
    if (levelTitleText.text != levelTitleValue) levelTitleText.text = levelTitleValue;

    // The portrait NovaBeat layout deliberately uses a full-width centered
    // field. Preserve that anchor every frame instead of snapping it back to
    // the desktop right edge. FNF keeps its stock right-aligned title.
    if (Preferences.menuStyle != "NovaBeat" || FlxG.height <= FlxG.width * 1.12)
      levelTitleText.x = FlxG.width - (levelTitleText.width + Math.max(10, FullScreenScaleMode.gameNotchSize.x));

    handleKeyPresses();

    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    super.update(elapsed);
    updateNovaBeatWeekTitleFade();
  }

  function updateNovaBeatWeekTitleFade():Void
  {
    if (Preferences.menuStyle != "NovaBeat" || levelTitles == null) return;

    var height:Float = FlxG.height;
    var fadeDistance:Float = Math.max(72, Math.min(150, height * 0.16));
    var fadeStart:Float = height - fadeDistance;
    var selectedIndex:Int = levelList.indexOf(currentLevelId);

    for (index in 0...levelTitles.members.length)
    {
      var item:LevelTitle = levelTitles.members[index];
      var baseAlpha:Float = index == selectedIndex ? 1.0 : 0.6;
      var fadeRange:Float = fadeDistance + item.height;
      var fadeAmount:Float = Math.max(0, Math.min(1, (item.y + item.height - fadeStart) / fadeRange));
      item.alpha = baseAlpha * (1.0 - fadeAmount);
    }
  }

  // Story Mode uses the upstream FNF mobile touch and swipe recognizers in both themes.
  inline function menuPointer():Dynamic return TouchUtil.touch;

  inline function menuSwipeUp():Bool return SwipeUtil.swipeUp;

  inline function menuSwipeDown():Bool return SwipeUtil.swipeDown;

  inline function menuSwipeLeft():Bool return SwipeUtil.swipeLeft;

  inline function menuSwipeRight():Bool return SwipeUtil.swipeRight;

  inline function menuPointerPressed():Bool return TouchUtil.pressed;

  inline function menuPointerJustReleased():Bool return TouchUtil.justReleased;

  inline function menuPointerJustSwipedAny():Bool return SwipeUtil.justSwipedAny;

  inline function menuPointerOver(sprite:FlxSprite):Bool return TouchUtil.overlaps(sprite);

  inline function menuPointerPressAction(sprite:FlxSprite):Bool return TouchUtil.pressAction(sprite, null, false);

  /**
   * NovaBeat mobile Story Mode uses the same row-by-row drag behavior as its
   * Options lists. The gesture must begin on a visible week title so arrows,
   * difficulty controls, and taps retain their normal behavior.
   */
  function handleNovaBeatBrowserLevelDrag():Bool
  {
    #if web
    if (Preferences.menuStyle != "NovaBeat" || !DeviceUtil.isMobileBrowser || selectedLevel || exitingMenu
      || !TouchUtil.browserPointerBridgeAvailable())
    {
      novaBeatBrowserDragActive = false;
      novaBeatBrowserDragAccumulator = 0;
      return false;
    }

    if (!novaBeatBrowserDragActive)
    {
      for (item in levelTitles.members)
      {
        if (TouchUtil.browserPointerPressedOn(item, item.camera))
        {
          novaBeatBrowserDragActive = true;
          novaBeatBrowserDragAccumulator = 0;
          break;
        }
      }
    }

    if (!novaBeatBrowserDragActive) return false;

    final deltaY:Float = TouchUtil.consumeBrowserPointerDeltaY();
    if (Math.isFinite(deltaY))
    {
      novaBeatBrowserDragAccumulator += deltaY;
      final rowHeight:Float = currentLevelTitle == null ? 48 : currentLevelTitle.height;
      final step:Float = Math.max(30, rowHeight * 0.55);

      while (novaBeatBrowserDragAccumulator >= step)
      {
        changeLevel(1);
        novaBeatBrowserDragAccumulator -= step;
      }
      while (novaBeatBrowserDragAccumulator <= -step)
      {
        changeLevel(-1);
        novaBeatBrowserDragAccumulator += step;
      }
    }

    if (TouchUtil.browserPointerIsDown()) return true;

    final wasDrag:Bool = TouchUtil.browserPointerHasDragged();
    novaBeatBrowserDragActive = false;
    novaBeatBrowserDragAccumulator = 0;
    return wasDrag;
    #else
    return false;
    #end
  }

  /**
   * FNF mobile Story Mode uses the same continuous row-by-row drag model as
   * its Options list. A drag must begin on a visible week title so taps and
   * the difficulty arrows keep their normal behavior.
   */
  function handleFNFBrowserLevelDrag():Bool
  {
    #if web
    if (Preferences.menuStyle == "NovaBeat" || !DeviceUtil.isMobileBrowser || selectedLevel || exitingMenu
      || !TouchUtil.browserPointerBridgeAvailable())
    {
      fnfBrowserDragActive = false;
      fnfBrowserDragAccumulator = 0;
      return false;
    }

    if (!fnfBrowserDragActive)
    {
      for (item in levelTitles.members)
      {
        if (TouchUtil.browserPointerPressedOn(item, item.camera))
        {
          fnfBrowserDragActive = true;
          fnfBrowserDragAccumulator = 0;
          break;
        }
      }
    }

    if (!fnfBrowserDragActive) return false;

    final deltaY:Float = TouchUtil.consumeBrowserPointerDeltaY();
    if (Math.isFinite(deltaY))
    {
      // Match the original FNF Options list: drag-down moves toward the
      // previous week; drag-up moves toward the next week.
      fnfBrowserDragAccumulator -= deltaY;
      final rowHeight:Float = currentLevelTitle == null ? 48 : currentLevelTitle.height;
      final step:Float = Math.max(30, rowHeight * 0.55);

      while (fnfBrowserDragAccumulator >= step)
      {
        changeLevel(1);
        fnfBrowserDragAccumulator -= step;
      }
      while (fnfBrowserDragAccumulator <= -step)
      {
        changeLevel(-1);
        fnfBrowserDragAccumulator += step;
      }
    }

    if (TouchUtil.browserPointerIsDown()) return true;

    final wasDrag:Bool = TouchUtil.browserPointerHasDragged();
    fnfBrowserDragActive = false;
    fnfBrowserDragAccumulator = 0;
    return wasDrag;
    #else
    return false;
    #end
  }

  function handleKeyPresses():Void
  {
    @:privateAccess
    if ((stickerSubState?.switchingState ?? false)) return;

    if (!exitingMenu)
    {
      // While a week-list drag is active, do not also interpret its release
      // as a one-shot swipe or a tap on a week title.
      if (handleNovaBeatBrowserLevelDrag()) return;
      if (handleFNFBrowserLevelDrag()) return;
      if (!selectedLevel)
      {
        // A completed finger swipe should move the week carousel opposite to
        // the finger's travel. Use the one-shot swipe event on NovaBeat mobile
        // so a long drag cannot advance several weeks in consecutive frames.
        // Leave the original FNF per-frame gesture path unchanged.
        final novaBeatMobileSwipe:Bool = Preferences.menuStyle == "NovaBeat" && DeviceUtil.isMobileBrowser;
        final fnfMobileBrowserSwipe:Bool = Preferences.menuStyle != "NovaBeat" && DeviceUtil.isMobileBrowser;
        // NovaBeat retains its established swipe mapping. Normal FNF mobile
        // Story Mode now follows the same direction as the restored FNF lists.
        final swipeToPrevious:Bool = novaBeatMobileSwipe ? SwipeUtil.justSwipedDown
          : (fnfMobileBrowserSwipe ? menuSwipeDown() : menuSwipeUp());
        final swipeToNext:Bool = novaBeatMobileSwipe ? SwipeUtil.justSwipedUp
          : (fnfMobileBrowserSwipe ? menuSwipeUp() : menuSwipeDown());
        if (controls.UI_UP_P || swipeToPrevious)
        {
          changeLevel(-1);
          changeDifficulty(0);
        }

        if (controls.UI_DOWN_P || swipeToNext)
        {
          changeLevel(1);
          changeDifficulty(0);
        }

        if (controls.FREEPLAY_JUMP_TO_TOP)
        {
          changeLevel(levelList.length);
          changeDifficulty(0);
        }

        if (controls.FREEPLAY_JUMP_TO_BOTTOM)
        {
          changeLevel(-levelList.length);
          changeDifficulty(0);
        }

        final wheelAmount:Int = Math.round(FlxMath.bound(FlxG.mouse.deltaWheel.y, -1, 1));

        if (wheelAmount != 0)
        {
          changeLevel(-wheelAmount);
        }

        // TODO: Querying UI_RIGHT_P (justPressed) after UI_RIGHT always returns false. Fix it!
        if (controls.UI_RIGHT_P #if FEATURE_TOUCH_CONTROLS
          || (SwipeUtil.swipeRight && TouchUtil.touch != null && TouchUtil.touch.deltaViewY < 10 && TouchUtil.touch.deltaViewY > -10)
          || (TouchUtil.pressAction(rightDifficultyArrow, null, false)) #end)
        {
          #if FEATURE_TOUCH_CONTROLS
          @:privateAccess
          if (TouchUtil.touch != null
            && !TouchUtil.pressAction(rightDifficultyArrow, null, false)) TouchUtil.touch._startY = TouchUtil.touch.viewY;
          #end
          changeDifficulty(1);
        }

        if (controls.UI_LEFT_P #if FEATURE_TOUCH_CONTROLS
          || (SwipeUtil.swipeLeft && TouchUtil.touch != null && TouchUtil.touch.deltaViewY < 10 && TouchUtil.touch.deltaViewY > -10)
          || (TouchUtil.pressAction(leftDifficultyArrow, null, false)) #end)
        {
          #if FEATURE_TOUCH_CONTROLS
          @:privateAccess
          if (TouchUtil.touch != null
            && !TouchUtil.pressAction(leftDifficultyArrow, null, false)) TouchUtil.touch._startY = TouchUtil.touch.viewY;
          #end
          changeDifficulty(-1);
        }

        if (controls.UI_RIGHT #if FEATURE_TOUCH_CONTROLS || TouchUtil.overlaps(rightDifficultyArrow) #end)
        {
          rightDifficultyArrow.animation.play('press');
        }
        else
        {
          rightDifficultyArrow.animation.play('idle');
        }

        if (controls.UI_LEFT #if FEATURE_TOUCH_CONTROLS || TouchUtil.overlaps(leftDifficultyArrow) #end)
        {
          leftDifficultyArrow.animation.play('press');
        }
        else
        {
          leftDifficultyArrow.animation.play('idle');
        }
      }

      if (controls.ACCEPT_P)
      {
        selectLevel();
      }

      #if FEATURE_TOUCH_CONTROLS
      if (!selectedLevel && TouchUtil.justReleased && !TouchUtil.overlaps(leftDifficultyArrow) && !SwipeUtil.justSwipedAny)
      {
        for (i in 0...levelTitles.members.length)
        {
          final item = levelTitles.members[i];
          final selectedItem = levelTitles.members[
            levelList.indexOf(currentLevelId)
          ];

          if (!TouchUtil.pressAction(item, null, false)) continue;

          (item == selectedItem) ? selectLevel() : changeLevel(i - levelList.indexOf(currentLevelId));
        }
      }
      #end
    }

    if (controls.BACK_P) goBack();
  }

  /**
   * Changes the selected level.
   * @param change +1 (down), -1 (up)
   */
  function changeLevel(change:Int = 0):Void
  {
    var currentIndex:Int = levelList.indexOf(currentLevelId);
    var prevIndex:Int = currentIndex;

    currentIndex += change;

    if (DeviceUtil.isMobileBrowser)
    {
      if (currentIndex < 0) currentIndex = 0;
      if (currentIndex >= levelList.length) currentIndex = levelList.length - 1;
    }
    else
    {
      if (currentIndex < 0) currentIndex = levelList.length - 1;
      if (currentIndex >= levelList.length) currentIndex = 0;
    }

    var previousLevelId:String = currentLevelId;
    currentLevelId = levelList[currentIndex];
    rememberedLevelId = currentLevelId;

    updateData();

    for (index in 0...levelTitles.members.length)
    {
      var item:LevelTitle = levelTitles.members[index];

      if (index == currentIndex)
      {
        currentLevelTitle = item;
        item.alpha = 1.0;
      }
      else
      {
        item.alpha = 0.6;
      }
    }

    if (currentIndex != prevIndex) playNavigationSound();

    repositionTitles();
    updateText();
    updateBackground(previousLevelId);
    updateProps();
    refresh();
  }

  /**
   * Changes the selected difficulty.
   * @param change +1 (right) to increase difficulty, -1 (left) to decrease difficulty
   */
  function changeDifficulty(change:Int = 0):Void
  {
    // "For now, NO erect in story mode" -Dave

    var difficultyList:Array<String> = currentLevel.getDifficulties().filter(e -> Constants.DEFAULT_DIFFICULTY_LIST.contains(e));
    // Use this line to displays all difficulties
    // var difficultyList:Array<String> = currentLevel.getDifficulties();
    var currentIndex:Int = difficultyList.indexOf(currentDifficultyId);

    currentIndex += change;

    // Wrap around
    if (currentIndex < 0) currentIndex = difficultyList.length - 1;
    if (currentIndex >= difficultyList.length) currentIndex = 0;

    var hasChanged:Bool = currentDifficultyId != difficultyList[currentIndex];
    currentDifficultyId = difficultyList[currentIndex];
    rememberedDifficulty = currentDifficultyId;

    if (difficultyList.length <= 1)
    {
      leftDifficultyArrow.visible = false;
      rightDifficultyArrow.visible = false;
    }
    else
    {
      leftDifficultyArrow.visible = true;
      rightDifficultyArrow.visible = true;
    }

    if (hasChanged)
    {
      buildDifficultySprite();
      playNavigationSound();
      // Disable the funny music thing for now.
      // funnyMusicThing();
    }

    updateText();
    refresh();
  }

  final FADE_OUT_TIME:Float = 1.5;

  function funnyMusicThing():Void
  {
    if (currentDifficultyId == 'nightmare')
    {
      FlxG.sound.music.fadeOut(FADE_OUT_TIME, 0.0);
    }
    else
    {
      FlxG.sound.music.fadeOut(FADE_OUT_TIME, 1.0);
    }
  }

  override public function dispatchEvent(event:ScriptEvent):Void
  {
    // super.dispatchEvent(event) dispatches event to module scripts.
    super.dispatchEvent(event);

    if (levelProps?.members != null && levelProps.members.length > 0)
    {
      // Dispatch event to props.
      for (prop in levelProps.members)
      {
        ScriptEventDispatcher.callEvent(prop, event);
      }
    }
  }

  function selectLevel():Void
  {
    if (!currentLevel.isUnlocked())
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      return;
    }

    if (selectedLevel) return;

    selectedLevel = true;

    FunkinSound.playOnce(Paths.sound('confirmMenu'));

    currentLevelTitle.isFlashing = true;

    for (prop in levelProps.members)
    {
      prop.playConfirm();
    }

    Paths.setCurrentLevel(currentLevel.id);

    PlayStatePlaylist.playlistSongIds = currentLevel.getSongs();
    PlayStatePlaylist.isStoryMode = true;
    PlayStatePlaylist.campaignScore = 0;

    var targetSongId:String = PlayStatePlaylist.playlistSongIds.shift();

    var targetSong:Song = SongRegistry.instance.fetchEntry(targetSongId, {variation: Constants.DEFAULT_VARIATION});

    PlayStatePlaylist.campaignId = currentLevel.id;
    PlayStatePlaylist.campaignTitle = currentLevel.getTitle();
    PlayStatePlaylist.campaignDifficulty = currentDifficultyId;

    Highscore.talliesLevel = new funkin.Highscore.Tallies();

    new FlxTimer().start(1, function(tmr:FlxTimer)
    {
      #if (mobile || FEATURE_TOUCH_CONTROLS)
      if (DeviceUtil.isMobileBrowser && backButton != null) FlxTween.tween(backButton, {alpha: 0}, 0.2, {ease: FlxEase.quadOut});
      #end

      FlxTransitionableState.skipNextTransIn = false;
      FlxTransitionableState.skipNextTransOut = false;

      var targetVariation:String = targetSong.getFirstValidVariation(PlayStatePlaylist.campaignDifficulty);

      FlxG.camera.fade(FlxColor.BLACK, 0.2, false, function()
      {
        LoadingState.loadPlayState({
          targetSong: targetSong,
          targetDifficulty: PlayStatePlaylist.campaignDifficulty,
          targetVariation: targetVariation
        }, true);
      });
    });
  }

  function updateBackground(?previousLevelId:String = ''):Void
  {
    if (Preferences.menuStyle == "NovaBeat")
    {
      // NovaBeat keeps its own full-screen menu artwork while the selected
      // week changes; the original FNF per-week background system stays below.
      if (levelBackground != null) return;

      levelBackground = new FlxSprite().loadGraphic(Paths.image('novabeat/menu-background'));
      var backgroundScale:Float = Math.max(FlxG.width / levelBackground.width, FlxG.height / levelBackground.height);
      levelBackground.scale.set(backgroundScale, backgroundScale);
      levelBackground.updateHitbox();
      levelBackground.screenCenter();
      levelBackground.scrollFactor.set();
      levelBackground.zIndex = -100;
      levelBackground.alpha = 1.0;
      add(levelBackground);
      return;
    }

    // Original FNF Story Mode background behavior.
    if (levelBackground == null || previousLevelId == '')
    {
      levelBackground = currentLevel.buildBackground();
      levelBackground.x = 0;
      levelBackground.y = BACKGROUND_Y;
      levelBackground.zIndex = 100;
      levelBackground.alpha = 1.0;
      add(levelBackground);
    }
    else
    {
      var previousLevel = LevelRegistry.instance.fetchEntry(previousLevelId);

      if (currentLevel.isBackgroundSimple() && previousLevel.isBackgroundSimple())
      {
        var previousColor:FlxColor = previousLevel.getBackgroundColor();
        var currentColor:FlxColor = currentLevel.getBackgroundColor();
        if (previousColor != currentColor)
        {
          FlxTween.cancelTweensOf(levelBackground);
          FlxTween.color(levelBackground, 0.9, levelBackground.color, currentColor, {ease: FlxEase.quartOut});
        }
      }
      else
      {
        var oldBackground:FlxSprite = levelBackground;
        FlxTween.tween(oldBackground, {alpha: 0.0}, 0.6, {
          ease: FlxEase.linear,
          onComplete: function(_)
          {
            remove(oldBackground);
          }
        });

        levelBackground = currentLevel.buildBackground();
        levelBackground.x = 0;
        levelBackground.y = BACKGROUND_Y;
        levelBackground.alpha = 0.0;
        levelBackground.zIndex = 100;
        add(levelBackground);

        FlxTween.tween(levelBackground, {alpha: 1.0}, 0.6, {
          ease: FlxEase.linear
        });
      }
    }
  }

  /**
   * Add the dark lower panel used behind the NovaBeat week carousel.
   * Its top edge matches the bottom edge of the stock FNF week-background
   * region, so the week list begins in the same place in both menu styles.
   */
  function updateNovaBeatWeekPanel(width:Int, height:Int):Void
  {
    if (Preferences.menuStyle != "NovaBeat") return;

    if (width <= 0 || height <= 0) return;

    var portrait:Bool = height > width * 1.12;
    // The stock background area is 456px tall in the desktop layout. Scale
    // that boundary down on short browser viewports; portrait uses its own
    // lower-screen band for the week/track information.
    var panelY:Int = portrait
      ? Std.int(height * 0.66)
      : Std.int(Math.min(BACKGROUND_Y + BACKGROUND_HEIGHT, height * 0.635));
    panelY = Std.int(Math.max(0, Math.min(height - 1, panelY)));
    var panelHeight:Int = Std.int(Math.max(1, height - panelY));

    if (novaBeatWeekPanel == null)
    {
      novaBeatWeekPanel = new FlxSprite();
      novaBeatWeekPanel.scrollFactor.set();
      // Draw above the full-screen background but immediately below the week-title group.
      novaBeatWeekPanel.zIndex = 14;
      novaBeatWeekPanel.alpha = 1.0;
      add(novaBeatWeekPanel);
    }

    novaBeatWeekPanel.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, panelHeight)), FlxColor.BLACK);
    novaBeatWeekPanel.setPosition(0, panelY);
  }

  function updateProps():Void
  {
    for (ind => prop in currentLevel.buildProps(levelProps.members))
    {
      // Tutorial data sets danceEvery: 2; normalize only this preview.
      if (currentLevelId == "tutorial") prop.danceEvery = 1.0;
      prop.x += (FullScreenScaleMode.gameCutoutSize.x / 4);
      prop.zIndex = 1000;
      if (levelProps.members[ind] != prop) levelProps.replace(levelProps.members[ind], prop) ?? levelProps.add(prop);
    }

    refresh();
  }

  function updateText():Void
  {
    tracklistText.text = 'TRACKS\n\n';
    tracklistText.text += currentLevel.getSongDisplayNames(currentDifficultyId).join('\n');

    if (Preferences.menuStyle == "NovaBeat")
    {
      if (FlxG.height > FlxG.width * 1.12)
      {
        var margin:Float = Math.max(18, FlxG.width * 0.045);
        tracklistText.fieldWidth = FlxG.width - margin * 2;
        tracklistText.alignment = CENTER;
        tracklistText.x = margin;
        tracklistText.y = FlxG.height * 0.76;
      }
      else
      {
        tracklistText.fieldWidth = FlxG.width * 0.55;
        tracklistText.alignment = CENTER;
        tracklistText.screenCenter(X);
        tracklistText.x -= (FlxG.width * 0.33);
        tracklistText.y = FlxG.height * 0.76;
      }
    }
    else
    {
      // Original FNF track-list placement and sizing.
      tracklistText.screenCenter(X);
      tracklistText.x -= (FlxG.width * 0.33);
    }

    var levelScore:Null<SaveScoreData> = Save.instance.getLevelScore(currentLevelId, currentDifficultyId);
    highScore = levelScore?.score ?? 0;
    // levelScore.accuracy
  }

  function goBack():Void
  {
    @:privateAccess
    if (exitingMenu || selectedLevel || (stickerSubState?.switchingState ?? false)) return;

    exitingMenu = true;
    FlxG.keys.enabled = false;
    if (Preferences.menuStyle == "NovaBeat")
      FlxG.switchState(() -> new NovaBeatMainMenuState());
    else
      FlxG.switchState(() -> new MainMenuState());
    FunkinSound.playOnce(Paths.sound(Preferences.menuStyle == "NovaBeat" ? 'novabeat/back' : 'cancelMenu'));
  }

  /**
   * Reposition titles based on the currently selected one.
   */
  function repositionTitles()
  {
    if (levelTitles == null || levelTitles.members.length == 0) return;

    var currentIndex:Int = levelList.indexOf(currentLevelId);
    if (currentIndex < 0 || currentIndex >= levelTitles.members.length) return;

    var portrait:Bool = FlxG.height > FlxG.width * 1.12;
    var targetY:Float = 480;
    if (Preferences.menuStyle == "NovaBeat")
      targetY = portrait ? FlxG.height * 0.36 : Math.min(480, FlxG.height * 0.67);

    levelTitles.members[currentIndex].targetY = targetY;

    // The alpha treatment belongs only to NovaBeat. Stock FNF relies on
    // its original LevelTitle behavior and does not rewrite every item's alpha.
    if (Preferences.menuStyle == "NovaBeat")
    {
      for (index in 0...levelTitles.members.length)
      {
        var item:LevelTitle = levelTitles.members[index];
        item.alpha = index == currentIndex ? 1.0 : 0.6;
        if (index == currentIndex) currentLevelTitle = item;
      }
    }

    // Every item above it should be positioned in relation to the next item.
    if (currentIndex > 0)
    {
      for (i in 0...currentIndex)
      {
        var itemIndex:Int = currentIndex - 1 - i;
        var nextItem:LevelTitle = levelTitles.members[itemIndex + 1];
        levelTitles.members[itemIndex].targetY = nextItem.targetY - Math.max(levelTitles.members[itemIndex].height + 20, 125);
      }
    }

    // Every item below it should be positioned in relation to the previous item.
    if (currentIndex < levelTitles.members.length - 1)
    {
      for (i in (currentIndex + 1)...levelTitles.members.length)
      {
        var previousItem:LevelTitle = levelTitles.members[i - 1];
        levelTitles.members[i].targetY = previousItem.targetY + (previousItem.height + 20);
      }
    }
  }
}
