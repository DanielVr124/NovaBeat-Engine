# Approved NovaBeat Engine Backlog

This is the approved proposal set supplied by the project owner on 2026-11-03. These entries are **planned backlog items**, not implemented features. Major engine features and quality-of-life work are deliberately kept separate.

## A. Major engine features

### Gameplay systems
- Custom Game Modes — allow mods to add entirely new ways to play.
- Replay Timeline — rewind and inspect individual gameplay moments.
- Per-Song Gameplay Rules — different mechanics for individual songs.
- Custom Combo Milestones — configurable rewards for combo achievements.
- Alternative Scoring Engines — let mods provide their own scoring algorithms.

### Audio and music systems
- Audio Effects — support optional filters and audio effects.
- BPM-Synchronized Effects — trigger visual effects using song timing.
- Custom Audio Transitions — smooth transitions between tracks.
- Lyrics Display System — display synchronized song lyrics.
- Audio Track Comparison — compare different versions of songs.
- Advanced Audio Preview — preview songs with adjustable playback controls.

### Mod ecosystem
- Built-in Online Mod Hub — browse community-hosted mods.
- Mod Pages — give every mod its own description, screenshots, and information.
- Isolated Mod Saves — keep mod-specific progress separate.
- Mod Compatibility Graph — visualize dependencies and conflicts.
- Automatic Dependency Installation — acquire required compatible dependencies.
- Mod Changelogs — display update information inside the manager.
- Mod API Explorer — browse available engine functions for creators.
- Local Mod Repository — maintain a searchable local library.
- Mod Import Queue — install several mods in one operation.

### Creator tools
- Visual Event Builder — create events without writing code.
- Camera Path Editor — design cinematic camera movements.
- Cutscene Timeline Editor — arrange animations, dialogue, and audio.
- Sprite Atlas Editor — organize and inspect sprite sheets.
- Shader Editor — create and preview visual shaders.
- Stage Prop Editor — arrange interactive stage objects.
- Audio Waveform Editor — inspect and edit song timing visually.
- Character Behavior Editor — configure advanced character logic.
- Animation Transition Editor — configure transitions between animations.
- Dialogue Branching Editor — create choices and branching conversations.
- Visual Script Graph — connect game events using visual nodes.
- Multi-File Mod Projects — organize complete mod projects in one workspace.
- Live Preview Windows — preview assets alongside your editor.

### Visual and presentation systems
- Animated Menu Background System.
- Dynamic Background Music Visualizers.
- Custom Song Introduction Sequences.
- Animated Gameplay HUD Elements.
- Custom Song Completion Animations.
- Custom Menu Particle Effects.
- Advanced Transition Effects.
- Per-Song Visual Presets.
- Custom Loading Screen Animations.
- Custom Post-Song Cinematics.
- Reactive Stage Lighting.
- Mod-Specific UI Themes.

### Engine and developer extensions
- Official NovaBeat Mod SDK.
- External Developer API.
- Custom Engine Extension Modules.
- Optional Plugin Architecture.
- Custom Gameplay Component Registration.
- Custom Asset Type Registration.
- Custom Input Device API.
- Mod-Specific Configuration Schemas.
- Engine Event Bus for Extensions.
- Third-Party Editor Integration.
- Script Performance Inspector.

## B. Quality-of-life improvements

### Gameplay QoL
- Automatic song replay after a failed attempt.
- Remember the last-used difficulty per song.
- Remember the last-used gameplay modifiers.
- Customizable song result summaries.
- Optional detailed hit-timing statistics.
- Quick chart restart from a configurable hotkey.
- Optional real-time accuracy graph.
- Adjustable countdown behavior.
- Configurable note-hit visual feedback.
- Customizable health-bar positioning.
- Per-song volume preferences.
- Quick song switching from the results screen.

