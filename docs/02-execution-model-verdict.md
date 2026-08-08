# 02 — Execution-model verdict (HARD GATE G2)

Research date: 2026-08-07  
Upstream pin: `open-goal/jak-project` @ `641fb572e876750d8618434d9f7c1a531b43b366`

## Verdict

# CONDITIONAL GO

OpenGOAL **can** be pursued for iPadOS/iOS **only if** Bot 2 first converts the Jak 1 pipeline into:

1. **ARM64-native GOAL codegen that is complete enough to build Jak 1**, and
2. an **AOT / no-runtime-emit execution mode** where the iOS process never needs writable-executable CPU memory.

This is not free and not mostly done. It is the entire port. Everything else is downstream productization.

If either (1) or (2) fails under the proof gates in `BOT2_PROMPT.md`, the project is a **NO-GO** for a native iOS product and should stop rather than paper over the problem with an interpreter fantasy or jailbreak-only path.

## Why this is the crux

iOS App Store reality:

- no Rosetta
- no general-purpose RWX / JIT for normal apps
- executable pages must be covered by the signed app model
- "flip W^X around a shared code heap forever" is a desktop/macOS JIT pattern, not an iOS product pattern

OpenGOAL reality at the pinned commit:

- supported product path is **x86-64 + AVX**
- macOS Apple Silicon users run via **Rosetta**
- runtime maps EE memory as **executable and writable**
- compiler defaults to `InstructionSet::X86`
- ARM64 encoder scaffolding exists, but GOAL function codegen is still `NYI`
- several C→GOAL bridges still write machine code into the heap at runtime

Therefore the port is not "UIKit shell around a working engine." It is "change OpenGOAL's execution model."

## Evidence table — runtime code generation / executable memory

| Site | What it does | Why it blocks iOS | AOT replacement |
|---|---|---|---|
| `game/runtime.cpp` EE `mmap(... PROT_EXEC\|READ\|WRITE)` | 128 MB GOAL address space used for code+data | RWX / writable code heap | Split model: immutable signed code mapping + writable data heap; or pure data heap + native code outside EE |
| `goalc` object emission + `link_and_exec` | Loads relocatable code into EE and patches links | Instruction patching / code relocation at runtime | AOT emit final ARM64 with data-only relocations, or prelink offline into a fixed code image |
| Listener/REPL (`klisten`) | Can compile/link fresh code while running | Pure JIT workflow | Disable completely in iOS product builds |
| `make_function_from_c*` in `kscheme.cpp` | Builds trampoline bytes into GOAL heap for C exports | Runtime machine-code write; currently still x86 bytes even under aarch64 ifs | Static trampoline table / pregenerated stubs / direct function pointers with fixed ABI shims |
| Mips2C stubs | Small generated stubs around C++ implementations | Runtime code emit | Pregenerate stubs or call through fixed native wrappers |
| `CodeTester` `MAP_JIT` + mprotect RX/RW | Unit-test JIT harness on Apple Silicon | Acceptable for host tests; not an iOS app strategy | Keep as **host-only** test tool |
| Live goalc over DECI2 | External compiler feeds code to runtime | JIT by another name | Host-only tooling; never in iOS app |

## Evidence table — ARM64 compiler maturity

| Area | Status at pin | Implication |
|---|---|---|
| `InstructionSet::ARM64` enum + dispatch | Present | Architecture fork exists |
| `IGenARM64` encodings | Large body of work (~3k LOC), recent PRs merged | Useful foundation |
| `CodeTester` on macOS aarch64 | Exists; uses MAP_JIT / mprotect | Proves encoder fragments can run on Apple Silicon host |
| `CodeGenerator::do_goal_function_arm64` | Throws `NYI` | Cannot compile ordinary GOAL functions for ARM64 yet |
| `CodeGenerator::do_asm_function_arm64` | Throws `NYI` | ASM functions blocked |
| `IR_*::do_codegen_arm64` | **41 / 41 throw `NYI`** | IR lowering not implemented |
| `goalc` CLI default | Hard-coded X86 | No product ARM64 compiler path yet |
| Runtime C trampolines | ARM asm helpers exist; heap emitters incomplete | Boot/runtime bridges still codegen-shaped |
| Upstream support stance | x86_64 only; no mobile plans | Ottsel is a fork/port effort, not an upstream switch flip |

## Feasible strategies (ranked)

### Strategy A — Preferred: Offline ARM64 AOT objects + no-emit runtime (CONDITIONAL GO path)

**Idea:** On a macOS host, compile Jak 1 with an ARM64 `goalc` into immutable artifacts. The iOS app only loads/links data and jumps into already-final code that never needs to be rewritten.

Required inventions:

1. Finish ARM64 IR lowering + function prologues/epilogues + calling convention.
2. Define an iOS code model:
   - either EE-relative ARM64 code placed into a **read-execute** mapping created from AOT bytes loaded as data then made RX **without later writes**, during a single load phase that still may be unavailable on iOS if pages are not signed;
   - or, more App-Store-safe: package AOT output as **native Mach-O code** (or multiple signed native libraries) generated offline, with GOAL pointers represented as handles/offsets into that native code.
