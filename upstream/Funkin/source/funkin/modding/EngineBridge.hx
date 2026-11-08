package funkin.modding;

#if sys
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Identifies the engine a package was authored for.
 *
 * NovaBeat is V-Slice-based, so V-Slice content uses the native runtime.
 * There is deliberately no second V-Slice adapter.
 *
 * Psych package identification is version-agnostic. Exact version labels are
 * shown only when a package explicitly declares its Psych Engine version.
 */
class EngineBridge
{
  public static inline final ENGINE_VSLICE:String = "v-slice";
  public static inline final ENGINE_PSYCH:String = "psych-engine";
  public static inline final ENGINE_UNKNOWN:String = "unknown";

  public static function detectEngine(
    modPath:String,
    polymodMetadata:Dynamic,
    novaBeatMetadata:Dynamic,
    packageMetadata:Dynamic = null
  ):EngineDetection
  {
    var engineValue:Dynamic = firstField([novaBeatMetadata, polymodMetadata, packageMetadata], ["engine", "engineId", "engine_id", "engineName", "engine_name", "psychEngine", "psych_engine"]);
    var declaredId:Null<String> = asString(engineValue);

    if (declaredId == null && engineValue != null && !Std.isOfType(engineValue, String))
    {
      declaredId = firstString(engineValue, ["id", "name", "engineId", "engine_id"]);
    }

    var normalized:String = declaredId == null ? "" : declaredId.toLowerCase();
    var explicitlyPsych:Bool = normalized.indexOf("psych") >= 0 || hasPsychMetadataFlag([novaBeatMetadata, polymodMetadata, packageMetadata]);

    // A version-only field is treated as a Psych declaration only when its
    // key explicitly names Psych. Generic "version" fields describe the mod,
    // not necessarily the engine, and must not be mistaken for engine versions.
    var psychVersion:Null<String> = findPsychVersion(engineValue, [novaBeatMetadata, polymodMetadata, packageMetadata], explicitlyPsych);
    var isPsych:Bool = explicitlyPsych || psychVersion != null || hasPsychMarkers(modPath);

    if (isPsych)
    {
      return {
        id: ENGINE_PSYCH,
        label: psychVersion == null ? "Psych Engine (version unknown)" : "Psych Engine " + psychVersion,
        version: psychVersion,
        launchable: false,
        explanation: psychVersion == null
          ? "Psych Engine was detected, but this package does not declare its exact Psych version. It remains unavailable until the matching compatibility features are implemented."
          : "Psych Engine " + psychVersion + " was detected. Psych runtime compatibility is not enabled in this NovaBeat build yet."
      };
    }

    var version:Null<String> = null;
    if (engineValue != null && !Std.isOfType(engineValue, String))
      version = firstString(engineValue, ["version"]);
    if (version == null)
      version = firstString(novaBeatMetadata, ["engineVersion", "engine_version"]);
    if (version == null)
      version = firstString(polymodMetadata, ["engineVersion", "engine_version"]);

    if (normalized.indexOf("v-slice") >= 0 || normalized.indexOf("vslice") >= 0
      || normalized.indexOf("funkin") >= 0 || normalized.indexOf("novabeat") >= 0)
    {
      return {
        id: ENGINE_VSLICE,
        label: "V-Slice",
        version: version,
        launchable: true,
        explanation: "Runs directly in NovaBeat's native V-Slice runtime."
      };
    }

    if (polymodMetadata != null)
    {
      return {
        id: ENGINE_VSLICE,
        label: "V-Slice",
        version: version,
        launchable: true,
        explanation: "Recognized as a native Polymod/V-Slice package."
      };
    }

    return {
      id: ENGINE_UNKNOWN,
      label: "Unknown Engine",
      version: version,
      launchable: false,
      explanation: "NovaBeat could not confidently identify this mod's engine."
    };
  }

  static function hasPsychMetadataFlag(sources:Array<Dynamic>):Bool
  {
    for (source in sources)
    {
      if (source == null) continue;
      for (field in ["isPsych", "isPsychEngine", "is_psych_engine", "psychEngine", "psych_engine"])
      {
        var value:Dynamic = Reflect.field(source, field);
        if (value == true) return true;
        var text:Null<String> = asString(value);
        if (text != null && text.toLowerCase().indexOf("psych") >= 0) return true;
      }
    }
    return false;
  }

