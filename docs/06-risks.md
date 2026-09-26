# 06 — Risks and open questions

## Critical risks (can kill the project)

### R1 — ARM64 GOAL codegen incomplete
**Evidence:** all IR ARM64 lowerings NYI; function generators throw.  
**Impact:** no AOT artifacts, no iOS.  
**Mitigation:** Bot 2 Gate H1 is first and hard. Bound the attempt; do not escape into UI work.

### R2 — iOS rejects runtime-created executable pages
**Impact:** Strategy A blob-load dies; must pivot to clang/Mach-O emission (Strategy B).  
**Mitigation:** decide packaging form with a dedicated spike immediately after H2; do not build product UX on a doomed load path.

### R3 — Hidden instruction rewriting in linker
**Impact:** even with AOT objects, load-time patching may write instructions.  
**Mitigation:** audit every link operator for code vs data mutation; force offline fixups.

### R4 — Runtime trampoline emission forgotten in edge paths
**Evidence:** `make_function_from_c*` and mips2c stubs.  
**Impact:** accidental RWX dependency returns late.  
**Mitigation:** compile-time `#error` on emit paths under iOS/no-emit flags; search-based CI check for opcode emitters.

## High risks

### R5 — OpenGL-only renderer
Large rewrite/port to Metal. Schedule risk, not first gate.

### R6 — Multi-thread pause semantics
EE/IOP/audio threads vs UIKit suspension. Softlocks/crashes on backgrounding.

### R7 — Asset pipeline UX
ISO extraction on iPad is the wrong design. Host-prepared package is elegant; poor onboarding can still make the app feel broken.

### R8 — Performance on iPad after Rosetta-era assumptions
Even with correct AOT, renderer/CPU hotspots may need work. Secondary to correctness gates.

### R9 — Legal/content mistakes
Accidental asset commit or redistributed ISO pieces. Hard process controls required.

### R10 — Over-scoping to “full product” before execution model proof
Classic failure mode. Roadmap forbids it.

## Medium risks
- SDL3 version friction with existing OpenGOAL pin
- ImGui debug UI assumptions on mobile
- Controller database / HID quirks
- Memory footprint of 128 MB EE model plus renderer resources on older iPads
- Divergence cost from fast-moving upstream

## Open questions Bot 2 must answer with evidence
1. What is the final code packaging form on iOS (RX blob vs Mach-O symbols)?
2. Which Jak 1 functions are mips2c/ASM and how are they exported without emit?
3. What is the minimum Metal surface for first frame?
4. What is the exact host command sequence for legal asset package creation?
5. What memory permission proof is reliable on Simulator vs device?

## Risk posture summary
The only research-phase unknown that matters is still the execution model. The verdict is **conditional go**, not a promise. Bot 2 either proves H1–H3 or stops.


## Added after deep pass

### R11 — Load-time instruction patching is pervasive by design
Not only trampolines: symbol/RIP/type links rewrite object bytes.  
Mitigation: offline finalization + data-only reloc model; audit during H2 with real objects.

### R12 — `call_goal` aarch64 wiring missing
Even with ARM asm helpers, common C wrappers don't call them.  
Mitigation: explicit H1/H2 task; easy to miss if only looking at encoder files.

### R13 — mips2c surface is part of Jak 1 boot/render path
25 Jak 1 units include tfrag/tie/collide/sparticle/etc.  
Mitigation: static shim generation for all registered mips2c functions before claiming no-emit.

### R14 — Packaging policy risk independent of host proofs
Host success ≠ iOS-safe code origin.  
Mitigation: forced packaging spike after H2 (`10-code-packaging-and-signing.md`).
