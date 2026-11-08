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
    var engineValue:Dynamic = firstField([novaBeatMetadata, polymodMetadata, packageMetadata], ["engine", "engineId", "engine_id"]);
    var declaredId:Null<String> = asString(engineValue);

    if (declaredId == null && engineValue != null && !Std.isOfType(engineValue, String))
    {
      declaredId = firstString(engineValue, ["id", "name", "engineId", "engine_id"]);
    }

    var normalized:String = declaredId == null ? "" : declaredId.toLowerCase();
    var explicitlyPsych:Bool = normalized.indexOf("psych") >= 0;

    // A version-only field is treated as a Psych declaration only when its
    // key explicitly names Psych. Generic "version" fields describe the mod,
    // not necessarily the engine, and must not be mistaken for engine versions.
    var psychVersion:Null<String> = findPsychVersion(engineValue, [novaBeatMetadata, polymodMetadata, packageMetadata]);
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

  static function findPsychVersion(engineValue:Dynamic, metadataSources:Array<Dynamic>):Null<String>
  {
    // Structured engine declarations can carry their own version.
    if (engineValue != null && !Std.isOfType(engineValue, String))
    {
      var nestedVersion:Null<String> = firstString(engineValue, ["version", "engineVersion", "engine_version", "psychEngineVersion", "psych_engine_version"]);
      if (nestedVersion != null) return normalizeVersion(nestedVersion);
    }

    // String declarations may include a version, e.g. "Psych Engine v0.7.3".
    var engineText:Null<String> = asString(engineValue);
    if (engineText != null)
    {
      var parsedEngineVersion:Null<String> = extractVersion(engineText);
      if (parsedEngineVersion != null) return parsedEngineVersion;
    }

    // Accept explicit Psych-specific version keys from common package
    // metadata files. Do not consume a generic "version" (usually mod version).
    var versionFields:Array<String> = [
      "psychEngineVersion",
      "psych_engine_version",
      "psychVersion",
      "psych_version",
      "psychEngine",
      "psych_engine"
    ];
    for (source in metadataSources)
    {
      if (source == null) continue;
      var direct:Null<String> = firstString(source, versionFields);
      if (direct != null)
      {
        var parsed:Null<String> = extractVersion(direct);
        return parsed == null ? direct : parsed;
      }

      var engine:Dynamic = Reflect.field(source, "engine");
      if (engine != null && !Std.isOfType(engine, String))
      {
        var nested:Null<String> = firstString(engine, ["version", "engineVersion", "engine_version", "psychEngineVersion", "psych_engine_version"]);
        if (nested != null) return normalizeVersion(nested);
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

    return hasPsychChartMarkers(root);
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
      var hasTempo:Bool = bpm != null && Std.isOfType(bpm, Float);
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
