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

## Build status

Importing source does not mean the project has been compiled or tested. Follow `upstream/Funkin/docs/COMPILING.md` for desktop setup and `upstream/Funkin/docs/COMPILING_MOBILE.md` for mobile setup. NovaBeat's Windows build, Android build, Android portrait/landscape UI, Mod Manager integration, and regression tests still require implementation and verification.

## Licensing

FNF source code includes its upstream Apache-2.0 license notice in `upstream/Funkin/LICENSE.md`. The separate `assets` and `art` repositories have their own licenses. Retain the upstream notices and do not redistribute material from those repositories unless their applicable licenses permit it.
