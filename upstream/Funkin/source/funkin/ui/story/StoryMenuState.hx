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
import funkin.data.story.level.LevelRegistry;
import funkin.data.song.SongRegistry;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.PlayStatePlaylist;
import funkin.play.song.Song;
import funkin.save.Save;
import funkin.Preferences;
import funkin.save.Save.SaveScoreData;
import funkin.ui.mainmenu.MainMenuState;
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
    // The previous experience may have been unloaded since the last visit.
    // A remembered Psych week ID must not be used if it is no longer registered.
    if (levelList.indexOf(currentLevelId) < 0)
    {
      currentLevelId = levelList[0];
      rememberedLevelId = currentLevelId;
    }

    updateData();

    levelTitles = new FlxTypedGroup<LevelTitle>();
    // The stock FNF black mask is at zIndex 99, so week titles stay just below it.
    levelTitles.zIndex = 98;
    add(levelTitles);

    updateBackground();

    var black:FunkinSprite = new FunkinSprite(levelBackground.x, 0).makeSolidColor(FlxG.width, Std.int(400 + levelBackground.y), FlxColor.BLACK);
    black.zIndex = levelBackground.zIndex - 1;
    add(black);

    levelProps = new FlxTypedGroup<LevelProp>();
    levelProps.zIndex = 1000;
    add(levelProps);

    updateProps();

    // Original FNF Story Mode track-list origin.
    tracklistText = new FlxText(0, levelBackground.x + levelBackground.height + 100, 0, 'Tracks', 32);
    tracklistText.setFormat('VCR OSD Mono', 32);
    tracklistText.alignment = CENTER;
    tracklistText.color = 0xFFE55777;
    add(tracklistText);

    scoreText = new FlxText(Math.max(FullScreenScaleMode.gameNotchSize.x, 10), 10, 0, 'HIGH SCORE: 42069420');
    scoreText.setFormat('VCR OSD Mono', 32);
    scoreText.zIndex = 1000;
    add(scoreText);

    levelTitleText = new FlxText(Math.max((FlxG.width * 0.7), FlxG.width - FullScreenScaleMode.gameNotchSize.x), 10, 0, 'LEVEL 1');
    levelTitleText.setFormat('VCR OSD Mono', 32, FlxColor.WHITE, RIGHT);
    levelTitleText.alpha = 0.7;
    levelTitleText.zIndex = 1000;
    add(levelTitleText);

    buildLevelTitles();

    final useNotch:Bool = Math.max(35, FullScreenScaleMode.gameNotchSize.x) != 35;
    leftDifficultyArrow = new FlxSprite(FlxG.width - (useNotch ? (FullScreenScaleMode.gameNotchSize.x) + 410 : 410), 480);
    leftDifficultyArrow.frames = Paths.getSparrowAtlas('storymenu/ui/arrows');
    leftDifficultyArrow.animation.addByPrefix('idle', 'leftIdle0');
    leftDifficultyArrow.animation.addByPrefix('press', 'leftConfirm0');
    leftDifficultyArrow.animation.play('idle');
    add(leftDifficultyArrow);

    buildDifficultySprite(Constants.DEFAULT_DIFFICULTY);
    buildDifficultySprite();

    rightDifficultyArrow = new FlxSprite(FlxG.width - (useNotch ? FullScreenScaleMode.gameNotchSize.x * 1.5 : 35), leftDifficultyArrow.y);
    rightDifficultyArrow.frames = leftDifficultyArrow.frames;
    rightDifficultyArrow.animation.addByPrefix('idle', 'rightIdle0');
    rightDifficultyArrow.animation.addByPrefix('press', 'rightConfirm0');
    rightDifficultyArrow.animation.play('idle');
    add(rightDifficultyArrow);

    add(difficultySprite);

    updateText();
    changeDifficulty();
    changeLevel();
    refresh();
    layoutStoryMenu(FlxG.width, FlxG.height);

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
    #end
    #end
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
    FunkinSound.playMusic('freakyMenu', {
      overrideExisting: true,
      restartTrack: false,
      persist: true
    });
  }

  function playNavigationSound():Void
  {
    FunkinSound.playOnce(Paths.sound("scrollMenu"), 0.4);
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

    difficultySprite.alpha = 0;

    difficultySprite.y = leftDifficultyArrow.y - 15;
    var targetY:Float = leftDifficultyArrow.y + 10;
    targetY -= (difficultySprite.height - difficultySprites.get(Constants.DEFAULT_DIFFICULTY).height) / 2;
    FlxTween.tween(difficultySprite, {y: targetY, alpha: 1}, 0.07);

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

    levelTitleText.x = FlxG.width - (levelTitleText.width + Math.max(10, FullScreenScaleMode.gameNotchSize.x));

    handleKeyPresses();

    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    super.update(elapsed);
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
   * FNF mobile Story Mode uses the same continuous row-by-row drag model as
   * its Options list. A drag must begin on a visible week title so taps and
   * the difficulty arrows keep their normal behavior.
   */
  function handleFNFBrowserLevelDrag():Bool
  {
    #if web
    if (!DeviceUtil.isMobileBrowser || selectedLevel || exitingMenu
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
      // While a browser week-list drag is active, do not also interpret its
      // release as a one-shot swipe or a tap on a week title.
      if (handleFNFBrowserLevelDrag()) return;
      if (!selectedLevel)
      {
        // Browser swipes are one-shot so a held finger cannot repeatedly
        // advance the week list.
        final swipeToPrevious:Bool = DeviceUtil.isMobileBrowser ? menuSwipeDown() : menuSwipeUp();
        final swipeToNext:Bool = DeviceUtil.isMobileBrowser ? menuSwipeUp() : menuSwipeDown();
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
      // pressAction() owns release detection. On mobile HTML5 the browser PointerEvent
      // bridge can capture a tap even when FlxTouch.justReleased was dropped.
      if (!selectedLevel && !TouchUtil.overlaps(leftDifficultyArrow) && !SwipeUtil.justSwipedAny)
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
    if (currentIndex < 0) currentIndex = 0;
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

    currentLevelTitle = levelTitles.members[currentIndex];

    if (currentIndex != prevIndex) playNavigationSound();

    repositionTitles();
    updateText();
    updateBackground(previousLevelId);
    updateProps();
    refresh();
    layoutStoryMenu(FlxG.width, FlxG.height);
  }

  /**
   * Changes the selected difficulty.
   * @param change +1 (right) to increase difficulty, -1 (left) to decrease difficulty
   */
  function changeDifficulty(change:Int = 0):Void
  {
    // "For now, NO erect in story mode" -Dave

    var difficultyList:Array<String> = currentLevel.getDifficulties()
      .map(function(value:String):String return value.toLowerCase())
      .filter(function(value:String):Bool return Constants.DEFAULT_DIFFICULTY_LIST.contains(value));
    if (difficultyList.length == 0) difficultyList = [Constants.DEFAULT_DIFFICULTY];

    // Some Psych week definitions use a difficulty spelling/case that is not
    // present in the imported chart list. Fall back to the first valid option.
    var currentIndex:Int = difficultyList.indexOf(currentDifficultyId.toLowerCase());
    if (currentIndex < 0) currentIndex = 0;

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

    if (PlayStatePlaylist.playlistSongIds.length == 0)
    {
      FlxG.log.warn('[Story Mode] Week ' + currentLevel.id + ' does not contain any imported songs.');
      selectedLevel = false;
      currentLevelTitle.isFlashing = false;
      return;
    }
    var targetSongId:String = PlayStatePlaylist.playlistSongIds.shift();

    var targetSong:Null<Song> = SongRegistry.instance.fetchEntry(targetSongId, {variation: Constants.DEFAULT_VARIATION});
    if (targetSong == null)
    {
      FlxG.log.warn('[Story Mode] Week ' + currentLevel.id + ' references a song that is not registered: ' + targetSongId);
      selectedLevel = false;
      currentLevelTitle.isFlashing = false;
      return;
    }

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
   * Recompose Story Mode for narrow portrait screens. Keep the original
   * landscape composition untouched, but give phones clear, non-overlapping
   * zones for the week selector, track list, score, and difficulty controls.
   */
  function layoutStoryMenu(width:Int, height:Int):Void
  {
    if (width <= 0 || height <= 0) return;
    if (height <= width * 1.12) return;

    if (scoreText != null)
    {
      scoreText.setFormat('VCR OSD Mono', 18, FlxColor.WHITE, LEFT);
      scoreText.setPosition(16, 14);
      scoreText.fieldWidth = width * 0.48;
    }

    if (levelTitleText != null)
    {
      levelTitleText.setFormat('VCR OSD Mono', 18, FlxColor.WHITE, RIGHT);
      levelTitleText.fieldWidth = width * 0.48;
      levelTitleText.setPosition(width * 0.50, 14);
    }

    if (tracklistText != null)
    {
      tracklistText.setFormat('VCR OSD Mono', 19, 0xFFE55777, CENTER);
      tracklistText.fieldWidth = width - 32;
      tracklistText.setPosition(16, height * 0.66);
      tracklistText.alignment = CENTER;
    }

    if (leftDifficultyArrow != null && rightDifficultyArrow != null)
    {
      leftDifficultyArrow.scale.set(0.72, 0.72);
      rightDifficultyArrow.scale.set(0.72, 0.72);
      leftDifficultyArrow.updateHitbox();
      rightDifficultyArrow.updateHitbox();
      leftDifficultyArrow.setPosition(width * 0.19, height * 0.86);
      rightDifficultyArrow.setPosition(width * 0.72, height * 0.86);
    }

    if (difficultySprite != null)
    {
      difficultySprite.scale.set(0.72, 0.72);
      difficultySprite.updateHitbox();
      difficultySprite.setPosition((width - difficultySprite.width) * 0.5, height * 0.855);
    }

    if (levelTitles != null)
    {
      for (item in levelTitles.members)
      {
        if (item == null) continue;
        item.scale.set(0.82, 0.82);
        item.updateHitbox();
        item.x = (width - item.width) * 0.5;
      }
      repositionTitles();
    }
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    layoutStoryMenu(width, height);
  }

  function updateProps():Void
  {
    var builtProps:Array<LevelProp> = currentLevel.buildProps(levelProps.members);
    for (ind in 0...builtProps.length)
    {
      var prop:LevelProp = builtProps[ind];
      // Story Mode previews use one consistent beat cadence. Gameplay stage
      // props keep their own data-defined cadence.
      prop.danceEvery = 1.0;
      prop.x += (FullScreenScaleMode.gameCutoutSize.x / 4);
      prop.zIndex = 1000;

      if (ind < levelProps.members.length)
      {
        var existingProp:LevelProp = levelProps.members[ind];
        if (existingProp != prop) levelProps.replace(existingProp, prop) ?? levelProps.add(prop);
      }
      else
      {
        levelProps.add(prop);
      }
    }

    refresh();
  }

  function updateText():Void
  {
    tracklistText.text = 'TRACKS\n\n';
    tracklistText.text += currentLevel.getSongDisplayNames(currentDifficultyId).join('\n');

    // Original FNF track-list placement and sizing.
    tracklistText.screenCenter(X);
    tracklistText.x -= (FlxG.width * 0.33);

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
    FlxG.switchState(() -> new MainMenuState());
    FunkinSound.playOnce(Paths.sound('cancelMenu'));
  }

  /**
   * Reposition titles based on the currently selected one.
   */
  function repositionTitles()
  {
    if (levelTitles == null || levelTitles.members.length == 0) return;

    var currentIndex:Int = levelList.indexOf(currentLevelId);
    if (currentIndex < 0 || currentIndex >= levelTitles.members.length) return;

    currentLevelTitle = levelTitles.members[currentIndex];
    final portraitLayout:Bool = FlxG.height > FlxG.width * 1.12;
    levelTitles.members[currentIndex].targetY = portraitLayout ? FlxG.height * 0.40 : 480;

    // Every item above it should be positioned in relation to the next item.
    if (currentIndex > 0)
    {
      for (i in 0...currentIndex)
      {
        var itemIndex:Int = currentIndex - 1 - i;
        var nextItem:LevelTitle = levelTitles.members[itemIndex + 1];
        final titleGap:Float = portraitLayout ? Math.max(72, Math.min(112, FlxG.height * 0.12)) : 125;
        levelTitles.members[itemIndex].targetY = nextItem.targetY - Math.max(levelTitles.members[itemIndex].height + 16, titleGap);
      }
    }

    // Every item below it should be positioned in relation to the previous item.
    if (currentIndex < levelTitles.members.length - 1)
    {
      for (i in (currentIndex + 1)...levelTitles.members.length)
      {
        var previousItem:LevelTitle = levelTitles.members[i - 1];
        final titleGap:Float = portraitLayout ? Math.max(72, Math.min(112, FlxG.height * 0.12)) : 125;
        levelTitles.members[i].targetY = previousItem.targetY + Math.max(previousItem.height + 16, titleGap);
      }
    }
  }
}
