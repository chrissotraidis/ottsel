# 08 — Runtime code-emission & executable-memory audit

Research date: 2026-08-07 (deep pass)  
Upstream pin: `open-goal/jak-project` @ `641fb572e876750d8618434d9f7c1a531b43b366`  
Scope: Jak 1 primary; Jak 2/3 noted only when same pattern exists.

This is the hard evidence behind `02-execution-model-verdict.md`.

## 1. Executive finding

OpenGOAL’s PC runtime is a **dynamic native-code loader**:

1. allocates a large EE memory region with execute permission,
2. copies object-file code into that region,
3. **rewrites instruction/data slots during linking**,
4. builds additional trampoline machine code at runtime for C/mips2c bridges,
5. jumps into that memory via assembly helpers.

That is not “almost AOT.” It is AOT-ish compilation of objects on a host, followed by **runtime code materialization**.

For iOS App Store-class apps, every one of those steps is hostile unless redesigned.

## 2. Inventory of sites

### A. EE memory mapping — `game/runtime.cpp`

- Maps `EE_MAIN_MEM_SIZE` (128 MB) with `PROT_EXEC | PROT_READ | PROT_WRITE`.
- Comment in-tree admits Apple Silicon cannot keep pages both writable and executable.
- After map, first 512 KB is `mprotect(... PROT_NONE)`.
- This is the root executable heap for GOAL code + data.

**iOS impact:** product path cannot keep a writable executable EE.

### B. Object link-time rewriting — `game/kernel/jak1/klink.cpp` + `common/link_types.h`

Link kinds (`common/link_types.h`):

| Kind | Meaning | Mutates |
|---|---|---|
| `LINK_SYMBOL_OFFSET` | patch symbol offset/address into object | yes, memory at link offsets |
| `LINK_TYPE_PTR` | write type pointer into object | yes |
| `LINK_DISTANCE_TO_OTHER_SEG_64/32` | patch distance (RIP-style) | yes — used for instruction immediates |
| `LINK_PTR` | patch pointer within segment | yes |

Concrete Jak 1 behaviors:

- `cross_seg_dist_link_v3` patches 32- or 64-bit values at `offset_of_patch` (comment: used for RIP).
- `symlink_v3` writes symbol address or `sym - s7` into each listed offset; if current value is `-1`, stores absolute symbol address.
- Type-pointer linking writes type offsets into listed locations.
- After linking, `CacheFlush(m_code_start, m_code_size)` is called (currently a no-op stub on PC, but semantically “code was modified”).

Compiler side (`goalc/emitter/ObjectGenerator.*`) intentionally emits runtime link records for:

- symbol mem/ptr instructions (`link_instruction_symbol_mem`, `link_instruction_symbol_ptr`)
- RIP-to-data / RIP-to-function (`link_instruction_static`, `link_instruction_to_function`)
- static type/symbol/pointer links

Jump links are compile-time patched in the object generator (`link_instruction_jump` / `handle_temp_jump_links`) — good. Many other links are **not**.

**iOS impact:** even if objects are built offline, current runtime still expects to rewrite bytes in code/data images while loading. A no-emit iOS runtime must either:

- resolve all instruction fixups offline into final ARM64, or
- restructure references so only writable **data** relocations remain.

### C. C→GOAL trampoline synthesis — `game/kernel/jak1/kscheme.cpp`

Functions:

- `make_function_from_c_systemv` / `_win32`
- `make_stack_arg_function_from_c_systemv` / `_win32`
- wrappers used heavily during kernel bootstrap

Measured in Jak 1 `kscheme.cpp` at pin:

- `make_function_from_c(` call sites: **40**
- `make_stack_arg_function*` references: **11**
- `make_raw_function*` references: **5**

These allocate a GOAL `function` object on the global heap and **write x86 machine bytes** into it (`0x48 0xb8 ...` movabs sequences, pushes, jmp rax). There is an aarch64 branch selecting `_arg_call_arm64` / `_stack_call_arm64` as the *target*, but the stub bytes emitted are still x86 (explicit TODO in source).

Used for essential kernel methods/symbols (`print`, `inspect`, allocators, `link`, format, etc.). Boot cannot avoid this path today.

**iOS impact:** must become a static shim table / prebuilt native bridge. No heap opcode writing.

### D. mips2c trampoline synthesis — `game/mips2c/mips2c_table.cpp`

When a mips2c function is registered (`LinkedFunctionTable::reg`):

1. allocate a GOAL function object,
2. write an x86 stub that pushes exec pointer + stack size,
3. jump to `_mips2c_call_systemv` / windows variant.

Readme states this clearly: “a small dynamically generated function object is created.”

Jak 1 mips2c translation units present (**25**):

