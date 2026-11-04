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

## Repository status

The official Friday Night Funkin' **v0.8.6** source is now tracked at `upstream/Funkin` as a pinned Git submodule. It is pinned to upstream commit `ee9d492becfc1178b2c80487167d09a880f90146`. You do **not** need to fork the upstream repository.

To download the source when cloning NovaBeat, use:

```bash
git clone --recurse-submodules https://github.com/DanielVr124/NovaBeat-Engine.git
```

If you already cloned NovaBeat without submodules, run:

```bash
git submodule update --init --recursive
```

The upstream FNF repository itself tracks `assets` and `art` as separate nested submodules. Recursive initialization checks out the exact revisions recorded by FNF 0.8.6. The NovaBeat repository is **not yet a verified build**: Windows/Android dependency setup, baseline compilation, and gameplay regression testing still need to be completed.

## Development status

Roadmap and approved backlog entries are proposals until their implementation is reviewed, compiled, and tested. Windows and Android remain the only targets; Android must support both portrait and landscape.

## Upstream and licensing

NovaBeat is an unofficial community project and is not affiliated with or endorsed by The Funkin' Crew Inc. Friday Night Funkin' and its original code, artwork, audio, and trademarks remain subject to their respective copyright and license terms.

The upstream source code is licensed under Apache-2.0. The separate `assets` and `art` repositories have their own licensing terms; the source-code license does not automatically grant permission to redistribute those materials. Preserve upstream notices and review all relevant licenses before redistributing source or builds.

- Upstream source: https://github.com/FunkinCrew/Funkin
- Upstream release: https://github.com/FunkinCrew/Funkin/releases/tag/v0.8.6
- Modding documentation: https://funkincrew.github.io/funkin-modding-docs/
