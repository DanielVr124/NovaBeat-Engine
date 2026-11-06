package funkin.ui.options;

import funkin.data.notestyle.NoteStyleRegistry;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxOutlineEffect;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import funkin.ui.Page;
import funkin.play.notes.NoteSprite;

class ColorsMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var curSelected:Int = 0;
  var grpNotes:FlxTypedGroup<NoteSprite>;
  var noteEffects:Array<FlxEffectSprite> = [];

  public function new()
  {
    super();

    grpNotes = new FlxTypedGroup<NoteSprite>();
    add(grpNotes);

    for (i in 0...4)
    {
      var note:NoteSprite = new NoteSprite(NoteStyleRegistry.instance.fetchDefault(), i);

      note.x = (100 * i) + i;
      note.screenCenter(Y);

      var _effectSpr:FlxEffectSprite = new FlxEffectSprite(note, [
        new FlxOutlineEffect(FlxOutlineMode.FAST, FlxColor.WHITE, 4, 1)
      ]);
      add(_effectSpr);
      noteEffects.push(_effectSpr);
      _effectSpr.y = 0;
      _effectSpr.x = i * 130;
      _effectSpr.scale.x = _effectSpr.scale.y = 0.7;
      // _effectSpr.setGraphicSize();
      _effectSpr.height = note.height;
      _effectSpr.width = note.width;

      // _effectSpr.updateHitbox();

      grpNotes.add(note);
    }
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    var portrait:Bool = height > width * 1.12;
    var spacing:Float = portrait ? Math.min(74, (width - 24) / 4) : 130;
    var totalWidth:Float = spacing * 3;
    for (index in 0...grpNotes.members.length)
    {
      var note:NoteSprite = grpNotes.members[index];
      note.setPosition((width - totalWidth) * 0.5 + index * spacing, (height - note.height) * 0.5);
      if (index < noteEffects.length)
      {
        var effect:FlxEffectSprite = noteEffects[index];
        effect.setPosition(note.x, note.y);
        effect.scale.set(portrait ? 0.48 : 0.7, portrait ? 0.48 : 0.7);
      }
    }
  }

  override function update(elapsed:Float)
  {
    if (controls.UI_RIGHT_P) curSelected += 1;
    if (controls.UI_LEFT_P) curSelected -= 1;

    if (curSelected < 0) curSelected = grpNotes.members.length - 1;
    if (curSelected >= grpNotes.members.length) curSelected = 0;

    if (controls.UI_UP)
    {
      // grpNotes.members[curSelected].colorSwap.update(elapsed * 0.3);
      // Note.arrowColors[curSelected] += elapsed * 0.3;
    }

    if (controls.UI_DOWN)
    {
      // grpNotes.members[curSelected].colorSwap.update(-elapsed * 0.3);
      // Note.arrowColors[curSelected] += -elapsed * 0.3;
    }

    super.update(elapsed);
  }
}
