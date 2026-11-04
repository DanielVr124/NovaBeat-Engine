# NovaBeat Engine — Prioritized Development Roadmap

**Project:** Friday Night Funkin': NovaBeat Engine  
**Tagline:** A New Rhythm. A New Experience.  
**Initial code baseline:** Friday Night Funkin' 0.8.6  
**Targets:** Windows PC and Android phones/tablets  
**Android layouts:** Portrait and landscape  
**Out of scope:** iOS; a separate launcher

This roadmap organizes the approved proposals into implementation stages. It is a plan, not a claim that these systems already exist. Items should move to "complete" only after implementation, compilation, and testing on the relevant platforms.

## Guiding principles

1. Keep the familiar FNF experience intact while adding optional NovaBeat capabilities.
2. Build shared engine systems once, then provide platform-specific Windows and Android interfaces where filesystem, input, or display behavior differs.
3. Treat Android portrait and landscape as first-class layouts, not a rotated desktop UI.
4. Prefer stable, testable releases over adding every proposal at once.
5. Design extension points and mod APIs before building advanced editors that depend on them.
6. Treat mods as untrusted packages: validate archives, avoid path traversal, show dependency and compatibility information, and make recovery possible.
7. Do not promise instant enable/disable when the game needs a restart to rebuild asset registries.

## Priority and release stages

### Stage 0 — Establish the source and build foundation
**Priority: P0 — required before feature work can be validated**

- Import the complete FNF 0.8.6 source tree into this repository, including the correct upstream notices and required submodules.
- Record the precise upstream revision and document how NovaBeat changes are applied.
- Restore and verify the `assets` and `art` submodules; the supplied source ZIP did not include their contents.
- Set up reproducible Windows and Android build instructions.
- Produce baseline builds before introducing further changes.
- Add regression checks for startup, save migration, mod loading, gameplay, and platform-specific file access.
- Introduce platform capability wrappers for file pickers, archive import, storage paths, orientation, and window operations.
- Establish an issue/bug-report template and a clear development status convention.

**Exit criteria:** Clean Windows and Android builds from the repository, with baseline gameplay and save data verified.

### Stage 1 — Native Mod Manager MVP
**Priority: P1 — first user-facing milestone**

Build the Mod Manager as a real FNF screen, accessible from the game's own menus. Do not require a separate launcher.

**Core capabilities**
- Browse installed mods and display title, author, version, description, compatibility, enabled state, and package information.
- Enable/disable mods with persistent settings and clear restart-required indicators.
- Install compatible ZIP packages and reject unsafe or malformed archives.
- Delete mods only after confirmation.
- Search by title and author; sort and filter by compatibility, version, and installation date.
- Show mod changelogs and a detail page with screenshots where metadata provides them.
- Detect duplicates, missing dependencies, incompatible versions, and likely conflicts.
- Support an import queue, batch installation/removal, and progress feedback.
- Provide one-click backup and restoration, plus recently deleted recovery.
- Support local groups, personal notes, labels, and favorites.
- Offer safe mode and useful mod-loading error reports.

**Windows implementation**
- Native file picker and drag-and-drop ZIP installation.
- Open the mods directory in Explorer.
- Remember separate keyboard/controller preferences and selected manager item.

**Android implementation**
- Native Android document picker and share-sheet import.
- Use app-accessible storage locations and handle scoped-storage permissions properly.
- Portrait and landscape layouts for all manager pages.
- Tablet layouts and adaptive controls.
- Make archive import, backup, restore, and delete work within Android storage rules.

**Exit criteria:** Verified install/enable/restart/disable/delete cycles on Windows and Android, including portrait and landscape testing on Android.

### Stage 2 — NovaBeat UI identity and navigation
**Priority: P1/P2 — establish a consistent engine feel**

