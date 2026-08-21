# Jak 2 macOS ARM64 prior art — Ottsel transfer research

Date: 2026-08-20  
External project: [`DiMiTriFrog/jak2-macos-arm64`](https://github.com/DiMiTriFrog/jak2-macos-arm64)  
External snapshot inspected: `044b9254d175896620f5001cdcffd1f420321a3a`  
Shared OpenGOAL base: `641fb572e876750d8618434d9f7c1a531b43b366`  
Ottsel checkout inspected: `/Users/chrissotraidis/GitHub/ottsel`

## Executive verdict

The Jak 2 project is strong, directly comparable prior art for Ottsel's ARM64
compiler, ABI, linker, runtime-bridge, and controller-lifecycle work. It is not
a drop-in solution for Ottsel's current iPad/iPhone product blockers.

The most important fact is provenance: both projects started from the exact
same OpenGOAL commit, `641fb572`. That makes individual fixes and tests unusually
easy to compare. The useful unit is therefore a focused commit, test, or
invariant—not the published repository as a whole.

The external project's demonstrated product path is:

```text
Jak 2 GOAL sources
  -> ARM64 goalc/JIT code generation
  -> Apple ARM64 ABI/runtime bridges
  -> MAP_JIT plus W^X transitions
  -> existing desktop OpenGL renderer
  -> native macOS ARM64 gameplay
```

Ottsel's required product path is materially different:

```text
Jak 1 GOAL sources
  -> signed-native/no-runtime-emit artifacts
  -> Mach-O __TEXT execution
  -> iOS/iPadOS runtime and lifecycle
  -> native Metal renderer parity
  -> touch/controller/audio/user-data product integration
```

Consequently:

- **Reuse selectively:** ARM64 tests, encoding corrections, ABI invariants,
  bridge tests, linker ideas, and controller edge cases.
- **Do not import:** `MAP_JIT`, runtime-created executable memory, dynamic
  trampolines as a product dependency, or the fork's whole tree.
- **Do not redirect the current goal:** the linked project does not implement
  Direct/Sprite/TIE/TFRAG/Merc rendering in Metal and therefore does not solve
  Ottsel's current renderer-composition gate.
- **Do not reopen passed gates without a failing regression:** Ottsel already
  proves signed-native/no-runtime-executable-code ARM64 execution and real
  macOS Jak 1 gameplay.

## Evidence boundary

This investigation used the external repository, its commit history, source,
evidence notes, screenshot, build system, and tests. It also configured and
built the external `goalc-test` target locally on an Apple M1.

Verified during this investigation:

- The external branch descends from the same `641fb572` OpenGOAL pin used by
  Ottsel.
- The external current snapshot configures and builds natively on Apple M1.
- Its `*ARM64*` test selection passes 151/151 tests locally.
- Its AOT infrastructure selection passes 19/19 tests locally.
- Its AOT generator produces an inventory of 8,049 functions and 132 MIPS2C
  declarations.
- Its own AOT completeness verifier rejects that output because it contains no
  linked game code.
- Its Metal backend is a window/context/clear/present shell; the game-data
  callbacks are empty.
- Its dynamic macOS runtime explicitly uses `MAP_JIT`, W^X protection
  transitions, `mprotect`, and ARM64 instruction-cache invalidation.

Not independently verified during this investigation:

- A local Jak 2 title/menu/gameplay launch. The external repository correctly
  excludes the user's ISO and extracted protected data.
- A campaign-complete or controller-complete Jak 2 acceptance run.
- A signed/notarized redistributable build.
- A functional Jak 2 AOT game build.
- A functional Jak 2 Metal game frame.
- Any iOS/iPadOS gameplay from the external project.

The committed gameplay screenshot and handoff are meaningful supporting
evidence, but they are not a substitute for a fresh local asset-backed replay.
The external handoff itself leaves campaign, controller, multi-monitor,
hardware-matrix, signing, notarization, and Gatekeeper QA open.

## Repository relationship and merge risk

### Exact common ancestor

The external ARM64 sequence begins immediately after:

```text
641fb572 decompiler: misc gltf exporter fixes (#4371)
```

Ottsel's canonical maintained patch also targets:

```text
641fb572e876750d8618434d9f7c1a531b43b366
```

This is ideal for commit-by-commit archaeology and test transplantation.

### Why the repository must not be merged wholesale

The final published snapshot is intentionally Jak 2-focused. It removes Jak 1,
Jak 3, Jak X, decompiler data, tests, assets, and documentation outside that
scope. A base-to-snapshot diff reported 5,548 changed paths and roughly 3.85
million deleted lines. Those deletions are product-scope trimming, not ARM64
fixes.

A whole-tree merge would therefore:

- delete the Jak 1 sources Ottsel requires;
- collide with Ottsel's large maintained patch stack;
- replace signed-native execution with a dynamic JIT path in key areas;
- add Jak 2-specific GOAL and memory-layout changes;
- introduce incomplete AOT and Metal scaffolding that looks more mature than
  it is;
- obscure the current renderer/audio/input gate evidence.

The safe unit of reuse is one falsifiable regression and its smallest fix.

## What the external project implemented

### 1. Explicit target architecture and separated outputs

Early commits make ARM64 an explicit compiler target instead of inferring that
all GOAL output is x86-64. They add:

- target-architecture parsing and naming;
- ARM64-specific output paths;
- architecture-aware `ObjectGenerator` construction;
- build presets for native macOS ARM64;
- regressions that keep x86 output behavior unchanged.

Relevant commits:

- `11425627` — explicit target-architecture selection and separated outputs.
- `7313c6fe` — arch-specific build-directory hygiene.

Ottsel already has its own target/no-emit path. The value here is the test
matrix and explicit separation invariant, not a replacement build design.

### 2. Apple ARM64 register policy and ABI

Commit `670dc600` introduces architecture-specific register information across
the compiler and allocator. The associated tests cover:

- GPR and SIMD register names;
- argument and return registers;
- callee-saved registers;
- exclusion of reserved/scratch registers from allocation;
- exclusion of `x18` on Apple platforms;
- prevention of duplicate allocation-order entries;
- preservation of the existing x86 register model.

This is highly reusable. Ottsel independently repaired saved-register mapping
and thread-suspend behavior, but the external suite is broader and would make a
good second oracle.

### 3. Broad ARM64 emitter parity

The most valuable single external commit is `6e39095c`, which audits every
then-public `IGenARM64` method and adds a large executable parity suite.

The external audit reports corrections in these families:

- 32-bit immediate zero/sign extension;
- `AND` versus accidentally encoded `ADD`;
- compare operand fields;
- scalar `sqrt` and int/float conversion register fields;
- byte/halfword/word/dword register-offset loads and stores;
- scalar SIMD register-offset load/store addressing;
- signed and scaled offset selection;
- 128-bit loads/stores;
- vector arithmetic and bitwise opcodes;
- vector shift immediates;
- static 32/64-bit loads;
- instruction-cache flushing for executable test buffers.

Later commits add or correct:

- 32-bit signed/unsigned divide and remainder lowering (`adb54e50`);
- vector blend, swizzle, shuffle, and splat (`2b06048b`);
- `vpshuflw` and `vpshufhw` (`afd16d72`);
- ZIP1/ZIP2 semantics for the `pext*`/PUNPCK family (`b87cd1ab`).

Ottsel has already independently found several of the same failures: incorrect
AND encoding, SP/XZR confusion, conversion-source fields, ZIP versus UZP, and
instruction-cache invalidation. Agreement between the two efforts materially
increases confidence in those fixes.

The remaining value is coverage: run the external tests against Ottsel to find
untested public operations before they become rare-path gameplay faults.

### 4. Typed relocations and ARM64 object linking

Commits `3c31afec` and `4580b6ee` add:

- a typed relocation model rather than x86-only implicit link assumptions;
- ARM64 same-function forward/backward jump patching;
- rejection of out-of-range branches;
- explicit rejection of x86 RIP-function link forms on ARM64;
- tests for relocation validation and object-generator behavior.

Ottsel's AOT/no-emit object path differs, but these tests can still serve as an
independent oracle for branch ranges, relocation kind, and address-field
ownership.

### 5. ARM64 compiler IR lowering

The external sequence implements and tests ARM64 lowering across:

- core IR operations (`0c376d4a`);
- symbol and static references (`c2f7b734`);
- branches and function calls (`6d06138b`);
- scalar and vector memory (`a5bce43d`);
- scalar integer/float math and conversions (`b0a9a27b`);
- basic GOAL asm forms (`10f369a2`);
- vector operations (`33866fb8`);
- 128-bit operations (`9db26d69`);
- function prologues, epilogues, spills, and callee-save behavior (`59cd8138`).

The tests execute generated ARM64 rather than only checking whether an opcode
is legal. That matches Ottsel's established rule that legal A64 bytes are not
sufficient semantic or ABI proof.

### 6. Native runtime bridges

Commit `e60d4ec3` expands and tests the ARM64 assembly bridges for:

- C++ calls from GOAL;
- packed stack calls;
- MIPS2C contexts;
- GOAL calls with multiple arities;
- alternate GOAL stacks;
- nested and repeated calls;
- GPR/SIMD sentinel preservation;
- 16-byte stack alignment and restoration.

The suite is relevant to Ottsel even though Ottsel's final product executes
signed native code. Bridge contract tests do not require adopting the external
dynamic execution architecture.

### 7. Dynamic trampolines and MIPS2C registration

Commits `79ddc214` and `0b57ea29` implement ARM64 trampolines and connect Jak 2
MIPS2C functions through them. Tests cover:

- relocatable literal calls;
- full-width native pointers;
- process-pointer argument placement;
- stack-function argument ordering;
- zero/nothing return contracts;
- MIPS2C context layout;
- repeated patch/execute cycles.

The contracts and fixtures are useful. The runtime-emitted trampoline mechanism
is not acceptable as an Ottsel product dependency because it requires
executable anonymous memory.

### 8. Centralized Apple ARM64 JIT memory

Commit `f66f2cd3` consolidates dynamic executable-memory handling into a
`JitRegion`/`JitWriteScope` abstraction. It correctly addresses several macOS
ARM64 concerns:

- `MAP_JIT` allocation;
- page size from `sysconf(_SC_PAGESIZE)`;
- aligned protection ranges;
- RW/RX transitions rather than simultaneous write/execute on Apple ARM64;
- instruction-cache invalidation;
- scoped write phases;
- invalid range and misuse checks;
- JIT entitlement packaging.

This is good engineering for a native macOS development runtime. It is
explicitly incompatible with Ottsel's product contract:

```text
signed native Mach-O __TEXT
no runtime-created executable pages
no MAP_JIT product shortcut
no copied executable blobs
```

Do not import `common/jit_memory.h`, the JIT entitlement, function pools, or
dynamic trampolines into the shipping Ottsel path.

### 9. Jak 2 runtime-through-gameplay integration

Commit `b87cd1ab` is a broad integration checkpoint. It combines shared ARM64
fixes with Jak 2-specific runtime and GOAL changes, including:

- larger ARM64 memory/layout allowances;
- function-pool and linker behavior;
- bridge and stack corrections;
- fake-ISO/file/IOP integration;
- renderer and settings adjustments;
- Jak 2 kernel, loader, scene, camera, traffic, and state changes;
- emitter and compiler corrections discovered by live gameplay;
- expanded regressions.

This commit is valuable as a symptom-to-layer map, but unsafe as a cherry-pick.
It changes 71 files and mixes shared compiler fixes with Jak 2 game logic. Any
candidate must be extracted at its shared layer and proven against Jak 1.

### 10. Catch-frame and process-stack ownership

Commits `4f3b297c` and `8a6e6632` refine Jak 2 process/catch-frame behavior and
its fixtures. The recorded invariants include:

- private, non-overlapping process stacks;
- 16-byte ARM64 alignment;
- explicit saved-register mapping;
- continuation preservation across suspend/resume;
- normal-return and throw coverage;
- removal of diagnostic production instrumentation.

Ottsel independently solved a related but not identical ARM64 continuation
contract around asm-function BLR returns and synthetic GOAL-stack return slots.
The external fixtures can be used as cross-checks, but its Jak 2 GOAL source
changes must not replace Ottsel's verified Jak 1 contract.

### 11. SDL controller lifecycle

Commit `f0b5c55f` improves the desktop controller manager. Its handoff records:

- RAII freeing of `SDL_GetGamepads()` results;
- separation of SDL instance IDs, enumeration indices, and logical ports;
- `ADDED`, `REMOVED`, and `REMAPPED` event handling;
- batched refresh after event polling;
- reuse of surviving controller handles;
- closing only disappeared devices;
- clearing buttons, pressure, sticks, simulated state, and vibration on
  disconnect/reassignment;
- bounds checks before rumble/LED/DualSense effects;
- stopping effects before closing a handle.

Ottsel's current mobile shell already enumerates, opens, retains, filters,
neutralizes on removal, chooses a replacement, and re-enumerates on resume.
Potential missing coverage worth adapting:

- `SDL_EVENT_GAMEPAD_REMAPPED`;
- reusing a still-valid handle across refresh;
- explicit teardown of future rumble/trigger/LED effects;
- logical-port versus instance-ID invariants;
- remap while buttons or axes are active;
- duplicate add/remove event idempotence.

These should be added as focused I1 regressions, not by replacing the mobile
shell with the desktop input manager.

### 12. Fullscreen/Game Mode and macOS packaging

Commits `4db9ddd6` and `c4e1c709` add:

- transactional fullscreen changes with SDL error propagation;
- persistence only after a successful display-mode change;
- native fullscreen as the Apple ARM64 default;
- a one-time migration from older borderless settings;
- monitor-index validation and resource cleanup;
- an ARM64-only relocatable unsigned app bundle;
- Homebrew dependency discovery, `Frameworks` relocation, and RPATH rewriting;
- checks that packaged Mach-O files contain only ARM64;
- exclusion of ISO/extracted assets from the package.

This is useful macOS release hygiene but does not address iOS code signing,
provisioning, Files import, device installation, or mobile lifecycle. Ottsel's
current macOS reference also intentionally defaults to Windowed verification,
so these changes are not a current gate.

## The external AOT work is scaffolding, not a game solution

The published snapshot adds an AOT architecture with:

- execution-mode and graphics-backend build switches;
- AOT manifest and stable function-ID types;
- data-template relocation validation;
- a native bridge registry;
- deterministic Apple ARM64 assembly emission;
- AOT-oriented macOS/iOS presets;
- determinism and completeness scripts.

The infrastructure tests are useful and locally pass. However, the actual Jak
2 generator only scans source text for named forms and writes inventory
records. Every generated function has:

```text
code_size = 0
```

The build report explicitly says:

```json
"aot_code_generation": "not-yet-linked",
"complete": false
```

The repository's own `verify_aot_completeness.py` rejects this state with:

```text
AOT input is an inventory only; linked code generation is required before this gate
```

Therefore the AOT code should be treated as design/reference material only.
It is not evidence that Jak 2—or Jak 1—runs from signed Mach-O `__TEXT` without
runtime code generation. Ottsel already has stronger product evidence at this
boundary.

Potential long-term ideas worth retaining:

- stable IDs instead of embedding host pointers in descriptors;
- canonical manifest serialization;
- deterministic generated assembly ordering;
- data-template relocation validation before publication;
- explicit build-time separation between host generator and target runtime;
- a completeness gate that deliberately fails on inventory-only output.

These are architectural cleanup candidates after playability, not a reason to
rewrite Ottsel's passed execution foundation now.

## The external Metal work is a shell, not a renderer

The external Metal pipeline successfully establishes:

- SDL Metal window creation;
- `CAMetalLayer` ownership;
- Metal device and command queue creation;
- resize and event plumbing;
- a clear/present render pass.

But the renderer module's game callbacks are empty:

```text
metal_send_chain(...): no-op
metal_texture_upload_now(...): no-op
metal_texture_relocate(...): no-op
metal_set_levels(...): no-op
metal_set_active_levels(...): no-op
metal_force_reload_*(): no-op
metal_set_pmode_alp(...): no-op
```

Each frame only calls `clear_and_present(...)`, and the renderer identifies
itself as `Metal (frame-clear)`.

It contains no implementation for:

- Jak DMA-chain consumption;
- VIF/GIF ordering;
- GS state;
- texture/CLUT upload and lookup;
- Direct geometry;
- Sprite3 expansion;
- TIE/TFRAG;
- Merc;
- depth/blend/alpha/fog semantics;
- renderer bucket ordering;
- final game composition.

Ottsel's existing Metal work is substantially ahead of this shell. The linked
project must not alter the current D3/R1 renderer direction.

## Directly actionable Ottsel findings

### Finding J2R-01 — `sqrt_f32` has an independent red-test candidate

Current Ottsel source:

```cpp
InstructionARM64 sqrt_f32(Register dst, Register src) {
  return InstructionARM64(Base(...), Rn(src.id()), Rm(dst.id()));
}
```

AArch64 scalar `FSQRT <Sd>, <Sn>` places the destination in `Rd`, not `Rm`.
The external parity audit independently found and fixed exactly this field
selection and backs it with executable tests.

Recommended treatment:

1. Add a focused executable/assembler-checked regression with different source
   and destination register IDs.
2. Demonstrate the current failure.
3. Change only `Rm(dst.id())` to `Rd(dst.id())` if the red test confirms it.
4. Run Ottsel's existing semantic suite and a clean/reverse patch check.
5. Do not claim a renderer or gameplay advance from this compiler hygiene fix.

### Finding J2R-02 — public emitter coverage remains incomplete

Current Ottsel still contains public ARM64 emitter functions marked
`not yet implemented`, including:

- `blend_vf`;
- `swizzle_vf`;
- `shuffle_vf`;
- `vpshuflw`;
- `vpshufhw`.

Ottsel already implements some equivalent compiler behavior through targeted
IR sequences, so a stub is not automatically a live bug. The correct next step
is coverage classification:

1. Port or adapt the external tests.
2. Determine whether Jak 1 generation calls the public emitter function or an
   alternate lowering.
3. Keep unused API gaps separate from generated-artifact blockers.
4. Implement only a path reached by a failing regression or the Jak 1 corpus.

### Finding J2R-03 — external test breadth exceeds Ottsel's current suite

Ottsel's semantic harness is excellent at regressions found during real boot
and gameplay, but it is not a full public-method parity matrix. The external
suite adds breadth across:

- all addressing modes;
- source/destination aliasing;
- boundary immediates;
- signed/unsigned behavior;
- special floating-point values;
- vector lane permutations;
- branch range failures;
- spill and callee-save behavior;
- nested bridge calls;
- alternate-stack guard pages.

This is the highest-value reusable asset in the external project.

### Finding J2R-04 — controller remap/teardown tests can strengthen I1

Ottsel's mobile controller ownership boundary is already implemented and its
physical-controller acceptance remains open. Add the external remap and
teardown cases to the existing shell tests without changing the shared
`PadState` authority.

### Finding J2R-05 — the AOT completeness philosophy is worth adopting

The external AOT implementation is incomplete, but its explicit failing
completeness gate is good practice. Ottsel should preserve equivalent honesty:
an inventory, compiled object, signed binary, or first frame cannot silently
stand in for complete signed-native gameplay.

## Reuse matrix

| External work | Ottsel relevance | Action |
|---|---|---|
| `6e39095c` emitter parity suite | High | Adapt test-first in a clean worktree |
| `670dc600` register/ABI tests | High | Adapt Apple `x18` and callee-save coverage |
| IR test files from `0c376d4a` through `9db26d69` | High | Port compatible cases; classify API drift |
| `59cd8138` function-frame tests | High | Cross-check spills, epilogues, and saved registers |
| `e60d4ec3` runtime-bridge tests | High | Adapt contract tests without JIT product dependency |
| relocation/object-generator tests | Medium-high | Use for branch/range/link-kind validation |
| catch-frame fixtures | Medium | Compare invariants; retain verified Jak 1 design |
| SDL controller lifecycle | Medium | Add remap/teardown/idempotence cases to I1 |
| packaging script | Low-medium | Reference macOS RPATH/ARM64 audit only |
| stable AOT IDs/manifests | Long-term | Consider after playability gates |
| AOT generator | Not usable as game code | Inventory only; do not adopt as completion |
| Metal pipeline | Not useful for renderer parity | Shell only; Ottsel is already ahead |
| `JitRegion`/`MAP_JIT` | Prohibited for product | Do not import |
| full repository snapshot | Destructive/incompatible | Never merge wholesale |
| Jak 2 GOAL content changes | Wrong game layer | Do not port around shared compiler defects |

## Recommended bounded adoption loop

This research should augment, not replace, the current goal-based loop.

### Gate J2R0 — preserve current work and establish the comparison boundary

- Start with outer and `out/jak-project` status/identity checks.
- Preserve all existing user/builder changes.
- Use a clean temporary worktree based on `641fb572` for extraction trials.
- Record external snapshot `044b9254` and the exact candidate commit.
- Do not run a second game runtime or boot another Simulator.

Exit bar: the comparison is isolated from the active renderer/audio changes and
no protected assets or build products enter git.

### Gate J2R1 — extract tests before implementations

Start with the smallest compatible subsets:

1. `sqrt_f32` different-register execution/encoding.
2. Apple `x18` exclusion and saved-register uniqueness.
3. scalar/vector conversion source/destination aliasing.
4. register-offset load/store round-trips.
5. branch-range and relocation rejection.
6. bridge stack alignment and nested-call preservation.

Exit bar: each test either runs unchanged, is narrowly adapted with its
semantic intent preserved, or is documented as incompatible due to deliberate
Ottsel architecture—not silently dropped.

### Gate J2R2 — classify every failure

For each red test, record one classification:

- **Jak 1 live/generated:** affects the current Jak 1 compiler corpus or runtime.
- **Shared latent defect:** public shared operation is wrong but no current live
  use is proven.
- **Alternate lowering:** Ottsel provides the behavior elsewhere and the public
  stub is not reached.
- **JIT-only:** depends on dynamic executable memory and is not a product path.
- **Jak 2-specific:** depends on Jak 2 GOAL/runtime layout.
- **Test/API drift:** assertion must be adapted before it is meaningful.

Exit bar: no implementation is imported without a failing, correctly classified
regression.

### Gate J2R3 — apply only minimal shared fixes

- Fix one shared defect at a time.
- Run the new test, Ottsel semantic regressions, affected compiler target,
  `git diff --check`, and maintained-patch clean/reverse checks.
- Rebuild a product binary only if the affected code is in that product path.
- Do not reopen signed-native A1 gates unless binary/protection evidence changes.

Exit bar: regression passes, unrelated Ottsel behavior remains green, and the
canonical maintained patch includes the change.

### Gate J2R4 — strengthen controller lifecycle separately

- Add `REMAPPED` and duplicate-event tests.
- Verify active state neutralizes on remove/remap.
- Verify replacement selection does not accept stale instance events.
- Preserve one selected pad-0 owner.
- Retain physical-controller acceptance as open until real hardware proof.

Exit bar: focused tests pass and one hardware add/input/remap/remove/reconnect
replay passes when hardware is available.

### Gate J2R5 — return to the existing first open product gate

The research loop must yield back to the current Ottsel dependency queue. It
must not become a new indefinite compiler rewrite. Current product work remains
renderer composition, touch/input completion, audio product integration,
iPhone parity, physical-device acceptance, packaging, and legal user-data UX.

Exit bar: the builder updates its own goal-based loop only where a finding
changes a concrete dependency or adds a bounded regression; otherwise it
records the research as supplemental and continues its current gate.

## Non-negotiable constraints for any reuse

- Preserve signed native Mach-O `__TEXT` execution.
- Never introduce `MAP_JIT`, RWX, runtime-created executable pages, or copied
  executable blobs into the product path.
- Never patch Jak 1 GOAL content to avoid a shared compiler/runtime defect.
- Never import Jak 2 game-specific content as a compiler fix.
- Never merge the external snapshot wholesale.
- Never commit an ISO, extracted retail data, saves, audio/video banks, build
  products, signing material, or secrets.
- Never call a test pass, signed build, first frame, decoded PCM, or Simulator
  result product completion.
- Keep one runtime and one booted Simulator maximum.
- Preserve current dirty user/builder work and the canonical patch mechanism.

## Source map

Primary external sources:

- Repository and scope: <https://github.com/DiMiTriFrog/jak2-macos-arm64>
- Full emitter parity commit:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/commit/6e39095c>
- Runtime-through-gameplay integration:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/commit/b87cd1ab>
- Centralized JIT memory:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/commit/f66f2cd3>
- Implementation handoff:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/blob/main/evidence/ARM-025-full-implementation-handoff.md>
- AOT generator:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/blob/main/goalc/aot/Jak2AotGenerator.cpp>
- AOT completeness verifier:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/blob/main/scripts/verify_aot_completeness.py>
- Metal pipeline:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/blob/main/game/graphics/pipelines/metal.mm>
- JIT memory implementation:
  <https://github.com/DiMiTriFrog/jak2-macos-arm64/blob/main/common/jit_memory.h>

Relevant Ottsel sources:

- `docs/STATUS.md`
- `docs/BOT33_PROMPT.md`
- `docs/15-macos-to-mobile-goal-loop.md`
- `docs/evidence/I1/i1-gamepad-ownership-2026-08-20.md`
- `patches/README.md`
- `out/jak-project/goalc/emitter/IGenARM64.cpp`
- `out/jak-project/tools/ottsel_a1/semantic_regressions.cpp`

## Final decision

The external project validates Ottsel's original diagnosis: OpenGOAL's 2026
ARM64 backend was incomplete, but a real native Apple ARM64 runtime was
achievable through systematic compiler, ABI, bridge, linker, and live-game
work. Ottsel has already crossed that foundation using a stricter signed-native
execution model.

The external project's best contribution now is a second, broader regression
oracle. Use it to harden Ottsel's compiler and controller edges without
changing the active product architecture. It provides no shortcut around the
remaining Metal renderer, mobile audio, touch, iPhone, or physical-device work.
