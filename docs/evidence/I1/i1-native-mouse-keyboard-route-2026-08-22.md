# I1 native mouse/keyboard route — 2026-08-22

## Scope

This is a focused input/route gate, not a playability claim. The fixed product
goal remains native Jak 1 on iPad, then iPhone parity and physical-device
readiness.

## Change

- WASD now uses SDL physical scancodes, with keycode fallback for compatibility.
- Native keyboard and mouse digital taps use a bounded 30-pad-read latch.
- Mouse motion accumulates into the native camera stick; mouse buttons map to
  Cross/Circle and hide the touch overlay after native input begins.
- Added canonical incremental patch:
  `patches/r1-native-digital-latch.patch`.

## Regression

`./out/jak-project/build/h1/goalc-test --gtest_filter='PlatformInput.*:KeyboardEventEdge.*'`
passed 9/9, including `NativeTapLatchSurvivesSlowGoalPoll`.

## Fresh one-Simulator replay

- Device: one booted iPad Pro 11-inch (M4), iOS 18.5; one Ottsel runtime.
- Signed build completed with `scripts/build-ios.sh` (`build_rc=0`).
- Route replayed: title-wait → Start → Cross → Down×4 → Cross.
- Fresh log reached `GAMEPLAY: enter village1` and resolved `MIS.DGO`.
- Fresh CUA screenshot:
  `/var/folders/b1/t1t38j255k53b4j97j63gfkh0000gp/T/com.openai.sky.CUAService/Simulator Screenshot 2026-08-22 at 4.14.13 PM.jpeg`
- Bounded video: `/tmp/ottsel-video/ipad-village1-partial-20260822-1615.mov`

## Disposition

The route/input dead-end is fixed for this replay, but the visible frame still
has missing geometry/large composition defects and no Jak; it is explicitly not
playable. R1 source/resource parity and native composition remain open. No TBP,
camera, shader, or Metal-policy remap was made.

## Cold native-event verification

- After terminating and relaunching the same signed app on the same single booted
  Simulator, a fresh `w` event logged `left=(127,0)` followed by key-up
  `left=(127,127)`.
- A fresh mouse drag logged `mouse-motion`, then native Cross down/up; the
  screenshot changed camera view, confirming the mouse path is live.
- Fault log remained 0 bytes and exactly one `com.ottsel.shell` runtime was
  present. Fresh visual evidence is still malformed and not playable:
  `/tmp/ottsel-video/cold-native-input-20260822-1647.png`
