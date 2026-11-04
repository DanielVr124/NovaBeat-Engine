# NovaBeat Engine — Complete Milestone Roadmap

**Project:** Friday Night Funkin': NovaBeat Engine  
**Tagline:** A New Rhythm. A New Experience.  
**Engine baseline:** Friday Night Funkin' 0.8.6  
**Supported targets:** Windows PC and Android phones/tablets  
**Android layouts:** Portrait and landscape are both required  
**Not planned:** iOS or a separate launcher

This is the master implementation plan for the approved NovaBeat backlog. It groups the work into milestones in dependency order. It is a plan, not a claim that the listed features already exist. A milestone is complete only after its code is merged, the relevant builds pass, and its acceptance checks are completed.

## Product rules

1. **Keep the original FNF experience intact.** NovaBeat should feel like the familiar official game first: preserve its core gameplay, songs, characters, timing, animations, and established flows. NovaBeat systems should extend the game rather than replace the original experience without a clear reason.
2. **The Mod Manager is in-game.** It belongs inside the game menus. NovaBeat is not getting a separate launcher.
3. **Windows and Android are first-class targets.** Shared systems should be implemented once where practical, with platform-specific file access, input, storage, display, and UI behavior where necessary.
4. **Android is not just a rotated desktop layout.** Phone portrait, phone landscape, and tablet layouts need deliberate responsive design, with orientation-specific HUD arrangements.
5. **Mods are untrusted packages.** Validate archives, block path traversal, detect invalid metadata and conflicts, explain dependencies, and provide backup/recovery.
6. **Build only at useful checkpoints.** Small changes get code review and focused checks. Full Windows and Android builds are reserved for substantial feature batches, platform-sensitive changes, and release candidates.
7. **Do not overstate completion.** A feature is not "done" because a screen exists; its workflows, error handling, persistence, relevant platforms, and regression tests must work.

## Current project status

**Current status: Foundation in progress.**

- The FNF 0.8.6 source tree has been imported into upstream/Funkin; the separately licensed upstream assets and art repositories remain pinned submodules.
- The opt-in Windows/Android build workflow and private build-delivery workflow are in the repository.
- A Windows native compilation has succeeded in CI once, but the earlier run did not retain a downloadable package. Private release delivery is configured to use the separate private NovaBeat-Builds repository; the first end-to-end release upload still needs to be verified.
- Android compilation has not yet been confirmed as successful.
- The Mod Manager and the other approved NovaBeat feature proposals remain planned work; they are not implemented by the source import or build setup.
- Android currently inherits the upstream landscape-only configuration. Portrait support and responsive layouts remain unfinished.

The first completed milestone must prove that clean, downloadable baseline builds can be produced and that original FNF behavior remains intact before feature work expands.

---

# Milestones

## M0 — Repository, source, and delivery foundation
**Priority:** P0 · **Status:** In progress

**Purpose:** Make the project reproducible and establish a dependable way to build and deliver both supported platforms.

**Work**
- Keep the exact FNF 0.8.6 source revision pinned and document how upstream changes are adopted.
- Preserve all upstream license notices and the separate assets/art submodule pins.
- Keep the Windows and Android dependency versions documented and reproducible.
- Maintain independent Windows-only, Android-only, and combined build selections.
- Package the Windows output as a ZIP containing the required runtime files, not just an isolated executable.
- Package the Android output as an APK.
- Publish successful outputs to Releases in the private NovaBeat-Builds repository; never publish proprietary game assets through the public source repository.
- Record build commit, platform, package name, size, and SHA-256 in release notes or the workflow summary.
- Keep build logs and failure summaries easy to inspect.

**Acceptance checks**
- A clean Windows CI build produces a launchable package.
- A clean Android CI build produces an installable debug APK.
- Windows-only and Android-only runs do not build the other platform.
- Private release uploads are confirmed by checking the actual release and its downloadable assets.
- Build instructions, required dependencies, and delivery location are documented.

**Exit:** Both baseline platforms can be built and their output packages can be downloaded from the private build repository.

## M1 — Original FNF parity and platform baseline
**Priority:** P0 · **Status:** Planned; follows M0

**Purpose:** Establish that NovaBeat remains recognizably and functionally the original FNF before layering on new systems.

**Shared FNF behavior to preserve**
- Main-menu navigation and the original game flow.
- Story Mode, Freeplay, song selection, difficulties, and results.
- Character, stage, animation, chart, note, scoring, health, and timing behavior.
- Existing options, input behavior, save data, and supported original content.
- Existing mod loading behavior while the new manager is being developed.
- Existing cutscenes, audio playback, transitions, and gameplay rendering.

