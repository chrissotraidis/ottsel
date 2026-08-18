# I1 — iPad textured normal-TIE milestone (2026-08-18)

## Scope

One iPad Pro 11-inch (M4) Simulator run using the signed local
`OttselShell.app`; no macOS game runtime was active. The Simulator was
terminated and shut down after the Computer Use visual check.

## Source-to-renderer contract

The mobile renderer consumes the same parsed FR3 data used by macOS:

- `TieTree::static_draws` supplies normal-TIE material batches and their
  `tree_tex_id` level-texture references.
- `PreloadedVertex::color_index` indexes the tree's `PackedTimeOfDay` data.
- The PC-port packet supplies the eight-palette interpolation weights.

For the live Village1 tree, the renderer expanded 30 normal draws to 253,196
triangles, uploaded 18 referenced FR3 textures, and rebuilt a 5,376-entry
RGBA palette. The log reported bounded palette updates with alpha capped at
128, matching the desktop shader's later two-times color multiplier.

## Live result

Computer Use showed textured, color-varied Village1 geometry on the iPad game
surface. This replaces the preceding flat-green transform proof. The final
short retest preserved the image and emitted only palette updates 1, 2, and 3,
confirming the trace is not a per-frame log flood.

## Gate status

**Passed:** first normal-TIE texture lookup, per-draw material submission,
time-of-day palette construction, bounded runtime telemetry, and a visible
textured iPad frame.

**Still open:** selecting/culling the correct active tree/draw groups, depth,
fog, alpha/blend/decal modes, animated textures, wind/envmap passes, all other
TIE categories, TFRAG/Merc/direct/sprites, title parity, gameplay input flow,
iPhone-size validation, device acceptance, and output-only audio.