`bones, collide_cache, collide_edge_grab, collide_func, collide_mesh, collide_probe, draw_string, generic_effect, generic_effect2, generic_merc, generic_tie, joint, merc_blend_shape, ocean, ocean_vu0, ripple, shadow, sky_tng, sparticle, sparticle_launcher, test_func, texture, tfrag, tie_methods, time_of_day`

These are not exotic optional mods; they include rendering/collision/particle hot paths.

ARM64 has `_mips2c_call_arm64` assembly, but the stub generator path inspected is still x86-byte oriented and gated on linux/apple-x86/win32.

**iOS impact:** every mips2c export needs a static GOAL-callable native entry, not a generated stub.

### E. Listener / live load — `game/kernel/jak1/klisten.cpp`, DECI2 server

- Runtime listens for compiler messages.
- Can `link_and_exec` received code into debug heap.
- This is a full interactive JIT-style workflow.

**iOS impact:** disable entirely in product builds. Host-only tooling may keep it.

### F. CodeTester host harness — `goalc/emitter/CodeTester.cpp`

- Allocates `MAP_JIT` on Apple Silicon.
- Flips `mprotect` between RX and RW around execute.
- Mentions possible need for `pthread_jit_write_protect_np`.

**iOS impact:** acceptable only as **host unit-test** infrastructure. Not a product runtime strategy.

### G. call_goal assembly bridges — incomplete on ARM

`game/kernel/asm_funcs_arm64.s` defines:

- `_arg_call_arm64`
- `_stack_call_arm64`
- `_mips2c_call_arm64`
- `_call_goal_asm_arm64`
- `_call_goal8_asm_arm64`
- `_call_goal_on_stack_asm_arm64`

But `game/kernel/common/kscheme.cpp` `call_goal` / `call_goal_on_stack` only wire:

- linux x86
- apple **x86_64**
- win32

There is **no `__aarch64__` branch** in `call_goal` wrappers at this pin. So even if ARM64 GOAL code existed, C→GOAL entry from the common kernel path is unfinished.

## 3. What is *not* a problem (important negatives)

- No evidence that Jak 1 gameplay intrinsically requires self-modifying GOAL as a design goal beyond OpenGOAL’s PC implementation choices.
- Jump displacement fixups can already be resolved at object-generation time.
- mips2c bodies themselves are ordinary C++; only their GOAL entry stubs are dynamic.
- `CacheFlush` on PC is currently a no-op, so ICACHE maintenance is not the blocker; **permission + signing + no unsigned executable memory** are.

## 4. Minimum no-emit redesign checklist

1. **Split EE:** writable data heap vs immutable code image(s).
2. **Offline finalization:** produce ARM64 code with no load-time instruction writes.
3. **Data-only relocs:** symbol/type/function references become table lookups or prelinked absolute slots in writable data, not patched immediates in RX code if iOS forbids that.
4. **Static foreign-function table:** replace all `make_function_from_c*` and mips2c stub emitters.
5. **Wire ARM call_goal asm** into common wrappers.
6. **Compile out listener/REPL** under iOS/no-emit flags.
7. **Permission proof** in tests: after load, code pages are not writable.

## 5. Severity ranking for Bot 2

| Priority | Item | Why |
|---|---|---|
| P0 | ARM64 IR/function codegen | without it, no AOT artifacts |
| P0 | Static C/mips2c shims | boot currently emits code |
| P0 | call_goal ARM wiring | C kernel cannot enter GOAL on aarch64 cleanly |
| P0 | Eliminate instruction fixups at load | link path rewrites code bytes |
| P1 | EE permission model | 128 MB RWX map |
| P1 | Disable listener | prevents reintroducing JIT |
| P2 | Packaging form (RX blob vs Mach-O) | distribution/signing |

## 6. Sources

- `ref/open-goal-jak-project/repo/game/runtime.cpp`
- `ref/open-goal-jak-project/repo/game/kernel/jak1/klink.cpp`
- `ref/open-goal-jak-project/repo/common/link_types.h`
- `ref/open-goal-jak-project/repo/goalc/emitter/ObjectGenerator.cpp`
- `ref/open-goal-jak-project/repo/game/kernel/jak1/kscheme.cpp`
- `ref/open-goal-jak-project/repo/game/mips2c/mips2c_table.cpp`
- `ref/open-goal-jak-project/repo/game/mips2c/readme.md`
- `ref/open-goal-jak-project/repo/game/kernel/asm_funcs_arm64.s`
- `ref/open-goal-jak-project/repo/game/kernel/common/kscheme.cpp`
- `ref/open-goal-jak-project/repo/goalc/emitter/CodeTester.cpp`
