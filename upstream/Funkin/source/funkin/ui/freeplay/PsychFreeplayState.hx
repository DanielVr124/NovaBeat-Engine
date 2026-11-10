package funkin.ui.freeplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.text.FlxTextAlign;
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
  static inline final VARIATION:String = Constants.DEFAULT_VARIATION;
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
  var menuMusicBeforePreview:Null<FlxSound> = null;
  var previewPaused:Bool = false;
  var previewVocals:Array<FunkinSound> = [];
  var previewBackground:FlxSprite;
  var previewTitle:FlxText;
  var previewTime:FlxText;
  var previewBarBack:FlxSprite;
  var previewBarFill:FlxSprite;
  var resetPrompt:Bool = false;
  var resetPromptText:FlxText;

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

    buildSongList();
    if (songs.length == 0)
    {
      FlxG.log.warn('[Psych Freeplay] The active Psych experience has no imported songs.');
      close();
      return;
    }

    background = new FlxSprite().loadGraphic(Paths.image('menuDesat', 'shared'));
    background.setGraphicSize(FlxG.width, FlxG.height);
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
    scoreBackground = new FlxSprite(FlxG.width * 0.55, 0).makeGraphic(Std.int(FlxG.width * 0.45), 66, FlxColor.BLACK);
    scoreBackground.alpha = 0.6;
    scoreBackground.scrollFactor.set();
    add(scoreBackground);

    scoreText = new FlxText(0, 5, FlxG.width - 12, '', 32);
    scoreText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    scoreText.scrollFactor.set();
    add(scoreText);

    difficultyText = new FlxText(0, 40, FlxG.width - 12, '', 24);
    difficultyText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.RIGHT);
    difficultyText.scrollFactor.set();
    add(difficultyText);
  }

  function createBottomHelp():Void
  {
    bottomBackground = new FlxSprite(0, FlxG.height - 28).makeGraphic(FlxG.width, 28, FlxColor.BLACK);
    bottomBackground.alpha = 0.6;
    bottomBackground.scrollFactor.set();
    add(bottomBackground);

    var help = 'PRESS SPACE TO LISTEN  /  PRESS RESET TO RESET SCORE AND ACCURACY';
    bottomText = new FlxText(0, bottomBackground.y + 5, FlxG.width, help, 16);
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

    previewTitle = new FlxText(FlxG.width * 0.6, 12, FlxG.width * 0.38, '', 24);
    previewTitle.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.RIGHT);
    previewTitle.scrollFactor.set();
    add(previewTitle);

    previewTime = new FlxText(FlxG.width * 0.6, 48, FlxG.width * 0.38, '00:00 / 00:00', 20);
    previewTime.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.RIGHT);
    previewTime.scrollFactor.set();
    add(previewTime);

    previewBarBack = new FlxSprite(FlxG.width * 0.6, 78).makeGraphic(Std.int(FlxG.width * 0.38), 8, FlxColor.BLACK);
    previewBarBack.scrollFactor.set();
    add(previewBarBack);

    previewBarFill = new FlxSprite(previewBarBack.x, previewBarBack.y).makeGraphic(1, 8, FlxColor.WHITE);
    previewBarFill.scrollFactor.set();
    add(previewBarFill);

    setPreviewPanelVisible(false);
  }

  function createResetPrompt():Void
  {
    resetPromptText = new FlxText(0, FlxG.height * 0.42, FlxG.width, 'RESET THIS SONG\'S SCORE AND ACCURACY?\nENTER: CONFIRM     ESC: CANCEL', 24);
    resetPromptText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.CENTER);
    resetPromptText.scrollFactor.set();
    resetPromptText.visible = false;
    add(resetPromptText);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (resetPrompt)
    {
      if (controls.ACCEPT)
      {
        var entry = songs[selected];
        Save.instance.removeSongScore(entry.id, currentDifficulty, VARIATION);
        resetPrompt = false;
        resetPromptText.visible = false;
        updateScore();
        FunkinSound.playOnce(Paths.sound('confirmMenu', 'shared'));
      }
      else if (controls.BACK)
      {
        resetPrompt = false;
        resetPromptText.visible = false;
        FunkinSound.playOnce(Paths.sound('cancelMenu', 'shared'));
      }
      return;
    }

    if (previewPlaying)
    {
      updatePreview(elapsed);
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
        resetPrompt = true;
        resetPromptText.visible = true;
      }
      else if (controls.BACK)
        goBack();
    }

    lerpedScore = FlxMath.lerp(intendedScore, lerpedScore, Math.exp(-elapsed * 24));
    lerpedRating = FlxMath.lerp(intendedRating, lerpedRating, Math.exp(-elapsed * 12));
    if (Math.abs(lerpedScore - intendedScore) <= 10) lerpedScore = intendedScore;
    if (Math.abs(lerpedRating - intendedRating) <= 0.0001) lerpedRating = intendedRating;

    updateScoreText();
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
  }

  function updateSongRows(elapsed:Float):Void
  {
    lerpSelected = FlxMath.lerp(selected, lerpSelected, Math.exp(-elapsed * 9.6));
    var min:Int = Math.floor(Math.max(0, lerpSelected - DRAW_DISTANCE));
    var max:Int = Math.ceil(Math.min(songs.length, lerpSelected + DRAW_DISTANCE + 1));

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
    menuMusicBeforePreview = FlxG.sound.music;
    menuMusicBeforePreview?.pause();

    entry.song.playInst(0.8, '', false);
    if (FlxG.sound.music == null || !FlxG.sound.music.exists)
    {
      FlxG.log.warn('[Psych Freeplay] Could not load preview instrumental for ' + entry.id);
      stopPreviewAudioOnly(true);
      return;
    }

    previewVocals = [];
    for (voicePath in entry.song.buildVoiceList())
    {
      var voice = FunkinSound.load(voicePath, 0.8, true, false, true, false, null, null, false, #if web true #else false #end);
      if (voice != null) previewVocals.push(voice);
    }
    for (voice in previewVocals) voice.time = FlxG.sound.music.time;

    previewPlaying = true;
    previewPaused = false;
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
    previewTime.text = formatTime(current) + ' / ' + formatTime(duration);
    previewBarFill.scale.x = duration > 0 ? Math.max(0, Math.min(1, current / duration)) : 0;
    previewBarFill.updateHitbox();
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
    background?.setGraphicSize(width, height);
    background?.updateHitbox();
    background?.screenCenter();
    bottomBackground?.makeGraphic(width, 28, FlxColor.BLACK);
    bottomBackground?.setPosition(0, height - 28);
    bottomText?.setSize(width, 16);
    bottomText?.setPosition(0, height - 23);
    scoreText?.setSize(width - 12, 32);
    difficultyText?.setSize(width - 12, 24);
    previewBackground?.makeGraphic(Std.int(width * 0.4), 100, FlxColor.BLACK);
    previewBackground?.setPosition(width * 0.6, 0);
    previewTitle?.setSize(width * 0.38, 24);
    previewTitle?.setPosition(width * 0.6, 12);
    previewTime?.setSize(width * 0.38, 20);
    previewTime?.setPosition(width * 0.6, 48);
    previewBarBack?.setPosition(width * 0.6, 78);
    previewBarFill?.setPosition(width * 0.6, 78);
    bottomText?.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.CENTER);
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
