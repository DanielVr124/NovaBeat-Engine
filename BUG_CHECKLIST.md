# NovaBeat bug checklist

Branch: `integration/nb-fixes` · latest commit: `bb78374` · updated 2026-11-16

Everything here is **compile-checked only**. The last two Windows builds went green,
which proves the Haxe compiles and links — not that any behaviour is correct.
Tick items as you test them.

Status: `[ ]` untested · `[x]` works · `[!]` broken (add a note)

---

## 1. Fixes waiting on a runtime test

### [ ] Death no longer crashes on the way back to Freeplay — `6b90c0a`
Play any song, die, let the game-over screen appear, then continue or leave.
**Pass:** no crash, Freeplay loads normally.

### [ ] Notes that could never be hit — `207fa09`
Play **SHELF**, watch the section around 42–44 seconds.
**Pass:** no arrows that are impossible to hit.

### [ ] Blank / cropped freeplay icons — `dd285cd`, `ae21525`
Open Freeplay and look at the icon column.
**Pass:** all 12 icons draw (capuchin, mgkid, gorilla, lucy, …), none sliced.
Regression note: the old code assumed 150×150 icons; yours are e.g. `243×92`.

### [ ] Health bar faces in gameplay — `e2943ee`, `dd285cd`
Start any song and look at both ends of the health bar.
**Pass:** a face on each end, no Flixel logo, nothing blank.

### [ ] Freeplay icons on the right — `8f53477`
Open Freeplay.
**Pass:** titles start at the left, icons sit in a right-hand column.
Also check: clicking an icon selects that row (the hitbox moved with it).

### [ ] Psych stage placement — `2ba64fc`
Play a song on the **City** stage (e.g. SHELF) and compare with real Psych Engine.
**Pass (expected):** GF far left, not between the opponent and BF; camera pulled
back to the stage's `defaultZoom` (0.85); BF standing on the floor, not buried.
**If GF is still mid-screen:** the stage name is still being lost — send
`logs/psych-stage.log`, it now records which stage name and folder were used.

### [ ] Stage diagnostics log — `975743f`
After playing a Psych song, `logs/psych-stage.log` should exist next to the game.
**Pass:** file exists and contains `resolve`, `stage-found` / `stage-not-found`,
`stage-applied` and `place-*` lines.

### [ ] Unsupported mods load — `544f2db`
Enable a mod that previously said it couldn't launch, then launch it.
**Pass:** it opens instead of being refused. Charts it genuinely cannot parse
may still show no notes — that is a data limit, not a refusal.

### [ ] Menu behaviour batch — `bb78374`
- [ ] **Navigate during a transition** — press down/up while a screen is still
      fading in. **Pass:** selection moves during the fade.
- [ ] **Enter skips ahead** — press Enter/Z during a fade-in. **Pass:** screen
      appears instantly. **Watch for:** the menu immediately launching something,
      which would mean the press was not consumed (it should be).
- [ ] **Pause in the opening cutscene** — start a Psych song with an intro and
      press pause. **Pass:** pause menu opens and you can skip.
- [ ] **Psych Freeplay transition** — open Psych Freeplay from the main menu.
      **Pass:** same black fade as Title → Main Menu.
- [ ] **Engine exclusivity** — in the mods menu, enable a Psych mod while a
      V-Slice mod is on (and the reverse). **Pass:** the other family turns off,
      mods from the same engine stay on.

---

## 2. Known bugs, not fixed yet

1. **Icon can get stuck invisible forever** — a failed load sets `visible = false`
   and nothing restores it, so a later successful reload stays hidden.
   `HealthIcon.hx:508`
2. **Stage scripts stop being recognised after a mod rescan** — `isRootPsychStageScript`
   still reads the volatile maps; it should use the persistent ones.
   `PsychModRuntime.hx:1123-1124` (also 123, 820, 858)
3. **Freeplay icon column assumes 150px width** — wide icons (`icon-lucy.png` is
   334px) can hang past the right margin. `PsychFreeplayState.hx:745-749`
4. **Freeplay row hitboxes hardcode height** — `+82`, `-20`, `-18` instead of the
   row's real size, so clicks land off on tall/short rows. `PsychFreeplayState.hx:618-621`
5. **Dead "NOT YET SUPPORTED" label** — unreachable now that every mod is
   launchable. `ExperienceLibraryState.hx:431`
6. **Missing icon files in the mod** — `Starved` wants `icon-starved`,
   `bf-dead` wants `icon-bfgorilla`; neither PNG exists, so those are always blank.
   Could fall back to a sibling icon.

---

## 3. Partial fixes / known risks

- **Psych Freeplay fade is main-menu only.** `FreeplayState.hx:3520` opens the
  same screen from vanilla Freeplay with no fade.
- **Enter skips the fade-in only.** The 0.7s fade-out still plays; cutting it
  short risked swallowing the state switch.
- **Engine exclusivity is enforced in the toggle only.** Mods enabled via a saved
  config, or a V-Slice extension already attached to a Psych experience, are not
  re-sorted.
- **`allowInputDuringTransition` defaults to true everywhere, including
  `PlayState`.** Gameplay now keeps updating during its entry fade. If anything
  odd happens at song start, this is the first suspect.
- **The cutscene-pause fix relaxes a guard that existed for a reason** (a latched
  Psych Freeplay launch input could open the pause menu). If the pause menu opens
  by itself at the start of a Psych song, that is the regression.

---

## 4. Not investigated yet

- **BF's vertical anchor.** Psych measures a character's Y from the top of the
  sprite, V-Slice positions from the feet. Needs the numbers in
  `logs/psych-stage.log` (`origin`, `height`, `scale` per role), not a guess.
- **Health icons in the first NovaBeat screenshot were missing entirely** and the
  bar showed a strange coloured block. Believed fixed by the icon sizing work.
  Re-test and confirm.
