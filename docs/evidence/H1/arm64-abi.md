# Ottsel ARM64 OpenGOAL ABI (H1)

Date: 2026-08-07  
Upstream pin: `641fb572e876750d8618434d9f7c1a531b43b366`  
Status: active for Gate H1 host proofs

## Design goal
Keep OpenGOAL's special-register model and 8-argument calling shape, mapped onto AAPCS64 / Apple ARM64 conventions already assumed by `game/kernel/asm_funcs_arm64.s`.

## Special registers
| Role | x86-64 | ARM64 | Notes |
|---|---|---|---|
| Process pointer (`pp`) | `r13` | `x20` | callee-saved; set by `_call_goal_asm_arm64` |
| Symbol table (`st`) | `r14` | `x21` | callee-saved; currently often same value as `pp` at call-in |
| Memory offset | `r15` | `x22` | callee-saved; GOAL pointers = real_addr - offset |
| Stack pointer | `rsp` | `sp` (`x31`) | 16-byte alignment required |
| Frame / link | n/a | `x29` / `x30` | not allocatable |

## Integer args / return
| Role | x86-64 | ARM64 |
|---|---|---|
| arg0..arg7 | `rdi rsi rdx rcx r8 r9 r10 r11` | `x0..x7` |
| integer return | `rax` | `x0`  (OpenGOAL encoder enum id `X8` is **not** used as return; runtime helpers return in `x0`) |

Correction against early enum comments in `Register.h`:
- Runtime C/GOAL bridges on ARM return in `x0` (AAPCS64).
- H1 RegisterInfo therefore sets GPR return to `X0`.
- Temp allocation still has free caller-saved regs (`x8..x15`, excluding reserved temps if needed).

## Vector / float
| Role | x86-64 | ARM64 |
|---|---|---|
| float/vector return | `xmm0` | `v0` |
| float/vector args | `xmm1..xmm8` | `v1..v8` |
| callee-saved vectors | `xmm8..xmm15` | `v8..v15` (Apple/AAPCS64 lower 64-bit preserve for v8-v15; we treat full Q as saved for GOAL prolog simplicity) |

## Saved GPRs (allocatable)
`x19` plus any additional used callee-saved not reserved as specials. Specials `x20/x21/x22` are reserved, not allocatable. `x23..x28` available as saved.

Initial H1 saved-GPR set:
- `x19, x23, x24, x25, x26`

## Caller-saved / temps
GPR temps: `x0..x15` minus those assigned as fixed args when constrained.
Reserved convention temps: prefer not to allocate `x16/x17` (veneer/linker) and never allocate `x18` (Apple platform register).

Initial H1 alloc order (GPR):
`x0,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x19,x23,x24,x25,x26`

Exclude: `x16,x17,x18,x20,x21,x22,x29,x30,sp`

## Function prolog / epilog (H1)
1. Save used callee-saved GPRs (and used saved vectors) with 16-byte stack discipline.
2. Allocate spill/var stack space rounded so final SP is 16-byte aligned before any call.
3. Emit IR.
4. Restore and `ret` (`ldr x30,[sp],#16` style via existing `IGen::ret`).

## Jump linking
ARM64 `B` / `B.cond` encode PC-relative immediates in the instruction word, not a trailing imm32.
H1 changes `InstructionARM64` imm metadata + `ObjectGenerator::handle_temp_jump_links` to patch ARM branch encodings correctly.

## Explicit non-goals for H1
- full vector math coverage
- mips2c / runtime no-emit (H2)
- iOS packaging (H2.5)
