package funkin.play.notes.notekind;

/**
 * Psych Engine's built-in "Alt Animation" note type.
 * Uses the native character animation suffix so Psych charts retain their
 * alternate sing animations without requiring a custom note-type script.
 */
class AltAnimNoteKind extends NoteKind
{
  public function new()
  {
    super('alt', 'Alt Animation', null, [], false, 'alt');
  }
}
