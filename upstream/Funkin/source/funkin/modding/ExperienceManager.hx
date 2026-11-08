package funkin.modding;

import funkin.data.song.SongRegistry;
import funkin.modding.EngineBridge.EngineDetection;
import funkin.modding.PsychModRuntime;
import funkin.save.Save;
import funkin.ui.freeplay.charselect.PlayableCharacter;

#if sys
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Discovers installed experiences and activates one native V-Slice package set.
 * Package classification and extension assignments are stored by NovaBeat;
 * they never rewrite an installed mod's files.
 */
class ExperienceManager
{
  public static inline final OFFICIAL_EXPERIENCE_ID:String = "friday-night-funkin";
  public static inline final PACKAGE_STANDALONE:String = "standalone";
  public static inline final PACKAGE_EXTENSION:String = "extension";
  public static inline final PACKAGE_UNCLASSIFIED:String = "unclassified";

  static var activeExperienceId:String = OFFICIAL_EXPERIENCE_ID;
  static var activeSongIds:Array<String> = [];
  static var activePsychSongIds:Array<String> = [];
  static var activePsychModDirs:Array<String> = [];

  public static function scanInstalled():Array<ExperienceInfo>
  {
    var result:Array<ExperienceInfo> = [];
    result.push({
      id: OFFICIAL_EXPERIENCE_ID,
      directory: null,
      title: "Friday Night Funkin'",
      description: "The original Friday Night Funkin' experience.",
      author: "The Funkin' Crew",
      engineId: EngineBridge.ENGINE_VSLICE,
      engineLabel: "V-Slice",
      engineVersion: null,
      packageType: PACKAGE_STANDALONE,
      ownerId: OFFICIAL_EXPERIENCE_ID,
      enabled: true,
      iconPath: null,
      isOfficial: true,
      launchable: true,
      explanation: "NovaBeat's native game content."
    });

    #if sys
    var root:String = PolymodHandler.getModRoot();
    if (!FileSystem.exists(root)) PolymodHandler.createModRoot();

    var directories:Array<String> = PolymodHandler.getAllInstalledModDirs();
    directories.sort(Reflect.compare);

    for (directory in directories)
    {
      var modPath:String = Path.join([root, directory]);
      var polymodMetadata:Dynamic = readJson(Path.join([modPath, "_polymod_meta.json"]));
      var novaBeatMetadata:Dynamic = readJson(Path.join([modPath, "_novabeat.json"]));
      // Keep each metadata source separate so an engine declaration in
      // meta.json/pack.json is still visible when Polymod metadata also exists.
      var packageMetadata:Dynamic = readJson(Path.join([modPath, "meta.json"]));
      if (packageMetadata == null) packageMetadata = readJson(Path.join([modPath, "pack.json"]));

      var genericMetadata:Dynamic = polymodMetadata;
      if (genericMetadata == null) genericMetadata = novaBeatMetadata;
      if (genericMetadata == null) genericMetadata = packageMetadata;

      var engine:EngineDetection = EngineBridge.detectEngine(modPath, polymodMetadata, novaBeatMetadata, packageMetadata);
      var psychAssessment:Null<PsychPackageAssessment> = engine.id == EngineBridge.ENGINE_PSYCH
        ? PsychModRuntime.inspectPackage(modPath)
        : null;
      var packageLaunchable:Bool = engine.launchable || (psychAssessment != null && psychAssessment.launchable);
      var packageExplanation:String = psychAssessment == null ? engine.explanation : psychAssessment.explanation;
      var displayEngineLabel:String = psychAssessment != null && psychAssessment.launchable
        ? engine.label + " • LEGACY CHARTS"
        : engine.label;
      var packageType:String = resolvePackageType(directory, engine, novaBeatMetadata);
      var enabledDirs:Array<String> = Save.instance.enabledModDirs.value;
      var title:Null<String> = metadataString(genericMetadata, "title");
      if (title == null) title = metadataString(genericMetadata, "name");
      if (title == null) title = directory;

      var description:Null<String> = metadataString(genericMetadata, "description");
      if (description == null) description = "Installed mod package. No description was provided.";

      var author:Null<String> = metadataString(genericMetadata, "author");
      if (author == null) author = "Unknown author";

      result.push({
        id: directory,
        directory: directory,
        title: title,
        description: description,
        author: author,
        engineId: engine.id,
        engineLabel: displayEngineLabel,
        engineVersion: engine.version,
        packageType: packageType,
        ownerId: packageType == PACKAGE_EXTENSION ? getExtensionOwner(directory) : directory,
        enabled: enabledDirs != null && enabledDirs.indexOf(directory) >= 0,
        iconPath: findIcon(modPath),
        isOfficial: false,
        launchable: packageLaunchable,
        explanation: packageExplanation
      });
    }
    #end

    return result;
  }

