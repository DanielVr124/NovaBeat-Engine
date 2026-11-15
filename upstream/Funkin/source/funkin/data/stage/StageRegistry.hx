package funkin.data.stage;

import funkin.play.stage.Stage;
import funkin.play.stage.ScriptedStage;
import funkin.util.tools.ISingleton;
import funkin.data.DefaultRegistryImpl;
import haxe.Json;
import openfl.Assets;

@:nullSafety
class StageRegistry extends BaseRegistry<Stage, StageData, StageEntryParams> implements ISingleton implements DefaultRegistryImpl
{
  public static final STAGE_DATA_VERSION:thx.semver.Version = '1.0.2';
  public static final STAGE_DATA_VERSION_RULE:thx.semver.VersionRule = '>=1.0.0 <1.1.0';

  public function new()
  {
    super('STAGE', 'stages', STAGE_DATA_VERSION_RULE);
  }

  /**
   * Parse both native V-Slice stage data and legacy Psych Engine stage JSON.
   * Psych uses top-level boyfriend/girlfriend/opponent positions and defaultZoom;
   * V-Slice expects characters.bf/gf/dad and cameraZoom.
   */
  override public function parseEntryDataWithMigration(id:String, version:Null<thx.semver.Version>):Null<StageData>
  {
    // Psych stage JSON has no V-Slice semantic version. Let the compatibility
    // parser inspect it instead of rejecting it before parseEntryData runs.
    if (version == null) return parseEntryData(id);
    return super.parseEntryDataWithMigration(id, version);
  }

  override public function parseEntryData(id:String):Null<StageData>
  {
    var path:String = Paths.json('stages/${id}');
    if (!Assets.exists(path))
    {
      trace('[STAGE] Missing stage data file: ' + path);
      return null;
    }
    return parseEntryDataRaw(Assets.getText(path), path);
  }

  override public function parseEntryDataRaw(contents:String, ?fileName:String):Null<StageData>
  {
    var normalized:String = contents;
    try
    {
      var raw:Dynamic = Json.parse(contents);
      if (raw != null && Reflect.hasField(raw, 'defaultZoom')
        && (Reflect.hasField(raw, 'boyfriend') || Reflect.hasField(raw, 'girlfriend') || Reflect.hasField(raw, 'opponent')))
      {
        var native:Dynamic = {
          version: STAGE_DATA_VERSION,
          name: fileName == null ? 'Psych Stage' : haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(fileName)),
          directory: Reflect.hasField(raw, 'directory') ? raw.directory : 'shared',
          cameraZoom: raw.defaultZoom,
          legacyPsychCoordinates: true,
          props: [],
          characters: {
            bf: psychCharacterPosition(raw, 'boyfriend', [-100, -100]),
            gf: psychCharacterPosition(raw, 'girlfriend', [0, 0]),
            dad: psychCharacterPosition(raw, 'opponent', [100, -100])
          }
        };
        normalized = Json.stringify(native);
        trace('[STAGE] Converted Psych Engine stage data: ' + fileName);
      }
    }
    catch (e)
    {
      trace('[STAGE] Failed to inspect stage JSON (' + fileName + '): ' + e);
      return null;
    }

    var parser = new json2object.JsonParser<StageData>();
    parser.ignoreUnknownVariables = false;
    // `normalized` is strict JSON: Psych input was parsed and re-serialized above,
    // while native input was successfully parsed by Json.parse(contents).
    // Keep the parser input normalized without calling SerializerUtil's private sanitizer.
    parser.fromJson(normalized, fileName);
    if (parser.errors.length > 0)
    {
      for (error in parser.errors) funkin.data.DataError.printError(error);
      return null;
    }
    return parser.value;
  }

  static function psychCharacterPosition(raw:Dynamic, field:String, cameraOffsets:Array<Float>):Dynamic
  {
    var position:Dynamic = Reflect.hasField(raw, field) ? Reflect.field(raw, field) : [0, 0];
    if (!Std.isOfType(position, Array) || (cast position:Array<Dynamic>).length < 2) position = [0, 0];
    return {
      zIndex: 0,
      position: position,
      scale: 1.0,
      cameraOffsets: cameraOffsets,
      scroll: [1, 1],
      alpha: 1.0,
      angle: 0.0
    };
  }
}

typedef StageEntryParams =
{
}
