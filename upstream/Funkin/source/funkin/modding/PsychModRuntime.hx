package funkin.modding;

import funkin.Assets;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongRegistry;
import funkin.data.song.importer.FNFLegacyData;
import funkin.data.song.importer.FNFLegacyImporter;
import funkin.play.song.Song;
import openfl.utils.AssetType;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * First-pass runtime bridge for classic Psych Engine chart-only songs.
 *
 * This bridge intentionally does not execute mod scripts. It converts legacy
 * Psych chart JSON into native V-Slice Song/SongDifficulty objects and resolves
 * Psych's conventional songs/<song>/ audio assets through Polymod's asset
 * libraries. Packages that require Lua/HScript are not considered launchable
 * by this compatibility tier.
 */
@:nullSafety(Off)
class PsychModRuntime
{
  static final audioFolders:Map<String, String> = [];
  static var cachedSoundAssetKeys:Null<Array<String>> = null;

  public static function inspectPackage(modPath:String):PsychPackageAssessment
  {
    #if sys
    if (!FileSystem.exists(modPath) || !FileSystem.isDirectory(modPath))
      return unavailable("The Psych mod folder could not be read.");

    var sources:Array<PsychSongSource> = scanSongSources(modPath);
    var scriptCount:Int = countPsychScripts(modPath);
    var playableCount:Int = 0;
    var songScriptCount:Int = 0;

    for (source in sources)
    {
      if (source.instrumentFile == null || source.chartFiles.length == 0) continue;
      if (hasSongScripts(source))
      {
        songScriptCount++;
        continue;
      }
      playableCount++;
    }

    if (playableCount == 0)
    {
      return {
        launchable: false,
        supportedSongCount: 0,
        explanation: songScriptCount > 0
          ? "Psych charts and instrumentals were found, but every complete song has a song-local Lua/HScript file. Those songs are not launchable until the Psych scripting runtime is implemented."
          : "Psych Engine detected. This first native compatibility tier needs a classic data/<song> chart and a matching Inst.ogg, Inst.mp3, or Inst.wav file under songs/<song>/ or assets/songs/<song>/. This package does not contain a complete song in that format."
      };
    }

    if (scriptCount > 0)
    {
      return {
        launchable: false,
        supportedSongCount: 0,
        explanation: "Psych songs were found, but this mod contains Lua/HScript files. NovaBeat does not execute Psych scripts yet, so this package may depend on missing gameplay behavior."
      };
    }

    return {
      launchable: true,
      supportedSongCount: playableCount,
      explanation: "Limited native Psych compatibility: " + Std.string(playableCount) + " classic chart song(s) without song-local scripts can launch with NovaBeat's built-in characters and default stage. " + Std.string(songScriptCount) + " song(s) with local Lua/HScript are skipped. Psych Lua/HScript execution, custom events, custom note types, custom character/stage behavior, and HTML5 local-mod launching are not supported yet."
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

      for (source in scanSongSources(modPath))
      {
        if (source.instrumentFile == null || source.chartFiles.length == 0 || hasSongScripts(source)) continue;
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
        if (source.instrumentFile == null || source.chartFiles.length == 0 || hasSongScripts(source)) continue;

        var songId:String = buildSongId(directory, source.songFolder);
        try
        {
          var song:Null<Song> = buildNativeSong(songId, source);
          if (song == null) continue;

          audioFolders.set(songId, source.songFolder);
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
        var legacy:Null<FNFLegacyData> = parseLegacyChart(chartPath);
        if (legacy != null && legacy.song != null && legacy.song.notes != null)
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

  static function buildNativeSong(songId:String, source:PsychSongSource):Null<Song>
  {
    var metadata:Null<SongMetadata> = null;
    var combinedNotes:Map<String, Array<funkin.data.song.SongData.SongNoteData>> = [];
    var combinedSpeeds:Map<String, Float> = [];
    var combinedEvents:Array<funkin.data.song.SongData.SongEventData> = [];

    for (chartPath in source.chartFiles)
    {
      var legacy:Null<FNFLegacyData> = parseLegacyChart(chartPath);
      if (legacy == null || legacy.song == null || legacy.song.notes == null) continue;

      var difficultyName:String = getDifficultyName(source.songFolder, Path.withoutExtension(Path.withoutDirectory(chartPath)));
      var importedMetadata:SongMetadata = FNFLegacyImporter.migrateMetadata(legacy, difficultyName);
      var importedChart:SongChartData = FNFLegacyImporter.migrateChartData(legacy, difficultyName);

      if (metadata == null) metadata = importedMetadata;

      for (difficulty in importedChart.notes.keys())
      {
        combinedNotes.set(difficulty, importedChart.getNotes(difficulty));
        combinedSpeeds.set(difficulty, importedChart.getScrollSpeed(difficulty));
      }

      // Legacy events are synthesized from section ownership by the importer.
      // They are difficulty-independent in this limited compatibility tier.
      if (combinedEvents.length == 0)
      {
        for (event in importedChart.events)
        {
          combinedEvents.push(event);
        }
      }
    }

    if (metadata == null || !combinedNotes.keys().hasNext()) return null;

    // The first adapter tier deliberately uses the original base-game cast and
    // default stage. It does not pretend to load Psych-only character/stage data.
    metadata.variation = Constants.DEFAULT_VARIATION;
    metadata.generatedBy = "NovaBeat Psych compatibility";
    metadata.playData.songVariations = [];
    metadata.playData.difficulties = [for (difficulty in combinedNotes.keys()) difficulty];
    metadata.playData.characters = new SongCharacterData("bf", "gf", "dad");
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
    var roots:Array<String> = [
      "scripts",
      "custom_events",
      "custom_notetypes",
      "custom_notes",
      "custom_substates",
      "stages",
      "characters"
    ];
    var count:Int = 0;
    for (folder in roots)
    {
      count += countScriptFiles(Path.join([modPath, folder]), 5);
    }
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
      if (StringTools.endsWith(lower, ".lua") || StringTools.endsWith(lower, ".hx"))
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
  static function countScriptFiles(path:String, depth:Int):Int return 0;
  static function getDifficultyName(songFolder:String, fileName:String):String return Constants.DEFAULT_DIFFICULTY;
  static function buildSongId(modDirectory:String, songFolder:String):String return "psych-" + modDirectory + "-" + songFolder;
  static function slug(value:String):String return value;
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
