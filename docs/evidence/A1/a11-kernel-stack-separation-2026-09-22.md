# A1.13/A1.14 - the kernel stack was shared with C->GOAL activations (2026-09-22)

Gate: the strict signed-GAME lane's pp=0 / data-call-target class (G1.18), which had survived the
`.ret` guards, the synthetic-return contract and the A1.10 kernel-continuation stash.

Question: after A1.13 balanced the kernel stack, the lane still died right after `served obj 1
(oracle)` with `pc = lr = fault addr = ee + 0x7FFFE10` (the initial kernel stack top), SIGBUS.
Which instruction jumps into the stack?

Measured (run held at the fault; ee = 0x102d5c000; the app kept running afterwards, so the memory
was read live):
- registers: x16 = x30 = 0x10ad5be10 = ee + 0x7FFFE10, x9 = ee + 0x8000000 and x10 = ee + 0x8c30000
  (the guard's module-block bounds), x11 = x12 = 0 - so the guard did reject the slot and jumped to
  its fallback x30; sp = 0x10ad5bdf0; x21 = s7; x20 (pp) = 0.
- memory: [sp] = 0x00000050ffffffff (a GOAL frame local, not a return address) and, one slot below,
  the resume side's stash = 0x10ad5be10 (a stack address). *kernel-sp* resolves to ee + 0x7FFFD90,
  i.e. the kernel was only 0x260 bytes into its stack, and the suspend side's slots live at
  [ee + 0x7FFFD90, ee + 0x7FFFDF0].
- host chain: `signed_gstate::link` -> `call_goal_on_stack_asm_arm64` -> signed villagep-obs +0xfe4
  -> signed gkernel +0x61b8 -> `jak1::method_set` -> `arg_call_arm64` -> `intern_type_from_c`;
  sp+0x54 names villagep-obs+0x9d24 (the method being installed). Same chain, same point in the
  boot, and reproducible in every strict run since G1.17.

Root cause: the kernel runs on a stack anchored at the top of EE memory (`kboot`: goal_stack =
ee + EE_MAIN_MEM_SIZE - 16) and every C->GOAL activation (`call_goal_on_stack`: klink's
`link_and_exec` and the signed loader) anchors at the same address. A *deep* activation - the
signed villagep-obs type/method install, measured ~0x1e0 bytes of frames - runs while the kernel is
suspended inside a dispatch, so its frames overwrite the kernel's saved slots. The suspend side
then pops clobbered words and the guarded `.ret` rejects the bogus slot and follows the fallback
into the stack. The earlier A1.7c/A1.10/A1.12 symptoms (a return into the caller's continuation
with the kernel register file; the rotated `execute-process-tree` argument group) are the same
clobber seen at shallower stack depths.

Fix, two source parts:
- A1.13 `goal_src/jak1/kernel/gkernel.gc`: the three suspend-side asm-funcs now also pop the resume
  side's sixth (stash) slot into x30, so sp lands exactly on the caller's resume point instead of
  0x10 low; the stash doubles as the guarded `.ret` fallback. Overlay
  `patches/a11-kernel-continuation-slot.patch`; guard `scripts/verify-kernel-continuation-slot.py`.
- A1.14 `game/kernel/jak1/kboot.cpp`: the kernel is anchored 64 KiB below the top of EE memory
  (`kActivationStackReserve = 0x10000`), so the activations own the top of EE memory and the
  kernel's frames only ever grow into the free EE tail (the heap ends at 0x3db0000). Overlay
  `patches/a11-kernel-stack-separation.patch`; guard `scripts/verify-kernel-stack-separation.py`.

Regressions: the continuation-slot guard checks the stash, the sixth pop in all three tails and -
in the emitted `gkernel.o` - that exactly three guarded `.ret` sites are preceded by the sixth pop;
the separation guard checks the reserve expression, that the activations still anchor at the top,
and that both overlays reverse-apply. Both PASS.
Verified: `goalc --isa arm64 -c (mi)` exit 0 (546 targets); strict build
(`OTTSEL_SIGNED_GSTATE_EXPERIMENT=0`, `config/signed-game-cgo-tit-vi1-control.json`,
`EXPORT_BANKS=1`) exit 0; **two fresh strict runs**, each with a 0-byte fault log and no BOOT FAILED:
all 55 village1 DGO objects served (village1-vis last), `LINKBEGIN: name=oracle` +
`SIGNED MODULE ENTER/RETURNED` + `signed took oracle` (the activation that used to fault),
346 ENTER = 346 RETURNED, `scene-level='village1'` with cam-accepted 4138/3373 and 0 rejects,
merc-submits 10525/9684, eichar=4, `DIRECT FRAME ... drawn=44`, `SPRITE FRAME ... drawn=23`.
Screenshots of both runs show the Jak title screen with its rendered village background (the two
differ, so the scene is live).

Open, not claimed: visible gameplay with input, audio, lifecycle/saves, level ownership (I0/I1) and
the renderer items (additive clouds, dynamic eyes) remain; no playability claim. The same kboot
anchor change is in the host build and has not been re-run there.
