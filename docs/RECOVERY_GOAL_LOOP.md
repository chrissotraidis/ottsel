# Ottsel recovery goal loop — 2026-09-12

This is the current execution authority. It supersedes numbered BOT queues, not the original product goal. Read `AGENTS.md`, this file, `reports/2026-09-12-recovery-review.md`, and the current STATUS board; follow older evidence only when its source/build/state match.

## September 14 execution update

Read `PROJECT_COMPLETION_PLAN.md` for the end-to-end guide and exact stage exits. Numbered BOT prompts remain historical.

## September 15 execution update

Disk gate is clear: 113 GiB available, zero tmp_pack_*. Stage 0 named crash checks PASS.
Find-only slots falsified. Host GAME+TIT+VI1 329/3061 and link-begin 315/3565 PASS. Signed iOS app (348 CGO-order modules, SHA 01480677) signed-links GAME.CGO and TIT static-screen/title-obs, then SIGSEGV at enter-state pp=0 on VI1 oracle. drawn=0. Not playable. Next: that pp=0 crash, then route/controls. Renderer: ALPHA0x48 clouds, then dynamic eyes.

## September 21 execution update

Stage 0 is green again for the current source: the nested streamed `link-begin` signed hook that made `verify-link-begin-patch.py` fail is captured as `patches/a11-streamed-link-begin.patch` and reconstructs all three files byte-for-byte (`klink.cpp` sha256 3eb8cd27). Host signed-GAME activation is green too: `python3 scripts/test-a11-gstate-loader.py --module-list config/signed-game-full-control.json` ran 313/313 modules ENTER/RETURN including `time-of-day` and `default-menu` with immutable text, data RW and code RX, so emission and activation are not the remaining signed blocker; strict app dispatch is. The 09-15 app crash was read through a blind handler: `served obj 1 (oracle)` then x20(pp)=0 with pc=lr=FAR=0x181674 and `s7` near 0x18ff40, i.e. a jump into GOAL data, while every `sym-scan` printed `below=none` because that scan only accepted the legacy code window, and the `enter-state` label was unsupported because `lr == pc`. `src/shell/ios_boot.cpp` now classifies the address region, resolves nearest and exact symbol slots with no window filter, attributes pc to signed module text, and gates the enter-state claim on legacy-code lr. Evidence: `evidence/A1/a11-signed-game-dispatch-fault-2026-09-21.md`.

## September 22 execution update - strict dispatch integrity goal loop

The strict signed-GAME crash is localized but not fixed; evidence
`evidence/A1/a11-recursive-dispatch-kernel-context-2026-09-22.md`.

Proven: three runs at three ASLR bases fault at the same GOAL place, `gkernel` seg0 +0x5554,
`ldr w1,[x0,x22]`, `this`(x24) = 0x3db0fb4, `x0` = 0x70004000, `si_addr` = `g_ee_main_mem`+0x70004000.
0x3db0fb4 is `*kernel-context*` - the static kernel-context object at the arena's first bytes
(gkernel seg0 data base 0x3db0fb0 + 4) - so the walk is handed the *context* where the pool belongs,
while `x23` (context) holds the lambda. The frame is a *recursive* `execute-process-tree`
invocation (x30 = seg0 0x55b0). Fault-time EE scan: the only non-stack holders of 0x3db0fb4 are the
`*kernel-context*` symbol slot 0x18adfc and one pooled word at 0x1f66e0. Refuted: heap/arena overlap
(the app logs `global heap 0x0013fd20 to 0x03db0000`) and `*active-pool*` as the source
(`active-pool-sym=0x4f4504` in the same run). Open: `x19`/`x23` are not preserved across the
indirect GOAL call at seg0 0x5518 (x19 returns as that call's host continuation 0x801d51c). Later the
same day the holder was localized (`evidence/A1/a11-walk-link-owner-2026-09-22.md`): only two non-stack
EE words hold 0x3db0fb4 - the `*kernel-context*` Symbol slot 0x18adfc and the pooled word 0x1f66e0,
whose 0x20-aligned block carries a Type pointer, three signed-module code addresses, the
`execute-process-tree` function value 0x803c2d4 and a pointer (0x1cb850) into zeroed pool memory; and
`*active-pool*`'s own child chain is healthy (0x4f4504 -> 0x4f45a4 -> 0x1f4364 -> '()), so the faulting
walk was fed outside that chain. The host stack shows the argument group one frame up still correct -
(func, context) = (lambda, *kernel-context*) - while the faulting frame's `this` is the context value,
so the rotated argument group at the indirect-call edge is the leading candidate.

Goal loop for this dependency. Exit: two fresh strict runs reach `LINKBEGIN: name=oracle` and a
live level with a process tree that holds no arena address, fault 0.
- G1.1 (done): localize to instruction, function, recursive edge, object and candidate cells; record
  the three-run A/B, the refutations and the register anomaly.
- G1.2 (done, both signals found): the fault handler now scans EE for the faulting value, prints every
  hit with its owner block and resolves names. Only the `*kernel-context*` Symbol slot and one pooled
  word hold it; that pooled block looks stale (it points into zeroed memory), and `*active-pool*`'s
  child chain is healthy. The faulting frame's `this` is the *context* value while the argument group
  one frame up is correct, so a poisoned cell exists and the edge group is rotated - not yet separated.
- G1.3 (done - ring audited, prediction refuted): the walk was instrumented as planned (emitter trace
  plus the ring dump in the fault handler) and the ring is now decodable end to end. No target is a
  non-entry and no caller-LR is an EE value, so the rotated-argument-group prediction is not supported.
  Evidence: `evidence/A1/a11-goal-ring-audit-2026-09-22.md`.
- G1.4 (landed 2026-09-22): the .ret fail-safe's keep-mask is now computed from the slot
  (goalc/compiler/IR.cpp, one instruction: mov x17, x30 after the slot load; overlay
  patches/a11-asm-ret-fail-safe.patch regenerated and verified byte-for-byte). Before the change every
  shipped guarded .ret site emitted lsr x17, x17, #32, so the mask came from the pushed synthetic
  continuation and the fail-safe was inert exactly when the slot held an EE value - the A1.1
  bad-call-target case. Regression: scripts/test-a11-asm-ret-guard.sh now requires the slot load at
  every guarded site (FAIL 8/8 before, PASS 8/8 after). Evidence:
  evidence/A1/a11-asm-ret-guard-mask-2026-09-22.md. Product effect: the strict run now serves the TIT
  DGO and the streamed village/oracle objects before dying later, in signed module font at seg0 0x6864
  (str w5, [x16] with x16 = g_ee_main_mem + 4, x20/pp = 0, drawn = 0).
- G1.5 (characterized 2026-09-22): the site is in signed `draw-string` (font module, nearest symbol
  0x852c004, fault +0x6860). Decoded: `ldr w0,[x2+0xbd0]; add x16,x0,ee; add x16,x16,#4; str w5,[x16]`
  with x0 = 0, so the store targets g_ee_main_mem + 4. x2 = 0x3da7140 is a heap address (below the arena
  reservation), the field at x2+0xbd0 holds 0, and the surrounding words are float/GS-like rather than a
  basic object head, so this is a null game-data pointer, not a missed loader slot write. The level load
  is still mixed: `signed took` covers static-screen, title-obs and villagep-obs while 13 streamed
  objects fall back (tpage-1609/416/415/397/1499, logo, logo-black, logo-cam, logo-volumes, ndi,
  ndi-cam, ndi-volumes, title-vis) - i.e. the level's own code is split between the arena and the heap.
- G1.6 (done 2026-09-22, control run): the surviving fault needs arena-executed GAME code. The same tree,
  machine and emitter with `config/signed-kernel-full.json` (GAME legacy) leaves `ottsel-fault.log` at 0
  bytes and loads village1 (`legacy fallback village1-vis`, windspinner, yakow, water-anim-village1,
  warpgate, 2 x GAMEPLAY), while the strict CGO registry sends all 335 signed modules through ENTER and
  RETURNED and then dies in signed `font`/`draw-string` on the null field at object+0xbd0. So the
  objective's bad-call-target class is fixed at the .ret site and the remaining barrier is the signed-GAME
  lane's execution/initialization, with the font site as the acceptance probe. Evidence:
  evidence/A1/a11-signed-game-vs-legacy-ab-2026-09-22.md.
- G1.7 (done 2026-09-22, host + live, verified twice): x2 is `font-h` module data + 0x50 in both strict
  runs, each against its own emission generation (`aggregate.json` places `font-h` seg0 data at 0x3db9940;
  the earlier run's x2 = 0x3da7140 is the same plus-0x50 in that generation's layout). Reading the live arena
  at the segment start and at x2 matches the module's data template word for word, so the signed loader did
  copy the segment; the field the code reads (`font-h` data + 0xc20) is a template zero in every
  generation and has no emitter slot/pointer record, and the live word is 0 too. So the word is legitimately
  zero in both modes and the defect is the pointer: signed GAME code (`font`/`draw-string`) treats
  `font-h`'s static data as a live GOAL object whose field at +0xbd0 should hold a pointer. That is the
  objective's arena-data class at a data site rather than a call target.
- G1.8 (partly done 2026-09-22): the producer is narrowed but not named. `font-h`'s emitter record set
  has no type-pointer slot at all (17 records: 13 function tags plus four symbol offsets near data 0xc40), so
  `font-h` data + 0x50 is not a GOAL object start and the arena word the code reads is not a field of one.
  Statically, the only write to x2 in `font` seg0 before the fault block is the `*font-work*` slot pattern at
  0x320 (slot = font data + 8792, kind symbol_offset) and the only branch into the fault block is the loop-exit
  beq at 0x6838, so x2 is live across the vertex loop from that slot read. Live, that slot's content resolves
  to a symbol at GOAL 0x1879e4 whose storage reads as zeros, so the static reading (a `*font-work*` global)
  and the live value (`font-h` data + 0x50) do not yet agree; the producer needs a runtime trace, not more
  static reading.
- G1.9 (done 2026-09-22, host + live): the null field is `font-work.buf`. `*font-work*` is a static
  `font-work` object (a GOAL `structure`, hence no runtime type pointer and no type slot among font-h's
  emitter records) at `font-h` seg0 data + 0x50: its symbol holds 0x3db9990 live, and the field at +0xbd0
  (`font-h` data + 0xc20) is 0 in the template, has no record, and is 0 live. Nothing in `goal_src/jak1`
  sets `(-> *font-work* buf)` and the static initializer does not set `:buf`, so the control's working
  font path means a runtime setter ran there and not in the strict lane - a setter/ordering difference, not
  emission or placement. Evidence: evidence/A1/a11-font-work-buf-null-2026-09-22.md.
- G1.10 (done 2026-09-22, host): the buf store is emitted correctly, so the caller passed a null
  buffer. The faithful mips2c draw_string stores its dma-buffer argument into font-work.buf
  (@sw a1, 3024(v1)@) and the decompilation mirrors it at font.gc:791; the emitted module does the same at
  code 0x324..0x36c (@ldr w2@ from the `*font-work*` slot, @add x16, x2, ee@, @add x16, x16, #0xbd0@,
  @str w1, [x16]@) with #0xbd4/#0xbd8 for str-ptr and flags. Unconditional and correct, so the faulting
  invocation was entered with a null dma-buffer: the caller is the defect site.
- G1.11 (done 2026-09-22, host + live): the display-frame buffer is not null. Decoding
  @draw-progress@'s emitted chain gives the offsets (@*display*@ + 0x22c, x32, + @*display*@ + 0x234, then +0x10,
  +0x24, +0x4); read live in the held process they give @*display*@ = 0x509d34, frame base 0x509f88 and a final
  value of 0xce8400. So a draw-string-xy caller taking its buffer from the display frame is not the faulting
  path, and the caller is still unnamed.