**Windows baseline**
- Keyboard, mouse, and controller navigation.
- Windowed and fullscreen modes.
- Save/configuration persistence and normal file access.
- Existing chart/gameplay behavior and supported mod folders.

**Android baseline**
- Official-style touch gameplay and mobile navigation.
- Android lifecycle behavior, pause/resume, and audio focus.
- Native document/file access where the upstream engine supports it.
- Phone and tablet input and rendering checks.
- Build and test the actual Android package; compilation alone is not proof of behavior.

**Acceptance checks**
- Start the game, navigate menus, play songs, finish/retry, change settings, restart, and confirm saved settings persist.
- Compare core flows against the FNF 0.8.6 baseline; document intentional NovaBeat differences.
- Confirm no regressions to note timing, audio sync, or input response.
- Verify the existing mod loading path still works.

**Exit:** Original game flows are verified on Windows and Android, and a baseline regression checklist exists.

## M2 — Android mobile experience: portrait, landscape, and tablets
**Priority:** P0/P1 · **Status:** Planned

**Purpose:** Make Android feel like a proper mobile FNF build rather than a desktop game forced onto a phone.

**Major work**
- Remove the inherited landscape-only assumption and support both portrait and landscape.
- Create intentional portrait and landscape layouts for menus, gameplay, HUD, results, options, and future manager screens.
- Adapt layouts to phone and tablet aspect ratios, safe areas, cutouts, and different screen sizes.
- Smoothly respond to device rotation without broken layout, lost input, black frames, or interrupted state.
- Allow optional orientation lock in settings.
- Save separate HUD arrangements for portrait and landscape.
- Ensure touch controls remain usable and configurable in both orientations.

**Android QoL**
- Adjustable touch-button size, spacing, position, and hitbox transparency.
- Multiple touchscreen control presets.
- Adjustable touch feedback vibration.
- Bluetooth/external controller support.
- Android share-sheet mod importing and ZIP import from downloads.
- Correct scoped-storage and permission handling.
- Battery-saving performance preset and automatic graphics-quality adjustment.
- Tablet-specific interface layouts.
- Automatic pause/audio handling when the app is backgrounded.

**Acceptance checks**
- Test representative phone and tablet sizes in portrait and landscape.
- Rotate during menus and gameplay; verify no broken or overlapping UI and no lost progress.
- Test touch, Bluetooth controller, pause/resume, audio focus, ZIP import, and storage permissions.
- Verify each orientation's saved HUD layout is restored correctly.

**Exit:** Android supports usable portrait and landscape experiences on phones and tablets, with mobile input and storage flows verified.

## M3 — Native in-game Mod Manager MVP
**Priority:** P1 · **Status:** Planned · **First major NovaBeat feature**

**Purpose:** Give players a polished, safe way to manage mods without leaving the game or using a separate launcher.

**Core manager**
- Add a Mod Manager entry to the game's own menus.
- Browse installed mods with title, author, version, description, compatibility, enabled state, and package information.
- Provide a detail page with metadata, screenshots where supplied, and changelog.
- Install compatible ZIP packages and reject malformed, unsafe, or unsupported archives.
- Enable and disable mods with persistent settings and a clear restart-required indicator where a restart is necessary.
- Delete mods only after confirmation.
- Search, sort, and filter installed mods.
- Detect duplicate mods, missing dependencies, incompatible versions, and likely conflicts.
- Provide safe mode and clear mod-loading error reports.
- Support a queue for imports and show progress, success, and failure states.

**Windows implementation**
- Native file picker.
- Drag-and-drop ZIP installation.
- Open the mods directory in Windows Explorer.

**Android implementation**
- Native Android document picker and share-sheet import.
- Import compatible ZIP files from Downloads and other provider apps.
- Use app-accessible storage and respect scoped-storage rules.
- Every manager screen works in portrait and landscape.

**Acceptance checks**
- Install, enable, restart, disable, update/replace, and delete a test mod.
- Try malformed ZIPs, unsafe paths, duplicate packages, missing dependencies, and incompatible versions.
- Confirm the base game still launches when a mod fails.
- Verify all flows with mouse/keyboard/controller on Windows and touch/controller on Android.

**Exit:** A player can safely install and manage local mods end-to-end on both platforms.

## M4 — Mod Manager Plus and local mod library
**Priority:** P1/P2 · **Status:** Planned

**Purpose:** Expand the MVP into a convenient library for players with larger mod collections.

