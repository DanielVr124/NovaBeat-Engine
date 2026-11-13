package funkin.ui.freeplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.song.SongRegistry;
import funkin.modding.ExperienceManager;
import funkin.play.PlayStatePlaylist;
import funkin.play.scoring.Scoring;
import funkin.play.song.Song;
import funkin.play.components.HealthIcon;
import funkin.save.Save;
import funkin.save.Save.SaveScoreData;
import funkin.ui.MusicBeatSubState;
import funkin.ui.transition.LoadingState;
import funkin.ui.transition.stickers.StickerSubState;

/**
 * Psych Engine 0.7.3-style Freeplay screen.
 *
 * It is only opened while the active experience contains launchable Psych
 * songs. The normal V-Slice FreeplayState is kept as a separate, unchanged path.
 */
@:nullSafety(Off)
class PsychFreeplayState extends MusicBeatSubState
{
  static final VARIATION:String = Constants.DEFAULT_VARIATION;
  static inline final DEFAULT_COLOR:Int = 0xFF9271FD;
  static inline final DRAW_DISTANCE:Int = 4;

  static var rememberedSelection:Int = 0;
  static var rememberedDifficulty:Map<String, String> = [];
  static var lastDifficultyName:String = Constants.DEFAULT_DIFFICULTY;

  var songs:Array<PsychFreeplaySong> = [];
  var songTexts:Array<PsychAlphabet> = [];
  var icons:Array<HealthIcon> = [];
  var selected:Int = 0;
  var lerpSelected:Float = 0;
  var holdTime:Float = 0;
  var currentDifficulties:Array<String> = [];
  var difficultyIndex:Int = 0;
  var currentDifficulty:String = Constants.DEFAULT_DIFFICULTY;

  var background:FlxSprite;
  var scoreText:FlxText;
  var scoreBackground:FlxSprite;
  var difficultyText:FlxText;
  var bottomBackground:FlxSprite;
  var bottomText:FlxText;
  var intendedColor:Int = DEFAULT_COLOR;
  var colorTween:Null<FlxTween> = null;
  var lerpedScore:Float = 0;
  var intendedScore:Int = 0;
  var lerpedRating:Float = 0;
  var intendedRating:Float = 0;

  // The original Psych preview player is represented by the same compact
  // transport panel and synchronized instrumental/vocal playback.
  var previewPlaying:Bool = false;
  var previewPlaybackRate:Float = 1.0;
  var previewSeekHoldTime:Float = 0;
  var previewRateHoldTime:Float = 0;
  var previewPlaybackText:FlxText;
  var previewPlaybackBackground:FlxSprite;
  var previewArrowUp:FlxText;
  var previewArrowDown:FlxText;
  var menuMusicBeforePreview:Null<FlxSound> = null;
  var previewPaused:Bool = false;
  var previewVocals:Array<FunkinSound> = [];
  var previewBackground:FlxSprite;
  var previewTitle:FlxText;
  var previewTime:FlxText;
  var previewBarBack:FlxSprite;
  var previewBarFill:FlxSprite;
  var resetPrompt:Bool = false;
  var resetPromptAlpha:Float = 0;
  var resetSelection:Int = 0;
  var resetBackground:FlxSprite;
  var resetHeader:PsychAlphabet;
  var resetSongTitle:PsychAlphabet;
  var resetYes:PsychAlphabet;
  var resetNo:PsychAlphabet;
  var resetIcon:HealthIcon;
  var previewWasPlaying:Bool = false;
  var stickerSubState:Null<StickerSubState> = null;

  public function new(?stickers:StickerSubState)
  {
    super(FlxColor.BLACK);
    if (stickers?.members != null) stickerSubState = stickers;
  }

  override function create():Void
  {
    super.create();

    persistentUpdate = true;
    PlayStatePlaylist.isStoryMode = false;

    if (!ExperienceManager.hasActivePsychSongs())
    {
      close();
      return;
    }

    if (stickerSubState != null)
    {
      persistentUpdate = true;
      persistentDraw = true;
      openSubState(stickerSubState);
      stickerSubState.degenStickers();
    }

    FunkinSound.playMusic('freakyMenu', {
      overrideExisting: true,
      restartTrack: false,
      loop: true,
      mapTimeChanges: false
    });

    buildSongList();
    if (songs.length == 0)
    {
      FlxG.log.warn('[Psych Freeplay] The active Psych experience has no imported songs.');
      close();
      return;
    }

    background = new FlxSprite().loadGraphic(Paths.image('menuDesat', 'shared'));
    background.antialiasing = true;
    background.screenCenter();
    background.scrollFactor.set();
    add(background);

    createSongRows();
    createScorePanel();
    createBottomHelp();
    createPreviewPanel();
    createResetPrompt();

    selected = rememberedSelection;
    if (selected < 0 || selected >= songs.length) selected = 0;
    background.color = songs[selected].color;
    intendedColor = background.color;
    lerpSelected = selected;
    changeSelection(0, false);
    updateSongRows(0);

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    addHitbox(true);
    addBackButton(FlxG.width - 92, FlxG.height - 92, FlxColor.WHITE, goBack, 0.65);
    #end
  }

