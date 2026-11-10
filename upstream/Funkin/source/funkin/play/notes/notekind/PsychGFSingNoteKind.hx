package funkin.play.notes.notekind;

/**
 * Psych Engine's built-in GF Sing note type.
 * The lane character suppresses its normal sing animation and routes the
 * animation to Girlfriend through BaseCharacter's note-kind behavior.
 */
class PsychGFSingNoteKind extends NoteKind
{
  public function new()
  {
    super('psychgfsing', 'GF Sing', null, [], true);
    gfSing = true;
  }
}
