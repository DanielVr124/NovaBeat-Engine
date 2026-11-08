package funkin.modding;

import funkin.Assets;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.character.CharacterData.CharacterData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongRegistry;
import funkin.data.song.importer.FNFLegacyData;
import funkin.data.song.importer.FNFLegacyImporter;
import funkin.play.song.Song;
import haxe.Json;
import openfl.utils.AssetType;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Runtime bridge for the currently supported classic Psych Engine mod tier.
 *
 * It converts legacy Psych chart JSON into native V-Slice song data, resolves
 * Psych's conventional songs/<song>/ audio assets, and exposes supported
 * global and song-local Lua/HScript source files to the script runtime.
 * Referenced custom event and note-type scripts are supported through the
 * bounded callback bridge. Custom stages, characters, and substates remain
 * gated until their asset and lifecycle adapters are available.
 */
@:nullSafety(Off)
class PsychModRuntime
{
  static final audioFolders:Map<String, String> = [];
  static final songDataFolders:Map<String, String> = [];
  static var cachedSoundAssetKeys:Null<Array<String>> = null;

  public static function inspectPackage(modPath:String):PsychPackageAssessment
  {
    #if sys
    if (!FileSystem.exists(modPath) || !FileSystem.isDirectory(modPath))
      return unavailable("The Psych mod folder could not be read.");

    var sources:Array<PsychSongSource> = scanSongSources(modPath);
    var globalScriptCount:Int = countPsychScripts(modPath);
    var unsupportedScriptCount:Int = countUnsupportedPsychScripts(modPath);
    var playableCount:Int = 0;

    // The legacy V-Slice importer ignores several Psych-only chart fields.
    // Inspect raw JSON before advertising the package as launchable so we do
    // not silently drop its stage, cast, events, or custom note behavior.
    for (source in sources)
    {
      // A chart without its matching instrumental cannot be launched and
      // should not prevent otherwise complete songs in this package loading.
      if (source.instrumentFile == null) continue;

      for (chartPath in source.chartFiles)
      {
        var chartProblem:Null<String> = inspectUnsupportedChartFeatures(chartPath, modPath);
        if (chartProblem != null)
        {
          return unavailable("This Psych package contains a chart feature NovaBeat does not support yet: " + chartProblem);
        }
      }

      var externalEventsProblem:Null<String> = inspectUnsupportedEventFile(
        Path.join([source.dataPath, "events.json"]),
        modPath
      );
      if (externalEventsProblem != null)
        return unavailable("This Psych package contains event data NovaBeat cannot safely load yet: " + externalEventsProblem);
    }
    var songScriptCount:Int = 0;

    for (source in sources)
    {
      if (source.instrumentFile == null || source.chartFiles.length == 0) continue;
      if (hasSongScripts(source)) songScriptCount++;
      else playableCount++;
    }

    if (unsupportedScriptCount > 0)
    {
      return {
        launchable: false,
        supportedSongCount: 0,
        explanation: "Psych charts were found, but this package also contains custom event, note-type, stage, character, or substate scripts. Those systems are not implemented yet, so this package is kept unavailable rather than launched with missing behavior."
      };
    }

    var supportedSongs:Int = playableCount + songScriptCount;
    if (supportedSongs == 0)
    {
      return {
        launchable: false,
        supportedSongCount: 0,
        explanation: "Psych Engine detected. This compatibility tier needs a classic data/<song> chart and a matching Inst.ogg, Inst.mp3, or Inst.wav file under songs/<song>/ or assets/songs/<song>/. No complete song package was found."
      };
    }

    var hasBasicScripts:Bool = globalScriptCount > 0 || songScriptCount > 0;
    return {
      launchable: true,
      supportedSongCount: supportedSongs,
      explanation: hasBasicScripts
        ? "Experimental Psych scripting compatibility: " + Std.string(supportedSongs) + " classic chart song(s) can launch with global scripts and song-local Lua/HScript callbacks, basic property access, and basic Lua sprite helpers. Custom events, note types, stages, characters, custom substates, and many advanced Psych APIs are not supported yet. Native builds only."
        : "Limited native Psych chart compatibility: " + Std.string(supportedSongs) + " classic chart song(s) can launch with NovaBeat's built-in characters and default stage. Lua/HScript song and global script loading is available for this basic compatibility tier. Custom events, note types, stages, characters, and custom substates remain unsupported."
    };
    #else
    return unavailable("Psych mod launching currently requires native mod-folder access.");
    #end
  }

