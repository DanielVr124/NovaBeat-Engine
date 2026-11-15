package funkin.ui.title;

import flixel.FlxG;
import funkin.ui.MusicBeatState;

/**
 * Compatibility shell for the original title-screen attract mode.
 *
 * NovaBeat keeps the title screen interactive and does not automatically
 * replace it with promotional/gameplay videos after a period of inactivity.
 */
class AttractState extends MusicBeatState
{
  override public function create():Void
  {
    // Preserve the Press Enter to Begin screen and skip the video state.
    FlxG.switchState(() -> new TitleState());
  }
}
