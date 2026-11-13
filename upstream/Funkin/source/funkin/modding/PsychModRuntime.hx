package funkin.modding;

import funkin.Assets;
import funkin.util.FileUtil;
import flixel.FlxG;
import funkin.modding.psychlua.PsychScriptRuntime;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.character.CharacterData.CharacterData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.data.song.importer.FNFLegacyData;
import funkin.data.song.importer.FNFLegacyImporter;
import funkin.play.song.Song;
import funkin.play.PlayState;
import haxe.Json;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Runtime bridge for Psych Engine packages.
 *
 * It supports classic psych_v1 charts in data/<song>/ and songs/<song>/, plus
 * the bounded strumline-based psych_v2 chart subset that maps safely onto
 * NovaBeat's two four-key gameplay lanes. Song-local scripts and assets are
 * resolved from either package layout. Unsupported mechanics are rejected
 * with a specific reason rather than silently discarded.
 */
@:nullSafety(Off)
class PsychModRuntime
{
  static final audioPaths:Map<String, String> = [];
  static final songDataFolders:Map<String, String> = [];
  static final psychSongStageNames:Map<String, String> = [];
  static final psychSongModRoots:Map<String, String> = [];
  static final psychSongStagePositions:Map<String, Map<String, Array<Float>>> = [];
  static final psychStageBaselines:Map<String, Dynamic> = [];
  static var psychWeekIds:Array<String> = [];
  static var psychFreeplayColors:Map<String, Int> = [];
  static var psychFreeplayIcons:Map<String, String> = [];
  static var psychFreeplaySongOrder:Array<String> = [];
  // Paths lookups can happen before PlayState.instance is assigned during song construction.
  // Retain the active imported-song context from the launch logger for those early lookups.
  static var lastLaunchSongId:Null<String> = null;
  static var lastLaunchDifficulty:String = 'normal';

  /**
   * Normalize image names supplied by Psych JSON/Lua before passing them to
   * NovaBeat's Paths helpers. Psych mods store images under <mod>/images/,
   * while Paths.image/getSparrowAtlas already add the images/ prefix.
   * This is shared by character JSON registration and the Psych Lua sprite API.
   *
   * Accept common explicit forms such as "images/foo.png" and
   * "assets/images/foo.png", but reject absolute paths and traversal.
   */
  public static function normalizePsychImageKey(requestedPath:String):String
  {
    if (requestedPath == null) return "";
    var result:String = StringTools.trim(StringTools.replace(requestedPath, "\\", "/"));
    if (result.length == 0 || StringTools.startsWith(result, "/")
      || (result.length > 1 && result.charAt(1) == ":")) return "";

    while (StringTools.startsWith(result.toLowerCase(), "assets/"))
      result = result.substr("assets/".length);
    while (StringTools.startsWith(result.toLowerCase(), "images/"))
      result = result.substr("images/".length);

    for (part in result.split("/"))
      if (part == "." || part == ".." || part.length == 0) return "";

    var slash:Int = result.lastIndexOf("/");
    var dot:Int = result.lastIndexOf(".");
    if (dot > slash)
    {
      var extension:String = result.substr(dot + 1).toLowerCase();
      if (["png", "jpg", "jpeg", "webp", "bmp"].indexOf(extension) >= 0)
        result = result.substr(0, dot);
    }
    return result;
  }

