package funkin.play.cutscene;

import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSignal;
import flixel.util.FlxTimer;
import funkin.play.PlayState;
#if sys
import sys.FileSystem;
#end
#if html5
import funkin.graphics.video.FlxVideo;
#end
#if hxvlc
import funkin.graphics.video.FunkinVideoSprite;
#end

/**
 * Assumes you are in the PlayState.
 */
class VideoCutscene
{
  #if hxvlc
  @:noCompletion
  static final DEFAULT_LANGUAGE:String = 'English';
  #end
  static var blackScreen:FlxSprite;
  static var cutsceneType:CutsceneType;
  #if html5
  static var vid:FlxVideo;
  #end
  #if hxvlc
  static var vid:FunkinVideoSprite;
  static var preloadedVid:Null<FunkinVideoSprite> = null;
  static var preloadedPath:String = "";
  #end

  /**
   * Called when the video is started.
   */
  public static final onVideoStarted:FlxSignal = new FlxSignal();

  /**
   * Called if the video is paused.
   */
  public static final onVideoPaused:FlxSignal = new FlxSignal();

  /**
   * Called if the video is resumed.
   */
  public static final onVideoResumed:FlxSignal = new FlxSignal();

  /**
   * Called if the video is restarted. onVideoStarted is not called.
   */
  public static final onVideoRestarted:FlxSignal = new FlxSignal();

  /**
   * Called when the video is ended or skipped.
   */
  public static final onVideoEnded:FlxSignal = new FlxSignal();

  /**
   * Prepare a native video decoder before a Psych script requests playback.
   * The decoder remains paused; playVideoNative() reuses it when the matching
   * startVideo() call arrives.
   */
  public static function preload(filePath:String):Bool
  {
    #if hxvlc
    if (filePath == null || StringTools.trim(filePath).length == 0) return false;
    if (preloadedVid != null && preloadedPath == filePath) return true;

    clearPreloadedVideo();
    var candidate:FunkinVideoSprite = createNativeVideo();
    candidate.active = false;
    preloadedVid = candidate;
    preloadedPath = filePath;
    candidate.bitmap.onEncounteredError.add(function(message:String):Void
    {
      if (preloadedVid == candidate)
      {
        trace('[Video Cutscene] Preloaded video failed: ' + message);
        preloadedVid = null;
        preloadedPath = "";
        candidate.destroy();
      }
    });

    if (candidate.load(filePath, getNativeVideoOptions()) && preloadedVid == candidate)
    {
      trace('[Video Cutscene] Preloaded video: ' + filePath);
      return true;
    }

    if (preloadedVid == candidate)
    {
      preloadedVid = null;
      preloadedPath = "";
      candidate.destroy();
    }
    trace('[Video Cutscene] Could not preload video: ' + filePath);
    return false;
    #else
    return false;
    #end
  }

  #if hxvlc
  static function createNativeVideo():FunkinVideoSprite
  {
    var video:FunkinVideoSprite = new FunkinVideoSprite(0, 0);
    video.bitmap.onFormatSetup.add(function():Void
    {
      if (video.bitmap != null && video.bitmap.bitmapData != null)
      {
        final scale:Float = Math.min(FlxG.width / video.bitmap.bitmapData.width, FlxG.height / video.bitmap.bitmapData.height);
        video.setGraphicSize(video.bitmap.bitmapData.width * scale, video.bitmap.bitmapData.height * scale);
        video.updateHitbox();
        video.screenCenter();
      }
    });
    return video;
  }

  static function getNativeVideoOptions():Array<String>
  {
    final fileOptions:Array<String> = [];
    #if FEATURE_VIDEO_SUBTITLES
    if (Preferences.subtitles)
      fileOptions.push(':sub-language=$DEFAULT_LANGUAGE');
    else
      fileOptions.push(':sub-language=none');
    fileOptions.push(':audio-language=$DEFAULT_LANGUAGE');
    #end
    return fileOptions;
  }

  static function clearPreloadedVideo():Void
  {
    if (preloadedVid != null)
    {
      preloadedVid.stop();
      preloadedVid.destroy();
      preloadedVid = null;
      preloadedPath = "";
    }
  }
  #end

  /** Release any prepared decoder when a song is abandoned or replaced. */
  public static function clearPreload():Void
  {
    #if hxvlc
    clearPreloadedVideo();
    #end
  }

