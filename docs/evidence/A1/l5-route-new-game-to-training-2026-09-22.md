# The iPad route reaches New Game and the training level - 2026-09-22

Gate: L5 (route and input) on the iPad lane.  Question: does the frontend accept the real route -
title -> START -> New Game -> save screen -> Continue Without Saving -> level gameplay - and can the
maintained driver prove it end to end?

**Method.**  One held press per step through the shell's hold triggers (a one-frame tap is invisible at
this lane's 5-8 fps), reading the frontend's own markers out of `ottsel-runtime.log`.  The probe tool is
`scripts/probe-ios-title-menu.py <udid> --launch --steps start,cross,down,down,down,down,cross --prefix
/tmp/ottsel-route1`; the maintained driver `scripts/replay-ios-normal-route.py <udid>` was then run as the
repo-native acceptance.

**Marker vocabulary measured on this build (with `OTTSEL_TRACE_INPUT=1`):**

```
OTTSEL INPUT: pad0 sample buttons=0x8      (START hold delivered to the pad)
OTTSEL TITLE: start edge in title-wait abs=8 rel=8 progress=#f busy=#f
OTTSEL TITLE: activate-progress returned progress=268159 master=progress   (PC menu becomes the frontend)
OTTSEL PC PROGRESS: edge screen=27 index=0 transition=#f abs=16384 rel=16384   (Cross)
OTTSEL PC PROGRESS: accept screen=27 index=0 selected=#f                      (NEW GAME)
OTTSEL PC PROGRESS: edge screen=18 index=0..3 transition=#f abs=64 rel=64     (Down x4)
OTTSEL PC PROGRESS: edge screen=18 index=4 + accept screen=18 index=4         (CONTINUE WITHOUT SAVING)
```

**Result.**  After the last accept the lane logs `GAMEPLAY: enter training` and reports
`scene-level='training'` with tie-ready/tfrag-ready true, cam-accepted 7329 with 0 rejects,
merc-submits 19389, eichar 485, vsync 1081, game-base 314945 and a 0-byte `ottsel-fault.log`.
`/tmp/ottsel-route1-village1.png` (probe run) and `/tmp/ottsel-driver-run-training.png` (driver run) show
the training level rendered - animated actor, bridge, crates, scattered fruit and the rock/grass terrain -
not a title screen.

**The maintained driver now passes** (`Continue Without Saving accepted`, exit 0): `start` ->
`OTTSEL TITLE: start edge in title-wait`, `cross` -> `accept screen=27 index=0`, `down` x4 ->
`edge screen=18 index=0..3`, `cross` -> `accept screen=18 index=4`.  Its August edge sequence was
therefore **correct, not stale** - it could not pass for a mechanical reason: with hold semantics its
`press()` waited for a neutral pad sample *before* releasing the trigger, and a sustained hold can never
produce one.  `press()` now releases on the edge and requires the neutral sample afterwards, and its
first expectation is the title's own edge marker (`screen=27` is only printed once the menu answers a
later input).

**Two readings from the previous turn are corrected.**  (1) The menu is the PC progress ring with
`NEW GAME` selected at index 0, and Cross accepts it; "Cross at the wheel returns to the title" came from
a Cross delivered while the title was still up (that session's START hold never reached the pad - the
title logged none of its own `start edge` markers).  (2) `/tmp/ottsel-routeA-final.png` and
`/tmp/ottsel-routeB-01-menu.png` are the title screen with `PRESS START`, not a menu.

**Controllability** is measured separately and positively in
`docs/evidence/A1/i1-target-control-proven-2026-09-22.md`: with the world-position trace the neutral pad
leaves the target exactly still (0.0 world-unit range over 15 samples) and a held stick moves it tens of
thousands of units in the same run.  This document's earlier screenshot-diff control was inconclusive only
because the intro was still animating; the trace settles it.

Not claimed: no jump/action or camera input, audio, lifecycle or playability acceptance.
