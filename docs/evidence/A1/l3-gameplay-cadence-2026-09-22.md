# Display cadence in the training level is state-dependent, and the game clock is wall-correct - 2026-09-22

Gate: L3/L0 (frame-time parity, measured on the product lane).  Question: what cadence does the iPad lane
hold *in gameplay*, and what distinguishes a fast window from a slow one?

**Method.**  Wall-clock frame rate from the lane's own counters: two reads of the last `OTTSEL SUBMITSTAT`
line in `ottsel-runtime.log`, N seconds apart, with the app running the training level (route-driven, no
input held) and nothing else on the machine.  `game-base` is the game's own display clock (300 units/s
nominal at `time-ratio` 1.000) and is how the lane states whether *game time* is correct.

**Three windows, same level, same launch protocol** (window A on the previous instance, B/C on the current
one):

| window | vsync delta | display | game-base rate | time-ratio |
|---|---|---|---|---|
| A (47 s) | 2430 frames | **51.70 fps** | 287 units/s | 1.000 |
| B (41 s) | 630 frames | **15.37 fps** | - | 4.000 |
| C (40 s) | 540 frames | **13.50 fps** | 308 units/s | 4.000 |

So the display rate is **state-dependent (13.5-51.7 fps)** while the game clock stays wall-correct in both
the fast (287/s) and the slow (308/s) window against the 300/s nominal: the lane is choppy, not slow.  The
round's original "4.7-10 fps" title reading and a 51.7 fps gameplay window are the same phenomenon at
different scene states.  **This corrects the first version of this document**, which reported the 51.7 fps
window as the gameplay rate; the 13.5-15.4 fps windows are just as much gameplay
(`scene-level='training'`, `tie-ready=true tfrag-ready=true`, 0 camera rejects, 0-byte fault log).

**What separates them, from the lane's own per-interval counters** (67 SUBMITSTAT samples of the current
instance): every slow interval reports `raster-draws=0` at 11-15 fps, while the fast intervals report
`raster-draws` of 260-1157 at 30-45 fps - with `tie-ready`/`tfrag-ready` true in both, so the GOAL-side
readiness flags do not distinguish them.  Hypothesis (not proven): when the native renderer draws nothing,
the present path still runs the CPU base upload (16 MB RGBA through the synchronous `MTLSimTexture
replaceRegion` XPC, the documented ~31 ms stall), whereas the native draw path skips it.

**Why the existing gate can still admit that upload.**  `cpu_base_wanted` (`src/shell/metal_shell.mm`) is
computed from a *shell-side* per-frame test - a `SceneFrameReference` in `_activeSceneFrame` that has an
uploaded mesh with vertices/indices/colors and non-zero `index_count` - through
`ottosel_mobile_cpu_frame_should_draw(tfrag_ready, tie_ready, probe)`
(`src/shell/mobile_scene_policy.h`).  SUBMITSTAT's `tie-ready`/`tfrag-ready` are the different, GOAL-side
`g_mobile_*_visibility_ready` flags, so a frame can be GOAL-ready and still take the CPU upload path.  The
next single instrument is therefore one line: report `cpu_base_wanted` beside `raster-draws`.

**Where the frame time goes in the fast state** (`sample` 3 s, thread-precise): the main thread is 1216 of
1866 samples idle in `SDL_SYS_DelayNS`/`nanosleep` (the loop's 60 Hz cap, `src/shell/main.cpp`), so it is
not the pacer; the game thread is 1146 samples in `send_gfx_dma_chain`, of which 302 are the texture
upload/decode path (`gfx_send_chain` -> `handle_mobile_pc_port_texture_upload` ->
`gfx_texture_upload_now` -> `download_texture_cached` -> `decode_texture_pixels_raw` 180), 92 are the
`access()` trigger probes, and the rest is the DMA walk resolved into signed-module slots
(pskernel/quaternion/matrix/vector-h/euler/geometry).  The decode memo is working and the residual decode
cost is mostly inherent: `OTTSELVRAM hits=83057 misses=27535 bytes=3407424 epoch=1 places=54949
changed=49178 evicted=27320 invalidations=49175` - a 25% miss rate against a 3.4 MB resident set (256 MB
budget, so not budget evictions) with `changed` covering 89% of mirror writes, i.e. the game really does
re-upload different bytes and the range invalidation is correct rather than redundant.

Not claimed: the upload-path mechanism is a hypothesis and no fix is landed here.  The slow window does
render gameplay (`/tmp/ottsel-slow-state.png`: Jak and Daxter on the canyon ledge), not a blank frame.