  public static function collectSongIds(modDirs:Array<String>):Array<String>
  {
    var result:Array<String> = [];
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;
      if (!inspectPackage(modPath).launchable) continue;

      for (source in scanSongSources(modPath))
      {
        if (source.instrumentFile == null || source.chartFiles.length == 0) continue;
        var songId:String = buildSongId(directory, source.songFolder);
        if (!result.contains(songId)) result.push(songId);
      }
    }
    #end
    return result;
  }

  /**
   * Load the currently selected Psych packages into SongRegistry.
   * Called after Polymod has mounted the active packages and before Freeplay
   * reads the registry. Only packages that pass inspectPackage are imported.
   */
  public static function loadSongs(modDirs:Array<String>):Array<String>
  {
    var loaded:Array<String> = [];
    #if sys
    audioFolders.clear();
    songDataFolders.clear();
    cachedSoundAssetKeys = null;

    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;

      var assessment:PsychPackageAssessment = inspectPackage(modPath);
      if (!assessment.launchable) continue;

      for (source in scanSongSources(modPath))
      {
        if (source.instrumentFile == null || source.chartFiles.length == 0) continue;

        var songId:String = buildSongId(directory, source.songFolder);
        try
        {
          var song:Null<Song> = buildNativeSong(songId, source);
          if (song == null) continue;

          audioFolders.set(songId, source.songFolder);
          songDataFolders.set(songId, source.dataPath);
          SongRegistry.instance.registerCompatibilitySong(song);
          loaded.push(songId);
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not import ${directory}/${source.songFolder}: ' + Std.string(error));
        }
      }
    }
    #end
    return loaded;
  }

  /** True only for a song imported by this Psych compatibility loader. */
  public static function isImportedSong(songId:String):Bool
  {
    return songId != null && audioFolders.exists(songId);
  }

  public static function getInstrumentalAssetPath(songId:String, suffix:String = ""):Null<String>
  {
    var folder:Null<String> = audioFolders.get(songId);
    if (folder == null) return null;

    var normalizedSuffix:String = suffix == null ? "" : suffix;
    if (normalizedSuffix != "" && !StringTools.startsWith(normalizedSuffix, "-"))
      normalizedSuffix = "-" + normalizedSuffix;

    var result:Null<String> = findSongAsset(folder, "Inst" + normalizedSuffix);
    if (result == null && normalizedSuffix != "")
      result = findSongAsset(folder, "Inst");
    return result;
  }

  /**
   * Resolve a role-specific voice stem. Classic Psych Voices.ogg is returned
   * only for the player side so the native legacy single-stem path is used once.
   */
  public static function getVoiceAssetPath(songId:String, characterId:String, role:String, suffix:String = ""):Null<String>
  {
    var folder:Null<String> = audioFolders.get(songId);
    if (folder == null) return null;

    var normalizedSuffix:String = suffix == null ? "" : suffix;
    if (normalizedSuffix != "" && !StringTools.startsWith(normalizedSuffix, "-"))
      normalizedSuffix = "-" + normalizedSuffix;

    var roleName:String = role == "opponent" ? "Opponent" : "Player";
    var candidates:Array<String> = [
      "Voices-" + characterId + normalizedSuffix,
      "Voices-" + roleName + normalizedSuffix,
      "Voices-" + characterId,
      "Voices-" + roleName
    ];

    for (candidate in candidates)
    {
      var result:Null<String> = findSongAsset(folder, candidate);
      if (result != null) return result;
    }

    if (role != "opponent")
      return findSongAsset(folder, "Voices");

    return null;
  }

  public static function isPsychDirectory(modPath:String):Bool
  {
    return EngineBridge.hasPsychMarkersForRuntime(modPath);
  }

  /**
   * Read global scripts, referenced custom event/note-type scripts, and
   * matching song-local scripts in Psych's expected load order.
   */
  public static function getScriptSources(modDirs:Array<String>, songId:String):Array<PsychScriptSource>
  {
    var globalSources:Array<PsychScriptSource> = [];
    var stageSources:Array<PsychScriptSource> = [];
    var characterSources:Array<PsychScriptSource> = [];
    var customEventSources:Array<PsychScriptSource> = [];
    var customNoteSources:Array<PsychScriptSource> = [];
    var songSources:Array<PsychScriptSource> = [];
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;

      var scriptsPath:String = Path.join([modPath, "scripts"]);
      globalSources = globalSources.concat(readScriptSources(scriptsPath, 5));

      var dataRoot:String = Path.join([modPath, "data"]);
      if (!FileSystem.exists(dataRoot) || !FileSystem.isDirectory(dataRoot)) continue;
      for (songFolder in FileSystem.readDirectory(dataRoot))
      {
        var dataPath:String = Path.join([dataRoot, songFolder]);
        if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) continue;
        if (buildSongId(directory, songFolder) != songId) continue;

        var eventNames:Array<String> = [];
        var noteTypeNames:Array<String> = [];
        var stageNames:Array<String> = [];
        var characterNames:Array<String> = [];
        for (fileName in FileSystem.readDirectory(dataPath))
        {
          var lower:String = fileName.toLowerCase();
          if (!StringTools.endsWith(lower, ".json") || lower == "events.json") continue;
          try
          {
            var chartRoot:Dynamic = Json.parse(File.getContent(Path.join([dataPath, fileName])));
            var chartSong:Dynamic = Reflect.field(chartRoot, "song");
            if (chartSong == null) continue;
            for (event in extractPsychEvents(Reflect.field(chartSong, "events")))
              if (!eventNames.contains(event.name.toLowerCase())) eventNames.push(event.name.toLowerCase());
            collectPsychNoteTypes(Reflect.field(chartSong, "notes"), noteTypeNames);

            var rawStage:Dynamic = Reflect.field(chartSong, "stage");
            if (rawStage == null || StringTools.trim(Std.string(rawStage)).length == 0)
              rawStage = Reflect.field(chartSong, "stageDefault");
            if (rawStage != null)
            {
              var stageName:String = StringTools.trim(Std.string(rawStage)).toLowerCase();
              if (stageName.length > 0 && !stageNames.contains(stageName)) stageNames.push(stageName);
            }

            for (field in ["player1", "player2", "player3", "gfVersion"])
            {
              var rawCharacter:Dynamic = Reflect.field(chartSong, field);
              if (rawCharacter == null) continue;
              var characterName:String = StringTools.trim(Std.string(rawCharacter)).toLowerCase();
              if (characterName.length > 0 && !characterNames.contains(characterName))
                characterNames.push(characterName);
            }
          }
          catch (error:Dynamic)
          {
            trace('[Psych Compatibility] Could not scan compatibility scripts in ' + fileName + ': ' + Std.string(error));
          }
        }

        var externalEventsPath:String = Path.join([dataPath, "events.json"]);
        if (FileSystem.exists(externalEventsPath))
        {
          try
          {
            var externalEvents:Dynamic = Json.parse(File.getContent(externalEventsPath));
            for (event in extractPsychEvents(externalEvents))
              if (!eventNames.contains(event.name.toLowerCase())) eventNames.push(event.name.toLowerCase());
          }
          catch (error:Dynamic)
          {
            trace('[Psych Compatibility] Could not scan events.json: ' + Std.string(error));
          }
        }

        stageSources = stageSources.concat(
          readNamedScriptSources(Path.join([modPath, "stages"]), stageNames)
        );
        characterSources = characterSources.concat(
          readNamedScriptSources(Path.join([modPath, "characters"]), characterNames)
        );
        customEventSources = customEventSources.concat(
          readNamedScriptSources(Path.join([modPath, "custom_events"]), eventNames)
        );
        customNoteSources = customNoteSources.concat(
          readNamedScriptSources(Path.join([modPath, "custom_notetypes"]), noteTypeNames)
        );
        songSources = songSources.concat(readScriptSources(dataPath, 3));
      }
    }
    #end
    return globalSources.concat(stageSources).concat(characterSources)
      .concat(customEventSources).concat(customNoteSources).concat(songSources);
  }

  public static function getCustomSubstateScriptSources(modDirs:Array<String>, name:String):Array<PsychScriptSource>
  {
    var result:Array<PsychScriptSource> = [];
    if (name == null || StringTools.trim(name).length == 0) return result;
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;
      result = result.concat(readNamedScriptSources(Path.join([modPath, "custom_substates"]), [name]));
    }
    #end
    return result;
  }

  /**
   * Resolve one additional script requested at runtime by Psych's addLuaScript /
   * addHScript helpers. Only files inside an enabled Psych package are eligible;
   * path traversal and absolute paths are rejected.
   */
  public static function getScriptSource(modDirs:Array<String>, requestedPath:String):Null<PsychScriptSource>
  {
    if (requestedPath == null || StringTools.trim(requestedPath).length == 0) return null;
    #if sys
    var relative:String = StringTools.replace(StringTools.trim(requestedPath), "\\", "/");
    while (StringTools.startsWith(relative, "/")) relative = relative.substr(1);
    if (StringTools.startsWith(relative.toLowerCase(), "mods/"))
    {
      var parts:Array<String> = relative.split("/");
      if (parts.length > 2) relative = parts.slice(2).join("/");
    }
    for (part in relative.split("/"))
      if (part == ".." || part == ".") return null;

    var candidates:Array<String> = [];
    if (StringTools.startsWith(relative.toLowerCase(), "scripts/"))
      candidates.push(relative);
    else
      candidates.push(Path.join(["scripts", relative]));

    var root:String = PolymodHandler.getModRoot();
    for (directory in (modDirs == null ? [] : modDirs))
    {
      var modPath:String = Path.normalize(Path.join([root, directory]));
      if (!isPsychDirectory(modPath)) continue;
      for (candidate in candidates)
      {
        var filePath:String = Path.normalize(Path.join([modPath, candidate]));
        var prefix:String = modPath;
        if (!StringTools.endsWith(prefix, "/")) prefix += "/";
        if (!StringTools.startsWith(filePath, prefix)) continue;
        if (!FileSystem.exists(filePath) || FileSystem.isDirectory(filePath)) continue;
        var extension:String = Path.extension(filePath).toLowerCase();
        if (extension != "lua" && extension != "hx" && extension != "hscript") continue;
        try
        {
          return {path: filePath, source: File.getContent(filePath)};
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not read requested script ' + filePath + ': ' + Std.string(error));
          return null;
        }
      }
    }
    #end
    return null;
  }

  public static function prepareSongCharacters(modDirs:Array<String>, songId:String,
      characters:Null<SongCharacterData>):Void
  {
    if (characters == null) return;
    var characterIds:Array<String> = [characters.player, characters.girlfriend, characters.opponent];
    for (characterId in characterIds)
    {
      if (characterId == null || characterId.length == 0
        || CharacterDataParser.fetchCharacterData(characterId) != null) continue;

      var registered:Bool = false;
      #if sys
      var root:String = PolymodHandler.getModRoot();
      for (directory in modDirs)
      {
        var modPath:String = Path.join([root, directory]);
        var jsonPath:Null<String> = findPsychCharacterDataFile(modPath, characterId);
        if (jsonPath == null) continue;
        try
        {
          var raw:Dynamic = Json.parse(File.getContent(jsonPath));
          var converted:Null<CharacterData> = convertPsychCharacterData(characterId, raw);
          if (converted != null && CharacterDataParser.registerModCharacterData(characterId, converted))
          {
            trace('[Psych Compatibility] Registered custom Psych character: ' + characterId);
            registered = true;
            break;
          }
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not convert custom character ' + characterId + ': ' + Std.string(error));
        }
      }
      #end
      if (!registered)
        trace('[Psych Compatibility] Custom character data was not registered: ' + characterId);
    }
  }

  #if sys
  static function findPsychCharacterDataFile(modPath:String, characterId:String):Null<String>
  {
    var candidates:Array<String> = [
      Path.join([modPath, "characters", characterId + ".json"]),
      Path.join([modPath, "data", "characters", characterId + ".json"])
    ];
    for (candidate in candidates)
      if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate)) return candidate;
    for (root in [Path.join([modPath, "characters"]), Path.join([modPath, "data", "characters"])])
    {
      if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) continue;
      for (entry in FileSystem.readDirectory(root))
        if (!FileSystem.isDirectory(Path.join([root, entry]))
          && entry.toLowerCase() == (characterId + ".json").toLowerCase())
          return Path.join([root, entry]);
    }
    return null;
  }

  static function hasPsychCharacterDataFile(modPath:String, characterId:String):Bool
  {
    var jsonPath:Null<String> = findPsychCharacterDataFile(modPath, characterId);
    if (jsonPath == null) return false;

    // Only accept the common Psych Sparrow JSON shape that the native
    // character converter below can faithfully map into NovaBeat.
    try
    {
      var raw:Dynamic = Json.parse(File.getContent(jsonPath));
      var image:Dynamic = Reflect.field(raw, "image");
      var rawAnimations:Dynamic = Reflect.field(raw, "animations");
      if (image == null || !Std.isOfType(image, String) || StringTools.trim(Std.string(image)).length == 0)
        return false;
      if (!Std.isOfType(rawAnimations, Array)) return false;

      var validAnimations:Int = 0;
      for (rawAnimation in (cast rawAnimations:Array<Dynamic>))
      {
        if (rawAnimation == null) continue;
        var animationName:Dynamic = Reflect.field(rawAnimation, "anim");
        if (animationName != null && StringTools.trim(Std.string(animationName)).length > 0)
          validAnimations++;
      }
      return validAnimations > 0;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Character JSON did not match the supported Sparrow schema for ' + characterId + ': ' + Std.string(error));
      return false;
    }
  }

  static function convertPsychCharacterData(characterId:String, raw:Dynamic):Null<CharacterData>
  {
    if (raw == null) return null;
    var image:Dynamic = Reflect.field(raw, "image");
    var rawAnimations:Dynamic = Reflect.field(raw, "animations");
    if (image == null || !Std.isOfType(rawAnimations, Array)) return null;

    var animations:Array<Dynamic> = [];
    var startingAnimation:String = "idle";
    for (rawAnimation in (cast rawAnimations:Array<Dynamic>))
    {
      if (rawAnimation == null) continue;
      var animationName:Dynamic = Reflect.field(rawAnimation, "anim");
      var animationPrefix:Dynamic = Reflect.field(rawAnimation, "name");
      if (animationName == null) continue;
      if (animationPrefix == null) animationPrefix = animationName;
      if (animations.length == 0) startingAnimation = Std.string(animationName);
      var fpsValue:Dynamic = Reflect.field(rawAnimation, "fps");
      var fps:Float = fpsValue == null ? 24 : Std.parseFloat(Std.string(fpsValue));
      if (Math.isNaN(fps) || fps <= 0) fps = 24;
      var offsetsValue:Dynamic = Reflect.field(rawAnimation, "offsets");
      var animationOffsets:Array<Float> = Std.isOfType(offsetsValue, Array) ? cast offsetsValue : [0, 0];
      animations.push({
        name: Std.string(animationName),
        prefix: Std.string(animationPrefix),
        frameRate: Std.int(fps),
        looped: Reflect.field(rawAnimation, "loop") == true,
        offsets: animationOffsets
      });
      if (Std.string(animationName).toLowerCase() == "idle") startingAnimation = "idle";
    }
    if (animations.length == 0) return null;

    var cameraValue:Dynamic = Reflect.field(raw, "camera_position");
    var cameraOffsets:Array<Float> = Std.isOfType(cameraValue, Array) ? cast cameraValue : [0, 0];
    var positionValue:Dynamic = Reflect.field(raw, "position");
    var position:Array<Float> = Std.isOfType(positionValue, Array) ? cast positionValue : [0, 0];
    var healthIconId:Dynamic = Reflect.field(raw, "healthicon");
    if (healthIconId == null || Std.string(healthIconId).length == 0) healthIconId = characterId;
    var scaleValue:Dynamic = Reflect.field(raw, "scale");
    var scale:Float = scaleValue == null ? 1 : Std.parseFloat(Std.string(scaleValue));
    if (Math.isNaN(scale) || scale <= 0) scale = 1;
    var singTimeValue:Dynamic = Reflect.field(raw, "sing_duration");
    var singTime:Float = singTimeValue == null ? 8 : Std.parseFloat(Std.string(singTimeValue));
    if (Math.isNaN(singTime) || singTime <= 0) singTime = 8;
    var isPixel:Bool = Reflect.field(raw, "no_antialiasing") == true;

    var data:Dynamic = {
      version: CharacterDataParser.CHARACTER_DATA_VERSION,
      name: characterId,
      renderType: "sparrow",
      assetPath: Std.string(image),
      scale: scale,
      healthIcon: {
        id: Std.string(healthIconId), shouldBop: true, scale: 1, flipX: false,
        isPixel: isPixel, offsets: [0, 25]
      },
      offsets: position,
      cameraOffsets: cameraOffsets,
      isPixel: isPixel,
      danceEvery: 1,
      singTime: singTime,
      animations: animations,
      startingAnimation: startingAnimation,
      flipX: Reflect.field(raw, "flip_x") == true,
      applyStageMatrix: false
    };
    return cast data;
  }

  static function readScriptSources(path:String, depth:Int):Array<PsychScriptSource>
  {
    var paths:Array<String> = [];
    collectScriptPaths(path, depth, paths);
    paths.sort(Reflect.compare);

    var result:Array<PsychScriptSource> = [];
    for (scriptPath in paths)
    {
      try
      {
        result.push({
          path: scriptPath,
          source: File.getContent(scriptPath)
        });
      }
      catch (error:Dynamic)
      {
        trace('[Psych Script Runtime] Could not read ' + scriptPath + ': ' + Std.string(error));
      }
    }
    return result;
  }

  static function readNamedScriptSources(path:String, requestedNames:Array<String>):Array<PsychScriptSource>
  {
    var result:Array<PsychScriptSource> = [];
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path) || requestedNames.length == 0) return result;

    var wanted:Map<String, Bool> = [];
    for (name in requestedNames)
      wanted.set(name.toLowerCase(), true);

    var entries:Array<String> = FileSystem.readDirectory(path);
    entries.sort(Reflect.compare);
    for (entry in entries)
    {
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child))
      {
        if (wanted.exists(entry.toLowerCase()))
          result = result.concat(readScriptSources(child, 5));
        continue;
      }

      var extension:String = Path.extension(entry).toLowerCase();
      var scriptName:String = Path.withoutExtension(entry).toLowerCase();
      if (wanted.exists(scriptName)
        && (extension == "lua" || extension == "hx" || extension == "hscript"))
      {
        try
        {
          result.push({path: child, source: File.getContent(child)});
        }
        catch (error:Dynamic)
        {
          trace('[Psych Script Runtime] Could not read ' + child + ': ' + Std.string(error));
        }
      }
    }

    result.sort(function(a:PsychScriptSource, b:PsychScriptSource):Int return Reflect.compare(a.path, b.path));
    return result;
  }

  static function collectScriptPaths(path:String, depth:Int, result:Array<String>):Void
  {
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;

    var entries:Array<String> = FileSystem.readDirectory(path);
    entries.sort(Reflect.compare);
    for (entry in entries)
    {
      if (entry.length == 0 || entry.charAt(0) == ".") continue;
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child))
      {
        if (depth > 0) collectScriptPaths(child, depth - 1, result);
        continue;
      }

      var lower:String = entry.toLowerCase();
      if (StringTools.endsWith(lower, ".lua") || StringTools.endsWith(lower, ".hx")
        || StringTools.endsWith(lower, ".hscript"))
        result.push(child);
    }
  }
  #end

  static function unavailable(message:String):PsychPackageAssessment
  {
    return {
      launchable: false,
      supportedSongCount: 0,
      explanation: message
    };
  }

  #if sys
  static function scanSongSources(modPath:String):Array<PsychSongSource>
  {
    var result:Array<PsychSongSource> = [];
    var dataRoot:String = Path.join([modPath, "data"]);
    if (!FileSystem.exists(dataRoot) || !FileSystem.isDirectory(dataRoot)) return result;

    for (songFolder in FileSystem.readDirectory(dataRoot))
    {
      if (songFolder.length == 0 || songFolder.charAt(0) == ".") continue;

      var dataPath:String = Path.join([dataRoot, songFolder]);
      if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) continue;

      var audioPath:Null<String> = findAudioFolder(modPath, songFolder);
      var instrumentFile:Null<String> = audioPath == null ? null : findExistingInstrument(audioPath);
      var chartFiles:Array<String> = [];

      for (fileName in FileSystem.readDirectory(dataPath))
      {
        var lower:String = fileName.toLowerCase();
        if (!StringTools.endsWith(lower, ".json") || lower == "events.json") continue;

        var chartPath:String = Path.join([dataPath, fileName]);
        var chartProblem:Null<String> = inspectUnsupportedChartFeatures(chartPath, modPath);
        var legacy:Null<FNFLegacyData> = parseLegacyChart(chartPath);
        // Preserve raw charts that use unsupported fields even when the
        // legacy importer rejects them, so a different difficulty cannot
        // accidentally make the whole package appear fully compatible.
        if ((legacy != null && legacy.song != null && legacy.song.notes != null) || chartProblem != null)
          chartFiles.push(chartPath);
      }

      if (chartFiles.length == 0) continue;

      result.push({
        songFolder: songFolder,
        dataPath: dataPath,
        audioPath: audioPath,
        instrumentFile: instrumentFile,
        chartFiles: chartFiles
      });
    }

    return result;
  }

  static function parseLegacyChart(path:String):Null<FNFLegacyData>
  {
    try
    {
      return FNFLegacyImporter.parseLegacyDataRaw(File.getContent(path), path);
    }
    catch (error:Dynamic)
    {
      return null;
    }
  }

  /**
   * Return a reason when raw Psych chart data contains a feature that the
   * current compatibility adapters cannot map without losing gameplay data.
   */
  static function inspectUnsupportedChartFeatures(path:String, modPath:String):Null<String>
  {
    try
    {
      var root:Dynamic = Json.parse(File.getContent(path));
      var song:Dynamic = Reflect.field(root, "song");
      // data/<song>/ can also contain dialogue/other JSON files. Only apply
      // this chart-specific gate when the file has the legacy song.notes key.
      if (song == null || Reflect.field(song, "notes") == null) return null;

      var supportedCharacterIds:Map<String, String> = [
        "player1" => "bf",
        "player2" => "dad",
        "player3" => "gf",
        "gfVersion" => "gf"
      ];

      for (field => expected in supportedCharacterIds)
      {
        var rawValue:Dynamic = Reflect.field(song, field);
        if (rawValue == null) continue;
        var actual:String = StringTools.trim(Std.string(rawValue));
        if (actual.length == 0 || actual.toLowerCase() == expected.toLowerCase()) continue;
        if (!hasPsychCharacterDataFile(modPath, actual))
          return "custom character '" + actual + "' is missing characters/" + actual + ".json";
      }

      var stageValue:Dynamic = Reflect.field(song, "stage");
      if (stageValue == null || StringTools.trim(Std.string(stageValue)).length == 0)
        stageValue = Reflect.field(song, "stageDefault");
      var stageName:String = stageValue == null ? Constants.DEFAULT_STAGE : StringTools.trim(Std.string(stageValue));
      if (stageName.length > 0 && stageName.toLowerCase() != Constants.DEFAULT_STAGE.toLowerCase()
        && !hasNamedPsychScript(Path.join([modPath, "stages"]), stageName))
        return "custom stage '" + stageName + "' is missing a matching stages/" + stageName + ".lua script";

      for (field in ["arrowSkin", "splashSkin", "noteStyle"])
      {
        var rawValue:Dynamic = Reflect.field(song, field);
        if (rawValue == null) continue;
        if (StringTools.trim(Std.string(rawValue)).length > 0)
          return "custom note skin/style metadata (" + field + ")";
      }

      var eventProblem:Null<String> = inspectUnsupportedEvents(Reflect.field(song, "events"), modPath);
      if (eventProblem != null) return eventProblem;

      var noteData:Dynamic = Reflect.field(song, "notes");
      if (Std.isOfType(noteData, Array))
      {
        var problem:Null<String> = inspectNoteSections(cast noteData, modPath);
        if (problem != null) return problem;
      }
      else if (noteData != null)
      {
        for (difficulty in Reflect.fields(noteData))
        {
          var difficultyNotes:Dynamic = Reflect.field(noteData, difficulty);
          if (!Std.isOfType(difficultyNotes, Array)) continue;
          var problem:Null<String> = inspectNoteSections(cast difficultyNotes, modPath);
          if (problem != null) return problem;
        }
      }

      return null;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not inspect raw chart ' + path + ': ' + Std.string(error));
      // Invalid/non-chart JSON is not a supported chart file and will not be
      // imported by parseLegacyChart either.
      return null;
    }
  }

  static function inspectUnsupportedEventFile(path:String, modPath:String):Null<String>
  {
    if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) return null;
    try
    {
      return inspectUnsupportedEvents(Json.parse(File.getContent(path)), modPath);
    }
    catch (error:Dynamic)
    {
      return "events.json could not be parsed (" + Std.string(error) + ")";
    }
  }

  static function inspectUnsupportedEvents(rawEvents:Dynamic, modPath:String):Null<String>
  {
    if (rawEvents == null) return null;
    var events:Array<PsychRawEvent> = extractPsychEvents(rawEvents);
    if (Std.isOfType(rawEvents, Array) && (cast rawEvents:Array<Dynamic>).length > 0 && events.length == 0)
      return "unrecognized Psych chart event format";

    for (event in events)
    {
      if (event.name.length == 0) return "an event with no name";
      if (isSupportedBuiltinPsychEvent(event.name)) continue;
      if (!hasNamedPsychScript(Path.join([modPath, "custom_events"]), event.name))
        return "custom event '" + event.name + "' has no matching custom_events script";
    }
    return null;
  }

  static function isSupportedBuiltinPsychEvent(name:String):Bool
  {
    return switch (StringTools.trim(name).toLowerCase())
    {
      case "add camera zoom", "screen shake", "set property", "camera follow pos",
        "play animation", "hey!", "set gf speed": true;
      default: false;
    };
  }

  static function hasNamedPsychScript(path:String, requestedName:String):Bool
  {
    if (requestedName == null || requestedName.length == 0
      || !FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;

    var normalized:String = Path.withoutExtension(Path.withoutDirectory(requestedName)).toLowerCase();
    var entries:Array<String> = FileSystem.readDirectory(path);
    for (entry in entries)
    {
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child))
      {
        if (entry.toLowerCase() == normalized && countScriptFiles(child, 5) > 0) return true;
        continue;
      }

      var extension:String = Path.extension(entry).toLowerCase();
      if ((extension == "lua" || extension == "hx" || extension == "hscript")
        && Path.withoutExtension(entry).toLowerCase() == normalized) return true;
    }
    return false;
  }

  static function extractPsychEvents(raw:Dynamic):Array<PsychRawEvent>
  {
    var result:Array<PsychRawEvent> = [];
    if (raw == null) return result;

    if (Std.isOfType(raw, Array))
    {
      for (entry in (cast raw:Array<Dynamic>))
      {
        if (entry == null) continue;
        if (Std.isOfType(entry, Array))
        {
          var row:Array<Dynamic> = cast entry;
          if (row.length >= 2 && Std.isOfType(row[1], Array))
          {
            var time:Null<Float> = parsePsychEventTime(row[0]);
            for (subEvent in (cast row[1]:Array<Dynamic>))
            {
              if (!Std.isOfType(subEvent, Array)) continue;
              var values:Array<Dynamic> = cast subEvent;
              if (values.length < 1) continue;
              appendPsychEvent(result, time, values[0], values.length > 1 ? values[1] : null,
                values.length > 2 ? values[2] : null);
            }
          }
          else if (row.length >= 2 && Std.isOfType(row[1], String))
          {
            appendPsychEvent(result, parsePsychEventTime(row[0]), row[1],
              row.length > 2 ? row[2] : null, row.length > 3 ? row[3] : null);
          }
        }
        else if (Reflect.isObject(entry))
        {
          appendPsychEventObject(result, entry);
        }
      }
      return result;
    }

    if (Reflect.isObject(raw))
    {
      var nested:Dynamic = Reflect.field(raw, "events");
      if (nested != null) return extractPsychEvents(nested);
      var song:Dynamic = Reflect.field(raw, "song");
      if (song != null)
      {
        var songEvents:Dynamic = Reflect.field(song, "events");
        if (songEvents != null) return extractPsychEvents(songEvents);
      }
      appendPsychEventObject(result, raw);
    }

    return result;
  }

  static function appendPsychEventObject(result:Array<PsychRawEvent>, entry:Dynamic):Void
  {
    var rawName:Dynamic = Reflect.field(entry, "e");
    if (rawName == null) rawName = Reflect.field(entry, "name");
    if (rawName == null) rawName = Reflect.field(entry, "event");
    var rawTime:Dynamic = Reflect.field(entry, "t");
    if (rawTime == null) rawTime = Reflect.field(entry, "time");
    var rawValues:Dynamic = Reflect.field(entry, "v");
    if (rawValues == null) rawValues = Reflect.field(entry, "value");
    var value1:Dynamic = null;
    var value2:Dynamic = null;

    if (Std.isOfType(rawValues, Array))
    {
      var values:Array<Dynamic> = cast rawValues;
      value1 = values.length > 0 ? values[0] : null;
      value2 = values.length > 1 ? values[1] : null;
    }
    else if (Reflect.isObject(rawValues))
    {
      value1 = Reflect.field(rawValues, "value1");
      value2 = Reflect.field(rawValues, "value2");
      if (value1 == null) value1 = Reflect.field(rawValues, "value");
      if (value1 == null) value1 = Reflect.field(rawValues, "anim");
      if (value2 == null) value2 = Reflect.field(rawValues, "target");
    }
    else
    {
      value1 = rawValues;
      value2 = Reflect.field(entry, "value2");
    }

    appendPsychEvent(result, parsePsychEventTime(rawTime), rawName, value1, value2);
  }

  static function appendPsychEvent(result:Array<PsychRawEvent>, time:Null<Float>, rawName:Dynamic,
      rawValue1:Dynamic, rawValue2:Dynamic):Void
  {
    if (time == null || rawName == null) return;
    var name:String = StringTools.trim(Std.string(rawName));
    if (name.length == 0) return;
    result.push({
      time: time,
      name: name,
      value1: rawValue1 == null ? "" : Std.string(rawValue1),
      value2: rawValue2 == null ? "" : Std.string(rawValue2)
    });
  }

  static function parsePsychEventTime(value:Dynamic):Null<Float>
  {
    if (value == null) return null;
    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? null : parsed;
  }

  static function collectPsychNoteTypes(noteData:Dynamic, result:Array<String>):Void
  {
    if (noteData == null) return;
    if (Std.isOfType(noteData, Array))
    {
      collectPsychNoteTypesFromSections(cast noteData, result);
      return;
    }

    for (difficulty in Reflect.fields(noteData))
    {
      var sections:Dynamic = Reflect.field(noteData, difficulty);
      if (Std.isOfType(sections, Array))
        collectPsychNoteTypesFromSections(cast sections, result);
    }
  }

  static function collectPsychNoteTypesFromSections(sections:Array<Dynamic>, result:Array<String>):Void
  {
    for (section in sections)
    {
      if (section == null) continue;
      var rows:Dynamic = Reflect.field(section, "sectionNotes");
      if (!Std.isOfType(rows, Array)) continue;
      for (note in (cast rows:Array<Dynamic>))
      {
        if (!Std.isOfType(note, Array)) continue;
        var values:Array<Dynamic> = cast note;
        if (values.length <= 3 || !Std.isOfType(values[3], String)) continue;
        var name:String = StringTools.trim(cast values[3]);
        if (name.length > 0 && !result.contains(name.toLowerCase())) result.push(name.toLowerCase());
      }
    }
  }

  static function inspectNoteSections(sections:Array<Dynamic>, modPath:String):Null<String>
  {
    for (section in sections)
    {
      if (section == null) continue;

      var sectionType:Dynamic = Reflect.field(section, "typeOfSection");
      if (sectionType != null && Std.int(sectionType) != 0)
        return "alternate section type metadata";

      var gfSection:Dynamic = Reflect.field(section, "gfSection");
      if (gfSection == true)
        return "GF-specific section ownership";

      var rows:Dynamic = Reflect.field(section, "sectionNotes");
      if (!Std.isOfType(rows, Array)) continue;

      for (note in (cast rows:Array<Dynamic>))
      {
        if (!Std.isOfType(note, Array)) continue;
        var values:Array<Dynamic> = cast note;
        if (values.length < 2 || values[1] == null) continue;

        var lane:Float = Std.parseFloat(Std.string(values[1]));
        if (Math.isNaN(lane) || lane < 0 || lane > 7)
          return "event or non-standard note-lane data";

        if (values.length > 3 && values[3] != null)
        {
          var noteType:Dynamic = values[3];
          if (Std.isOfType(noteType, Bool))
          {
            // The vanilla alternate-animation note flag is preserved by the
            // legacy adapter and maps to NovaBeat's built-in "alt" note kind.
            continue;
          }
          if (Std.isOfType(noteType, String))
          {
            var customType:String = StringTools.trim(cast noteType);
            if (customType.length == 0) continue;
            if (!hasNamedPsychScript(Path.join([modPath, "custom_notetypes"]), customType))
              return "custom note type '" + customType + "' has no matching custom_notetypes script";
            continue;
          }
          return "unrecognized Psych note-type metadata";
        }
      }
    }

    return null;
  }

  static function readPsychString(source:Dynamic, field:String, fallback:String):String
  {
    var value:Dynamic = source == null ? null : Reflect.field(source, field);
    if (value == null) return fallback;
    var result:String = StringTools.trim(Std.string(value));
    return result.length == 0 ? fallback : result;
  }

  static function buildNativeSong(songId:String, source:PsychSongSource):Null<Song>
  {
    var metadata:Null<SongMetadata> = null;
    var psychPlayerId:String = "bf";
    var psychGirlfriendId:String = "gf";
    var psychOpponentId:String = "dad";
    var combinedNotes:Map<String, Array<funkin.data.song.SongData.SongNoteData>> = [];
    var combinedSpeeds:Map<String, Float> = [];
    var combinedEvents:Array<funkin.data.song.SongData.SongEventData> = [];

    for (chartPath in source.chartFiles)
    {
      var legacy:Null<FNFLegacyData> = parseLegacyChart(chartPath);
      if (legacy == null || legacy.song == null || legacy.song.notes == null) continue;

      var chartRoot:Dynamic = Json.parse(File.getContent(chartPath));
      var chartSong:Dynamic = Reflect.field(chartRoot, "song");
      var difficultyName:String = getDifficultyName(source.songFolder, Path.withoutExtension(Path.withoutDirectory(chartPath)));
      var importedMetadata:SongMetadata = FNFLegacyImporter.migrateMetadata(legacy, difficultyName);
      var importedChart:SongChartData = FNFLegacyImporter.migrateChartData(legacy, difficultyName);

      if (metadata == null)
      {
        metadata = importedMetadata;
        psychPlayerId = readPsychString(chartSong, "player1", "bf");
        psychOpponentId = readPsychString(chartSong, "player2", "dad");
        psychGirlfriendId = readPsychString(chartSong, "gfVersion", readPsychString(chartSong, "player3", "gf"));
      }

      for (difficulty in importedChart.notes.keys())
      {
        combinedNotes.set(difficulty, importedChart.getNotes(difficulty));
        combinedSpeeds.set(difficulty, importedChart.getScrollSpeed(difficulty));
      }

      // Legacy camera changes are synthesized from section ownership by the importer.
      if (combinedEvents.length == 0)
      {
        for (event in importedChart.events)
          combinedEvents.push(event);
      }

      for (event in extractPsychEvents(Reflect.field(chartSong, "events")))
      {
        combinedEvents.push(new SongEventData(event.time, "PsychCompatibilityEvent", {
          name: event.name,
          value1: event.value1,
          value2: event.value2
        }));
      }
    }

    // Some Psych versions store event data in a separate events.json file.
    var externalEventsPath:String = Path.join([source.dataPath, "events.json"]);
    if (FileSystem.exists(externalEventsPath))
    {
      var externalEvents:Dynamic = Json.parse(File.getContent(externalEventsPath));
      for (event in extractPsychEvents(externalEvents))
      {
        combinedEvents.push(new SongEventData(event.time, "PsychCompatibilityEvent", {
          name: event.name,
          value1: event.value1,
          value2: event.value2
        }));
      }
    }

    if (metadata == null || !combinedNotes.keys().hasNext()) return null;

    // The first adapter tier deliberately uses the original base-game cast and
    // default stage. It does not pretend to load Psych-only character/stage data.
    metadata.variation = Constants.DEFAULT_VARIATION;
    metadata.generatedBy = "NovaBeat Psych compatibility";
    metadata.playData.songVariations = [];
    metadata.playData.difficulties = [for (difficulty in combinedNotes.keys()) difficulty];
    metadata.playData.characters = new SongCharacterData(psychPlayerId, psychGirlfriendId, psychOpponentId);
    metadata.playData.stage = Constants.DEFAULT_STAGE;
    metadata.playData.noteStyle = Constants.DEFAULT_NOTE_STYLE;
    for (difficulty in metadata.playData.difficulties)
    {
      metadata.playData.ratings.set(difficulty, 0);
    }

    var chart:SongChartData = new SongChartData(combinedSpeeds, combinedEvents, combinedNotes);
    var charts:Map<String, SongChartData> = [];
    charts.set(Constants.DEFAULT_VARIATION, chart);

    return Song.buildRaw(songId, [metadata], Constants.DEFAULT_VARIATION, charts, false, false);
  }

  static function findAudioFolder(modPath:String, songFolder:String):Null<String>
  {
    var candidates:Array<String> = [
      Path.join([modPath, "songs", songFolder]),
      Path.join([modPath, "assets", "songs", songFolder])
    ];

    for (candidate in candidates)
    {
      if (FileSystem.exists(candidate) && FileSystem.isDirectory(candidate)) return candidate;
    }
    return null;
  }

  static function findExistingInstrument(audioPath:String):Null<String>
  {
    for (fileName in ["Inst.ogg", "Inst.mp3", "Inst.wav"])
    {
      var candidate:String = Path.join([audioPath, fileName]);
      if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate)) return candidate;
    }
    return null;
  }

  static function countPsychScripts(modPath:String):Int
  {
    // Only top-level/global scripts are part of the initial supported loader.
    return countScriptFiles(Path.join([modPath, "scripts"]), 5);
  }

  static function countUnsupportedPsychScripts(modPath:String):Int
  {
    // Referenced custom_events and custom_notetypes are loaded by name.
    // The remaining Psych script roots still require unsupported state/asset
    // lifecycle adapters and are deliberately rejected.
    var roots:Array<String> = [
      "custom_notes"
    ];
    var count:Int = 0;
    for (folder in roots)
      count += countScriptFiles(Path.join([modPath, folder]), 5);
    return count;
  }

  static function hasSongScripts(source:PsychSongSource):Bool
  {
    return countScriptFiles(source.dataPath, 3) > 0;
  }

  static function countScriptFiles(path:String, depth:Int):Int
  {
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return 0;
    var count:Int = 0;

    for (entry in FileSystem.readDirectory(path))
    {
      if (entry.length == 0 || entry.charAt(0) == ".") continue;
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child))
      {
        if (depth > 0) count += countScriptFiles(child, depth - 1);
        continue;
      }

      var lower:String = entry.toLowerCase();
      if (StringTools.endsWith(lower, ".lua") || StringTools.endsWith(lower, ".hx") || StringTools.endsWith(lower, ".hscript"))
        count++;
    }

    return count;
  }

  static function getDifficultyName(songFolder:String, fileName:String):String
  {
    var normalized:String = fileName.toLowerCase();
    var songKey:String = songFolder.toLowerCase();

    if (normalized == songKey || normalized == "chart") return Constants.DEFAULT_DIFFICULTY;
    if (StringTools.startsWith(normalized, songKey + "-"))
      return normalized.substr(songKey.length + 1);
    if (StringTools.startsWith(normalized, "chart-"))
      return normalized.substr("chart-".length);

    return Constants.DEFAULT_DIFFICULTY;
  }

  static function buildSongId(modDirectory:String, songFolder:String):String
  {
    return "psych-" + slug(modDirectory) + "-" + slug(songFolder);
  }

  static function slug(value:String):String
  {
    var result:String = ~/[^a-zA-Z0-9]+/g.replace(value, "-").toLowerCase();
    while (StringTools.startsWith(result, "-")) result = result.substr(1);
    while (StringTools.endsWith(result, "-")) result = result.substr(0, result.length - 1);
    return result.length == 0 ? "mod" : result;
  }
  #else
  static function scanSongSources(modPath:String):Array<PsychSongSource> return [];
  static function parseLegacyChart(path:String):Null<FNFLegacyData> return null;
  static function buildNativeSong(songId:String, source:PsychSongSource):Null<Song> return null;
  static function findAudioFolder(modPath:String, songFolder:String):Null<String> return null;
  static function findExistingInstrument(audioPath:String):Null<String> return null;
  static function countPsychScripts(modPath:String):Int return 0;
  static function countUnsupportedPsychScripts(modPath:String):Int return 0;
  static function countScriptFiles(path:String, depth:Int):Int return 0;
  static function getDifficultyName(songFolder:String, fileName:String):String return Constants.DEFAULT_DIFFICULTY;
  static function buildSongId(modDirectory:String, songFolder:String):String return "psych-" + modDirectory + "-" + songFolder;
  static function slug(value:String):String return value;
  static function readScriptSources(path:String, depth:Int):Array<PsychScriptSource> return [];
  static function collectScriptPaths(path:String, depth:Int, result:Array<String>):Void {}
  #end

  static function findSongAsset(songFolder:String, baseName:String):Null<String>
  {
    var fileCandidates:Array<String> = [baseName + ".ogg", baseName + ".mp3", baseName + ".wav"];
    var soundKeys:Array<String> = cachedSoundAssetKeys ??= Assets.list(AssetType.SOUND);

    for (fileName in fileCandidates)
    {
      var suffix:String = "/" + songFolder.toLowerCase() + "/" + fileName.toLowerCase();
      for (assetKey in soundKeys)
      {
        var normalized:String = assetKey.toLowerCase().replace("\\", "/");
        if (StringTools.endsWith(normalized, suffix) && Assets.exists(assetKey, AssetType.SOUND))
          return assetKey;
      }
    }

    // These aliases cover both legacy Psych mods (songs/<song>/...) and
    // source-built Psych content placed under assets/songs/<song>/...
    for (fileName in fileCandidates)
    {
      var candidates:Array<String> = [
        "songs:" + songFolder + "/" + fileName,
        "songs:songs/" + songFolder + "/" + fileName,
        "songs:assets/songs/" + songFolder + "/" + fileName
      ];
      for (candidate in candidates)
      {
        if (Assets.exists(candidate, AssetType.SOUND)) return candidate;
      }
    }

    return null;
  }
}

typedef PsychPackageAssessment =
{
  var launchable:Bool;
  var supportedSongCount:Int;
  var explanation:String;
}

typedef PsychSongSource =
{
  var songFolder:String;
  var dataPath:String;
  var audioPath:Null<String>;
  var instrumentFile:Null<String>;
  var chartFiles:Array<String>;
}


typedef PsychScriptSource =
{
  var path:String;
  var source:String;
}

typedef PsychRawEvent =
{
  var time:Float;
  var name:String;
  var value1:String;
  var value2:String;
}
