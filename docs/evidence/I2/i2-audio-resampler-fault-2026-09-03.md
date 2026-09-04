# I2 audio startup fault — 2026-09-03

Status: OPEN. This run is diagnostic evidence, not audio or playability acceptance.

Question: is the new iOS PLAYER RPC path reaching a valid native audio route, or
does audio initialization fail before any PCM can be produced?

Evidence:

- Disk gate before build: 84 GiB available; outer and nested temporary-pack counts 0.
- Focused platform suite: 5/5 passed, including the empty-TIE regression and
  PLAYER-target classification.
- Signed app: `out/jak-project/out/ios/app/OttselShell.app` assembled successfully.
- Fresh cold run on iPad Pro 11-inch M4 Simulator
  `08636791-2675-4675-8335-EF72EF954DCF`, one runtime, 25 seconds.
- Runtime address trace: EE `[0x7000000000,0x7008000000)`, SPU
  `[0x1007b7628,0x10088a3e8)`, `overlap=false`.
- PLAYER RPC loaded COMMON (461 sounds) and VILLAGE1 (43 sounds).
- Route reached `GAMEPLAY: enter title`. The new guard logged that `title` has
  no TIE geometry, then the TFRAG snapshot completed; this specifically clears
  the earlier empty-TIE indexing suspicion.
- The run still gated with signal 11 at `pc=0x1046069b0`, `fault addr=0x140`.
  The fault words decode to `ldp ..., [x20, #0x140]`, with `x20=0`, and the
  retained signal diagnostics identify the existing `enter-state` probe/path,
  not `build_visible_mobile_tie_mesh`.
- The later LLDB attach captured the held fault on thread `#11`, with the
  renderer call chain `capture_mobile_camera -> gfx_send_chain ->
  send_gfx_dma_chain -> arg_call_arm64`; the main thread was in
  `presentRGBA`, while SDL audio threads were alive.
- The earlier SDL symbolization was cross-thread/misleading. Its captured
  `x9` was not the expected resampler destination and `x30` pointed inside
  SDL, so it is not proof that SDL's filter algorithm is the root cause.
- No `pcm-peak>0`, audible route, Village1, or controllable Jak evidence.

Conclusion: the empty-TIE renderer hazard is fixed and regression-covered, but
the authoritative blocker is now the gated `enter-state`/GOAL fault reached
after the renderer emits its title snapshots. Audio successfully opens a
playback route and its threads remain alive. The EE/SPU overlap hypothesis is
disproven, and the SDL-resampler theory is withdrawn. Keep camera, TBP/lookup,
strip restart, and unrelated renderer changes frozen while isolating the
invalid state/process pointer.

Next falsifiable experiment: identify the caller that supplies the null process
or state object to `enter-state`, add a before-failing focused regression for
that pointer contract, and rerun one signed cold launch. Do not claim I2
acceptance.