  function buildSongList():Void
  {
    songs = [];
    var orderedSongIds = funkin.modding.PsychModRuntime.getPsychFreeplaySongOrder();

    for (songId in orderedSongIds)
    {
      if (!ExperienceManager.isPsychSong(songId)) continue;
      var song:Null<Song> = SongRegistry.instance.fetchEntry(songId, {variation: VARIATION});
      if (song == null) continue;

      var difficulties:Array<String> = song.listDifficulties(null, [VARIATION], true, true);
      if (difficulties.length == 0) continue;

      var firstDifficulty = song.getDifficulty(difficulties[0], VARIATION);
      var iconId:String = firstDifficulty?.characters?.opponent ?? 'face';
      var freeplayIcon:Null<String> = funkin.modding.PsychModRuntime.getPsychFreeplayIcon(songId, iconId);
      var color:Int = funkin.modding.PsychModRuntime.getPsychFreeplayColor(songId);
      songs.push({
        id: songId,
        song: song,
        name: song.songName,
        icon: freeplayIcon ?? iconId,
        color: color
      });
    }
  }

  function createSongRows():Void
  {
    for (i in 0...songs.length)
    {
      var songText = new PsychAlphabet(0, FlxG.height * 0.48, songs[i].name);
      // PsychAlphabet is a FlxSpriteGroup: its own scroll factor also affects
      // child glyph rendering, even when each glyph has a zero scroll factor.
      // Keep both group and glyphs in screen space so gameplay camera scroll
      // cannot move the Freeplay rows outside the viewport.
      songText.scrollFactor.set(0, 0);
      songText.targetY = i;
      songText.setMenuScale(Math.min(1, 980 / Math.max(1, songText.textWidth)));
      songText.visible = false;
      songText.active = false;
      // Freeplay rows are screen-space UI and must not follow gameplay camera scroll.
      songText.scrollFactor.set(0, 0);
      songTexts.push(songText);

      var icon = new HealthIcon(songs[i].icon);
      // A freshly constructed HealthIcon does not load its graphic until
      // configure() is called. Supply the Psych song's icon ID explicitly,
      // including pixel metadata when the icon belongs to a pixel character.
      var iconCharacterData = CharacterDataParser.fetchCharacterData(songs[i].icon);
      var iconScale:Float = Math.min(1.0, Math.max(0.5, FlxG.width / 720));
      icon.configure({
        id: songs[i].icon,
        shouldBop: false,
        scale: 1.0,
        flipX: false,
        isPixel: iconCharacterData?.isPixel ?? false,
        offsets: [0.0, 0.0]
      });
      icon.size.set(iconScale, iconScale);
      icon.autoUpdate = false;
      icon.alpha = 0.6;
      icon.visible = false;
      icon.active = false;
      icon.scrollFactor.set(0, 0);
      icons.push(icon);
    }

    // Draw the complete icon column first, then every song title above it.
    // Long/tall icons can no longer paint over neighboring song names.
    for (icon in icons) add(icon);
    for (songText in songTexts) add(songText);
  }

  function createScorePanel():Void
  {
    scoreText = new FlxText(FlxG.width * 0.7, 5, 0, '', 32);
    scoreText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    scoreText.scrollFactor.set();

    scoreBackground = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, FlxColor.BLACK);
    scoreBackground.alpha = 0.6;
    scoreBackground.scrollFactor.set();
    add(scoreBackground);

