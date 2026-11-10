package funkin.play.event;

import funkin.data.song.SongData.SongEventData;
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