- Apply consistent NovaBeat styling to the main menus, Options, Mod Manager, loading screens, and results screens.
- Add a reusable transition service so screens do not implement unrelated one-off wipes.
- Add the requested diagonal transition as the signature NovaBeat transition (full specification below).
- Implement interface scaling, per-resolution layouts, compact mode, animation-speed controls, notification behavior, and navigation history.
- Add global settings search, contextual help, a searchable shortcut list, and first-run guidance.
- Ensure all menus work with mouse, keyboard, controller, and Android touch.

**Requested signature transition — Nova Diagonal Dissolve**
- **Reveal / undissolve:** a soft diagonal reveal travels from the top-left corner toward the bottom-right corner.
- **Cover / load-away:** the opposite direction, from bottom-right toward top-left.
- Use a smooth eased edge rather than a harsh straight cut; the diagonal boundary should travel continuously across the screen.
- Reuse the same transition implementation for menu navigation, editor entry/exit, song loading, results, and other state changes.
- Keep it performant on lower-end Android devices and avoid a black-frame flash.
- Respect a future reduced-motion option and allow duration/easing to be tuned centrally.
- This should become a signature visual treatment, not a reason to delay core functionality.

**Exit criteria:** Consistent navigation and transition behavior across the game's major screens, with portrait/landscape-safe rendering.

### Stage 3 — Mod architecture and developer extension foundation
**Priority: P2 — make future systems safe and extensible**

- Publish the NovaBeat Mod SDK and documented external developer API.
- Add versioned mod configuration schemas and a browsable Mod API Explorer.
- Add an engine event bus and stable registration points for custom gameplay components and asset types.
- Design extension modules and optional plugin architecture with explicit compatibility checks.
- Add script performance inspection and developer diagnostics.
- Support isolated mod save data so different mods or mod profiles do not overwrite unrelated progress.
- Visualize dependencies and conflicts in a compatibility graph.
- Install dependencies only after compatibility checks and user approval.
- Maintain a searchable local mod repository.
- Add third-party editor integration points.
- Document extension permissions and validate packages before enabling them.

**Online Mod Hub — defer until the local manager and security model are stable**
- Browse community-hosted mods, collections, and mod pages.
- Display descriptions, screenshots, authors, versions, ratings/reviews, and changelogs.
- Support update discovery and dependency acquisition.
- Include package integrity checks, clear download sources, moderation/reporting paths, and safe rollback.
- The hub should be optional; local installation must continue to work offline.

**Exit criteria:** A documented, versioned extension API with example mods and automated compatibility tests.

### Stage 4 — Gameplay systems
**Priority: P3 — expand what players and mods can create**

- Custom game modes that mods can register.
- Per-song gameplay rules and custom gameplay component registration.
- Replay capture and a replay timeline for inspecting gameplay moments.
- Alternative scoring engines and configurable combo milestones.
- Custom result summaries and optional detailed hit-timing statistics.
- Quick restart and quick song switching from results.
- Remember per-song difficulty and gameplay modifiers.
- Adjustable countdown behavior and configurable hit feedback.
- Customizable health-bar positioning and per-song volume preferences.
- Automatic replay after a failed attempt, with a user setting to disable it.

**Exit criteria:** Gameplay APIs documented; custom game modes and scoring extensions tested with multiple mods and save profiles.

### Stage 5 — Audio and music presentation
**Priority: P3**

- Optional audio effects and configurable processing.
- BPM-synchronized visual/audio effects.
- Custom audio transitions between tracks.
- Synchronized lyrics display.
- Audio track comparison and advanced previews with playback controls.
- Visual waveform and audio inspection tools.
- Per-song volume preferences and better stem/audio routing where the source architecture supports it.

**Exit criteria:** No timing regressions; audio effects and previews do not disrupt note timing or gameplay synchronization.

### Stage 6 — Visual presentation and themes
**Priority: P3/P4**

- Animated menu backgrounds and custom menu particle effects.
- Dynamic background-music visualizers.
- Custom song introductions and post-song cinematics.
- Animated gameplay HUD elements and custom song-completion animations.
- Advanced transitions and per-song visual presets.
- Custom loading screen animations.
- Reactive stage lighting.
- Mod-specific UI themes.
- Preserve readable gameplay and provide reduced-motion/accessibility fallbacks.

