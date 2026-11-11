package funkin.ui.story;

import funkin.util.SortUtil;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.play.song.Song;
import funkin.data.IRegistryEntry;
import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.data.story.level.LevelData;

/**
 * An object used to retrieve data about a story mode level (also known as "weeks").
 * Can be scripted to override each function, for custom behavior.
 */
class Level implements IRegistryEntry<LevelData>
{
  /**
   * @param id The ID of the JSON file to parse.
   */
  public function new(id:String, ?params:Dynamic)
  {
    this.id = id;
    var psychRuntimeData:Dynamic = params == null ? null : Reflect.field(params, "psychRuntimeData");
    _data = psychRuntimeData == null ? _fetchData(id) : cast psychRuntimeData;

    if (_data == null)
    {
      throw 'Could not parse level data for id: $id';
    }
  }

  /**
   * Get the list of songs in this level, as an array of IDs.
   * @return Array<String>
   */
  public function getSongs():Array<String>
  {
    // Copy the array so that it can't be modified on accident
    return _data.songs.copy();
  }

  /**
   * Retrieve the title of the level for display on the menu.
   * @return Title of the level as a string
   */
  public function getTitle():String
  {
    // TODO: Maybe add localization support?
    return _data.name;
  }

  /**
   * Retrieve the title of the level for display on a capsule.
   * @return Title of the capsule as a string
   */
  public function getCapsuleTitle():String
  {
    return _data.capsule?.name ?? null;
  }

  public function getCapsuleTitleOffsets():Array<Float>
  {
    return _data.capsule?.offsets ?? [0.0, 0.0];
  }

  /**
   * Construct the title graphic for the level.
   * @return The constructed graphic as a sprite.
   */
  public function buildTitleGraphic():FlxSprite
  {
    if (Reflect.field(_data, "psychImported") == true)
    {
      var title:FlxText = new FlxText(0, 0, 0, _data.name, 32);
      title.setFormat("VCR OSD Mono", 32, FlxColor.WHITE);
      title.updateHitbox();
      return title;
    }

    var result:FlxSprite = new FlxSprite().loadGraphic(Paths.image(_data.titleAsset));

    return result;
  }

  /**
   * Get the list of songs in this level, as an array of names, for display on the menu.
   * @param difficulty The difficulty of the level being displayed
   * @return The display names of the songs in this level
   */
  public function getSongDisplayNames(difficulty:String):Array<String>
  {
    var songList:Array<String> = getSongs() ?? [];
    var songNameList:Array<String> = songList.map(function(songId:String)
    {
      return getSongDisplayName(songId, difficulty);
    });
    return songNameList;
  }

  static function getSongDisplayName(songId:String, difficulty:String):String
  {
    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId, {variation: Constants.DEFAULT_VARIATION});
    if (song == null) return 'Unknown';

