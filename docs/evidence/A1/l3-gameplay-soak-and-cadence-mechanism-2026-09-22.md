# A five-minute gameplay soak: steady cadence, constant per-frame content, and what the ratio means - 2026-09-22

Gate: L3 (cadence) plus the acceptance item "stability".  Question: what does the lane actually hold during
*sustained* gameplay, and does the cadence correlate with what the scene is doing?

**Method.**  Touch-only route into the training level (NEW GAME, D-pad down twice to an empty save slot,
Cross - all through `ottsel-touch-*`), then fifteen cycles of "hold left-stick + Cross, release, hold
left-stick + D-pad up, release" for about five minutes.  107 `OTTSEL SUBMITSTAT` samples were tabulated as
per-interval frame rate (vsync delta over wall delta) against the per-frame deltas of the lane's own scene
counters.

```
title window (scene-level='village1'):   45.0 fps  ratio 1.0  cam/frame 9.0
training gameplay (34 intervals):        22.5-30.0 fps  ratio 3.0
                                         merc/frame 9.4 -> 3.0, eichar/frame ~1, cam/frame 6
```

Throughout the gameplay soak the per-frame content is **constant** (3 merc draws, ~1 eichar, 6 camera
entries per frame) while the displayed rate oscillates between 22.5 and 30 fps in the log's own 90-frame
quantisation.  So the slow windows are not "the scene got heavier": the frame is saturated on a workload
that does not change.

**What the ratio actually is, and the loop it closes.**  It is not a knob: `drawable.gc:978-997` computes it
inside the game - `time-ratio = timer-count(0x10000800) / *ticks-per-frame*` (rounded up), clamped to 1.0 when
the frame was under 1.3 ticks - and hands it to `set-time-ratios *display*`; the port drives that timer from
the host clock, so the ratio is the game's *response* to a slow frame, and the game's clock stays wall-correct
(measured 287-308 units/s against the 300/s nominal).

That closes a feedback loop.  With `R` the cost of one displayed frame's render work, `S` the cost of one
game frame's simulation and `k` the ratio: `T = R + k*S`, and wall-correct game time needs `k = 60*T`, so
`T = R / (1 - 60*S)`.  The frame time is therefore set by `R` and `S` alone, with the simulation cost
*amplified* - at `S ~= 10 ms` the factor `1/(1 - 60*S)` is about 2.5.  Ratio 1.0 in the title window (45 fps),
3.0 in gameplay (22.5-30 fps) and 4.0 in the heavy transient window measured earlier (13.5 fps) are three
points of the same loop, not three different bugs, and the constant per-frame content above is what pins
gameplay to its equilibrium.

The lever is therefore any cut to `R` or `S`, and it is amplified.  The earlier profile puts the largest
identified block in the shell's texture upload/decode path (`decode_texture_pixels_raw` 180 of 1145
game-thread samples, with the memo already working at a 25% miss rate) and the per-chain `access()` probes
at 92 - both inside the saturated game thread.  This also explains why the earlier atlas-upload sizing bought
+25-48% rather than the ~7% of the samples it removed.

**Stability over the soak.**  RSS 967 MB at the start and 910 MB at the end (no growth), `ottsel-fault.log`
0 bytes, 346 ENTER = 346 RETURNED maintained, and every input came from the touch surface, so the touch
handler ran continuously for five minutes without a leak or a fault.

Not claimed: no optimisation is landed here, and this does not measure a physical device, where the same
`W` would be a different (probably smaller) share of the frame budget.
