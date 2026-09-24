# L5 route attempt and post-atlas re-profile - 2026-09-22

Gate: L5 (route/input) with an L3 re-profile.  Question: with the atlas uploads sized, what limits the
frame, and does the documented normal route drive?

**Re-profile** (`sample <pid> 3`, iPad strict lane, root 1594 samples).  The main thread is 65% idle
(`__semwait_signal` 1044), so the game thread limits: 1365 samples in `ottosel_ios_run_boot` ->
`ottosel_module_drawable_s0_code` -> `arg_call_arm64` -> `send_gfx_dma_chain`, of which 490 are
`gfx_send_chain`, 457 `render_mobile_sprite_bucket`, 287 `render_mobile_sprite_group0` ->
`ottosel_metal_append_sprite_mesh_n`.  The largest single leaf under the sprite path is now
**`-[MTLSimDevice newTextureWithDescriptor:]` (111 samples, ~7% of the game thread)** - the per-call
*texture allocation*, not the upload that was just shrunk - and the remaining ~875 samples are the
non-sprite DMA/bucket walk (55%), with the rest diffuse.  So the next sprite change is to recycle sprite
textures on command-buffer completion, mirroring the vertex-buffer pool that already exists
(`borrowVertexBufferBytes:` / `recycleVertexBuffers:after:` in metal_shell.mm).

**Route attempt 1 (the maintained driver).**  `scripts/replay-ios-normal-route.py` cannot pass on this
build: it waits for `OTTSEL INPUT: pad0 sample buttons=0x0`, and that marker no longer exists anywhere in
the shell - the file triggers now log `ottsel BOT22: latched <button> tap (file trigger)` on stderr
(`src/shell/main.cpp`).  The driver aborted at its first press with that mismatch, not because input was
lost.

**Route attempt 2 (by hand, `--console-pty`).**  The shell latched **7 of 7** taps (START, CROSS, four
DOWNs, CROSS), but the frontend never left `screen=27` - the log shows only the title's own
`OTTSEL PROGRESS: request/entering/normal screen=27` lines and no transition.  `OTTSEL INPUT: native
keyboard/mouse active; touch overlay hidden` appears once, and the pad samples report
`has-display=false` - which is *normal on this lane* in every build I hold, including the pre-change
baseline, so it is not a regression from the atlas work.  The blocker is therefore between the latched
key and the game's pad/frontend, and it is the next thing to measure.

**Route attempt 3 (plain `simctl launch`, no console).**  Inconclusive by method: the app was still
booting 3m47s in (log tail: linking `gsound`) with the trigger files unconsumed, so the console-pty launch
is what keeps the app active enough to reach the title; the route must be driven that way.

**Side result:** the HUD native path now runs (24 `native HUD` lines) and shows the two-axis atlas sizing
in use - `atlas=384x64` and `512x128` - so the previously unexercised HUD atlas change from the last turn
is exercised on the title's HUD sprites.  Every run this turn kept `ottsel-fault.log` at 0 bytes.

Next: (1) make the game's pad consume the injected taps (the L5 blocker above), (2) refresh the route
driver's stale acceptance marker so it can run, (3) recycle sprite textures on completion for the ~7%
allocation cost, then (4) the non-sprite walk.  Not claimed: no playability, audio or lifecycle acceptance.