  static function firstField(sources:Array<Dynamic>, fields:Array<String>):Dynamic
  {
    for (source in sources)
    {
      if (source == null) continue;
      for (field in fields)
      {
        var value:Dynamic = Reflect.field(source, field);
        if (value != null) return value;
      }
    }
    return null;
  }

  static function firstString(source:Dynamic, fields:Array<String>):Null<String>
  {
    if (source == null) return null;
    for (field in fields)
    {
      var value:Null<String> = asString(Reflect.field(source, field));
      if (value != null) return value;
    }
    return null;
  }

  static function findPsychVersion(
    engineValue:Dynamic,
    metadataSources:Array<Dynamic>,
    explicitlyPsych:Bool
  ):Null<String>
  {
    var psychVersionFields:Array<String> = [
      "psychEngineVersion",
      "psych_engine_version",
      "psychVersion",
      "psych_version"
    ];
    var generalVersionFields:Array<String> = ["version", "engineVersion", "engine_version"];

    // A structured engine declaration may use a generic version field, but
    // only when its ID/name explicitly identifies Psych Engine.
    if (engineValue != null && !Std.isOfType(engineValue, String))
    {
      var nestedId:Null<String> = firstString(engineValue, ["id", "name", "engineId", "engine_id"]);
      var nestedIsPsych:Bool = explicitlyPsych || (nestedId != null && nestedId.toLowerCase().indexOf("psych") >= 0);
      var nestedVersion:Null<String> = firstString(engineValue,
        nestedIsPsych ? generalVersionFields.concat(psychVersionFields) : psychVersionFields);
      if (nestedVersion != null) return normalizeVersion(nestedVersion);
    }

    // String declarations may include a version, e.g. "Psych Engine v0.7.3".
    var engineText:Null<String> = asString(engineValue);
    if (engineText != null && (explicitlyPsych || engineText.toLowerCase().indexOf("psych") >= 0))
    {
      var parsedEngineVersion:Null<String> = extractVersion(engineText);
      if (parsedEngineVersion != null) return parsedEngineVersion;
    }

    for (source in metadataSources)
    {
      if (source == null) continue;

      // Explicit Psych-specific version keys are safe even when a separate
      // engine declaration is absent.
      var direct:Null<String> = firstString(source, psychVersionFields);
      if (direct != null)
      {
        var parsed:Null<String> = extractVersion(direct);
        return parsed == null ? direct : parsed;
      }

      var engine:Dynamic = Reflect.field(source, "engine");
      if (engine != null && !Std.isOfType(engine, String))
      {
        var nestedId:Null<String> = firstString(engine, ["id", "name", "engineId", "engine_id"]);
        var nestedIsPsych:Bool = explicitlyPsych || (nestedId != null && nestedId.toLowerCase().indexOf("psych") >= 0);
        var nested:Null<String> = firstString(engine,
          nestedIsPsych ? generalVersionFields.concat(psychVersionFields) : psychVersionFields);
        if (nested != null) return normalizeVersion(nested);
      }

      // Some manifests declare "engine": "Psych Engine" and place the
      // corresponding version beside it as "engineVersion".
      if (explicitlyPsych)
      {
        var declaredEngineVersion:Null<String> = firstString(source, ["engineVersion", "engine_version"]);
        if (declaredEngineVersion != null) return normalizeVersion(declaredEngineVersion);
      }
    }

    return null;
  }
  static function normalizeVersion(value:String):String
  {
    var parsed:Null<String> = extractVersion(value);
    return parsed == null ? StringTools.trim(value) : parsed;
  }

  static function extractVersion(value:String):Null<String>
  {
    var pattern:EReg = ~/([0-9]+(?:\.[0-9A-Za-z]+){1,3}(?:[-+][0-9A-Za-z.-]+)?)/;
    if (pattern.match(value)) return pattern.matched(1);
    return null;
  }
  /**
   * Runtime-facing wrapper used by the native Psych compatibility scanner.
   * The detailed marker check remains shared with the Game Library detector.
   */
  public static function hasPsychMarkersForRuntime(modPath:String):Bool
  {
    #if sys
    return hasPsychMarkers(modPath);
    #else
    return false;
    #end
  }

  public static function canLaunch(engineId:String):Bool
  {
    return engineId == ENGINE_VSLICE;
  }

