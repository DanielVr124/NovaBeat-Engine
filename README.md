# Friday Night Funkin': NovaBeat Engine

**A New Rhythm. A New Experience.**

NovaBeat Engine is an unofficial community engine project based on Friday Night Funkin'. The goal is to expand the game with a polished native mod manager, more flexible gameplay and audio systems, creator tools, richer presentation, and quality-of-life improvements.

## Platform targets

- **Windows PC**
- **Android phones and tablets**, with both portrait and landscape layouts

iOS is intentionally outside the project scope. NovaBeat does not plan to ship a separate launcher; it remains a game you launch directly.

## Project priorities

1. Establish a reliable Windows and Android source/build foundation.
2. Deliver a native in-game Mod Manager.
3. Build a safe, extensible mod and gameplay API.
4. Add player-facing gameplay, audio, and presentation features.
5. Expand the creator toolchain.
6. Polish accessibility, performance, and diagnostics.

See [ROADMAP.md](ROADMAP.md) for the prioritized plan and [docs/APPROVED_BACKLOG.md](docs/APPROVED_BACKLOG.md) for the approved proposal list.

## Current source baseline

The initial development baseline supplied for this project is Friday Night Funkin' **0.8.6**.

The `patches/FNF-0.8.6-Mod-Manager.patch` file contains the initial native desktop Mod Manager source changes prepared against that baseline. It is a patch, not a complete copy of the upstream game source. The Windows build and runtime behavior have **not** yet been verified.

The supplied source archive references the official `assets` and `art` Git submodules. Those contents are not included in the uploaded archive and must be initialized separately before a complete build can be produced.

## Applying the initial patch

1. Obtain the exact FNF 0.8.6 source tree and initialize its required submodules.
2. From the root of that source tree, apply the patch:
   ```sh
   git apply /path/to/FNF-0.8.6-Mod-Manager.patch
   ```
3. Review the changes, install the Haxe/Lime dependencies, and build the Windows target using the upstream compiling guide.
4. Run the mod-manager test checklist in `docs/MOD_MANAGER.md`.

The current patch is desktop-first. Android support for the native manager, Android file importing, portrait/landscape layouts, and orientation-aware transitions are planned work and must not be considered implemented yet.

## Upstream and licensing

NovaBeat is an unofficial community project and is not affiliated with or endorsed by The Funkin' Crew Inc. Friday Night Funkin' and its original code, artwork, audio, and trademarks remain subject to their respective copyright and license terms. The upstream source identifies its code as Apache-2.0; bundled assets have separate licensing. Retain all required upstream notices and review the relevant licenses before redistributing source or builds.

- Upstream source: https://github.com/FunkinCrew/Funkin
- Modding documentation: https://funkincrew.github.io/funkin-modding-docs/
