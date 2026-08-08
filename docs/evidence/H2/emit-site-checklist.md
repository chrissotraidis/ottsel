# H2 — no-emit emit-site checklist (doc 08 verification)

Date: 2026-08-07. Patch: `patches/h2-noemit-runtime-host.patch` (extends H1 patch).
Host proofs all ran on Apple Silicon (macOS 26.5.2, arm64).

## Summary

Gate H2 result: **PASS (host)** — AOT-compiled ARM64 GOAL executes from RX-only
mappings; no writable code pages after load; no instruction writes during or
after load; the C→GOAL bridge and static C-export shims are proven without any
runtime instruction emission. Kernel-level integration (function objects on the
GOAL heap, full boot) remains H3 work and is explicitly listed below.

## Checklist (from `docs/08-emit-site-audit.md`)

| # | Site | Status in H2 | Evidence |
|---|---|---|---|
| A | `game/runtime.cpp` EE mmap RWX | **Split model proven.** Host proof maps code RX-only (never writable after load); `mach_vm_region` reports `R-X`, `mprotect(PROT_WRITE)` probe denied. EE-wide split stays host+Simulator work (H3/S1) | `run-h2-proof.log` |
| B | Link-time object rewriting (`klink.cpp`, link tables) | **Offline-resolvable path in place.** ARM64 intra-function jumps patched at finalize (`emit_function_code_only`); symbol/function/static link IRs implemented for ARM64 with link records that the H3 AOT pipeline resolves offline (no runtime instruction writes) | IR.cpp symbol lowerings; ObjectGenerator ARM jump patching |
| C | `make_function_from_c*` runtime stub emitters | **Static shim proven.** Static ARM64 trampoline reads C target from a writable `__DATA` slot; registration writes only data. `_arg_call_arm64`/`_stack_call_arm64` exist upstream; kernel integration (function objects) is H3 | `run-h2-shim.log`, `h2_static_shim.s` |
| D | mips2c dynamic stub synthesis | **Static entry design adopted** (same slot pattern as C shims). Table generation deferred to H3 boot; no emit remains | design in this doc |
| E | Listener / network `link_and_exec` | **Compile-time disabled under `OTTSEL_NO_EMIT`** (both jak1 + common klisten paths guarded); option wired in CMake | `game/kernel/jak1/klisten.cpp` |
| F | CodeTester `MAP_JIT` harness | Kept **host-only** (unchanged); not used by product proofs | — |
| G | `call_goal` / `call_goal_on_stack` ARM64 wiring | **Done + proven end-to-end.** `__aarch64__` branches call `_call_goal_asm_arm64` / `_call_goal_on_stack_asm_arm64`; bridge test assembles the real `asm_funcs_arm64.s` and runs AOT GOAL through it | `run-h2-bridge.log` |

## Proof artifacts

| Proof | Command | Result |
|---|---|---|
| RX-only AOT exec (5 GOAL fns: add/const/submul/branch/loop) | `./build/h1/goalc/ottsel-h2-proof` | `[H2] RX-ONLY EXEC PASS cases=5`; every region `protection=R-X`; code hash unchanged before/after; late `mprotect(PROT_WRITE)` denied |
| C→GOAL bridge via real asm helper | `./build/h1/goalc/ottsel-h2-bridge` | `[H2-bridge] PASS cases=3` (add/const/branch through `_call_goal_asm_arm64`) |
| Static C-export shim (no runtime instruction writes) | `./build/h1/goalc/ottsel-h2-shim` | `[H2-shim] PASS` — add(40,2)=42, triple(14)=42; shim code in `__TEXT` (RX), slots in `__DATA` (RW) |
| call_goal ARM64 wiring compiles | `clang++ -fsyntax-only game/kernel/common/kscheme.cpp` | clean (pre-existing format warnings only) |
| `OTTSEL_NO_EMIT` listener guard compiles | `clang++ -fsyntax-only -DOTTSEL_NO_EMIT ... jak1/klisten.cpp` | clean |

## What changed (compiler + runtime surface)

- `RegisterInfo`: ARM64 GPRs 0..31 and vectors 32..63 (disjoint ids; encoder
  fields mask `&31`). Fixes the GPR/vector id collision that corrupted
  prolog/epilog and spills on ARM64.
- ARM64 IR lowerings added: LoadSymbolPointer (`#f`/`#t`/`_empty_` + general),
  SetSymbolValue, GetSymbolValue, StaticVarAddr, StaticVarLoad, FunctionAddr,
  RegValAddr — all emitting offline-resolvable link records (no runtime writes).
- `do_goal_function_arm64` prolog/epilog with 16-byte stack discipline.
- `call_goal` / `call_goal_on_stack` `__aarch64__` branches (common kscheme).
- `OTTSEL_NO_EMIT` CMake option + listener code-receive guards.

## Honest boundaries (deferred to H3)

1. Kernel-level function objects on the GOAL heap: `make_function_from_c` still
   needs the static-slot shims wired into real boot; the slot pattern is proven
   standalone, not yet through `alloc_heap_object`.
2. mips2c static entry table generation.
3. Full EE memory split inside the game process (code vs data) and the first
   real GOAL boot (needs H3 assets pipeline).
4. Symbol/function link *resolution* into final AOT images (the offline prelink
   step), to be driven by H3's object pipeline.

None of these leave a runtime instruction-write path in the exercised host
proofs; each is a packaging/integration step for H3.
