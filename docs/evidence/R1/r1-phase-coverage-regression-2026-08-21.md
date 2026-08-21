# R1 phase-coverage regression — 2026-08-21

## Gate

R1 same-transition Sprite3 phase sequence and source-item ownership.

## Before failure

The existing `Sprite3Native.*` suite had no contract for the post-transition
coverage proven on macOS. A test-first build failed because
`has_jak1_post_transition_coverage` did not exist. The live mobile aggregate
remains below the observed macOS bar at 8 world groups, 0 HUD groups, and 2
3D groups; the accepted macOS dispatch records 51 world blocks, 3 HUD blocks,
and 2 3D groups.

## Change

Added the pure diagnostic predicate
`has_jak1_post_transition_coverage(world_groups, hud_groups, three_d_groups)`
to `common/dma/ottsel_sprite_phase.h`, plus two ROM-free assertions in
`test/test_sprite3_native.cpp`. The helper only expresses the captured phase
coverage contract; it is not called by the renderer and does not change bucket
ownership, texture selection, Metal state, or game content.

## Focused proof

```text
ninja -C build/h1 goalc-test
./build/h1/goalc-test --gtest_filter='Sprite3Native.*'
15 tests passed
```

The before-failing compile error was the expected missing predicate. After the
smallest helper was added, all 15 focused tests passed.

## Live boundary

No new Simulator replay was used for this pure contract. The authoritative
live observations remain the fresh macOS transition log
`log/jak1.2026-08-21T02-38-46.log` and the prior shared-vsync mobile aggregate.
The Simulator is known to be blank and non-audible, so this regression makes
no visual or playability claim.

## Verdict

OPEN. The regression now makes the producer-phase gap falsifiable, but it does
not identify whether the missing post-transition records arise in the mobile
bucket interval, GOAL producer state, or a chain boundary. No product fix is
justified yet.

## Next gate

Capture or extract the mobile Sprite3 chain boundary that should follow the
early `48 + 16` phase, then compare it with desktop's first `0x24f2` group
before changing the producer or native consumer.