**Major work**
- Local searchable mod repository/library.
- Isolated mod saves and separate mod/profile progress.
- Mod compatibility graph showing dependencies and conflicts.
- Compatible dependency discovery and user-approved automatic dependency installation.
- Mod pages/details, changelogs, author/version information, and compatibility status.
- Import queue for multiple mods.
- Remember last selected mod and manager location.

**Mod Manager QoL**
- Batch install and batch removal.
- Mod folders, groups, favorites, notes, and personal labels.
- Automatic duplicate detection and clearer duplicate resolution.
- One-click mod backup and restore.
- Recently deleted mod recovery.
- Queue progress and per-package error reporting.
- Search by author and version.
- Filters for compatibility and recently installed.
- Bulk export selected mods.

**Acceptance checks**
- Manage a larger test library with duplicates, dependencies, incompatible versions, and multiple profiles.
- Verify isolated saves do not overwrite unrelated progress.
- Verify backup, restore, recovery, batch, and export operations.
- Confirm no mod operation can write outside its approved storage area.

**Exit:** The Mod Manager supports larger local libraries safely and predictably.

## M5 — NovaBeat UI identity, navigation, and signature transition
**Priority:** P1/P2 · **Status:** Planned

**Purpose:** Give NovaBeat a recognizable, polished interface while keeping the familiar FNF flow.

**Major work**
- Establish a consistent visual system for menus, options, Mod Manager, loading, and results.
- Add the approved **Nova Diagonal Dissolve / Reveal** transition as a reusable screen-transition service.
- Reveal direction: top-left toward bottom-right.
- Cover direction: bottom-right toward top-left.
- Use a soft moving edge, smooth easing, and consistent timing.
- Reuse the transition across menus, editors, loading, and results rather than making unrelated one-off effects.
- Add mod-specific UI themes and consistent notification behavior.
- Ensure mouse, keyboard, controller, and touch navigation remain coherent.

**Settings/interface QoL**
- Global settings search.
- Searchable keyboard shortcut list.
- Customizable keyboard shortcuts and controller bindings.
- Adjustable menu animation speed.
- Adjustable interface scaling.
- Remember window size and position.
- Remember previous menu location and navigation history.
- Context-sensitive help and first-time setup guide.
- Per-resolution UI layouts and compact interface mode.
- Customizable notification duration.

**Acceptance checks**
- Navigate all major screens with each supported input method.
- Test transitions between screens and into/out of gameplay without black-frame flashes or lost input.
- Test UI scaling, resolution changes, reduced motion, Android rotation, and mod themes.

**Exit:** A consistent NovaBeat interface and reusable signature transition work across major screens and both platforms.

## M6 — NovaBeat Mod SDK and engine extension architecture
**Priority:** P2 · **Status:** Planned · **Dependency for advanced mod features**

**Purpose:** Give mod authors stable, documented ways to extend the engine without relying on fragile internal implementation details.

**Major work**
- Official NovaBeat Mod SDK.
- Versioned external developer API.
- Mod-specific configuration schemas.
- Engine event bus for extensions.
- Custom gameplay component registration.
- Custom asset-type registration.
- Custom input-device API.
- Custom engine extension modules.
- Optional plugin architecture with explicit compatibility checks.
- Mod API Explorer.
- Script performance inspector.
- Third-party editor integration points.
- Permission model and package validation rules.

**Acceptance checks**
- Produce example mods using documented APIs.
- Test API version mismatch and extension incompatibility behavior.
- Ensure extension failures can be isolated and diagnosed.
- Verify mod saves and config data remain scoped correctly.

**Exit:** The SDK is documented and versioned, and example extensions pass compatibility tests.

## M7 — Gameplay systems and gameplay QoL
**Priority:** P2/P3 · **Status:** Planned · **Depends on M6**

**Major engine features**
- Custom Game Modes that mods can register.
- Replay Timeline for rewinding and inspecting gameplay moments.
- Per-Song Gameplay Rules.
- Custom Combo Milestones.
- Alternative Scoring Engines.
- Custom gameplay component support through the SDK.

**Gameplay QoL**
- Automatic song replay after a failed attempt, with a setting to disable it.
- Remember last-used difficulty per song.
- Remember last-used gameplay modifiers.
- Customizable song result summaries.
- Optional detailed hit-timing statistics.
- Quick chart restart from a configurable hotkey.
- Optional real-time accuracy graph.
- Adjustable countdown behavior.
- Configurable note-hit visual feedback.
- Customizable health-bar positioning.
- Per-song volume preferences.
- Quick song switching from results.

