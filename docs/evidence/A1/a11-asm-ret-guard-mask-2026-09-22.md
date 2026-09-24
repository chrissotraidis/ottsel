# A1.4 the .ret fail-safe computed its mask from a stale register (2026-09-22, host + app)

Gate: the landed `.ret` fail-safe now actually selects on the slot. Proven by the shipped bytes, by a
regression that fails 8/8 before the change and passes 8/8 after, and by a product effect: the strict
signed-GAME run leaves the TIT/kernel-context phase and dies later, in the village/font phase.

## The defect
`IGen::shr_gpr64_u8(reg, sa)` emits `LSR reg, reg, #sa` (IGenARM64.cpp:2357, `Rn(reg.id())`), so
`IR_AsmRet::do_codegen_arm64`'s keep-mask sequence shifted **x17 itself** instead of the slot. The
regression double in `test/a11_asm_ret_guard_test.cpp` shifts `x30` (the slot) — the source and its
regression disagreed, and the shipped objects followed the source. All six guarded `.ret` sites in the
shipped `gkernel` module emitted, byte for byte
```
0xaa1e03f0 mov x16, x30
0xf94003fe ldr x30, [sp]
0xd360fe31 lsr x17, x17, #32     <- stale: x17 held the pushed synthetic continuation
0xd1000631 sub x17, x17, #1
0x937ffe31 asr x17, x17, #63
```
With x17 holding a host continuation the mask came out zero, so `x30` stayed the raw slot value: the
fail-safe was inert exactly when the slot held an EE value — the A1.1 bad-call-target case (the
village-cam Symbol address 0x181674 with pc == x30) that the guard was written to prevent.

## The fix
One instruction in `goalc/compiler/IR.cpp` (`IR_AsmRet::do_codegen_arm64`): `mov x17, x30` after the
slot load, before the shift. `out/jak-project/goalc/compiler/IR.cpp` sha256
`e65e821c1577cabefb8f393ca9acd0759ca940e24b036f582283e55184454ead`; `patches/a11-asm-ret-fail-safe.patch`
was regenerated as a pin-to-current snapshot and `scripts/verify-asm-ret-guard-patch.py` reproduces that
file byte for byte from pin `641fb572`. Only x2/x16/x17 are touched, x0/v0 stay untouched.

## The regression
`scripts/test-a11-asm-ret-guard.sh` now requires, for every guarded site in every emitted signed module,
`mov x17, x30` between `ldr x30, [sp]` and the shift. Against the pre-fix objects it reported
`FAIL: 8 of 8 guarded .ret sites compute the keep-mask from a stale register` (aligner, gkernel x6,
gstate) and exited 1; after the fix it reports
`PASS: 8 guarded .ret sites compute the keep-mask from the slot`. The regenerated objects show
`0xaa1e03f1` (mov x17, x30) at all six gkernel sites, and the select-contract test still passes.

## Product effect (same signed profile, regenerated objects)
Objects regenerated with the rebuilt goalc (546 targets, 25.7 s) and the app rebuilt with
`OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json` + banks 1. The run now serves the
TIT DGO *and* the streamed village/oracle objects (`served obj 0 (villagep-obs`, `served obj 1 (oracle`)
before failing later: `signal 10` in signed module `font` offset 0x6864, faulting word
`0xb9000205` = `str w5, [x16]` with x16 = g_ee_main_mem + 4, x0 = mem[g_ee_main_mem+4] = 0, x20/pp = 0,
`drawn=0`. So the .ret class is fixed at that site and the surviving defect is a low/EE-offset data
access in the village-phase signed code, not a bad `.ret` target.

## Next iteration (one variable)
Characterize the `font` module's `str w5, [x16]` at seg0 0x6864: emit `font.o` host-side and decode the
instruction and its address-forming instructions, then decide whether the base (g_ee_main_mem + 4) comes
from a GOAL offset used as an address or from a relocation that is 4 off. Prediction: it is the same
"GOAL/EE value used as a host address" class, one site, fixable in the emitter with a bounded regression.

