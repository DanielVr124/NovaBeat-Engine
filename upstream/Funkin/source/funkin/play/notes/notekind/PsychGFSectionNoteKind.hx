package funkin.play.notes.notekind;

/**
 * Psych's gfSection flag: the note remains on its charted lane, but Girlfriend
 * performs the sing animation instead of the lane's BF/opponent character.
 */
class PsychGFSectionNoteKind extends NoteKind
{
  public function new()
  {
    super('psychgfsection', 'GF Section');
    gfSing = true;
  }
}