**Exit criteria:** Visual systems are configurable, performant, and do not obscure gameplay information.

### Stage 7 — Creator toolkit
**Priority: P4 — build on the stable SDK**

- Visual Event Builder.
- Camera Path Editor.
- Cutscene Timeline Editor.
- Sprite Atlas Editor.
- Shader Editor and live shader previews.
- Stage Prop Editor.
- Audio Waveform Editor.
- Character Behavior Editor.
- Animation Transition Editor.
- Dialogue Branching Editor.
- Visual Script Graph.
- Multi-file mod projects and live preview windows.
- Improve chart editing with multi-chart tabs, chart comparison, bulk note/event edits, copy/paste across charts, custom timeline markers, waveform controls, custom editor panels, workspace presets, validation warnings, and event search/replace.

**Exit criteria:** A small creator workflow can build, validate, preview, and package a mod without external tools for the supported task.

### Stage 8 — Quality, accessibility, and platform polish
**Priority: continuous; release gate for every milestone**

**General**
- Crash recovery and automatic recovery after a crash.
- Detailed crash reports, built-in log viewer, and one-click diagnostic export.
- Startup troubleshooting and safe-mode suggestions after repeated crashes.
- Memory-usage warnings, missing-asset detection, and performance bottleneck explanations.
- Colorblind-friendly indicators, reduced motion, high contrast, adjustable text size, visual audio cues, and configurable background dimming.

**Windows**
- Drag-and-drop files, multi-monitor positioning, resizable windows, quick fullscreen toggle, graphics presets, controller hot-plug detection, editor mouse sensitivity, quick developer tools, compatible archive file association, and remembered PC control configurations.

**Android**
- Portrait/landscape layouts and saved per-orientation HUD positions.
- Smooth rotation transitions and optional orientation lock.
- Adjustable touch-button size, spacing, position, transparency, and control presets.
- Touch vibration intensity, Bluetooth controller support, and tablet layouts.
- Share-sheet/ZIP imports, scoped storage handling, battery-saving preset, adaptive graphics quality, and correct pause/audio behavior when backgrounded.

**Exit criteria:** Each release passes Windows and Android regression tests; Android tests include phone and tablet layouts in both portrait and landscape.

## Suggested release milestones

| Milestone | Contents | Release gate |
|---|---|---|
| **NovaBeat 0.1 — Foundation** | Complete source tree, reproducible builds, baseline tests, shared platform abstractions | Windows and Android compile |
| **NovaBeat 0.2 — Mod Manager** | Native manager, install/enable/disable/delete, profiles, safe import, backup, Android support | End-to-end mod workflow verified on both platforms |
| **NovaBeat 0.3 — Nova UI** | Signature diagonal transition, coherent menus, settings search, UI scaling | Navigation and orientation regressions pass |
| **NovaBeat 0.4 — Mod SDK** | API, configuration schemas, event bus, dependencies, isolated saves | Example extension mods pass compatibility tests |
| **NovaBeat 0.5 — Gameplay & Audio** | Custom game modes, replay timeline, scoring rules, audio features | Timing and save tests pass |
| **NovaBeat 0.6 — Creator Tools** | Visual editors, preview windows, packaging and validation | A sample mod can be built and packaged |
| **NovaBeat 1.0 — Stable Engine** | Mature features, diagnostics, accessibility, documentation, platform QA | Release checklist and regression suite pass |

## Scope decisions

- Windows and Android are the only planned platforms.
- Android portrait and landscape are both required.
- No separate launcher is planned.
- The Mod Manager is the first major product milestone.
- The Online Mod Hub is deliberately later than local mod management; it depends on a stable API, package validation, and a clear trust/safety model.
- Advanced creator editors depend on the SDK and stable extension points.
- Roadmap items remain proposals until implemented and verified.
