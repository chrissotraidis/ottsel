# A1.8 - the .ret fail-safe kept a GOAL frame local as a code address (2026-09-22)
(2026-09-22, live, three runs)

Status: fixed at the source with a regression; verified in three strict runs.  The
ret-into-data fault at the oracle serve is closed and the lane advances to a later,
different fault.  No playability claim.

## Symptom
After A1.7c-fix the strict signed-GAME lane ran 337 signed modules, 32 LINKBEGINs,
signed top-levels for static-screen/title-obs/villagep-obs, and then died immediately
after `OTTSEL DGO RPC: served obj 1 (oracle, 66859 bytes)`: EXC_BAD_ACCESS with
`pc = lr = x30 = 0x50ffffffff`, region-host, no GOAL offset.  The A1.7b counter read
calls=7208..7268, leaks=42, i.e. the C-call path was healthy.

## Root cause
The A1.1 .ret fail-safe selects between the slot at [sp] and the incoming x30, and its
test was "keep the slot when its high half is nonzero" (every address this port executes
is at or above 0x1_00000000).  At the oracle serve the slot held a GOAL frame local,
0x00000050ffffffff: low half 0xffffffff, high half 0x50.  The high half is nonzero, the
guard kept it, and the following `ret` left the image.

Decisive measurement (lldb, stopped at the exact fault): `x16 = ottsel_module_main_s0_code
+ 0xBF0C` - the guard's own `x16 = x30`, i.e. the incoming link register, which is the
valid continuation pushed by the caller's call shim.  Writing `pc = lr = x16` and
continuing advanced the boot past the fault to a new one, so the fail-safe's fallback is
the correct return for this site.

## Fix and regression
The guard now keeps the slot only when its high half names this port's executable window,
[0x1_00000000, 0x9_00000000) - app image, __GOAL modules, export-bank stubs, host stack
and shared cache all sit at high half 1.  `IR_AsmRet::do_codegen_arm64`
(goalc/compiler/IR.cpp) emits, after the A1.6 mask-from-slot load:
`mov x9,x17; sub x9,x9,#9; asr x9,x9,#63` (hi <= 8), `mov x10,#0; sub x10,x10,x17;
orr x10,x10,x17; asr x10,x10,#63` (hi != 0), `and x9,x9,x10`, then selects with
`x30 = x16 + (([sp] - x16) & keep)`.  Overlay `patches/a11-asm-ret-fail-safe.patch`
regenerated pin->current; `scripts/verify-asm-ret-guard-patch.py` PASS
(sha256 147350f6972ed504a4ecd78200fdf46f5cb1aee531bf8d77d14ace48ae1b0b15).
`test/a11_asm_ret_guard_test.cpp` mirrors the new sequence and adds the two measured
non-code slots (0x50ffffffff, 0x0f41210f24); the harness and the emitted-module check
both PASS, and a pre-change copy fails the new cases.

Operational: these guard bytes are baked into the GOAL objects
(`out/jak1/obj/*.o`, byte-swapped at a non-4-aligned file offset) and the slice emitter
copies them, so a compiler change only reaches the app after
`goalc --game jak1 --isa arm64 -c "(build-kernel)"` (KERNEL members) and
`-c "(mi)"` (546 targets, ~9 s, also rewrites KERNEL/GAME/ENGINE.CGO, which the signed
preflight requires to match the loose objects).  Verified byte-wise afterwards: all 8
guarded sites (aligner 1, gkernel 6, gstate 1) carry the new test.

## Verified (three runs)
Runs 1-2 (7/8 sites regenerated) and run 3 (8/8): each reports 32 LINKBEGIN, signed
RETURNED for title-obs and villagep-obs, `served obj 1 (oracle)`, calls=7268/leaks=42,
and no ret-into-data fault.  All three end at the same new fault - see G1.18.

## Next gate (G1.18)
Executing code at GOAL 0x88ba328 with `lr = 0x181674` (the village-cam Symbol) and a bad
memory access (fault addresses 0x106090ce34 / 0x0dee4fa794 / 0x109e590d54 across runs) -
deterministic, immediately after oracle is served.  That is the same "GOAL data used as a
call target" class as A1.1, now with pc inside code and the data value in the link
register, so G1.18 chases the producer of that link register next.
