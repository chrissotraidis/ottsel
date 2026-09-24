# L3: the per-present CPU base upload is skipped when the live scene replaces it - 2026-09-22

Gate: L3.  Change (one variable): `-[OttselMetalRenderer presentRGBA:...]` pushed the whole
drawable-sized RGBA surface through `MTLSimTexture replaceRegion` on every present, even when the live
TFRAG/TIE scene was drawn by Metal.  The render pass already clears that attachment to
(0.03, 0.04, 0.07) - the same neutral colour the shell fills into that buffer - and the base *draw* was
already skipped by `ottsel_mobile_cpu_frame_should_draw` once both meshes are ready, so the upload was
the only remaining cost.  `cpu_base_wanted` is now computed once per frame, before the upload, from that
same policy, and gates the texture creation, the upload and the base draw, so the two cannot disagree.
Context: `ottsel_metal_gfx_game_frame` returns 0 unconditionally (metal_gfx.mm:9395), so the shell
always presented that flat CPU buffer; `ottsel_metal_gfx_has_live_scene` is true whenever the TFRAG or
TIE visibility is ready.

Measured with the L0 harness in the same window (`vsync` 181..451), two runs each:

| build | run 1 | run 2 |
|---|---|---|
| A2 baseline (upload every present) | 5.51 fps | 5.74 fps |
| C base skipped | 5.29 fps | 5.87 fps |

The cadence is unchanged - as the profile predicted, the main thread was 53% idle - but the stall is
gone: `sample` moves the main thread's `presentRGBA:` frame from **268 to 54 samples** and the process
total from 1630 to 1563, with `xpc_connection_send_message_with_reply_sync` 232 -> 199 (what remains is
the game thread's sprite uploads).  Correctness evidence: both runs reach chain 900, 346 ENTER = 346
RETURNED, `ottsel-fault.log` 0 bytes, `DIRECT FRAME ... drawn=44` and `SPRITE FRAME ... drawn=23/26`
unchanged, and the screenshot still shows the title screen with its rendered village background and
PRESS START.

Remaining frame-rate lever (profiled, unchanged): the game thread spends 1528 of 1630 samples inside
`send_gfx_dma_chain` - `render_mobile_sprite_group0` 552, `appendSpriteMeshNow` 410 (the sprite texture
uploads; cross-frame reuse was refuted, but *intra-frame* dedup of identical uploads is unexplored and
cannot hit that hazard because uploads are drained before the frame is encoded), plus the DMA walk.
Not claimed: no fps improvement, and no route/input, audio or lifecycle acceptance.
