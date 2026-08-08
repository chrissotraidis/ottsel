# 09 — ARM64 compiler gap analysis

Research date: 2026-08-07  
Pin: `641fb572e876750d8618434d9f7c1a531b43b366`

## 1. Bottom line

Upstream has built a **real ARM64 instruction encoding layer** and a host test harness, but **not** a game-capable ARM64 OpenGOAL compiler.

At this pin:

- encoder: substantial
- IR lowering: **0% implemented** (41/41 throw NYI)
- function prolog/epilog generators: NYI
- compiler CLI: hard-coded X86
- register allocator info: still x86-centric defaults
- runtime call bridges: ARM asm present, C wrappers incomplete

## 2. Layered maturity

```
Frontend (parse/typecheck/IR build)
  status: exists, shared
        |
        v
Regalloc / calling convention
  status: x86-shaped RegisterInfo; ARM enums exist but not a finished ABI model
        |
        v
IR -> machine ops (do_codegen_*)
  status: x86 complete-ish; ARM64 all NYI
        |
        v
IGen / Instruction encode
  status: ARM64 large implementation present (~2985 LOC)
        |
        v
ObjectGenerator link records
  status: still models x86 RIP/imm32 style runtime patches
        |
        v
Runtime execute
  status: x86 product path; ARM experimental pieces only
```

## 3. Exact NYI surface

### CodeGenerator
- `do_goal_function_arm64` → `NYI - CodeGenerator::do_goal_function_arm64`
- `do_asm_function_arm64` → `NYI - CodeGenerator::do_asm_function`

### IR lowerings
There are **41** `IR_*::do_codegen_x86` methods and **41** matching `do_codegen_arm64` methods.
All 41 ARM methods throw.

Includes (representative, not abbreviated away):

- control: `IR_GotoLabel`, `IR_ConditionalBranch`, `IR_FunctionCall`, `IR_Return`, `IR_JumpReg`
- memory: `IR_LoadConstOffset`, `IR_StoreConstOffset`, `IR_LoadConstant64`, `IR_StaticVarLoad`, `IR_StaticVarAddr`, `IR_GetStackAddr`, `IR_RegValAddr`
- symbols: `IR_LoadSymbolPointer`, `IR_GetSymbolValue`, `IR_SetSymbolValue`, `IR_GetSymbolValueAsm`
- integer/float/vector: `IR_IntegerMath`, `IR_FloatMath`, `IR_FloatToInt`, `IR_IntToFloat`, `IR_VFMath*`, `IR_Int128Math*`, `IR_BlendVF`, `IR_SplatVF`, `IR_SwizzleVF`, `IR_SqrtVF`
- asm helpers: push/pop/add/sub/ret/fnop/fwait/regset asm
- misc: `IR_RegSet`, `IR_ValueReset`, `IR_Null`, `IR_Nop`, function/static addresses

### Encoder TODOs
`IGenARM64.cpp` still has multiple TODOs (16 `TODO` hits), including reserved-register usage (`x16`), store sequences, and naming debt. This is unfinished polish on top of an unfinished middle-end.

## 4. What *is* done (do not understate)

Merged work (PRs observed via GitHub API during research):

- #3290: CodeTester passing on Arm64 (macOS), encoding mechanism, dispatch
- #4318: bulk ARM64 instructions from x86 map
- #4334: load/store conversion largely finished

Also present:

- `InstructionSet::{X86,ARM64}`
- `IGen` dispatch macro to X86/ARM64
- ARM register enums and many encode helpers
- macOS CMake presets `*-macos-arm64-clang*`
- docs/setup notes: ARM64 build is “experimental, unsupported”

This is a beachhead, not a product.

## 5. ABI / register model gaps

From `goalc/emitter/Register.*` and OpenGOAL porting docs (`porting-info/registers`):

- OpenGOAL on x86 reserves special roles:
  - process pointer
  - symbol table (`st` / s7-equivalent)
  - memory offset register
- `RegisterInfo::make_register_info()` currently configures **x86 arg regs / saved regs**.
- ARM64 needs a deliberate mapping to AAPCS64 + OpenGOAL specials (asm file comments already reference Apple AAPCS docs and preserve q8–q15 etc.).

Until ABI is specified and used by prolog/epilog + calls, IR lowering cannot be “just fill in emits.”

## 6. Object model coupling to x86

Even with ARM encodes, object linking currently assumes things like:

- 32-bit immediate displacement style symbol addressing
- RIP-relative distances patched at runtime (`LINK_DISTANCE_TO_OTHER_SEG_32`)
- compile-time jump patching using x86 imm size assumptions (`get_imm_size() == 4` in jump handler)

ARM64 branches/immediates are not drop-in replacements. Bot 2 must redesign the code model for ARM64 PIC/finalization, not only translate opcodes.

## 7. Suggested implementation order (compiler-only)

1. **ABI doc + RegisterInfo ARM path** (args, ret, specials, saved sets)
2. **Minimal IR set for tests:** const/move/add/sub/load/store/branch/call/return
3. `do_goal_function_arm64` prolog/epilog
4. CodeTester cases for that set on Apple Silicon host
5. symbol access strategy that does **not** require later instruction writes
6. broaden IR coverage toward Jak 1 boot subset
7. asm-function path
8. only then full game compile

## 8. Estimation posture (not a schedule promise)

This is a compiler project measured in **multiple substantial gates**, not a weekend port. The encoder beachhead saves work, but IR+ABI+code-model are the real bulk.

## 9. Sources

- `goalc/compiler/CodeGenerator.cpp`
- `goalc/compiler/IR.cpp`
- `goalc/emitter/IGenARM64.*`
- `goalc/emitter/Register.*`
- `goalc/emitter/ObjectGenerator.cpp`
- `goalc/main.cpp`
- `docs/setup/system/macos.md`
- GitHub PRs #3290, #4318, #4334
- OpenGOAL docs: `/docs/porting-info/registers`, developing category (assembly emitter notes)
