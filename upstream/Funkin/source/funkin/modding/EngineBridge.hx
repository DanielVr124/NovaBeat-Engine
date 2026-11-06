package funkin.modding;

#if sys
import haxe.io.Path;
import sys.FileSystem;
#end

/**
 * Identifies the engine a package was authored for.
 *
 * NovaBeat is V-Slice-based, so V-Slice content uses the native game runtime.
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
    if (normalized.indexOf("psych") >= 0 || psychVersion != null || hasPsychMarkers(modPath))
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

    // Polymod packages without an external-engine declaration are native
    // V-Slice packages in this V-Slice-based game.
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
  static function hasPsychMarkers(modPath:String):Bool
  {
    var distinctiveFolders:Array<String> = ["custom_events", "custom_notetypes", "custom_substates"];
    for (folder in distinctiveFolders)
    {
      var path:String = Path.join([modPath, folder]);
      if (FileSystem.exists(path) && FileSystem.isDirectory(path)) return true;
    }

    var scriptsPath:String = Path.join([modPath, "scripts"]);
    if (FileSystem.exists(scriptsPath) && FileSystem.isDirectory(scriptsPath))
    {
      for (file in FileSystem.readDirectory(scriptsPath))
      {
        if (StringTools.endsWith(file.toLowerCase(), ".lua")) return true;
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