  public static function getSavedExperienceId():String
  {
    var saved:Null<String> = Save.instance.activeExperienceId.value;
    return saved == null || saved.length == 0 ? OFFICIAL_EXPERIENCE_ID : saved;
  }

  public static function getActiveExperienceId():String return activeExperienceId;

  public static function getActiveSongIds():Array<String> return activeSongIds.copy();

  public static function getActivePsychSongIds():Array<String> return activePsychSongIds.copy();

  public static function getActivePsychModDirs():Array<String> return activePsychModDirs.copy();

  public static function setPackageEnabled(info:ExperienceInfo):Bool
  {
    if (info == null || info.isOfficial || info.directory == null) return true;
    var enabledDirs:Array<String> = Save.instance.enabledModDirs.value.copy();
    var index:Int = enabledDirs.indexOf(info.directory);
    var enabled:Bool = index < 0;
    if (enabled)
      enabledDirs.push(info.directory);
    else
      enabledDirs.splice(index, 1);
    Save.instance.enabledModDirs.value = enabledDirs;
    Save.system.flush();
    return enabled;
  }

  public static function cyclePackageType(info:ExperienceInfo):String
  {
    if (info == null || info.isOfficial || info.directory == null) return PACKAGE_STANDALONE;

    var next:String = switch (info.packageType)
    {
      case PACKAGE_STANDALONE: PACKAGE_EXTENSION;
      case PACKAGE_EXTENSION: PACKAGE_UNCLASSIFIED;
      default: PACKAGE_STANDALONE;
    };

    var map:Map<String, String> = copyStringMap(Save.instance.modPackageKinds.value);
    map.set(info.directory, next);
    Save.instance.modPackageKinds.value = map;
    Save.system.flush();
    return next;
  }

  public static function cycleExtensionOwner(info:ExperienceInfo, experiences:Array<ExperienceInfo>):String
  {
    if (info == null || info.directory == null) return OFFICIAL_EXPERIENCE_ID;

    var choices:Array<String> = [OFFICIAL_EXPERIENCE_ID];
    for (experience in experiences)
    {
      if (experience.isOfficial || experience.packageType != PACKAGE_STANDALONE || !experience.launchable) continue;
      choices.push(experience.id);
    }

    var current:String = getExtensionOwner(info.directory);
    var index:Int = choices.indexOf(current);
    var next:String = choices[(index + 1 + choices.length) % choices.length];

    var map:Map<String, String> = copyStringMap(Save.instance.modExtensionOwners.value);
    map.set(info.directory, next);
    Save.instance.modExtensionOwners.value = map;
    Save.system.flush();
    return next;
  }

  public static function getExtensionOwner(directory:String):String
  {
    var map:Map<String, String> = Save.instance.modExtensionOwners.value;
    var value:Null<String> = map == null ? null : map.get(directory);
    return value == null || value.length == 0 ? OFFICIAL_EXPERIENCE_ID : value;
  }

  public static function experienceTitle(ownerId:String, experiences:Array<ExperienceInfo>):String
  {
    if (ownerId == OFFICIAL_EXPERIENCE_ID) return "Friday Night Funkin'";
    for (experience in experiences)
    {
      if (experience.id == ownerId) return experience.title;
    }
    return ownerId;
  }

