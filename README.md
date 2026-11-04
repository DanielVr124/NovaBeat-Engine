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

## Repository status

This repository currently contains the project README, roadmap, and approved backlog. The complete upstream FNF source tree has **not** yet been imported into this repository.

The owner-provided baseline archive is Friday Night Funkin' **0.8.6**. A separate updated source ZIP and a patch-only ZIP have been prepared in the development conversation, but the GitHub integration available in this session cannot push a multi-file binary archive or bulk-import the full source tree. Do not treat this repository as buildable yet.

The source archive also references the official `assets` and `art` Git submodules. Those contents were not included in the uploaded archive and must be initialized separately before a complete build can be produced.

## Source import next step

To make this repository independently buildable, import the complete FNF 0.8.6 source tree, preserve its upstream license notices, initialize the `assets` and `art` submodules, and then apply/review the NovaBeat Mod Manager source changes. The current Mod Manager integration is desktop-first; Android manager UI, Android file importing, portrait/landscape layouts, and orientation-aware transitions remain planned work.

## Upstream and licensing

NovaBeat is an unofficial community project and is not affiliated with or endorsed by The Funkin' Crew Inc. Friday Night Funkin' and its original code, artwork, audio, and trademarks remain subject to their respective copyright and license terms. The upstream source identifies its code as Apache-2.0; bundled assets have separate licensing. Retain all required upstream notices and review the relevant licenses before redistributing source or builds.

- Upstream source: https://github.com/FunkinCrew/Funkin
- Modding documentation: https://funkincrew.github.io/funkin-modding-docs/
