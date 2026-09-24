# L3: the sprite atlas upload is sized to the rows it packs - 2026-09-22 (landed)

Gate: L3.  Change (one variable): the World2D product-group atlas (`src/shell/metal_gfx.mm`, the
48-sprite group 0) was uploaded as a full 512x512 (1 MB) region on every call, while a call packs only
1-6 tiles of 64x64 (the `textures=N` count in the log).  The atlas *buffer* keeps its maximum size so
the packing math is untouched, but `uv[1]` is now emitted in atlas pixels and normalised after the loop
by the number of rows actually used, and the texture and the upload cover only those rows.  Measured
before the change: ~130 uploads and ~13 MB per frame, 92-95% of those bytes padding or repeats
(evidence/A1/l3-sprite-upload-volume-2026-09-22.md).

Measured with the L0 harness in the same window (`vsync` 181..451), iPad strict lane:

| build | run 1 | run 2 |
|---|---|---|
| A2 baseline (before the base-upload skip) | 5.51 fps | - |
| C base-upload skip | 5.29 fps | - |
| D revert of the withdrawn dedup | 5.62 fps | - |
| E atlas sized to the used rows | **8.18 fps** | **6.92 fps** |

**+25-48% (mean ~7.5 fps against ~5.5) with the same GOAL objects.**  Mechanism evidence from the
pre-existing bounded log: the atlas upload size is now `512x64` (128 KB) for 124032 calls and `512x128`
for 8 calls in run 1, where every call used to be `512x512` (1 MB) - 8x fewer bytes per upload - and the
lane reached chain 1350 / 1170 in 115 s against 900 for the baseline.

Correctness: `World2D atlas rejected=0` in both runs; `SPRITE FRAME ... drawn=16/25` and `DIRECT FRAME
... drawn=44` unchanged against the baseline's 14-26 / 44; `ottsel-fault.log` 0 bytes in both; 346 ENTER
= 346 RETURNED; and the screenshot still shows the title screen with its rendered village background and
PRESS START, i.e. the re-normalised sprite UVs place the tiles correctly.

Not measured this turn: a fresh `sample` profile to show the `appendSpriteMeshNow` share dropping (the
bytes-per-call log and the fps are the direct evidence).  Remaining lever: the sprite path still issues
~900-1080 uploads/s of ~128 KB (~110-135 MB/s) and the other three atlas/standalone upload sites in
metal_gfx.mm still push their full textures; after those, the DMA walk.  Not claimed: no route/input,
audio or lifecycle acceptance.
