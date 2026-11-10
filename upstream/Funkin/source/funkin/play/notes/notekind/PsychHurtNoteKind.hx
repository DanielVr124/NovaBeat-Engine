package funkin.play.notes.notekind;

/**
 * Psych Engine's built-in Hurt Note.
 * Avoiding it is safe; hitting it is routed through NovaBeat's normal miss
 * pipeline and removes health instead of awarding a successful hit.
 * The native regression fixture verifies the kind, damage flag, and score exclusion.
 */
class PsychHurtNoteKind extends NoteKind
{
  public function new()
  {
    super('psychhurt', 'Hurt Note');
    hurt = true;
    scoreable = false;
  }
}
