# R1 shared-vsync Sprite3 aggregate — 2026-08-21

## Gate

Frame-aligned mobile 66→68 product walk versus the macOS Sprite3 dispatch.

## Identity

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed Simulator executable SHA-256:
  `efc9562e8e973db8bd34811b1605d4e4eb38a848d5d9b12bc43dd3ea4739614e`.
- Focused `Sprite3Native.*`: 12/12 passed; strict codesign passed.
- Environment: one iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`.

## Before failure

Independent bucket snapshots differed between fresh routes: one reported
9 groups / 384 sprites and another 10 groups / 448 sprites. A shared-vsync
join was required before treating that as a producer or parser defect.

## Change

Added the trigger-gated `ottsel-trace-mobile-sprite-frame-aggregate`. It uses
the retained product interval (`bucket66.addr` through `bucket68.addr`), sums
all product walks sharing the armed `g_ottsel_ios_vsync_count`, and closes at
the next vsync. It is diagnostic-only and does not alter rendering, Direct
decoding, or bucket ownership.

## Live proof

The fresh validated-pack route entered Village1 twice. The aggregate emitted:

```text
OTTSEL SPRITE FRAME AGG: accepted vsync=21314 chain=21313
OTTSEL SPRITE FRAME AGG: complete vsync=21314 chains=1 groups=9 sprites=384 world=320 hud=0 3d=64 other=0
```

The fault log was 0 bytes. The macOS same-route oracle remains one complete
Sprite3 dispatch with 51 world blocks / 2,432 world sprites and 3 HUD blocks /
128 sprites.

## Interpretation

The earlier 10-group/448 result was a different phase window, not evidence
that the retained parser is nondeterministic. The mobile frame-aligned result
is stable at 9 groups / 384 sprites for this accepted phase, but it remains
far short of the macOS dispatch and still uses mobile-owned resources beginning
at `0x2c8d` rather than the macOS world phase beginning at `0x24f2`.

## Verdict and next slice

OPEN. Shared-vsync aggregation is now proven. The next falsifiable slice is to
capture the same aggregate over the complete accepted macOS phase boundary and
map missing mobile groups/resources in order, before widening Sprite3 or
changing camera/shader policy. The Simulator remained blank and non-audible;
this is not playability proof.

## Ordered phase contract regression

The ROM-safe `Sprite3Native.RequiresOrderedJak1PostTransitionPhaseCoverage`
regression now encodes the next falsifiable boundary: two leading `ThreeD`
records, followed by ordered `World2D` and `Hud2D` coverage. The mobile-shaped
aggregate (3D plus world, no HUD) fails the contract; the accepted macOS-shaped
aggregate passes it. The helper is pure classification logic and does not alter
the renderer or executable-memory policy. R1 remains OPEN.
