# A1.16: the .ret guard keeps either lane's code band - 2026-09-22

Gate: L0/L1.  Question: can the shared objects' `.ret` fail-safe be correct on both lanes at once?

Change (one variable): `IR_AsmRet::do_codegen_arm64` no longer hardcodes the iPad signed arena as the
only code band.  It computes two keeps and adds them, so the slot is kept when it lands in
`[ee + 0x8000000, ee + 0x8c30000)` (iPad signed arena: `ARENA_SIZE` 128 MB and module code at offsets
`>= arena_size`, ottsel_signed_gstate.cpp:109) or `[ee + 0x3ebc000, ee + 0x4ee0000)` (the macOS lane's
no-emit region, klink.cpp:45 / kscheme.cpp:211), and rejected otherwise.  Same register set as before
(x2, x9-x12, x16, x17, x30); the selector reads the slot copy in x17, so an intermediate selection
cannot feed the next band.  Overlay `patches/a11-asm-ret-fail-safe.patch` regenerated (pin-to-current
snapshot, 1508 lines) and `scripts/verify-asm-ret-guard-patch.py` PASSes.

Objects re-emitted (`goalc --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'`: all 546
targets in 8.1 s, after `ninja -C build/h1 goalc`).  Byte scan of `out/jak1/obj/*.o`: all 8 guarded
sites (aligner 1, gkernel 6, gstate 1) carry band 1 *and* band 2 - `movz x10,#0x8c3,lsl16` 8,
`movz x10,#0x4ee,lsl16` 8, `movz x9,#0xc000` 8 and `movk x9,#0x3eb,lsl16` 8.  The rewritten
`KERNEL.CGO` (420368 bytes, 10:36) carries 7 of them (gkernel 6 + gstate 1).

Regressions:
- `bash scripts/test-a11-asm-ret-guard.sh` PASS: 21 select cases in `test/a11_asm_ret_guard_test.cpp`
  (both bands' inclusive/exclusive endpoints, the macOS code slot kept, the macOS kernel stack, the
  inter-band gap and the iPad module-data band top all rejected) plus the 8 emitted sites' A1.6
  mask-from-slot contract.
- `python3 scripts/validate-arm64-emission.py` PASS: 90112 code words across 8 objects decode and
  round-trip, so the new `movz/movk` bound words are valid A64.
- Stage 0 named checks re-run and PASS: `test-metal-encoder-guard.sh`, `test-link-begin-args.sh`,
  `verify-link-begin-patch.py`, `verify-asm-synthetic-return-patch.py`, `test-a11-call-goal-asm-ret.sh`,
  `test-goal-bridge-regfile.py`; `verify-overlay-coverage.py` PASS (178 governed, 2 documented strays).

macOS lane (the lane L1 is about): three consecutive `./build/h1/game/gk -v --game jak1 -- -boot
-fakeiso` runs of 60 s each - **0 crash dumps on stderr in all three** (the site `gkernel+0x6d54`
`ldur w0,[x16,#-4]` with `x24 = &EnableMethodSet` faulted 3/3 before this change), 348
`executing top-level` lines (216 before), an OpenGL 4.1 (Metal) context and a 1280x960 window, live
`OTTSEL ROUTE STATE: title-wait-ready`, and 10-14 `OTTSEL PAD` reads with `has-display=true` at 60 s.
Read with the previous evidence: the pre-change fault was the guard's fallback returning into the middle
of a GOAL function, so its prologue never set x24 and the block used the C++ caller's live
`&EnableMethodSet` as an object; with the real return value kept the block is entered through its
prologue (`mov x24, x0` from `(-> pp 0x58)`) and the DGO link completes.

iPad strict lane, two runs (`OTTSEL_SIGNED_GSTATE_EXPERIMENT=0
OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json OTTSEL_SIGNED_EXPORT_BANKS=1 bash
scripts/build-ios.sh`, bundle 10:43): `ottsel-fault.log` **0 bytes** in both, 346 ENTER = 346
RETURNED, one `signed took oracle`, `scene-level='village1'` with cam-accepted 4098->4875 and
4101->4880, 0 rejects, merc-submits 9310->10568 and 9480->10737, eichar=4, `DIRECT FRAME ... drawn=44`,
vsync 541->631, and the screenshot shows the title screen with its rendered village background.  The
lane's own module map confirms band 1 is that arena (`SIGNED MODULE ENTER: name=gkernel ...
main=0x8018000`).

Not claimed: no route input, audio or lifecycle claim on either lane; the macOS lane still has no
frame-counter heartbeat (L0) and the iPad cadence has not been re-measured since the 9 fps note.
