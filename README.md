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

See [ROADMAP.md](ROADMAP.md), [docs/APPROVED_BACKLOG.md](docs/APPROVED_BACKLOG.md), and [docs/SOURCE_IMPORT.md](docs/SOURCE_IMPORT.md).

## Source repository

The complete FNF v0.8.6 **source code is stored directly in this repository** under , pinned to upstream commit . This is a vendored copy of the source tree, not a fork or source submodule.

The separately licensed upstream  and  repositories remain pinned as submodules. Run  to fetch them, or use  when cloning NovaBeat.

The source import does **not** mean NovaBeat is already buildable. Windows and Android dependency setup, baseline compilation, Mod Manager integration, and regression testing still need to be completed.

## Development status

Roadmap and approved backlog entries are proposals until their implementation is reviewed, compiled, and tested. Windows and Android remain the only targets; Android must support both portrait and landscape.

## Upstream and licensing

NovaBeat is an unofficial community project and is not affiliated with or endorsed by The Funkin' Crew Inc. Friday Night Funkin' and its original code, artwork, audio, and trademarks remain subject to their respective copyright and license terms.

The upstream source code is licensed under Apache-2.0; retain its notice in . The separate  and  repositories have their own licensing terms. The source-code license does not automatically grant permission to redistribute those materials.

- Upstream source: https://github.com/FunkinCrew/Funkin
- Upstream release: https://github.com/FunkinCrew/Funkin/releases/tag/v0.8.6
- Modding documentation: https://funkincrew.github.io/funkin-modding-docs/
