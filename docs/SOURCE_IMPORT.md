# Upstream source checkout

NovaBeat tracks the official Friday Night Funkin' v0.8.6 repository as a Git submodule.

- **Submodule path:** `upstream/Funkin`
- **Upstream repository:** https://github.com/FunkinCrew/Funkin
- **Pinned tag:** `v0.8.6`
- **Pinned commit:** `ee9d492becfc1178b2c80487167d09a880f90146`

This avoids requiring a GitHub fork. The submodule pointer lives in the NovaBeat repository; the upstream files are checked out into the working directory when Git initializes submodules.

## First-time clone

```bash
git clone --recurse-submodules https://github.com/DanielVr124/NovaBeat-Engine.git
cd NovaBeat-Engine
```

## Existing clone

From the NovaBeat repository directory:

```bash
git submodule update --init --recursive
```

The recursive step is important. The upstream FNF repository contains its own `assets` and `art` submodules. Those are separate repositories, pinned by the upstream FNF commit.

## Build location

The upstream game project is under:

```text
upstream/Funkin/
```

Read the upstream `docs/COMPILING.md` for desktop prerequisites and `docs/COMPILING_MOBILE.md` for mobile/Android prerequisites. Do not assume a successful clone means the project has already compiled.

## Licensing and redistribution

The upstream source repository identifies its code as Apache-2.0 and includes its license notice in `upstream/Funkin/LICENSE.md`. The `assets` and `art` submodules have separate licensing terms. Keep the submodules pinned as upstream specifies, and do not redistribute artwork, music, or other protected assets unless the applicable license permits it.

## NovaBeat status

This import establishes the source baseline only. It does not mark any proposed NovaBeat backlog item as implemented. NovaBeat's Windows and Android build setup, Android portrait/landscape behavior, Mod Manager integration, and regression testing must be completed and verified separately.
