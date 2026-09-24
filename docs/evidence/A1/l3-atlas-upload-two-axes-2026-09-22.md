# L3: the sprite atlases are sized on both axes - 2026-09-22 (landed, neutral)

Gate: L3.  Change (one variable): after the row sizing (World2D atlas upload 1 MB -> 128 KB, +25-48% fps)
the two atlas sites are sized on the width axis as well.  The packing fills columns 0..n of a row-major
layout, so the columns used bound the used area; `uv[0]` is now deferred and normalised in the same
place as `uv[1]`.  The HUD site received both axes at once.

Measured with the L0 harness (`vsync` 181..451), iPad strict lane:

| build | run 1 | run 2 |
|---|---|---|
| A2 baseline | 5.51 fps | - |
| E World2D rows sized | 8.18 fps | 6.92 fps |
| F + HUD rows sized | 7.71 fps | 6.75 fps |
| G World2D + HUD, rows and columns | 7.71 fps | 6.75 fps |

Upload sizes went from a flat `512x64` to `64x64 / 128x64 / 192x64 / 256x64 / 320x64` (1-5 tiles wide
times one row), i.e. another ~2-8x fewer bytes per call, and the cadence did not move beyond the
run-to-run spread (the same build measured 8.18 and 6.92).  That is the useful part of the result: the
texture upload is no longer the frame bottleneck, so what remains of the frame time is the CPU side -
the profile's 1528/1630 samples inside `send_gfx_dma_chain`.

Correctness in both runs: 346 ENTER = 346 RETURNED, `World2D atlas rejected=0`, `SPRITE FRAME ...
drawn=32/16`, `DIRECT FRAME ... drawn=44`, `ottsel-fault.log` 0 bytes, and the screenshot still shows
the title screen with its village background and PRESS START, so the two-axis re-normalisation places
the tiles correctly.  (Run 1's final `DIRECT FRAME` sample line reads drawn=0 while run 2's reads 44 and
both screenshots render, so that line is a per-frame sample rather than a regression.)

Unexercised: the HUD native path still logs nothing in this window (0 `native HUD` lines), so its two-axis
sizing is landed but unverified until a HUD-bearing scene draws it - the L5 route or a level with the HUD
up.  Not claimed: no additional fps from the width sizing; no route/input, audio or lifecycle acceptance.