### Mod Manager QoL
- Drag-and-drop mod installation.
- Batch mod installation.
- Batch mod removal.
- Mod list folders and custom groups.
- Automatic duplicate mod detection.
- One-click mod backup.
- One-click mod restoration.
- Mod installation queue with progress.
- Search by mod author.
- Search by mod version.
- Filter by compatibility.
- Filter by recently installed.
- Remember previously selected mod.
- Mod notes and personal labels.
- Recently deleted mods recovery.
- Bulk export selected mods.

### Settings and interface QoL
- Global settings search.
- Searchable keyboard shortcut list.
- Customizable keyboard shortcuts.
- Customizable controller bindings.
- Adjustable menu animation speed.
- Adjustable interface scaling.
- Remember window size and position.
- Remember previous menu location.
- Context-sensitive help.
- Per-resolution UI layouts.
- Interactive first-time setup guide.
- Optional compact interface mode.
- Customizable notification duration.
- Improved menu navigation history.

### Chart Editor QoL
- Automatic recovery after a crash.
- Visual unsaved-changes indicator.
- Multiple charts open simultaneously.
- Chart comparison mode.
- Bulk note editing.
- Bulk event editing.
- Copy and paste between different charts.
- Custom timeline markers.
- Adjustable waveform display.
- Customizable editor panels.
- Editor workspace presets.
- Inline chart validation warnings.
- Search and replace chart events.

### Android QoL — phones and tablets, portrait and landscape
- Portrait-specific interface layouts.
- Landscape-specific interface layouts.
- Save separate HUD arrangements for each orientation.
- Smooth transitions when rotating the device.
- Adjustable touch-button size and spacing.
- Customizable touch-button positions.
- Multiple touchscreen control presets.
- Adjustable touch feedback vibration.
- External Bluetooth controller support.
- Android share-sheet mod importing.
- Import mods directly from downloaded ZIP files.
- Improved Android storage permission handling.
- Battery-saving performance preset.
- Automatic graphics quality adjustment.
- Tablet-specific interface layouts.
- Automatic pause and audio handling when backgrounded.
- Optional orientation lock accessible from settings.
- Customizable mobile hitbox transparency.

### Windows PC QoL
- Drag-and-drop files into the game.
- Multi-monitor window positioning.
- Customizable window dimensions.
- Quick fullscreen toggle.
- Automatic graphics quality presets.
- Improved controller hot-plug detection.
- Configurable mouse sensitivity in editors.
- Quick access developer tools.
- Windows file association for compatible mod archives.
- Remember separate PC control configurations.

### Accessibility, diagnostics, and recovery QoL
- Colorblind-friendly gameplay indicators.
- Reduced animation and motion mode.
- High-contrast interface theme.
- Adjustable interface text size.
- Optional visual audio cues.
- Configurable background dimming.
- Detailed crash reports.
- Built-in log viewer.
- One-click diagnostic report export.
- Startup troubleshooting mode.
- Automatic safe-mode suggestion after repeated crashes.
- Memory usage warnings.
- Missing asset detection.
- Performance bottleneck explanations.

## C. Additional approved visual behavior

### Nova Diagonal Dissolve / Reveal
The project owner requested a smooth diagonal screen transition:

- **Reveal / undissolve:** begin at the top-left and travel toward the bottom-right.
- **Cover / load-away:** reverse direction, beginning at the bottom-right and traveling toward the top-left.
- Use a soft, smooth moving edge and consistent easing.
- Reuse the same transition service across menus, editors, loading, and results.
- Keep it performant on Android and respect a reduced-motion setting.

## D. Platform scope

- Windows PC.
- Android phones and tablets.
- Android must support portrait and landscape.
- iOS is not a target.
- A separate launcher is not planned.

## E. Backlog policy

- Keep features and QoL items separate in planning and release notes.
- Prioritize foundations and the native Mod Manager before advanced creator tools and online services.
- Online mod distribution depends on a stable SDK, dependency model, package validation, and safe update/rollback behavior.
- A proposal becomes "implemented" only after code is merged, relevant builds pass, and behavior is tested.