    return song.songName;
  }

  /**
   * Whether this level is unlocked. If not, it will be greyed out on the menu and have a lock icon.
   * Override this in a script.
   * @default `true`
   * @return Whether this level is unlocked
   */
  public function isUnlocked():Bool
  {
    var psychStartUnlocked:Dynamic = Reflect.field(_data, "psychStartUnlocked");
    return psychStartUnlocked == null ? true : psychStartUnlocked == true;
  }

  /**
   * Whether this level is visible. If not, it will not be shown on the menu at all.
   * Override this in a script.
   * @default `true`
   * @return Whether this level is visible in the menu
   */
  public function isVisible():Bool
  {
    return _data.visible;
  }

  /**
   * Build a sprite for the background of the level.
   * Can be overriden by ScriptedLevel. Not used if `isBackgroundSimple` returns true.
   * @return The constructed sprite
   */
  public function buildBackground():FlxSprite
  {
    if (!_data.background.startsWith('#'))
    {
      // A Psych week may refer to an image that is missing from the extracted
      // package. Never let a preview-only background asset crash Story Mode.
      try
      {
        var imagePath:String = Paths.image(_data.background);
        if (!Assets.exists(imagePath))
          throw 'Background image does not exist: ' + _data.background;
        return new FlxSprite().loadGraphic(imagePath);
      }
      catch (error:Dynamic)
      {
        trace('[Story Mode] Could not load background for week ' + id + ': ' + Std.string(error));
        return new FlxSprite().makeGraphic(FlxG.width, 400, FlxColor.fromRGB(32, 32, 32));
      }
    }

    // Color specified
    var result:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 400, FlxColor.WHITE);
    result.color = getBackgroundColor();
    return result;
  }

  /**
   * Returns true if the background is a solid color.
   * If you have a ScriptedLevel with a fancy background, you may want to override this to false.
   * @return Whether the background is a simple color
   */
  public function isBackgroundSimple():Bool
  {
    return _data.background.startsWith('#');
  }

  /**
   * Returns true if the background is a solid color.
   * If you have a ScriptedLevel with a fancy background, you may want to override this to false.
   * @return The background as a simple color. May not be valid if `isBackgroundSimple` returns false.
   */
  public function getBackgroundColor():FlxColor
  {
    return FlxColor.fromString(_data.background);
  }

  /**
   * The list of difficulties the player can select from for this level.
   * @return The difficulty IDs.
   */
  public function getDifficulties():Array<String>
  {
    var difficulties:Array<String> = [];

    var songList:Array<String> = getSongs();
    if (songList.length == 0) return [Constants.DEFAULT_DIFFICULTY];

    var firstSongId:String = songList[0];
    var firstSong:Null<Song> = SongRegistry.instance.fetchEntry(firstSongId, {variation: Constants.DEFAULT_VARIATION});

    if (firstSong != null)
    {
      // Don't display alternate characters in Story Mode. Only show `default` and `erect` variations.
      for (difficulty in firstSong.listDifficulties([Constants.DEFAULT_VARIATION, 'erect'], false, false))
      {
        difficulties.push(difficulty);
      }
    }

    // Sort in a specific order! Fall back to alphabetical.
    difficulties.sort(SortUtil.defaultsThenAlphabetically.bind(Constants.DEFAULT_DIFFICULTY_LIST));

    // Filter to only include difficulties that are present in all songs
    for (songIndex in 1...songList.length)
    {
      var songId:String = songList[songIndex];
      var song:Null<Song> = SongRegistry.instance.fetchEntry(songId, {variation: Constants.DEFAULT_VARIATION});

      if (song == null) continue;

      for (difficulty in difficulties.copy())
      {
        if (!song.hasDifficulty(difficulty, [Constants.DEFAULT_VARIATION, 'erect']))
        {
          difficulties.remove(difficulty);
        }
      }
    }

    var psychImported:Bool = Reflect.field(_data, "psychImported") == true;
    var rawPsychDifficulties:Dynamic = Reflect.field(_data, "psychDifficulties");
    if (psychImported && rawPsychDifficulties != null)
    {
      var requested:Array<String> = [];
      if (Std.isOfType(rawPsychDifficulties, String))
      {
        for (part in Std.string(rawPsychDifficulties).split(","))
        {
          var value:String = StringTools.trim(part);
          if (value.length > 0) requested.push(value.toLowerCase());
        }
      }
      else if (Std.isOfType(rawPsychDifficulties, Array))
      {
        for (part in (cast rawPsychDifficulties:Array<Dynamic>))
          if (part != null) requested.push(StringTools.trim(Std.string(part)).toLowerCase());
      }

      if (requested.length > 0)
      {
        var filtered:Array<String> = difficulties.filter(function(difficulty:String):Bool
        {
          return requested.indexOf(difficulty.toLowerCase()) >= 0;
        });
        if (filtered.length > 0) difficulties = filtered;
      }
    }

    if (difficulties.length == 0) difficulties = ['normal'];

    return difficulties;
  }

  /**
   * Build the props for display over the colored background.
   * @param existingProps The existing prop sprites, if any.
   * @return The constructed prop sprites
   */
  public function buildProps(?existingProps:Array<LevelProp>):Array<LevelProp>
  {
    var props:Array<LevelProp> = existingProps == null ? [] : [for (x in existingProps) x];

    // A level with no props must still retire props from the previously
    // selected week; otherwise stale sprites can remain in the camera draw list.
    if (_data.props.length == 0)
    {
      for (prop in props)
      {
        if (prop == null) continue;
        prop.visible = false;
        prop.active = false;
      }
      return props;
    }

    // Hide surplus entries before rebuilding the active set.
    for (i in _data.props.length...props.length)
    {
      props[i].visible = false;
      props[i].active = false;
    }

    for (propIndex in 0..._data.props.length)
    {
      var propData:LevelPropData = _data.props[propIndex];
      var existingProp:Null<LevelProp> = propIndex < props.length ? props[propIndex] : null;

      // Reuse only a live sprite with the same underlying asset. Replacing a
      // destroyed sprite (or one whose texture changes) avoids queuing stale
      // frames in FunkinCamera after switching weeks.
      if (existingProp != null && existingProp.exists && existingProp.propData != null
        && existingProp.propData.assetPath == propData.assetPath)
      {
        existingProp.propData = propData;
        existingProp.visible = true;
        existingProp.active = true;
        existingProp.x = propData.offsets[0] + FlxG.width * 0.25 * propIndex;
      }
      else
      {
        if (existingProp != null)
        {
          existingProp.visible = false;
          existingProp.active = false;
        }

        var propSprite:Null<LevelProp> = LevelProp.build(propData);
        if (propSprite == null) continue;

        propSprite.x = propData.offsets[0] + FlxG.width * 0.25 * propIndex;
        if (propIndex < props.length)
          props[propIndex] = propSprite;
        else
          props.push(propSprite);
      }
    }

    return props;
  }}
