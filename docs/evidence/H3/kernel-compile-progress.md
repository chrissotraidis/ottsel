# H3 — Jak 1 ARM64 kernel compile progress

Date: 2026-08-07 (Bot 2, first H3 iteration)
Pin: `641fb572e876750d8618434d9f7c1a531b43b366` (worktree `out/jak-project`)
Patch: `patches/h3-jak1-kernel-arm64-compile.patch`
Assets: `~/ottsel-user/iso/` (untracked, not staged)

## Status: IN PROGRESS (host compile slice)

### Extraction pipeline (done this iteration)

The host extractor built and ran on the legal ISO:

    ninja -C build/h1 extractor
    ./build/h1/decompiler/extractor \
      "/Users/chrissotraidis/ottsel-user/iso/Jak and Daxter - The Precursor Legacy (USA) (En,Fr,De,Es,It).iso" \
      --extract -e --proj-path "$PWD"

Result: `iso_data/jak1/` (1.4 GB) with `CGO/` (KERNEL.CGO, ENGINE.CGO, GAME.CGO,
levels), `DGO/`, `MUS/`, `STR/`. Detected SCUS-97124 (NTSC-U). All inside
`out/jak-project/iso_data`, matched by `.gitignore` (`out/`), never staged.

### Host runtime boots on arm64 (partial)

`ninja -C build/h1 gk` succeeds; `gk -fakeiso` launches SDL/OpenGL on Apple M1
(OpenGL 4.1 Metal), reaches the GOAL boot path, and fails only because the
compiled `fr3` data (from the GOAL level build) does not exist yet — i.e. it
stops after runtime init, before the GOAL kernel dispatch completes.

## Boot-path analysis (what remains)

Retail `KERNEL.CGO` is PS2 MIPS; OpenGOAL recompiles `goal_src/jak1/kernel/*.gc`
for the host and links at boot via `load_and_link_dgo_from_c("kernel", ...)` →
`link_and_exec` (listener) or the offline loader. The no-emit boot requires:

1. ARM64 `goalc` compiling the full kernel (`gkernel.gc` etc. — `*stdcon*`
   externs resolve once the C kernel defines them at boot).
2. A no-emit object loader in `gk`: `link_and_exec` currently writes code into
   the RWX EE mapping; the ARM64 path must load our objects with data-only
   relocations (symbol slots, type/pointer links) into code that is RX after
   load.
3. `kernel-dispatcher` set by the GOAL kernel top-level, then
   `KernelCheckAndDispatch` calls it — first real GOAL entry.

This is the next H3 slice; it is integration (loader + boot), not more IR NYI
for the kernel headers.

The ARM64 `goalc` now compiles real Jak 1 kernel GOAL sources into objects
through the real codegen path:

| Object | Status | Notes |
|---|---|---|
| `gcommon.o` | PASS | base kernel, defines PC_PORT/BIG_MEMORY |
| `gkernel-h.o` | PASS | kernel globals header |
| `gstring-h.o` | PASS | string externs |
| `gstring.o` | PASS | string system |
| `dgo-h.o` | PASS | DGO header |
| `gkernel.gc` | blocked at `*stdcon*` | extern resolved by C kernel at boot (not a codegen NYI) |

Commands (one goalc session, correct kernel order):

    ./build/h1/goalc/goalc --isa arm64 -c \
      '(asm-file "goal_src/jak1/kernel-defs.gc") \
       (asm-file "goal_src/jak1/kernel/gcommon.gc" :color :write) \
       (asm-file "goal_src/jak1/kernel/gkernel-h.gc" :color :write) \
       (asm-file "goal_src/jak1/kernel/gstring-h.gc" :color :write) \
       (asm-file "goal_src/jak1/kernel/gstring.gc" :color :write) \
       (asm-file "goal_src/jak1/kernel/dgo-h.gc" :color :write)'

Output: `out/jak1/obj/{gcommon,gkernel-h,gstring-h,gstring,dgo-h}.o` written.

## What this proves

- Real Jak 1 GOAL (not toy tests) compiles for ARM64 through
  `do_goal_function_arm64` with no NYI in the exercised IR set.
- The symbol data-slot relocation design works: ARM64 symbol access emits
  ADR-to-slot (patched offline at finalize) + load offset + add st; the only
  runtime patch is the writable u32 slot (`sym - s7`), never instructions.
- ARM64 RIP link-table records are suppressed (references are offline-resolved
  at object finalize), matching the H2.5 generated-native decision.

## Compiler work in this iteration

- `Allocator_v2` is now ISA-aware (was hardcoded x86 registers; ARM64 floats
  were colored to invalid ids → crash). Allocation orders come from
  `RegisterInfo` per active ISA.
- ARM64 div/mod: `SDIV`/`UDIV` + `MSUB` with x17 scratch (dividend preserved),
  GOAL 32-bit sign-extension semantics.
- `IR_Int128Math{2,3}Asm`, `IR_VFMath{2,3}Asm` arm64 lowerings (mirror x86;
  encoders already existed).
- `IR_IntToFloat` / `IR_FloatToInt` arm64 (`SCVTF`/`FCVTZS` + sign-extend).
- `static_addr` fixed to ADR semantics (was LDR-literal = load *value at*
  label; GOAL needs *address of*); offline patch added for same-segment refs.
- `static_load` fixed wrong size cases (4/8 emitted 8-bit loads).
- Symbol access IRs (`LoadSymbolPointer` general, `Get/SetSymbolValue`) now
  use the no-emit data-slot pattern.
- Relaxed over-strict `addr != SP` asserts on stack spill load/store.

## Remaining NYI (15 IRs, not blocking kernel headers)

`IR_Asm*` family (push/pop/add/sub/ret/fnop/fwait/regset-asym/get-sym-asym),
`IR_JumpReg`, `IR_BlendVF`, `IR_SplatVF`, `IR_SwizzleVF`, `IR_SqrtVF`,
`IR_FloatMath` (partial default case).

## Next blockers for boot (not codegen NYIs)

1. Extern/global resolution: `*stdcon*` etc. are defined by the C kernel at
   boot; compiling `gkernel.gc`/`pskernel.gc` needs the host boot pipeline that
   loads the C kernel and links objects (the real H3 boot step).
2. Vector math/asm IRs above (needed by engine code, not kernel headers).
3. Runtime integration: load AOT objects into EE memory, run `kboot`/kernel
   init with the no-emit loader (data-only relocs), first GOAL entry.

## Honest boundary

This is the compile half of H3. The boot half (link objects against the C
kernel, enter real Jak 1 GOAL code) is not yet done; it is the next slice.
No assets were staged; ISO remains at `~/ottsel-user/iso/`.
