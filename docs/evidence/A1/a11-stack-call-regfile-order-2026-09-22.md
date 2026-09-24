# A1.7c-fix - _stack_call_arm64 restored GOAL's registers from the wrong slots
(2026-09-22, live, two runs)

Status: fixed at the source with a strengthened regression; verified in two strict runs.
The rpc-h/gsound null-object fault is gone and the boot advances to a later, different
fault.  No playability claim.

## Symptom (the gate A1.9 left open)
The strict signed-GAME lane died deterministically inside rpc-h `call` at seg0 +0x8b8
(`str w23, [x16]`, x16 = ee + 0xC) - a null-object field write on the readable-but-
unwritable low page.  x19 (obj) was 0 while x23/x24/x25/x26 were also 0.

## Root cause (measured)
At the fault the frame's own prologue save is intact: [sp+0x60] (the slot
`str x19, [sp, #-0x10]!` wrote at entry) held 0x1549300, a live rpc-buffer-pair, while
live x19 was 0.  The only call between the last correct use of x19 (data+296 slot read,
(-> obj rpc-port)) and the faulting store is the `blr` that invokes `rpc-call`
(engine/ps2/rpc-h.gc:141).  rpc-call is a C extern (jak1/ksound.cpp:
`make_stack_arg_function_symbol_from_c`), so it enters through the export-bank
`stack` stub -> `_stack_call_arm64`.

`_stack_call_arm64`'s prologue pushed the A1.7c GPR block (x19,x23,x24,x25,x26,x27,x28)
*after* the A1.7c vector block (q15,q14 / q13,q12 / q11,q10 / q9,q8), but its epilogue
still popped the vectors first.  Every pop therefore read the wrong 16/32-byte slot:
x19-x28 were restored from the vector save area and v8-v15 from the GPR slots.  (The
`_arg_call_arm64`, `_call_goal_asm_arm64`, `_call_goal8_asm_arm64` and
`_call_goal_on_stack_asm_arm64` sequences are exact reverses; only `_stack_call_arm64`
was wrong.)  Decisive: the A1.7b counter recorded in=out=0x1549294 for the last call
(no leak), because it samples x19 either side of `blr` - the corruption happens in the
epilogue after the counter.  A1.10 (pre-interning slot names) fixed the gsound slot
value but not this; the fault was identical.

## Fix and regression
The GPR block now sits immediately after `stp q15, q14, [sp, #-32]!` in
`_stack_call_arm64`'s prologue, so the pop sequence is the exact reverse of the push
sequence.  Source out/jak-project/game/kernel/asm_funcs_arm64.s; overlay
patches/a11-goal-bridge-regfile.patch regenerated from pin 641fb572e + h3 + vector +
synthetic-return; `scripts/verify-asm-synthetic-return-patch.py` reconstructs the file
byte-for-byte (sha256 4a76368454d2efb4f8ca978cfa043449616923ed1e79bf5adcbacbcffbec99fb).
A presence-only check missed this, so `scripts/test-goal-bridge-regfile.py` now
simulates the stack offset by offset and requires every pop to read the slot its push
wrote: FAIL with 13 named mismatches on a pre-fix copy, PASS on the fixed tree.

## Verified (two runs, same code)
Both runs report 337 signed modules RETURNED, 32 `LINKBEGIN` (signed took static-screen,
title-obs, villagep-obs; legacy fallback tpage-1609/416/415/397/1499, logo,
logo-black/cam/volumes, ndi, ndi-cam/volumes, title-vis) and end at the same new fault.
The A1.7b counter again reports the true C-side violations (42 leaks in 7208 calls,
target jak1::method_set) instead of 4 in 1933, i.e. the earlier low count was itself a
symptom of the corrupt epilogue.

## Next gate (G1.17)
The next deterministic fault is a return/branch to 0x50ffffffff (pc = lr = x30 =
0x50ffffffff, region-host, no GOAL offset).  The surviving frame chain is
`signed_gstate::link` -> `call_goal_on_stack_asm_arm64` -> signed `villagep-obs` +0xfe4
-> signed `gkernel` +0x6128 -> `jak1::method_set` -> `arg_call_arm64` ->
`jak1::intern_type_from_c`, i.e. the villagep-obs type/method-install path that G1.1 and
G1.15 also pointed at.  Keep the trampoline guard, its regression, the A1.7b counter and
the A1.9 probe; chase the bad return target next, then two clean strict runs before this
class is retired.
