package funkin.modding;

import funkin.Assets;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongMetadata;
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
 * Packages requiring unimplemented custom events, note types, stages,
 * characters, or substates are kept unavailable rather than partially loaded.
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
        var chartProblem:Null<String> = inspectUnsupportedChartFeatures(chartPath);
        if (chartProblem != null)
        {
          return unavailable("This Psych package contains a chart feature NovaBeat does not support yet: " + chartProblem);
        }
      }
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
        : "Limited native Psych chart compatibility: " + Std.string(supportedSongs) + " classic chart song(s) can launch with NovaBeat's built-in characters and default stage. Lua/HScript song and global script loading is available for this basic compatibility tier. Custom events, note types, stages, characters, and custom substates remain unsupported.";
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

  /**
   * Read the supported Psych script set for the active song. Global scripts
   * from each active package load first, followed by matching data/<song>
   * scripts. Custom event/stage/character folders are intentionally excluded.
   */
  public static function getScriptSources(modDirs:Array<String>, songId:String):Array<PsychScriptSource>
  {
    var globalSources:Array<PsychScriptSource> = [];
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
        songSources = songSources.concat(readScriptSources(dataPath, 3));
      }
    }
    #end
    return globalSources.concat(songSources);
  }

  #if sys
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
        var chartProblem:Null<String> = inspectUnsupportedChartFeatures(chartPath);
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
   * current legacy-chart adapter would otherwise discard or replace.
   */
  static function inspectUnsupportedChartFeatures(path:String):Null<String>
  {
    try
    {
      var root:Dynamic = Json.parse(File.getContent(path));
      var song:Dynamic = Reflect.field(root, "song");
      // data/<song>/ can also contain dialogue/other JSON files. Only apply
      // this chart-specific gate when the file has the legacy song.notes key.
      if (song == null || Reflect.field(song, "notes") == null) return null;

      var supportedIds:Map<String, String> = [
        "player1" => "bf",
        "player2" => "dad",
        "player3" => "gf",
        "gfVersion" => "gf",
        "stage" => Constants.DEFAULT_STAGE,
        "stageDefault" => Constants.DEFAULT_STAGE
      ];

      for (field => expected in supportedIds)
      {
        var rawValue:Dynamic = Reflect.field(song, field);
        if (rawValue == null) continue;
        var actual:String = StringTools.trim(Std.string(rawValue)).toLowerCase();
        if (actual.length == 0) continue;
        if (actual != expected.toLowerCase())
          return "custom or non-default " + field + " (" + actual + ")";
      }

      for (field in ["arrowSkin", "splashSkin", "noteStyle"])
      {
        var rawValue:Dynamic = Reflect.field(song, field);
        if (rawValue == null) continue;
        if (StringTools.trim(Std.string(rawValue)).length > 0)
          return "custom note skin/style metadata (" + field + ")";
      }

      var events:Dynamic = Reflect.field(song, "events");
      if (Std.isOfType(events, Array) && (cast events:Array<Dynamic>).length > 0)
        return "chart event data";

      var noteData:Dynamic = Reflect.field(song, "notes");
      if (Std.isOfType(noteData, Array))
      {
        var problem:Null<String> = inspectNoteSections(cast noteData);
        if (problem != null) return problem;
      }
      else if (noteData != null)
      {
        for (difficulty in Reflect.fields(noteData))
        {
          var difficultyNotes:Dynamic = Reflect.field(noteData, difficulty);
          if (!Std.isOfType(difficultyNotes, Array)) continue;
          var problem:Null<String> = inspectNoteSections(cast difficultyNotes);
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

  static function inspectNoteSections(sections:Array<Dynamic>):Null<String>
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
            if (noteType == true) return "alternate-animation note types";
            continue;
          }
          if (Std.isOfType(noteType, String) && StringTools.trim(cast noteType).length == 0) continue;
          return "custom Psych note types";
        }
      }
    }

    return null;
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
    // Only top-level/global scripts are part of the initial supported loader.
    return countScriptFiles(Path.join([modPath, "scripts"]), 5);
  }

  static function countUnsupportedPsychScripts(modPath:String):Int
  {
    var roots:Array<String> = [
      "custom_events",
      "custom_notetypes",
      "custom_notes",
      "custom_substates",
      "stages",
      "characters"
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
