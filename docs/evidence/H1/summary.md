# H1 — ARM64 GOAL function codegen: what changed

Date: 2026-08-07. Patch: `patches/h1-arm64-goal-function-codegen.patch`

## Register model (ABI)
- `RegisterInfo` is now ISA-aware: `make_register_info_x86()` / `make_register_info_arm64()`
  and `set_active_instruction_set()` (see `arm64-abi.md`).
- ARM64 mapping: args x0..x7, return x0 (AAPCS64 + runtime asm helpers),
  specials pp=x20, st=x21, offset=x22, stack=sp.
- Saved GPRs x19,x23..x28; reserved x16/x17/x18/x29/x30/sp.
- Compiler activates the correct RegisterInfo for the selected InstructionSet.

## Function codegen
- Implemented `CodeGenerator::do_goal_function_arm64` (prolog/epilog with
  16-byte stack discipline, spill/restore, vector backup, ret).
- `CodeGenerator::emit_function_machine_code` + `ObjectGenerator::emit_function_code_only`
  expose single-function machine code for host proofs.

## IR lowerings (now non-NYI)
const (IR_LoadConstant64), move (IR_RegSet), integer math (add/sub/and/or/xor/not/
shifts/mul32/mul64), float math (add/sub/mul/div/min/max/sqrt), load/store const
offset, conditional branch, goto, call, return, null, nop, value-reset, stack addr.
16 IRs implemented; 25 remain NYI (symbol/function-addr links deferred to H2,
asm + vector + float-to-int families not exercised by H1 tests).

## Encoder bug fixes found while proving
- `ARM64::Hw` masked `&4` instead of `&3` (MOVZ/MOVK hw field).
- `ARM64::Imm16` shifted by 16 instead of 5 (bits 20-5).
- Field bound asserts used C++ `2 ^ N` (XOR) instead of `pow2(N)`.
- ARM64 branch imm metadata (`imm_size`/`imm_word_index`) added to
  `InstructionARM64`; `ObjectGenerator::handle_temp_jump_links` now patches
  ARM64 `B` (imm26) and `B.cond` (imm19) words; `emit_function_code_only`
  applies the same intra-function patching.
- CMake: drop `-mavx` on arm64 hosts so the tree builds natively.

## Honest scope note
`defun` top-level registration functions still require IR_FunctionAddr /
IR_StaticVarAddr / symbol-value links, which are x86-RIP-shaped runtime links
and belong to H2's no-emit code model. H1 proves ordinary function bodies
through the real codegen path (the exercised IR set), and the harness emits
those bodies directly.

## Proof
`run-h1-proof.log`: 5/5 cases pass with real compile+execute on Apple Silicon
(add2=42, const=123, submul=18, branch abs(-7)=7, id=99). No NYI in the
exercised set. CLI `--isa x86|arm64` works; unknown ISA rejected cleanly.