- G1.12 (done 2026-09-22, live; no new run needed): the caller, the argument and the trap are named off the
  installed binary plus the held process. The fault instruction at font seg0 +0x6864 is @font.gc:1462@ in
  @draw-string@ (the live `draw-string` symbol value is 0x84BC004 = font+4, and the pc's own words match the
  disassembly); the return address is main+0xB090, i.e. the @blr@ at main+0xB08C = @display-loop@'s
  @(draw-string *stdcon0* s3-1 *font-context*)@ at @engine/game/main.gc:513@. Every slot that call site loads
  resolves to that line: +3988/3992/3996/4000/4004 = *debug-segment*/*master-mode*/pause/*cheat-mode*/camera,
  +4008/+4028 draw-string-xy, +4012 *common-text*, +4016 draw-string, +4020 *stdcon0*, +4024 *font-context*,
  +4032 *stdcon1*. The argument was NULL: live @*font-work*@ has @buf@ = 0 at +0xBD0 while @str-ptr@ = 0x4F4DF4 =
  the live @*stdcon0*@ at +0xBD4, so the prologue stored a null context. x25 is callee-saved (@m_saved_gprs@ =
  X19,X23,X24,X25,X26 in @goalc/emitter/Register.cpp@), @draw-string@ contains no @bl@/@blr@ and never writes x25,
  and the pause block is skipped (*master-mode* 0x1992D4 != @'pause@ 0x1993EC), so the null is the on-screen frame
  field the chain loads (emitted @debug-buf@ at +0x20, @global-buf@ at +0x24). The SIGBUS is a *store* to the
  readable-but-unwritable low-EE page: @ldr@ of ee+4 returns dma-out 0 and only the final @str@ traps, which
  supersedes the A1.5 "PROT_NONE guard" reading. Evidence: evidence/A1/a11-font-buffer-caller-named-2026-09-22.md.
- G1.13 (next, one variable): make the reading simultaneous with the fault. The post-fault snapshot does not
  reproduce the crash (@*debug-segment*@ reads 0x18FE04, the x21/#f value, which selects the global-buf path)
  because the gated handler holds only the faulting thread while the streamed activation keeps writing globals,
  and the activation is what sets @*debug-segment*@. Add one bounded in-process probe to the fault handler
  (symbol lookup for @*debug-segment*@/@*master-mode*@/@*cheat-mode*@ and @*display*@, then on-screen, vframe,
  @frame@, @frame+0x20/+0x24/+0x28@; about eight lines), rerun the strict profile, and let it decide between a
  null debug buffer (allocate the debug buffers whenever @*debug-segment*@ can be true) and a wrong flag (fix the
  activation/loader so the flag cannot be truthy there). G1.14 then needs two clean strict runs to retire the class.
  Instrument landed 2026-09-22: `src/shell/ottsel_fault_state.h` (`ottsel_fault_state_read`) plus the
  fault-handler call in `src/shell/ios_boot.cpp`, printing two bounded `a17` lines (flag vs the x21 register,
  then on-screen/vframe/frame/+0x20/+0x24/+0x28). It compiles and links clean in the strict build
  (`OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json
  OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh`, exit 0; the probe string is present in
  `out/jak-project/out/ios/app/OttselShell.app/OttselShell`). It is not run yet: install that bundle, run the
  strict profile once, and read the `a17` lines from `ottsel-fault.log` - that one measurement picks the fix.
- G1.14 (done 2026-09-22): the probe ran and picked the fix. At the fault the flag is #f (0x18FE04 = s7;
  `FIX_SYM_TRUE = 0x8`), the frame's `+0x24` slot is non-null (0xCDCFD4) and `+0x20` is 0, and the caller's
  x19 (which holds `disp`) came back as a host address 0x1013E0100, so the `(-> disp frames ... global-buf)`
  chain read a foreign object. `draw-string` writes none of x19/x24/x25, and the C->GOAL bridges
  `_call_goal_asm_arm64`/`_call_goal8_asm_arm64` saved only x20/x21/x22 - the same defect A1.2/A1.3 recorded
  as "x19 returns as that call's host continuation". Both bridges now preserve x19-x28 + v8-v15 (LIFO),
  mirroring `_call_goal_on_stack_asm_arm64`; overlay `patches/a11-goal-bridge-regfile.patch`, regression
  `scripts/test-goal-bridge-regfile.py` (PASS fixed / FAIL pre-fix). The strict profile now runs far past the
  old crash point with no fault log (that was run 1 only).  Falsified as a closure by run 2: the same binary faulted at the font site within minutes and the held process shows x19 = ottsel::signed_gstate::villagep_obs_manifest with ottsel_ios_run_boot as the root C frame, so the crash is data-dependent and at least one more x19 clobberer exists. Evidence: evidence/A1/a11-goal-bridge-regfile-2026-09-22.md.
- G1.15 (done 2026-09-22): the x19 clobber is fixed and verified.  The GOAL->C++ trampolines _arg_call_arm64 and
  _stack_call_arm64 now preserve GOAL register file (x19-x28 + v8-v15, LIFO, balanced), so no C++ callee can
  corrupt GOAL x19: two runs of the fixed code never fault at the font/draw-string site, where every earlier run
  did within a minute.  The A1.7b counter named the violators (jak1::method_set pre-guard; jak1::asize_of_basic
  contained afterwards).  Evidence: evidence/A1/a11-goal-bridge-regfile-2026-09-22.md.
- G1.16 (done 2026-09-22, two runs): the rpc-h/gSound null-object fault was a trampoline save/restore
  ordering defect, not a loader slot.  `_stack_call_arm64` pushed the A1.7c GPR block after the vector
  block but its epilogue still popped the vectors first, so after every GOAL->C call through it x19-x28 held
  vector-save bytes (x19 = 0) and v8-v15 held GPR bytes.  Evidence: at the fault the frame's own saved x19
  was 0x1549300 while live x19 was 0, and the A1.7b counter reported in == out (the corruption is in the
  epilogue, after the counter samples).  The GPR block now sits immediately after `stp q15, q14` so the pop
  sequence is the exact reverse of the push.  Regression `scripts/test-goal-bridge-regfile.py` now simulates
  the stack offsets (FAIL 13 named mismatches pre-fix, PASS fixed); overlay
  `patches/a11-goal-bridge-regfile.patch` regenerated and verified byte-for-byte.  Both runs: 337 modules
  RETURNED, 32 LINKBEGIN.  Evidence: evidence/A1/a11-stack-call-regfile-order-2026-09-22.md.
- G1.17 (done 2026-09-22, three runs): the ret-into-data fault at the oracle serve is closed.  The A1.1
  .ret fail-safe kept the slot whenever its high half was nonzero, and during the oracle serve the slot held
  a GOAL frame local 0x00000050ffffffff (high half 0x50), so ret left the image with pc == lr == x30.
  Measured at the fault: x16 = the guard's own "x16 = x30" = main_s0_code+0xBF0C, a valid continuation, and
  resuming at it advanced the boot - so the fallback is this site's correct return.  The guard now keeps the
  slot only when its high half names this port's window [0x1_00000000, 0x9_00000000), else falls back to the
  incoming x30.  Landed: goalc/compiler/IR.cpp, overlay patches/a11-asm-ret-fail-safe.patch (pin->current,
  verify-asm-ret-guard-patch PASS), harness cases for both measured non-code slots (0x50ffffffff,
  0x0f41210f24).  Operational: those guard bytes are baked into out/jak1/obj/*.o, so a compiler change only
  ships after "goalc --game jak1 --isa arm64 -c '(mi)'" (546 targets, also rewriting the CGOs the signed
  preflight matches against) and then the app build; all 8 guarded sites (aligner 1, gkernel 6, gstate 1) then
  carry the new test.  Evidence: evidence/A1/a11-asm-ret-window-2026-09-22.md.
- G1.18 (next, one variable): all three runs now die executing code at GOAL 0x88ba328 with lr = 0x181674 (the
  village-cam Symbol) and a bad memory access, deterministically right after "served obj 1 (oracle)".  That is
  the A1.1 "GOAL data used as a call target" class, now with pc inside code and the data value in the link
  register, so chase the producer of that link register.  Keep the trampoline guard, its regression, the A1.7b
  counter, the .ret window guard and the A1.9 probe; then two clean strict runs before this class is retired.
  Measured in the held run (x30 = lr = 0x181674 = a GOAL Symbol address, x20/pp = 0, fault addr = x16+0x10
  with x16 = 0x109e590d44): the faulting instruction is main+0xa328 'ldur w0, [x16, #0x10]' and the enclosing
  block is the *display*-relative chain the A1.12 note attributed to draw-progress ((-> this 0x22c) scaled by
  32 into an array at this+0x234, then +0x10 / +0x20 / +0x24 / +0x4).  It runs with x19 = the stack pointer
  (x19 = x10 = sp), so the block dereferences a host value where a GOAL object offset belongs.  The live GOAL
  slots on the stack hold Symbol addresses instead of code addresses ([sp+0x10] = 0x1f53d4), i.e. the same
  'GOAL data used as a code/link value' shape one step earlier; intern_type_from_c+0xf8 / alloc_heap_object
  appear only as stale stack words (the C++ allocator does not call GOAL), so the live entry into the faulting
  function is what has to be named.  Next: walk the GOAL frames at the fault (the pushed (synthetic, x30)
  pairs plus the 'str x9, [sp, #-16]!' old-sp stash) and print each frame's return slot with its module and
  offset, then fix the producer of the data return address/link register.
  Note: above[]/below[]/sp-words print two 32-bit halves per address by design, so the log alone cannot tell a
  host address from a GOAL value; the host-frame/classify lines carry full addresses - use those or lldb.
  Frame structure measured: the pc (main seg0 +0xa328, host base ee+0x88b0000) is real main text; three live
  call_goal_on_stack frames sit under signed_gstate::link (three nested GOAL activations) and the C++ frames
  above the fault are alloc_heap_object (saved x30 = intern_type_from_c+0xf8) and method_set (saved x30 =
  arg_call_arm64+0x5c).  method_set is pure C++ and never calls GOAL, so those words are stale/saved-register
  values, not the live caller: the only live C->GOAL bridges in the scan are the three call_goal_on_stack frames
  (the loader's module-entry calls; klink.cpp passes goal_stack), so the faulting main function was entered
  inside a GOAL activation, not from the allocator.  Candidate C++->GOAL dispatchers to break on:
  call_method_of_type (kscheme.cpp:1464 -> get_method -> call_goal) as used by asize_of_basic (:1796) and
  copy_basic (:1764, which reads the type tag at obj-4), call_method_of_type_arg2 (klink.cpp:912, relocate) and
  kprint (:342/:363).  Negative result: no _call_goal_asm_arm64 frame appears in the fault scan, which excludes
  copy_basic/asize_of_basic as this fault's live entry.  Next: break on the three bridge entries plus klink.cpp's
  activation call, log the target and x0..x2, and name which activation reaches main+0xa328; then fix the
  producer of the data link register / host-value x19.
  Function NAMED: the faulting code is display-loop (main seg0 entry +0x7d24 - main.json's seg0 immutable
  function tag is at 0x7d20, and the A1.7 record has display-loop's entry at main+0x7D24/+0x7DA4 loading disp
  into x19).  main+0x8000..+0xa328 disassembles with no ret and no x19 save/reload, so the x19 at the fault is
  the register as it was when the function started, and x30 (0x181674 = the village-cam Symbol) survives every
  call in the body, i.e. it is the ENTRY link register: display-loop was entered with a data link register.
  So the defect is at the call that entered display-loop, not inside it.  Next measurement: hardware-breakpoint
  main+0x7d24 in a fresh run (the __GOAL pages stay untouched that way) and log x19/x20/x21/x30/sp plus the
  caller's slots, then fix that producer and run twice.
  ENTRY MEASURED (fresh run, pid 78652): at display-loop's entry x19 = the entry address itself, x20 (pp) =
  0x1f53d4 (a GOAL symbol-table address, not a process) while x21 = s7, x0 = 0x801fb74, x1 = 0x1f437c, x2 =
  0x1f53d4 (== x20), x3 = s7, x4 = 4, lr = gkernel+0x1cb4.  So display-loop was reached by a tail call through
  x19, and pp already held a Symbol address before it ran: the corruption is upstream.  The caller's site
  (gkernel +7336..+7348) is a guarded .ret of the A1.8 shape followed by padding, so lr = +7348 is that
  function's own link register, not a blr continuation; the next gkernel function (+7348) is a GOAL method
  dispatch ((-> pp -4) tag, (-> type 0x38) method, blr).  Next: break at main+0x7da4 (disp load into x19) and
  main+0xa328 in one run, and on the gkernel tail-call site, to name what set pp and who tail-called
  display-loop.
  CONSOLIDATION: the fresh run hit the A1.7 font crash instead of the oracle-serve variant (font+26724,
  'str w5,[x16]' with x16 = arena+4, x0 = x5 = x25 = 0, lr = main+0xB090 = main.gc:513 = display-loop calling
  draw-string, x19 = a stack address, x20/pp = 0) - the same x19-clobbered-display-object cause as G1.18, so
  both variants are one defect.  The A1.7c guard already covers _arg_call_arm64/_stack_call_arm64, the four
  C->GOAL bridges and _mips2c_call_arm64, so the surviving clobberer is a boundary or store none of those
  cover.  Next: bisect inside display-loop with hardware breakpoints (entry +0x7d24, disp load +0x7da4, and the
  draw-string/draw-progress call sites), reading x19 at each; the crashed run is a clean reproducer.
  x19 WRITE SITES (static, whole function): display-loop writes x19 exactly once - 'mov x19, x0' at
  main+0x7da4 - and saves it at +0x7d24; every other use is a read.  So x19 can only change through a callee
  that fails to preserve it.  At the font crash x19 = sp+0x200 (a frame-local address).  Two candidates remain:
  (a) x0 was already wrong at the single load (the first blr at main+0x7d70 runs before it and x0 is
  caller-saved), or (b) a callee between +0x7da4 and the draw-string call clobbers x19.  Discriminator: break
  at main+0x7da4 and read x0 (measured 0x801fb74 at the entry) - unchanged means (b), a stack address means
  (a).  Then fix and verify with two clean strict runs.
  DISCRIMINATOR ANSWERED (fresh run, main host base 0x10b5ac000): at main+0x7da4 x0 = 0x509d34 = the *display*
  value, so the single x19 load is CORRECT and case (a) is refuted; the first blr (main+0x7d70) reloads x0 from
  the *display* symbol before the load (entry x0 was 0x801fb74).  So case (b) holds: a callee between +0x7da4
  and the draw-string call changes x19, and the first call after the load is at main+0x7e20.  Next: put breakpoints
  on the blr sites in +0x7e20..+0xb08c with the condition $x19 != 0x509d34 (validate_layout ran at boot, so
  software breakpoints are safe now); the first hit names the preceding call as the clobberer, then fix it.
  CORRECTIONS/CONCLUSION: software breakpoints on __GOAL text are unusable - the loader's validate_layout
  protection check runs at boot after they are installed, so the run dies with SIGABRT.  Hardware breakpoints
  only.  The last unverified boundary is now covered: test-goal-bridge-regfile.py simulates
  _mips2c_call_arm64's offsets too (modeling sub sp,#1280 and a 32-byte entry slack) and PASSes, so all six
  GOAL<->C boundaries are machine-verified LIFO-balanced and none clobbers x19.  With display-loop writing x19
  exactly once (correctly, from the *display* value) and the crash x19 = the faulting frame's sp+0x200, the
  remaining cause is a GOAL callee that writes x19 without saving it - a codegen/emitter defect in a signed
  module.  Next: statically scan the emitted modules for functions that write x19 with no matching prologue
  save, starting with display-loop's callees, and fix that function.
  WHERE THE CODE COMES FROM: a11_module_emitter.h is 387 lines with no prologue/register-save logic and no
  x19 reference, so the modules' instruction streams (prologues, GOAL register-file saves, call shims, .ret
  sites) are copied from the goalc-produced out/jak1/obj/*.o.  A missing-x19-save defect must already be in
  those objects, and goalc's rebuild check is source-content based ((mi) reports all 546 targets in ~9 s), so
  objects from an earlier compiler revision can survive a compiler change.  Next experiment: move out/jak1/obj
  aside, run goalc --game jak1 --isa arm64 -c '(mi)' for a genuine full recompile, rebuild the app and run
  twice; if the clobber persists, scan the emitted modules for a function that writes x19 with no matching
  prologue save (hardware-breakpoint bisection, 4 sites per run, otherwise).
  RESULT: a forced full recompile (out/jak1/obj moved aside, 'goalc -c (mi)' = all 1068 targets in 10.5 s,
  518 fresh objects, guarded sites still present 8/8 after the rebuild) reproduced the IDENTICAL fault
  (pc = main+0xa328, lr = 0x181674, GOAL offset 0x88ba328, 32 LINKBEGIN), so object staleness is refuted and
  the corruption is in current goalc output or GOAL semantics.  Remaining work: name the callee that leaves
  x19 wrong between main+0x7da4 and the draw-string call, using hardware breakpoints only (4 sites per run,
  bisecting the 109 post-load blr sites), then fix it and verify with two clean strict runs.
  SHIPPED-BINARY CHECK (otool on the installed app): _stack_call_arm64 at 0x1001c0770 ships the corrected
  prologue/epilogue order (q15,q14 / x19,x23 / x24,x25 / x26,x27 / x28 / q13,q12 / q11,q10 / q9,q8 then the
  arg array; pops exactly reversed, counters present), so that boundary is verified in the artifact too.
  With all six asm boundaries cleared in source, regression and binary, the remaining candidate is a
  goalc-produced function in a signed module that writes x19 without saving it.  Next: disassemble each emitted
  module's text and flag every x19/w19 write with no enclosing prologue save since the nearest preceding ret
  (starting with main and its callees), then fix that function and verify with two clean strict runs.
  RESULT - MAIN IS CLEAN: lldb-disassembled main's whole seg0 (live app, ee+0x88b0000, 12288 instructions) and
  scanned for x19/w19 destination writes with no enclosing prologue save: 84 writes, 0 unsaved.  Every main
  function - display-loop included - saves x19 before using it, so the clobberer is NOT in main.  With the six
  asm boundaries, the trampolines and the objects all cleared, the remaining candidate is a NON-main function
  display-loop reaches through a slot: another signed module, a streamed/legacy object, or a C/asm path.
  Next: repeat the same disassembly + save scan for gkernel and the loading-screen path (progress,
  gsound, dgo/rpc-h), naming any function whose body writes x19 with no enclosing save; then fix it and verify
  with two clean strict runs.
  MODULE SCAN: gkernel, progress, gsound and rpc-h have no genuine unsaved x19 write (progress 66/0, gsound
  60/0, rpc-h 17/0; gkernel's 5 flags are false positives - three are post-.ret restores, one is a normal
  mov x19,x0).  Decoding them gave the port's GOAL tail-call convention: 'ldr w0,[slot] / add x0,x0,x22 / str
  x0,[sp,#-0x10]! / mov x30,x0 / add x19,x19,x22 / br x19' - a tail-called function starts with x19 = its own
  entry and x30 = the caller continuation, exactly as measured at display-loop's entry.  So the 0x181674 in x30
  is a CALLER CONTINUATION value: a thunk set x30 from a slot whose value is a GOAL offset (a Symbol address)
  rather than a host code address.  Next: find the thunk that tail-called display-loop (caller gkernel, lr =
  gkernel+0x1cb4) and check how it computes x30.
  x30 WRITE SITES (gkernel, first 0xc000): only the six A1.8 guard epilogues (mov x2,x30 / sub / and / mov
  x30,x16 at gkernel+0x7316, +0x7512, +0x8376, +0x27240, +0x27588, +0x32860 - so the guard demonstrably ships in
  the installed app) and two correct tail-call thunks (ldr w0,[x16] / add x0,x0,x22 / str x0,[sp,#-0x10]! / mov
  x30,x0 at +0x7712 and +0x31544).  No missing-deref thunk in that region.  Since x30 was a CODE address at
  display-loop's entry (gkernel+7348) but is 0x181674 in the crash frame, x30 became data inside the display
  path.  Next: scan all modules for x30 writes (including ldr x30,[...], .ret slot reads and shim pushes) and
  search the symbol table for a slot whose value is 0x181674.
  SYMBOL-VALUE HYPOTHESIS REFUTED: memory find -e 0x181674 over ee+0x100000..ee+0x1a0000 found nothing, so no
  symbol's value is 0x181674.  It is the village-cam Symbol's own address, produced transiently by 'slot + s7'
  (the intermediate of a symbol_offset read).  main's x30 writes are all normal shim restores or guarded
  epilogues, so the defect is a slot value consumed without the '+ee' and 'ldr w,[x16]' deref.  Next: search the
  emitted modules (via lldb disassembly + a Python driver, all 335 if needed, starting with the streamed/level
  modules and font) for 'add xN,xN,x21' followed closely by 'mov x30,xN' or a branch using it.
  PATTERN-SCAN STATUS: three .s-word scans failed as tools - 5105 hits for the loose 'add xD,xD,x21' rule, 49639
  for the slot-read rule (the s7/ee arithmetic is pervasive and my deref window was one instruction short), and 0
  for the tail-call filter, which contradicts the live gkernel+0x7b58 disassembly.  Cause: gkernel.s holds only
  15058 .long words plus SYMBOLIC instructions (adrp/add are textual), so a .long-only scan mis-maps indices to
  offsets and misses symbolically emitted instructions.  Retire the .s-word approach: scan module code through
  lldb disassembly, which is uniform.  Search for a slot value reaching a branch or x30 without the '+x22' and
  'ldr wK,[x16]' pair - especially 'add x19,x19,x22' whose x19 came from a raw slot, and 'mov x30,xD' fed from
  an s7-relative load.
  DISPATCH-THROUGH-x19: decoding the whole gkernel tail-call thunk (+0x7b14..+0x7b5c) shows it dispatches through
  an INHERITED x19 - it loads/dereferences a slot, adds s7+ee, reads the symbol VALUE, adds ee, pushes it and
  sets x30, then does 'add x19,x19,x22 / br x19' without ever writing x19.  So x19 is the caller-supplied
  dispatch target; a caller passing a DATA offset (a Symbol address) makes it branch to arena+offset, straight
  into the module-arena data region - precisely the objective's shape, and consistent with the measured
  display-loop entry (x19 = its own entry, ee already added).  NEXT: find the caller that computes the x19
  dispatch target from a raw slot value with no 'ldr wK,[x16]' dereference, scanning lldb disassembly rather
  than .s words.
  TWO x19 SHAPES IN DISASSEMBLY: (i) the pervasive SLOT-READ sequence ('adrp x19,<slot> / ldrsw x19,[x16] / add
  x19,x19,x21 / add x19,x19,x22 / eor x17 / mov x16,x19 / add x16,x16,x17 / ldr w19,[x16]') where x19 is the
  slot address and the value IS dereferenced - correct; and (ii) the DISPATCH form (gkernel+0x7b58: 'mov
  x30,x0 / args / add x19,x19,x22 / br x19') with no dereference, where x19 is the caller-supplied target.
  Discriminator: 'add x19,x19,x22' followed by 'br x19' with no 'ldr w19,[x16]' between.  NEXT: enumerate the
  dispatch-form sites across all modules and find which caller sets x19 from a raw s7-relative value.
  MAPPING CONFIRMED, .s OFFSETS UNRELIABLE: gkernel.s's first eight words match live memory at 0x10B75C000, so
  the module base is right and the .s corresponds to the running code - but the .s is 15058 .long words PLUS
  symbolic instructions (no 'br x19' or 'add x19,x19,x22' appears as text or as the expected word), so offsets
  computed from .long indices are wrong and symbolically emitted instructions are invisible to word scans.
  Earlier .s-index-derived guard offsets (0x1954/0x1a10/0x1d48/0x6120/0x627c/0x75d4) are unreliable; lldb <+N>
  offsets are the trustworthy ones (live guard epilogues at gkernel+0x7316, +0x7512, +0x8376, +0x27240,
  +0x27588, +0x32860).  Use lldb disassembly for every module-level offset and scan.
  x19 VALUE CLUE: at the font crash x19 = the faulting frame's sp + 0x200 - a stack-slot address, not a GOAL
  object - while display-loop writes x19 exactly once (correctly).  So the clobbering callee puts an sp-derived
  address into x19 and does not restore it (frame-pointer style store); search for 'mov x19, sp' /
  'add x19, sp, #imm' / an x19 restore from a slot holding an sp-derived address on display-loop's call path.
  NEXT: hardware-breakpoint bisection of x19 inside display-loop (four sites per run, e.g. +0x7da4 control,
  +0x8c00, +0x9d00, +0xb08c, each conditioned on x19 != 0x509d34) - one continue, read the first that fires,
  halving each run, then fix + regression + two clean strict runs.  Sites: /tmp/blr_main.txt (110 entries).
- G1.8 (next, one variable): decide whether the pointer or the object is wrong. Cheapest discriminator: dump
  `font-h.o`'s own link records for data offset 0xc20 (host-side, legacy object format) and compare with the
  emitter json. No record in either proves the word is zero in both modes, so the defect is the producer of x2
  (a global or field holding a static-data address where a heap object belongs); a record in the object but
  not in the emitter would be an emission defect. Then fix that one site with a bounded regression.
- G1.9: rerun the strict profile twice; confirm oracle linked, live level activity and zero faults;
  only then retire the pp=0/arena class and unlock I0/I1 and the renderer lane.

Next iterations, one falsifiable question each, in dependency order:
1. In progress, with two corrections. The pp=0 crash replays in every strict run and its text goes to the app's `ottosel-fault.log`; the runtime log keeps growing from renderer threads after the gated handler stops the faulting thread. The named reading: `pc=x30=0x181674` is the `village-cam` Symbol object address (value = Type `0x34d0bf4`), `pp=0`, `x21`=s7, `__PAGEZERO` covers everything below `0x100000000`, the value sits in an argument slot at CPU-stack +0/+0x50, and the chain runs from `signed_gstate::link` through `call_goal_on_stack` -> signed `villagep-obs` -> `gkernel` -> `jak1::method_set` -> `arg_call_arm64` -> `intern_type_from_c` -> `alloc_heap_object`, i.e. the signed loader's activation of `villagep-obs` and its `village-cam` type definition. The C->GOAL bridges now establish the GOAL synthetic return slot that asm-funcs read (`patches/a11-call-goal-synthetic-return.patch`, regression `scripts/test-a11-call-goal-asm-ret.sh`, reconstruction `scripts/verify-asm-synthetic-return-patch.py`) — a real contract fix, but a full rebuild still faults identically, so it is not this crash's cause. Since then: the object dump refutes the type-record lead (`villagep-obs.o` records those five references as kind-1 symbol records with initial word 0, so both loaders write `sym - s7`), the fault is an `IR_AsmRet`-style `ldr x30, [sp]` with the bad value at CPU-stack offset 0 on a genuine GOAL stack frame, and `config/signed-kernel-full.json` with banks 1 runs the same code cleanly (oracle linked, 68 DGO objects, level activity) — so the defect is in the signed path's execution of GAME modules. Next: walk the GOAL frame chain from the fault `sp` (`[sp+0x10]` holds `sp+0x60`), name each frame against `modules[]`, and print the frame-local slot that produced x30; `sp+0x98` already names `villagep-obs+0x9d24`, a GOAL function entry, so the method-install path writing through the frame's Type/Symbol pair is the prime candidate. Frame dump taken: [sp] holds that Symbol address while `sp+0x38` holds the Type object, `sp+0x98` names the method entry `villagep-obs+0x9d24`, `[sp+0x10]` stores the caller sp as a 32-bit low half, and the consumer decode at `villagep-obs.s` seg2 `0xd64` shows the slot *is* dereferenced. Landed: `.ret` now selects `[sp]` vs the incoming x30 by the port address split (`patches/a11-asm-ret-fail-safe.patch`, regression `scripts/test-a11-asm-ret-guard.sh`), and the guarded select proved the fault site's incoming x30 was already 0x181674 - the contamination starts upstream. It is inert in the app until the prebuilt GOAL objects are regenerated with the rebuilt goalc, because the module emitter only rewrites `out/jak1/obj/*.o`. 2026-09-22 measurements: the export-bank path is refuted (banks=0 faults identically), the loader writes the five `village-cam` slots correctly as `sym - s7` with the Symbol still undefined at activation, and the consumer sites do dereference - Regeneration done 2026-09-22 (`goalc --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'`, 546 targets in 8.2 s): the `.ret` guard is now live in `gkernel`/`gstate`, the 0x181674 branch into GOAL data is gone, and the failure moved into `gkernel` at GOAL 0x801d554 (nearest symbol `execute-process-tree`) as a data fault - confirming the `.ret` slot as the mechanism and putting the origin upstream. Next: enable the emitter GOAL call trace and read its ring at the new crash. Later on 2026-09-22: the `method_set`-with-a-Symbol theory is refuted (a bounded log for symbol-table-window type arguments produced no hits), and the crash position is precise - the fault is in the DGO-completion GOAL code after `served obj 1 (oracle)` and before `link-begin` for the oracle, inside signed GAME code.
2. Only after 1 is closed: strict-mode route and level-ownership acceptance (I0/I1) with the pp=0 class retired.
3. Renderer, unchanged and still deferred behind the architecture gate: per-batch ALPHA 0x48 additive clouds, then dynamic eyes.
4. Then I2 audio/lifecycle/saves, I3 frontend, P1 iPhone, reproducible packaging and D1 devices, in the ordered gates below.

The ordered list below preserves recovery history and subsystem details; the completion plan supplies current dependency order. At every iteration select the first unmet dependency, state one falsifiable question, implement the smallest change, prove it, update the current step and continue. Stop product work at hard gates; never substitute a research route for strict signed product acceptance.

## Product and exit contract
Deliver honestly playable native Jak 1 on iPad first, then iPhone parity and physical-device readiness, with reproducible ROM-safe packaging. Use signed ARM64 AOT code, no runtime code emission/RWX/MAP_JIT/listener execution. Users supply legal game data; never commit it. Do not invent another engine.
Original brief/roadmap: `00-phase1-brief.md`, `05-roadmap.md`, `BOT2_PROMPT.md`. Detailed current acceptance: `16-ipados-ios-goal-loop-2026-08-23.md`. Its gate names are stable: M0 macOS reference; I0 iPad bootstrap/route; I1 scene+pacing; I2 audio/lifecycle/saves; I3 PS2 controls/settings; P1 iPhone; D1 devices.
A build, log, counter, title, first frame, residency string, camera pan or screenshot hash is not gameplay proof. Simulator acceptance does not close physical-device readiness. No App Store submission, Jak 2/3 or multiplayer scope.

## Execution rules
- One writer owns each source file; this recovery task owns all runtime/build actions. Subagents may do bounded independent source/test work. The previous builder stays read-only until explicitly handed ownership.
- Before each experiment run `df -h / | tail -1` and count `.git/objects/pack/tmp_pack_*`, resolving the common git directory for worktrees. Require at least 40 GB available and zero temporary packs, as supplied in AGENTS.md; no cleanup is implied. Either failure stops product work.
- Preserve pre-existing changes; stage exact files only, no blanket resets or `git add -A`; every new worktree file <100 MB. Do not regenerate a broad nested patch without auditing its scope. Do not truncate evidence or delete data.
- One booted Simulator maximum, normally iPad `08636791-2675-4675-8335-EF72EF954DCF`; inspect the inventory first. Never parallelize captures, launches, builds or input injection. Shut down the previous test device before testing iPhone.
- Record only under `/tmp/ottsel-video/` using AGENTS.md's exact H.264/SIGINT sequence, sleep ≤30s, then size and SimRender-handle checks. Never start a recording with an existing live movie handle.
- For each iteration state: question, source evidence, predicted failure, smallest change, decisive check. Run one default-off probe in a fresh process; an experiment with no valid measurement is inconclusive, not a win.
- Keep one ≤60-line evidence document per proven gate and ≤8 appended STATUS lines. Update this loop's current step instead of creating BOT68/BOT69. After three unchanged failures, reassess the premise/observer and record the exact blocker; continue independent useful work.

## Ordered recovery and completion gates
Whole-game signed-code recovery (subsystem details in step 8) is the primary implementation priority after prerequisites, as ordered by PROJECT_COMPLETION_PLAN.md. It is an original-PRD architecture blocker; visual progress cannot defer or close it.
1. **Crash/reconstruction prerequisite (focused regressions passed).** Root-cause evidence: August 21 malformed-link report and August 22 encoder boundary report. Prove normal/exception/exactly-once encoder cleanup and null/zero/negative link rejection; keep guards plus tests in reproducible patches. Reconcile current bucket-policy tests using terrain ownership and 69/70 boundaries. No new renderer R-round before these checks pass.
2. **Trustworthy baseline.** Preserve dirty-source hashes/diff, surgically remove the unconditional production `direct_fs` diagnostic return, and keep genuine fixes. Compile from known source; record executable hash, data identity, device, route, flags and output timestamps. Audit default-on probes and report actual GPU completion/error, not merely draw-call counts.
3. **Correct batch ownership.** Regression: append B after snapshot A, finish A, verify B survives and its bytes cannot be recycled until B's consuming command buffer completes. Give Sky captured-tag erasure. Use immutable fresh buffers as a bounded correctness control if necessary; restore pooling only with proven ownership. This is not a mandate for a renderer rewrite.
4. **MERC parity.** Regression against full desktop vec4 skin→perspective→GS→Metal equations, including identity/translated/weighted bones and zero-weight garbage. Preserve homogeneous W through the native vertex contract; restore the oracle depth subtraction only after the test passes. Verify actor/world occlusion and ground contact, not merely clip-visible counts. Existing depth-mode sweeps are diagnostics, not accepted math.
5. **I0 route + controllability.** Launch with `SIMCTL_CHILD_OTTSEL_TRACE_INPUT=1`; `python3 scripts/replay-ios-normal-route.py <sole-booted-udid>` drives the normal menus and waits for each accepted edge plus neutral release. Fresh normal title→New Game→Continue Without Saving (or chosen save)→Village1 intro completion→Training. Correlate frontend screen, cutscene/camera and target/control state with visible evidence. Use real input: move, stop, reverse, jump/action, camera, neutral release; show actor movement relative to fixed world landmarks. Do not substitute `(bg 'village1)` or a flyover for this route. Fix the first reproducible failed transition before more cosmetic probes.
6. **I1 remaining rendering and pacing.** Compare matched game state/packets against M0. Close HUD/title material, sky, TFRAG/TIE/MERC/material/effect defects individually. Direct baseline: equivalent nx/ny mapping is not a bug; test raw GS/XYOFFSET inputs and clipping, FST/fractional UV, STQ interpolation, texture identity/CLUT, alpha/blend in that order of demonstrated mismatch. Never infer texture failure from an unisolated final screenshot. Terrain followups: retain geometry across camera motion and update draw visibility; interpolate resolved per-vertex TOD colors instead of flat palette indices. Use the independent tests in the review before claiming screenshot causality.
7. **I1 acceptance.** Two fresh normal-route runs with coherent world, grounded/occluded animated Jak, sustained player movement/jump/action and camera follow. Retain bounded clips plus a longer log/state window; report presented-frame cadence and p50/p95/p99 frame time, not DMA chains/s as FPS. Compare responsiveness with M0, no matching crash or unbounded resource growth. Every visible defect must be fixed or explicitly block acceptance.
8. **Whole-game signed-code and I2 audio/lifecycle/persistence.** Close the original signed-AOT architecture prerequisite: current `OTTSEL_NO_EMIT` still makes loaded CGO pages executable and writes trampolines; the signed A1.1 slice alone is not whole-game proof. Follow `SIGNED_AOT_RECOVERY.md`, `10-code-packaging-and-signing.md` and `reports/2026-09-12-delivery-audit.md` to move all executable code into signed Mach-O and keep only data/link metadata writable. Do not defer this to device-only testing or label the research bundle data-free. Confirm nonzero game PCM and actual audible output; test pause, interruptions, background/resume, disconnect/cancel neutral input, save/reload, termination/relaunch. Do not regress into stale “zero PCM” assumptions. Human/device-only acceptance remains explicit if tools cannot observe it.
9. **I3 frontend.** Follow the existing `ref/sunpad` interaction reference and full PS2 controls/settings contract in doc 16: both sticks, all buttons, multitouch/feedback, editable persistent normalized layouts, controller handoff, iPad/iPhone defaults and accessible settings. Unfreeze this lane after I0/I1 are stable; preserve game input while changing the UI and validate every rewired control.
10. **P1 iPhone.** Stop iPad Simulator, use one iPhone profile, repeat accepted route and controls/audio/lifecycle/save tests; correct safe-area/layout/performance differences. Shared regressions reopen their originating iPad gate.
11. **Reproducible delivery + D1.** Reconstruct the pinned engine with maintained patches; build/package from documented commands without `/tmp` script dependencies. Audit signed executable/no-emit behavior and asset-free deliverables; prove local legal-data import and saves. Install/test physical iPad and iPhone when available; report exact signing/device/user blockers without claiming completion or fabricating proof. Continue packaging and independent tests while device acceptance is pending.

## Sky diagnostic contract when needed
Use one captured immutable real batch and its exact texture/state after all other draws, with matched route/viewport and successful command-buffer completion. Test constant output, UV visualization, known texture, real texture, then real material as separate controlled variants. Do not change batch filters, position, state or buffer ownership simultaneously. Identify raw versus normalized coordinate values; do not transform logged NDC twice. A second mutable queue snapshot is not the same batch.

## Current continuation
- **Next renderer change: additive Sky cloud blending.** Build1f1d78e1 froze41 real Training batches. First4 show blue/pink sky (333960 pixels, meanRGB160.436); adding cloud batches4–34 lowers the same pixels to28.835. They request ALPHA0x48 = Cs*As+Cd; native uses source-over. Last six black triangles only fill675180 previously uncovered pixels: keep them. Implement the demonstrated blend state, test actual GPU equations/captured population, then fresh normal-route visual/controls. Evidence and exact state: `evidence/I1/recovery-stale-terrain-2026-09-12.md`. The earlier five-fragment test proves real sampling/material work for batch0; raw-vs-normalized and blanket sampler hypotheses are refuted. Refinement (2026-09-14, host-only read-only): the clouds ALPHA value already reaches the draw loop as NativeSpriteBatch.diagnostic_alpha (metal_shell.mm:334/2803), and TIE separately consults the extracted 3-bit DrawMode::AlphaBlend, which also maps the additive enum 2 to source-over, so the fix needs both decoders and no new per-batch plumbing; desktop uses GsAlpha for Direct (DirectRenderer.cpp) and DrawMode for tfrag (background_common.cpp). Decode re-confirmed (2026-09-14, host-only read-only): 0x48 = SOURCE/ZERO_OR_FIXED/SOURCE/DEST under the port's own layout (gs.h:205-220, a=bits0-1..d=bits6-7), and GsAlpha::print() (gs.cpp:282-341) labels c SOURCE as As and d DEST as "+Cd" while BlendState::from_register (DirectRenderer.cpp:1548) repacks nothing, so the additive branch (Cs-0)*As+Cd is the right decode and no decoder or field-order change is in scope; 0x44 (sky base batches 0-3) is source-over either way. Fix-site refinement (2026-09-14, host-only read-only): the blend is baked into a pipeline state, so the fix is two additive states plus mode-based selection in the shell, not a decoder edit - Direct's source-over 'directBlendPipeline' (metal_shell.mm:925-930, selected :2350) already receives the raw register as 'NativeSpriteBatch.diagnostic_alpha', and TIE already reads its 3-bit mode at the selection site (:1752 '(draw.mode>>24)&7u') but collapses it via 'ottsel_mobile_alpha_blend_enabled' (mobile_scene_policy.h:120-124, mode 2 and mode 1 both return true) into the single source-over 'tieBlendPipeline' (:1041-1044, selected :1764); both carriers exist, so no re-plumbing and no decoder change.
- **Next MERC change: dynamic eyes.** Actual eichar eye_id0/1 currently bind static FR3 slots323/324. Desktop bucket54 composes background/iris/pupil/lid into persistent128x128 textures. Stage the real producer with immutable eye images published atomically with MERC geometry/camera; require packet, pixel and allocation/lifetime regressions before application. Captured flags0 disables modified vertices; envmap needs per-effect fade evidence. Lighting/HDR and alpha-test/ignore-mask/decal-alpha corrections already pass focused and live checks, but hair/eyes remain visibly wrong. Refined by the 2026-09-14 host-only audit: the static level slot is the same eye-page texture the desktop uses as the eye background base, so the eyes are uncomposed rather than mis-textured and only buckets 3/67 have native consumers today - the fix is a new bucket-54 GS consumer composing four quads into a 128x128 texture, not a texture-id swap (evidence/I1/recovery-merc-menu-2026-09-12.md). Bucket trace landed 2026-09-14 (host-only, read-only): jak1 `(eyes 54)` and `update-eyes` (`eye.gc:679-724`) also routes level-eye render DMA into texture-upload buckets 48/51; native windows are pure arithmetic (`mobile_generic_policy.h:71-74`, `off + 16*(id+1)`) so the generic 0..69 `DmaFollower` loop already walks 54, and `render-eyes` copies the level `iris-shader` adgif into each packet (`eye.gc:74`) so the bucket DMA is self-describing and no new serialized eye field is needed; `merc-eye-anim` (`eye.gc:905`) is the per-actor producer over 11 slot controls. Publish constraint (2026-09-14, host-only read-only): the frame has exactly one render pass - `metal_shell.mm:1471` creates the only MTLRenderCommandEncoder (RAII-closed by RenderEncoderEndGuard, `metal_encoder_guard.h`) attached to the drawable or the diagnostic `directOffscreenTarget` (:1445-1459), present/commit at :2589/:2596 - and Metal cannot sample the current attachment, so the composer must be its own earlier encoder in the same command buffer rather than same-pass; GS order (dma-h.gc:219-227: 48/49/51/52/54/55) has level eyes composing into 48/51 before the 49/52 merc-pris draws that sample them, and 48/51 are already the native texture-upload window, so the publish is a bind override at `metal_gfx.mm:2150` keyed by MercDraw.eye_id over the pure-offset slot formula (`mobile_scene_policy.h:69-73`), not a new serialized field.
- **Verified scene baseline:** crash guards, consumed-resource retirement, full homogeneous MERC W, resolved TOD colors, Direct STQ/FST/register/depth/texture identity, retained multi-level terrain and completed MERC/Direct frames pass regressions and fresh normal routes. Correct HUD depth/matrix/color/coverage and Sprite homogeneous interpolation restore intact settled menus. Recorded jump/forward/reverse/release shows Jak moving relative to fixed landmarks; no full I1 acceptance while visible defects remain. Detailed history: recovery review and `evidence/I1/recovery-{stale-terrain,merc-menu}-2026-09-12.md`.
- **Signed KERNEL now works in the app.** Build9ea8a4ca matches installed hash, returns all eight canonical signed tops, binds279 immutable export slots, reaches normal Training and passes recorded controls, fault0. Actual app1426 linked references/codewords also pass; host631/combined-bank657 checks include205 entries, six tagged RW pointers and real process reparenting. Build with `OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-kernel-full.json OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh`; repeat identical variables for shell-only. Exact source/KERNEL-member/generated-cache guards are mandatory. Registry identity is now general: `a11-ordered-activation.patch` removes the loader's last KERNEL names (object-derived release policy, `module_count >= 1` with distinct names and a final `gstate`, generated-array load order) and the generator/harness/manifest guards accept any ordered list, exercised by `config/signed-ordered-control.json` (canonical631/ordered162 PASS). GAME and streamed levels still use research executable pages; the next GAME blocker is no longer emission: data-only members now emit (`a11-data-only-main-segment.patch`, guard `a11_module_emitter.h:98-99`) and all four corpus restrictions pass the host set, so the ordered GAME registry, code-versus-asset name identity and then streamed GOAL-side linking/reload come next; follow `SIGNED_AOT_RECOVERY.md`. The streamed lane is now bounded: the title-village1 route's level code is 14 members of the already-bundled TIT/VI1 (832 KiB text) needing only the two implemented relaxations, so `locate_member`'s KERNEL/GAME-only scan and the loader's value-0 intern are the binding limits, not emitter coverage or a missing container (`.log` addenda 2-3). Fail-closed fix shape (2026-09-14, host-only read-only): resolve symbol slots through `find_symbol_from_c` - a genuine non-creating lookup whose miss path is `find_symbol_in_area` falling through to `find_symbol_in_fixed_area` (`kscheme.cpp:991-997`, `:962-971`) - and `require(sym.offset, ...)` instead of interning at value 0; the five diagnostic names become explicit optional lookups, and Type slots keep `intern_type_from_c` because it does set `symbol->value` and a find-only require there would be wrong rather than safer. Correction: the `#ifdef OTTSEL_IOS` full-table fallback in `find_symbol_from_c` (`kscheme.cpp:1062-1085`, from `r0-call-trace-probe-goalc.patch:421`) is unreachable dead code - every exit of the if/else ahead of it returns - so S1.3 order-independence is structural (the table never deletes) and the fix must not rely on that block; `intern_from_c` also never requires `symbol_slot != 0`. Spec: `evidence/A1/a11-loader-fail-closed-2026-09-14.md`. Fail closed there means the loader aborting with the offending name, not `link()`'s early `return false` (:255 / :258), which `link_and_exec` turns into the legacy executable-page link (`jak1/klink.cpp:936-940`, `:983`).
- **Whole-game signed-code census (A1, 2026-09-14):** read-only reproduction of the emitter over every container member puts the genuine code corpus at 872 members with 381 accepted / 491 rejected and exactly four causes (315 hardcoded type/method whitelist, 96 distance32 ADRP+LDR Q, 76 data-only main segment, 4 pointer target outside static data). The confirmed generalizations are a widened data-side type guard, one validated distance32 consumer class (16-byte SIMD LDR Q), and a widened kind-5 pointer path (`--links`: 1255 data->code pointers, tagged `&7==4`, leaving 11 members after the other two). `--types` shows all 872 code members carry kind-2 records (66154 records over 117 distinct `(name, methods)` pairs) and every one of the 17217 records patching inside signed text (518 members) is `function`/9, so type identity resolves at load through genuine `intern_type_from_c` rather than an invented tag-index table; `--identity` shows the whole corpus is 518 distinct code names that map 1:1 onto loose `.o` files (name is a valid aggregate key, no label collisions); each restriction is enforced in three product-path places (the emitter, `scripts/emit-signed-module-arena.py` from `scripts/build-ios.sh:342` and the runtime `validate_module`), so emitter, generator, runtime checks and the pinned pointer regression change together (`SIGNED_AOT_RECOVERY.md`); `--simulate` predicts 650 then 785/872 and `--relax-all` 872/872 with no residual. Method and numbers: `evidence/A1/a11-whole-corpus-census-2026-09-14.md`, re-run `python3 scripts/a11-corpus-census.py [--simulate|--links|--types|--relax-all|--budget|--identity]`. All four are now implemented and host-verified (872/872 residual 0) but no GAME list is emitted, linked or activated and no product build ran; the disk gate still blocks product work. Extending it (2026-09-14, host-only): the dependency-ordered GAME math control activates through the real link_and_exec (`config/signed-math-control.json` 199 PASS; the data-only/gamedata controls 181/190), and of the four single-member probe crashes the navigate-h abort is a missing `vector` type (parent math+vector-h, 199 PASS), the load-dgo/ramdisk SIGBUS is a null `Symbol::value` (parent rpc-h, 190 PASS each) and gsound's SIGSEGV is a null `ee::iop` boot-scope gap in the host fixture, frame-identical to the 315-member control while the app's `OTTSEL_IOS` shim returns before touching `iop`; what remains product-side is the loader failing to reject an undefined `Symbol::value` that feeds an indirect call. Correction (same day, host-only, `.log` addendum): the 184 names outside KERNEL/GAME/ENGINE are not missing or transformed level code - all 184 are byte-identical code members of the 25 built `out/jak1/iso/*.DGO` level containers, so extending the registry to streamed levels is a `locate_member` scan-scope and bundle-content change, not a new link format. Raw detail: `evidence/A1/a11-whole-corpus-census-2026-09-14.log`.
- **Audio/lifecycle:** pause/open race, sound ownership/spatial dispatch and native bank loading pass focused checks. Real Home/foreground resumes PCM/input; normal route loads COMMON/VILLAGE1/MISTY/TRAINING and plays Training ambient handles, fault0. Actual audibility, dialogue, interruptions, saves/relaunch and held-input cancellation remain open; see `evidence/AU1/recovery-audio-lifecycle-2026-09-12.md`.
- **Pacing remains open.** Simulator300-command-buffer sample has0errors/missing,54.176completionHz and GPUdurationp50.216ms/p953.708ms. These are command timings, never display FPS. Measure presented cadence on a supported surface; retain responsive sustained gameplay evidence.
- Root owns all app/build/runtime work, one Simulator. Subagents own bounded staged source/tests only when explicitly assigned a compiler lane. Current work must close I1/I2, then I3/P1/D1 and reproducible ROM-safe/no-JIT delivery in the ordered gates above. No title/log/host-test shortcut closes the original PRD.
  A1.10 (done 2026-09-22, root-caused + fixed, verified once): the display-loop x19 loss was NOT a clobber inside the function.  The loop-end (suspend) at main+0xbf08 returned into its own continuation main+0xbf0c via thread-suspend's guarded .ret: the slot held 0x00000050ffffffff (a GOAL frame local), the A1.8 window test rejected it, and the fail-safe fell back to the incoming x30 - for an asm-func entered by a GOAL call that is the caller's link register, not the kernel's return address - so display-loop resumed with the kernel's register file (pp=0, x19 = a kernel-stack address).  thread-resume never ran for that dispatch (site trace: it runs for every good dispatch).  thread-suspend reads [*kernel-sp* + 0x50] for its return, which only holds a continuation when the kernel left a synthetic there.  Fix: thread-resume/reset-and-call stash their incoming x30 as the first kernel slot and thread-suspend/return-from-thread/-dead pop it into lr and return with (.jr lr) (a variant that pushed without popping drifted the kernel stack 0x10 per dispatch and overflowed a stack guard - not shipped).  My lldb site-condition conditions were unreliable on hardware breakpoints; the bisection used Python breakpoint callbacks that read the stopping frame.  Verified once: all 15 DGO objects served, level linked, 6131+ display frames at drawn=0 (before: x19 lost within four iterations).  Evidence: evidence/A1/a11-kernel-continuation-slot-2026-09-22.md; overlay patches/a11-kernel-continuation-slot.patch.
  A1.11 (next, one variable): the lane now dies later at the documented A1.1 "GOAL data used as a code target" shape - pc = lr = ee + 0x7fffe10 (the *kernel-sp* symbol slot), pp = 0, fault frame gkernel+0x60a8.  Two clean strict runs are still required before the pp=0 class can be retired.
  A1.11 (done 2026-09-22, root-caused + fixed, verified once): the A1.10 build's new failure was the .ret window, not the stash - the guard's slot held a GOAL *stack* address (ee + 0x7fffe10) and the A1.8 keep-test (slot >> 32 in [1,8]) accepts any host address, so `ret` left the image with pc == lr == x30 and pp = 0 (measured live under lldb: x19 = the address of the string "village-cam", sp = pc - 0x20). The window is now the module block [x22 + 0x8000000, x22 + 0x8c30000), which is the only executable region in this port (the heap, module data, app image and stacks all fall back to the incoming link register); the A1.10 stash stays with the guarded .ret on the suspend side, so a stashed stack address is rejected and the thread-start path falls back to its trampoline. Verified: 8/8 guarded sites carry the new test (byte scan of out/jak1/obj/*.o), the 14-case guard regression PASSes including the measured stack escape, and a fresh strict run loads all 15 DGO objects and keeps the display loop alive. Evidence: evidence/A1/a11-ret-window-stack-2026-09-22.md; overlay patches/a11-asm-ret-fail-safe.patch.
  A1.12 (next, one variable): close the objective's pp=0/data-target class - signed gkernel text at gkernel+0x55e4 does `ldr w,[x0,x22]` with x0 = 0x5f746c75 (a static string read as a GOAL object). Chase the producer of that object (the loader/execute-process-tree path that hands a string where an object belongs), then two clean strict runs.
  A1.12 (next, one variable): the post-A1.11 blocker is named precisely - `execute-process-tree` (gkernel entry 0x54a4) faults at entry+0x140 with `ldr w1,[x0,x22,sxtx]` and x0 = 0x5f746c75 (ASCII "ult_"); its pool/lambda walk reads its object from `*(x24+ee+0x10)` while x24 (GOAL s3) holds the *return address* of the indirect call at entry+0x104, x19 holds *kernel-context* and pp = 0. So callee-saved GOAL registers come back from that indirect call as the call's continuation/context (the same shape the September-22 note recorded for x19/x23), which is a save/restore imbalance across the call rather than a missing prologue save. Chase that callee's register-frame balance, then a source-level fix + a regression and two clean strict runs.
  A1.12 (in progress, frame-level ground truth in hand): the pp=0 data fault is inside `execute-process-tree` (gkernel entry 0x54a4) at entry+0x140 with `ldr w1,[x0,x22,sxtx]` and x0 = a data word. Its prologue saves x19/x23/x24/x25/x30 and maps arg0->x24, arg1->x19, arg2->x23. At the fault the prologue's SAVED slots are intact but the entry values are already nonsense (arg0 = s7+8, arg1 = *kernel-context*) and gkernel+0x5640 repeats through the deeper frames, i.e. a deep chain of recursive activations entered from the call at entry+0x19c. So the walk is handed wrong arguments before it starts (the recorded 'rotated argument group' shape), and the producer is upstream of the faulting frame. Next: trace the argument setup of the recursive site and the first activation from `call_goal_on_stack_asm_arm64` in `signed_gstate::link`, fix the producer, add a regression, and get two clean strict runs.
  A1.13 (producer found 2026-09-22, fix not yet landed): the pp=0 data fault's rotated argument group comes from the A1.10 stash - `thread-resume` pushes six kernel slots but `thread-suspend` pops five and returns through the guarded .ret, so the kernel resumes with sp = entry_sp - 0x10 and the kernel stack drifts 0x10 lower on every suspend/resume. After minutes of dispatches the kernel frames shift, `execute-process-tree`'s recursion is entered with rotated arguments (measured live: ET#1..#3 correct - pool/func/context - then ET#4 with x0=0, x1=*kernel-context* in the func slot, x2=the previous arg0), and it dereferences the bogus object. Fix: keep the stack balanced - either pop the sixth slot and jump through a module-block-validated value, or drop the extra push and have thread-resume/reset-and-call write x30 over the caller's synthetic slot at [entry_sp] - plus a regression over the emitted epilogues, then two clean strict runs.

2026-09-22 (A1.13, LANDED - the kernel stack is balanced): the three suspend-side asm-funcs (`thread-suspend`, `return-from-thread`, `return-from-thread-dead`) now pop the resume side's sixth (A1.10 stash) slot into x30 before the guarded `.ret`, so sp lands exactly on the caller's resume point instead of 0x10 low; the stash doubles as the `.ret` fallback. Regression `scripts/verify-kernel-continuation-slot.py` checks the source tails and the emitted `gkernel.o` (exactly three guarded `.ret` sites preceded by `ldr x30,[sp],#16`); overlay `patches/a11-kernel-continuation-slot.patch` regenerated.
2026-09-22 (A1.14, ROOT CAUSE FOUND AND FIXED - the kernel stack was shared with C->GOAL activations): the post-A1.13 fault was `pc = lr = fault addr = ee + 0x7FFFE10` (the initial kernel stack top) with SIGBUS right after `served obj 1 (oracle)`. Held at the fault and read live: x16 = x30 = that stack address (the guard's fallback), x9/x10 = the guard's module-block bounds, x11 = x12 = 0 (the slot was rejected), sp = the resume point, `[sp] = 0x00000050ffffffff` (a GOAL frame local) and the stash one slot below = a stack address; `*kernel-sp*` = ee + 0x7FFFD90, so the kernel's six resume slots live at [ee + 0x7FFFD90, ee + 0x7FFFDF0]. The kernel's stack (kboot's goal_stack) and every C->GOAL activation (klink's `link_and_exec`, the signed loader) anchor at the SAME top-of-EE address, and the deep signed villagep-obs type/method install (~0x1e0 bytes of frames) ran while the kernel was suspended and overwrote those slots, so the suspend side popped garbage and the `.ret` followed its fallback into the stack. Fix: kboot anchors the kernel 64 KiB below the top (`kActivationStackReserve = 0x10000`) so activations own the top of EE memory; overlay `patches/a11-kernel-stack-separation.patch`, guard `scripts/verify-kernel-stack-separation.py`, evidence `evidence/A1/a11-kernel-stack-separation-2026-09-22.md`.
2026-09-22 (A1.14, VERIFIED - two clean strict runs): both runs have a 0-byte fault log, serve all 55 village1 DGO objects, reach `LINKBEGIN: name=oracle` + `SIGNED MODULE ENTER/RETURNED` + `signed took oracle`, balance 346 ENTER = 346 RETURNED, and report `scene-level='village1'` (cam-accepted 4138/3373, 0 rejects, merc-submits 10525/9684, eichar=4) with `DIRECT FRAME ... drawn=44` and `SPRITE FRAME ... drawn=23`; screenshots of both runs show the title screen with its rendered village background. The pp=0/data-target class (G1.18) is retired for the strict lane. NEXT (I0/I1): route and level-ownership acceptance - title -> New Game -> Village1 -> Training with real input - then the renderer items (per-batch ALPHA 0x48 additive clouds, then dynamic eyes), I2 audio/lifecycle/saves, I3 frontend, P1 iPhone and D1 devices. Visible gameplay, audio and lifecycle are NOT yet claimed; the host build shares the kboot change and has not been re-run there.


## September 22 (evening) execution update - macOS/iOS parity loop (L0-L6)

The strict signed-GAME crash class is closed (A1.13/A1.14), so this round targets the two things the
iPad lane still gets obviously wrong: it does not load the game the way the macOS lane does, and it does
not run at speed.  The macOS lane (`out/jak-project/build/h1/game/gk`, the M0 reference) is the oracle
and has to be rebuilt, healthy and measured before any parity claim.

Measured this round:
- **iPad cadence: 9 fps.**  The game's own vsync counter advanced 180 frames in 20 s of wall time
  (re-measured after A1.14).  The app is otherwise healthy: 0-byte fault log, `scene-level='village1'`,
  ~92% of one core busy, title screen rendering.
- **iPad frame cost (`sample`, main thread):** ~41% of the busy time is the present path
  (`ottosel_metal_present` -> `presentRGBA:` -> `MTLSimTexture replaceRegion` -> a *synchronous XPC
  round trip into MTLSimDriver* plus the frame memmove), ~30% is the loop's 60 Hz budget
  `SDL_SYS_DelayNS`, the rest is game/renderer work.  Uploading a whole RGBA frame (16 MB at iPad
  drawable size) on every present is the single biggest lever.
- **macOS lane: unbuildable, then broken.**  The checked-in `gk` was a stale Aug 23 binary and the lane
  could not be rebuilt from the current source at all: the ARM64 trampolines need eight
  `ottsel_cbridge_*` diagnostics that only the iOS shell and the test harness defined (`Undefined
  symbols: _arg_call_arm64`).  Fixed in A1.15.  The rebuilt lane boots the kernel, links 216
  top-levels, then faults in the `IR_AsmRet` guard (`sig=11`, the guard fallback `x16` outside the
  module window, `si_addr` in the host mapping) and stalls with only the audio thread alive.  The same
  fault is in the Aug 23 binary, so it predates A1.13/A1.14: the oracle is broken, not merely slow.
- **Structural difference:** the macOS lane draws the world with the upstream GPU renderer (OpenGL);
  the iPad lane draws through the shell's own Metal path *and* uploads a full CPU RGBA frame per
  present.  Parity claims must compare like for like (same route, same frame, same counters).

**L0 - measurement harness (both lanes, no behaviour change).**  Question: can each lane report
presented cadence and phase wall-times from its own log in one command?  Exit: a documented per-lane
command that yields frames/s over a fixed wall window plus the phase timestamps (iPad:
`OTTSEL SUBMITSTAT ... vsync=` sampled over N seconds; macOS: the equivalent frame counter, added as a
bounded `lg::info` heartbeat if the host has none).  Evidence: one bounded document with both lanes'
numbers, same machine, one lane running at a time.
Done 2026-09-22: the macOS lane logs `OTTSEL HOSTFRAME: frames=... wall_s=... fps=...` once every 300 rendered frames from `OpenGLRenderer::render` (per-frame callee of `GLDisplay::render`), overlay `patches/a11-host-frame-heartbeat.patch`; the iPad lane still reports `OTTSEL SUBMITSTAT ... vsync=`.  Same machine, one lane at a time: macOS **59.9 fps** steady over a 90 s run (0 crash dumps, 348 top-levels, title reached) against the iPad strict lane's **6.6-6.75 fps** (270 frames per 40-41 s in the title/village window).  Evidence: `evidence/A1/macos-lane-frame-heartbeat-2026-09-22.md`.

**L1 - the macOS oracle is restored (A1.16 done; L0 heartbeat done).**  Question: why does the macOS lane fault in
the `IR_AsmRet` guard during boot while the iPad lane boots to the title on the same emitted objects?
Exit: the macOS lane reaches the title with a 0-byte fault log and a live frame counter, sharing the
same objects and guards as the iPad lane; then re-run the Stage 0 named checks and the lane's own route.
Solved 2026-09-22 (A1.16): the guard's single window was the iPad signed arena band `[x22+0x8000000, x22+0x8c30000)` (ARENA_SIZE 128 MB, module code at offsets >= arena_size) while the macOS lane runs all GOAL code from `[ee+0x3ebc000, ee+0x4ee0000)`, so every guarded `.ret` there rejected its real return value (measured slot 0x7003ed79b4, keep 0) and fell back into the middle of a GOAL function; that is what produced the deterministic `gkernel+0x6d54` fault whose frame held `x24 = &EnableMethodSet`. The emitted keep-test is now two bands (either lane), the overlay and the 21-case harness are in step, and the objects were re-emitted with all 8 guarded sites carrying both bands. Measured after the change: macOS lane 3 runs / 0 crash dumps / 348 top-levels / `title-wait-ready` / pad reads with `has-display=true`; iPad strict lane 2 runs / `ottsel-fault.log` 0 bytes / 346 ENTER = 346 RETURNED / `signed took oracle` / `scene-level='village1'` / title screen rendered. Evidence: `evidence/A1/a11-ret-guard-two-band-2026-09-22.md`. L0 followed (both lanes now report their own cadence: macOS 59.9 fps, iPad 6.6-6.75 fps), so this gate is closed and L2/L3 are next.

**L2 - clock and loading contract.**  Question: is the iPad lane's game clock tied to its frame rate, so
9 fps means game time, loading progress and input all run ~7x slow?  Measure frames/s plus the game's own
time counters on both lanes, then the wall time of each loading phase (boot -> title, title DGO serve,
level link, level active).  Exit: the lane runs its intended cadence (or a stated, stable cadence) with
the game clock consistent with it, and the boot-to-title and load-phase wall times are within a stated
factor of the macOS lane.
Answered 2026-09-22 (L2, measured on both lanes): the game clock is not tied to the frame rate.  `read_ee_timer()` is the host monotonic clock (`ns*3/10`) and `display-frame-start` advances `base`/`game`/`part-frame-counter` by `int(time-ratio)*time-factor`, so wall rate is 300 units/s.  Measured with the new clock fields on both heartbeats: macOS 59.9 fps / game-base 300.0 units/s / time-ratio 1.000, iPad strict lane 4.74-10.0 fps (mean ~8) / game-base 299.6-337.5 units/s (mean ~316) / time-ratio samples 4.000, with 346 ENTER = 346 RETURNED and 0-byte fault logs in both iPad runs.  So the iPad lane is choppy, not slow: at ~8 fps each presented frame advances ~4-8 frames of game time, which is where the step-size and input-granularity questions live (100-200 ms sampling; `scaled-seconds` is not clamped).  Loading is ~3x, not ~9x: process start to an active `village1` was ~3 s on macOS against ~8-10 s on the iPad lane.  Still open for this gate: a shared boot->title wall-time marker (the host probe is file-triggered from the shared settings directory, which the iPad container never sees).  Evidence: `evidence/A1/game-clock-and-load-phases-2026-09-22.md`.

**L3 - iPad frame-time parity (present path first).**  Question: which single change to the present path
removes the per-frame synchronous upload/XPC stall?  Candidates in order: stop uploading a full RGBA
frame when the GPU path already drew the scene; present from a persistent shared staging surface instead
of re-uploading per frame; drive the frame budget from measured work instead of a fixed 60 Hz sleep.  One
variable per run, measured with L0.

**L4 - visible correctness parity (same frame on both lanes).**  Baseline measured 2026-09-22 on the running iPad lane (`sample <pid> 3`, 1630 samples): the main thread spends 864 samples in `SDL_SYS_DelayNS`/`nanosleep` (waiting for the next chain), **420 in `ottosel_metal_present` -> `presentRGBA:` -> `MTLSimTexture replaceRegion`, 190 of them inside the synchronous XPC round trip** (`sendXPCMessageWithReplySync` -> `xpc_connection_send_message_with_reply_sync` -> `mach_msg2_trap`), and ~346 in game/renderer work; across all threads the weights add `_platform_memmove` 26, `access` 37 (per-chain trigger-file probes) and stdio writes (per-chain diagnostics), so probes and logging are also in the frame budget.  The game/EE thread did not separate in that sample.  Candidates in order: the per-chain `access()` probes, the per-chain verbose logging (keeping the bounded heartbeats), then the present path itself.  First experiment 2026-09-22 (content-addressed sprite texture cache, one variable): **refuted** - reusing an uploaded `MTLTexture` when the incoming pixels are byte-identical measured 2.84/2.90 fps against the baseline's 5.40/5.74 in the same `vsync` 181..451 window, and reverting restored 5.51/5.74, so in this simulator a texture the in-flight frame still references costs a hazard wait that a fresh texture per call never pays.  Reframing: `MTLSimTexture replaceRegion` is the simulator's XPC upload path, so simulator fps understates device cadence; the largest single XPC was the *frame* upload (16 MB per present): that change landed 2026-09-22 - the present path now computes `cpu_base_wanted` once per frame from the same policy that gates the base draw and skips the texture creation, the upload and the draw together, which moved the main thread's `presentRGBA:` frame from 268 to 54 `sample` samples with the cadence unchanged (the main thread was 53% idle) and the visuals and fault log untouched.  What is left for the frame *rate* is the game thread: 1528 of 1630 samples in `send_gfx_dma_chain`, `render_mobile_sprite_group0` 552, `appendSpriteMeshNow` 410 - cross-frame sprite texture reuse is refuted, so the sprite path was measured next: it performs ~13-15 uploads and ~13 MB per frame and 92-95% of those bytes repeat an upload earlier in the same frame, yet a frame-scoped dedup in the renderer (hash plus reuse within one frame, no cross-frame sharing) was **withdrawn** - it broke the sprite pipeline (`drawn=0`, the atlas path 7x less often, the lane degrading) - so this renderer tolerates neither cross-frame nor intra-frame texture sharing.  The attribution then paid off: the World2D product-group atlas was packed per call but always uploaded as a full 512x512 (1 MB) region while carrying 1-6 64x64 tiles, so the atlas is now sized to the rows it uses (`uv[1]` deferred and re-normalised by the used height), which measured **8.18 / 6.92 fps against ~5.5 before** in the same window with the visuals, drawn counts and 0-byte fault logs unchanged.  Next single change: the HUD atlas site got the same treatment (its path did not run in the title window, so it stays landed-but-unverified until a HUD-bearing scene draws it), and the World2D atlas is now sized on both axes (64x64 .. 320x64 instead of a flat 512x64), which measured 7.71 / 6.75 fps - unchanged within the run-to-run spread, i.e. the texture upload is no longer the frame bottleneck.  What remains is the CPU side (send_gfx_dma_chain 1528/1630 samples), so the next single change inside the sprite path is to recycle textures on command-buffer completion (mirroring the vertex-buffer pool) - the re-profile puts the per-call texture allocation at 111 of 1594 game-thread samples - and after that the non-sprite DMA/bucket walk (875 samples, 55%), with the route blocker below taking precedence for the product goal.  The game thread's own spread is `send_gfx_dma_chain` 1528/1630, of which `gfx_send_chain` 715 and the sprite upload 410, with the rest in the DMA walk and bucket dispatch.  Evidence: `evidence/A1/l3-sprite-texture-cache-refuted-2026-09-22.md`.  Then the known renderer items:
per-batch ALPHA 0x48 additive clouds, dynamic MERC eyes, HUD/menu material, compared as matched captures.

Attempted 2026-09-22 and blocked one step in: the maintained driver scripts/replay-ios-normal-route.py waits for 'OTTSEL INPUT: pad0 sample buttons=0x0', a marker the current shell no longer logs (triggers now log 'ottsel BOT22: latched <button> tap (file trigger)' on stderr), and driven by hand with --console-pty the shell latched 7 of 7 taps while the frontend never left screen=27.  has-display=false is normal on this lane in every build held, so the blocker sits between the latched key and the game pad.  Evidence: evidence/A1/l5-route-attempt-and-reprofile-2026-09-22.md.

Environment blocker (2026-09-22): a fresh app container dies during boot with an uncaught ghc::filesystem::filesystem_error naming .../OttselShell.app/iso_data/SBK - build-ios.sh stages only DGO/TEXT into the bundle (ROM-safe by design) while ios_boot.cpp needs the user pack families (CGO DGO fr3 MUS SBK STR TEXT VAG VIS), and a missing family is an uncaught exception rather than a named error.  The lane was recovered 2026-09-22 without new user data: the extracted data was still in the repository's gitignored out/jak-project/iso_data/jak1 plus the derived fr3, scripts/prepare-user-data-pack.sh rebuilt a 1.5 GB pack, and staging its missing families into the bundle after the build restored a clean boot (346 modules, title, 0-byte fault log).  The rule is that the bundle needs the build's own DGO/TEXT plus the pack's missing families; overwriting the built DGO/TEXT with the pack's originals boots to 332 modules and then crashes with a held fault.  Route probes then decoded the current build: pad bits are 0x8 START (SDLK_RETURN), 0x4000 Cross (SDLK_SPACE) and 0x40 DpadDown (SDLK_DOWN); a Cross hold at the wheel returns to the title, so one menu item per run must be probed with >= 1 s of neutral pad between presses; and level='village1' in the camera-entry lines is the title screen's own live backdrop rather than a New Game.  Route driving then worked with the hold triggers: title -> 3 s START hold -> the main menu wheel over village1 (screenshots in /tmp), while the August item order (cross, 4x down, cross) returned to the title, so what is stale is the menu model, not the plumbing.  Injected input is now proven end to end (pad samples show buttons=0x8 START then 0x0), so what is left for the route is the frontend transition that the driver's stale expectations cannot see.  The packaging gap is now understood and half closed: the supported path is the app own F1 import (a validated pack in Documents/OttselUserData is promoted into a durable container copy and the build-generated TIT/VI1 DGOs and TEXT are overlaid on top), scripts/import-ios-user-data.sh <udid> [pack] performs it and was verified end to end (title in 20 s, 346 modules, 0-byte fault log, 1560 MB durable copy), and because the durable copy lives in the container a rebuild no longer wipes the lane data; what remains is making a fresh install with no imported pack report the missing family by name instead of terminating with an uncaught ghc::filesystem::filesystem_error.  This session wiped the staged families with a rebuild and the container's promoted copy with a simctl uninstall, so the iPad lane needs the user's data restaged before any further iPad measurement; the macOS lane is unaffected.  Evidence: evidence/A1/ios-lane-user-data-dependency-2026-09-22.md.

**L5 - route and input on the iPad lane.**  Title -> New Game -> Village1 -> Training with real input at
the L2 cadence; then I2 audio/lifecycle/saves, I3 frontend, P1 iPhone, D1 devices in the existing order.

Rules unchanged (`AGENTS.md`): one booted Simulator at a time, diagnostics bounded and stored under
`/tmp`, one concise evidence document per proven gate (maximum 60 lines), at most eight appended STATUS
lines, never `git add -A`.  Every source edit gets a narrowly scoped overlay - the coverage guard
enforces that at path level, so hunk-level coverage is an open L1 item.

## September 22 (night) execution update - G2 acceptance goal loop

This is the current loop; it takes over from the L0-L6 parity round above where that round's items
repeat.  `PROJECT_COMPLETION_PLAN.md` still supplies the stage definitions, `AGENTS.md` the runtime
rules, and `00-phase1-brief.md` / `05-roadmap.md` the original product goal, which is unchanged:
honestly playable native Jak 1 on iPad first, then iPhone parity and physical-device readiness, signed
ARM64 AOT, no runtime code emission, legal user data, asset-free delivery.

Entry state (measured on this source, not inherited): the strict signed lane boots, reports
346 SIGNED MODULE ENTER = 346 RETURNED, resolves `scene-level='village1'`/`training` and draws title
and in-level frames with a 0-byte `ottsel-fault.log`; the touch-only route reaches Training; per-class
touch defaults, safe-area clamping and the layout-editor round trip are landed on iPad and phone; the
macOS M0 lane boots with its own frame heartbeat.  Playability is NOT claimed: audible output, the
renderer material defects and physical devices are open.

G2.1 I2 state fidelity - DONE 2026-09-22 (was the board's `NEXT`).
  Question: does a save written from inside a level restore the state it recorded after a relaunch?
  Answer, plus a correction: the save stores a continue point and run counters, not a transform, so the
  board's "compare the position" method was invalid.  An in-level save (pause wheel -> CIRCLE -> SAVE
  GAME) wrote `bank2.bin` recording `training-start`; after terminate/relaunch, slot 1 loads straight
  into training with `CAMERA START: cp "training-start"` while slot 0 (`title-start`) routes title ->
  village1 -> training with cp `game-start`.  The loaded continue point is the string the slot's own
  save recorded, so the state comes from the save, not from a level default.  Tool
  `scripts/verify-ios-save-continue-point.py`; evidence `evidence/A1/i2-save-state-fidelity-2026-09-22.md`.
  Next fidelity increment (not a blocker for this claim): a second save after real mid-level progress,
  because the measured counters track the run clock rather than progress.

G2.2 L4 renderer parity - next, re-scoped 2026-09-22 after a premise check.
  Closed as stale: the per-batch ALPHA 0x48 Sky-cloud item.  On the accepted source the Sky batch draw
  block never executes in a full title/Village1/Training run (`SKYLOOP` and `SKYBOUNDFRAME` counts are
  0 while that block's own per-frame records are in the source), so an additive `directBlendPipeline`
  variant would be unverifiable, and the composite that does run is already replace-then-add
  (`metal_gfx.mm:4838-4849`).  Evidence: `evidence/A1/g2-sky-batch-path-inert-2026-09-22.md`.  The
  open question there (the decode reports `submitted=2` yet the published store reads empty) is its own
  bounded probe, not a blend change.
  Measured 2026-09-22 (both items below, one build, three runs; overlay
  `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions): **item 1 is
  answered and its premise is refuted.**  A ledger inside `OttselMobileDirectFrame` plus one bounded
  eight-line `SKYSTORE` record at the pass' `_skyFrameStore.snapshot()` site shows every publish
  reaching the snapshot the pass consumes (`append=2/40/40/34` -> `publish=1` -> `snapshot=2/40/40/34`,
  `rollback=0 empty-publish=0 empty-replace=0`), so no clear ever overtook a submitted population: the
  Sky batch block has been running all along, and the earlier `SKYLOOP`/`SKYBOUNDFRAME` count of 0 was a
  log-channel artifact (`NSLog` records live in the unified log, `ottsel-runtime.log` carries only
  `lg::info`; same run: port log 0/0 against unified 24/3).  **Item 2's ledger is measured too:**
  re-armed per scene-level selection and read over a routed run that reached `scene-level='training'`,
  a first four-batch sample read 0x44 and the exhaustive per-population histogram that replaced it
  corrected that reading: the textured cloud tiles carry GS ALPHA **0x48** (additive) and only the
  untextured full-screen strips carry 0x44 (source-over), the Direct text/logo batches report register
  0 (no ALPHA_1 in the bucket, and the register was not even carried until this round), and 199 of 200
  live TIE draws request AlphaBlend preset 1 with preset 2 (the additive enum) never requested.  So the
  additive population the loop was looking for is live on this lane and the Sky site was drawing it
  source-over.  Evidence:
  `evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md` and
  `evidence/A1/g2-live-blend-register-ledger-2026-09-22.md`.  Item 1 needs no renderer change (none was
  made).  The stale premise-check document
  `evidence/A1/g2-sky-batch-path-inert-2026-09-22.md` is superseded on its "block never executes" point.
  Landed 2026-09-22 (same overlay, four further runs): the decode, the additive pipeline state and the
  register-driven Sky selection are in source.  `src/shell/mobile_blend_policy.h` decodes a/b/c/d(+fix)
  into the six combinations the desktop handles (plus `Unsupported`, with a zero register as
  `Unspecified`), `bash scripts/test-mobile-blend-policy.sh` passes 12/12 on the host, and the Sky site
  selects `directAdditivePipeline` (rgb SrcAlpha/One/Add, alpha One/Zero) for the 0x48 population.
  Matched capture on a static Training camera in one run with the gate flipped: the sky region reads
  85.9/88.2 mean under source-over against 110.5/111.7 under the register-driven additive state, the
  diff confined to that region (47.2% of its pixels > 24, mean|delta| 50.5/channel), and visually the
  sky strip is black against light blue.  **Root cause corrected the same day** (see
  `evidence/A1/g2-sky-draw-source-2026-09-22.md`): bucket 3 is upstream's `SKY_DRAW`, and its
  `SkyRenderer` is a `DirectRenderer` that draws only when the tag after its 64-byte setup packet is
  `qwc == 5` (the live `OTTSEL SKY SHAPE` ledger confirms `payload-qwc=4 payload-size=64
  after-setup-qwc=5`), sampling the **64x96 sky texture the SkyBlend handlers composite** (buckets
  32/39) - a composite this lane does not implement.  Drawing those quads therefore samples the
  uncomposited relocated source while the port's own sky composite already draws the sky, and with the
  live additive registers (32x32 cloud tiles 0x48) the double-draw became a vivid rainbow.  They are
  now **skipped by default** (`drawn=skipped`; matched pair `disc/new-9.png` clean against
  `disc/old-9.png` rainbow), a fresh default process logs no sky draw records at all, and the
  register-driven selection is unconditional (it is inert here until the composite exists).  Two
  earlier readings are retracted: the `qwc != 8 -> tfrag-trans` branch belongs to `SkyBlendHandler`
  (buckets 32/39), not bucket 3, and the sky texels are real sky-source data (`OTTSEL SKY TEXEL`),
  not garbage.  Next: port the SkyBlend composite and draw bucket 3 from its result; behind it the
  Direct site's blend decision (its register is carried but never selected on) and the TIE preset-2
  question remain.  Evidence: `evidence/A1/g2-sky-additive-blend-2026-09-22.md` and
  `evidence/A1/g2-sky-draw-source-2026-09-22.md`.
  Next, in order, one variable per run and each measured before it is changed:
  1. Bounded per-frame log of the Sky batch store's begin/publish/snapshot state to name where the two
     submitted strips are lost.  If they are meant to draw, that is a real missing-fan defect; if not,
     delete the dead path rather than blend it.
  2. Bounded ledger of the blend modes live sites actually request - TIE's `draw.mode >> 24` collapses
     the additive enum value 2 into the source-over pipeline (`metal_shell.mm:1796-1808`, predicate in
     `mobile_scene_policy.h:120-124`), and the Direct/sprite sites carry `diagnostic_alpha`.  Then land
     the GS/DrawMode equation decoder (both packs are two-bits-per-field in the port's own headers) plus
     additive pipeline states **only at the sites the ledger proves**, with a focused regression on the
     decode and a matched before/after capture.
  3. Dynamic MERC eyes (bucket 54 composes four quads into a persistent 128x128 texture; publish as its
     own earlier encoder in the same command buffer, keyed by `MercDraw.eye_id`), then HUD/menu material.
     **Stage 1 landed 2026-09-22** (`evidence/A1/g2-merc-eyes-bucket54-decode-2026-09-22.md`): bucket 54
     is `MERC_EYES_AFTER_PRIS`, and upstream's `EyeRenderer` decodes a 128-byte GS offset packet, a
     32-byte alpha setup, a NEXT/NOP and then, per eye slot, an ADGIF (iris TEX0) + background + iris L/R
     + pupil L/R + lid L/R, each draw a 32-byte scissor plus a 96-byte sprite.  The composition window is
     GS 512..1024 at four units per texel (`shaders/eye.vert`), so
     `target_px = (xyz - eye_offset)/4 - 128`; the target starts as the iris page's (0,0) texel, iris and
     lid are copies, only the pupil blends, and the result loads at `8160 + slot` (which is how
     `Merc2.cpp:1175`'s `eye_id == 0xff ? tree_tex_id : (0xefffff00 | eye_id)` resolves).
     `submit_mobile_native_eye_bucket` now decodes that chain and composes 128x128 RGBA per slot on the
     CPU, with `ottsel-trace-eye-dump` PPM dumps; it binds nothing, so the visible eyes are unchanged.
     Measured against the real packets: the ADGIF addresses are exactly TEX0_1/TEX1_1/MIPTBP1_1/CLAMP_1/
     MIPTBP2_1, the rects remap into the target as the oracle predicts, and the three layers resolve from
     the registered 16x16 PSMT8 pages (`iris tbp0=0x276f psm=19 cbp=0x279f registry=1`).  The pupil page
     decodes as a clean soft disc; the iris page shows speckled blocks and the composite is blocky
     (nearest sampling against the oracle's LINEAR).  Next in order: bilinear sampling; settle whether the
     iris page's speckles are data or palette by comparing it with the page the MERC eye draw samples
     today (slots 323/324); then bind the composed slot into the `eye_id != 0xff` draws, which is the step
     that changes what the player sees.
     **Stage 2 landed 2026-09-23** (`evidence/A1/g2-merc-eyes-bind-2026-09-23.md`): the composed slots
     are now bound.  `MercDraw::eye_id` is `(pair << 1) | is_r` (`Tfrag3Data.h:553`), so it indexes the
     composed slots directly; `mobile_eye_texture_base()` reserves 40 texture slots out of
     `g_mobile_next_texture_base` (no collision with a level's range), the bucket-54 consumer composes
     every pair it walks into `g_mobile_eye_images[pair*2 + lr]`, and the MERC draw builder overrides the
     draw's texture index for `eye_id != 0xff`, re-uploading the composed 128x128 only when it changes
     (a blink moves the lid band).  Measured: `OTTSEL EYE BIND: model=eichar-lod0 eye-id=0x0 slot=0
     texture-index=1689` and `eye-id=0x1 slot=1`, plus the sidekick's slots 2/3, while the level texture
     the eye used before is a 4x4 flat blue-grey page.  Visually Jak's eye now shows a light-blue iris
     with a dark pupil and a skin-coloured lid band.  **The rim speckles were then fixed in the same
     round:** the composition had preferred the *relocated-registry* copy of each palettized eye page, and
     that copy carries garbage palette colours (saturated green/magenta rim texels, which
     `ignore-alpha=true` let show).  Upstream resolves an eye layer through the level's texture pool by
     TBP0, so `mobile_eye_source` now tries that route first (the page's metadata `combo_id` ->
     `g_mobile_pool_textures` -> the level's own texture); `OTTSEL EYE SRC: ... path=pool` and the resolved
     page is a clean blue iris disc, with the eye reading as white sclera + blue iris + dark pupil on Jak
     and white sclera + dark pupil on Daxter.  The composition then covered **all 20 pairs with per-pair
     change detection** (the walk was capped at two pairs; a pair is recomposed only when its layer
     textures or rects change, so steady state is one comparison: `OTTSEL EYE CHAIN: pairs=2 slots=4
     composed=2`, then `composed=0`, then `composed=1` on a blink).  Still open: there is no
     desktop-capture A/B for the whole eye, and one frame showed a transient white cloud-like overlay
     that its neighbouring frames do not (unattributed; the reserved eye slots cannot alias another
     consumer's indices).
     **HUD/menu material opened 2026-09-23** (`evidence/A1/g2-hud-material-decode-2026-09-23.md`): the
     game's HUD sprite groups do reach the port - 48 sprites/288 vertices and 32/192, a populated atlas
     (`atlas-rgb=23785/40960`), nothing skipped, a permissive draw state (GEQUAL, no depth writes, alpha
     test GEQUAL at 2/128, scene depth clear 0.0) and an HUD ndc-z of 0.995 - yet no HUD shows in the
     in-level captures.  Per-sprite clips show a full-screen 4.7%-alpha fade quad plus large panels, and
     the group's clip x reaches 13.95.  The desktop-faithfulness hypothesis (`sprite_3d.vert`'s
     `scales.w = scales.z`, i.e. upstream scales both bases by the sy-derived value where the port uses
     sx) was measured and refuted as the cause - the sampled sprites have sy > sx, so the quirk widens x,
     and it stays behind `ottsel-trace-hud-desktop-scale` rather than landing.  Next: isolate the
     in-level HUD frame itself (all 24 logged groups share one timestamp, so the sampled groups are the
     intro/loading panels), then instrument the sprite draw path if the quads still do not land.
     Follow-up the same day narrowed it: with a per-second record the HUD groups appear throughout the
     level (one every ~18 vsyncs, `vsync=934` ... `1133`, all `scene-level='training'`), the shell encodes
     them (`Sprite3 native draw vertices=288 blend=enabled texture=hit`), and the largest-atlas dump shows
     the real HUD content (face-button icons, eco shapes, Daxter's head).  Forcing the vertex alpha to 1
     changes nothing on screen and the store-clearing legacy path is gated off here, so the remaining
     split is "off-screen geometry" versus "rejected fragments" (a texel alpha of 0 at the sampled uv) -
     the next measurement is a HUD fixture that replaces the clip corners with a known corner quad.
     The fixture ran (`OTTSEL HUD FIXTURE: active`, corner quadrant at z=0.995, opaque, atlas centre) and
     painted nothing, alone or together with a gated overlay-depth control
     (`ottsel-trace-sprite-overlay-depth`).  That control is the first thing that changed what the pass
     paints: with sprite batches drawn under the overlay (ALWAYS/no-write) state, long thin strips appear
     over the bridge/rock area - live sprite geometry (the World2D set, sharing the pass with the HUD) is
     being rejected by the GEQUAL depth test because its z is farther than the world's where it draws.
     Next: log the first vertex of the batch the shell is about to submit (the buffer is shared storage),
     which decides whether the fixture reaches the GPU at all; the World2D strips are also recorded as
     their own defect.
     That read-back landed: every atlas-sized batch the shell draws is world space (e.g.
     `tex=384x64 n=288 v0=(-5.375,44.424) uv=(0.000,0.000) q=25.500 z=0.0006`, or `q=445.682 z=-0.0978`),
     so the HUD's appended batch never reaches the draw although the HUD path reports 23 submitted groups
     in the same run.  The two blockers are now separated: the World2D batches are drawn and rejected by
     the GEQUAL depth test (hence the overlay-depth control painting them as strips), while the HUD's
     quads are not drawn at all - and their depth (0.995, behind most world pixels) would have passed.
     Next: instrument the sprite store's size right after the HUD append and again at the pass' snapshot,
     to place the HUD's entries (never appended, appended then erased, or a store the pass does not read).
     That instrumentation corrected the reading: sampling one batch per second had hidden the HUD - with
     every batch of one pass logged, the HUD's atlas batch is present (`store=72 idx=7 tex=384x64 n=288
     v0=(-5.399,43.544) q=25.500 z=0.0006`) and the producer side records `tex=320x64 n=288 store=1` with
     the store size swinging 1..72.  Its effective depth is `z/q = 2.4e-5` - the near plane - so the pass'
     GEQUAL test against the world discards it, exactly as it discards the World2D strips, while other
     HUD groups carry 0.995 and would pass.  The root cause is therefore the sprite depth derivation
     (`final_position.z / 16777216` with the selected `hud.hvdf`/`user_hvdf` offset folded into `base`),
     not the HUD's geometry or its store path.  Next: log the first sprites' matrix index, offset
     components and pre-multiply depth against the desktop's own inputs.
     That landed and sharpened it again: the per-sprite `hud.user_hvdf[matrix-1]` offsets carry z ~
     8.36-8.37M, `base.z` ~ 16.7M and a pre-multiply depth ~0.995, and the pass-side read-back (filtered to
     the HUD's q band) confirms the stored vertices (`store=68 idx=8 tex=320x64 n=288 v0=(74.5,259.6)
     q=255.026 z=0.9931`), i.e. `z = pre-depth x clip-w` exactly as the code writes - so the rasterizer
     sees `z/q ~ 0.001-0.004`, the near end of the port's [0,1] range, for the quads that land on screen
     while other groups sit at 0.995.  The remaining variable is therefore the *world's* depth convention
     against the Sprite3 pass' GEQUAL/no-write test over a scene cleared to 0.0 - the same state that hides
     the World2D population.  Two earlier readings of my own are retracted as sampling artifacts (logging
     one batch per second): "the store reads empty" and "the HUD's batch never reaches the draw".
     Done 2026-09-23, and it refutes the depth explanation: the census shows the HUD's atlas batches *are*
     drawn (`tex=384x64 n=252 q=263.223 z/q=0.99536`), the world's own Metal depth is 0.068..0.956
     (`ndc-z=(-0.8645,0.9120)` for village1) against the HUD's near-end 0.9952..0.9959, and the quads that
     miss the screen carry `xyz.x=245760` in their own record - the closed pause screen parked about seven
     screens right.  The gated `ottsel-trace-sprite-atlas-fill` redraw paints eight white cells in the
     menu's own slots once the menu is open, so the material is drawn and the in-level absence is the
     closed menu, not a fragment or depth rejection.
     Verified 2026-09-23 with a matched *unfilled* capture of the open pause menu: the menu renders with its
     material (icons on their panels, GEYSER ROCK / 0% / OPTIONS), the gated white fill was covering working
     cells rather than empty ones, the zero-alpha atlas cells are TCC=1 and transparent by design (the
     upstream forced-alpha-1 rule applies only when TCC=0), and the settled title is clean - the glyph
     lattice in its first seconds is a transient opening state and the solid blocks are this harness's own
     touch overlay (1x1 texture, removed under native input).  So this sub-item owes no product fix: the
     material path draws what the game submits, and with no menu open the only in-level population is the
     closed progress screen plus its dimmer.  Evidence: `evidence/A1/g2-hud-material-decode-2026-09-23.md`.
     Landed the same day: bucket 3 now draws from the SkyBlend composite by default (the producer already
     builds the 32x32/64x64 buffers; the old default skipped the fan from before that producer existed).
     Matched same-run A/B at one camera: `drawn=as-sky` renders a blue sky where `drawn=skipped` renders
     black, differing on 22455 pixels confined to the sky box with mean |delta| 121/channel and lane health
     unchanged.  Control: `ottsel-trace-sky-skip-draw`.  Evidence:
    `evidence/A1/g2-sky-blend-default-draw-2026-09-23.md`.  Next in the renderer lane: the Direct site's
     `evidence/A1/g2-sky-blend-default-draw-2026-09-23.md`.  Both blend questions behind it are closed the same
     day by live ledger measurement: every sampled TIE draw selects preset 1 and the additive enum is never
     requested, and every Direct batch carries register 0x0 (`Unspecified`), so neither needs a renderer
     change.  The sky bucket's generic (non-sky-draw) window is a measured defect rather than a candidate -
     processing it turns the settled title into a full-frame triangular mosaic (71.720% of pixels) where the
     default shows the composite sky, and in-level it moves only 0.673% inside the sky box - so rendering the
     TRANS/LOWRES_TRANS tfrag trees it contains is the next renderer item, then the composite registration key
     (psm 0) and the eye item's desktop A/B.
  Exit: each defect has a production regression, a matched capture and no regression in the other paths;
  an isolated fixture alone does not close it.

G2.3 I2 audibility.  Question: is real game output audible on a supported surface with the correct
  event association?  PCM is already non-zero and banks load, so the Simulator driver workaround or the
  device lane decides it; callback and peak counters do not pass.  Exit: ambient/effects, music and
  dialogue heard and tied to actual game events, plus interruption and held-input cancellation.

G2.4 I3 frontend completion.  Question: does every rewired control and setting behave in play and
  persist after relaunch and across lifecycle transitions?  Landed: per-class defaults, safe-area
  clamp, editor round trip, class keyed on `UIUserInterfaceIdiom`.  Remaining: the settings entries
  (Gameplay / Controls / Video / Audio / Data & Saves / Diagnostics) with working behavior and
  persistence, controller handoff, accessibility labels.  Trigger-file input does not satisfy this gate.

G2.5 P1 iPhone parity re-run.  Question: do the accepted route, the save/load sequence of G2.1 and the
  system checks hold on the phone profile with the new layout?  The phone already boots, routes to
  Training and logs `class=phone` with its safe area; an older 667x375-point profile still needs its own
  check.  Sequential: stop the iPad lane first, then re-check shared regressions on iPad.
  Done 2026-09-23 for that profile (iPhone SE 3rd generation, 667x375 points, `class=phone surface=667x375
  min-region=37x43 safe-lrtb=0x0x0x0`): with the accepted user data imported it passes title -> NEW GAME ->
  CONTINUE WITHOUT SAVING -> Training (`village1` then `training`, 346 ENTER = 346 RETURNED, 0-byte fault
  log) and its save menu draws the copied save metadata without clipping.  Without imported data the same
  binary never reaches `title-wait-ready` and loops on `ndi-intro` (2638 warnings), which is the G2.6
  question answered in the negative.  Left open on this lane: the sky fan draws unresident first frames on
  a fresh phase (its own item), and the save WRITE path is still only verified on iPad.

G2.6 Stage 7 packaging and import.  Question: does a fresh asset-free install fail helpfully by naming
  the missing user-data family instead of dying in an uncaught `ghc::filesystem` error, and can the
  product be reconstructed from the documented pin/patches?  Then the allowlist package inspection.
  Partial 2026-09-23, measured on the phone lane with its data absent: the *log* half passes - `OTTSEL F1`
  names every missing family (`bundle data at <bundle>.app/iso_data is incomplete (missing: CGO, fr3, MUS,
  SBK, STR, VAG, VIS); import a user pack with scripts/import-ios-user-data.sh`) and nothing dies with an
  uncaught filesystem error - but the *screen* half does not: the shell's status screen (the DATA line plus
  the log tail) is drawn and never presented while the game renderer owns the layer, so the user sees a
  grid of unresident tiles and the app spins on `ndi-intro` (921 warnings).  Two gates that made the status
  screen render in that state were landed, built and captured with no visible effect, so the fix is to
  composite the status screen inside the product pass (or suppress the game's presentation without a user
  pack); the gate stays in source as the prerequisite.  Reproduction: install into a container without
  `OttselUserData` (an install rotates the data container, which produces exactly that state).  The
  reconstruction and allowlist halves are untouched.  Second attempt the same day, also landed and also
  invisible: an in-pass status texture (`ottsel_metal_set_status_overlay`, drawn right after the touch
  overlay) reproduced the identical frame, which refutes the first note's "never presented" reading -
  `ottsel_metal_gfx_game_frame()` is a stub returning 0, so the shell always presents its own surface.  The
  flat-colour probe then ran: the data-less screen turns uniformly green and the run logs
  `OTTSEL STATUS: surface=667x375 font-scale=3 flat-probe=1`, so the status surface does reach the layer -
  but both candidates upload `g_rgba`, so the probe names no presenter.  Reading the presenter then found the
  mechanism: `presentRGBA:` is the single presenter and it skips the CPU base once the level meshes are ready
  (`ottssel_mobile_cpu_frame_should_draw`), which a data-less boot satisfies.  Keeping that base when
  `!ottsel_ios_has_user_data()` and pushing the in-pass overlay (both landed; the overlay logs `set 667x375
  vertices=6`) still leaves the same grid.  A magenta-fill probe then proved the overlay draw *does*
  rasterise (the screen turns uniformly magenta), and at original resolution the presented tiles are
  letter-shaped glyphs of ~40x56 px repeating in a lattice rather than the status lines - so the shell's
  status surface content is the defect, and its geometry is suspect too (`surface=667x375` against this
  phone's 750x1334 drawable).  One real bug was found and fixed on the way: the Direct batch loop never
  restored the per-batch GS scissor, so every later full-screen overlay draw was clipped.  The surface dump
  then settled it: `surface.ppm` (667x375) holds the status screen itself - header, green line, the yellow
  DATA line, log rows - so `render_surface()` and the F1/DATA reporting are correct and only the mapping onto
  the layer is wrong (the capture is 750x1334 while the shell surface and its reported drawable are both
  667x375).  ANSWERED YES the same day, and the defect was the shell's own font: `draw_char` read the
  column-major `font5x7.h` row-major, transposing every glyph and reading two bytes past each (the "lattice
  of letter tiles" the captures showed all along).  With `kFontW` 5 / `kFontH` 7 and the loops swapped, the
  same surface dump reads `ottsel S2.0 - Metal` / `GPU path: Metal` / `DATA: import OttselUserData in Files`
  plus the log tail, and the device capture shows the same legible lines - so the screen half of this
  question passes too, and the shell's whole text surface is legible for the first time.  Remaining in this
  gate: reconstructing the product from the pin/patches and the allowlist inspection; the bundle-fallback
  diagnostic path is unchanged, and the log tail is dominated by repeated DIRECT/SPRITE FRAME lines.

G2.7 D1 physical devices.  Build/sign the device target, install on iPad then iPhone, and re-run
  launch/import/gameplay, audio/interruption, held-input cancellation, save/relaunch, pacing and soak.
  Simulator signing does not establish this; when provisioning is missing, record the exact gap.

One maintenance item that blocks cheap verification: `scripts/replay-ios-normal-route.py` still waits
for `OTTSEL INPUT: pad0 sample buttons=0x0`, a marker the current shell no longer logs (triggers log
`ottsel BOT22: latched <button> tap (file trigger)`).  Refresh it to the markers the shell does emit
(`TITLE: start edge`, `accept screen=`, `GAMEPLAY: enter`) so the route is one command again.
## September 23 execution update - G2 save write, and the route driver's slot path

The G2 lane's save write is measured now instead of assumed, and the "the slot accept writes nothing"
story was a harness defect, not a product one.  The frontend's save screen is the writer:
`save-game-title` (18) sends a slot that already holds a save to the overwrite dialog (11), whose yes/no
row defaults to NO and which only the D-pad LEFT/RIGHT handlers answer, and the second accept enters
`memcard-saving` (13), where `enter!` issues `auto-save-command 'save` (`progress.gc:279-287`).  Every
earlier attempt answered that dialog with `ottsel-hold-dpad-left`, a file name the shell never reads
(holds are `ottsel-hold-{start,cross,left,right,up,down}`, `src/shell/main.cpp:1288-1298`; `dpad-left` is
only a touch region), so the dialog stayed at NO and no file changed.  `scripts/replay-ios-normal-route.py
--accept-slot 0` now drives the whole sequence on a fresh launch with the documented env, so the route is
one command again and the maintenance item above is closed: it wrote `bank0.bin` on the iPad
(`6b8040a7...` -> `a3599ea8...`), `bank1.bin` on a repeat run, and `bank0.bin` on the phone
(`526cfe06...`), with 346 SIGNED MODULE ENTER = 346 RETURNED and 0-byte `ottsel-fault.log` throughout.
The repeat landed on a different file because each save *file* is double-buffered over banks `2N`/`2N+1`
(`game/kernel/common/kmemcard.cpp:240-282`), which also corrects the verify tool's old slot-to-bank line.
The same driver reads the files back (`--load-slot N`): slot 1 loads `cp "training-start"` and slot 0 - the file written this round - returns to the title and starts its level with `cp "game-start"`, the documented `title-start` shape, so the write and the read agree per slot.  Evidence: `docs/evidence/A1/g2-save-write-2026-09-23.md`.  Still open in G2.1/G2.5: a save after real
mid-level progress (the in-game pause has no save rows of its own), plus the unchanged audibility and
physical-device gates.

### In-game save (G2.1's last increment, 2026-09-23)

The pause is an entry point, not a dead end: it has no option rows of its own (it activates
`progress-screen fuel-cell` and draws the level's task list), but `respond-progress` pushes
`progress-screen settings` (3) outright on CIRCLE (`progress.gc:1128-1135`), and screen 3 is bound to the
main options table whose index 4 is `save-game`.  The harness had never pressed CIRCLE because the shell
exposes no hold trigger for it, so the new `scripts/probe-ios-ingame-save.py` answers the pause through
`ottsel-touch-circle` - the finger path an iPad player uses.  Measured in one run: a held left stick moved
the target 71343.1 units (pad-max 1.0), then the pause -> settings -> SAVE GAME -> slot -> overwrite dialog
-> YES chain wrote `bank0.bin` with save_count 5, continue-point `training-start` and counters equal to the
lane's own `game-base=311565`, at 346 = 346 modules and a 0-byte fault log.  Evidence:
`docs/evidence/A1/g2-ingame-save-2026-09-23.md`; the save-path map's "the in-game pause cannot save" section
is corrected with it.  Still open: audibility, the renderer items, frontend settings, and devices.

### G2.2 items 1 and 2 closed by measurement (2026-09-23)

Item 1 is not a defect: the sky batch store begins, appends and publishes with
`published-batches == snapshot` (40, then 34), `empty-publish=0`, `rollback=0`, and keeps the previous
snapshot on frames where the producer does not run, so no strip is lost - and the same run logs `SKYLOOP`
72 times, `SKYBOUNDFRAME` 9 and `SKYFRAME` 334, which supersedes the 2026-09-22 sky-batch-path-inert
reading on this source.  Item 2 needs no code: the sky population requests 0x44/0x48 only (`other=0`) and
every additive-keyed batch is already drawn additively (32/32), the TIE population asks for preset 2
(additive) in 0 of 600 draws, and the Direct population writes no ALPHA register at all, so no additive
state is owed anywhere; the decode stays covered by `scripts/test-mobile-blend-policy.sh` (PASS 12/12).
Evidence: `docs/evidence/A1/g2-blend-ledger-and-sky-store-2026-09-23.md`.  The same run also corrects the
carried-forward sky item: the fan's own line reports `drawn=skipped` (57 title-window samples) against
`drawn=as-sky` in-level (67), so the fan is not what fills the title's sky - and at the title a no-op A/B
6 s apart already moves 62.8% of the sky band, so only an in-level (stable) frame-matched A/B attributes a
path, where skipping the fan moves just 0.25-1.02%.  What is left in G2.2 is item 3 (dynamic MERC eyes) and
naming what fills the title's sky.

### Reconstruction at hunk level, the missing sounds, and one sky hypothesis refuted (2026-09-23)

The coverage guard is path-level, so G2.6's reconstruction question needed the hunk level: the new
`scripts/verify-overlay-hunks.py` reverse-applies every live overlay per target root and reports, per
patch, how many later patches touch the same files.  Here 21 of 53 live overlays reverse-apply cleanly, 34
do not - the layered-stack case, the canonical base among them - and the check found one real defect:
`a11-loader-fail-closed.patch` was listed live but its body is rejected as `corrupt patch at line 39`, and
both files it targets are reproduced by other patches, so it is now recorded in the README's malformed
group and the live stack has no unparsable bodies.  A from-scratch build from the pin remains G2.6's open
half.  Evidence: `docs/evidence/A1/g2-overlay-hunk-check-2026-09-23.md`.

G2.3's "missing sounds" lead is closed as a data fact: 2970 of 2977 warnings are one name, `fire-pop`,
which never resolves because it is in none of the 24 SBK files although the game's own data (VI1.DGO,
VI3.DGO, L1.CGO) references it - and the repository's extracted ISO data agrees - so it is a dangling
reference in the shipped data, not a port or pack defect.  The other four missing names are transient
requests before their bank loads.  G2.3's remaining gap is unchanged: a supported surface whose audio
device actually opens.

One earlier hypothesis is refuted: the title's banded/rainbow sky is not explained by a missing composite,
because the producer does run there (`OTTSEL SKY BLEND: produced copies=3 ... vsync=63..66`).  Naming what
fills the title's sky still needs a frame-matched A/B at a static moment plus a sampled-texture dump.

### I3 pressed/neutral feedback (2026-09-23)

The shell's own touch surface is now live feedback instead of a static layout walk: the held set comes from the
same finger state that routes input, a held region lifts toward white and goes near-opaque, and the surface is
rebuilt and re-uploaded only when that set changes (one integer compare per frame when idle).  Verified in data
(the pressed region's own RGBA, alpha 0.18-0.24 -> 0.97-1.00, logged within a 20-line budget) and in pixels
(holding `dpad-up` changes 89.2% of that region's own box and 0.0% of every other region; holding `r1` 97.2%;
the no-input control 0.0% everywhere).  One method note that cost two wrong readings first: the shell's surface
is landscape (`class=tablet surface=1210x834`) while `simctl io screenshot` captures the portrait device frame,
so app-space layout boxes appear rotated by x'=1-y, y'=x in a capture.  Evidence:
`docs/evidence/A1/i3-touch-pressed-feedback-2026-09-23.md`.  Still open in I3: region labels/art, the settings
entries, controller handoff and accessibility labels.

### I3 settings surface (2026-09-23)

The persistent three-dot entry the completion plan names now exists: a `Menu` touch region appended after `R1`
(drawn as three dots, with its own touch trigger), a per-class settings file beside the layout, a screen composed
on the CPU into the surface the shell status screen already uses, and a modal touch handler ahead of the editor
and the game pad that consumes every finger while it is up.  Only entries with behaviour are offered: SURFACE
OPACITY (writes the overlay tint), SURFACE VISIBLE (AUTO/ALWAYS/HIDDEN, driving the upload policy), RESET LAYOUT.
Driven with touch only: open, select row 1, change it to ALWAYS (`saved visible=ALWAYS`), close; after a
relaunch the screen reports `visible=ALWAYS` from `settings-tablet.cfg`, which holds `1` then `1`.  Evidence:
`docs/evidence/A1/i3-settings-surface-2026-09-23.md`.  Still open in I3: the Video/Audio/Data & Saves/
Diagnostics sections, region labels/art, controller handoff and accessibility labels.

### I3 settings sections and the music volume (2026-09-23)

The settings surface now has the plan's shape: a section list, one screen per section, and only sections whose
entries have real behaviour - CONTROLS (opacity, visible, reset layout), AUDIO (music volume), DATA & SAVES
(user pack status and the data root) and DIAGNOSTICS (the shell log overlay); Gameplay and Video wait for a
setting with real behaviour rather than being drawn empty.  The audio row drives the port's own music master
(`snd_SetMasterVolume` group 16) and its effect is measured in the lane's PCM dump: volume 0 gives
`peak=0 rms=0` for all 39 captured seconds where volume 100 gives `rms` up to 4554 in the same window.
Values live in a per-class file beside the layout and survive a relaunch (music 100 -> 80 -> reloaded as 80,
log overlay ON -> reloaded as ON).  Evidence:
`docs/evidence/A1/i3-settings-sections-and-audio-volume-2026-09-23.md`.  Still open in I3: the Gameplay and
Video sections, region labels/art, controller handoff and accessibility labels.

### I3 touch labels (2026-09-23)

The control surface names itself now: a glyph is emitted as one quad per lit pixel of the same 5x7 font the
status screen uses (`STK`, `CAM`, `X`, `O`, `[]`, `TR`, the four D-pad arrows, `ST`, `L1`, `R1`), centred
inside each region's own hit box so drawing and hit-testing cannot drift, brightening with the held state, and
costing only vertices because the overlay samples a 1x1 white texture.  Verified by capture at the title and by
the unchanged feedback contract in-level (holding `dpad-up` changes 73.7% of its own box, 0.0% of every other
region, control 0.0%).  Evidence: `docs/evidence/A1/i3-touch-labels-2026-09-23.md`.  Still open in I3: real
button art, VoiceOver accessibility labels, controller handoff, and the Gameplay/Video settings sections.

### I3 controller handoff (2026-09-23)

The gamepad path was never exercised on this lane, so a bounded virtual-pad diagnostics was added and it found
the defect that blocked controller play: the shell's shutdown release sat inside the frame loop, so a pad was
acquired and dropped in the same pass and no gamepad input ever reached the game.  The release now sits with the
other exit calls, and the frame body re-enumerates once a second while the shell owns no pad, so handoff is
self-healing.  Verified through the virtual pad: the whole accepted route, the analog stick (target moved
66766.5 units at pad-max 1.0), and a detach/reattach cycle after which input still reaches the game.  Physical
hardware remains G2.7/D1's claim.  Evidence: `docs/evidence/A1/i3-controller-handoff-2026-09-23.md`.

### I3 labels on both device classes (2026-09-23)

The labelled surface now fits whatever class it runs on: each label's pixel is derived from its own region, so
the tablet's wide bars and the phone's narrow arms both work (a fixed size overflowed the phone's 0.055-wide
D-pad arms); glyphs are square on screen through the axis aspect; and the overlay is rebuilt when the drawable
size changes, since both the safe-area clamp and the aspect come from it.  Verified on the phone profile
(`class=phone surface=667x375`: labels inside their regions and the settings section list rendering) and
re-checked on the tablet, where the held D-pad cell is still visibly brighter than its neighbours.  Evidence:
`docs/evidence/A1/i3-labels-both-classes-2026-09-23.md`.

### G2.2 title sky: the fan is the sky; the gate relaxation was reverted unproven (2026-09-23)

A same-run A/B with the fan's skip control shows the title's sky *is* the fan (sky strip near-black with it
skipped, blue with it drawn).  The title window also carries the `qwc == 6` form of the same bucket, so the sky
path's `qwc == 5` condition was relaxed to accept it - and reverted, because the un-relaxed build's settled
title sky is already blue (blueish 91.1%), i.e. the earlier banded/rainbow reading is not reproduced here and
the change would have been unproven.  Two method notes: `OTTSEL SKY SHAPE` is racy (one run's samples show both
qwc values for the same bucket start), and sky windows are confounded by the logo.  Next: an early-frame A/B
with a logo-excluding mask, with the skip trigger set before the title's first frames.  Evidence:
`docs/evidence/A1/g2-title-sky-fan-is-the-sky-2026-09-23.md`.

### G2.2 title sky closed on both profiles (2026-09-23)

The fan's skip control, set before launch for the control run and read through a frame-edge strip the control
proves sky-only, shows the same picture on the iPad and the phone: with the fan the title's sky is blue and
drifting to a sunset from the first capture, without it the region is one constant flat fill at every moment.
There is no early window in which another draw fills the sky, so the carried "fan first-frame garbage" reading
is not reproducible on this source and the gate relaxation stays reverted.  Evidence:
`docs/evidence/A1/g2-title-sky-fan-is-the-sky-2026-09-23.md`.

### Stability: fault-site attribution, and the phone fault that will not reproduce (2026-09-23)

A single phone-lane fault seen during the title runs could not be decoded after the fact, so the fault handler
now records the image slide and names pc and lr through `dladdr` (symbol, offset, image) - diagnostic only.  Six
phone cycles alternating the fan-skip control that was set at the time, each reaching the title and dwelling
20 s, produced zero fault bytes with 346 modules (seven clean attempts including the earlier repeat), so the
fault is not reproducible on that route and stays open and unexplained; the next occurrence will name itself,
and its original dump is preserved as `ottsel-fault.log.prev`.  Evidence:
`docs/evidence/A1/ios-fault-attribution-2026-09-23.md`.

### G2.5 phone parity re-run, then the iPad re-check (2026-09-23)

With the labelled surface, the settings entry and the per-class label fit landed, the phone lane was re-driven on
the current build through the touch path alone: the frontend save's overwrite dialog answered YES wrote
`bank1.bin` (`b4e89c5f` -> `2e7f1460`), the post-save flow reached Training, and the touch stick moved the target
(`pad-max` 0.34, displacement (36951, 31793)) at 346 = 346 modules and a 0-byte fault log.  The sequential iPad
re-check wrote `bank0.bin` (`01a8adfd` -> `36d71248`) with the same route, control and health, so the shared
regressions hold on both classes.  Evidence: `docs/evidence/A1/g25-phone-parity-rerun-2026-09-23.md`.

### G2 stability soak on the iPad (2026-09-23)

A bounded soak on the current build: the accepted route to Training, then sixteen 30-second ticks of input through
the shell's own hold triggers with a lifecycle round trip in the middle, sampling input, scene, fault size and
modules per tick.  All sixteen ticks stayed in `training` with a 0-byte fault log (346 = 346 modules), the target
trace spans 4790650 x 3646196 units at pad-max 1.00 from the held sticks, and a stick hold straight after the
background/foreground round trip still reached the game.  Evidence: `docs/evidence/A1/g2-ipad-soak-2026-09-23.md`.

### Phone soak, and the settings surface under load (2026-09-23)

The phone lane was soaked the same way as the iPad - the accepted route to Training, sixteen 30-second input
ticks, a lifecycle round trip - and stayed in `training` with a 0-byte fault log in every tick (346 = 346
modules, target trace spanning 4482456 x 3461459 units at pad-max 1.00).  The same run exercised the settings
surface and the diagnostics row **while the game was running**: the CONTROLS step and the DIAGNOSTICS toggle both
took effect and saved, and the toggle's capture shows the shell's own log surface filling the screen over live
gameplay.  Evidence: `docs/evidence/A1/g25-phone-soak-and-settings-under-load-2026-09-23.md`.

### I3 PS2 button shapes (2026-09-23)

The control surface carries the PS2 reference now: a small shape vocabulary on the overlay's triangle list draws
○ (disc), × (two 45-degree bars), □ (filled square) and △ inside their own face regions, plus the four D-pad
arrowheads - each centred in its region, sized by the region's narrow dimension with the axis aspect folded in so
it is round on screen, and brightening with the held state as the text marks did.  The stick, camera, shoulders
and start keep short text and the settings entry keeps its dots.  Verified by capture on the iPad and the phone,
including a held Cross region with its × lifted.  Evidence: `docs/evidence/A1/i3-ps2-button-shapes-2026-09-23.md`.

### I3 accessibility labels (2026-09-23)

The shell draws its own controls, so UIKit had nothing to name and VoiceOver saw an unlabelled game surface.
A transparent `OttselAccessibilityView` now sits over the Metal view, takes no touch, and answers the
container protocol UIKit uses with one `UIAccessibilityElement` per region - a spoken label and a frame in the
container's own space - published from the same walk that draws the surface and cleared when it hides.  One
correction is on record: the frame must not be Y-flipped (`add_touch_rect` maps a region's y=0 to clip y=+1
and UIKit is also top-left origin), and with the flip the labels sat on the wrong half of the screen.  Verified
on both classes (14 elements each; `Start` at y=62.55 on the 834-tall iPad surface, y=6.75 on the 375-tall
phone) and independently against the screen: the `D-pad up` frame mapped through the capture rotation lands on
the held region (95.4% of its pixels > 235, dark scene just outside).  Evidence:
`docs/evidence/A1/i3-accessibility-labels-2026-09-23.md`.

### I3 Gameplay and Video sections (2026-09-23)

The settings entry names six sections and only Gameplay and Video were absent.  GAMEPLAY now carries CAMERA
SENSITIVITY (scales the touch camera region's drag) and INVERT CAMERA Y, and VIDEO carries RENDER SCALE (the
shell owns the CAMetalLayer, so it scales the drawable the game and every native draw render into).  Both are
measured rather than inferred: the camera hold's own pad sample reads `right=(147,117)` at 50% and `(208,87)`
at 200%, `(208,167)` inverted; render scale moves the surface 1210x834 -> 907x625 -> 605x417 (phone 667x375 ->
500x281 -> 333x187), and the static settings screen's bright-pixel fraction doubles from 0.0234 to 0.0544.  One
correction is on record: VIDEO was first brightness/contrast on the shell's scaled frame and measured as a
no-op on screen - the tone lands on the shell's CPU buffer, not the natively drawn frame - so it was removed.
Evidence: `docs/evidence/A1/i3-gameplay-video-sections-2026-09-23.md`.

### G2.6 reconstruction, measured at file level (2026-09-23)

The forward claim was untested (the coverage guard is path-level, the hunk guard only reverse-applies), so the
README's own recipe was run: a fresh worktree at pin `641fb572e`, then `h3-jak1-host-boot.patch`, then every
other overlay that `git apply --check` accepts (31, in repeated sorted passes).  That reproduces 182 of 193
nested files byte-for-byte; the 11 that differed (395 lines) were working-tree diagnostic and experiment edits
that no overlay had captured, so `patches/g2-working-tree-source-gap.patch` captures exactly that delta and the
recipe now reproduces all 193, re-verified from a second fresh worktree.  File-level only - the reconstructed
build and run remain open.  Evidence: `docs/evidence/A1/g26-reconstruction-file-level-2026-09-23.md`.

### G2.3 audibility: the Simulator blocker is gone (2026-09-23)

The 2026-09-22 reading that the Simulator's CoreAudio open hangs forever does not reproduce: in two
consecutive runs the same build opens the real device (`device=21`, `route='System audio playback device'`, no
`SDL_AUDIO_DRIVER` set) with the callback running.  The captured PCM is 45.01 s of S16 stereo 48 kHz, peak
32768, rms 4913, and every silent second is accounted for (boot, the level-load gap, and the two seconds the
app was backgrounded).  The sound is tied to game events - 19 named PLAYER RPC events across the frontend,
movement, swimming, water, level ambience and a level event - with `Load music village1` for the music, and the
background/foreground pause and resume is visible in the PCM, not only in the log.  Open in this gate: dialogue
(no NPC conversation on the route) and a human listening check.  Evidence:
`docs/evidence/A1/g23-audibility-simulator-open-2026-09-23.md`.

### I3: a stray keyboard event no longer costs the touch controls (2026-09-23)

An in-level acceptance frame came back with no controls drawn.  `ShellPadInput::keyboard()`, `mouse_motion()`
and `mouse_button()` all hide the touch surface through a flag that nothing ever cleared, so one keyboard,
mouse or gamepad event removed the controls for the rest of the run - and the harness's own `ottsel-hold-*`
triggers reproduce it.  A `FINGER_DOWN` now clears that flag, which is what `AUTO` ("follows the input in use")
means.  Same-build in-level A/B, counting the overlay's own tint: 0 pixels after the keyboard hold, 74,595 after
one touch.  Evidence: `docs/evidence/A1/i3-touch-surface-restored-on-touch-2026-09-23.md`.

### G2 acceptance with audio in one run (2026-09-23)

With audio reachable, one process now carries the simulator-side acceptance bar: route to Training (rc 0),
in-level play through the touch path, 346 = 346 modules, 0-byte fault log, `scene-level='training'` 75 times, the
target translating 5.64M x 3.67M units, an 80.00 s PCM dump (peak 32768, 71 of 80 seconds carrying signal) with
`Load music village1`, 27 named sound events tied to the driven input, and stills plus a 25 s video showing live
gameplay with the controls drawn.  Device playability, dialogue audio and a human listening check remain open.
Evidence: `docs/evidence/A1/g2-acceptance-run-with-audio-2026-09-23.md`.

### G2.5 phone parity on the current build (2026-09-23)

Three shell changes landed since the phone was last driven, so it was re-driven rather than assumed: fresh
install, route to Training (rc 0), `class=phone surface=667x375`, `scene-level='training'`, 346 = 346 modules, a
0-byte fault log, Cross at pressure 255, and the target spanning 5,558,057 units.  The new items behave
identically - RENDER SCALE moves the surface 667x375 -> 500x281 -> 333x187 and back, CAMERA SENSITIVITY 50% with
INVERT ON gives `right=(147,137)`, and the touch-surface fix reads 0 overlay pixels after a keyboard hold against
39,559 after a touch - and audio reaches the real device there too (80.00 s PCM, peak 32768, rms 3467, 21 named
events, `Load music village1`).  Device-side parity is still open.  Evidence:
`docs/evidence/A1/g25-phone-parity-current-build-2026-09-23.md`.

### G2.3 dialogue: reachable, and silent for a named port reason (2026-09-23)

The earlier note that the training level has no dialogue hint was wrong (the grep was truncated):
`training-obs.gc:109-129` defines seven hint volumes and driving Jak forward fires them.  The line is silent
because a voicebox plays it as `spool-<name>` and only the desktop `RPC_Player` (`srpc.cpp:313`) strips the
prefix, finds the VAG and plays it - the `#ifdef OTTSEL_IOS` handler (`:104`) drops it to the bank lookup, which
logs `sound missing name=spool-sagevb38`.  The cutscene path is silent for the same reason (`str-play-async`'s
PLAY-STR RPC has no iOS consumer; `current-str-pos` stays -1).  Not a data defect: the voice lines are
`VAG/VAGDIR.AYB` + `VAGWAD.ENG`, absent from all 24 SBK files, and the pieces to play them exist
(`snd_StartVAGProbeShared`, `VagVoice`).  Next: a real feature - a `spool-` branch on the iOS RPC plus a
shell-side VAG service.  Evidence: `docs/evidence/A1/g23-dialogue-ios-vag-gap-2026-09-23.md`.

### G2.3 dialogue: the iOS VAG player landed (2026-09-23)

The gap named last round is closed for the path the level uses: the iOS `RPC_Player` now hands `spool-<line>`
to the shell, and `ottsel_ios_play_vag_dialogue` resolves the name in `VAG/VAGDIR.AYB` (offsets are in
2048-byte sectors - measured), reads `VAG/VAGWAD.ENG`, and starts the engine's VAG voice.  Driving Jak into the
training level's hint volumes now gives `VAG dialogue name='SAGEVB38' ... started=1` and `ASSTVB40 ...
started=1` where the same two lines were `sound missing name=spool-...` before, with no stall and no regression
(346 = 346, 0-byte fault log, music intact, PCM non-silent).  The cutscene `str-play-async`/PLAY-STR channel and
a human listening check remain open.  Evidence: `docs/evidence/A1/g23-dialogue-ios-vag-player-2026-09-23.md`.
### Disk floor hit: the build script leaks a generation per build (2026-09-23)

The dialogue fix was verified on the phone as well (`SAGEVB38 ... started=1`, zero `spool-` misses, 346 = 346,
fault 0), but the install pushed the volume below the repository's floor, so this is where product work stops
until it is reclaimed.  The cause is measured: `scripts/build-ios.sh:321` mktemp's a `modules.XXXXXX` generation
directory and never removes it, so `out/jak-project/out/ios/app/signed-gstate` has accumulated 79 `modules.*` and
3 `aggregate.*` directories totalling 13 GB.  `/` dipped to 38 GiB while the lane was booted (below the required 40 GB) and returned to 45 GiB after
shutdown, so the leak is worth reclaiming rather than currently blocking - and reclaiming is with the user,
since deletion is gated here.  Evidence: `docs/evidence/A1/g23-dialogue-ios-vag-player-2026-09-23.md`.

### G2.3 dialogue: the cutscene channel landed, and two bugs fixed on the way (2026-09-23)

The PLAY-STR channel was only clock-emulated on iOS, so cutscenes advanced without audio; the branch now resolves
the same 8-character name the desktop `RPC_PLAY` does and hands it to the shell's VAG player.  Landing it exposed
two bugs, both fixed: a `char[48]` name copied into a 17-byte local (`__stack_chk_fail` -> SIGABRT in
`sceSifCallRpc`, crash report `OttselShell-2026-09-23-100557.ips`), and a sample buffer freed while a long cutscene
line was still decoding (`snd::Voice::DecodeSamples`, a 38,728-byte fault log).  The exact five-play sequence that
faulted now runs with a 0-byte fault log and reaches Training (346 = 346).  Overlays: `g23-ios-vag-cutscene.patch`,
regenerated `g23-ios-vag-dialogue-shell.patch`.  Evidence: `docs/evidence/A1/g23-dialogue-cutscene-vag-2026-09-23.md`.

### G2.3 dialogue: stop handling (2026-09-23)

The stream RPC's stop (`result 1`) ends a spooled line, and the lane logs five stops against three plays, so the
cutscene hook ignoring it would leave narration playing over whatever comes next - what skipping a cutscene does.
`snd_StopVAGProbeShared` (a hard `Voice::Stop` in the sound shim) is now called from the iOS stop branch through
the shell.  Verified: 5 plays / 5 stops, `scene-level='training'`, 346 = 346, 0-byte fault log.  Evidence:
`docs/evidence/A1/g23-dialogue-cutscene-vag-2026-09-23.md`.

### G2.3 audibility: a correction, and an open question (2026-09-23)

The AUDIO row called `MUSIC VOLUME` drives the synth **master** (group 16): with it at 0, two runs - one reaching
Training with its level ambience - were pure silence (120.00 s and 115.00 s, peak 0).  The row is now labelled
`MASTER VOLUME`, verified through the settings screen.  That also confounded the dialogue A/B this round intended,
so dialogue audibility stays unproven: the lines resolve and the engine accepts the voice (`started=1`), but the
narration has not been shown to contribute signal to the mix.  Next: a per-call off-switch plus an aligned
cutscene-window comparison at full volume, or a voice-level meter.  Evidence:
`docs/evidence/A1/g23-audio-master-volume-and-dialogue-audibility-2026-09-23.md`.

### G2.3 dialogue: the voice works, and the stop is per-stream (2026-09-23)

The VAG probe armed at boot (nothing else playing) proves the voice: `SA3INTRO` produced PCM peak 30836, non-silent
7/9 seconds, through the same `snd_StartVAGProbeShared` the dialogue uses.  The stream stop is now per-stream - one
shared token for play and stop, and the shell stops only the line that is playing (`stop ignored` otherwise),
mirroring the desktop's `StopVAG`.  New: the game plays **and stops each cutscene line in the same second**, while
the training hints get no stop and play in full - so the cutscene narration is cut short by the game, and that is
now its own open question.  The narration's share of the mix is still unmeasured.  Evidence:
`docs/evidence/A1/g23-dialogue-voice-works-and-stream-stop-2026-09-23.md`.

### G2.6 allowlist package inspection (2026-09-23)

The built bundle is 61 MB and is exactly the shell binary, Info.plist, the signature, the two CGOs, the two built
DGOs and 48 built TEXT files - no ROM families at all.  Its DGO/TEXT are the build's own, proven by hash: same
names, different bytes from the extracted ROM's (`TIT.DGO` `7421fc02...` vs `7226f8e0...`, `VI1.DGO` `ccbce309...`
vs `9300242a...`, `0COMMON.TXT` `d28eb00a...` vs `2defc222...`).  The player's data lives in the app container
(the Files import), never the bundle.  Evidence: `docs/evidence/A1/g26-allowlist-package-inspection-2026-09-23.md`.

### G2.3 audibility: a real music volume, and the dialogue measured in the mix (2026-09-23)

`SetMusicVol()` drives groups **1 and 2** for music; group 16 is the synth master, which is why the AUDIO row muted
everything.  `apply_music_volume` now scales 1 and 2, and with the row at 0 the mix stays alive - 90 s, peak 16383,
rms 951, **79/90 non-silent** against 0/120 and 0/115 before.  Muting the music also made the dialogue measurable:
the training hint lines raise the mix's per-second rms from a ~200-800 ambience baseline to **6179, 4731, 2629,
2495** at the exact second `SAGEVB38` starts, staying elevated for the length of each line.  So the narration is in
the output.  Open: a human listening check, and why the game stops the cutscene lines immediately.  Evidence:
`docs/evidence/A1/g23-music-volume-and-dialogue-in-mix-2026-09-23.md`.

### G2.6: the status screen was covering the game (2026-09-23)

A screenshot showed the shell's own log/status surface over a running game.  A bounded `OTTSEL DATA: status` line
showed `has-user-data` oscillating (state 2 -> 3 -> 2) because `select_ios_iso_data_dir()` reset the flag at its
start and runs again mid-run while a pack is re-imported; the status overlay is uploaded inside a branch whose
clear is skipped once the scene is live, so it stuck.  Only the fallback clears the flag now.  Verified: no
state=3, and the screen reads mean 59.7/dark 0.04 (game) against 34.4/0.84 (status screen).  The overlay-clear
still lives inside that branch - the defensive follow-up.  Evidence:
`docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.

### G2.6 status-screen residual closed (2026-09-23)

`status_overlay_active` is hoisted out of the branch that uploads it, and the overlay is cleared after that branch
whenever it is still up with the data present and the scene live - so a late upload can no longer stick over the
game.  A normal run is unchanged (`1 -> 0 -> 2`, screen mean 60.7, 346 = 346, fault 0); the new branch's trigger
is the fixed bug, so it is a guard, not a fix.  Evidence:
`docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.

### G2.6 aftermath: visible evidence re-established (2026-09-23)

With the status screen no longer covering the game, a fresh route shows the screen changing with the game and an
in-level frame that is the game itself (mean 60.8 / dark 0.03 against the status surface's 34.4 / 0.84); the frame
lacks controls only because the route drives with keyboard triggers, and one touch restores them (90,133 overlay
pixels).  Open from the same thread: whether the intro cutscene plays its intended sequence.  Evidence:
`docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.

### G2.3/G2.6: the intro cutscene does not play (2026-09-23)

Answered with the display fixed: the cutscene's level loads and draws, but its sequence does not - a capture right
after New Game is a close-up of rock geometry with no camera, actors or HUD.  The port's `STALL-ART` trace names it:
the spool buffer holding the cutscene's part is `locked` with owner `sequenceA-village1` (the title's own village1
sequence), so the part never reaches `active`, the wait spins and the sequence aborts - which is also why its audio
lines are played and stopped in the same second.  The existing `OTTSEL SPOOL RECOVER` does not cover a `locked`
buffer.  Next: release the buffer when the intro takes over, or widen the recovery - the game's spool-ownership
contract needs reading first.  Evidence: `docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.

### G2.3: the cutscene stall is a stale spool-owner handle (2026-09-23)

The contract was read - a buffer promotes from 'locked to 'active only when `(not locked?)` and `(handle->process
load-file-owner)` - and the dead-owner fix was tried and did not fire.  The new `owner-alive` trace is decisive:
the owner resolves to `#<invalid object #x1>`, not `#f`, so the game's promotion never runs and a `not
handle->process` guard never matches.  The root is the stale handle lookup, not the spool.  Evidence:
`docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.
