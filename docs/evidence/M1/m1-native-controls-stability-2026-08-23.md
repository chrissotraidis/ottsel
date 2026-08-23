# M1 native controls and stability — 2026-08-23

## Scope

Fresh ARM64 Mac runtime after the geometry-bound clamp, typed curve-knot fix, and
native mouse-direction fix.

## Verified

- `(mi)` rebuilt all 546 Jak 1 targets with `--isa arm64`.
- `gk` rebuilt; SHA256: `7f5769b47ca1aeb9c9c3915c07949aa2f3c944b1346a9751a1fb0aa018af33e4`.
- `goalc-test`: 750/750 tests passed after the movement-release and
  simultaneous-release-edge regressions.
- Fresh cold start reached coherent title, Village1, and Training frames without `OTTSEL CRASH`, `SIGABRT`, `presentRGBA`, or `_MTLCommandEncoder` markers.
- Pause/resume worked through the native Return route.
- W/A/S/D produced `(127,0)`, `(0,127)`, `(127,254)`, and `(254,127)` respectively, each returning to `(127,127)` after release.
- Space/E/F/R and Return/KP Enter/Escape now map to Cross/Circle/Square/Triangle/Start; WASD remains movement, mouse motion remains camera, and left/right/middle/X1/X2 map to Cross/Circle/Square/L1/R1. The left-hand cluster adds Q=L1, Shift=R1, C=L2, and X=R2.
- Rightward mouse drag visibly rotated the camera; no persistent left turn was observed.
- Minimize/restore emitted focus-clear/focus-resume events and rendering continued without relaunch.
- Runtime remained alive for over five minutes; `sample` showed frame-swap waits rather than an input/geometry spin loop.
- A clean follow-up run explicitly selected the physical `MacBook Air Speakers` route; output callbacks ran with nonzero mixer peaks through a bounded soak and no fault markers.
- Analog keyboard actions now release on the SDL key-up edge while button taps
  retain their bounded latch. `MovementKeyUpImmediatelyReturnsToNeutral` passes,
  and the rebuilt runtime left Jak standing after repeated A movement taps.
- The rebuilt process remains alive after approximately 2h49 of wall-clock
  process age; the audio telemetry reached window 10,300 with no crash, assert,
  linker, or encoder marker. This is soak evidence only; the current captured
  frame is a cutscene and is not counted as a gameplay frame.
- A later clean helper build reached Village1 and Training again, retained fresh
  Training frames, and remained alive for more than 14 minutes after keyboard,
  mouse-button, mouse-drag, concurrent tap, and focus-resume checks.
- The curve crash regression was reproduced before the helper split at
  `EE pc=0x3f57c88` with `si_addr=0x7056a720ac`; the helper build completed the
  same Village1-to-Training route with no fault marker.
- The focused simultaneous movement/action unit test passes; live automation
  emits tap down/up pairs and cannot prove a physically held simultaneous key.
- The release-edge regression confirms movement returns to neutral immediately
  while a short Cross tap remains latched for its bounded delivery window and
  then clears cleanly.

## Evidence

- `/tmp/ottsel-macos-20260823-082656/{title,village,training,post-mouse,post-resume}.jpeg`; fresh replay frames: `/tmp/ottsel-macos-fresh-post-start-20260823.jpeg`, `/tmp/ottsel-macos-fresh-new-game-20260823.jpeg`, `/tmp/ottsel-macos-fresh-save-transition-20260823.jpeg`, `/tmp/ottsel-macos-fresh-active-20260823.jpeg`
- `/tmp/ottsel-macos-20260823-082656/wrapper-current.log`
- `/tmp/ottsel-macos-20260823-082656/mac-acceptance-sample.txt`
- `/tmp/ottsel-mi-geometry-clamp.log`
- `/tmp/ottsel-wrapper-current.log`
- `/tmp/ottsel-macos-20260823-freeze-fix/final-macos-route.log`
- `/tmp/ottsel-macos-20260823-freeze-fix/gk.sha256`; `/tmp/ottsel-macos-20260823-freeze-fix/final-training-linear-knot-helper.png`
- `/tmp/ottsel-macos-20260823-freeze-fix/training-after-controls-focus.png`
- `/tmp/ottsel-macos-20260823-fix/post-release-a.jpeg`; fresh coherent Training frame after controls: `/tmp/ottsel-macos-fresh-training-controls-20260823.jpeg`
- Physical-speaker audio route: `/tmp/ottsel-macos-physical-audio-20260823-165719/{wrapper-current-post-soak.log,audio-transcript-post-soak.txt,fault-scan-post-soak.txt}`

## Boundary

This is strong Mac runtime evidence. Engineering acceptance is nearly closed.
The active route is now correct for this session, but human audible confirmation
is still open until the user confirms hearing the game through that route. Do
not begin iPad work until the user confirms audibility or the row is otherwise
resolved.
