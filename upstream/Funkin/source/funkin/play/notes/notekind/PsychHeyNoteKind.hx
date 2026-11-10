package funkin.play.notes.notekind;

/**
 * Psych Engine's built-in Hey! note type.
 * BaseCharacter handles the associated Hey/Cheer animation behavior.
 */
class PsychHeyNoteKind extends NoteKind
{
  public function new()
  {
    super('psychhey', 'Hey!');
    hey = true;
  }
}