  static function asString(value:Dynamic):Null<String>
  {
    if (value == null || !Std.isOfType(value, String)) return null;
    var result:String = cast value;
    return result.length == 0 ? null : result;
  }

  #if sys
  /**
   * Detect Psych mod layouts without depending on a particular Psych version.
   *
   * Psych has changed packaging conventions over time, so detection checks
   * several long-lived signatures: Psych-specific script roots, Lua/HScript
   * files in known roots, and the legacy chart JSON envelope. A generic data
   * or scripts folder alone is not enough.
   */
  static function hasPsychMarkers(modPath:String):Bool
  {
    if (!FileSystem.exists(modPath) || !FileSystem.isDirectory(modPath)) return false;

    if (hasPsychMarkersInRoot(modPath)) return true;

    // Some users extract a downloaded mod archive without removing its
    // wrapper folder. Recognize one common nested "mods/<mod-name>" layout.
    var nestedModsPath:String = Path.join([modPath, "mods"]);
    if (FileSystem.exists(nestedModsPath) && FileSystem.isDirectory(nestedModsPath))
    {
      for (entry in FileSystem.readDirectory(nestedModsPath))
      {
        if (entry.length == 0 || entry.charAt(0) == ".") continue;
        var candidate:String = Path.join([nestedModsPath, entry]);
        if (FileSystem.isDirectory(candidate) && hasPsychMarkersInRoot(candidate)) return true;
      }
    }

    return false;
  }

  static function hasPsychMarkersInRoot(root:String):Bool
  {
    // These directories are strong Psych signatures across multiple releases.
    var distinctiveFolders:Array<String> = ["custom_events", "custom_notetypes", "custom_substates"];
    for (folder in distinctiveFolders)
    {
      var path:String = Path.join([root, folder]);
      if (FileSystem.exists(path) && FileSystem.isDirectory(path)) return true;
    }

    // Script locations used by Psych mods over time. Four levels allow
    // data/<song>/ and a nested difficulty/script folder without traversing
    // large art/audio directories.
    var scriptFolders:Array<String> = [
      "scripts",
      "stages",
      "characters",
      "custom_events",
      "custom_notetypes",
      "custom_substates",
      "data"
    ];
    for (folder in scriptFolders)
    {
      if (containsPsychScript(Path.join([root, folder]), 4)) return true;
    }

    // Asset-only packages can still be recognized from Psych's distinctive
    // week, character, and stage JSON schemas even without any scripts/charts.
    return hasPsychChartMarkers(root)
      || hasPsychWeekMarkers(root)
      || hasPsychCharacterMarkers(root)
      || hasPsychStageMarkers(root);
  }

  /**
   * Looks for Lua/HScript files in a known Psych script root. The depth cap
   * keeps discovery bounded when a mod includes large asset directories.
   */
  static function containsPsychScript(path:String, remainingDepth:Int):Bool
  {
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;

    for (entry in FileSystem.readDirectory(path))
    {
      if (entry.length == 0 || entry.charAt(0) == ".") continue;
      var childPath:String = Path.join([path, entry]);

      if (FileSystem.isDirectory(childPath))
      {
        if (remainingDepth > 0 && containsPsychScript(childPath, remainingDepth - 1)) return true;
        continue;
      }

      var lower:String = entry.toLowerCase();
      if (StringTools.endsWith(lower, ".lua") || StringTools.endsWith(lower, ".hx")) return true;
    }

    return false;
  }

  /**
   * Psych's legacy chart format wraps the song in a top-level "song" object
   * containing note sections. This signature has remained useful across
   * older and newer official Psych releases, including chart-only packages.
   */
  static function hasPsychChartMarkers(root:String):Bool
  {
    var dataPath:String = Path.join([root, "data"]);
    if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) return false;

    for (songFolder in FileSystem.readDirectory(dataPath))
    {
      if (songFolder.length == 0 || songFolder.charAt(0) == ".") continue;
      var songPath:String = Path.join([dataPath, songFolder]);

      if (!FileSystem.isDirectory(songPath))
      {
        if (StringTools.endsWith(songFolder.toLowerCase(), ".json") && isPsychChartFile(Path.join([dataPath, songFolder])))
          return true;
        continue;
      }

      for (fileName in FileSystem.readDirectory(songPath))
      {
        if (!StringTools.endsWith(fileName.toLowerCase(), ".json")) continue;
        if (isPsychChartFile(Path.join([songPath, fileName]))) return true;
      }
    }