  /**
   * Activates the selected standalone package and its assigned extensions.
   * Returns null on success or a player-facing explanation on failure.
   */
  public static function activate(info:ExperienceInfo):Null<String>
  {
    if (info == null) return "No experience was selected.";
    if (!info.isOfficial && info.packageType == PACKAGE_EXTENSION)
    {
      return "This is a content extension. Launch the experience it is assigned to instead.";
    }
    if (!info.isOfficial && !info.enabled)
    {
      return "This package is disabled. Press E to enable it before launching.";
    }
    if (!info.isOfficial && info.packageType == PACKAGE_UNCLASSIFIED)
    {
      return "This mod is not classified yet. Press TAB to choose Standalone or Content Extension.";
    }
    if (!info.isOfficial && !EngineBridge.canLaunch(info.engineId) && !info.launchable)
    {
      return info.explanation;
    }

    var ownerId:String = info.isOfficial ? OFFICIAL_EXPERIENCE_ID : info.id;
    var modDirs:Array<String> = getModDirsForExperience(info);
    var songIds:Array<String> = collectSongIds(modDirs);
    var psychDirs:Array<String> = ownerId == OFFICIAL_EXPERIENCE_ID ? [] : getLaunchablePsychModDirs(modDirs);
    var psychSongIds:Array<String> = PsychModRuntime.collectSongIds(psychDirs);

    if (ownerId != OFFICIAL_EXPERIENCE_ID && songIds.length == 0)
    {
      return "No playable songs were found. Psych support currently requires classic chart files and an instrumental; script-dependent mods are not supported yet.";
    }

    // Make the selected ownership context visible before registries and scripts
    // reload, so any initialization hooks query the correct experience.
    activeExperienceId = ownerId;
    activeSongIds = ownerId == OFFICIAL_EXPERIENCE_ID ? [] : songIds;
    activePsychSongIds = ownerId == OFFICIAL_EXPERIENCE_ID ? [] : psychSongIds;
    activePsychModDirs = psychDirs;

    Save.instance.activeExperienceId.value = ownerId;
    Save.system.flush();

    // Reload only after the active ownership context is established.
    PolymodHandler.forceReloadAssets(modDirs);
    return null;
  }

  public static function isSongAvailable(songId:String):Bool
  {
    if (activeExperienceId == OFFICIAL_EXPERIENCE_ID) return true;
    return activeSongIds.indexOf(songId) >= 0;
  }

  public static function shouldShowPlayer(player:PlayableCharacter):Bool
  {
    if (player == null || activeExperienceId == OFFICIAL_EXPERIENCE_ID) return true;

    for (songId in activeSongIds)
    {
      var song = SongRegistry.instance.fetchEntry(songId);
      if (song == null) continue;
      if (song.getVariationsByCharacter(player).length > 0) return true;
    }

    return false;
  }

  static function getModDirsForExperience(info:ExperienceInfo):Array<String>
  {
    var ownerId:String = info.isOfficial ? OFFICIAL_EXPERIENCE_ID : info.id;
    var result:Array<String> = [];

    for (candidate in scanInstalled())
    {
      if (candidate.isOfficial || candidate.directory == null || !candidate.enabled || !candidate.launchable) continue;

      var isSelectedExperience:Bool = !info.isOfficial
        && candidate.id == ownerId
        && candidate.packageType == PACKAGE_STANDALONE;
      var isAssignedExtension:Bool = candidate.packageType == PACKAGE_EXTENSION
        && getExtensionOwner(candidate.directory) == ownerId;

      if ((isSelectedExperience || isAssignedExtension) && result.indexOf(candidate.directory) == -1)
        result.push(candidate.directory);
    }

    // Keep the same relative load priority the player configured in the Mod
    // Manager, but only among packages belonging to the active experience.
    var configuredOrder:Array<String> = Save.instance.enabledModDirs.value;
    result.sort(function(a:String, b:String):Int
    {
      var aIndex:Int = configuredOrder.indexOf(a);
      var bIndex:Int = configuredOrder.indexOf(b);
      if (aIndex >= 0 && bIndex >= 0) return aIndex - bIndex;
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      return Reflect.compare(a, b);
    });

    return result;
  }

