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

See [ROADMAP.md](ROADMAP.md), [docs/APPROVED_BACKLOG.md](docs/APPROVED_BACKLOG.md), [docs/SOURCE_IMPORT.md](docs/SOURCE_IMPORT.md), and [docs/BUILDING.md](docs/BUILDING.md).

## Source repository

The complete FNF v0.8.6 source code is stored directly in this repository under `upstream/Funkin/`, pinned to upstream commit `ee9d492becfc1178b2c80487167d09a880f90146`. This is a vendored copy of the source tree, not a fork or source submodule.

The separately licensed upstream `assets` and `art` repositories remain pinned as submodules. Run `git submodule update --init --recursive` to fetch them, or use `git clone --recurse-submodules` when cloning NovaBeat.

The repository now includes independent Windows desktop and Android build checks in GitHub Actions. A green job verifies that the upstream FNF 0.8.6 baseline compiles for that platform; it does not mean the proposed NovaBeat Mod Manager or other backlog features are implemented. See [docs/BUILDING.md](docs/BUILDING.md) for local build requirements and the known Android orientation limitation.

## Build verification

The [NovaBeat platform build checks](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-platform-builds.yml) workflow compiles a Windows release executable and an Android debug APK independently. It does not publish binaries because the upstream asset and art licenses restrict public redistribution.

## Development status

Roadmap and approved backlog entries are proposals until their implementation is reviewed, compiled, and tested. Windows and Android remain the only targets; Android must support both portrait and landscape.

## Upstream and licensing

NovaBeat is an unofficial community project and is not affiliated with or endorsed by The Funkin' Crew Inc. Friday Night Funkin' and its original code, artwork, audio, and trademarks remain subject to their respective copyright and license terms.

The upstream source code is licensed under Apache-2.0; retain its notice in `upstream/Funkin/LICENSE.md`. The separate `assets` and `art` repositories have their own licensing terms. The source-code license does not automatically grant permission to redistribute those materials.

- Upstream source: https://github.com/FunkinCrew/Funkin
- Upstream release: https://github.com/FunkinCrew/Funkin/releases/tag/v0.8.6
- Modding documentation: https://funkincrew.github.io/funkin-modding-docs/

For a private HTML5 test build from a feature branch, include `[web-build]` in the commit message. The build is packaged and published separately from the Windows and Android packages.

<!-- [full-build-android] -->
<!-- Android build trigger: 1794538617689 -->
