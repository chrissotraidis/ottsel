# A1.0 — Semantic ARM64 regression layer (PASS, 2026-08-09)

The emission validator proves only that words decode as legal A64.  This
layer asserts what emitted code DOES.  Harness:
`out/jak-project/tools/ottsel_a1/semantic_regressions.cpp` (target
`ottsel-a1-sem`, built with `cmake --build out/jak-project/build/h1 --target
ottsel-a1-sem -j 8`).

## Results (14/14 assertions PASS)

Emitter-unit (5):
- static_load_f32 emits `ldr s` (never the STR-Q clobber).
- load16u +s8 emits unscaled LDURH (never scaled LDRH).
- store16 +s8 keeps STURH.
- `_stack_call_arm64` pushes (x6,x7)(x4,x5)(x2,x3)(x0,x1) so the GOAL arg
  array is [x0..x7] (source scan of game/kernel/asm_funcs_arm64.s).

GOAL-compile (9, real goalc ARM64 emission of GOAL source):
- stack-var addressing uses `add xd, sp, #imm`; no `mov xd, xzr`
  (SP->xzr regression).
- u16 field read emits LDURH; no scaled LDRH (x2-offset regression).
- non-leaf caller saves x30 in the prologue and restores it before `ret`.
- two-level nesting (outer -> mid -> leaf): outer saves/restores x30 and
  ends with `ret` (LR preserved through deeper chains).

## Negative proofs (each regression fails when the bug is reintroduced)

1. Reintroduced STR-Q in static_load_f32 + scaled LDRH in load16u: 4
   assertions FAIL (words 0x3d800200 / 0x79402200); restored -> PASS.
2. Swapped the `_stack_call_arm64` arg pairs: assertion 7 FAIL (after fixing
   a harness bug that ignored its own `ok` flag); restored -> PASS.

Run: `./out/jak-project/build/h1/goalc/ottsel-a1-sem` -> `[A1.0] PASS all
semantic regressions`.

## Encoding validation (unchanged product state)

- KERNEL.CGO: 86,016 code words PASS (8 objects).
- GAME.CGO:   3,829,760 code words PASS (346 objects).
- (`python3 scripts/validate-arm64-emission.py --cgo ...`)