**Acceptance checks**
- Test each game mode and scoring system against normal FNF gameplay.
- Confirm replay capture/playback and timeline seeking are deterministic enough for the documented use.
- Confirm timing, accuracy, score, health, and save data remain correct.
- Verify settings persist and can be disabled where appropriate.

**Exit:** Custom gameplay systems work through documented extension points without breaking standard songs or scoring.

## M8 — Audio and music systems
**Priority:** P3 · **Status:** Planned

**Major engine features**
- Optional Audio Effects and filters.
- BPM-Synchronized Effects.
- Custom Audio Transitions between tracks.
- Synchronized Lyrics Display.
- Audio Track Comparison for alternate versions.
- Advanced Audio Preview with adjustable playback controls.
- Audio waveform inspection and improved stem/audio routing where supported.

**Acceptance checks**
- Test audio timing against chart timing at multiple BPMs.
- Check seek, pause, resume, transitions, preview, and track switching.
- Verify optional processing can be disabled and does not add avoidable latency.
- Test audio behavior on Windows and Android, including app background/resume.

**Exit:** Audio systems remain synchronized with gameplay and behave correctly across both platforms.

## M9 — Visual and presentation systems
**Priority:** P3/P4 · **Status:** Planned

**Major engine features**
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

**Acceptance checks**
- Check visual timing against music and gameplay.
- Keep notes, characters, and important HUD information readable.
- Provide reduced-motion options and performance fallbacks.
- Profile representative lower-end Android hardware as well as Windows.

**Exit:** Visual features are optional, configurable, performant, and do not obscure gameplay.

## M10 — Creator toolkit and chart-editor expansion
**Priority:** P4 · **Status:** Planned · **Depends on M6**

**Creator tools**
- Visual Event Builder.
- Camera Path Editor.
- Cutscene Timeline Editor for animation, dialogue, and audio.
- Sprite Atlas Editor.
- Shader Editor and live shader previews.
- Stage Prop Editor.
- Audio Waveform Editor.
- Character Behavior Editor.
- Animation Transition Editor.
- Dialogue Branching Editor.
- Visual Script Graph.
- Multi-File Mod Projects.
- Live Preview Windows.

**Chart Editor QoL**
- Automatic recovery after a crash.
- Visible unsaved-changes indicator.
- Multiple charts open simultaneously.
- Chart comparison mode.
- Bulk note editing and bulk event editing.
- Copy/paste between charts.
- Custom timeline markers.
- Adjustable waveform display.
- Customizable editor panels and workspace presets.
- Inline chart validation warnings.
- Search and replace chart events.

**Acceptance checks**
- Build a sample mod using the creator workflow.
- Save, reopen, validate, preview, and package it.
- Test crash recovery and unsaved changes.
- Ensure editor functions are clearly marked when unavailable on Android or other restricted form factors.

**Exit:** A documented creator workflow can build, validate, preview, and package supported mod content.

## M11 — Windows, accessibility, diagnostics, and recovery QoL
**Priority:** Continuous · **Status:** Planned and applied incrementally

**Windows PC QoL**
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

**Accessibility**
- Colorblind-friendly gameplay indicators.
- Reduced animation and motion mode.
- High-contrast interface theme.
- Adjustable interface text size.
- Optional visual audio cues.
- Configurable background dimming.

**Diagnostics and recovery**
- Detailed crash reports.
- Built-in log viewer.
- One-click diagnostic report export.
- Startup troubleshooting mode.
- Safe-mode suggestion after repeated crashes.
- Memory usage warnings.
- Missing asset detection.
- Performance bottleneck explanations.

**Acceptance checks**
- Test Windows window management, multi-monitor behavior, controller reconnection, file drop, and file associations.
- Test accessibility settings throughout menus and gameplay.
- Verify diagnostic reports avoid exposing private data and contain actionable information.
- Verify recovery paths preserve user saves and mod files.

**Exit:** The engine has practical accessibility, diagnostics, and recovery tools, with Windows-specific QoL complete.

## M12 — Online Mod Hub and community services
**Priority:** P4 · **Status:** Planned · **Deliberately deferred until local manager and SDK are stable**

**Major engine features**
- Built-in Online Mod Hub.
- Online Mod Pages with descriptions, screenshots, authors, version information, and changelogs.
- Browse and search community-hosted mods and collections.
- Update discovery.
- Dependency discovery and installation after compatibility checks and user approval.
- Mod ratings/reviews where moderation and abuse controls are available.
- Clear download sources, package integrity verification, moderation/reporting, and safe rollback.

