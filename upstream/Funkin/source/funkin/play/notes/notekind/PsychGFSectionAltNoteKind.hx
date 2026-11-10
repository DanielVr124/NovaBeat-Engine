package funkin.play.notes.notekind;

/**
 * Psych gfSection combined with Alt Animation.
 * Girlfriend performs the alternate sing animation for the note.
 */
class PsychGFSectionAltNoteKind extends NoteKind
{
  public function new()
  {
    super('psychgfsectionalt', 'GF Section Alt Animation', null, [], false, 'alt');
    gfSing = true;
  }
}
