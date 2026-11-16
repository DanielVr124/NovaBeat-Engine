package funkin.modding.psychlua;

import funkin.util.FileUtil;
import sys.FileSystem;

/**
 * Psych's achievement API, backed by a local JSON file.
 *
 * Psych keeps achievements in a save file that other mods read through
 * getAchievementScore and friends. This engine has no achievement system at
 * all, so the same functions are implemented against a small file next to the
 * executable. Scores survive restarts and stay per-achievement, which is what
 * scripts actually rely on.
 *
 * Nothing here unlocks OS-level achievements or talks to Newgrounds: there is
 * no platform to report to on desktop builds.
 */
class PsychAchievements
{
  /** Where achievement state lives, relative to the game directory. */
  static final STORAGE_FILE:String = "psych-achievements.json";

  static var entries:Null<Map<String, AchievementEntry>> = null;

  /** Cached set of achievement ids declared by installed mods. */
  static var declaredIds:Null<Map<String, Bool>> = null;

  static function storagePath():String
  {
    return FileUtil.get_gameDirectory() + STORAGE_FILE;
  }

  static function store():Map<String, AchievementEntry>
  {
    if (entries != null) return entries;

    var loaded:Map<String, AchievementEntry> = [];
    #if sys
    try
    {
      if (FileSystem.exists(storagePath()))
      {
        var parsed:Dynamic = FileUtil.readJSONFromPath(storagePath());
        if (parsed != null)
        {
          for (id in Reflect.fields(parsed))
          {
            var raw:Dynamic = Reflect.field(parsed, id);
            if (raw == null) continue;
            loaded.set(id, {
              unlocked: Reflect.field(raw, "unlocked") == true,
              score: readNumber(Reflect.field(raw, "score"), 0)
            });
          }
        }
      }
    }
    catch (error:Dynamic)
    {
      trace('[Psych Achievements] Could not read ' + storagePath() + ': ' + Std.string(error));
      loaded = [];
    }
    #end

    return entries = loaded;
  }

  static function flush():Void
  {
    #if sys
    try
    {
      var plain:Dynamic = {};
      var all:Map<String, AchievementEntry> = store();
      for (id in all.keys())
      {
        var entry:Null<AchievementEntry> = all.get(id);
        if (entry == null) continue;
        Reflect.setField(plain, id, {unlocked: entry.unlocked, score: entry.score});
      }
      sys.io.File.saveContent(storagePath(), haxe.Json.stringify(plain));
    }
    catch (error:Dynamic)
    {
      trace('[Psych Achievements] Could not write ' + storagePath() + ': ' + Std.string(error));
    }
    #end
  }

  static function entryFor(id:String):AchievementEntry
  {
    var all:Map<String, AchievementEntry> = store();
    var existing:Null<AchievementEntry> = all.get(id);
    if (existing != null) return existing;

    var created:AchievementEntry = {unlocked: false, score: 0};
    all.set(id, created);
    return created;
  }

  /**
   * True when some installed mod declares this achievement under
   * mods/&lt;mod&gt;/achievements/&lt;id&gt;.json, or when it has already been
   * unlocked locally.
   */
  public static function exists(id:String):Bool
  {
    if (id == null || id.length == 0) return false;
    if (entryFor(id).unlocked) return true;
    return declaredAchievements().exists(id);
  }

  /** Ids declared by installed mods, scanned once and cached. */
  static function declaredAchievements():Map<String, Bool>
  {
    if (declaredIds != null) return declaredIds;

    var scanned:Map<String, Bool> = [];
    #if sys
    for (modRoot in modDirectories())
    {
      var folder:String = modRoot + "achievements/";
      if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;
      for (file in FileSystem.readDirectory(folder))
      {
        if (!StringTools.endsWith(file.toLowerCase(), ".json")) continue;
        scanned.set(file.substr(0, file.length - 5), true);
      }
    }
    #end

    return declaredIds = scanned;
  }

  #if sys
  /** Candidate mod roots, in the same order the loader searches them. */
  static function modDirectories():Array<String>
  {
    var roots:Array<String> = [];
    try
    {
      var base:String = FileUtil.get_gameDirectory() + "mods/";
      if (FileSystem.exists(base) && FileSystem.isDirectory(base))
      {
        for (name in FileSystem.readDirectory(base))
        {
          var path:String = base + name + "/";
          if (FileSystem.isDirectory(path)) roots.push(path);
        }
      }
    }
    catch (error:Dynamic) {}
    return roots;
  }
  #end

  public static function isUnlocked(id:String):Bool
  {
    if (id == null || id.length == 0) return false;
    return entryFor(id).unlocked;
  }

  /** Returns false when the id is unknown or was already unlocked. */
  public static function unlock(id:String):Bool
  {
    if (!exists(id)) return false;
    var entry:AchievementEntry = entryFor(id);
    if (entry.unlocked) return false;

    entry.unlocked = true;
    flush();
    trace('[Psych Achievements] Unlocked ' + id);
    return true;
  }

  public static function getScore(id:String):Int
  {
    if (id == null || id.length == 0) return 0;
    return Std.int(entryFor(id).score);
  }

  public static function setScore(id:String, score:Int):Bool
  {
    if (id == null || id.length == 0) return false;
    entryFor(id).score = score;
    flush();
    return true;
  }

  public static function addScore(id:String, delta:Int):Bool
  {
    if (id == null || id.length == 0) return false;
    var entry:AchievementEntry = entryFor(id);
    entry.score += delta;
    flush();
    return true;
  }

  static function readNumber(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;
    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? fallback : parsed;
  }
}

/** One achievement's local state. */
typedef AchievementEntry =
{
  var unlocked:Bool;
  var score:Float;
}
