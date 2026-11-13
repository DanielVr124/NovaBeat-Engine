package funkin.modding;

#if sys
import haxe.Json;
import haxe.io.Path;
import polymod.fs.ZipFileSystem.ZipFileSystemParams;

/**
 * Lets classic Psych packages participate in Polymod's OpenFL asset library
 * without requiring users to add a V-Slice/Polymod manifest to their mod.
 *
 * Psych packages commonly use pack.json and are discovered by NovaBeat's
 * experience scanner. Polymod itself only mounts a mod when its filesystem
 * can find _polymod_meta.json, so this filesystem supplies a virtual manifest
 * for recognized Psych package roots while leaving the package on disk intact.
 */
class PsychAwareZipFileSystem extends polymod.fs.SysZipFileSystem
{
  public function new(params:ZipFileSystemParams)
  {
    super(params);
  }

  override public function exists(path:String):Bool
  {
    if (super.exists(path)) return true;
    return getSyntheticPsychMetadata(path) != null;
  }

  override public function getFileContent(path:String):Null<String>
  {
    if (super.exists(path)) return super.getFileContent(path);
    return getSyntheticPsychMetadata(path);
  }

  static function getSyntheticPsychMetadata(path:String):Null<String>
  {
    if (path == null || Path.withoutDirectory(path).toLowerCase() != "_polymod_meta.json")
      return null;

    var modPath:String = Path.directory(path);
    if (modPath == null || modPath.length == 0 || modPath == "."
      || !PsychModRuntime.isPsychDirectory(modPath))
      return null;

    var directory:String = Path.withoutDirectory(modPath);
    if (directory == null || directory.length == 0) return null;

    // Polymod validates these two SemVer fields before it mounts a package.
    // Use NovaBeat's current mod API version, and a neutral synthetic package
    // version; the original Psych pack.json remains untouched.
    var metadata:Dynamic = {
      id: directory,
      title: directory,
      description: "Psych Engine content mounted by NovaBeat",
      author: "Unknown",
      api_version: PolymodHandler.API_VERSION,
      mod_version: "1.0.0"
    };
    trace('[Psych Compatibility] Providing virtual Polymod metadata for asset mounting: ' + modPath);
    return Json.stringify(metadata);
  }
}
#end
