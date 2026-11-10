package funkin.play.event;

import funkin.data.song.SongData.SongEventData;
import funkin.Conductor;
import funkin.modding.psychlua.PsychScriptRuntime;
import funkin.modding.psychlua.PsychGameplayApi;
import funkin.play.PlayState;

/**
 * Routes legacy Psych chart events through the shared Psych callback/API
 * bridge. The chart's original event name and values are retained in data.
 */
class PsychCompatibilitySongEvent extends SongEvent
{
  public function new(id:String)
  {
    super("PsychCompatibilityEvent");
  }

  override public function handleEvent(data:SongEventData):Void
  {
    if (data == null || data.value == null || PlayState.instance == null) return;

    var eventName:Dynamic = Reflect.field(data.value, "name");
    if (eventName == null) return;

    if (Std.string(eventName) == "__PsychSectionState")
    {
      PsychGameplayApi.setPsychSectionState(
        Std.int(Reflect.field(data.value, "curSection")),
        Reflect.field(data.value, "mustHitSection") == true,
        Reflect.field(data.value, "altAnim") == true,
        Reflect.field(data.value, "gfSection") == true
      );
      // Only announce a section transition when the marker is current. Old
      // markers are skipped on seeks; updateGlobals derives the active state
      // directly from the chart timeline instead of replaying past callbacks.
      if (Conductor.instance.songPosition - data.time <= 1000)
        PsychScriptRuntime.dispatch("onSectionHit", [PsychGameplayApi.getCurrentPsychSection()]);
      return;
    }

    var value1:Dynamic = Reflect.field(data.value, "value1");
    var value2:Dynamic = Reflect.field(data.value, "value2");
    PsychGameplayApi.triggerEvent(
      PlayState.instance,
      Std.string(eventName),
      value1 == null ? "" : Std.string(value1),
      value2 == null ? "" : Std.string(value2)
    );
  }
}