3. Replace every runtime stub emitter with static tables.
4. Disable listener/REPL/code-receive paths in iOS builds.
5. Ensure linker patches are **data relocations only**, never instruction rewrites. If ARM64 immediates/branches require instruction patching, those patches must be resolved offline.

**Why preferred:** Keeps OpenGOAL architecture recognizable and benefits from upstream ARM emitter work.

**Main risk:** iOS may reject any scheme that creates executable pages from data blobs at runtime, even once. If so, Strategy A must escalate to "AOT compiler emits C/LLVM/Mach-O" rather than "load blob and execute."

### Strategy B — AOT translate GOAL/IR to C++ or LLVM bitcode, compile with clang into the app

**Idea:** Treat `goalc` as a frontend that outputs C++/LLVM for Jak 1, then build a normal native iOS binary.

Pros:

- best match for iOS code signing
- no executable heap

Cons:

- large new backend
- loses fidelity with OpenGOAL object/linker semantics unless carefully re-modeled
- likely multi-month compiler project before first frame

Use if Strategy A hits a hard platform wall on creating RX pages from AOT blobs.

### Strategy C — Interpreter / bytecode VM for GOAL on iOS

**Idea:** Don’t emit ARM64 at all; interpret OpenGOAL or a portable bytecode.

Pros:

- avoids JIT

Cons:

- abandons OpenGOAL’s native-performance design
- massive new runtime
- poor fit for a first-of-its-kind high-fidelity action platformer target
- not elegant relative to existing compiler investment

**Not recommended** except as a last-ditch research probe. Bot 2 should not start here.

### Strategy D — Rely on MAP_JIT / debug entitlements / non-App-Store only

Rejected for the product goal. Fine for host unit tests. Not a path to a normal iPad app.

## Decision details

### What "GO" would have required
A already-working ARM64 OpenGOAL path that runs Jak 1 without RWX and without runtime code writes.

That does **not** exist upstream today.

### What "NO-GO" would have required
A structural impossibility even with major compiler work (for example, if game correctness required perpetual self-modifying code).

We did **not** find that. The self-modifying / runtime-emit behaviors appear to be **implementation choices** of the PC port and development workflow, not an intrinsic unknowable property of Jak 1 game logic. They can be designed out, at real cost.

### Why CONDITIONAL GO
Because the destination architecture is plausible, partial ARM64 foundations exist, and adjacent iOS ports prove native AOT game stacks can ship — but the critical compiler/runtime work is unfinished and is a multi-gate engineering program, not a shell port.

## Non-negotiable Bot 2 order

Bot 2 must not build touch UI, icons, or polish before these proofs:

1. **Host ARM64 goalc can compile a non-trivial GOAL function** (no NYI).
2. **Host ARM64 runtime can execute that function without RWX pages remaining writable.**
3. **All runtime stub emitters are removed or static.**
4. **Jak 1 AOT build artifacts can be produced on macOS host.**
5. Only then: iOS/iPadOS Simulator shell loads those artifacts and reaches a first proven GOAL call / frame path.

If proof 1–3 fail after bounded attempts, stop and report NO-GO with evidence.

## Residual unknowns (do not hand-wave)

1. Exact App Store acceptability of one-time create-RX-from-AOT-blob vs requiring clang-built Mach-O code.
2. How many OpenGOAL instruction patterns depend on x86-specific behavior or RIP-style linking that needs redesign for ARM64 PIC/signed code.
3. Whether EE memory pointer model can remain 128 MB contiguous under iOS allocation realities once code is removed from it.
4. Completeness of ARM64 vector/VU-ish sequences used heavily by game code.
5. Scope of mips2c/ASM function surface in Jak 1 that also needs non-emit call gates.

## Deep-pass reinforcement (same verdict, stronger evidence)

A second research pass audited mechanisms in source, not just architecture slides:

- full emit-site inventory: [`08-emit-site-audit.md`](08-emit-site-audit.md)
- ARM64 compiler gap analysis: [`09-arm64-compiler-gap-analysis.md`](09-arm64-compiler-gap-analysis.md)
- packaging/signing options: [`10-code-packaging-and-signing.md`](10-code-packaging-and-signing.md)
- confidence/unknowns: [`12-research-confidence.md`](12-research-confidence.md)

Material upgrades to the case:

1. Link-time rewriting is not theoretical: Jak 1 `klink` patches RIP distances, symbol slots, and type pointers into loaded objects; ObjectGenerator emits those reloc records on purpose.
2. Boot path emits many trampolines: ~40 `make_function_from_c` sites in Jak 1 `kscheme.cpp`, plus mips2c stub synthesis for 25 Jak 1 translation units.
3. ARM64 is bifurcated: encoder substantial, IR lowering 0/41, and `call_goal` C wrappers still lack an aarch64 branch despite ARM asm helpers existing.
4. Packaging is a separate hard decision after host proofs; RX-blob load is only a probe, not an assumed App Store path.

None of these falsified CONDITIONAL GO. They raise the lower bound of required work and make NO-GO stop conditions more concrete.

## Bottom line for humans

- **Do not** start this project as "SDL window + existing gk binary."
- **Do** start it as "finish ARM64 AOT OpenGOAL for Jak 1, then wrap the no-emit runtime in an iOS shell."
- Jak 1 remains the correct first title **because** it minimizes game unknowns while the compiler/runtime problem is solved.