  /**
   * Play a video cutscene.
   * TODO: Currently this is hardcoded to start the countdown after the video is done.
   * @param path The path to the video file. Use Paths.file(path) to get the correct path.
   * @param cutseneType The type of cutscene to play, determines what the game does after. Defaults to `CutsceneType.STARTING`.
   */
  public static function play(filePath:String, ?cutsceneType:CutsceneType = STARTING):Void
  {
    if (PlayState.instance == null) return;

    #if FEATURE_VIDEO_PLAYBACK
    var fileExists:Bool = openfl.Assets.exists(filePath);
    #if sys
    // Psych mods keep cutscenes in their own videos/ folder. Those files are
    // ordinary mod files, not necessarily mounted OpenFL assets.
    if (!fileExists) fileExists = FileSystem.exists(filePath);
    #end
    if (!fileExists)
    {
      // Display a popup. Psych scripts commonly cancel onStartCountdown()
      // while waiting for startVideo(). If the file is missing, resume that
      // flow on the next timer tick so the song is not left before countdown.
      funkin.util.WindowUtil.showError('Error playing video', 'Video file does not exist: ${filePath}');
      trace('Video file does not exist: ${filePath}');

      var failedCutsceneType:CutsceneType = cutsceneType;
      new FlxTimer().start(0.001, function(timer:FlxTimer):Void
      {
        if (PlayState.instance != null) onCutsceneFinish(failedCutsceneType);
      });
      return;
    }
    #end

    // A starting/ending cutscene takes over the screen. A mid-song video is
    // meant to overlay a song that keeps running, and this flag disables note
    // processing, so enabling it there would freeze the chart while the music
    // advanced underneath and leave the song desynced once the video ended.
    if (cutsceneType != CutsceneType.MIDSONG)
    {
      PlayState.instance.isInCutscene = true;
      PlayState.instance.camHUD.visible = false;
    }

    // Display a black screen to hide the game while the video is playing.
    blackScreen = new FlxSprite(-200, -200).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
    blackScreen.scrollFactor.set(0, 0);
    blackScreen.cameras = [PlayState.instance.camCutscene];
    PlayState.instance.add(blackScreen);

    VideoCutscene.cutsceneType = cutsceneType;

    #if mobile
    if (cutsceneType == ENDING)
    {
      PlayState.instance.togglePauseButton();
    }
    #end

    #if NO_FEATURE_VIDEO_PLAYBACK
    trace(" WARNING ".bold().bg_yellow() + " Video playback is not enabled. Calling video end callback instead.");
    finishVideo();
    #else
    #if html5
    playVideoHTML5(Paths.stripLibrary(filePath));
    #elseif hxvlc
    playVideoNative(filePath);
    #else
    throw "No video support for this platform!";
    #end
    #end
  }

  public static function isPlaying():Bool
  {
    #if (html5 || hxvlc)
    return vid != null;
    #else
    return false;
    #end
  }

  #if html5
  static function playVideoHTML5(filePath:String):Void
  {
    // Video displays OVER the FlxState.
    vid = new FlxVideo(filePath);

    if (vid != null)
    {
      vid.zIndex = 0;

      vid.finishCallback = finishVideo.bind(0.5);

      vid.cameras = [PlayState.instance.camCutscene];

      PlayState.instance.add(vid);

      PlayState.instance.refresh();

      onVideoStarted.dispatch();
    }
    else
    {
      trace('ALERT: Video is null! Could not play cutscene!');
    }
  }
  #end

  #if hxvlc
  static function playVideoNative(filePath:String):Void
  {
    // Reuse the decoder prepared during song loading whenever the script asks
    // for this exact file. Otherwise retain the normal on-demand fallback.
    final usingPreloaded:Bool = preloadedVid != null && preloadedPath == filePath;
    if (usingPreloaded)
    {
      vid = cast preloadedVid;
      preloadedVid = null;
      preloadedPath = "";
    }
    else
    {
      clearPreloadedVideo();
      vid = createNativeVideo();
    }

    if (vid != null)
    {
      final activeVideo:FunkinVideoSprite = vid;
      activeVideo.zIndex = 0;
      activeVideo.active = false;
      activeVideo.bitmap.onEncounteredError.add(function(message:String):Void
      {
        trace('[Video Cutscene] Playback error: ' + message);
        if (vid == activeVideo) finishVideo(0.5);
      });
      activeVideo.bitmap.onEndReached.add(function():Void
      {
        if (vid == activeVideo) finishVideo(0.5);
      });

      activeVideo.cameras = [PlayState.instance.camCutscene];
      PlayState.instance.add(activeVideo);
      PlayState.instance.refresh();

      if ((usingPreloaded || activeVideo.load(filePath, getNativeVideoOptions())) && activeVideo.play())
      {
        onVideoStarted.dispatch();
      }
      else if (vid != null)
      {
        trace('ALERT: Could not load or play video cutscene: ' + filePath);
        finishVideo(0.5);
      }
    }
    else
    {
      trace('ALERT: Video is null! Could not play cutscene!');
      finishVideo(0.5);
    }
  }
  #end

