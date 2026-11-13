package funkin.play.character;

import funkin.modding.events.ScriptEvent;
import funkin.util.assets.FlxAnimationUtil;
import flixel.graphics.frames.FlxFramesCollection;
import funkin.data.character.CharacterData.CharacterRenderType;
import funkin.modding.PsychModRuntime;

/**
 * A SparrowCharacter is a Character which is rendered by
 * displaying an animation derived from a SparrowV2 atlas spritesheet file.
 *
 * BaseCharacter has game logic, SparrowCharacter has only rendering logic.
 * KEEP THEM SEPARATE!
 */
class SparrowCharacter extends BaseCharacter
{
  public function new(id:String)
  {
    super(id, CharacterRenderType.Sparrow);
  }

  override function onCreate(event:ScriptEvent):Void
  {
    // Display a custom scope for debugging purposes.
    #if FEATURE_DEBUG_TRACY
    cpp.vm.tracy.TracyProfiler.zoneScoped('SparrowCharacter.create(${this.characterId})');
    #end

    loadSpritesheet();
    loadAnimations();

    super.onCreate(event);
  }

  function loadSpritesheet()
  {
    trace('Loading assets for Sparrow character "${characterId}"', flixel.util.FlxColor.fromString("#89CFF0"));

    try
    {
      var tex:FlxFramesCollection = Paths.getSparrowAtlas(_data.assetPath);
      if (tex == null)
      {
        PsychModRuntime.logActiveAssetPipelineStep("character.atlas.empty",
          "character=" + characterId + " atlas=" + _data.assetPath);
        trace('Could not load Sparrow sprite: ${_data.assetPath}');
        return;
      }

      this.frames = tex;
      PsychModRuntime.logActiveAssetPipelineStep("character.atlas.loaded",
        "character=" + characterId + " atlas=" + _data.assetPath + " loaded=true");
    }
    catch (error:Dynamic)
    {
      PsychModRuntime.logActiveAssetPipelineStep("character.atlas.failed",
        "character=" + characterId + " atlas=" + _data.assetPath + " error=" + Std.string(error));
      throw error;
    }

    if (_data.isPixel)
    {
      this.isPixel = true;
      this.antialiasing = false;
    }
    else
    {
      this.isPixel = false;
      this.antialiasing = true;
    }

    this.setScale(_data.scale);
  }

  function loadAnimations()
  {
    trace('[SPARROWCHAR] Loading ${_data.animations.length} animations for ${characterId}');

    FlxAnimationUtil.addAtlasAnimations(this, _data.animations);

    for (anim in _data.animations)
    {
      if (anim.offsets == null)
      {
        setAnimationOffsets(anim.name, 0, 0);
      }
      else
      {
        setAnimationOffsets(anim.name, anim.offsets[0], anim.offsets[1]);
      }
    }

    var animNames = this.animation.getNameList();
    trace('[SPARROWCHAR] Successfully loaded ${animNames.length} animations for ${characterId}');
  }
}
