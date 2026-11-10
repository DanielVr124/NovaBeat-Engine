# Psych Engine compatibility status

NovaBeat keeps native V-Slice mod loading as its primary path and uses a separate compatibility adapter for Psych Engine packages. A Psych package is never allowed to replace the original Friday Night Funkin' menu or intercept a mod's own menu code.

This document describes the current compatibility tier, not a claim that every Psych mod works.

## Package layouts

The native mod-folder scanner recognizes chart packages in both of these locations:

- Classic psych_v1 charts: `mods/<mod>/data/<song>/`
- Song-package charts: `mods/<mod>/songs/<song>/`

Audio is resolved from `songs/<song>/` or `assets/songs/<song>/`. The instrumental must be named `Inst.ogg`, `Inst.mp3`, or `Inst.wav`. Song-local scripts are read from the folder containing the charts; global scripts are read from `scripts/`.

## Chart formats

### psych_v1

The adapter passes legacy Psych chart JSON through the existing FNF legacy chart importer, then translates the result to native V-Slice song data. Existing V-Slice chart loading is unchanged.

Common Psych stage IDs are mapped to corresponding built-in V-Slice stage IDs. When the chart omits its stage, the compatibility layer applies the standard base-game week stage mapping for the original song names. A custom Psych stage script runs over NovaBeat's valid base stage; the adapter does not try to fetch a V-Slice StageRegistry entry for a Psych-only stage ID.

### psych_v2 (limited subset)

The adapter currently converts charts with the standard opponent and player strumlines, four columns per line, standard note timing/length/type/alt-animation fields, section BPM changes, time signatures, and camera targets.

The current V-Slice song data model has a single shared event timeline and two standard gameplay lanes. The adapter therefore does not claim support for additional/silent strumlines, GF-owned notes, variable key counts, mid-song key-count changes, mid-song scroll-velocity changes, or different embedded/external event timelines for multiple difficulties. Packages that would lose those mechanics are kept unavailable rather than launched with incomplete behavior.

## Scripts and gameplay

The compatibility runtime can discover global and song-local Lua/HScript files, as well as named stage, character, custom-event, and custom-note-type scripts. It exposes a bounded Psych-style callback and gameplay API. For a song, global and referenced scripts load before note/event generation; `onCreate` and `onSongLoaded` run after chart generation; `onCreatePost` runs exactly once after the PlayState scene is initialized and before countdown callbacks. Script execution is sandboxed; arbitrary native libraries, host process access, and unrestricted filesystem/network access are not provided.

A package using the legacy `custom_notes/` runtime is currently rejected. Custom stages still need a matching stage script, and custom character data must be in a format that the current character adapter can convert.

The built-in event adapter currently handles camera zoom, screen shake, property changes, camera follow position, character animation, Hey!, GF dance speed, and Change Character (BF/GF/DAD swaps). The built-in event list is not yet complete. Other events must have a matching custom-event script. Unknown or unhandled behavior must not be silently dropped.

## Platform scope

The filesystem-based Psych package adapter currently requires a native build. The HTML5 build is still useful for V-Slice/browser regression checks, but it does not establish native Psych mod compatibility.

## Verification checklist

The current test pass should cover:

1. A classic psych_v1 song with an instrumental and vocals.
2. A psych_v1 song in the newer `songs/<song>/` package layout.
3. A psych_v2 song with opponent/player four-key strumlines.
4. Non-4/4 section timing and a section BPM change.
5. A common built-in Psych stage and a custom stage script.
6. A custom character JSON and its character script.
7. Global and song-local Lua scripts, followed by an HScript script.
8. A built-in Psych event and a custom event script.
9. A custom note type script.
10. A chart with an extra strumline or unsupported key count, which must be rejected with a clear reason.
11. A package with multiple difficulty-specific event files, which must be rejected until difficulty-aware event storage exists.
12. V-Slice mods before and after Psych activation to confirm the native path remains unchanged.

A successful compile is only a source/build check. Actual gameplay behavior still requires running these packages in the Windows build and comparing results with the corresponding Psych Engine version.