  public static function inspectPackage(modPath:String):PsychPackageAssessment
  {
    #if sys
    if (!FileSystem.exists(modPath) || !FileSystem.isDirectory(modPath))
      return unavailable("The Psych mod folder could not be read.");

    modPath = resolvePsychContentRoot(modPath);
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

      var embeddedEventSignature:Null<String> = null;
      for (chartPath in source.chartFiles)
      {
        var chartProblem:Null<String> = inspectUnsupportedChartFeatures(chartPath, modPath);
        if (chartProblem != null)
        {
          return unavailable("This Psych package contains a chart feature NovaBeat does not support yet: " + chartProblem);
        }

        // V-Slice stores one event timeline per song, not one per difficulty.
        // Refuse different embedded timelines rather than accidentally mixing
        // or replaying a difficulty's events on every other chart.
        try
        {
          var chartRoot:Dynamic = Json.parse(File.getContent(chartPath));
          var chartSong:Dynamic = getPsychChartDataRoot(chartRoot);
          var rawEvents:Dynamic = Reflect.field(chartSong, "events");
          if (rawEvents == null) rawEvents = Reflect.field(chartRoot, "events");
          var normalizedEvents:Array<Dynamic> = [];
          for (event in extractPsychEvents(rawEvents))
          {
            normalizedEvents.push({
              time: event.time,
              name: event.name,
              value1: event.value1,
              value2: event.value2
            });
          }
          var signature:String = Json.stringify(normalizedEvents);
          if (embeddedEventSignature == null)
            embeddedEventSignature = signature;
          else if (embeddedEventSignature != signature)
            return unavailable("This package has different embedded event timelines for multiple difficulties. NovaBeat's current song data model uses one shared event timeline, so it cannot safely load these charts together yet.");
        }
        catch (error:Dynamic)
        {
          return unavailable("A chart's embedded Psych events could not be compared safely (" + Std.string(error) + ").");
        }
      }

      var eventFiles:Array<String> = findPsychEventsFiles(source.dataPath);
      var hasDifficultyEvents:Bool = false;
      for (eventsPath in eventFiles)
      {
        var eventFileName:String = Path.withoutExtension(Path.withoutDirectory(eventsPath)).toLowerCase();
        if (StringTools.startsWith(eventFileName, "events-")) hasDifficultyEvents = true;
        var externalEventsProblem:Null<String> = inspectUnsupportedEventFile(eventsPath, modPath);
        if (externalEventsProblem != null)
          return unavailable("This Psych package contains event data NovaBeat cannot safely load yet: " + externalEventsProblem);
      }
      if (hasDifficultyEvents && source.chartFiles.length > 1)
        return unavailable("This package has separate events-<difficulty>.json files for multiple charts. NovaBeat's current song data model uses one shared event timeline, so this package needs difficulty-aware event storage before it can be launched safely.");
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
        explanation: "Psych charts were found, but this package contains custom_notes/ scripts. That legacy custom-note system is not supported yet, so the package is kept unavailable rather than launched with missing behavior."
      };
    }

    var supportedSongs:Int = playableCount + songScriptCount;
    if (supportedSongs == 0)
    {
      return {
        launchable: false,
        supportedSongCount: 0,
        explanation: "Psych Engine detected, but no complete song package was found. NovaBeat checks psych_v1 charts in data/<song>/ or songs/<song>/ and psych_v2 chart-*.json files in songs/<song>/, together with a matching Inst audio file."
      };
    }

    var hasBasicScripts:Bool = globalScriptCount > 0 || songScriptCount > 0;
    return {
      launchable: true,
      supportedSongCount: supportedSongs,
      explanation: hasBasicScripts
        ? "Experimental Psych compatibility: " + Std.string(supportedSongs) + " song(s) were found in classic or song-package layouts. Global, song-local, stage, character, event, and note-type Lua/HScript scripts load through NovaBeat's bounded compatibility API. Additional strumlines, variable key counts, mid-song scroll-velocity changes, and unsupported native extensions remain unavailable. Native builds only."
        : "Limited Psych chart compatibility: " + Std.string(supportedSongs) + " song(s) were found in classic or song-package layouts and can launch with compatible chart features. Lua/HScript global and song-local script loading is available on native builds."
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
      modPath = resolvePsychContentRoot(modPath);
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
    audioPaths.clear();
    songDataFolders.clear();
    psychSongStageNames.clear();
    psychSongModRoots.clear();
    psychSongStagePositions.clear();

    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;
      modPath = resolvePsychContentRoot(modPath);

      var assessment:PsychPackageAssessment = inspectPackage(modPath);
      if (!assessment.launchable) continue;

      for (source in scanSongSources(modPath))
      {
        if (source.instrumentFile == null || source.chartFiles.length == 0) continue;

        if (source.audioPath == null) continue;
        var songId:String = buildSongId(directory, source.songFolder);
        try
        {
          var song:Null<Song> = buildNativeSong(songId, source);
          if (song == null) continue;

          audioPaths.set(songId, Path.normalize(FileSystem.fullPath(source.audioPath)));
          songDataFolders.set(songId, source.dataPath);
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


  /**
   * Persist the last reached phase of an imported Psych song launch.
   * This file log is separate from trace output and creates the logs folder
   * automatically on the first write on native targets. Writes are synchronous
   * so the final recorded phase survives an abrupt native process exit.
   */
  public static function logSongLaunchStep(songId:String, difficulty:String, phase:String, ?details:String = ""):Void
  {
    #if sys
    if (!isImportedSong(songId)) return;

    lastLaunchSongId = songId;
    lastLaunchDifficulty = difficulty;

    var cleanDetails:String = details == null ? "" : StringTools.replace(StringTools.replace(details, "\n", " "), "\r", " ");
    var line:String = Date.now().toString() + " | " + songId + " | " + difficulty + " | " + phase;
    if (cleanDetails.length > 0) line += " | " + cleanDetails;

    try
    {
      FileUtil.appendStringToPath("logs/psych-song-launch.log", line + "\n");
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not write launch diagnostic: ' + Std.string(error));
    }
    #end
  }

  /**
   * Write image/atlas resolution details into the same persistent log used by
   * imported Psych song launch diagnostics. This is intentionally separate
   * from trace(), which is not included in psych-song-launch.log.
   */
  public static function logAssetResolution(request:String, assetType:String, checks:Array<String>, resolvedPath:String):Void
  {
    #if sys
    var playState:Null<PlayState> = PlayState.instance;
    var songId:Null<String> = playState != null && playState.currentSong != null
      ? playState.currentSong.id
      : lastLaunchSongId;
    if (songId == null || !isImportedSong(songId)) return;

    var difficulty:String = playState != null ? playState.currentDifficulty : lastLaunchDifficulty;
    var details:String = "type=" + assetType
      + " request=" + request
      + " checks=[" + checks.join(" | ") + "]"
      + " resolved=" + resolvedPath;
    logSongLaunchStep(songId, difficulty, "asset.resolve", details);
    #end
  }

  /** Return songs in the same week-file order used by classic Psych Freeplay. */
  public static function getPsychFreeplaySongOrder():Array<String>
  {
    return psychFreeplaySongOrder.copy();
  }

  /** Return the Psych week color for a song, or the classic purple default. */
  public static function getPsychFreeplayColor(songId:String):Int
  {
    return psychFreeplayColors.get(songId) ?? 0xFF9271FD;
  }

  /** Return the week-defined icon character, falling back to the chart opponent. */
  public static function getPsychFreeplayIcon(songId:String, fallback:String = 'face'):String
  {
    var iconId:Null<String> = psychFreeplayIcons.get(songId);
    if (iconId == null || StringTools.trim(iconId).length == 0) return fallback;

    iconId = StringTools.trim(iconId);
    // Psych week files name the asset (icon-gorilla), while HealthIcon expects
    // the character ID (gorilla) and adds the icon- prefix itself.
    if (StringTools.startsWith(iconId.toLowerCase(), "icon-"))
      iconId = iconId.substr(5);

    return iconId.length == 0 ? fallback : iconId;
  }

  /**
   * Convert standard Psych weeks/<week>.json files into runtime-only native
   * Story Mode levels. The source mod files remain untouched.
   */
  public static function loadWeeks(modDirs:Array<String>):Array<String>
  {
    var loaded:Array<String> = [];
    for (oldId in psychWeekIds) LevelRegistry.instance.removePsychLevel(oldId);
    psychWeekIds = [];
    psychFreeplayColors.clear();
    psychFreeplayIcons.clear();
    psychFreeplaySongOrder = [];

    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;
      modPath = resolvePsychContentRoot(modPath);
      var weekPath:String = Path.join([modPath, "weeks"]);
      if (!FileSystem.exists(weekPath) || !FileSystem.isDirectory(weekPath)) continue;

      var weekFiles:Array<String> = [];
      var weekListPath:String = Path.join([weekPath, "weekList.txt"]);
      if (FileSystem.exists(weekListPath))
      {
        for (rawWeekName in File.getContent(weekListPath).split("\n"))
        {
          var weekName:String = StringTools.trim(rawWeekName);
          if (weekName.length == 0 || weekName.startsWith("#")) continue;
          if (!weekName.toLowerCase().endsWith(".json")) weekName += ".json";
          var listedPath:String = Path.join([weekPath, weekName]);
          if (FileSystem.exists(listedPath) && !weekFiles.contains(weekName))
            weekFiles.push(weekName);
        }
      }

      // Psych loads the explicit weekList order first, then appends unlisted
      // week JSON files in alphabetical order.
      var remainingWeekFiles:Array<String> = FileSystem.readDirectory(weekPath);
      remainingWeekFiles.sort(Reflect.compare);
      for (candidate in remainingWeekFiles)
      {
        if (Path.extension(candidate).toLowerCase() == "json" && !weekFiles.contains(candidate))
          weekFiles.push(candidate);
      }

      for (weekFile in weekFiles)
      {
        if (Path.extension(weekFile).toLowerCase() != "json") continue;
        var fullPath:String = Path.join([weekPath, weekFile]);
        try
        {
          var raw:Dynamic = Json.parse(File.getContent(fullPath));
          var hideFreeplay:Bool = Reflect.field(raw, "hideFreeplay") == true;
          var rawSongs:Dynamic = Reflect.field(raw, "songs");
          if (rawSongs == null || !Std.isOfType(rawSongs, Array)) continue;

          var songIds:Array<String> = [];
          for (songEntry in (cast rawSongs:Array<Dynamic>))
          {
            var rawSongName:Dynamic = Std.isOfType(songEntry, Array) && songEntry.length > 0
              ? songEntry[0]
              : songEntry;
            if (rawSongName == null) continue;
            var songId:Null<String> = resolvePsychWeekSongId(directory, Std.string(rawSongName));
            if (songId != null)
            {
              if (songIds.indexOf(songId) < 0) songIds.push(songId);
              if (!hideFreeplay && !psychFreeplaySongOrder.contains(songId)) psychFreeplaySongOrder.push(songId);

              if (!hideFreeplay && Std.isOfType(songEntry, Array))
              {
                var entry:Array<Dynamic> = cast songEntry;
                if (entry.length > 1 && entry[1] != null && !psychFreeplayIcons.exists(songId))
                  psychFreeplayIcons.set(songId, Std.string(entry[1]));

                if (entry.length > 2 && Std.isOfType(entry[2], Array) && !psychFreeplayColors.exists(songId))
                {
                  var rgb:Array<Dynamic> = cast entry[2];
                  if (rgb.length >= 3)
                  {
                    var red:Int = Std.int(Std.parseInt(Std.string(rgb[0])) ?? 146);
                    var green:Int = Std.int(Std.parseInt(Std.string(rgb[1])) ?? 113);
                    var blue:Int = Std.int(Std.parseInt(Std.string(rgb[2])) ?? 253);
                    red = Std.int(Math.max(0, Math.min(255, red)));
                    green = Std.int(Math.max(0, Math.min(255, green)));
                    blue = Std.int(Math.max(0, Math.min(255, blue)));
                    psychFreeplayColors.set(songId, 0xFF000000 | (red << 16) | (green << 8) | blue);
                  }
                }
              }
            }
          }
          if (songIds.length == 0) continue;

          var weekId:String = "psych-week-" + slug(directory) + "-" + slug(Path.withoutExtension(weekFile));
          var displayName:String = readPsychString(raw, "storyName",
            readPsychString(raw, "weekName", Path.withoutExtension(weekFile)));
          var hidden:Bool = Reflect.field(raw, "hideStoryMode") == true;
          var hiddenUntilUnlocked:Bool = Reflect.field(raw, "hiddenUntilUnlocked") == true;
          var startUnlocked:Bool = Reflect.field(raw, "startUnlocked") == true;
          var background:String = buildPsychWeekBackground(raw);
          var props:Array<Dynamic> = buildPsychWeekProps(modPath, Reflect.field(raw, "weekCharacters"));
          var psychDifficulties:Array<String> = [];
          var rawDifficulties:Dynamic = Reflect.field(raw, "difficulties");
          if (Std.isOfType(rawDifficulties, String))
          {
            for (part in Std.string(rawDifficulties).split(","))
            {
              var difficulty:String = StringTools.trim(part);
              if (difficulty.length > 0 && !psychDifficulties.contains(difficulty))
                psychDifficulties.push(difficulty);
            }
          }
          else if (Std.isOfType(rawDifficulties, Array))
          {
            for (part in (cast rawDifficulties:Array<Dynamic>))
            {
              if (part == null) continue;
              var difficulty:String = StringTools.trim(Std.string(part));
              if (difficulty.length > 0 && !psychDifficulties.contains(difficulty))
                psychDifficulties.push(difficulty);
            }
          }

          var data:Dynamic = {
            version: Std.string(LevelRegistry.LEVEL_DATA_VERSION),
            name: displayName,
            titleAsset: "psych-week-title",
            props: props,
            visible: !hidden,
            songs: songIds,
            background: background,
            psychImported: true,
            psychStartUnlocked: startUnlocked || !hiddenUntilUnlocked,
            psychDifficulties: psychDifficulties
          };
          LevelRegistry.instance.registerPsychLevel(weekId, cast data);
          psychWeekIds.push(weekId);
          loaded.push(weekId);
          trace('[Psych Compatibility] Registered Story Mode week: ' + displayName + ' (' + songIds.length + ' songs).');
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not import week ' + fullPath + ': ' + Std.string(error));
        }
      }
    }
    #end

    return loaded;
  }

  #if sys
  static function buildPsychWeekBackground(week:Dynamic):String
  {
    var requested:String = readPsychString(week, "weekBackground", "");
    if (requested.length > 0) return requested;

    var color:Dynamic = Reflect.field(week, "freeplayColor");
    if (color != null && Std.isOfType(color, Array) && color.length >= 3)
    {
      var red:Int = Std.int(Math.max(0, Math.min(255, Std.parseFloat(Std.string(color[0])))));
      var green:Int = Std.int(Math.max(0, Math.min(255, Std.parseFloat(Std.string(color[1])))));
      var blue:Int = Std.int(Math.max(0, Math.min(255, Std.parseFloat(Std.string(color[2])))));
      return "#" + StringTools.hex(red, 2) + StringTools.hex(green, 2) + StringTools.hex(blue, 2);
    }
    return "#202020";
  }

  static function findPsychWeekCharacterDataFile(modPath:String, characterId:String):Null<String>
  {
    var menuRoot:String = Path.join([modPath, "images", "menucharacters"]);
    if (!FileSystem.exists(menuRoot) || !FileSystem.isDirectory(menuRoot)) return null;

    var requested:String = (characterId + ".json").toLowerCase();
    for (entry in FileSystem.readDirectory(menuRoot))
    {
      var candidate:String = Path.join([menuRoot, entry]);
      if (!FileSystem.isDirectory(candidate) && entry.toLowerCase() == requested)
        return candidate;
    }
    return null;
  }

  /**
   * Resolve a week song by its imported song ID first, then by its chart display
   * name. Some Psych packs use a display title in weeks/*.json that differs
   * from the data/<folder>/ directory name.
   */
  static function resolvePsychWeekSongId(modDirectory:String, requestedSongName:String):Null<String>
  {
    if (requestedSongName == null || StringTools.trim(requestedSongName).length == 0) return null;

    var exactId:String = buildSongId(modDirectory, requestedSongName);
    if (audioPaths.exists(exactId)) return exactId;

    var requestedSlug:String = slug(requestedSongName);
    var ownerPrefix:String = "psych-" + slug(modDirectory) + "-";
    var matches:Array<String> = [];
    for (songId in audioPaths.keys())
    {
      if (!StringTools.startsWith(songId, ownerPrefix)) continue;

      var folderSlug:String = songId.substr(ownerPrefix.length);
      if (folderSlug == requestedSlug)
      {
        matches.push(songId);
        continue;
      }

      var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);
      if (song != null && slug(song.songName) == requestedSlug)
        matches.push(songId);
    }

    return matches.length == 1 ? matches[0] : null;
  }

  static function buildPsychWeekProps(modPath:String, rawCharacters:Dynamic):Array<Dynamic>
  {
    var result:Array<Dynamic> = [];
    if (rawCharacters == null || !Std.isOfType(rawCharacters, Array)) return result;

    for (rawId in (cast rawCharacters:Array<Dynamic>))
    {
      if (rawId == null) continue;
      var characterId:String = StringTools.trim(Std.string(rawId));
      if (characterId.length == 0 || result.length >= 3) continue;

      var menuPath:Null<String> = findPsychWeekCharacterDataFile(modPath, characterId);
      if (menuPath != null)
      {
        try
        {
          var menuData:Dynamic = Json.parse(File.getContent(menuPath));
          var image:String = readPsychString(menuData, "image", characterId);
          var idlePrefix:String = readPsychString(menuData, "idle_anim", "idle");
          var confirmPrefix:String = readPsychString(menuData, "confirm_anim", "");
          var position:Array<Float> = readPsychStagePosition(menuData, "position") ?? [0.0, 0.0];
          var menuAnimations:Array<Dynamic> = [{
            name: "idle",
            prefix: idlePrefix,
            frameRate: 24,
            looped: true,
            offsets: [0.0, 0.0],
            flipX: false,
            flipY: false
          }];
          if (confirmPrefix.length > 0)
          {
            menuAnimations.push({
              name: "confirm",
              prefix: confirmPrefix,
              frameRate: 24,
              looped: false,
              offsets: [0.0, 0.0],
              flipX: false,
              flipY: false
            });
          }
          result.push({
            assetPath: "menucharacters/" + image,
            animations: menuAnimations,
            startingAnimation: "idle",
            danceEvery: 1.0,
            scale: readPsychFloat(menuData, "scale", 1.0),
            alpha: 1.0,
            isPixel: false,
            offsets: position,
            flipX: Reflect.field(menuData, "flipX") == true,
            flipY: false
          });
          continue;
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not read week menu character ' + characterId + ': ' + Std.string(error));
        }
      }

      var characterPath:Null<String> = findPsychCharacterDataFile(modPath, characterId);
      if (characterPath == null) continue;
      try
      {
        var characterData:Dynamic = Json.parse(File.getContent(characterPath));
        var animations:Array<Dynamic> = [];
        var rawAnimations:Dynamic = Reflect.field(characterData, "animations");
        if (rawAnimations != null && Std.isOfType(rawAnimations, Array))
        {
          for (rawAnimation in (cast rawAnimations:Array<Dynamic>))
          {
            if (rawAnimation == null) continue;
            var animName:String = readPsychString(rawAnimation, "anim", "idle");
            animations.push({
              name: animName,
              prefix: readPsychString(rawAnimation, "name", animName),
              frameRate: Std.int(readPsychFloat(rawAnimation, "fps", 24)),
              looped: Reflect.field(rawAnimation, "loop") == true,
              offsets: readPsychStagePosition(rawAnimation, "offsets") ?? [0.0, 0.0],
              flipX: false,
              flipY: false
            });
          }
        }
        if (animations.length == 0) continue;

        result.push({
          assetPath: readPsychString(characterData, "image", ""),
          animations: animations,
          startingAnimation: "idle",
          danceEvery: 1.0,
          scale: readPsychFloat(characterData, "scale", 1.0),
          alpha: 1.0,
          isPixel: Reflect.field(characterData, "no_antialiasing") == true,
          offsets: [0.0, 0.0],
          flipX: Reflect.field(characterData, "flip_x") == true,
          flipY: false
        });
      }
      catch (error:Dynamic)
      {
        trace('[Psych Compatibility] Could not create week prop for ' + characterId + ': ' + Std.string(error));
      }
    }
    return result;
  }
  #end

  /**
   * Resolve a Psych startVideo() request inside the owning mod's videos folder.
   * Returns a native filesystem path; traversal and absolute paths are rejected.
   */
  public static function resolvePsychVideoPath(songId:String, requestedPath:String):Null<String>
  {
    #if sys
    var modRoot:Null<String> = psychSongModRoots.get(songId);
    if (modRoot == null || requestedPath == null || StringTools.trim(requestedPath).length == 0) return null;

    var relative:String = StringTools.replace(StringTools.trim(requestedPath), "\\", "/");
    while (StringTools.startsWith(relative, "/")) relative = relative.substr(1);
    if (~/^[a-zA-Z]:/.match(relative)) return null;
    for (part in relative.split("/"))
      if (part == ".." || part == "." || part.length == 0) return null;

    if (Path.extension(relative).length == 0) relative += ".mp4";

    var videosRoot:String = Path.normalize(Path.join([modRoot, "videos"]));
    var prefix:String = StringTools.endsWith(videosRoot, "/") ? videosRoot : videosRoot + "/";
    var videoPath:String = Path.normalize(Path.join([videosRoot, relative]));
    if (!StringTools.startsWith(videoPath, prefix)) return null;
    if (!FileSystem.exists(videoPath) || FileSystem.isDirectory(videoPath)) return null;
    return videoPath;
    #else
    return null;
    #end
  }

  /** True only for a song imported by this Psych compatibility loader. */
  public static function isImportedSong(songId:String):Bool
  {
    return songId != null && audioPaths.exists(songId);
  }


  /**
   * Read Psych healthbar_colors for the active opponent/player pair.
   * The first RGB triplet is the opponent/empty side; the second is the
   * boyfriend/player/filled side, matching Psych's health bar convention.
   */
  public static function getPsychHealthBarColors(songId:String, playerId:String, opponentId:String):Null<Array<Int>>
  {
    #if sys
    if (songId == null || playerId == null || opponentId == null) return null;
    var modRoot:Null<String> = psychSongModRoots.get(songId);
    if (modRoot == null) return null;

    var opponentPath:Null<String> = findPsychCharacterDataFile(modRoot, opponentId);
    var playerPath:Null<String> = findPsychCharacterDataFile(modRoot, playerId);
    if (opponentPath == null || playerPath == null) return null;

    try
    {
      var opponentRaw:Dynamic = Json.parse(File.getContent(opponentPath));
      var playerRaw:Dynamic = Json.parse(File.getContent(playerPath));
      var opponentColors:Null<Array<Int>> = readPsychHealthBarColor(opponentRaw);
      var playerColors:Null<Array<Int>> = readPsychHealthBarColor(playerRaw);
      if (opponentColors == null || playerColors == null) return null;
      return opponentColors.concat(playerColors);
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not read character healthbar_colors for ' + songId + ': ' + Std.string(error));
      return null;
    }
    #else
    return null;
    #end
  }

  #if sys
  static function readPsychHealthBarColor(characterData:Dynamic):Null<Array<Int>>
  {
    var raw:Dynamic = characterData == null ? null : Reflect.field(characterData, "healthbar_colors");
    if (!Std.isOfType(raw, Array) || raw.length < 3) return null;
    var result:Array<Int> = [];
    for (i in 0...3)
    {
      var parsed:Float = Std.parseFloat(Std.string(raw[i]));
      if (Math.isNaN(parsed)) return null;
      result.push(Std.int(Math.max(0, Math.min(255, parsed))));
    }
    return result;
  }
  #end


  /**
   * Apply the active Psych package's stages/<stage>.json data to the native
   * stage before characters are constructed. The baseline is restored on
   * every stage load so Psych overrides cannot leak into ordinary V-Slice
   * songs that reuse the same native Stage instance.
   */
  public static function applyPsychStageData(stage:Dynamic, songId:String):Void
  {
    if (stage == null) return;
    var stageId:String = Std.string(Reflect.field(stage, "id"));
    if (stageId.length == 0) return;

    var stageData:Dynamic = Reflect.field(stage, "_data");
    if (stageData == null) return;

    var baseline:Dynamic = psychStageBaselines.get(stageId);
    if (baseline == null)
    {
      var characters:Dynamic = Reflect.field(stageData, "characters");
      baseline = {
        cameraZoom: Reflect.field(stageData, "cameraZoom"),
        boyfriend: copyPsychStageCharacterData(Reflect.field(characters, "bf")),
        girlfriend: copyPsychStageCharacterData(Reflect.field(characters, "gf")),
        opponent: copyPsychStageCharacterData(Reflect.field(characters, "dad"))
      };
      psychStageBaselines.set(stageId, baseline);
    }

    Reflect.setField(stageData, "cameraZoom", Reflect.field(baseline, "cameraZoom"));
    var stageCharacters:Dynamic = Reflect.field(stageData, "characters");
    restorePsychStageCharacterData(Reflect.field(stageCharacters, "bf"), Reflect.field(baseline, "boyfriend"));
    restorePsychStageCharacterData(Reflect.field(stageCharacters, "gf"), Reflect.field(baseline, "girlfriend"));
    restorePsychStageCharacterData(Reflect.field(stageCharacters, "dad"), Reflect.field(baseline, "opponent"));
    psychSongStagePositions.remove(songId);

    #if sys
    var stageName:Null<String> = psychSongStageNames.get(songId);
    var modRoot:Null<String> = psychSongModRoots.get(songId);
    if (stageName == null || modRoot == null) return;

    // Stage names are file basenames, never arbitrary paths.
    if (stageName.indexOf("/") >= 0 || stageName.indexOf("\\") >= 0
      || stageName == "." || stageName == "..") return;

    var stagePath:String = Path.normalize(Path.join([modRoot, "stages", stageName + ".json"]));
    var stageDirectory:String = Path.normalize(Path.join([modRoot, "stages"]));
    var prefix:String = StringTools.endsWith(stageDirectory, "/") ? stageDirectory : stageDirectory + "/";
    if (!StringTools.startsWith(stagePath, prefix) || !FileSystem.exists(stagePath) || FileSystem.isDirectory(stagePath)) return;

    try
    {
      var raw:Dynamic = Json.parse(File.getContent(stagePath));
      var zoom:Float = readPsychFloat(raw, "defaultZoom", stage.camZoom);
      if (zoom > 0 && !Math.isNaN(zoom)) Reflect.setField(stageData, "cameraZoom", zoom);

      var positions:Map<String, Array<Float>> = [];
      var boyfriend:Array<Float> = readPsychStagePosition(raw, "boyfriend");
      var girlfriend:Array<Float> = readPsychStagePosition(raw, "girlfriend");
      var opponent:Array<Float> = readPsychStagePosition(raw, "opponent");
      if (boyfriend != null) positions.set("boyfriend", boyfriend);
      if (girlfriend != null) positions.set("girlfriend", girlfriend);
      if (opponent != null) positions.set("opponent", opponent);
      psychSongStagePositions.set(songId, positions);

      // Psych character JSON already carries its own camera offsets and
      // scale, so the native stage's per-character offsets must not be added.
      for (entry in [
        Reflect.field(stageCharacters, "bf"),
        Reflect.field(stageCharacters, "gf"),
        Reflect.field(stageCharacters, "dad")
      ])
      {
        if (entry == null) continue;
        Reflect.setField(entry, "cameraOffsets", [0.0, 0.0]);
        Reflect.setField(entry, "scale", 1.0);
        Reflect.setField(entry, "scroll", [1.0, 1.0]);
        Reflect.setField(entry, "alpha", 1.0);
        Reflect.setField(entry, "angle", 0.0);
      }
      trace('[Psych Compatibility] Applied Psych stage JSON for ' + stageName + ' (' + songId + ').');
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not load stage data for ' + stageName + ': ' + Std.string(error));
    }
    #end
  }

  /** True when a named stage script is stored directly in the Psych mod root. */
  public static function isRootPsychStageScript(songId:String, sourcePath:String):Bool
  {
    #if sys
    if (songId == null || sourcePath == null) return false;
    var stageName:Null<String> = psychSongStageNames.get(songId);
    var modRoot:Null<String> = psychSongModRoots.get(songId);
    if (stageName == null || modRoot == null || stageName.length == 0) return false;

    var sourceDirectory:String = Path.normalize(Path.directory(sourcePath));
    var expectedDirectory:String = Path.normalize(modRoot);
    if (sourceDirectory != expectedDirectory) return false;
    return Path.withoutExtension(Path.withoutDirectory(sourcePath)).toLowerCase() == stageName.toLowerCase();
    #else
    return false;
    #end
  }

  /** Place a Psych character at the x/y coordinates from stages/<stage>.json. */
  public static function applyPsychStageCharacterPosition(character:Dynamic, role:String):Void
  {
    if (character == null || PlayState.instance == null || PlayState.instance.currentSong == null) return;
    var positions:Null<Map<String, Array<Float>>> = psychSongStagePositions.get(PlayState.instance.currentSong.id);
    if (positions == null) return;
    var position:Null<Array<Float>> = positions.get(role);
    if (position == null || position.length < 2) return;

    var offsets:Dynamic = Reflect.field(character, "globalOffsets");
    var offsetX:Float = offsets != null && offsets.length > 0 ? cast offsets[0] : 0;
    var offsetY:Float = offsets != null && offsets.length > 1 ? cast offsets[1] : 0;
    var x:Float = position[0] + offsetX;
    var y:Float = position[1] + offsetY;
    Reflect.setProperty(character, "x", x);
    Reflect.setProperty(character, "y", y);

    var originalPosition:Dynamic = Reflect.field(character, "originalPosition");
    if (originalPosition != null)
      Reflect.callMethod(originalPosition, Reflect.field(originalPosition, "set"), [x, y]);
    var resetCamera:Dynamic = Reflect.field(character, "resetCameraFocusPoint");
    if (resetCamera != null) Reflect.callMethod(character, resetCamera, []);
  }

  static function copyPsychStageCharacterData(source:Dynamic):Dynamic
  {
    if (source == null) return null;
    return {
      zIndex: Reflect.field(source, "zIndex"),
      position: copyPsychStageVector(Reflect.field(source, "position"), [0.0, 0.0]),
      scale: Reflect.field(source, "scale"),
      cameraOffsets: copyPsychStageVector(Reflect.field(source, "cameraOffsets"), [0.0, 0.0]),
      scroll: copyPsychStageVector(Reflect.field(source, "scroll"), [1.0, 1.0]),
      alpha: Reflect.field(source, "alpha"),
      angle: Reflect.field(source, "angle")
    };
  }

  static function copyPsychStageVector(value:Dynamic, fallback:Array<Float>):Array<Float>
  {
    if (value == null || value.length < 2) return fallback.copy();
    return [cast value[0], cast value[1]];
  }

  static function restorePsychStageCharacterData(target:Dynamic, source:Dynamic):Void
  {
    if (target == null || source == null) return;
    Reflect.setField(target, "zIndex", Reflect.field(source, "zIndex"));
    Reflect.setField(target, "position", copyPsychStageVector(Reflect.field(source, "position"), [0.0, 0.0]));
    Reflect.setField(target, "scale", Reflect.field(source, "scale"));
    Reflect.setField(target, "cameraOffsets", copyPsychStageVector(Reflect.field(source, "cameraOffsets"), [0.0, 0.0]));
    Reflect.setField(target, "scroll", copyPsychStageVector(Reflect.field(source, "scroll"), [1.0, 1.0]));
    Reflect.setField(target, "alpha", Reflect.field(source, "alpha"));
    Reflect.setField(target, "angle", Reflect.field(source, "angle"));
  }

  static function readPsychStagePosition(source:Dynamic, field:String):Null<Array<Float>>
  {
    var value:Dynamic = source == null ? null : Reflect.field(source, field);
    if (value == null || !Std.isOfType(value, Array) || value.length < 2) return null;
    var x:Float = Std.parseFloat(Std.string(value[0]));
    var y:Float = Std.parseFloat(Std.string(value[1]));
    if (Math.isNaN(x) || Math.isNaN(y)) return null;
    return [x, y];
  }

  /**
   * Resolve a dialogue JSON file relative to data/<song>/ for the currently
   * imported Psych song. Path traversal is rejected.
   */
  public static function getSongDataFile(songId:String, requestedPath:String):Null<PsychScriptSource>
  {
    #if sys
    var root:Null<String> = songDataFolders.get(songId);
    if (root == null || requestedPath == null || StringTools.trim(requestedPath).length == 0) return null;

    var relative:String = StringTools.replace(StringTools.trim(requestedPath), "\\", "/");
    while (StringTools.startsWith(relative, "/")) relative = relative.substr(1);
    if (!StringTools.endsWith(relative.toLowerCase(), ".json")) relative += ".json";
    for (part in relative.split("/"))
      if (part == ".." || part == ".") return null;

    var base:String = Path.normalize(root);
    var prefix:String = StringTools.endsWith(base, "/") ? base : base + "/";
    var filePath:String = Path.normalize(Path.join([base, relative]));
    if (!StringTools.startsWith(filePath, prefix)) return null;
    if (!FileSystem.exists(filePath) || FileSystem.isDirectory(filePath)) return null;
    try
    {
      return {path: filePath, source: File.getContent(filePath)};
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not read song data file ' + filePath + ': ' + Std.string(error));
      return null;
    }
    #else
    return null;
    #end
  }

  /**
   * Read a Psych mod's settings.json defaults and merge them with the user's
   * persisted per-mod values in the normal game save. Only the named mod's
   * own data/settings.json is read; script-provided paths are never accepted.
   */
  public static function getModSetting(saveTag:String, ?modName:String = null):Dynamic
  {
    if (saveTag == null || StringTools.trim(saveTag).length == 0) return null;
    if (FlxG.save == null || FlxG.save.data == null) return null;
    #if sys
    var directory:String = modName == null || StringTools.trim(modName).length == 0
      ? PsychScriptRuntime.getExecutingScriptModDirectory()
      : StringTools.trim(modName);
    if (directory.length == 0 || directory.indexOf("/") >= 0 || directory.indexOf("\\") >= 0
      || directory == "." || directory == "..") return null;

    var root:String = Path.normalize(PolymodHandler.getModRoot());
    var modPath:String = Path.normalize(Path.join([root, directory]));
    modPath = Path.normalize(resolvePsychContentRoot(modPath));
    var rootPrefix:String = StringTools.endsWith(root, "/") ? root : root + "/";
    if (!StringTools.startsWith(modPath, rootPrefix)) return null;

    var settingsPath:String = Path.join([modPath, "data", "settings.json"]);
    if (!FileSystem.exists(settingsPath) || FileSystem.isDirectory(settingsPath)) return null;

    var allSettings:Map<String, Dynamic> = cast Reflect.field(FlxG.save.data, "modSettings");
    if (allSettings == null)
    {
      allSettings = new Map<String, Dynamic>();
      Reflect.setField(FlxG.save.data, "modSettings", allSettings);
    }
    var settings:Map<String, Dynamic> = cast allSettings.get(directory);
    if (settings == null) settings = new Map<String, Dynamic>();
    // Refresh only when this key is not already stored. This preserves user
    // preferences while allowing a mod update to introduce additional settings.
    if (!settings.exists(saveTag))
    {
      try
      {
        var parsed:Dynamic = Json.parse(File.getContent(settingsPath));
        if (Std.isOfType(parsed, Array))
        {
          for (entry in (cast parsed:Array<Dynamic>))
          {
            if (entry == null) continue;
            var key:Dynamic = Reflect.field(entry, "save");
            if (key == null) continue;
            var keyName:String = Std.string(key);
            if (keyName.length == 0 || settings.exists(keyName)) continue;
            var kind:Dynamic = Reflect.field(entry, "type");
            if (kind == "keybind" || kind == "key")
            {
              settings.set(keyName, {
                keyboard: Reflect.field(entry, "keyboard") ?? "NONE",
                gamepad: Reflect.field(entry, "gamepad") ?? "NONE"
              });
            }
            else
            {
              var defaultValue:Dynamic = Reflect.field(entry, "value");
              if (defaultValue != null) settings.set(keyName, defaultValue);
            }
          }
        }
      }
      catch (error:Dynamic)
      {
        trace('[Psych Compatibility] Could not read mod settings for ' + directory + ': ' + Std.string(error));
        return null;
      }
      allSettings.set(directory, settings);
    }
    return settings.get(saveTag);
    #else
    return null;
    #end
  }

  /**
   * Resolve a relative path inside one enabled Psych mod folder. Absolute
   * paths, traversal segments, and paths escaping the package root are rejected.
   */
  #if sys
  static function resolvePsychModPath(modDirectory:String, relativePath:String):Null<String>
  {
    if (modDirectory == null || modDirectory.length == 0 || relativePath == null || relativePath.length == 0)
      return null;
    if (modDirectory.indexOf("/") >= 0 || modDirectory.indexOf("\\") >= 0
      || modDirectory == "." || modDirectory == "..") return null;

    var relative:String = StringTools.replace(StringTools.trim(relativePath), "\\", "/");
    if (StringTools.startsWith(relative, "/") || (relative.length > 1 && relative.charAt(1) == ":")) return null;
    for (part in relative.split("/"))
      if (part == "." || part == ".." || part.length == 0) return null;

    var base:String = Path.normalize(Path.join([PolymodHandler.getModRoot(), modDirectory]));
    var prefix:String = StringTools.endsWith(base, "/") ? base : base + "/";
    var resolved:String = Path.normalize(Path.join([base, relative]));
    return StringTools.startsWith(resolved, prefix) ? resolved : null;
  }

  static function createPsychDirectory(path:String):Bool
  {
    if (FileSystem.exists(path)) return FileSystem.isDirectory(path);
    var parent:String = Path.directory(path);
    if (parent != null && parent != path && parent.length > 0 && !createPsychDirectory(parent)) return false;
    try
    {
      FileSystem.createDirectory(path);
      return true;
    }
    catch (error:Dynamic)
    {
      return false;
    }
  }
  #end

  /** Read a file only from the currently executing script's owning mod. */
  public static function getModFile(relativePath:String):Null<PsychScriptSource>
  {
    #if sys
    var directory:String = PsychScriptRuntime.getExecutingScriptModDirectory();
    var path:Null<String> = resolvePsychModPath(directory, relativePath);
    if (path == null || !FileSystem.exists(path) || FileSystem.isDirectory(path)) return null;
    try return {path: path, source: File.getContent(path)} catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not read mod file ' + path + ': ' + Std.string(error));
      return null;
    }
    #else
    return null;
    #end
  }

  /** Write only within the active Psych mod package; never to absolute paths. */
  public static function saveModFile(relativePath:String, content:String):Bool
  {
    #if sys
    var path:Null<String> = resolvePsychModPath(PsychScriptRuntime.getExecutingScriptModDirectory(), relativePath);
    if (path == null || content == null) return false;
    try
    {
      var parent:String = Path.directory(path);
      if (!createPsychDirectory(parent)) return false;
      File.saveContent(path, content);
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not save mod file ' + relativePath + ': ' + Std.string(error));
      return false;
    }
    #else
    return false;
    #end
  }

  /** Delete only a relative file inside the active Psych mod package. */
  public static function deleteModFile(relativePath:String):Bool
  {
    #if sys
    var path:Null<String> = resolvePsychModPath(PsychScriptRuntime.getExecutingScriptModDirectory(), relativePath);
    if (path == null || !FileSystem.exists(path) || FileSystem.isDirectory(path)) return false;
    try
    {
      FileSystem.deleteFile(path);
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not delete mod file ' + relativePath + ': ' + Std.string(error));
      return false;
    }
    #else
    return false;
    #end
  }

  /** List immediate entries of a relative directory inside the active mod. */
  public static function listModDirectory(relativePath:String):Array<String>
  {
    #if sys
    var requested:String = relativePath == null || StringTools.trim(relativePath).length == 0 ? "data" : relativePath;
    var directory:Null<String> = resolvePsychModPath(PsychScriptRuntime.getExecutingScriptModDirectory(), requested);
    if (directory == null || !FileSystem.exists(directory) || !FileSystem.isDirectory(directory)) return [];
    try
    {
      var result:Array<String> = FileSystem.readDirectory(directory);
      result.sort(Reflect.compare);
      return result;
    }
    catch (error:Dynamic)
    {
      return [];
    }
    #else
    return [];
    #end
  }

  /**
   * Resolve a file from the owning Psych package (for example
   * images/dialogue/bf.json). It does not search outside that package.
   */
  public static function getModAssetFile(songId:String, requestedPath:String):Null<PsychScriptSource>
  {
    #if sys
    var dataPath:Null<String> = songDataFolders.get(songId);
    if (dataPath == null || requestedPath == null || StringTools.trim(requestedPath).length == 0) return null;

    var relative:String = StringTools.replace(StringTools.trim(requestedPath), "\\", "/");
    while (StringTools.startsWith(relative, "/")) relative = relative.substr(1);
    for (part in relative.split("/"))
      if (part == ".." || part == ".") return null;

    var modRoot:String = Path.directory(Path.directory(dataPath));
    var base:String = Path.normalize(modRoot);
    var prefix:String = StringTools.endsWith(base, "/") ? base : base + "/";
    var filePath:String = Path.normalize(Path.join([base, relative]));
    if (!StringTools.startsWith(filePath, prefix)) return null;
    if (!FileSystem.exists(filePath) || FileSystem.isDirectory(filePath)) return null;
    try
    {
      return {path: filePath, source: File.getContent(filePath)};
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not read mod asset metadata ' + filePath + ': ' + Std.string(error));
      return null;
    }
    #else
    return null;
    #end
  }

  public static function getInstrumentalAssetPath(songId:String, suffix:String = ""):Null<String>
  {
    var folder:Null<String> = audioPaths.get(songId);
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
    var folder:Null<String> = audioPaths.get(songId);
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
   * Read global scripts, referenced custom event/note-type scripts, and
   * matching song-local scripts from both Psych package layouts.
   */
  public static function getScriptSources(modDirs:Array<String>, songId:String):Array<PsychScriptSource>
  {
    var globalSources:Array<PsychScriptSource> = [];
    var stageSources:Array<PsychScriptSource> = [];
    var characterSources:Array<PsychScriptSource> = [];
    var customEventSources:Array<PsychScriptSource> = [];
    var customNoteSources:Array<PsychScriptSource> = [];
    var songSources:Array<PsychScriptSource> = [];
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;
      modPath = resolvePsychContentRoot(modPath);
      globalSources = globalSources.concat(readScriptSources(Path.join([modPath, "scripts"]), 5));

      for (source in scanSongSources(modPath))
      {
        if (buildSongId(directory, source.songFolder) != songId) continue;
        var eventNames:Array<String> = [];
        var noteTypeNames:Array<String> = [];
        var stageNames:Array<String> = [];
        var characterNames:Array<String> = [];

        for (chartPath in source.chartFiles)
        {
          try
          {
            var chartRoot:Dynamic = Json.parse(File.getContent(chartPath));
            var chartSong:Dynamic = getPsychChartDataRoot(chartRoot);
            var chartMetadata:Dynamic = getPsychChartMetadata(chartRoot);
            var rawEvents:Dynamic = Reflect.field(chartSong, "events");
            if (rawEvents == null) rawEvents = Reflect.field(chartRoot, "events");
            for (event in extractPsychEvents(rawEvents))
              if (!eventNames.contains(event.name.toLowerCase())) eventNames.push(event.name.toLowerCase());

            var noteData:Dynamic = Reflect.field(chartSong, "notes");
            if (isPsychV2ChartRoot(chartRoot) && Std.isOfType(noteData, Array))
            {
              for (note in (cast noteData:Array<Dynamic>))
              {
                if (note == null) continue;
                var rawType:Dynamic = Reflect.field(note, "k");
                if (rawType == null) rawType = Reflect.field(note, "type");
                if (rawType == null) continue;
                var typeName:String = StringTools.trim(Std.string(rawType)).toLowerCase();
                if (typeName.length > 0 && !isSupportedBuiltinPsychNoteType(typeName) && !noteTypeNames.contains(typeName))
                  noteTypeNames.push(typeName);
              }
            }
            else
            {
              collectPsychNoteTypes(noteData, noteTypeNames);
            }

            var rawStage:Dynamic = Reflect.field(chartSong, "stage");
            if (rawStage == null || StringTools.trim(Std.string(rawStage)).length == 0)
              rawStage = Reflect.field(chartSong, "stageDefault");
            if (rawStage == null) rawStage = Reflect.field(chartMetadata, "stage");
            if (rawStage != null)
            {
              var stageName:String = StringTools.trim(Std.string(rawStage)).toLowerCase();
              if (stageName.length > 0 && !stageNames.contains(stageName)) stageNames.push(stageName);
            }

            for (field in ["player1", "player2", "player3", "gfVersion"])
            {
              var rawCharacter:Dynamic = Reflect.field(chartSong, field);
              if (rawCharacter == null) continue;
              var characterName:String = StringTools.trim(Std.string(rawCharacter)).toLowerCase();
              if (characterName.length > 0 && !characterNames.contains(characterName))
                characterNames.push(characterName);
            }

            var rawLines:Dynamic = Reflect.field(chartRoot, "strumlines");
            if (Std.isOfType(rawLines, Array))
            {
              for (line in (cast rawLines:Array<Dynamic>))
              {
                var chars:Dynamic = line == null ? null : Reflect.field(line, "characters");
                if (!Std.isOfType(chars, Array)) continue;
                for (character in (cast chars:Array<Dynamic>))
                {
                  if (character == null) continue;
                  var characterName:String = StringTools.trim(Std.string(character)).toLowerCase();
                  if (characterName.length > 0 && !characterNames.contains(characterName))
                    characterNames.push(characterName);
                }
              }
            }
          }
          catch (error:Dynamic)
          {
            trace('[Psych Compatibility] Could not scan scripts referenced by ' + chartPath + ': ' + Std.string(error));
          }
        }

        for (eventsPath in findPsychEventsFiles(source.dataPath))
        {
          try
          {
            var externalEvents:Dynamic = Json.parse(File.getContent(eventsPath));
            for (event in extractPsychEvents(externalEvents))
              if (!eventNames.contains(event.name.toLowerCase())) eventNames.push(event.name.toLowerCase());
          }
          catch (error:Dynamic)
          {
            trace('[Psych Compatibility] Could not scan ' + eventsPath + ': ' + Std.string(error));
          }
        }

        stageSources = stageSources.concat(readNamedScriptSources(Path.join([modPath, "stages"]), stageNames));
        // Some Psych packs keep the named stage script beside images/,
        // characters/, and songs/ instead of inside stages/. Only exact
        // stage-name matches are loaded from the package root.
        stageSources = stageSources.concat(readNamedScriptSources(modPath, stageNames));
        characterSources = characterSources.concat(readNamedScriptSources(Path.join([modPath, "characters"]), characterNames));
        customEventSources = customEventSources.concat(readNamedScriptSources(Path.join([modPath, "custom_events"]), eventNames));
        customNoteSources = customNoteSources.concat(readNamedScriptSources(Path.join([modPath, "custom_notetypes"]), noteTypeNames));
        songSources = songSources.concat(readScriptSources(source.dataPath, 3));
      }
    }
    #end

    var combined:Array<PsychScriptSource> = globalSources.concat(stageSources).concat(characterSources)
      .concat(customEventSources).concat(customNoteSources).concat(songSources);
    var seen:Map<String, Bool> = [];
    var unique:Array<PsychScriptSource> = [];
    for (source in combined)
    {
      var key:String = StringTools.replace(source.path, "\\", "/").toLowerCase();
      if (seen.exists(key)) continue;
      seen.set(key, true);
      unique.push(source);
    }
    return unique;
  }

  public static function getCustomSubstateScriptSources(modDirs:Array<String>, name:String):Array<PsychScriptSource>
  {
    var result:Array<PsychScriptSource> = [];
    if (name == null || StringTools.trim(name).length == 0) return result;
    #if sys
    var root:String = PolymodHandler.getModRoot();
    for (directory in modDirs)
    {
      var modPath:String = Path.join([root, directory]);
      if (!isPsychDirectory(modPath)) continue;
      modPath = resolvePsychContentRoot(modPath);
      result = result.concat(readNamedScriptSources(Path.join([modPath, "custom_substates"]), [name]));
    }
    #end
    return result;
  }

  /**
   * Resolve one additional script requested at runtime by Psych's addLuaScript /
   * addHScript helpers. Only files inside an enabled Psych package are eligible;
   * path traversal and absolute paths are rejected.
   */
  public static function getScriptSource(modDirs:Array<String>, requestedPath:String):Null<PsychScriptSource>
  {
    if (requestedPath == null || StringTools.trim(requestedPath).length == 0) return null;
    #if sys
    var relative:String = StringTools.replace(StringTools.trim(requestedPath), "\\", "/");
    while (StringTools.startsWith(relative, "/")) relative = relative.substr(1);
    if (StringTools.startsWith(relative.toLowerCase(), "mods/"))
    {
      var parts:Array<String> = relative.split("/");
      if (parts.length > 2) relative = parts.slice(2).join("/");
    }
    for (part in relative.split("/"))
      if (part == ".." || part == ".") return null;

    var candidates:Array<String> = [];
    if (StringTools.startsWith(relative.toLowerCase(), "scripts/"))
      candidates.push(relative);
    else
      candidates.push(Path.join(["scripts", relative]));

    var root:String = PolymodHandler.getModRoot();
    for (directory in (modDirs == null ? [] : modDirs))
    {
      var modPath:String = Path.normalize(Path.join([root, directory]));
      if (!isPsychDirectory(modPath)) continue;
      modPath = Path.normalize(resolvePsychContentRoot(modPath));
      for (candidate in candidates)
      {
        var filePath:String = Path.normalize(Path.join([modPath, candidate]));
        var prefix:String = modPath;
        if (!StringTools.endsWith(prefix, "/")) prefix += "/";
        if (!StringTools.startsWith(filePath, prefix)) continue;
        if (!FileSystem.exists(filePath) || FileSystem.isDirectory(filePath)) continue;
        var extension:String = Path.extension(filePath).toLowerCase();
        if (extension != "lua" && extension != "hx" && extension != "hscript") continue;
        try
        {
          return {path: filePath, source: File.getContent(filePath)};
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not read requested script ' + filePath + ': ' + Std.string(error));
          return null;
        }
      }
    }
    #end
    return null;
  }

  public static function prepareSongCharacters(modDirs:Array<String>, songId:String,
      characters:Null<SongCharacterData>):Void
  {
    if (characters == null) return;

    // Change Character events may name a character that is not one of the
    // chart's three starting roles. Register the owning package's complete
    // standard characters/ catalog so those swaps can resolve at runtime.
    #if sys
    var songDataPath:Null<String> = songDataFolders.get(songId);
    if (songDataPath != null)
    {
      var ownerRoot:String = Path.normalize(Path.directory(Path.directory(songDataPath)));
      // Full Psych game distributions sometimes keep their shared character
      // JSON beside the mod pack (../assets/characters) instead of duplicating
      // it inside mods/characters. Import those companion definitions too.
      for (characterRoot in psychCharacterDataRoots(ownerRoot))
      {
        if (!FileSystem.exists(characterRoot) || !FileSystem.isDirectory(characterRoot)) continue;
        for (entry in FileSystem.readDirectory(characterRoot))
        {
          if (Path.extension(entry).toLowerCase() != "json") continue;
          var characterId:String = Path.withoutExtension(entry);
          if (CharacterDataParser.fetchCharacterData(characterId) != null) continue;
          var jsonPath:String = Path.join([characterRoot, entry]);
          try
          {
            var raw:Dynamic = Json.parse(File.getContent(jsonPath));
            var converted:Null<CharacterData> = convertPsychCharacterData(characterId, raw);
            if (converted != null && CharacterDataParser.registerModCharacterData(characterId, converted))
              trace('[Psych Compatibility] Registered additional Psych character for scripted swaps: ' + characterId);
          }
          catch (error:Dynamic)
          {
            trace('[Psych Compatibility] Could not register additional character ' + characterId + ': ' + Std.string(error));
          }
        }
      }
    }
    #end

    var characterIds:Array<String> = [characters.player, characters.girlfriend, characters.opponent];
    for (characterId in characterIds)
    {
      if (characterId == null || characterId.length == 0
        || CharacterDataParser.fetchCharacterData(characterId) != null) continue;

      var registered:Bool = false;
      #if sys
      var root:String = PolymodHandler.getModRoot();
      for (directory in modDirs)
      {
        var modPath:String = Path.join([root, directory]);
        if (!isPsychDirectory(modPath)) continue;
        modPath = resolvePsychContentRoot(modPath);
        var jsonPath:Null<String> = findPsychCharacterDataFile(modPath, characterId);
        if (jsonPath == null) continue;
        try
        {
          var raw:Dynamic = Json.parse(File.getContent(jsonPath));
          var converted:Null<CharacterData> = convertPsychCharacterData(characterId, raw);
          if (converted != null && CharacterDataParser.registerModCharacterData(characterId, converted))
          {
            trace('[Psych Compatibility] Registered custom Psych character: ' + characterId
              + ' (JSON: ' + jsonPath + ', atlas: images/' + converted.assetPath + ')');
            registered = true;
            break;
          }
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not convert custom character ' + characterId + ': ' + Std.string(error));
        }
      }
      #end
      if (!registered)
        trace('[Psych Compatibility] Custom character data was not registered: ' + characterId);
    }
  }

  #if sys
  static function psychCharacterDataRoots(modPath:String):Array<String>
  {
    var roots:Array<String> = [
      Path.join([modPath, "characters"]),
      Path.join([modPath, "data", "characters"])
    ];

    // Some full Psych Engine games ship their playable-character JSON beside
    // the mods/ directory while the corresponding atlas is inside mods/images.
    // This keeps those game-bundled characters available when testing/importing
    // the game's own mods/ pack as a NovaBeat mod.
    var companionRoot:String = Path.normalize(Path.join([Path.directory(modPath), "assets", "characters"]));
    if (roots.indexOf(companionRoot) < 0) roots.push(companionRoot);
    return roots;
  }

  static function findPsychCharacterDataFile(modPath:String, characterId:String):Null<String>
  {
    if (characterId == null || characterId.length == 0
      || characterId.indexOf("/") >= 0 || characterId.indexOf("\\") >= 0
      || characterId == "." || characterId == "..") return null;

    var fileName:String = characterId + ".json";
    var roots:Array<String> = psychCharacterDataRoots(modPath);
    for (root in roots)
    {
      var candidate:String = Path.join([root, fileName]);
      if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate)) return candidate;
    }
    for (root in roots)
    {
      if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) continue;
      for (entry in FileSystem.readDirectory(root))
        if (!FileSystem.isDirectory(Path.join([root, entry]))
          && entry.toLowerCase() == fileName.toLowerCase())
          return Path.join([root, entry]);
    }
    return null;
  }

  static function hasPsychCharacterDataFile(modPath:String, characterId:String):Bool
  {
    var jsonPath:Null<String> = findPsychCharacterDataFile(modPath, characterId);
    if (jsonPath == null) return false;

    // Only accept the common Psych Sparrow JSON shape that the native
    // character converter below can faithfully map into NovaBeat.
    try
    {
      var raw:Dynamic = Json.parse(File.getContent(jsonPath));
      var image:Dynamic = Reflect.field(raw, "image");
      var rawAnimations:Dynamic = Reflect.field(raw, "animations");
      if (image == null || !Std.isOfType(image, String) || StringTools.trim(Std.string(image)).length == 0)
        return false;
      if (!Std.isOfType(rawAnimations, Array)) return false;

      var validAnimations:Int = 0;
      for (rawAnimation in (cast rawAnimations:Array<Dynamic>))
      {
        if (rawAnimation == null) continue;
        var animationName:Dynamic = Reflect.field(rawAnimation, "anim");
        if (animationName != null && StringTools.trim(Std.string(animationName)).length > 0)
          validAnimations++;
      }
      return validAnimations > 0;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Character JSON did not match the supported Sparrow schema for ' + characterId + ': ' + Std.string(error));
      return false;
    }
  }

  static function convertPsychCharacterData(characterId:String, raw:Dynamic):Null<CharacterData>
  {
    if (raw == null) return null;
    var image:Dynamic = Reflect.field(raw, "image");
    var rawAnimations:Dynamic = Reflect.field(raw, "animations");
    if (image == null || !Std.isOfType(rawAnimations, Array)) return null;
    var imageKey:String = normalizePsychImageKey(Std.string(image));
    if (imageKey.length == 0) return null;
    // Psych character atlases conventionally live in images/characters/.
    // Some packs omit "characters/" from the JSON image field, so complete
    // that standard path when the value is only a bare atlas name.
    if (imageKey.indexOf("/") < 0) imageKey = "characters/" + imageKey;

    var animations:Array<Dynamic> = [];
    var startingAnimation:String = "idle";
    for (rawAnimation in (cast rawAnimations:Array<Dynamic>))
    {
      if (rawAnimation == null) continue;
      var animationName:Dynamic = Reflect.field(rawAnimation, "anim");
      var animationPrefix:Dynamic = Reflect.field(rawAnimation, "name");
      if (animationName == null) continue;
      if (animationPrefix == null) animationPrefix = animationName;
      if (animations.length == 0) startingAnimation = Std.string(animationName);
      var fpsValue:Dynamic = Reflect.field(rawAnimation, "fps");
      var fps:Float = fpsValue == null ? 24 : Std.parseFloat(Std.string(fpsValue));
      if (Math.isNaN(fps) || fps <= 0) fps = 24;
      var offsetsValue:Dynamic = Reflect.field(rawAnimation, "offsets");
      var animationOffsets:Array<Float> = Std.isOfType(offsetsValue, Array) ? cast offsetsValue : [0, 0];
      animations.push({
        name: Std.string(animationName),
        prefix: Std.string(animationPrefix),
        frameRate: Std.int(fps),
        looped: Reflect.field(rawAnimation, "loop") == true,
        offsets: animationOffsets
      });
      if (Std.string(animationName).toLowerCase() == "idle") startingAnimation = "idle";
    }
    if (animations.length == 0) return null;

    var cameraValue:Dynamic = Reflect.field(raw, "camera_position");
    var cameraOffsets:Array<Float> = Std.isOfType(cameraValue, Array) ? cast cameraValue : [0, 0];
    var positionValue:Dynamic = Reflect.field(raw, "position");
    var position:Array<Float> = Std.isOfType(positionValue, Array) ? cast positionValue : [0, 0];
    var healthIconId:Dynamic = Reflect.field(raw, "healthicon");
    if (healthIconId == null || Std.string(healthIconId).length == 0) healthIconId = characterId;
    var scaleValue:Dynamic = Reflect.field(raw, "scale");
    var scale:Float = scaleValue == null ? 1 : Std.parseFloat(Std.string(scaleValue));
    if (Math.isNaN(scale) || scale <= 0) scale = 1;
    var singTimeValue:Dynamic = Reflect.field(raw, "sing_duration");
    var singTime:Float = singTimeValue == null ? 8 : Std.parseFloat(Std.string(singTimeValue));
    if (Math.isNaN(singTime) || singTime <= 0) singTime = 8;
    var isPixel:Bool = Reflect.field(raw, "no_antialiasing") == true;

    var data:Dynamic = {
      version: CharacterDataParser.CHARACTER_DATA_VERSION,
      name: characterId,
      renderType: "sparrow",
      assetPath: imageKey,
      scale: scale,
      healthIcon: {
        id: Std.string(healthIconId), shouldBop: true, scale: 1, flipX: false,
        isPixel: isPixel, offsets: [0, 25]
      },
      offsets: position,
      cameraOffsets: cameraOffsets,
      isPixel: isPixel,
      danceEvery: 1,
      singTime: singTime,
      animations: animations,
      startingAnimation: startingAnimation,
      flipX: Reflect.field(raw, "flip_x") == true,
      applyStageMatrix: false
    };
    return cast data;
  }

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

  static function readNamedScriptSources(path:String, requestedNames:Array<String>):Array<PsychScriptSource>
  {
    var result:Array<PsychScriptSource> = [];
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path) || requestedNames.length == 0) return result;

    var wanted:Map<String, Bool> = [];
    for (name in requestedNames)
      wanted.set(name.toLowerCase(), true);

    var entries:Array<String> = FileSystem.readDirectory(path);
    entries.sort(Reflect.compare);
    for (entry in entries)
    {
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child))
      {
        if (wanted.exists(entry.toLowerCase()))
          result = result.concat(readScriptSources(child, 5));
        continue;
      }

      var extension:String = Path.extension(entry).toLowerCase();
      var scriptName:String = Path.withoutExtension(entry).toLowerCase();
      if (wanted.exists(scriptName)
        && (extension == "lua" || extension == "hx" || extension == "hscript"))
      {
        try
        {
          result.push({path: child, source: File.getContent(child)});
        }
        catch (error:Dynamic)
        {
          trace('[Psych Script Runtime] Could not read ' + child + ': ' + Std.string(error));
        }
      }
    }

    result.sort(function(a:PsychScriptSource, b:PsychScriptSource):Int return Reflect.compare(a.path, b.path));
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

  static function getPsychChartDataRoot(chartRoot:Dynamic):Dynamic
  {
    var legacySong:Dynamic = chartRoot == null ? null : Reflect.field(chartRoot, "song");
    return legacySong == null ? chartRoot : legacySong;
  }

  static function getPsychChartMetadata(chartRoot:Dynamic):Dynamic
  {
    if (chartRoot == null) return null;
    var metadata:Dynamic = Reflect.field(chartRoot, "metadata");
    return metadata == null ? chartRoot : metadata;
  }

  static function isPsychV2ChartRoot(chartRoot:Dynamic):Bool
  {
    if (chartRoot == null) return false;
    return Std.isOfType(Reflect.field(chartRoot, "notes"), Array)
      && Std.isOfType(Reflect.field(chartRoot, "strumlines"), Array);
  }

  #if sys
  static function isPsychChartFile(path:String):Bool
  {
    try
    {
      var root:Dynamic = Json.parse(File.getContent(path));
      var legacySong:Dynamic = Reflect.field(root, "song");
      if (legacySong != null && Reflect.field(legacySong, "notes") != null) return true;
      return isPsychV2ChartRoot(root);
    }
    catch (error:Dynamic)
    {
      return false;
    }
  }
  #end

  static function isBuiltinPsychStage(stageName:String):Bool
  {
    if (stageName == null) return true;
    return switch (StringTools.trim(stageName).toLowerCase())
    {
      case "", "stage", "spooky", "philly", "limo", "mall", "mallevil",
        "school", "schoolevil", "tank", "tankmanbattlefield", "phillystreets", "phillyblazin",
        "mainstage", "spookymansion", "phillytrain", "limoride", "mallxmas": true;
      default: false;
    };
  }

  static function resolvePsychStage(stageName:String, ?songFolder:String):String
  {
    if (stageName == null || StringTools.trim(stageName).length == 0)
    {
      var songKey:String = songFolder == null ? "" : songFolder.toLowerCase();
      return switch (songKey)
      {
        case "spookeez", "south", "monster": "spookyMansion";
        case "pico", "philly", "philly-nice", "blammed": "phillyTrain";
        case "milf", "satin-panties", "high": "limoRide";
        case "cocoa", "eggnog": "mallXmas";
        case "winter-horrorland": "mallEvil";
        case "senpai", "roses": "school";
        case "thorns": "schoolEvil";
        case "ugh", "guns", "stress": "tankmanBattlefield";
        case "darnell", "lit-up", "2hot": "phillyStreets";
        case "blazin": "phillyBlazin";
        default: Constants.DEFAULT_STAGE;
      };
    }
    return switch (StringTools.trim(stageName).toLowerCase())
    {
      case "stage", "mainstage": Constants.DEFAULT_STAGE;
      case "spooky", "spookymansion": "spookyMansion";
      case "philly", "phillytrain": "phillyTrain";
      case "phillystreets": "phillyStreets";
      case "phillyblazin": "phillyBlazin";
      case "limo", "limoride": "limoRide";
      case "mall", "mallxmas": "mallXmas";
      case "mallevil", "malleevil": "mallEvil";
      case "school": "school";
      case "schoolevil": "schoolEvil";
      case "tank", "tankmanbattlefield": "tankmanBattlefield";
      // A Psych custom stage is implemented by its stages/<name>.lua/.hx
      // script; the V-Slice chart still needs a valid StageRegistry entry.
      // Keep the native scene on the base stage and let the Psych stage script
      // supply/position its own background objects.
      default: Constants.DEFAULT_STAGE;
    };
  }

  static function psychStrumLineRole(line:Dynamic):Int
  {
    if (line == null) return -1;

    // Psych v2 line types are authoritative: OPPONENT=0, PLAYER=1,
    // ADDITIONAL=2. In particular, an additional/GF line isPlayer=false too,
    // so the legacy boolean must not turn it into an opponent line.
    var type:Dynamic = Reflect.field(line, "type");
    if (type != null)
    {
      if (type == 1 || (Std.isOfType(type, String) && Std.string(type).toLowerCase() == "player"))
        return 0;
      if (type == 0 || (Std.isOfType(type, String) && Std.string(type).toLowerCase() == "opponent"))
        return 1;
      return -1;
    }

    // Older pre-type psych_v2 files used isPlayer alone.
    var isPlayer:Dynamic = Reflect.field(line, "isPlayer");
    if (isPlayer == true) return 0;
    if (isPlayer == false) return 1;
    return -1;
  }

  #if sys
  static function findPsychEventsFiles(dataPath:String):Array<String>
  {
    var result:Array<String> = [];
    if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) return result;
    var files:Array<String> = FileSystem.readDirectory(dataPath);
    files.sort(Reflect.compare);
    for (fileName in files)
    {
      var lower:String = fileName.toLowerCase();
      if (lower == "events.json" || (StringTools.startsWith(lower, "events-") && StringTools.endsWith(lower, ".json")))
      {
        var fullPath:String = Path.join([dataPath, fileName]);
        if (FileSystem.exists(fullPath) && !FileSystem.isDirectory(fullPath)) result.push(fullPath);
      }
    }
    return result;
  }

  static function findPsychEventFile(dataPath:String, difficulty:String):Null<String>
  {
    var specific:String = Path.join([dataPath, "events-" + difficulty + ".json"]);
    if (FileSystem.exists(specific) && !FileSystem.isDirectory(specific)) return specific;
    var shared:String = Path.join([dataPath, "events.json"]);
    if (FileSystem.exists(shared) && !FileSystem.isDirectory(shared)) return shared;
    return null;
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

  /**
   * Return the Psych-facing display label for an internally normalized
   * built-in note kind. Keep private engine IDs out of Lua callback arguments.
   */
  public static function getPsychNoteTypeName(noteType:Null<String>):String
  {
    if (noteType == null) return "";
    return switch (StringTools.trim(noteType).toLowerCase())
    {
      case "alt": "Alt Animation";
      case "noanim": "No Animation";
      case "psychhey": "Hey!";
      case "psychgfsing": "GF Sing";
      case "psychhurt": "Hurt Note";
      case "psychgfsection": "";
      case "psychgfsectionalt": "Alt Animation";
      default: noteType;
    };
  }

  #if sys
  /**
   * Resolve a Psych package extracted with one extra archive wrapper folder,
   * for example mods/<installed-name>/mods/<actual-mod>/songs/<song>/.
   * EngineBridge already recognizes this layout; every scanner and loader
   * must use the same inner content root after detection.
   */
  static function resolvePsychContentRoot(modPath:String):String
  {
    if (!FileSystem.exists(modPath) || !FileSystem.isDirectory(modPath)) return modPath;

    // Prefer a normal mod root when it already contains chart packages.
    if (scanSongSources(modPath).length > 0) return modPath;

    var nestedModsPath:String = Path.join([modPath, "mods"]);
    if (!FileSystem.exists(nestedModsPath) || !FileSystem.isDirectory(nestedModsPath)) return modPath;

    var candidates:Array<String> = [];
    for (entry in FileSystem.readDirectory(nestedModsPath))
    {
      if (entry.length == 0 || entry.charAt(0) == ".") continue;
      var candidate:String = Path.join([nestedModsPath, entry]);
      if (!FileSystem.isDirectory(candidate)) continue;
      if (!EngineBridge.hasPsychMarkersForRuntime(candidate)) continue;
      if (scanSongSources(candidate).length == 0) continue;
      candidates.push(candidate);
    }

    // A single nested package is unambiguous. Do not merge several independent
    // mods into one package or let them shadow each other's scripts/charts.
    return candidates.length == 1 ? candidates[0] : modPath;
  }

  static function scanSongSources(modPath:String):Array<PsychSongSource>
  {
    var bySong:Map<String, PsychSongSource> = [];
    for (rootName in ["data", "songs"])
    {
      var songRoot:String = Path.join([modPath, rootName]);
      if (!FileSystem.exists(songRoot) || !FileSystem.isDirectory(songRoot)) continue;
      var songFolders:Array<String> = FileSystem.readDirectory(songRoot);
      songFolders.sort(Reflect.compare);
      for (songFolder in songFolders)
      {
        if (songFolder.length == 0 || songFolder.charAt(0) == ".") continue;
        var dataPath:String = Path.join([songRoot, songFolder]);
        if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) continue;
        var chartFiles:Array<String> = [];
        var fileNames:Array<String> = FileSystem.readDirectory(dataPath);
        fileNames.sort(Reflect.compare);
        for (fileName in fileNames)
        {
          if (!StringTools.endsWith(fileName.toLowerCase(), ".json")) continue;
          var chartPath:String = Path.join([dataPath, fileName]);
          if (isPsychChartFile(chartPath)) chartFiles.push(chartPath);
        }
        if (chartFiles.length == 0) continue;

        var existing:Null<PsychSongSource> = bySong.get(songFolder);
        if (existing == null)
        {
          var audioPath:Null<String> = findAudioFolder(modPath, songFolder);
          var instrumentFile:Null<String> = audioPath == null ? null : findExistingInstrument(audioPath);
          bySong.set(songFolder, {
            songFolder: songFolder,
            dataPath: dataPath,
            audioPath: audioPath,
            instrumentFile: instrumentFile,
            chartFiles: chartFiles
          });
        }
        else
        {
          for (chartPath in chartFiles)
            if (!existing.chartFiles.contains(chartPath)) existing.chartFiles.push(chartPath);
          if (rootName == "songs") existing.dataPath = dataPath;
        }
      }
    }
    var result:Array<PsychSongSource> = [for (source in bySong) source];
    result.sort(function(a:PsychSongSource, b:PsychSongSource):Int return Reflect.compare(a.songFolder, b.songFolder));
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
   * current compatibility adapters cannot map without losing gameplay data.
   */
  static function inspectUnsupportedChartFeatures(path:String, modPath:String):Null<String>
  {
    try
    {
      var root:Dynamic = Json.parse(File.getContent(path));
      var song:Dynamic = getPsychChartDataRoot(root);
      var metadata:Dynamic = getPsychChartMetadata(root);
      var isV2:Bool = isPsychV2ChartRoot(root);
      var legacyNotes:Dynamic = Reflect.field(song, "notes");
      if (!isV2 && legacyNotes == null) return null;

      var supportedCharacterIds:Map<String, String> = [
        "player1" => "bf", "player2" => "dad", "player3" => "gf", "gfVersion" => "gf"
      ];
      for (field => expected in supportedCharacterIds)
      {
        var rawValue:Dynamic = Reflect.field(song, field);
        if (rawValue == null) continue;
        var actual:String = StringTools.trim(Std.string(rawValue));
        if (actual.length == 0 || actual.toLowerCase() == expected.toLowerCase()) continue;
        var characterAvailable:Bool = hasPsychCharacterDataFile(modPath, actual)
          || CharacterDataParser.fetchCharacterData(actual) != null;
        if (!characterAvailable && field == "player1")
        {
          // Some classic Psych packs assume their playable BF variant is part of
          // the source engine rather than bundled in the mod. Keep the song
          // playable with NovaBeat's standard BF instead of rejecting every song.
          continue;
        }
        if (!characterAvailable)
          return "custom character '" + actual + "' is missing characters/" + actual + ".json";
      }

      var stageValue:Dynamic = Reflect.field(song, "stage");
      if (stageValue == null || StringTools.trim(Std.string(stageValue)).length == 0)
        stageValue = Reflect.field(song, "stageDefault");
      if (stageValue == null) stageValue = Reflect.field(metadata, "stage");
      var stageName:String = stageValue == null ? "" : StringTools.trim(Std.string(stageValue));
      if (stageName.length > 0 && !isBuiltinPsychStage(stageName)
        && !hasNamedPsychScript(Path.join([modPath, "stages"]), stageName)
        && !hasNamedPsychScript(modPath, stageName))
        return "custom stage '" + stageName + "' needs a matching stages/" + stageName
          + ".lua/.hx script or a root-level " + stageName + ".lua/.hx script";

      for (field in ["arrowSkin", "splashSkin", "noteStyle", "uiSkin"])
      {
        var rawValue:Dynamic = Reflect.field(metadata, field);
        if (rawValue == null) rawValue = Reflect.field(song, field);
        if (rawValue == null) continue;

        var skinName:String = StringTools.trim(Std.string(rawValue));
        if (skinName.length == 0) continue;

        // Psych writes this canonical default splash atlas into exported
        // charts. It does not mean that a package supplies a custom skin.
        if (field == "splashSkin" && skinName.toLowerCase() == "notesplashes") continue;

        return "custom note/UI skin metadata (" + field + ": " + skinName + ")";
      }

      if (isV2)
      {
        var lines:Array<Dynamic> = cast Reflect.field(root, "strumlines");
        var rawNotes:Array<Dynamic> = cast Reflect.field(root, "notes");
        var chartKeyCount:Float = readPsychFloat(metadata, "keyCount", 4);
        if (chartKeyCount != 4)
          return "the psych_v2 chart declares a non-four-key layout";

        for (line in lines)
        {
          if (line == null) continue;
          var lineKeyCount:Dynamic = Reflect.field(line, "keyCount");
          if (lineKeyCount != null && Std.int(lineKeyCount) != 4)
            return "a psych_v2 strumline declares a non-four-key layout";
        }
        for (line in lines)
        {
          if (line == null) continue;
          var chars:Dynamic = Reflect.field(line, "characters");
          if (!Std.isOfType(chars, Array)) continue;
          for (rawCharacter in (cast chars:Array<Dynamic>))
          {
            if (rawCharacter == null) continue;
            var character:String = StringTools.trim(Std.string(rawCharacter));
            if (character.length == 0 || ["bf", "dad", "gf"].indexOf(character.toLowerCase()) >= 0) continue;
            if (!hasPsychCharacterDataFile(modPath, character))
              return "custom character '" + character + "' is missing characters/" + character + ".json";
          }
        }

        for (note in rawNotes)
        {
          if (note == null) continue;
          var rawLine:Dynamic = Reflect.field(note, "s");
          var rawColumn:Dynamic = Reflect.field(note, "d");
          if (rawLine == null || rawColumn == null) return "a psych_v2 note is missing its strumline or column";
          var lineIndex:Int = Std.int(rawLine);
          var column:Int = Std.int(rawColumn);
          if (lineIndex < 0 || lineIndex >= lines.length) return "a psych_v2 note references an invalid strumline";
          if (column < 0 || column > 3) return "a psych_v2 chart uses more than four keys per strumline";
          if (psychStrumLineRole(lines[lineIndex]) < 0)
            return "a psych_v2 chart uses an additional strumline that NovaBeat cannot map yet";
          var rawType:Dynamic = Reflect.field(note, "k");
          if (rawType == null) rawType = Reflect.field(note, "type");
          if (rawType != null && Std.isOfType(rawType, String))
          {
            var noteType:String = StringTools.trim(Std.string(rawType));
            if (noteType.length > 0 && !isSupportedBuiltinPsychNoteType(noteType)
              && !hasNamedPsychScript(Path.join([modPath, "custom_notetypes"]), noteType))
              return "custom note type '" + noteType + "' has no matching custom_notetypes script";
          }
          if (Reflect.field(note, "g") == true || Reflect.field(note, "gfNote") == true)
          {
            var gfNoteType:String = rawType == null ? "" : StringTools.trim(Std.string(rawType));
            if (gfNoteType.length == 0 && Reflect.field(note, "a") == true) gfNoteType = "alt";
            if (!isSupportedPsychGFSectionNoteType(gfNoteType))
              return "GF-owned notes combined with note type '" + gfNoteType + "' are not supported yet";
          }
        }

        var sections:Dynamic = Reflect.field(root, "sections");
        if (Std.isOfType(sections, Array))
        {
          for (section in (cast sections:Array<Dynamic>))
          {
            if (section == null) continue;
            if (Reflect.field(section, "changeKeyCount") == true) return "mid-song key-count changes";
            if (Reflect.field(section, "changeSpeed") == true)
              return "mid-song base scroll-speed changes";
            if (Reflect.field(section, "changeScrollVelocity") == true)
              return "mid-song scroll-velocity changes";
          }
        }
      }
      else if (legacyNotes != null)
      {
        if (Std.isOfType(legacyNotes, Array))
        {
          var problem:Null<String> = inspectNoteSections(cast legacyNotes, modPath);
          if (problem != null) return problem;
        }
        else
        {
          for (difficulty in Reflect.fields(legacyNotes))
          {
            var difficultyNotes:Dynamic = Reflect.field(legacyNotes, difficulty);
            if (!Std.isOfType(difficultyNotes, Array)) continue;
            var problem:Null<String> = inspectNoteSections(cast difficultyNotes, modPath);
            if (problem != null) return problem;
          }
        }
      }

      var rawEvents:Dynamic = Reflect.field(song, "events");
      if (rawEvents == null) rawEvents = Reflect.field(root, "events");
      return inspectUnsupportedEvents(rawEvents, modPath);
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Could not inspect raw chart ' + path + ': ' + Std.string(error));
      return "chart JSON could not be parsed (" + Std.string(error) + ")";
    }
  }

  static function inspectUnsupportedEventFile(path:String, modPath:String):Null<String>
  {
    if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) return null;
    try
    {
      return inspectUnsupportedEvents(Json.parse(File.getContent(path)), modPath);
    }
    catch (error:Dynamic)
    {
      return "events.json could not be parsed (" + Std.string(error) + ")";
    }
  }

  static function inspectUnsupportedEvents(rawEvents:Dynamic, modPath:String):Null<String>
  {
    if (rawEvents == null) return null;
    var events:Array<PsychRawEvent> = extractPsychEvents(rawEvents);
    if (Std.isOfType(rawEvents, Array) && (cast rawEvents:Array<Dynamic>).length > 0 && events.length == 0)
      return "unrecognized Psych chart event format";

    for (event in events)
    {
      if (event.name.length == 0) return "an event with no name";
      if (isSupportedBuiltinPsychEvent(event.name)) continue;
      if (!hasNamedPsychScript(Path.join([modPath, "custom_events"]), event.name))
        return "custom event '" + event.name + "' has no matching custom_events script";
    }
    return null;
  }

  static function isSupportedBuiltinPsychEvent(name:String):Bool
  {
    return switch (StringTools.trim(name).toLowerCase())
    {
      case "add camera zoom", "screen shake", "set property", "camera follow pos",
        "play animation", "hey!", "set gf speed", "change character", "change scroll speed": true;
      default: false;
    };
  }

  static function hasNamedPsychScript(path:String, requestedName:String):Bool
  {
    if (requestedName == null || requestedName.length == 0
      || !FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;

    var normalized:String = Path.withoutExtension(Path.withoutDirectory(requestedName)).toLowerCase();
    var entries:Array<String> = FileSystem.readDirectory(path);
    for (entry in entries)
    {
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child))
      {
        if (entry.toLowerCase() == normalized && countScriptFiles(child, 5) > 0) return true;
        continue;
      }

      var extension:String = Path.extension(entry).toLowerCase();
      if ((extension == "lua" || extension == "hx" || extension == "hscript")
        && Path.withoutExtension(entry).toLowerCase() == normalized) return true;
    }
    return false;
  }

  static function extractPsychEvents(raw:Dynamic):Array<PsychRawEvent>
  {
    var result:Array<PsychRawEvent> = [];
    if (raw == null) return result;

    if (Std.isOfType(raw, Array))
    {
      for (entry in (cast raw:Array<Dynamic>))
      {
        if (entry == null) continue;
        if (Std.isOfType(entry, Array))
        {
          var row:Array<Dynamic> = cast entry;
          if (row.length >= 2 && Std.isOfType(row[1], Array))
          {
            var time:Null<Float> = parsePsychEventTime(row[0]);
            for (subEvent in (cast row[1]:Array<Dynamic>))
            {
              if (!Std.isOfType(subEvent, Array)) continue;
              var values:Array<Dynamic> = cast subEvent;
              if (values.length < 1) continue;
              appendPsychEvent(result, time, values[0], values.length > 1 ? values[1] : null,
                values.length > 2 ? values[2] : null);
            }
          }
          else if (row.length >= 2 && Std.isOfType(row[1], String))
          {
            appendPsychEvent(result, parsePsychEventTime(row[0]), row[1],
              row.length > 2 ? row[2] : null, row.length > 3 ? row[3] : null);
          }
        }
        else if (Reflect.isObject(entry))
        {
          appendPsychEventObject(result, entry);
        }
      }
      return result;
    }

    if (Reflect.isObject(raw))
    {
      var nested:Dynamic = Reflect.field(raw, "events");
      if (nested != null) return extractPsychEvents(nested);
      var song:Dynamic = Reflect.field(raw, "song");
      if (song != null)
      {
        var songEvents:Dynamic = Reflect.field(song, "events");
        if (songEvents != null) return extractPsychEvents(songEvents);
      }
      appendPsychEventObject(result, raw);
    }

    return result;
  }

  static function appendPsychEventObject(result:Array<PsychRawEvent>, entry:Dynamic):Void
  {
    var rawName:Dynamic = Reflect.field(entry, "e");
    if (rawName == null) rawName = Reflect.field(entry, "name");
    if (rawName == null) rawName = Reflect.field(entry, "event");
    var rawTime:Dynamic = Reflect.field(entry, "t");
    if (rawTime == null) rawTime = Reflect.field(entry, "time");
    var rawValues:Dynamic = Reflect.field(entry, "v");
    if (rawValues == null) rawValues = Reflect.field(entry, "values");
    if (rawValues == null) rawValues = Reflect.field(entry, "value");
    var value1:Dynamic = null;
    var value2:Dynamic = null;

    if (Std.isOfType(rawValues, Array))
    {
      var values:Array<Dynamic> = cast rawValues;
      value1 = values.length > 0 ? values[0] : null;
      value2 = values.length > 1 ? values[1] : null;
    }
    else if (Reflect.isObject(rawValues))
    {
      value1 = Reflect.field(rawValues, "value1");
      value2 = Reflect.field(rawValues, "value2");
      if (value1 == null) value1 = Reflect.field(rawValues, "value");
      if (value1 == null) value1 = Reflect.field(rawValues, "anim");
      if (value2 == null) value2 = Reflect.field(rawValues, "target");
    }
    else
    {
      value1 = rawValues;
      value2 = Reflect.field(entry, "value2");
    }

    appendPsychEvent(result, parsePsychEventTime(rawTime), rawName, value1, value2);
  }

  static function appendPsychEvent(result:Array<PsychRawEvent>, time:Null<Float>, rawName:Dynamic,
      rawValue1:Dynamic, rawValue2:Dynamic):Void
  {
    if (time == null || rawName == null) return;
    var name:String = StringTools.trim(Std.string(rawName));
    if (name.length == 0) return;
    result.push({
      time: time,
      name: name,
      value1: rawValue1 == null ? "" : Std.string(rawValue1),
      value2: rawValue2 == null ? "" : Std.string(rawValue2)
    });
  }

  static function parsePsychEventTime(value:Dynamic):Null<Float>
  {
    if (value == null) return null;
    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? null : parsed;
  }

  /**
   * Psych's legacy built-in note types that map cleanly to native V-Slice
   * note kinds. Other Psych note types remain gated unless their custom
   * custom_notetypes script is present.
   */
  static function isSupportedBuiltinPsychNoteType(name:String):Bool
  {
    if (name == null) return false;
    return switch (StringTools.trim(name).toLowerCase())
    {
      case "alt", "alt animation", "no animation", "hey!", "gf sing", "hurt note": true;
      default: false;
    };
  }

  /**
   * GF-section ownership can be represented natively for ordinary GF sings,
   * Alt Animation, and the explicit GF Sing note type. Other combinations
   * are rejected rather than silently losing their note behavior.
   */
  static function isSupportedPsychGFSectionNoteType(name:String):Bool
  {
    if (name == null) return true;
    return switch (StringTools.trim(name).toLowerCase())
    {
      case "", "alt", "alt animation", "gf sing": true;
      default: false;
    };
  }

  static function normalizePsychGFSectionNoteType(name:Null<String>):String
  {
    var normalized:String = normalizePsychNoteType(name == null ? "" : name);
    return switch (normalized.toLowerCase())
    {
      case "": "psychgfsection";
      case "alt": "psychgfsectionalt";
      default: normalized;
    };
  }

  /** Convert Psych display names to the built-in note-kind IDs used in gameplay. */
  static function normalizePsychNoteType(name:String):String
  {
    if (name == null) return "";
    return switch (StringTools.trim(name).toLowerCase())
    {
      case "alt animation": "alt";
      case "no animation": "noanim";
      case "hey!": "psychhey";
      case "gf sing": "psychgfsing";
      case "hurt note": "psychhurt";
      default: name;
    };
  }

  static function collectPsychNoteTypes(noteData:Dynamic, result:Array<String>):Void
  {
    if (noteData == null) return;
    if (Std.isOfType(noteData, Array))
    {
      collectPsychNoteTypesFromSections(cast noteData, result);
      return;
    }

    for (difficulty in Reflect.fields(noteData))
    {
      var sections:Dynamic = Reflect.field(noteData, difficulty);
      if (Std.isOfType(sections, Array))
        collectPsychNoteTypesFromSections(cast sections, result);
    }
  }

  static function collectPsychNoteTypesFromSections(sections:Array<Dynamic>, result:Array<String>):Void
  {
    for (section in sections)
    {
      if (section == null) continue;
      var rows:Dynamic = Reflect.field(section, "sectionNotes");
      if (!Std.isOfType(rows, Array)) continue;
      for (note in (cast rows:Array<Dynamic>))
      {
        if (!Std.isOfType(note, Array)) continue;
        var values:Array<Dynamic> = cast note;
        if (values.length <= 3 || !Std.isOfType(values[3], String)) continue;
        var name:String = StringTools.trim(cast values[3]);
        if (name.length > 0 && !isSupportedBuiltinPsychNoteType(name) && !result.contains(name.toLowerCase()))
          result.push(name.toLowerCase());
      }
    }
  }

  static function inspectNoteSections(sections:Array<Dynamic>, modPath:String):Null<String>
  {
    for (section in sections)
    {
      if (section == null) continue;

      var sectionType:Dynamic = Reflect.field(section, "typeOfSection");
      if (sectionType != null && Std.int(sectionType) != 0)
        return "alternate section type metadata";

      var gfSection:Bool = Reflect.field(section, "gfSection") == true;
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

        var noteType:Dynamic = values.length > 3 ? values[3] : null;
        var noteTypeName:String = "";
        if (Std.isOfType(noteType, Bool))
        {
          // The legacy boolean flag denotes Alt Animation when true.
          if (noteType == true) noteTypeName = "alt";
        }
        else if (Std.isOfType(noteType, String))
        {
          noteTypeName = StringTools.trim(cast noteType);
        }
        else if (noteType != null)
        {
          return "unrecognized Psych note-type metadata";
        }

        if (gfSection && !isSupportedPsychGFSectionNoteType(noteTypeName))
          return "GF sections combined with note type '" + noteTypeName + "' are not supported yet";

        if (noteTypeName.length > 0 && !isSupportedBuiltinPsychNoteType(noteTypeName)
          && !hasNamedPsychScript(Path.join([modPath, "custom_notetypes"]), noteTypeName))
          return "custom note type '" + noteTypeName + "' has no matching custom_notetypes script";
      }
    }

    return null;
  }

  /**
   * Reapply Psych's GF-section ownership to notes produced by the legacy
   * importer. It preserves the same note ordering and lane flip rules.
   */
  static function applyPsychGFSectionOwnership(
    sections:Array<Dynamic>,
    notes:Array<funkin.data.song.SongData.SongNoteData>
  ):Void
  {
    var noteIndex:Int = 0;
    for (section in sections)
    {
      if (section == null) continue;
      var gfSection:Bool = Reflect.field(section, "gfSection") == true;
      var mustHitSection:Bool = Reflect.field(section, "mustHitSection") == true;
      var rows:Dynamic = Reflect.field(section, "sectionNotes");
      if (!Std.isOfType(rows, Array)) continue;

      for (rawNote in (cast rows:Array<Dynamic>))
      {
        if (!Std.isOfType(rawNote, Array)) continue;
        var values:Array<Dynamic> = cast rawNote;
        if (values.length < 2 || values[1] == null) continue;

        var lane:Float = Std.parseFloat(Std.string(values[1]));
        if (Math.isNaN(lane)) continue;
        var noteData:Int = Std.int(lane);
        if (noteData < 0) continue; // Psych event notes are excluded by the importer.
        if (noteData > 8) noteData = noteData % 8;
        if (!mustHitSection)
        {
          if (noteData >= 4) noteData -= 4;
          else noteData += 4;
        }

        if (noteIndex >= notes.length) return;
        var importedNote:funkin.data.song.SongData.SongNoteData = notes[noteIndex];
        noteIndex++;
        if (!gfSection) continue;

        var noteType:Dynamic = values.length > 3 ? values[3] : null;
        var noteTypeName:String = "";
        if (Std.isOfType(noteType, Bool))
        {
          if (noteType == true) noteTypeName = "alt";
        }
        else if (Std.isOfType(noteType, String))
        {
          noteTypeName = StringTools.trim(cast noteType);
        }
        importedNote.kind = normalizePsychGFSectionNoteType(noteTypeName);
      }
    }
  }

  /** Add internal timeline markers so Psych section globals follow chart timing. */
  static function appendPsychSectionStateEvents(
    sections:Array<Dynamic>,
    initialBpm:Float,
    events:Array<SongEventData>
  ):Void
  {
    var currentBpm:Float = initialBpm > 0 && !Math.isNaN(initialBpm) ? initialBpm : Constants.DEFAULT_BPM;
    var sectionStart:Float = 0;
    for (index in 0...sections.length)
    {
      var section:Dynamic = sections[index];
      if (section == null) continue;
      if (Reflect.field(section, "changeBPM") == true)
      {
        var nextBpm:Float = readPsychFloat(section, "bpm", currentBpm);
        if (nextBpm > 0 && !Math.isNaN(nextBpm)) currentBpm = nextBpm;
      }

      events.push(new SongEventData(sectionStart, "PsychCompatibilityEvent", {
        name: "__PsychSectionState",
        curSection: index,
        mustHitSection: Reflect.field(section, "mustHitSection") == true,
        altAnim: Reflect.field(section, "altAnim") == true,
        gfSection: Reflect.field(section, "gfSection") == true
      }));

      var lengthInSteps:Float = readPsychFloat(section, "lengthInSteps", 16);
      if (lengthInSteps <= 0 || Math.isNaN(lengthInSteps)) lengthInSteps = 16;
      sectionStart += lengthInSteps * (60000.0 / currentBpm / 4.0);
    }
  }

  static function readPsychString(source:Dynamic, field:String, fallback:String):String
  {
    var value:Dynamic = source == null ? null : Reflect.field(source, field);
    if (value == null) return fallback;
    var result:String = StringTools.trim(Std.string(value));
    return result.length == 0 ? fallback : result;
  }

  #if sys
  /**
   * A small number of Psych packs ship a playable BF atlas but omit its
   * character JSON. Register only the known, complete GorillaFunkin BF
   * variants; do not guess for arbitrary missing player character IDs.
   */
  static function registerKnownPsychPlayerAtlasAlias(modPath:String, characterId:String):Bool
  {
    var atlasName:String;
    switch (characterId.toLowerCase())
    {
      case "bf capuchin": atlasName = "BoyCapuchin";
      case "bf capuchin run": atlasName = "BoyrunCapuchin";
      default: return false;
    }

    var charactersDirectory:String = Path.join([modPath, "images", "characters"]);
    var atlasPng:String = Path.join([charactersDirectory, atlasName + ".png"]);
    var atlasXml:String = Path.join([charactersDirectory, atlasName + ".xml"]);
    if (!FileSystem.exists(atlasPng) || !FileSystem.exists(atlasXml)) return false;

    var iconId:String = "bfcapuchin";
    var iconPath:String = Path.join([modPath, "images", "icons", "icon-" + iconId + ".png"]);
    if (!FileSystem.exists(iconPath)) iconId = "bf";

    // The atlas contains the regular BF idle/sing/miss prefixes. Use the
    // canonical Psych BF offsets as a safe baseline; precise per-animation
    // alignment cannot be recovered because the package omitted the JSON.
    var animations:Array<Dynamic> = [
      {anim: "idle", name: "idle", fps: 24, loop: false, offsets: [-5, 0]},
      {anim: "singLEFT", name: "left", fps: 24, loop: false, offsets: [5, -6]},
      {anim: "singDOWN", name: "down", fps: 24, loop: false, offsets: [-20, -51]},
      {anim: "singUP", name: "up", fps: 24, loop: false, offsets: [-46, 27]},
      {anim: "singRIGHT", name: "right", fps: 24, loop: false, offsets: [-48, -7]},
      {anim: "singLEFTmiss", name: "leftmiss", fps: 24, loop: false, offsets: [7, 19]},
      {anim: "singDOWNmiss", name: "downmiss", fps: 24, loop: false, offsets: [-15, -19]},
      {anim: "singUPmiss", name: "upmiss", fps: 24, loop: false, offsets: [-46, 27]},
      {anim: "singRIGHTmiss", name: "rightmiss", fps: 24, loop: false, offsets: [-44, 22]}
    ];

    // Only the non-running Capuchin atlas includes a hey animation.
    if (atlasName == "BoyCapuchin")
      animations.push({anim: "hey", name: "hey", fps: 24, loop: false, offsets: [-3, 5]});

    var raw:Dynamic = {
      image: "characters/" + atlasName,
      animations: animations,
      position: [0, 350],
      healthicon: iconId,
      flip_x: true,
      camera_position: [0, 0],
      sing_duration: 4,
      scale: 1,
      no_antialiasing: false
    };

    var converted:Null<CharacterData> = convertPsychCharacterData(characterId, raw);
    if (converted == null || !CharacterDataParser.registerModCharacterData(characterId, converted))
      return CharacterDataParser.fetchCharacterData(characterId) != null;

    trace('[Psych Compatibility] Registered missing player JSON for "' + characterId
      + '" from bundled atlas "' + atlasName + '" using baseline BF animation offsets.');
    return true;
  }
  #end

  static function resolvePsychPlayerCharacter(modPath:String, requestedId:String):String
  {
    var normalized:String = requestedId == null ? "" : StringTools.trim(requestedId);
    if (normalized.length == 0 || normalized.toLowerCase() == "bf" || normalized.toLowerCase() == "boyfriend")
      return "bf";

    if (hasPsychCharacterDataFile(modPath, normalized)
      || CharacterDataParser.fetchCharacterData(normalized) != null)
      return normalized;

    #if sys
    if (registerKnownPsychPlayerAtlasAlias(modPath, normalized)) return normalized;
    #end

    trace('[Psych Compatibility] Player character "' + normalized
      + '" is not bundled or registered; using NovaBeat BF for this song.');
    return "bf";
  }

  static function buildNativeSong(songId:String, source:PsychSongSource):Null<Song>
  {
    var modPath:String = Path.normalize(Path.directory(Path.directory(source.dataPath)));
    var metadata:Null<SongMetadata> = null;
    var psychPlayerId:String = "bf";
    var psychGirlfriendId:String = "gf";
    var psychOpponentId:String = "dad";
    var combinedNotes:Map<String, Array<funkin.data.song.SongData.SongNoteData>> = [];
    var combinedSpeeds:Map<String, Float> = [];
    var combinedEvents:Array<funkin.data.song.SongData.SongEventData> = [];
    var hasEmbeddedEvents:Bool = false;
    var hasPsychSectionStates:Bool = false;
    var firstDifficulty:String = Constants.DEFAULT_DIFFICULTY;
    var hasFirstDifficulty:Bool = false;

    for (chartPath in source.chartFiles)
    {
      var chartRoot:Dynamic = Json.parse(File.getContent(chartPath));
      var difficultyName:String = getDifficultyName(source.songFolder, Path.withoutExtension(Path.withoutDirectory(chartPath)));
      if (!hasFirstDifficulty)
      {
        firstDifficulty = difficultyName;
        hasFirstDifficulty = true;
      }

      if (isPsychV2ChartRoot(chartRoot))
      {
        var importedV2:Null<PsychV2ChartImport> = convertPsychV2Chart(
          chartRoot, source.dataPath, difficultyName, source.songFolder
        );
        if (importedV2 == null) continue;
        var v2StageName:String = readPsychString(getPsychChartMetadata(chartRoot), "stage",
          readPsychString(chartRoot, "stage", ""));
        if (v2StageName.length > 0)
        {
          psychSongStageNames.set(songId, v2StageName);
          psychSongModRoots.set(songId, Path.normalize(modPath));
        }
        hasPsychSectionStates = true;
        if (extractPsychEvents(Reflect.field(chartRoot, "events")).length > 0) hasEmbeddedEvents = true;
        if (metadata == null)
        {
          metadata = importedV2.metadata;
          psychPlayerId = resolvePsychPlayerCharacter(modPath, importedV2.player);
          psychGirlfriendId = importedV2.girlfriend;
          psychOpponentId = importedV2.opponent;
        }
        combinedNotes.set(difficultyName, importedV2.notes);
        combinedSpeeds.set(difficultyName, importedV2.speed);
        if (combinedEvents.length == 0)
        {
          for (event in importedV2.events) combinedEvents.push(event);
        }
        else
        {
          for (event in importedV2.events)
            if (!combinedEvents.contains(event)) combinedEvents.push(event);
        }
        continue;
      }

      var legacy:Null<FNFLegacyData> = parseLegacyChart(chartPath);
      if (legacy == null || legacy.song == null || legacy.song.notes == null) continue;
      var chartSong:Dynamic = Reflect.field(chartRoot, "song");
      if (extractPsychEvents(Reflect.field(chartSong, "events")).length > 0) hasEmbeddedEvents = true;
      if (!hasPsychSectionStates)
      {
        var rawLegacyNotes:Dynamic = Reflect.field(chartSong, "notes");
        var rawSections:Dynamic = rawLegacyNotes;
        if (!Std.isOfType(rawLegacyNotes, Array)) rawSections = Reflect.field(rawLegacyNotes, difficultyName);
        if (Std.isOfType(rawSections, Array))
        {
          appendPsychSectionStateEvents(cast rawSections, readPsychFloat(chartSong, "bpm", Constants.DEFAULT_BPM), combinedEvents);
          hasPsychSectionStates = true;
        }
      }
      var importedMetadata:SongMetadata = FNFLegacyImporter.migrateMetadata(legacy, difficultyName);
      var importedChart:SongChartData = FNFLegacyImporter.migrateChartData(legacy, difficultyName);

      if (metadata == null)
      {
        metadata = importedMetadata;
        psychPlayerId = resolvePsychPlayerCharacter(modPath, readPsychString(chartSong, "player1", "bf"));
        psychOpponentId = readPsychString(chartSong, "player2", "dad");
        psychGirlfriendId = readPsychString(chartSong, "gfVersion", readPsychString(chartSong, "player3", "gf"));
      }

      var stageName:String = readPsychString(chartSong, "stage", readPsychString(chartSong, "stageDefault", ""));
      if (stageName.length > 0)
      {
        psychSongStageNames.set(songId, stageName);
        psychSongModRoots.set(songId, Path.normalize(Path.directory(Path.directory(source.dataPath))));
      }
      importedMetadata.playData.stage = resolvePsychStage(stageName, source.songFolder);
      if (metadata == importedMetadata) metadata.playData.stage = resolvePsychStage(stageName, source.songFolder);
      importedMetadata.playData.characters = new SongCharacterData(psychPlayerId, psychGirlfriendId, psychOpponentId);

      for (difficulty in importedChart.notes.keys())
      {
        var importedNotes:Array<funkin.data.song.SongData.SongNoteData> = importedChart.getNotes(difficulty);
        for (note in importedNotes)
        {
          if (note.kind != null && note.kind.length > 0)
            note.kind = normalizePsychNoteType(note.kind);
        }

        // FNFLegacyImporter ignores Psych's gfSection flag; reapply it using
        // the same flattened note order and legacy lane flip after conversion.
        var rawLegacyNotes:Dynamic = Reflect.field(chartSong, "notes");
        var rawDifficultySections:Dynamic = rawLegacyNotes;
        if (!Std.isOfType(rawLegacyNotes, Array))
          rawDifficultySections = Reflect.field(rawLegacyNotes, difficulty);
        if (Std.isOfType(rawDifficultySections, Array))
          applyPsychGFSectionOwnership(cast rawDifficultySections, importedNotes);

        combinedNotes.set(difficulty, importedNotes);
        combinedSpeeds.set(difficulty, importedChart.getScrollSpeed(difficulty));
      }
      if (combinedEvents.length == 0)
      {
        for (event in importedChart.events) combinedEvents.push(event);
      }
      for (event in extractPsychEvents(Reflect.field(chartSong, "events")))
      {
        combinedEvents.push(new SongEventData(event.time, "PsychCompatibilityEvent", {
          name: event.name, value1: event.value1, value2: event.value2
        }));
      }
    }

    // Chart-embedded events take precedence. A standalone events file is a
    // fallback for charts that do not carry their own event data.
    if (!hasEmbeddedEvents && hasFirstDifficulty)
    {
      var eventsPath:Null<String> = findPsychEventFile(source.dataPath, firstDifficulty);
      if (eventsPath != null)
      {
        try
        {
          var externalEvents:Dynamic = Json.parse(File.getContent(eventsPath));
          for (event in extractPsychEvents(externalEvents))
          {
            combinedEvents.push(new SongEventData(event.time, "PsychCompatibilityEvent", {
              name: event.name, value1: event.value1, value2: event.value2
            }));
          }
        }
        catch (error:Dynamic)
        {
          trace('[Psych Compatibility] Could not import events from ' + eventsPath + ': ' + Std.string(error));
        }
      }
    }

    if (metadata == null || !combinedNotes.keys().hasNext()) return null;
    metadata.variation = Constants.DEFAULT_VARIATION;
    metadata.generatedBy = "NovaBeat Psych compatibility";
    metadata.playData.songVariations = [];
    metadata.playData.difficulties = [for (difficulty in combinedNotes.keys()) difficulty];
    metadata.playData.characters = new SongCharacterData(psychPlayerId, psychGirlfriendId, psychOpponentId);
    if (metadata.playData.stage == null || metadata.playData.stage.length == 0)
      metadata.playData.stage = Constants.DEFAULT_STAGE;
    metadata.playData.noteStyle = Constants.DEFAULT_NOTE_STYLE;
    for (difficulty in metadata.playData.difficulties)
      metadata.playData.ratings.set(difficulty, 0);

    var chart:SongChartData = new SongChartData(combinedSpeeds, combinedEvents, combinedNotes);
    var charts:Map<String, SongChartData> = [];
    charts.set(Constants.DEFAULT_VARIATION, chart);
    return Song.buildRaw(songId, [metadata], Constants.DEFAULT_VARIATION, charts, false, false);
  }

  static function convertPsychV2Chart(chartRoot:Dynamic, dataPath:String, difficultyName:String,
      songFolder:String):Null<PsychV2ChartImport>
  {
    if (!isPsychV2ChartRoot(chartRoot)) return null;

    var embeddedMetadata:Dynamic = getPsychChartMetadata(chartRoot);
    var externalMetadataPath:String = Path.join([dataPath, "metadata-" + difficultyName + ".json"]);
    if (!FileSystem.exists(externalMetadataPath))
      externalMetadataPath = Path.join([dataPath, "metadata.json"]);
    var externalMetadata:Dynamic = null;
    if (FileSystem.exists(externalMetadataPath) && !FileSystem.isDirectory(externalMetadataPath))
    {
      try externalMetadata = Json.parse(File.getContent(externalMetadataPath)) catch (error:Dynamic)
      {
        trace('[Psych Compatibility] Could not parse ' + externalMetadataPath + ': ' + Std.string(error));
      }
    }

    var meta:Dynamic = {};
    if (externalMetadata != null)
      for (field in Reflect.fields(externalMetadata)) Reflect.setField(meta, field, Reflect.field(externalMetadata, field));
    if (embeddedMetadata != null)
      for (field in Reflect.fields(embeddedMetadata)) Reflect.setField(meta, field, Reflect.field(embeddedMetadata, field));

    var songName:String = readPsychString(meta, "songName", readPsychString(meta, "song", songFolder));
    var artist:String = readPsychString(meta, "artist", Constants.DEFAULT_ARTIST);
    var charter:String = readPsychString(meta, "charter", Constants.DEFAULT_CHARTER);
    var bpm:Float = readPsychFloat(meta, "bpm", Constants.DEFAULT_BPM);
    var speed:Float = readPsychFloat(meta, "speed", 1.0);
    if (Math.isNaN(bpm) || bpm <= 0) bpm = Constants.DEFAULT_BPM;
    if (Math.isNaN(speed) || speed <= 0) speed = 1.0;

    var lines:Array<Dynamic> = cast Reflect.field(chartRoot, "strumlines");
    var player:String = "bf";
    var opponent:String = "dad";
    var girlfriend:String = "gf";
    for (line in lines)
    {
      var role:Int = psychStrumLineRole(line);
      var chars:Dynamic = Reflect.field(line, "characters");
      if (!Std.isOfType(chars, Array) || (cast chars:Array<Dynamic>).length == 0) continue;
      var character:String = StringTools.trim(Std.string((cast chars:Array<Dynamic>)[0]));
      if (character.length == 0) continue;
      if (role == 0) player = character;
      else if (role == 1) opponent = character;
      else if (girlfriend == "gf") girlfriend = character;
    }

    var metadata:SongMetadata = new SongMetadata(songName, artist, charter, Constants.DEFAULT_VARIATION);
    metadata.timeChanges = [new funkin.data.song.SongData.SongTimeChange(0, bpm)];
    metadata.playData.stage = resolvePsychStage(readPsychString(meta, "stage", ""), songFolder);
    metadata.playData.characters = new SongCharacterData(player, girlfriend, opponent);

    var notes:Array<funkin.data.song.SongData.SongNoteData> = [];
    var rawNotes:Array<Dynamic> = cast Reflect.field(chartRoot, "notes");
    for (note in rawNotes)
    {
      if (note == null) continue;
      var lineIndex:Int = Std.int(Reflect.field(note, "s"));
      var column:Int = Std.int(Reflect.field(note, "d"));
      if (lineIndex < 0 || lineIndex >= lines.length || column < 0 || column > 3) return null;
      var role:Int = psychStrumLineRole(lines[lineIndex]);
      if (role < 0) return null;
      var data:Int = column + (role == 0 ? 0 : 4);
      var noteTime:Float = readPsychFloat(note, "t", 0);
      var noteLength:Float = readPsychFloat(note, "l", 0);
      var kind:String = readPsychString(note, "k", readPsychString(note, "type", ""));
      if (kind.length == 0 && Reflect.field(note, "a") == true) kind = "alt";
      if (Reflect.field(note, "g") == true || Reflect.field(note, "gfNote") == true)
        kind = normalizePsychGFSectionNoteType(kind);
      else
        kind = normalizePsychNoteType(kind);
      notes.push(new funkin.data.song.SongData.SongNoteData(noteTime, data, noteLength, kind));
    }

    var events:Array<funkin.data.song.SongData.SongEventData> = [];
    for (event in extractPsychEvents(Reflect.field(chartRoot, "events")))
    {
      events.push(new SongEventData(event.time, "PsychCompatibilityEvent", {
        name: event.name, value1: event.value1, value2: event.value2
      }));
    }

    var sections:Dynamic = Reflect.field(chartRoot, "sections");
    var sectionStart:Float = 0;
    var currentBpm:Float = bpm;
    if (Std.isOfType(sections, Array))
    {
      var lastCameraChar:Int = -1;
      var sectionList:Array<Dynamic> = cast sections;
      for (sectionIndex in 0...sectionList.length)
      {
        var section:Dynamic = sectionList[sectionIndex];
        if (section == null) continue;
        events.push(new SongEventData(sectionStart, "PsychCompatibilityEvent", {
          name: "__PsychSectionState",
          curSection: sectionIndex,
          mustHitSection: Reflect.field(section, "mustHitSection") == true,
          altAnim: Reflect.field(section, "altAnim") == true,
          gfSection: Reflect.field(section, "gfSection") == true
        }));
        if (Reflect.field(section, "changeBPM") == true)
        {
          var nextBpm:Float = readPsychFloat(section, "bpm", currentBpm);
          if (nextBpm > 0 && !Math.isNaN(nextBpm))
          {
            currentBpm = nextBpm;
            metadata.timeChanges.push(new funkin.data.song.SongData.SongTimeChange(sectionStart, currentBpm));
          }
        }

        var beats:Float = readPsychFloat(section, "beats", 0);
        var denominator:Int = 4;
        var signature:Dynamic = Reflect.field(section, "timeSignature");
        if (Std.isOfType(signature, Array))
        {
          var values:Array<Dynamic> = cast signature;
          if (values.length > 0 && (beats <= 0 || Math.isNaN(beats)))
            beats = Std.parseFloat(Std.string(values[0]));
          if (values.length > 1) denominator = Std.int(values[1]);
        }
        if (beats <= 0 || Math.isNaN(beats)) beats = 4;
        if (denominator <= 0) denominator = 4;

        var cameraTarget:Dynamic = Reflect.field(section, "cameraTarget");
        if (cameraTarget != null)
        {
          var target:Int = Std.int(cameraTarget);
          if (target >= 0 && target < lines.length)
          {
            var cameraRole:Int = psychStrumLineRole(lines[target]);
            if (cameraRole >= 0)
            {
              var cameraChar:Int = cameraRole == 0 ? 0 : 1;
              if (cameraChar != lastCameraChar)
              {
                events.push(new SongEventData(sectionStart, "FocusCamera", {char: cameraChar}));
                lastCameraChar = cameraChar;
              }
            }
          }
        }
        sectionStart += beats * (4.0 / denominator) * (60000.0 / currentBpm);
      }
    }

    return {
      metadata: metadata,
      notes: notes,
      speed: speed,
      events: events,
      player: player,
      girlfriend: girlfriend,
      opponent: opponent
    };
  }

  static function readPsychFloat(source:Dynamic, field:String, fallback:Float):Float
  {
    var value:Dynamic = source == null ? null : Reflect.field(source, field);
    if (value == null) return fallback;
    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? fallback : parsed;
  }

  /**
   * Synthetic regression test for the supported psych_v2 chart subset.
   * Exposed to the debug console so it can be run without an uploaded mod.
   */
  public static function runPsychV2SmokeTests():Bool
  {
    #if sys
    try
    {
      // Psych image fields may include the physical images/ prefix and file
      // extension even though NovaBeat's Paths helpers add both themselves.
      if (normalizePsychImageKey("images/characters/Gorilla.png") != "characters/Gorilla") return false;
      if (normalizePsychImageKey("assets/images/stages/forestback.png") != "stages/forestback") return false;
      if (normalizePsychImageKey("../outside.png") != "") return false;

      var fixture:Dynamic = Json.parse(
        '{"metadata":{"songName":"NovaBeat Psych v2 Smoke Test","artist":"Test","charter":"Test","bpm":100,"speed":1,"stage":"philly"},' +
        '"strumlines":[{"type":0,"characters":["dad"],"keyCount":4},{"type":1,"characters":["bf"],"keyCount":4}],' +
        '"notes":[{"t":500,"s":0,"d":1,"l":250},{"t":1000,"s":1,"d":2,"a":true},' +
        '{"t":1250,"s":0,"d":3,"k":"Alt Animation"},{"t":1500,"s":1,"d":3,"k":"No Animation"},' +
        '{"t":1750,"s":0,"d":0,"k":"Hey!"},{"t":2000,"s":1,"d":0,"k":"GF Sing"},' +
        '{"t":2250,"s":1,"d":2,"k":"Hurt Note"},' +
        '{"t":2500,"s":0,"d":2,"g":true},{"t":2750,"s":1,"d":3,"k":"Alt Animation","g":true}],' +
        '"events":[{"t":750,"e":"Add Camera Zoom","v":["0.02","0.03"]},' +
        '{"t":1800,"e":"Change Scroll Speed","v":["1.5","2"]}],' +
        '"sections":[{"timeSignature":[3,4],"cameraTarget":1},{"changeBPM":true,"bpm":120,"timeSignature":[3,4],"cameraTarget":0}]}'
      );

      var converted:Null<PsychV2ChartImport> = convertPsychV2Chart(
        fixture,
        Path.join(["mods", "__novabeat_psych_v2_smoke__", "songs", "smoke-test"]),
        "normal",
        "smoke-test"
      );
      if (converted == null) return false;
      if (converted.notes.length != 9) return false;
      if (converted.notes[0].data != 5 || converted.notes[0].length != 250) return false;
      if (converted.notes[1].data != 2 || converted.notes[1].kind != "alt") return false;
      if (converted.notes[2].kind != "alt" || converted.notes[3].kind != "noanim") return false;
      if (converted.notes[4].kind != "psychhey" || converted.notes[5].kind != "psychgfsing") return false;
      if (converted.notes[6].kind != "psychhurt") return false;
      if (converted.notes[7].kind != "psychgfsection" || converted.notes[8].kind != "psychgfsectionalt") return false;
      if (!isSupportedBuiltinPsychNoteType("Alt")
        || !isSupportedBuiltinPsychNoteType("Alt Animation")
        || !isSupportedBuiltinPsychNoteType("No Animation")
        || !isSupportedBuiltinPsychNoteType("Hey!")
        || !isSupportedBuiltinPsychNoteType("GF Sing")
        || !isSupportedBuiltinPsychNoteType("Hurt Note")) return false;
      if (converted.metadata.playData.stage != "phillyTrain") return false;
      if (converted.metadata.timeChanges.length != 2) return false;
      if (Math.abs(converted.metadata.timeChanges[1].timeStamp - 1800) > 0.01) return false;
      if (converted.metadata.timeChanges[1].bpm != 120) return false;
      if (converted.events.length != 6) return false;
      var v2SectionState:Null<SongEventData> = converted.events.find(function(event:SongEventData)
      {
        return Reflect.field(event.value, "name") == "__PsychSectionState"
          && Reflect.field(event.value, "curSection") == 1;
      });
      if (v2SectionState == null || v2SectionState.time != 1800) return false;
      if (!isSupportedBuiltinPsychEvent("Change Scroll Speed")) return false;
      if (getPsychNoteTypeName("psychhey") != "Hey!"
        || getPsychNoteTypeName("psychgfsing") != "GF Sing"
        || getPsychNoteTypeName("psychhurt") != "Hurt Note"
        || getPsychNoteTypeName("psychgfsection") != ""
        || getPsychNoteTypeName("psychgfsectionalt") != "Alt Animation"
        || getPsychNoteTypeName("alt") != "Alt Animation"
        || getPsychNoteTypeName("noanim") != "No Animation") return false;

      // Ensure the normalized Psych built-ins resolve to concrete native note-kind classes.
      var heyKindClass:Null<Class<Dynamic>> = Type.resolveClass("funkin.play.notes.notekind.PsychHeyNoteKind");
      var gfSingKindClass:Null<Class<Dynamic>> = Type.resolveClass("funkin.play.notes.notekind.PsychGFSingNoteKind");
      var altKindClass:Null<Class<Dynamic>> = Type.resolveClass("funkin.play.notes.notekind.AltAnimNoteKind");
      var hurtKindClass:Null<Class<Dynamic>> = Type.resolveClass("funkin.play.notes.notekind.PsychHurtNoteKind");
      var gfSectionKindClass:Null<Class<Dynamic>> = Type.resolveClass("funkin.play.notes.notekind.PsychGFSectionNoteKind");
      var gfSectionAltKindClass:Null<Class<Dynamic>> = Type.resolveClass("funkin.play.notes.notekind.PsychGFSectionAltNoteKind");
      if (heyKindClass == null || gfSingKindClass == null || altKindClass == null || hurtKindClass == null
        || gfSectionKindClass == null || gfSectionAltKindClass == null) return false;
      var heyKind:Dynamic = Type.createInstance(heyKindClass, []);
      var gfSingKind:Dynamic = Type.createInstance(gfSingKindClass, []);
      var hurtKind:Dynamic = Type.createInstance(hurtKindClass, []);
      var gfSectionKind:Dynamic = Type.createInstance(gfSectionKindClass, []);
      var gfSectionAltKind:Dynamic = Type.createInstance(gfSectionAltKindClass, []);
      if (Reflect.field(heyKind, "hey") != true || Reflect.field(gfSingKind, "gfSing") != true
        || Reflect.field(hurtKind, "hurt") != true || Reflect.field(hurtKind, "scoreable") != false
        || Reflect.field(gfSectionKind, "gfSing") != true
        || Reflect.field(gfSectionAltKind, "gfSing") != true
        || Reflect.field(gfSectionAltKind, "suffix") != "alt") return false;
      if (!isSupportedPsychGFSectionNoteType("")
        || !isSupportedPsychGFSectionNoteType("Alt Animation")
        || !isSupportedPsychGFSectionNoteType("GF Sing")
        || isSupportedPsychGFSectionNoteType("Hurt Note")) return false;

      // Exercise the psych_v1 raw-section adapter separately from psych_v2.
      var legacyGFNotes:Array<funkin.data.song.SongData.SongNoteData> = [
        new funkin.data.song.SongData.SongNoteData(500, 0, 0, ""),
        new funkin.data.song.SongData.SongNoteData(1000, 1, 0, "alt")
      ];
      var legacyGFFirstRow:Array<Dynamic> = [500, 0, 0, ""];
      var legacyGFSecondRow:Array<Dynamic> = [1000, 1, 0, true];
      var legacyGFSectionRows:Array<Dynamic> = [legacyGFFirstRow, legacyGFSecondRow];
      var legacyGFSections:Array<Dynamic> = [
        {mustHitSection: true, gfSection: true, sectionNotes: legacyGFSectionRows}
      ];
      applyPsychGFSectionOwnership(legacyGFSections, legacyGFNotes);
      if (legacyGFNotes[0].kind != "psychgfsection" || legacyGFNotes[1].kind != "psychgfsectionalt") return false;

      var legacySectionEvents:Array<SongEventData> = [];
      appendPsychSectionStateEvents([
        {mustHitSection: true, altAnim: true, gfSection: false, lengthInSteps: 8},
        {mustHitSection: false, altAnim: false, gfSection: true, lengthInSteps: 16, changeBPM: true, bpm: 200}
      ], 100, legacySectionEvents);
      if (legacySectionEvents.length != 2 || legacySectionEvents[1].time != 1200) return false;
      if (Reflect.field(legacySectionEvents[0].value, "mustHitSection") != true
        || Reflect.field(legacySectionEvents[0].value, "altAnim") != true
        || Reflect.field(legacySectionEvents[1].value, "gfSection") != true
        || Reflect.field(legacySectionEvents[1].value, "curSection") != 1) return false;

      // The additional/GF strumline must never be misread as an opponent lane.
      if (psychStrumLineRole({type: 2, isPlayer: false}) != -1) return false;
      if (resolvePsychStage("a-custom-psych-stage", "smoke-test") != Constants.DEFAULT_STAGE) return false;
      if (!runNestedPackageRootSmokeTest()) return false;
      return true;
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] psych_v2 smoke test failed: ' + Std.string(error));
      return false;
    }
    #else
    return false;
    #end
  }

  /**
   * Regression test for mods extracted as an archive wrapper containing
   * mods/<actual-mod>/. This mirrors the folder shape already accepted by
   * EngineBridge's Psych detector and verifies the runtime resolves the same
   * inner package root before scanning charts.
   */
  static function runNestedPackageRootSmokeTest():Bool
  {
    var tempParent:Null<String> = Sys.getEnv("TEMP");
    if (tempParent == null || tempParent.length == 0) tempParent = Sys.getEnv("TMPDIR");
    if (tempParent == null || tempParent.length == 0) tempParent = Sys.getCwd();

    var tempRoot:String = Path.join([tempParent, "novabeat-psych-smoke-" + Std.string(Std.random(0x7FFFFFFF))]);
    var wrappedRoot:String = Path.join([tempRoot, "mods", "wrapped"]);
    var contentRoot:String = Path.join([wrappedRoot, "mods", "actual-mod"]);
    var chartFolder:String = Path.join([contentRoot, "data", "smoke-song"]);

    var passed:Bool = false;
    try
    {
      createSmokeDirectoryTree(chartFolder);
      File.saveContent(Path.join([chartFolder, "smoke-song.json"]),
        '{"song":{"song":"smoke-song","notes":[],"bpm":100}}');

      var resolved:String = resolvePsychContentRoot(wrappedRoot);
      passed = Path.normalize(resolved) == Path.normalize(contentRoot);
    }
    catch (error:Dynamic)
    {
      trace('[Psych Compatibility] Nested package root smoke test failed: ' + Std.string(error));
      passed = false;
    }

    // Haxe has no try/finally construct; clean up after either result path.
    deleteSmokeDirectoryTree(tempRoot);
    return passed;
  }

  static function createSmokeDirectoryTree(path:String):Void
  {
    if (path == null || path.length == 0 || FileSystem.exists(path)) return;
    var parent:String = Path.directory(path);
    if (parent != null && parent.length > 0 && parent != path) createSmokeDirectoryTree(parent);
    if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
  }

  static function deleteSmokeDirectoryTree(path:String):Void
  {
    if (path == null || path.length == 0 || !FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;
    for (entry in FileSystem.readDirectory(path))
    {
      var child:String = Path.join([path, entry]);
      if (FileSystem.isDirectory(child)) deleteSmokeDirectoryTree(child);
      else FileSystem.deleteFile(child);
    }
    FileSystem.deleteDirectory(path);
  }

  static function findAudioFolder(modPath:String, songFolder:String):Null<String>
  {
    // Psych charts store a data-folder name, while their audio may live in
    // songs/<folder> or assets/songs/<folder>. Match the physical directory
    // case-insensitively instead of deriving it from the generated song ID.
    var roots:Array<String> = [
      Path.join([modPath, "songs"]),
      Path.join([modPath, "assets", "songs"])
    ];

    for (root in roots)
    {
      if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) continue;

      for (entry in FileSystem.readDirectory(root))
      {
        if (entry.toLowerCase() != songFolder.toLowerCase()) continue;

        var candidate:String = Path.join([root, entry]);
        if (FileSystem.exists(candidate) && FileSystem.isDirectory(candidate))
          return Path.normalize(FileSystem.fullPath(candidate));
      }
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
    // Referenced custom_events and custom_notetypes are loaded by name.
    // The remaining Psych script roots still require unsupported state/asset
    // lifecycle adapters and are deliberately rejected.
    var roots:Array<String> = [
      "custom_notes"
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
  public static function runPsychV2SmokeTests():Bool return false;
  #end

  static function findSongAsset(audioFolder:String, baseName:String):Null<String>
  {
    #if sys
    if (audioFolder == null || StringTools.trim(audioFolder).length == 0) return null;

    // Resolve stems only inside the directory discovered for this Psych
    // package. Never synthesize a songs:<song-id> asset-library key.
    var fileCandidates:Array<String> = [baseName + ".ogg", baseName + ".mp3", baseName + ".wav"];
    for (fileName in fileCandidates)
    {
      var candidate:String = Path.join([audioFolder, fileName]);
      if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate))
        return Path.normalize(FileSystem.fullPath(candidate));
    }
    #end

    return null;
  }
}

typedef PsychV2ChartImport =
{
  var metadata:SongMetadata;
  var notes:Array<funkin.data.song.SongData.SongNoteData>;
  var speed:Float;
  var events:Array<funkin.data.song.SongData.SongEventData>;
  var player:String;
  var girlfriend:String;
  var opponent:String;
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

typedef PsychRawEvent =
{
  var time:Float;
  var name:String;
  var value1:String;
  var value2:String;
}