  public static function restartVideo():Void
  {
    #if html5
    if (vid != null)
    {
      vid.restartVideo();
      vid.resumeVideo();
      onVideoRestarted.dispatch();
    }
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.bitmap.time = 0;
      vid.resume();
      onVideoRestarted.dispatch();
    }
    #end
  }

  public static function pauseVideo():Void
  {
    #if html5
    if (vid != null)
    {
      vid.pauseVideo();
      onVideoPaused.dispatch();
    }
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.pause();
      onVideoPaused.dispatch();
    }
    #end
  }

  public static function hideVideo():Void
  {
    #if html5
    if (vid != null)
    {
      vid.visible = false;
      blackScreen.visible = false;
    }
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.visible = false;
      blackScreen.visible = false;
    }
    #end
  }

  public static function showVideo():Void
  {
    #if html5
    if (vid != null)
    {
      vid.visible = true;
      blackScreen.visible = false;
    }
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.visible = true;
      blackScreen.visible = false;
    }
    #end
  }

  public static function resumeVideo():Void
  {
    #if html5
    if (vid != null)
    {
      vid.resumeVideo();
      onVideoResumed.dispatch();
    }
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.resume();
      onVideoResumed.dispatch();
    }
    #end
  }

  /**
   * Finish the active video cutscene. Done when the video is finished or when the player skips the cutscene.
   * @param transitionTime The duration of the transition to the next state. Defaults to 0.5 seconds (this time is always used when cancelling the video).
   * @param finishCutscene The callback to call when the transition is finished.
   */
  public static function finishVideo(?transitionTime:Float = 0.5):Void
  {
    trace('ALERT: Finish video cutscene called!');

    var cutsceneType:CutsceneType = VideoCutscene.cutsceneType;

    #if html5
    if (vid != null)
    {
      PlayState.instance.remove(vid);
    }
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.stop();
      PlayState.instance.remove(vid);
    }
    #end

    #if (html5 || hxvlc)
    if (vid != null)
    {
      vid.destroy();
      vid = null;
    }
    #end

    PlayState.instance.camHUD.visible = true;
    // Only startCountdown() used to clear this flag, so a mid-song video left
    // the state permanently "in cutscene": note processing stayed disabled and
    // the song never advanced again. Every cutscene type has to end the state.
    PlayState.instance.isInCutscene = false;

    FlxTween.tween(blackScreen, {alpha: 0}, transitionTime, {
      ease: FlxEase.quadInOut,
      onComplete: function(twn:FlxTween)
      {
        PlayState.instance.remove(blackScreen);
        blackScreen = null;
      }
    });
    FlxTween.tween(FlxG.camera, {zoom: PlayState.instance.stageZoom}, transitionTime, {
      ease: FlxEase.quadInOut,
      onComplete: function(twn:FlxTween)
      {
        onVideoEnded.dispatch();
        onCutsceneFinish(cutsceneType);
      }
    });
  }

  /**
   * The default callback used when a cutscene is finished.
   * You can specify your own callback when calling `VideoCutscene#play()`.
   */
  static function onCutsceneFinish(cutsceneType:CutsceneType):Void
  {
    switch (cutsceneType)
    {
      case CutsceneType.STARTING:
        PlayState.instance.startCountdown();
      case CutsceneType.ENDING:
        PlayState.instance.endSong(true); // true = right goddamn now
      case CutsceneType.MIDSONG:
        // Do nothing.
        // throw "Not implemented!";
    }
  }

  /**
   * Destroy the active cutscene, if any. Separate from finishVideo() so that it doesn't trigger onCutsceneFinish().
   */
  public static function destroyVideo()
  {
    clearPreload();
    #if html5
    if (vid != null) PlayState.instance.remove(vid);
    #end

    #if hxvlc
    if (vid != null)
    {
      vid.stop();
      PlayState.instance.remove(vid);
    }
    #end

    #if (html5 || hxvlc)
    if (vid != null)
    {
      vid?.destroy();
      vid = null;
    }
    #end

    if (blackScreen != null)
    {
      PlayState.instance.remove(blackScreen);
      blackScreen = null;
    }
  }
}

enum CutsceneType
{
  STARTING; // The default cutscene type. Starts the countdown after the video is done.
  MIDSONG; // Does nothing.
  ENDING; // Ends the song after the video is done.
}
