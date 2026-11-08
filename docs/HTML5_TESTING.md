# NovaBeat HTML5 — Mobile Fix Verification

This checklist belongs to the feature branch `feature/optional-novabeat-menu-mod-manager`.
It is a verification guide, not a claim that every item has passed on a physical device.

## Changes included in this browser build

- [x] Add versioned Service Worker asset caching. A new cache is populated before activation; an incomplete download is discarded and the prior cache is retained.
- [x] Prevent scheme-preview hitboxes from registering duplicate live gameplay input bindings.
- [x] Reposition the Double Thumb DPad clusters so the two thumb zones remain separate on narrow portrait screens.
- [x] Put the five control schemes in the same order in the mobile settings and scheme picker: Arrows, Four Lanes, Double Thumb DPad, Triangle, Square.
- [x] Use the same release-based touch selection helper as the working Performance submenu for the Customization category and NovaBeat menu-customization rows.
- [x] Restore the original FNF Story Mode swipe mapping in NovaBeat instead of applying the extra inverted mapping.
- [x] Keep the NovaBeat portrait Story Mode week-title and difficulty-sprite anchors centered after selection changes.
- [x] Improve mobile Mod Library cards with enabled state, version, author, and a short description.
- [x] Increase the readability of NovaBeat portrait main-menu tiles.

## Physical-device verification still required

- [ ] **Portrait layout:** test title/main menu, Story Mode, Options and gameplay in portrait; rotate during use and confirm no clipped controls or stuck layout.
- [ ] **Two-thumb / DPad controls:** open the scheme picker, preview Double Thumb DPad, select it, back out, then start a song. Confirm the menu does not freeze and both thumb clusters are independently usable.
- [ ] **Offline cache:** load once online, wait for the Service Worker to finish installing, then reload offline. Confirm the game opens. Reconnect after a new build and confirm the new version replaces the old cache only after download succeeds.
- [ ] **Mobile Mod Library:** check card sizing, selection, details, action buttons, scrolling, and back navigation on a phone. Browser builds cannot scan a local mods directory; that limitation is enforced by browser security.
- [ ] **Story Mode:** drag upward and downward with both touch and mouse; confirm the week list moves opposite the finger. Check week-name and difficulty alignment in portrait and landscape.
- [ ] **Customization:** test every category and every row by tapping, changing values, scrolling where applicable, and returning with Back. Confirm settings persist.
- [ ] **NovaBeat main menu:** test portrait and landscape tile sizing, top-bar buttons, selection transitions, music, and repeated rotation. Desktop NovaBeat and the original FNF menu must remain unchanged.

## Items not changed blindly

- [ ] **Gyroscope sensitivity:** no gyroscope/device-orientation input handler was found in the NovaBeat main-menu source or the checked HTML previews. The effect's actual implementation needs to be located before changing its sensitivity.
- [ ] **Memory optimization:** the engine already has a texture/audio cache manager and purge lifecycle. No broad cache purge was added because it could evict assets still in use; memory needs measurement during repeated song and menu transitions.
- [ ] **Gameplay lag spikes/crash:** no visual, audio, animation, FPS, or gameplay-quality reductions were made. The reported spikes begin when gameplay activity starts; profiling on the affected browser/device is needed to distinguish asset decode, memory growth, audio, and per-frame work.

## Browser Mod Library limitation

A web page cannot enumerate or modify a user's local mods folder. The HTML5 screen can explain this limitation, but actual local Polymod discovery and enable/disable operations require a native build unless a separate browser-import workflow is implemented.

## Test report

When reporting results, include:
- Device and browser/version.
- Portrait or landscape orientation.
- Which control scheme was selected.
- Whether the problem happens before a song, during countdown, or after notes/characters start moving.
- Any browser console error or crash message, if available.

## Matching native-build source snapshot

- The HTML5 companion build is requested against the same NovaBeat engine source snapshot as Windows commit `6269ee8c1c50bb4d805010c510245d5dd041dbed`.
- The build-trigger commit changes this checklist only; no engine or asset source is changed by the trigger.
- The Windows build remains the required target for testing locally installed Psych mods because browser security prevents local mod-folder discovery.
