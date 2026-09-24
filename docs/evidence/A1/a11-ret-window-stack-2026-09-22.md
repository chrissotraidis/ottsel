# A1.11 - the .ret window accepted a GOAL stack address (2026-09-22)

Gate: the strict signed-GAME lane's remaining bad-call-target/pp=0 class, plus the regression the A1.10
stash exposed.

Question: after A1.10 (thread-resume/reset-and-call stash their incoming x30 as the sixth kernel slot,
and the suspend-side asm-funcs return through the guarded .ret) the display class was gone and the loop
ran 6131+ frames, but the run then died on the *boot* thread with pc == lr == ee + 0x7fffe10 (a GOAL
stack address), x20(pp) = 0, and x19 = the address of the string "village-cam". Which test let that
through?

Measured (fresh run, ee = 0x100c40000, held under lldb at the fault):
- EXC_BAD_ACCESS at pc = 0x108c3fe10; x22 = ee, x20 = 0, x21 = s7, x30 = lr = pc, sp = 0x108c3fdf0
  (so pc == sp + 0x20), x19 = 0x104110ac8 which reads as the ASCII bytes "vill" "age-" "cam".
- The stack around sp: [sp] = 0x00000050ffffffff, [sp+0x10] = 0x181674 (the village-cam Symbol address),
  [sp+0x20] = a stack address, and 0x108c3fe10 also sits at [sp-0x10] and [sp-0x30].
- So the guarded .ret read a slot holding a *host stack* address, the A1.8 window test (slot >> 32 in
  [1, 8]) accepted it because every host address has a high half in [1, 8] there, and `ret` left the image.
- A thread-resume breakpoint showed x30 at its entry is the kernel continuation in this lane, so the
  A1.10 stash is populated; the escape is the *window*, not the stash.
- Bytes of the freshly built objects: all 8 guarded sites (aligner 1, gkernel 6, gstate 1) carry the new
  test, and the old A1.8/A1.6 word forms (mov x10,#0 / lsr x17,x17,#32) are gone (byte scan of
  out/jak1/obj/*.o).

Fix - two source changes:
- goalc/compiler/IR.cpp (IR_AsmRet::do_codegen_arm64): the keep-test is now the *module block*
  [x22 + 0x8000000, x22 + 0x8c30000) instead of "high half in [1,8]". The signed modules and the legacy
  CGO code both live there (~0xc205c0 bytes of emitted modules), while the GOAL heap (0x13fd20..0x3db0000),
  the module data (ee + ~0x3xxxxxx), the app image/stubs and every stack sit below it, so they fall back
  to the incoming link register - which is what a C-entered, trampoline-entered or thread-start .ret wants.
  Overlay patches/a11-asm-ret-fail-safe.patch regenerated pin->current (verify-asm-ret-guard-patch PASS).
- goal_src/jak1/kernel/gkernel.gc: the A1.10 sixth-slot stash stays (thread-resume and reset-and-call push
  their incoming x30 as the first kernel slot), but the suspend-side asm-funcs are back to five pops plus
  the guarded `.ret` - with the tighter window the guard keeps the stashed *module* continuation when it is
  real code and rejects a stashed stack address, so the thread-start path falls back to its trampoline
  instead of jumping into the stack. Overlay patches/a11-kernel-continuation-slot.patch regenerated.

Regression: test/a11_asm_ret_guard_test.cpp now mirrors the new sequence and takes ee as an argument; it
requires a module slot (ee+0x8018000, ee+0x8810000) to be kept, the low bound to be inclusive and the high
bound exclusive, and the measured escapes - ee+0x7fffe10 (the A1.11 stack address), the module-data slot
ee+0x3db9940, the heap slot ee+0x13fd20, an app-image address, 0x181674 and 0x50ffffffff - to fall back,
including the "no address invented" cases with a zero link register. bash scripts/test-a11-asm-ret-guard.sh
PASS (14 cases) and the module scan still reports the guarded sites load their mask from the slot.

Verified: goalc (mi) exit 0 after rebuilding libcompiler.dylib (cmake --build build/h1 --target
ottsel-a11-slice); the strict build exit 0. A fresh strict run serves all 15 DGO objects (title-vis last),
links the level, reports OTTSEL TEX REMAP and keeps the display loop alive (drawn=0 frames) where the
A1.10 build died in a stack-guard region.

Open (next): the lane is back at the documented G1.18 blocker - executing signed gkernel text at
gkernel+0x55e4 with pp = 0 and x0 = 0x5f746c75 ("ult_", a static string read as a GOAL object), i.e. the
A1.1 "GOAL data used as an object" class in the loader/execute-process-tree path. Two clean strict runs
are still not achieved, so the objective's pp=0/data-target class stays open.
