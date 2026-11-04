# Vendored upstream source

The official Friday Night Funkin' v0.8.6 source files are stored directly in this repository at .

- Upstream: https://github.com/FunkinCrew/Funkin
- Version: v0.8.6
- Exact source commit: 

This is a vendored source tree, not a link to a fork or a source submodule. The engine code, project files, build scripts, documentation, and upstream license notices are ordinary files committed in NovaBeat.

## Artwork and asset repositories

Upstream FNF stores  and  in separate repositories. They remain pinned as Git submodules at the exact revisions recorded by FNF v0.8.6, because they have separate licensing terms.

To fetch those two submodules after cloning:

Submodule path 'upstream/Funkin/art': checked out '429ab728b19272dca834c83d97b1646455b22579'
Submodule path 'upstream/Funkin/assets': checked out '9300719cb261d23f72344807055be6d109c9949c'

Or clone NovaBeat and initialize them in one step:

Submodule path 'upstream/Funkin': checked out 'ee9d492becfc1178b2c80487167d09a880f90146'
Submodule path 'upstream/Funkin/art': checked out '429ab728b19272dca834c83d97b1646455b22579'
Submodule path 'upstream/Funkin/assets': checked out '9300719cb261d23f72344807055be6d109c9949c'

## Build status

Importing source does not mean the project has been compiled or tested. Follow  for desktop setup and  for mobile setup. NovaBeat's Windows build, Android build, Android portrait/landscape UI, Mod Manager integration, and regression tests still require implementation and verification.

## Licensing

FNF source code includes its upstream Apache-2.0 license notice in . The separate  and  repositories have their own licenses. Retain the upstream notices and do not redistribute material from those repositories unless their applicable licenses permit it.