  static function collectSongIds(modDirs:Array<String>):Array<String>
  {
    var result:Array<String> = [];
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var songsPath:String = Path.join([root, directory, "data", "songs"]);
      if (!FileSystem.exists(songsPath) || !FileSystem.isDirectory(songsPath)) continue;

      for (songFolder in FileSystem.readDirectory(songsPath))
      {
        var songPath:String = Path.join([songsPath, songFolder]);
        if (FileSystem.isDirectory(songPath) && result.indexOf(songFolder) == -1)
          result.push(songFolder);
      }
    }
    #end

    for (songId in PsychModRuntime.collectSongIds(modDirs))
    {
      if (result.indexOf(songId) == -1) result.push(songId);
    }

    return result;
  }

  static function getLaunchablePsychModDirs(modDirs:Array<String>):Array<String>
  {
    var result:Array<String> = [];
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (PsychModRuntime.isPsychDirectory(modPath) && PsychModRuntime.inspectPackage(modPath).launchable)
        result.push(directory);
    }
    #end
    return result;
  }

  static function resolvePackageType(directory:String, engine:EngineDetection, metadata:Dynamic):String
  {
    var stored:Map<String, String> = Save.instance.modPackageKinds.value;
    if (stored != null)
    {
      var saved:Null<String> = stored.get(directory);
      if (saved != null) return normalizePackageType(saved);
    }

    var packageData:Dynamic = metadata == null ? null : Reflect.field(metadata, "package");
    var declared:Null<String> = metadataString(packageData, "type");
    if (declared == null) declared = metadataString(metadata, "packageType");
    if (declared != null) return normalizePackageType(declared);

    // V-Slice packages are treated as extensions by default. External engines
    // remain unclassified until the player or a recognized manifest decides.
    return engine.id == EngineBridge.ENGINE_VSLICE ? PACKAGE_EXTENSION : PACKAGE_UNCLASSIFIED;
  }

  static function normalizePackageType(value:String):String
  {
    return switch (value.toLowerCase())
    {
      case "standalone", "standalone-experience": PACKAGE_STANDALONE;
      case "extension", "content-extension", "addon", "add-on": PACKAGE_EXTENSION;
      default: PACKAGE_UNCLASSIFIED;
    }
  }

  static function copyStringMap(source:Map<String, String>):Map<String, String>
  {
    var result:Map<String, String> = [];
    if (source != null)
      for (key in source.keys()) result.set(key, source.get(key));
    return result;
  }

  #if sys
  static function readJson(path:String):Dynamic
  {
    if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) return null;
    try
    {
      return Json.parse(File.getContent(path));
    }
    catch (error:Dynamic)
    {
      trace("Could not read mod metadata at " + path + ": " + Std.string(error));
      return null;
    }
  }

  static function metadataString(metadata:Dynamic, key:String):Null<String>
  {
    if (metadata == null) return null;
    var value:Dynamic = Reflect.field(metadata, key);
    if (value == null || !Std.isOfType(value, String)) return null;
    var text:String = cast value;
    return text.length == 0 ? null : text;
  }

  static function findIcon(modPath:String):Null<String>
  {
    var candidates:Array<String> = ["_polymod_icon.png", "icon.png", "modIcon.png", "images/icon.png"];
    for (candidate in candidates)
    {
      var path:String = Path.join([modPath, candidate]);
      if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return path;
    }
    return null;
  }
  #else
  static function metadataString(metadata:Dynamic, key:String):Null<String>
  {
    if (metadata == null) return null;
    var value:Dynamic = Reflect.field(metadata, key);
    return value != null && Std.isOfType(value, String) ? cast value : null;
  }
  #end
}

typedef ExperienceInfo =
{
  var id:String;
  var directory:Null<String>;
  var title:String;
  var description:String;
  var author:String;
  var engineId:String;
  var engineLabel:String;
  var engineVersion:Null<String>;
  var packageType:String;
  var ownerId:String;
  var enabled:Bool;
  var iconPath:Null<String>;
  var isOfficial:Bool;
  var launchable:Bool;
  var explanation:String;
}
