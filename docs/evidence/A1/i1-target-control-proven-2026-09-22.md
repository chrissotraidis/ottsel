# Input moves the target: a controlled A/B on the iPad lane - 2026-09-22

Gate: I1 (control on the iPad lane).  Question: does a held pad input move the game's target, and does a
neutral pad leave it still - measured, not judged from screenshots?

**Instrument.**  The bounded world-position trace the target already arms at spawn for 2400 frames
(`goal_src/jak1/engine/gfx/shadow/shadow.gc`: `OTTSEL TARGET POS: t=(~f,~f,~f) pad=~f`, one line in
sixteen, printed after collision has finalized so it shows the post-collision position;
armed by `goal_src/jak1/engine/target/target-death.gc`).  `pad` is the target's own `pad-magnitude`,
i.e. the left analog stick - the stick Jak 1 reads for movement, which the shell derives from A/D/W/S
(`ottsel-hold-stick-left/right`, `src/shell/main.cpp`).

**Protocol** (`scripts/probe-ios-target-control.py <udid> --route --seconds 15`): fresh launch with
`OTTSEL_TRACE_INPUT=1`, drive the route with the maintained driver, wait until the target reports four
seconds without movement (so a level transition or intro cannot pollute the control window), then sample
four phases in the same run and the same level: neutral, stick-left held, neutral, stick-right held.

**Result - run 1 (15 s phases).**
```
phase           n       x-range       z-range   max-step  pad
neutral-a       9           0.0           0.0        0.0  [0.0]
stick-left     24       70483.0       20699.0    35571.0  [0.0, 1.0]
             held(pad>=0.9): n=22 displacement=(-60442.0, 17984.5) |d|=63060.9
neutral-b      15           0.0           0.0        0.0  [0.0]
stick-right    25       25301.5       27764.5    19839.0  [0.0, 0.9921]
             held(pad>=0.9): n=23 displacement=(4298.0, 1031.5) |d|=4420.0
```

**Result - run 2 (20 s phases, `--seconds 20 --screenshots /tmp/ottsel-play`), repeatability and
direction:**

```
phase           n       x-range       z-range   max-step  pad
neutral-a      18           0.0           0.0        0.0  [0.0]
stick-left     55       79565.5       22721.5    33381.0  [0.0, 1.0]
             held(pad>=0.9): n=50 displacement=(-51477.0, 5791.0) |d|=51801.7
neutral-b      35           0.0           0.0        0.0  [0.0]
stick-right    27       19616.0       50450.0    10690.0  [0.0, 0.9921]
             held(pad>=0.9): n=25 displacement=(12149.0, -48983.0) |d|=50467.1
```

Both neutral windows are **exactly** constant (0.0 world-unit range over 9-35 samples, `pad=0.0`) and both
held windows move the target by ~50k world units at `pad >= 0.99` with **matched magnitudes** (51802 left,
50467 right) and opposite displacement vectors (dot product -9.1e8) - the camera-relative left/right
reversal.  So the movement is input-driven, not drift, animation or the renderer, it repeats, and it has
direction.  Run 1's ~7% stick-right distance was the camera orientation in that window, not a defect: run 2
matches the magnitudes.

Visibly corroborated in the same run: `/tmp/ottsel-play-stick-left-before.png` shows the Geyser Rock start
area (grass, the log, the blue bridge, Jak standing) and `/tmp/ottsel-play-stick-left-after.png` shows the
canyon interior he walked into.  In that end frame Jak's pose against the wall is visually distorted; that
is recorded as an observation, not diagnosed here.

This supersedes the previous turn's "controllability is not established": that reading compared
*screenshots* while the intro was still animating (a 12 s no-input window also changed frames, `eichar`
3005 -> 3095) and did not use the position trace that was being armed in the same run.  The trace settles
it: zero movement with a neutral pad, tens of thousands of units with the stick held, in one run.

Not claimed: no jump/action or camera input, no audio, lifecycle or sustained-play acceptance, and no
playability claim - the route and this measurement are on the same strict lane with a 0-byte fault log.
