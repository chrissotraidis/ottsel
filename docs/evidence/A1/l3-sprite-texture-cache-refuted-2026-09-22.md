# L3: the game thread's frame cost, and why a sprite texture cache is worse - 2026-09-22

Gate: L3 (iPad frame-time parity).  Question: which single change removes the per-frame synchronous
upload/XPC stall in the present path?

Profile first (`sample <pid> 3` on the running iPad lane, 1630 samples).  The game thread
(`ottosel_ios_run_boot` -> `ottosel_module_drawable_s0_code` -> `arg_call_arm64`) spends 1528 of its
1630 samples in `send_gfx_dma_chain`: 715 under `gfx_send_chain`, and **410 of those inside
`-[MTLSimTexture replaceRegion:...]` - the synchronous XPC sprite-texture upload** reached through
`render_mobile_sprite_bucket` -> `render_mobile_sprite_group0` -> `ottosel_metal_append_sprite_mesh_n` ->
`-[OttselMetalRenderer appendSpriteMeshNow:...]` (319 of them under
`xpc_connection_send_message_with_reply_sync`).  The rest of the game thread is the DMA walk, bucket
dispatch and sprite mesh building.  The main thread (1630 samples) is 864 in
`SDL_SYS_DelayNS`/`nanosleep` (idle, waiting for the next chain), 420 in `ottosel_metal_present` ->
`presentRGBA:` -> `replaceRegion` (190 of them in the same synchronous XPC), ~346 in game work.  So both
the sprite uploads (game thread, ~25%) and the frame upload (main thread, ~26%) are the same
`MTLSimTexture replaceRegion` XPC; a 1 MB sprite atlas or a 16 MB frame at ~500 MB/s XPC explains the
~31 ms per upload the samples imply.

Experiment B (one variable): a content-addressed sprite texture cache - reuse an uploaded `MTLTexture`
when the incoming pixels are byte-identical (FNV-1a hash plus `memcmp`), so static atlases stop being
re-uploaded.  Measured with the L0 harness in a fixed window (`vsync` 181..451, two runs each):

| build | run 1 | run 2 |
|---|---|---|
| A baseline (fresh texture + `replaceRegion` per call) | 5.40 fps | 5.74 fps |
| B content cache | 2.84 fps | 2.90 fps |
| A2 reverted | 5.51 fps | 5.74 fps |

**Refuted: the cache is ~2x slower.**  The likely mechanism is that reusing a texture the in-flight
frame still references makes the simulator serialize - the CPU-side `replaceRegion` into a texture the
GPU is still reading costs the hazard wait that a fresh texture per call never pays - and every call
additionally hashes and, on a miss, copies the full 1 MB region.  The revert restores the baseline
exactly (A2 = A within noise), so the measurement pipeline detects a real change.

Reframing carried forward: `MTLSimTexture replaceRegion` is the *simulator's* upload path - the driver
copies the bytes into the GPU process over XPC.  A real device uploads a shared/private texture with a
memory copy, so the simulator's 4.7-10 fps understates device cadence, and a change that only avoids
simulator XPC cost may not move a device.  The product-relevant levers, in order: (1) stop uploading a
full RGBA frame on every present when the GPU path already drew the scene (16 MB per present is the
largest single XPC, and the doc's own first candidate), (2) the DMA walk / sprite mesh building, which is
the largest single block of the game thread (~50% plus ~20%), (3) the per-chain diagnostics (77430 log
lines in one 115 s run, ~84 per frame) and the per-chain `access()` trigger probes - the profile puts
stdio at only ~2% and `access` at ~2.3%, so these are cleanups rather than levers.

Not claimed: no fps improvement landed.  The next single change is (1), measured the same way (L0 window
181..451, two runs, plus a `sample`), with the sprite path left exactly as it is (fresh texture per call).
