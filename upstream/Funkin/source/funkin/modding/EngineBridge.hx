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

  public static function detectEngine(modPath:String, polymodMetadata:Dynamic, novaBeatMetadata:Dynamic):EngineDetection
  {
    var engineValue:Dynamic = novaBeatMetadata == null ? null : Reflect.field(novaBeatMetadata, "engine");
    if (engineValue == null && polymodMetadata != null) engineValue = Reflect.field(polymodMetadata, "engine");

    var declaredId:Null<String> = asString(engineValue);
    if (declaredId == null && engineValue != null && !Std.isOfType(engineValue, String))
      declaredId = asString(Reflect.field(engineValue, "id"));
    if (declaredId == null && novaBeatMetadata != null)
      declaredId = asString(Reflect.field(novaBeatMetadata, "engineId"));

    var version:Null<String> = null;
    if (engineValue != null && !Std.isOfType(engineValue, String))
      version = asString(Reflect.field(engineValue, "version"));
    if (version == null && novaBeatMetadata != null)
      version = asString(Reflect.field(novaBeatMetadata, "engineVersion"));
    if (version == null && polymodMetadata != null)
      version = asString(Reflect.field(polymodMetadata, "psychEngineVersion"));

    var normalized:String = declaredId == null ? "" : declaredId.toLowerCase();
    var psychVersion:Null<String> = polymodMetadata == null ? null : asString(Reflect.field(polymodMetadata, "psychEngineVersion"));

    if (normalized.indexOf("psych") >= 0 || psychVersion != null)
    {
      if (version == null) version = psychVersion;
      return {
        id: ENGINE_PSYCH,
        label: version == null ? "Psych Engine" : "Psych Engine " + version,
        version: version,
        launchable: false,
        explanation: "Psych Engine was detected. A compatible Psych runtime is not available in this NovaBeat build yet."
      };
    }

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

    if (hasPsychMarkers(modPath))
    {
      return {
        id: ENGINE_PSYCH,
        label: version == null ? "Psych Engine" : "Psych Engine " + version,
        version: version,
        launchable: false,
        explanation: "Psych-specific files were detected. A compatible Psych runtime is not available in this NovaBeat build yet."
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
   * Detect the folder conventions used by official Psych Engine mods.
   *
   * Do not treat a generic "data" or "scripts" folder as sufficient on its
   * own. We look for Psych-specific script locations or a Psych chart JSON
   * shape to avoid misclassifying ordinary V-Slice/Polymod packages.
   */
  static function hasPsychMarkers(modPath:String):Bool
  {
    var distinctiveFolders:Array<String> = ["custom_events", "custom_notetypes", "custom_substates"];
    for (folder in distinctiveFolders)
    {
      var path:String = Path.join([modPath, folder]);
      if (FileSystem.exists(path) && FileSystem.isDirectory(path)) return true;
    }

    // Psych supports scripts globally and beside data, stage, and character
    // content. Search only these known roots and keep the traversal shallow.
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
      if (containsPsychScript(Path.join([modPath, folder]), 3)) return true;
    }

    return hasPsychChartMarkers(modPath);
  }

  /**
   * Looks for Lua/HScript files in a known Psych script root. The depth cap
   * keeps discovery quick even when a mod includes large asset directories.
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
   * Scriptless Psych mods still use the characteristic chart envelope:
   * { "song": { "song": "...", "notes": [...], ... } }.
   */
  static function hasPsychChartMarkers(modPath:String):Bool
  {
    var dataPath:String = Path.join([modPath, "data"]);
    if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) return false;

    for (songFolder in FileSystem.readDirectory(dataPath))
    {
      if (songFolder.length == 0 || songFolder.charAt(0) == ".") continue;
      var songPath:String = Path.join([dataPath, songFolder]);
      if (!FileSystem.exists(songPath) || !FileSystem.isDirectory(songPath)) continue;

      for (fileName in FileSystem.readDirectory(songPath))
      {
        if (!StringTools.endsWith(fileName.toLowerCase(), ".json")) continue;
        var chartPath:String = Path.join([songPath, fileName]);
        try
        {
          var parsed:Dynamic = Json.parse(File.getContent(chartPath));
          var songData:Dynamic = Reflect.field(parsed, "song");
          if (songData != null && Reflect.field(songData, "notes") != null) return true;
        }
        catch (error:Dynamic)
        {
          // An unrelated or malformed JSON file is not proof of a Psych mod.
        }
      }
    }

    return false;
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
