# Vendored upstream source

The official Friday Night Funkin' v0.8.6 source files are stored directly in this repository at `upstream/Funkin/`.

- Upstream: https://github.com/FunkinCrew/Funkin
- Version: v0.8.6
- Exact source commit: `ee9d492becfc1178b2c80487167d09a880f90146`

This is a vendored source tree, not a link to a fork or a source submodule. The engine code, project files, build scripts, documentation, and upstream license notices are ordinary files committed in NovaBeat.

## Artwork and asset repositories

Upstream FNF stores `assets` and `art` in separate repositories. They remain pinned as Git submodules at the exact revisions recorded by FNF v0.8.6, because they have separate licensing terms.

To fetch those two submodules after cloning:

```bash
git submodule update --init --recursive
```

Or clone NovaBeat and initialize them in one step:

```bash
git clone --recurse-submodules https://github.com/DanielVr124/NovaBeat-Engine.git
```

## Building

See [BUILDING.md](BUILDING.md) for the Windows desktop and Android toolchains and the reproducible GitHub Actions build checks. The original FNF compilation guides remain available at `upstream/Funkin/docs/COMPILING.md` and `upstream/Funkin/docs/COMPILING_MOBILE.md`.

The Android build check compiles the current upstream landscape-oriented Android configuration. It does not complete NovaBeat's separate requirement for responsive portrait and landscape layouts. Runtime behavior and device testing remain separate from compilation.

## Licensing

FNF source code includes its upstream Apache-2.0 license notice in `upstream/Funkin/LICENSE.md`. The separate `assets` and `art` repositories have their own licenses. Their licenses prohibit public redistribution of their proprietary content by anyone other than the copyright owner. Keep the content private and do not publish game binaries containing it.
