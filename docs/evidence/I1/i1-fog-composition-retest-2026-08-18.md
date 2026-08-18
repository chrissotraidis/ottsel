# I1 — iPad fog transport and composition retest (2026-08-18)

## Scope

One fresh signed `OttselShell.app` run on the iPad Pro 11-inch (M4) Simulator
(`08636791-2675-4675-8335-EF72EF954DCF`). No macOS `gk` process was active.
The app was terminated and the Simulator shut down immediately after capture.

## Verified runtime boundaries

- The game advanced through title and displayed `village1`.
- The mobile TIE renderer built its one-time visible selection: three trees,
  119 batches, 511,138 vertices, 252,888 triangles, and 67 textures.
- The GIF/GS stream delivered live fog colors to the mobile renderer:
  `(41,128,200)`, `(159,150,200)`, `(128,179,242)`, and `(128,179,241)`.
- The Metal TIE shader consumes those colors with the desktop fog-distance
  inputs from the PC-port camera packet.

## Opaque-TFRAG follow-up

A second fresh signed run retained the normal-TIE submission and added the
desktop-equivalent opaque TFRAG slice: LOD 0, `NORMAL` only, rendered before
TIE with its own mesh and time-of-day color table. The live cull selected one
TFRAG tree with 77 material batches, 75,960 vertices, 53,304 triangles, and a
1,024-entry palette. The captured image now contains the Village1 hill, tower,
and foreground terrain that were absent before this slice.

## Captured result

The Simulator frame remains overwhelmingly black above the terrain. Opaque
TFRAG has improved the landscape, but Direct/Sprite sky and effects,
transparent/dirt/ice TFRAG, and remaining TIE material behavior are absent.

## Gate result

**Passed narrowly:** real FOGCOL delivery and one visibility-culled,
opaque-TFRAG Metal pass using the desktop FR3/camera/material contract.

**Still open:** the iPad scene-composition gate. The next product slice is the
Direct/Sprite sky/effects path, after which translucent/dirt/ice TFRAG needs
its own blend/order rules and a same-phase macOS/iPad visual comparison. Do
not use the legacy VU/GIF diagnostic raster as the product solution.