    difficultyText = new FlxText(scoreText.x, scoreText.y + 36, 0, '', 24);
    difficultyText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.CENTER);
    difficultyText.scrollFactor.set();
    add(difficultyText);
    add(scoreText);
  }

  function positionHighscore():Void
  {
    scoreText.x = FlxG.width - scoreText.width - 6;
    scoreBackground.scale.x = FlxG.width - scoreText.x + 6;
    scoreBackground.x = FlxG.width - (scoreBackground.scale.x / 2);
    difficultyText.x = Std.int(scoreBackground.x + (scoreBackground.width / 2));
    difficultyText.x -= difficultyText.width / 2;
  }

  function createBottomHelp():Void
  {
    bottomBackground = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, FlxColor.BLACK);
    bottomBackground.alpha = 0.6;
    bottomBackground.scrollFactor.set();
    add(bottomBackground);

    var help = 'Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.';
    bottomText = new FlxText(0, bottomBackground.y + 4, FlxG.width, help, 16);
    bottomText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.CENTER);
    bottomText.scrollFactor.set();
    add(bottomText);
  }

  function createPreviewPanel():Void
  {
    var xPos:Float = FlxG.width * 0.7;

    previewBackground = new FlxSprite(xPos - 6, 0).makeGraphic(1, 100, FlxColor.BLACK);
    previewBackground.alpha = 0.6;
    previewBackground.scrollFactor.set();
    add(previewBackground);

    previewPlaybackBackground = new FlxSprite(xPos - 6, 0).makeGraphic(1, 100, FlxColor.BLACK);
    previewPlaybackBackground.alpha = 0.6;
    previewPlaybackBackground.scrollFactor.set();
    add(previewPlaybackBackground);

    previewTitle = new FlxText(xPos, 5, 0, '', 32);
    previewTitle.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    previewTitle.scrollFactor.set();
    add(previewTitle);

    previewTime = new FlxText(xPos, 65, 0, '< 00:00 / 00:00 >', 32);
    previewTime.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    previewTime.scrollFactor.set();
    add(previewTime);

    previewPlaybackText = new FlxText(FlxG.width * 0.6, 20, 0, '1.00x', 32);
    previewPlaybackText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE);
    previewPlaybackText.scrollFactor.set();
    add(previewPlaybackText);

    previewArrowUp = new FlxText(0, 0, 0, '^', 32);
    previewArrowUp.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
    previewArrowUp.scrollFactor.set();
    add(previewArrowUp);

    previewArrowDown = new FlxText(0, 0, 0, '^', 32);
    previewArrowDown.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
    previewArrowDown.flipY = true;
    previewArrowDown.scrollFactor.set();
    add(previewArrowDown);

    previewBarBack = new FlxSprite(xPos, 98).makeGraphic(1, 5, FlxColor.BLACK);
    previewBarBack.scrollFactor.set();
    add(previewBarBack);

    previewBarFill = new FlxSprite(xPos, 98).makeGraphic(1, 5, FlxColor.WHITE);
    previewBarFill.scrollFactor.set();
    add(previewBarFill);

    positionPreview();
    setPreviewPanelVisible(false);
  }

  function positionPreview():Void
  {
    if (previewTitle == null || previewTime == null || songs.length == 0) return;

    var length:Int = songs[selected].name.length;
    var shortName:Bool = length < 5;

    previewTitle.x = FlxG.width - previewTitle.width - 6;
    if (shortName) previewTitle.x -= 10 * length - length;

    previewBackground.scale.x = FlxG.width - previewTitle.x + 12;
    previewBackground.x = FlxG.width - (previewBackground.scale.x / 2);

    previewTime.x = Std.int(previewBackground.x + (previewBackground.width / 2));
    previewTime.x -= previewTime.width / 2;
    if (shortName) previewTime.x -= length - 5;

    previewPlaybackBackground.scale.x = previewPlaybackText.width + 30;
    previewPlaybackBackground.x = previewBackground.x - (previewBackground.scale.x / 2);
    previewPlaybackBackground.x -= previewPlaybackBackground.scale.x;

    previewPlaybackText.x = previewPlaybackBackground.x - previewPlaybackText.width / 2;
    previewPlaybackText.y = previewPlaybackText.height;

    previewBarBack.scale.x = Math.max(1, previewTitle.width);
    previewBarBack.y = previewTitle.y + previewTitle.height + 10;
    previewBarBack.x = previewTitle.x + previewTitle.width / 2 - 15;

    previewBarFill.x = previewBarBack.x;
    previewBarFill.y = previewBarBack.y;
    previewBarFill.scale.x = previewBarBack.scale.x;

    previewArrowUp.x = previewPlaybackText.x + previewPlaybackText.width / 2 - 10;
    previewArrowUp.y = previewPlaybackText.y - previewPlaybackText.height;
    previewArrowDown.x = previewArrowUp.x;
    previewArrowDown.y = previewPlaybackText.y + previewPlaybackText.height;
  }

  function createResetPrompt():Void
  {
    resetBackground = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    resetBackground.alpha = 0;
    resetBackground.scrollFactor.set();
    resetBackground.visible = false;
    add(resetBackground);

    resetHeader = new PsychAlphabet(0, 180, 'Reset the score of');
    resetHeader.setMenuPosition((FlxG.width - resetHeader.textWidth) / 2, 180);
    resetHeader.visible = false;
    add(resetHeader);

    resetSongTitle = new PsychAlphabet(0, 270, '');
    resetSongTitle.visible = false;
    add(resetSongTitle);

    resetIcon = new HealthIcon('face');
    resetIcon.autoUpdate = false;
    resetIcon.visible = false;
    add(resetIcon);

    resetYes = new PsychAlphabet(0, 0, 'Yes');
    resetYes.visible = false;
    add(resetYes);

    resetNo = new PsychAlphabet(0, 0, 'No');
    resetNo.visible = false;
    add(resetNo);
  }

  function showResetPrompt():Void
  {
    resetPrompt = true;
    resetPromptAlpha = 0;
    resetSelection = 1;
    var entry = songs[selected];
    var title:String = entry.name + ' (' + currentDifficulty.toUpperCase() + ')?';
    var scale:Float = title.length > 18 ? 0.8 : 1.0;

    remove(resetSongTitle, true);
    resetSongTitle.destroy();
    resetSongTitle = new PsychAlphabet(0, 270, title);
    resetSongTitle.setMenuScale(scale);
    resetSongTitle.setMenuPosition((FlxG.width - resetSongTitle.textWidth) / 2 + (60 * scale), 270);
    resetSongTitle.visible = true;
    add(resetSongTitle);

    resetIcon.characterId = entry.icon;
    resetIcon.size.set(scale, scale);
    resetIcon.visible = true;
    resetIcon.alpha = 0;
    resetIcon.setPosition(resetSongTitle.x - resetIcon.width + (10 * scale), resetSongTitle.y - 30);

    resetYes.setMenuPosition((FlxG.width - resetYes.textWidth) / 2 - 200, resetSongTitle.y + 150);
    resetNo.setMenuPosition((FlxG.width - resetNo.textWidth) / 2 + 200, resetSongTitle.y + 150);
    for (item in [resetBackground, resetHeader, resetSongTitle, resetIcon, resetYes, resetNo])
      item.visible = true;
    updateResetSelection();
  }

  function updateResetSelection():Void
  {
    resetYes.setMenuScale(resetSelection == 0 ? 1.0 : 0.75);
    resetNo.setMenuScale(resetSelection == 1 ? 1.0 : 0.75);
    resetYes.setMenuAlpha(resetSelection == 0 ? 1.25 : 0.6);
    resetNo.setMenuAlpha(resetSelection == 1 ? 1.25 : 0.6);
    resetIcon.playAnimation(resetSelection == 0 ? "idle" : "losing", "idle", true);
  }

  function updateResetPrompt(elapsed:Float):Void
  {
    resetPromptAlpha = Math.min(0.6, resetPromptAlpha + elapsed * 1.5);
    resetBackground.alpha = resetPromptAlpha;
    var textAlpha:Float = Math.min(1.0, resetPromptAlpha / 0.6);
    resetHeader.setMenuAlpha(textAlpha);
    resetSongTitle.setMenuAlpha(textAlpha);
    resetIcon.alpha = textAlpha;
  }

  function closeResetPrompt():Void
  {
    resetPrompt = false;
    resetBackground.visible = false;
    resetHeader.visible = false;
    resetSongTitle.visible = false;
    resetIcon.visible = false;
    resetYes.visible = false;
    resetNo.visible = false;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (stickerSubState?.isSwitchingState() ?? false) return;

    if (resetPrompt)
    {
      updateResetPrompt(elapsed);
      if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
      {
        resetSelection = 1 - resetSelection;
        updateResetSelection();
        FunkinSound.playOnce(Paths.sound('scrollMenu', 'shared'));
      }
      if (controls.BACK)
      {
        closeResetPrompt();
        FunkinSound.playOnce(Paths.sound('cancelMenu', 'shared'));
      }
      else if (controls.ACCEPT)
      {
        if (resetSelection == 0)
        {
          var entry = songs[selected];
          Save.instance.removeSongScore(entry.id, currentDifficulty, VARIATION);
          updateScore();
        }
        closeResetPrompt();
        FunkinSound.playOnce(Paths.sound('cancelMenu', 'shared'));
      }
      return;
    }

    if (previewPlaying)
    {
      updatePreview(elapsed);
      if (!previewPlaying) return;
      updatePreviewControls(elapsed);
      if (controls.BACK)
      {
        stopPreview();
        return;
      }
      if (FlxG.keys.justPressed.SPACE || controls.ACCEPT)
        togglePreviewPause();
    }
    else
    {
      if (songs.length > 1)
      {
        var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;

        if (FlxG.keys.justPressed.HOME)
        {
          changeSelection(-selected, true);
          holdTime = 0;
        }
        else if (FlxG.keys.justPressed.END)
        {
          changeSelection((songs.length - 1) - selected, true);
          holdTime = 0;
        }
        else if (controls.UI_UP_P)
        {
          changeSelection(-shiftMult, true);
          holdTime = 0;
        }
        else if (controls.UI_DOWN_P)
        {
          changeSelection(shiftMult, true);
          holdTime = 0;
        }

        if (controls.UI_UP || controls.UI_DOWN)
        {
          var previousHold:Int = Math.floor((holdTime - 0.5) * 10);
          holdTime += elapsed;
          var currentHold:Int = Math.floor((holdTime - 0.5) * 10);
          if (holdTime > 0.5 && currentHold > previousHold)
          {
            var step = currentHold - previousHold;
            changeSelection(step * (controls.UI_UP ? -1 : 1) * shiftMult, true);
          }
        }
        else holdTime = 0;

        if (FlxG.mouse.wheel != 0)
        {
          FunkinSound.playOnce(Paths.sound('scrollMenu', 'shared'), 0.2);
          changeSelection(-shiftMult * FlxG.mouse.wheel, false);
        }
      }

      if (controls.UI_LEFT_P) changeDifficulty(-1);
      else if (controls.UI_RIGHT_P) changeDifficulty(1);

      if (FlxG.keys.justPressed.SPACE)
      {
        startPreview();
      }
      else if (controls.ACCEPT)
      {
        startSelectedSong();
        return;
      }
      else if (controls.RESET)
      {
        showResetPrompt();
        return;
      }
      else if (controls.BACK)
      {
        goBack();
        return;
      }

      // Mouse clicks also act as taps on touch devices: first tap selects a
      // visible row; tapping the selected row again launches it.
      if (FlxG.mouse.justPressed)
      {
        for (i in 0...songTexts.length)
        {
          var item = songTexts[i];
          if (!item.visible) continue;

          var icon:HealthIcon = icons[i];
          var left:Float = Math.min(item.x - 20, icon.x - 10);
          var right:Float = item.x + item.textWidth + 20;
          var top:Float = Math.min(item.y - 18, icon.y - 10);
          var bottom:Float = Math.max(item.y + 82, icon.y + icon.height + 10);
          if (FlxG.mouse.x < left || FlxG.mouse.x > right || FlxG.mouse.y < top || FlxG.mouse.y > bottom) continue;

          if (i == selected)
          {
            startSelectedSong();
            return;
          }
          changeSelection(i - selected, true);
          break;
        }
      }
    }

    lerpedScore = FlxMath.lerp(intendedScore, lerpedScore, Math.exp(-elapsed * 24));
    lerpedRating = FlxMath.lerp(intendedRating, lerpedRating, Math.exp(-elapsed * 12));
    if (Math.abs(lerpedScore - intendedScore) <= 10) lerpedScore = intendedScore;
    if (Math.abs(lerpedRating - intendedRating) <= 0.0001) lerpedRating = intendedRating;

    updateScoreText();
    positionHighscore();
    updateSongRows(elapsed);
  }

  function changeSelection(change:Int = 0, playSound:Bool = true):Void
  {
    if (songs.length == 0) return;
    if (playSound) FunkinSound.playOnce(Paths.sound('scrollMenu', 'shared'), 0.4);

    var previousDifficulties:Array<String> = currentDifficulties.copy();
    selected = ((selected + change) % songs.length + songs.length) % songs.length;
    rememberedSelection = selected;

    var entry = songs[selected];
    if (entry.color != intendedColor)
    {
      colorTween?.cancel();
      intendedColor = entry.color;
      colorTween = FlxTween.color(background, 1, background.color, intendedColor);
    }

    for (i in 0...songTexts.length)
    {
      songTexts[i].setMenuAlpha(i == selected ? 1.0 : 0.6);
      icons[i].alpha = i == selected ? 1.0 : 0.6;
    }

    currentDifficulties = entry.song.listDifficulties(null, [VARIATION], true, true);
    if (currentDifficulties.length == 0) currentDifficulties = [Constants.DEFAULT_DIFFICULTY];

    var savedDiff:Null<String> = rememberedDifficulty.get(entry.id);
    var savedIndex:Int = savedDiff == null ? -1 : currentDifficulties.indexOf(savedDiff);
    var lastIndex:Int = currentDifficulties.indexOf(lastDifficultyName);
    var defaultIndex:Int = currentDifficulties.indexOf(Constants.DEFAULT_DIFFICULTY);

    // Psych first carries a song's own saved difficulty only when it is not
    // part of the previous song's list; otherwise the last global difficulty wins.
    if (savedIndex >= 0 && savedDiff != null && !previousDifficulties.contains(savedDiff))
      difficultyIndex = savedIndex;
    else if (lastIndex >= 0)
      difficultyIndex = lastIndex;
    else if (defaultIndex >= 0)
      difficultyIndex = defaultIndex;
    else
      difficultyIndex = 0;

    currentDifficulty = currentDifficulties[difficultyIndex];
    lastDifficultyName = currentDifficulty;
    rememberedDifficulty.set(entry.id, currentDifficulty);
    updateDifficultyText();
    updateScore();
  }

  function changeDifficulty(change:Int):Void
  {
    if (currentDifficulties.length <= 1) return;
    difficultyIndex = (difficultyIndex + change) % currentDifficulties.length;
    if (difficultyIndex < 0) difficultyIndex += currentDifficulties.length;
    currentDifficulty = currentDifficulties[difficultyIndex];
    lastDifficultyName = currentDifficulty;
    rememberedDifficulty.set(songs[selected].id, currentDifficulty);
    updateDifficultyText();
    updateScore();
  }

  function updateDifficultyText():Void
  {
    var label = currentDifficulty.toUpperCase();
    difficultyText.text = currentDifficulties.length > 1 ? '< ' + label + ' >' : label;
  }

  function updateScore():Void
  {
    var score:Null<SaveScoreData> = Save.instance.getSongScore(songs[selected].id, currentDifficulty, VARIATION);
    intendedScore = score?.score ?? 0;
    intendedRating = Math.max(0, Scoring.tallyCompletion(score?.tallies));
    if (!Math.isFinite(intendedRating)) intendedRating = 0;
  }

  function updateScoreText():Void
  {
    var rating = Std.string(Math.floor(lerpedRating * 10000) / 100);
    var parts = rating.split('.');
    if (parts.length == 1) parts.push('00');
    while (parts[1].length < 2) parts[1] += '0';
    scoreText.text = 'PERSONAL BEST: ' + Std.int(lerpedScore) + ' (' + parts[0] + '.' + parts[1] + '%)';
    positionHighscore();
  }

  function updateSongRows(elapsed:Float):Void
  {
    lerpSelected = FlxMath.lerp(selected, lerpSelected, Math.exp(-elapsed * 9.6));

    // Preserve the original Psych Freeplay scrolling window and row spacing.
    var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - DRAW_DISTANCE)));
    var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + DRAW_DISTANCE)));
    var rowSpacing:Float = Math.min(156, Math.max(88, FlxG.height * 0.19));
    var centerY:Float = FlxG.height * 0.48;

    // Use one shared icon column and one shared title column for every row.
    // Reserving icon space even when an icon fails to load prevents titles
    // from jumping horizontally between songs.
    var iconX:Float = Math.max(16, FlxG.width * 0.08);
    var iconScale:Float = Math.min(1.0, Math.max(0.5, FlxG.width / 720));
    var titleX:Float = iconX + (HealthIcon.HEALTH_ICON_SIZE * iconScale) + 14;
    var availableTextWidth:Float = Math.max(1, FlxG.width - titleX - 24);

    for (i in 0...songTexts.length)
    {
      var item:PsychAlphabet = songTexts[i];
      var icon:HealthIcon = icons[i];
      if (Math.abs(icon.size.x - iconScale) > 0.01) icon.size.set(iconScale, iconScale);
      var offset:Float = item.targetY - lerpSelected;
      var visible:Bool = i >= min && i < max;

      item.visible = item.active = visible;
      icon.visible = icon.active = visible;
      if (!visible) continue;

      item.setMenuMaxWidth(availableTextWidth);
      var y:Float = centerY + offset * rowSpacing;

      icon.setPosition(iconX, y - (icon.height * 0.5));
      item.setMenuPosition(titleX, y);
    }
  }

  function startPreview():Void
  {
    if (songs.length == 0) return;
    var entry = songs[selected];
    var previewDifficulty = entry.song.getDifficulty(currentDifficulty, VARIATION);
    if (previewDifficulty == null)
    {
      FlxG.log.warn('[Psych Freeplay] Missing preview difficulty ' + currentDifficulty + ' for ' + entry.id);
      return;
    }

    // Keep the main menu theme alive underneath the preview, then restore it
    // when preview playback ends.
    menuMusicBeforePreview = FlxG.sound.music;
    menuMusicBeforePreview?.pause();

    previewDifficulty.playInst(0.8, '', false);
    if (FlxG.sound.music == null || !FlxG.sound.music.exists)
    {
      FlxG.log.warn('[Psych Freeplay] Could not load preview instrumental for ' + entry.id);
      stopPreviewAudioOnly(true);
      return;
    }

    previewVocals = [];
    for (voicePath in previewDifficulty.buildVoiceList())
    {
      var voice = FunkinSound.load(voicePath, 0.8, true, false, true, false, null, null, false, #if web true #else false #end);
      if (voice != null) previewVocals.push(voice);
    }
    for (voice in previewVocals) voice.time = FlxG.sound.music.time;

    previewPlaying = true;
    previewPaused = false;
    previewPlaybackRate = 1.0;
    previewSeekHoldTime = 0;
    previewRateHoldTime = 0;
    applyPreviewPlaybackRate();
    previewTitle.text = 'PLAYING: ' + entry.name;
    previewWasPlaying = false;
    positionPreview();
    setPreviewPanelVisible(true);
    scoreBackground.visible = false;
    scoreText.visible = false;
    difficultyText.visible = false;
    bottomText.text = 'Press SPACE to Pause / Press ESCAPE to Exit / Press R to Reset the Song';
  }

  function updatePreview(elapsed:Float):Void
  {
    var music = FlxG.sound.music;
    if (music == null || !music.exists || (!music.playing && music.time >= music.length && music.length > 0))
    {
      stopPreview();
      return;
    }

    if (!previewPaused)
    {
      for (voice in previewVocals)
      {
        if (music.time > 5 && Math.abs(voice.time - music.time) >= 5)
          voice.time = music.time;
      }
    }

    var duration:Float = Math.max(0, music.length);
    var current:Float = Math.max(0, music.time);
    previewTime.text = '< ' + formatTime(current) + ' / ' + formatTime(duration) + ' >';

    var progress:Float = duration > 0 ? Math.max(0, Math.min(1, current / duration)) : 0;
    previewBarFill.scale.x = previewBarBack.scale.x * progress;
  }

  function updatePreviewControls(elapsed:Float):Void
  {
    var music = FlxG.sound.music;
    if (music == null || !music.exists) return;

    if (controls.UI_LEFT_P)
    {
      if (!previewPaused && !previewWasPlaying)
      {
        previewWasPlaying = true;
        music.pause();
        for (voice in previewVocals) voice.pause();
      }
      previewSeekHoldTime = 0;
      seekPreview(-1000);
    }
    else if (controls.UI_RIGHT_P)
    {
      if (!previewPaused && !previewWasPlaying)
      {
        previewWasPlaying = true;
        music.pause();
        for (voice in previewVocals) voice.pause();
      }
      previewSeekHoldTime = 0;
      seekPreview(1000);
    }

    if (controls.UI_LEFT || controls.UI_RIGHT)
    {
      previewSeekHoldTime += elapsed;
      if (previewSeekHoldTime > 0.5)
        seekPreview(40000 * elapsed * (controls.UI_LEFT ? -1 : 1));
    }
    else
    {
      previewSeekHoldTime = 0;
      if (previewWasPlaying)
      {
        music.resume();
        for (voice in previewVocals) voice.resume();
        previewWasPlaying = false;
      }
    }

    if (controls.UI_UP_P)
    {
      previewRateHoldTime = 0;
      previewPlaybackRate = Math.min(3.0, FlxMath.roundDecimal(previewPlaybackRate + 0.05, 2));
      applyPreviewPlaybackRate();
    }
    else if (controls.UI_DOWN_P)
    {
      previewRateHoldTime = 0;
      previewPlaybackRate = Math.max(0.25, FlxMath.roundDecimal(previewPlaybackRate - 0.05, 2));
      applyPreviewPlaybackRate();
    }

    if (controls.UI_UP || controls.UI_DOWN)
    {
      previewRateHoldTime += elapsed;
      if (previewRateHoldTime > 0.6)
      {
        var direction:Int = controls.UI_UP ? 1 : -1;
        previewPlaybackRate = Math.max(0.25,
          Math.min(3.0, FlxMath.roundDecimal(previewPlaybackRate + direction * 0.05 * elapsed * 8, 2)));
        applyPreviewPlaybackRate();
      }
    }
    else
    {
      previewRateHoldTime = 0;
    }

    if (controls.RESET)
    {
      previewPlaybackRate = 1.0;
      music.time = 0;
      for (voice in previewVocals) voice.time = 0;
      applyPreviewPlaybackRate();
    }
  }

  function applyPreviewPlaybackRate():Void
  {
    var music = FlxG.sound.music;
    if (music != null && music.exists) music.pitch = previewPlaybackRate;
    for (voice in previewVocals) voice.pitch = previewPlaybackRate;
    if (previewPlaybackText != null)
    {
      var rateText:Array<String> = Std.string(FlxMath.roundDecimal(previewPlaybackRate, 2)).split('.');
      if (rateText.length == 1) rateText.push('00');
      while (rateText[1].length < 2) rateText[1] += '0';
      previewPlaybackText.text = rateText[0] + '.' + rateText[1] + 'x';
      positionPreview();
    }
  }

  function seekPreview(amount:Float):Void
  {
    var music = FlxG.sound.music;
    if (music == null || !music.exists) return;
    var nextTime = Math.max(0, Math.min(music.length, music.time + amount));
    music.time = nextTime;
    for (voice in previewVocals) voice.time = nextTime;
  }

  function togglePreviewPause():Void
  {
    var music = FlxG.sound.music;
    if (music == null || !music.exists) return;
    previewPaused = !previewPaused;
    if (previewPaused)
    {
      music.pause();
      for (voice in previewVocals) voice.pause();
      previewTitle.text = 'PLAYING: ' + songs[selected].name + ' (PAUSED)';
    }
    else
    {
      music.resume();
      for (voice in previewVocals) voice.resume();
      previewTitle.text = 'PLAYING: ' + songs[selected].name;
    }
  }

  function stopPreviewAudioOnly(restoreMenuMusic:Bool = false):Void
  {
    for (voice in previewVocals)
    {
      voice.stop();
      voice.destroy();
    }
    previewVocals = [];

    if (FlxG.sound.music != null && FlxG.sound.music != menuMusicBeforePreview)
      FlxG.sound.music.stop();

    if (restoreMenuMusic && menuMusicBeforePreview != null)
    {
      FlxG.sound.music = menuMusicBeforePreview;
      menuMusicBeforePreview.resume();
    }
    previewWasPlaying = false;
    menuMusicBeforePreview = null;
  }

  function stopPreview():Void
  {
    stopPreviewAudioOnly(true);
    previewPlaying = false;
    previewPaused = false;
    previewWasPlaying = false;
    previewPlaybackRate = 1.0;
    setPreviewPanelVisible(false);
    scoreBackground.visible = true;
    scoreText.visible = true;
    difficultyText.visible = true;
    bottomText.text = 'Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.';
    applyPreviewPlaybackRate();
  }

  function setPreviewPanelVisible(value:Bool):Void
  {
    previewBackground.visible = value;
    previewPlaybackBackground.visible = value;
    previewPlaybackText.visible = value;
    previewArrowUp.visible = value;
    previewArrowDown.visible = value;
    previewTitle.visible = value;
    previewTime.visible = value;
    previewBarBack.visible = value;
    previewBarFill.visible = value;
  }

  static function formatTime(milliseconds:Float):String
  {
    var seconds:Int = Std.int(Math.max(0, milliseconds) / 1000);
    var minutes:Int = Std.int(seconds / 60);
    seconds %= 60;
    return (minutes < 10 ? '0' : '') + minutes + ':' + (seconds < 10 ? '0' : '') + seconds;
  }

  function startSelectedSong():Void
  {
    var entry = songs[selected];
    var targetDifficulty = entry.song.getDifficulty(currentDifficulty, VARIATION);
    if (targetDifficulty == null)
    {
      FlxG.log.warn('[Psych Freeplay] Missing chart difficulty ' + currentDifficulty + ' for ' + entry.id);
      return;
    }

    rememberedSelection = selected;
    rememberedDifficulty.set(entry.id, currentDifficulty);
    PlayStatePlaylist.isStoryMode = false;
    PlayStatePlaylist.campaignId = null;

    FunkinSound.playOnce(Paths.sound('confirmMenu', 'shared'));
    stopPreviewAudioOnly();
    previewPlaying = false;

    var instrumental:String = entry.song.getBaseInstrumentalId(currentDifficulty, targetDifficulty.variation ?? VARIATION) ?? '';
    funkin.modding.PsychModRuntime.logSongLaunchStep(entry.id, currentDifficulty, 'freeplay.selection.confirmed',
      'instrumental-id=' + instrumental);
    LoadingState.loadPlayState({
      targetSong: entry.song,
      targetDifficulty: currentDifficulty,
      targetVariation: targetDifficulty.variation ?? VARIATION,
      targetInstrumental: instrumental,
      practiceMode: false,
      minimalMode: false,
      botPlayMode: false
    }, true, true);
  }

  function goBack():Void
  {
    if (previewPlaying)
    {
      stopPreview();
      return;
    }
    colorTween?.cancel();
    FunkinSound.playOnce(Paths.sound('cancelMenu', 'shared'));
    close();
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);

    background?.screenCenter();
    bottomBackground?.makeGraphic(width, 26, FlxColor.BLACK);
    bottomBackground?.setPosition(0, height - 26);
    if (bottomText != null) bottomText.fieldWidth = width;
    bottomText?.setPosition(0, height - 22);
    if (previewBackground != null) positionPreview();
    bottomText?.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.CENTER);
    #if mobile
    if (bottomText != null) bottomText.text = 'Tap a song to select it. Tap it again to play.';
    if (scoreText != null) scoreText.setFormat(Paths.font('vcr.ttf'), Std.int(Math.max(16, Math.min(26, width * 0.06))),
      FlxColor.WHITE, FlxTextAlign.RIGHT);
    if (difficultyText != null) difficultyText.setFormat(Paths.font('vcr.ttf'), Std.int(Math.max(14, Math.min(22, width * 0.05))),
      FlxColor.WHITE, FlxTextAlign.CENTER);
    #end
    if (scoreText != null) positionHighscore();
  }

  override public function destroy():Void
  {
    colorTween?.cancel();
    if (previewPlaying) stopPreviewAudioOnly(false);
    super.destroy();
    // Don't carry a frame-atlas wrapper across Freeplay state lifetimes. Its
    // underlying bitmap may be released while this substate is being replaced.
    PsychAlphabet.clearAtlasCache();
  }
}

private typedef PsychFreeplaySong =
{
  var id:String;
  var song:Song;
  var name:String;
  var icon:String;
  var color:Int;
}