**Rules**
- The Hub is optional; local mod installation must continue to work offline.
- Never silently execute or install untrusted packages.
- Validate compatibility and integrity before installation.
- Make source, permissions, and dependency changes clear to the player.
- Do not begin this milestone until the local Mod Manager, SDK, and package security model are stable.

**Acceptance checks**
- Test the Hub while online, offline, and under unreliable network conditions.
- Test invalid, removed, incompatible, and malicious package scenarios.
- Verify user approval is required for install/update/dependency changes.
- Test rollback and local-only workflows.

**Exit:** The optional online ecosystem is safe, maintainable, and does not compromise offline use.

## M13 — NovaBeat 1.0 release hardening
**Priority:** Release gate · **Status:** Planned

**Purpose:** Turn the accumulated features into a stable, supportable release.

**Work**
- Freeze the release feature set and fix high-impact bugs.
- Complete Windows and Android regression suites.
- Verify Android phone/tablet portrait and landscape layouts.
- Verify original FNF gameplay and representative third-party mods.
- Verify save migration, mod isolation, backup/restore, and recovery.
- Run performance, memory, startup, long-session, and low-storage tests.
- Verify crash reporting, safe mode, and diagnostics.
- Audit license notices, package contents, version metadata, and private distribution.
- Produce release notes and a known-issues list.
- Publish verified Windows and Android deliverables to the private NovaBeat-Builds repository.

**1.0 acceptance gate**
- Windows package installs/launches and passes the supported smoke/regression tests.
- Android APK installs/launches and passes phone/tablet, portrait/landscape, touch, lifecycle, and storage tests.
- No known release-blocking data-loss, save-corruption, security, or gameplay-timing issues.
- Both downloadable packages match the tested source commit and have recorded SHA-256 hashes.

**Exit:** NovaBeat 1.0 is tagged, documented, and downloadable for Windows and Android.

---

# Cross-milestone quality-of-life policy

QoL work is tracked separately from major engine features. It can be delivered alongside a milestone when it is low-risk and relevant, but it must not silently delay the core milestone.

- **Gameplay QoL** is delivered with M7.
- **Mod Manager QoL** is delivered with M4.
- **Settings and navigation QoL** is delivered with M5.
- **Chart Editor QoL** is delivered with M10.
- **Android QoL** is split between the mobile foundation in M2 and later refinements.
- **Windows QoL** is delivered with M11.
- **Accessibility, diagnostics, and recovery** are improved continuously and consolidated in M11/M13.

The approved backlog remains the detailed item inventory. This roadmap determines the intended sequence and acceptance gates; it does not remove any approved proposal.

# Build, testing, and delivery policy

- **Small code changes:** review and run focused/static checks; do not launch both full native builds automatically.
- **Feature milestone or large batch:** compile the affected platform(s); compile both platforms when shared engine code changes.
- **Platform-specific work:** run the relevant platform build and tests.
- **Release candidate:** run full Windows and Android builds, verify the packages, and smoke-test them.
- **Windows-only build:** must not start Android.
- **Android-only build:** must not start Windows.
- **Distribution:** successful Windows packages and Android APKs go to the private NovaBeat-Builds repository, never to public releases.
- **Verification:** compilation success is not the same as runtime testing. Report each state separately: implemented, compiled, package delivered, and behavior tested.

# Dependency order at a glance

1. M0 — Source/build/delivery foundation.
2. M1 — Original FNF parity and platform baseline.
3. M2 — Android portrait/landscape and mobile experience.
4. M3 — Native in-game Mod Manager MVP.
5. M4 — Mod Manager Plus and local library.
6. M5 — NovaBeat UI identity and navigation.
7. M6 — Mod SDK and extension architecture.
8. M7 — Gameplay systems.
9. M8 — Audio systems.
10. M9 — Visual/presentation systems.
11. M10 — Creator toolkit.
12. M11 — Windows QoL, accessibility, diagnostics, and recovery (continuous).
13. M12 — Online Mod Hub (after M4 and M6; intentionally late).
14. M13 — NovaBeat 1.0 release hardening (after the required feature set).

## Scope reminder

- Windows PC and Android phones/tablets only.
- Android portrait and landscape are required.
- Preserve the original FNF experience as the default.
- The Mod Manager is built into the game; no separate launcher.
- Keep major engine features and QoL improvements distinct.
- All roadmap items remain planned until implementation, platform verification, and acceptance checks are complete.
