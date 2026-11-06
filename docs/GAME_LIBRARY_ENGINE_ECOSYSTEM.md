# NovaBeat Game Library and Engine Ecosystem

## Runtime model

NovaBeat is based on FNF 0.8.6 / V-Slice. V-Slice packages use the native runtime directly; there is no separate V-Slice adapter.

The Game Library is an in-game startup state, not a separate executable or launcher. The original Friday Night Funkin' experience is always listed. NovaBeat initializes Polymod without loading user packages, then the selected experience activates only its enabled package set and reloads Polymod and the data registries before proceeding through the existing title/menu flow.

Packages disabled in the existing Mod Manager remain visible in the Game Library but cannot be launched until enabled. The E key toggles the selected package's existing enabled state; this setting is shared with the Mod Manager. Moving the selection keeps the highlighted row in view and uses a short slide transition when the list advances.

## Package classifications

Every installed package has a NovaBeat-local classification:

- **Standalone**: a separately selectable experience.
- **Content Extension**: an add-on assigned to an experience.
- **Unclassified**: requires a player decision.

Native V-Slice/Polymod packages default to Content Extension unless their metadata or the player explicitly identifies them as standalone. External-engine packages remain unclassified until NovaBeat can identify their runtime.

Choices are stored in NovaBeat save data and do not modify installed mod folders. An optional `_novabeat.json` file can declare:

```json
{
  "engine": {
    "id": "psych-engine",
    "version": "0.7.3"
  },
  "package": {
    "type": "standalone"
  }
}
```

An extension can be assigned to an experience in the Game Library. New native V-Slice extensions default to Friday Night Funkin'. Unknown external-engine packages remain unclassified until the player decides. Disabled extensions are not loaded.

## Active content ownership

A standalone experience loads its own native Polymod package and the compatible extensions assigned to it. The official FNF experience loads its assigned extensions. Installed packages remain on disk when another experience is selected.

For modern V-Slice Freeplay, song IDs are collected from the selected packages' `data/songs/<song-id>` folders. Freeplay filters its native song list to those owned IDs. Playable-character categories are then derived from the characters used by those songs. Original character assets are not removed.

Song scores and Story Mode level scores/completion checks are namespaced by the active experience, so two experiences that use the same song or level ID do not overwrite each other's scores. Existing official FNF score keys are left unchanged for backwards compatibility. Other progression details such as character-seen flags and favorites still need their own experience-scoped pass.

## Engine identification and compatibility

Engine identification is separate from package classification:

- **V-Slice** is native to NovaBeat and does not use an adapter.
- **Psych Engine** can be identified through explicit metadata or distinctive Psych package markers.
- Unknown packages are not silently treated as playable.

The first compatibility milestone detects and labels Psych packages but does not execute them. A real Psych runtime still needs versioned chart/data conversion, script API compatibility, events, note types, modcharts, shaders, media behavior, and a dedicated Psych-style Freeplay presentation. Until then, detected Psych packages are shown as unavailable rather than incorrectly reported as playable.

## Psych Freeplay scope

When Psych runtime support is implemented, its Freeplay presentation is the only existing FNF menu presentation that is intentionally engine-specific. It should be adapted from the selected Psych source version, use direct song selection without character categories, and retain NovaBeat's normal main menu, Story Mode, Options, pause menu, results screen, and gameplay HUD.

## Current implementation stage

This branch establishes the in-game Game Library, local package classification and extension-owner persistence, native V-Slice package activation, experience song ownership filtering, and automatic modern Freeplay character-category visibility. It does not yet claim a working Psych runtime or a completed Psych Freeplay clone.
