package funkin.modding.psychlua;

import flixel.FlxSubState;
import funkin.play.PlayState;

/**
 * Minimal named Psych custom substate. It reuses the same script instances and
 * gameplay API as the owning song while exposing Psych's custom-substate
 * lifecycle callbacks.
 */
@:nullSafety(Off)
class PsychCustomSubState extends FlxSubState
{
  public final substateName:String;
  final playState:PlayState;

  public function new(name:String, owner:PlayState)
  {
    super();
    substateName = name;
    playState = owner;
  }

  override public function create():Void
  {
    super.create();
    PsychScriptRuntime.setOnScripts("customSubstate", this);
    PsychScriptRuntime.setOnScripts("customSubstateName", substateName);
    PsychScriptRuntime.dispatch("onCustomSubstateCreate", [substateName]);
    PsychScriptRuntime.dispatch("onCustomSubstateCreatePost", [substateName]);
  }

  override public function update(elapsed:Float):Void
  {
    PsychScriptRuntime.dispatch("onCustomSubstateUpdate", [substateName, elapsed]);
    super.update(elapsed);
    PsychScriptRuntime.dispatch("onCustomSubstateUpdatePost", [substateName, elapsed]);
  }

  override public function destroy():Void
  {
    PsychScriptRuntime.dispatch("onCustomSubstateDestroy", [substateName]);
    PsychScriptRuntime.setOnScripts("customSubstate", null);
    PsychScriptRuntime.setOnScripts("customSubstateName", "");
    PsychScriptRuntime.unloadCustomSubstateScripts();
    PsychGameplayApi.finishCustomSubstate(this);
    if (playState != null) playState.persistentUpdate = true;
    super.destroy();
  }
}