    return false;
  }


  /**
   * Psych week files have a distinctive schema containing songs,
   * weekCharacters, and weekName.
   */
  static function hasPsychWeekMarkers(root:String):Bool
  {
    var path:String = Path.join([root, "weeks"]);
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;

    for (fileName in FileSystem.readDirectory(path))
    {
      if (!StringTools.endsWith(fileName.toLowerCase(), ".json")) continue;
      try
      {
        var parsed:Dynamic = Json.parse(File.getContent(Path.join([path, fileName])));
        var songs:Dynamic = Reflect.field(parsed, "songs");
        var weekCharacters:Dynamic = Reflect.field(parsed, "weekCharacters");
        var weekName:Dynamic = Reflect.field(parsed, "weekName");
        if (Std.isOfType(songs, Array) && Std.isOfType(weekCharacters, Array)
          && weekName != null && Std.isOfType(weekName, String))
          return true;
      }
      catch (error:Dynamic)
      {
        // Ignore malformed or unrelated JSON files.
      }
    }
    return false;
  }

  /**
   * Psych character JSONs use animations, image, healthicon, and
   * healthbar_colors fields. Requiring the combination avoids matching
   * ordinary character metadata from other engines.
   */
  static function hasPsychCharacterMarkers(root:String):Bool
  {
    var path:String = Path.join([root, "characters"]);
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;

    for (fileName in FileSystem.readDirectory(path))
    {
      if (!StringTools.endsWith(fileName.toLowerCase(), ".json")) continue;
      try
      {
        var parsed:Dynamic = Json.parse(File.getContent(Path.join([path, fileName])));
        var animations:Dynamic = Reflect.field(parsed, "animations");
        var image:Dynamic = Reflect.field(parsed, "image");
        var healthIcon:Dynamic = Reflect.field(parsed, "healthicon");
        var healthColors:Dynamic = Reflect.field(parsed, "healthbar_colors");
        if (Std.isOfType(animations, Array) && image != null && Std.isOfType(image, String)
          && healthIcon != null && Std.isOfType(healthIcon, String)
          && Std.isOfType(healthColors, Array))
          return true;
      }
      catch (error:Dynamic)
      {
        // Ignore malformed or unrelated JSON files.
      }
    }
    return false;
  }

  /**
   * Psych stage JSONs use defaultZoom and character spawn-position arrays.
   */
  static function hasPsychStageMarkers(root:String):Bool
  {
    var path:String = Path.join([root, "stages"]);
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;

    for (fileName in FileSystem.readDirectory(path))
    {
      if (!StringTools.endsWith(fileName.toLowerCase(), ".json")) continue;
      try
      {
        var parsed:Dynamic = Json.parse(File.getContent(Path.join([path, fileName])));
        var defaultZoom:Dynamic = Reflect.field(parsed, "defaultZoom");
        var boyfriend:Dynamic = Reflect.field(parsed, "boyfriend");
        var opponent:Dynamic = Reflect.field(parsed, "opponent");
        if (defaultZoom != null && Std.isOfType(boyfriend, Array) && Std.isOfType(opponent, Array))
          return true;
      }
      catch (error:Dynamic)
      {
        // Ignore malformed or unrelated JSON files.
      }
    }
    return false;
  }

  static function isPsychChartFile(chartPath:String):Bool
  {
    try
    {
      var parsed:Dynamic = Json.parse(File.getContent(chartPath));
      var songData:Dynamic = Reflect.field(parsed, "song");
      if (songData == null) return false;

      var songName:Dynamic = Reflect.field(songData, "song");
      var notes:Dynamic = Reflect.field(songData, "notes");
      var bpm:Dynamic = Reflect.field(songData, "bpm");
      var hasSongIdentity:Bool = songName != null && Std.isOfType(songName, String);
      var hasChartContent:Bool = notes != null;
      var hasTempo:Bool = bpm != null;
      return hasSongIdentity && hasChartContent && hasTempo;
    }
    catch (error:Dynamic)
    {
      // An unrelated or malformed JSON file is not proof of a Psych mod.
      return false;
    }
  }
  #else
  static function hasPsychMarkers(modPath:String):Bool return false;
  #end
}

typedef EngineDetection =
{
  var id:String;
  var label:String;
  var version:Null<String>;
  var launchable:Bool;
  var explanation:String;
}
