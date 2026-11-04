# Friday Night Funkin': NovaBeat Engine

**A New Rhythm. A New Experience.**

NovaBeat Engine is an unofficial community engine project based on Friday Night Funkin'. The goal is to expand the game with a polished native mod manager, more flexible gameplay and audio systems, creator tools, richer presentation, and quality-of-life improvements.

## Platform targets

- **Windows PC**
- **Android phones and tablets**, with both portrait and landscape layouts
- **Experimental HTML5 browser test build** for private testing; this is not yet a supported release platform

iOS is intentionally outside the project scope. NovaBeat does not plan to ship a separate launcher; it remains a game you launch directly.

## Project priorities

1. Establish a reliable Windows and Android source/build foundation.
2. Deliver a native in-game Mod Manager.
3. Build a safe, extensible mod and gameplay API.
4. Add player-facing gameplay, audio, and presentation features.
5. Expand the creator toolchain.
6. Polish accessibility, performance, and diagnostics.

See [ROADMAP.md](ROADMAP.md), [docs/APPROVED_BACKLOG.md](docs/APPROVED_BACKLOG.md), [docs/SOURCE_IMPORT.md](docs/SOURCE_IMPORT.md), and [docs/BUILDING.md](docs/BUILDING.md).

## Source repository

The complete FNF v0.8.6 source code is stored directly in this repository under `upstream/Funkin/`, pinned to upstream commit `ee9d492becfc1178b2c80487167d09a880f90146`. This is a vendored copy of the source tree, not a fork or source submodule.

The separately licensed upstream `assets` and `art` repositories remain pinned as submodules. Run `git submodule update --init --recursive` to fetch them, or use `git clone --recurse-submodules` when cloning NovaBeat.

The repository includes independent Windows desktop and Android build checks, plus a separate experimental HTML5 browser test workflow. A green job verifies that the upstream FNF 0.8.6 baseline compiles for that platform; it does not mean the proposed NovaBeat Mod Manager or other backlog features are implemented. See [docs/BUILDING.md](docs/BUILDING.md) for build requirements and [docs/HTML5_TESTING.md](docs/HTML5_TESTING.md) for browser testing.

## Build verification

The [NovaBeat platform build checks](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-platform-builds.yml) workflow compiles Windows and Android independently. The separate [HTML5 browser test workflow](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-html5.yml) packages the experimental browser build. Every successfully packaged target, including pull-request builds, is automatically published by a separate workflow to the private NovaBeat-Builds Releases because upstream FNF art and assets cannot be redistributed publicly.

## Development status

Roadmap and approved backlog entries are proposals until their implementation is reviewed, compiled, and tested. Windows and Android remain the supported native release targets; Android must support both portrait and landscape. HTML5 is an experimental private testing target.

## Upstream and licensing

NovaBeat is an unofficial community project and is not affiliated with or endorsed by The Funkin' Crew Inc. Friday Night Funkin' and its original code, artwork, audio, and trademarks remain subject to their respective copyright and license terms.

The upstream source code is licensed under Apache-2.0; retain its notice in `upstream/Funkin/LICENSE.md`. The separate `assets` and `art` repositories have their own licensing terms. The source-code license does not automatically grant permission to redistribute those materials.

- Upstream source: https://github.com/FunkinCrew/Funkin
- Upstream release: https://github.com/FunkinCrew/Funkin/releases/tag/v0.8.6
- Modding documentation: https://funkincrew.github.io/funkin-modding-docs/
