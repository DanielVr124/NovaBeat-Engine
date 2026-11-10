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
  static inline final LIST_X:Float = 90;
  static inline final LIST_Y:Float = 320;
  static inline final ITEM_SPACING_Y:Float = 156;
  static inline final DRAW_DISTANCE:Int = 4;

  static var rememberedSelection:Int = 0;
  static var rememberedDifficulty:Map<String, String> = [];

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
  var resetSelection:Int = 1;
  var resetBackground:FlxSprite;
  var resetHeader:PsychAlphabet;
  var resetSongTitle:PsychAlphabet;
  var resetYes:PsychAlphabet;
  var resetNo:PsychAlphabet;
  var resetIcon:HealthIcon;

  public function new()
  {
    super(FlxColor.BLACK);
  }

  override function create():Void
  {
    super.create();

    if (!ExperienceManager.hasActivePsychSongs())
    {
      close();
      return;
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
    background.setGraphicSize(FlxG.width, 0);
    if (background.height < FlxG.height) background.setGraphicSize(0, FlxG.height);
    background.updateHitbox();
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
    for (songId in ExperienceManager.getActivePsychSongIds())
      if (!orderedSongIds.contains(songId)) orderedSongIds.push(songId);

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
      var songText = new PsychAlphabet(LIST_X, LIST_Y, songs[i].name);
      songText.targetY = i;
      songText.setMenuScale(Math.min(1, 980 / Math.max(1, songText.textWidth)));
      songTexts.push(songText);
      add(songText);

      var icon = new HealthIcon(songs[i].icon);
      icon.autoUpdate = false;
      icon.alpha = 0.6;
      icons.push(icon);
      add(icon);
    }
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
    difficultyText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.RIGHT);
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

    var help = 'PRESS SPACE TO LISTEN  /  PRESS RESET TO RESET YOUR SCORE AND ACCURACY';
    bottomText = new FlxText(0, bottomBackground.y + 4, FlxG.width, help, 16);
    bottomText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.CENTER);
    bottomText.scrollFactor.set();
    add(bottomText);
  }

  function createPreviewPanel():Void
  {
    previewBackground = new FlxSprite(FlxG.width * 0.6, 0).makeGraphic(Std.int(FlxG.width * 0.4), 100, FlxColor.BLACK);
    previewBackground.alpha = 0.6;
    previewBackground.scrollFactor.set();
    add(previewBackground);

    previewPlaybackBackground = new FlxSprite(FlxG.width * 0.55, 0).makeGraphic(Std.int(FlxG.width * 0.15), 100, FlxColor.BLACK);
    previewPlaybackBackground.alpha = 0.6;
    previewPlaybackBackground.scrollFactor.set();
    add(previewPlaybackBackground);

    previewPlaybackText = new FlxText(FlxG.width * 0.55, 20, FlxG.width * 0.15, '1.00x', 32);
    previewPlaybackText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
    previewPlaybackText.scrollFactor.set();
    add(previewPlaybackText);

    previewTitle = new FlxText(FlxG.width * 0.7, 5, FlxG.width * 0.28, '', 32);
    previewTitle.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    previewTitle.scrollFactor.set();
    add(previewTitle);

    previewTime = new FlxText(FlxG.width * 0.7, 65, FlxG.width * 0.28, '< 00:00 / 00:00 >', 32);
    previewTime.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    previewTime.scrollFactor.set();
    add(previewTime);

    previewBarBack = new FlxSprite(FlxG.width * 0.7, 98).makeGraphic(Std.int(FlxG.width * 0.28), 5, FlxColor.BLACK);
    previewBarBack.scrollFactor.set();
    add(previewBarBack);

    previewBarFill = new FlxSprite(previewBarBack.x, previewBarBack.y).makeGraphic(Std.int(FlxG.width * 0.28), 5, FlxColor.WHITE);
    previewBarFill.scrollFactor.set();
    add(previewBarFill);

    setPreviewPanelVisible(false);
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

    resetIcon.visible = true;
    resetIcon.alpha = 0;
    resetIcon.setGraphicSize(Std.int(resetIcon.width * scale));
    resetIcon.updateHitbox();
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
      updatePreviewControls(elapsed);
      if (controls.BACK)
      {
        stopPreview();
        return;
      }
      if (FlxG.keys.justPressed.SPACE || controls.ACCEPT)
      {
        togglePreviewPause();
      }
      if (controls.UI_LEFT_P) seekPreview(-1000);
      if (controls.UI_RIGHT_P) seekPreview(1000);
      }
    else
    {
      if (songs.length > 1)
      {
        if (FlxG.keys.justPressed.HOME)
          changeSelection(-selected, true);
        else if (FlxG.keys.justPressed.END)
          changeSelection((songs.length - 1) - selected, true);
        else if (controls.UI_UP_P)
          changeSelection(FlxG.keys.pressed.SHIFT ? -3 : -1, true);
        else if (controls.UI_DOWN_P)
          changeSelection(FlxG.keys.pressed.SHIFT ? 3 : 1, true);

        if (controls.UI_UP || controls.UI_DOWN)
        {
          var previousHold:Int = Math.floor((holdTime - 0.5) * 10);
          holdTime += elapsed;
          var currentHold:Int = Math.floor((holdTime - 0.5) * 10);
          if (holdTime > 0.5 && currentHold > previousHold)
          {
            var step = currentHold - previousHold;
            changeSelection(step * (controls.UI_UP ? -1 : 1) * (FlxG.keys.pressed.SHIFT ? 3 : 1), true);
          }
        }
        else holdTime = 0;

        if (FlxG.mouse.wheel != 0)
          changeSelection(-FlxG.mouse.wheel, true);
      }

      if (controls.UI_LEFT_P) changeDifficulty(-1);
      else if (controls.UI_RIGHT_P) changeDifficulty(1);

      if (FlxG.keys.justPressed.SPACE)
        startPreview();
      else if (controls.ACCEPT)
        startSelectedSong();
      else if (controls.RESET)
      {
        showResetPrompt();
      }
      else if (controls.BACK)
        goBack();
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

    var saved = rememberedDifficulty.get(entry.id);
    var savedIndex = saved == null ? -1 : currentDifficulties.indexOf(saved);
    var normalIndex = currentDifficulties.indexOf(Constants.DEFAULT_DIFFICULTY);
    difficultyIndex = savedIndex >= 0 ? savedIndex : (normalIndex >= 0 ? normalIndex : 0);
    currentDifficulty = currentDifficulties[difficultyIndex];
    updateDifficultyText();
    updateScore();
  }

  function changeDifficulty(change:Int):Void
  {
    if (currentDifficulties.length <= 1) return;
    difficultyIndex = (difficultyIndex + change) % currentDifficulties.length;
    if (difficultyIndex < 0) difficultyIndex += currentDifficulties.length;
    currentDifficulty = currentDifficulties[difficultyIndex];
    rememberedDifficulty.set(songs[selected].id, currentDifficulty);
    updateDifficultyText();
    updateScore();
    FunkinSound.playOnce(Paths.sound('scrollMenu', 'shared'), 0.4);
  }

  function updateDifficultyText():Void
  {
    var label = currentDifficulty.toUpperCase();
    difficultyText.text = currentDifficulties.length > 1 ? '<  ' + label + '  >' : label;
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
    var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - DRAW_DISTANCE)));
    var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + DRAW_DISTANCE)));

    for (i in 0...songTexts.length)
    {
      var visible = i >= min && i < max;
      var text = songTexts[i];
      var icon = icons[i];
      text.visible = visible;
      icon.visible = visible;
      if (!visible) continue;

      var offset = i - lerpSelected;
      var x = LIST_X + offset * 20;
      var y = LIST_Y + offset * ITEM_SPACING_Y;
      text.setMenuPosition(x, y);
      icon.setPosition(x + text.textWidth + 12, y - 30);
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
    setPreviewPanelVisible(true);
    scoreBackground.visible = false;
    scoreText.visible = false;
    difficultyText.visible = false;
    bottomText.text = 'SPACE: PAUSE / ESC: EXIT PREVIEW / LEFT-RIGHT: SEEK';
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

    var duration = Math.max(0, music.length);
    var current = Math.max(0, music.time);
    previewTime.text = '< ' + formatTime(current) + ' / ' + formatTime(duration) + ' >';
    var progress:Float = duration > 0 ? Math.max(0, Math.min(1, current / duration)) : 0;
    previewBarFill.setGraphicSize(Math.max(1, Std.int(previewBarBack.width * progress)), 5);
    previewBarFill.updateHitbox();
  }

  function updatePreviewControls(elapsed:Float):Void
  {
    var music = FlxG.sound.music;
    if (music == null || !music.exists) return;

    if (controls.UI_LEFT_P)
    {
      previewSeekHoldTime = 0;
      seekPreview(-1000);
    }
    else if (controls.UI_RIGHT_P)
    {
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
      previewPlaybackText.text = Std.string(FlxMath.roundDecimal(previewPlaybackRate, 2)) + 'x';
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
    menuMusicBeforePreview = null;
  }

  function stopPreview():Void
  {
    stopPreviewAudioOnly(true);
    previewPlaying = false;
    previewPaused = false;
    setPreviewPanelVisible(false);
    scoreBackground.visible = true;
    scoreText.visible = true;
    difficultyText.visible = true;
    bottomText.text = 'PRESS SPACE TO LISTEN  /  PRESS RESET TO RESET SCORE AND ACCURACY';
  }

  function setPreviewPanelVisible(value:Bool):Void
  {
    previewBackground.visible = value;
    previewPlaybackBackground.visible = value;
    previewPlaybackText.visible = value;
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
    LoadingState.loadPlayState({
      targetSong: entry.song,
      targetDifficulty: currentDifficulty,
      targetVariation: targetDifficulty.variation ?? VARIATION,
      targetInstrumental: instrumental,
      practiceMode: false,
      minimalMode: false,
      botPlayMode: false
    }, true);
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
    if (background != null)
    {
      background.setGraphicSize(width, 0);
      if (background.height < height) background.setGraphicSize(0, height);
      background.updateHitbox();
      background.screenCenter();
    }
    bottomBackground?.makeGraphic(width, 26, FlxColor.BLACK);
    bottomBackground?.setPosition(0, height - 26);
    if (bottomText != null) bottomText.fieldWidth = width;
    bottomText?.setPosition(0, height - 22);
    previewBackground?.makeGraphic(Std.int(width * 0.4), 100, FlxColor.BLACK);
    previewBackground?.setPosition(width * 0.6, 0);
    previewPlaybackBackground?.makeGraphic(Std.int(width * 0.15), 100, FlxColor.BLACK);
    previewPlaybackBackground?.setPosition(width * 0.55, 0);
    if (previewPlaybackText != null) previewPlaybackText.fieldWidth = width * 0.15;
    previewPlaybackText?.setPosition(width * 0.55, 20);
    if (previewTitle != null) previewTitle.fieldWidth = width * 0.28;
    previewTitle?.setPosition(width * 0.7, 5);
    if (previewTime != null) previewTime.fieldWidth = width * 0.28;
    previewTime?.setPosition(width * 0.7, 65);
    previewBarBack?.makeGraphic(Std.int(width * 0.28), 5, FlxColor.BLACK);
    previewBarBack?.setPosition(width * 0.7, 98);
    previewBarFill?.makeGraphic(Std.int(width * 0.28), 5, FlxColor.WHITE);
    previewBarFill?.setPosition(width * 0.7, 98);
    bottomText?.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.CENTER);
    positionHighscore();
  }

  override public function destroy():Void
  {
    colorTween?.cancel();
    if (previewPlaying) stopPreviewAudioOnly(false);
    super.destroy();
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
