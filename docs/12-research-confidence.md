# 12 — Research confidence & remaining unknowns

## Confidence by claim

| Claim | Confidence | Basis |
|---|---|---|
| OpenGOAL is x86_64 product path today | **High** | README, FAQ, install docs, CMake presets |
| Jak 1 is the most complete title | **High** | README status section |
| Runtime uses executable EE memory | **High** | `runtime.cpp` source |
| Runtime rewrites object memory during link | **High** | `klink.cpp`, `link_types.h`, ObjectGenerator |
| C and mips2c bridges emit machine code at runtime | **High** | `kscheme.cpp`, `mips2c_table.cpp`, readme |
| ARM64 encoder exists but IR/function codegen is NYI | **High** | source + PR history |
| `call_goal` C wrappers not wired for aarch64 | **High** | `common/kscheme.cpp` branches |
| No OpenGOAL iOS reference implementation | **High** | upstream statements + no found port |
| iOS product cannot rely on RWX/JIT entitlements | **High** (policy/engineering) | platform practice + Apple entitlement docs existence; not a loophole plan |
| Metal rewrite effort is large but secondary | **Medium-High** | renderer size + OpenGL-only pipeline |
| Option 1 RX-blob packaging acceptable on iOS device/store | **Low** | needs Bot 2 spike |
| Full Jak 1 ARM64 AOT performance will be good on iPad | **Medium** | unknown until H3/S2 |

## Unknowns that remain (honest)

1. Exact App Store acceptability of one-time RX mapping from AOT blobs.
2. Full count of instruction-immediates vs data-only patches across all Jak 1 objects (needs compiled object audit during Bot 2; Phase 1 audited mechanisms, not every object).
3. Completeness of ARM vector lowering vs all Jak 1 GOAL patterns once IR work begins.
4. Whether EE 128 MB contiguous mapping strategy must change under iOS allocation limits once code leaves EE.
5. Physical device performance and thermal behavior.

## What would falsify CONDITIONAL GO

- Discovery that correct Jak 1 execution requires ongoing self-modifying code that cannot be prefinalized.
- Discovery that no packaging option can execute AOT code under iOS constraints.
- ARM64 codegen proving intractable after bounded serious H1 attempts with no path to subset boot.

Until then, CONDITIONAL GO stands, with heavier evidence than the first pass.
