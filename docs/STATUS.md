# STATUS — Ottsel

Date: 2026-08-09
Repo: `ottsel`
Mode: Phase 2 build loop — **Gate A1 active (signed-native execution proof)**

Read `docs/15-progress-audit.md` before resuming. The Simulator RX-blob path is
a research transport, not the H2.5 product execution model.

## Gate board

| Gate | Title | Status | Evidence |
|---|---|---|---|
| G0–G5 | Phase 1 research (see archive below) | PASS | `docs/` 00–12 |
| **H1** | **ARM64 GOAL codegen works on host** | **PASS (2026-08-07)** | `docs/evidence/H1/` |
| **H2** | **No-emit runtime on host** | **PASS (2026-08-07, host)** | `docs/evidence/H2/` |
| **H2.5** | **Packaging form decision** | **PASS (2026-08-07)** | `docs/evidence/H2.5/`, `docs/10-code-packaging-and-signing.md` |
| H3 | Jak 1 host AOT boot proof | **PASS (2026-08-08, host)** — GOAL kernel dispatcher executes and loops under RX, no faults; evidence captured | `docs/evidence/H3/dispatcher-loop-2026-08-08.md`, `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log`, `docs/13-current-state.md`, `docs/BOT4_HANDOFF.md` |
| S1 | Simulator shell loads runtime | **PASS (2026-08-08)** — iPad Pro 11-inch (M4) Simulator launches the shell; the no-emit ARM64 runtime maps EE RW, links all 8 KERNEL.CGO objects with RW->RX flips, boots to the GOAL kernel dispatcher loop (48,200+ iterations, zero faults). Fix: register pc-prof/PC-port exports on iOS + full-table intern fallback scan; gated-error no-crash-loop safety net retained. | `docs/evidence/S1/s13-dispatcher-loop.md`, `docs/evidence/S1/s13-dispatcher-loop.log|png`, `docs/evidence/S1/s11-*`, `docs/evidence/S1/s12-*` |
| S2.0 | Metal shell spike | **PASS (2026-08-09)** — real CAMetalLayer pipeline presents the shell log surface; explicitly not a game frame | `docs/evidence/S2/s20-metal-spike.md`, `s20-*` |
| S2.1 | GAME.CGO engine integration | **RESEARCH CHECKPOINT (2026-08-09)** — all 346 objects compile; encoding validator passes; Simulator RX-blob linker reaches object 204, then deterministically ret/jumps to EE base in the `make-village1-light-kit` chain. Pause after preserving the active dirty probe; A1 is next. | `docs/evidence/S2/s21-game-cgo-arm64.md`, `docs/evidence/S2/s21-game-cgo-simboot.md`, `s21-*` |
| **A1.0** | **Semantic ARM64 regression layer** | **PASS (2026-08-09)** — 14/14 semantic assertions (load-vs-store, widths, scaled/unscaled, SP->xzr, ABI arg order, LR save/restore incl. 2-level nesting) with negative proofs; KERNEL.CGO 86,016 + GAME.CGO 3,829,760 words still validate; object-204 fault localized deterministically below the boot loop via a bounded GOAL->GOAL call trace (chain: mood-tables top-level -> 0x23d8554 -> 0x23d8004 -> 0x5ab0e4 -> 0x5fc574/0x5fd9d4 -> 0x5a9234 x3 from site 0x23d8408 -> ret/jump to EE base). | `docs/evidence/A1/a1-semantic-regressions.md`, `docs/evidence/A1/a1-object204-bounded-trace.md`, `docs/evidence/A1/a1-mood-tables-bounded-trace.log`, `docs/evidence/A1/a1-bounded-call-trace-probe.patch` |
| **A1.1** | **Real OpenGOAL code in signed Mach-O `__TEXT`** | **PASS (2026-08-09)** — real KERNEL.CGO slice (string=, name=, ref, last, nmember) linked into OttselShell __TEXT via the offline linker (tools/ottsel_a1_1), codesign verifies, all 7 checks execute on the iPad Simulator with captured output; no runtime instruction relocation. | `docs/evidence/A1/a11-signed-text-slice.md`, `a11-simulator-slice-pass.log` |
| **A1.2** | **Product execution-permission proof** | **PASS (2026-08-09)** — source audit (AOT path: no mprotect(PROT_EXEC)/MAP_JIT/code-copy/instruction-patching; runtime linking limited to writable data + function-pointer tables); negative proof: slice PASSES with KERNEL/GAME.CGO removed from the bundle; Mach-O/codesign/runtime evidence captured. | `docs/evidence/A1/a12-execution-permission-proof.md` |
| **A1** | **Signed-native OpenGOAL execution** | **PASS (2026-08-09)** — real OpenGOAL artifact executes from signed Mach-O text on the iPad Simulator with no runtime-created executable GOAL code (A1.0 + A1.1 + A1.2). | `docs/evidence/A1/*` |
| **S2.1** | **Complete game engine integration** | **VERIFIED STABLE TITLE BOOT (2026-08-15)** -- the previous deterministic enter-state fault is FIXED.  Root cause: `target-title` (title-obs.gc, a TIT.DGO object) was never linked -- the DGO loader skipped the PS2-v3 title objects as "non-GOAL", and GAME.CGO has no title-obs -- so `(go target-title)` stored 0 and enter-state called EE+0.  Fix (runtime-side): ship the recompiled TIT.DGO (no-emit title-obs/static-screen), accept the v3 "GOAL"-magic block tag in the DGO serve, and complete v3 links synchronously in link_begin.  Verified: zero faults, title-obs top-level runs, full process tree (24 nodes), dispatcher past 121k iterations, village1 load boundary handled ROM-safely.  S2.1 engine integration is at the renderer-ready boundary; S2.2 (first Jak frame via Metal) is next. | `docs/evidence/S2/s21-bot13-titlefix.md`, `s21-bot13-titlefix-*` |
| S2.2 | First real Jak 1 frame via Metal | **IN PROGRESS (2026-08-16)** — present-path regression fixed (c6b7104); the port's disabled mips2c `ln` calls are restored and GAME.CGO recompiled (7d44395a) so the game's tfrag draw pipeline runs (TFASM fires, tfrag-work draw-state set); the tfragment's stored dma-chain (the per-draw VIF stream incl. the frag-list header at VU 0x0) is located and an SPR->VIF1 scaffold parses it into VU memory.  Composed frame still needs the full VIF stream parse (DIRECT-embedded commands + far geometry UNPACKs) and the vis-list resolution (the port's draw-node-cull is disabled -> vis bit 0). | `docs/evidence/S2/s22-bot21-present-path-fixed.md`, `s22-bot21c-ln-restored.md` || S3 | Touch MVP + lifecycle | BLOCKED ON S2 | — |
| S2.2 | First real Jak 1 frame via Metal | **UNBLOCKED — LEVEL ACTIVATES (2026-08-16, BOT22)** — the "level never activates" blocker is RESOLVED and its premise disproven: the bsp write always landed (the probes read one word short — `bsp` is at ref+44, the inline kheap is 16-aligned at mem+32; 0x3fdd674 is `level-default`, not the loading level).  The real chain: the level pipeline is healthy through `'loaded`; the game was waiting for START on the title screen; no input path existed in the headless shell; and the title intro can never play (iso_data has NO STR files, so the spooled logo/ndi anims never load).  Fixes (runtime/shell only): synthetic pad bridge (taps/keys/file trigger press START), an EE-thread `(bg 'village1)` driver (the game's own debug boot-to-level entry), `play? = #f` (the genuine bg-flow state) and `*artist-all-visible* = #t` (the engine's artist toggle) for the no-VIS fallback.  Verified live, zero faults: village1 slot1 `'active` (bsp=0x2ef80d4), title discarded, background-work fills every frame (tfrag-count=1, tie-count=3 = the bsp's trees), the restored tie-ln RUNS with vis0=0xffffffff.  Remaining for the composed frame: the shell VU1 data path (VU1STAT: 2080 runs, zero GIF output — frag list empty at top=0; the tie microcode is not yet embedded) = Track B steps 2–4. | `docs/evidence/S2/s22-bot22-level-activation.md`, `s22-bot22-activation.log`, `s22-bot22-village1-active.png` || S3 | Touch MVP + lifecycle | BLOCKED ON S2 | — |
| R1 | ROM-safe handoff package | BLOCKED ON S3 | — |

## H1 result (2026-08-07)

- **PASS** — ARM64 `goalc` function codegen path works on Apple Silicon host.
- Pin: `open-goal/jak-project` @ `641fb572e876750d8618434d9f7c1a531b43b366` (unchanged from Phase 1).
- Patch: `patches/h1-arm64-goal-function-codegen.patch` (applies clean, verified).
- Proof: `ottsel-h1-proof` compiles and executes 5 GOAL functions (add/const/
  submul/branch/move) through `do_goal_function_arm64`; no NYI in exercised IR set.
- Evidence: `docs/evidence/H1/{commands,summary,arm64-abi,run-h1-proof,build-h1,cmake-configure}.md|log`
- Worktree: `out/jak-project` (build dir `out/jak-project/build/h1`, gitignored).
- Honest boundary: symbol/function-address IRs (`IR_FunctionAddr`,
  `IR_StaticVarAddr`, symbol links) remain NYI — deferred to H2's no-emit
  code model. `defun` top-level registration still needs them; H1 proves
  ordinary function bodies.

## H2 result (2026-08-07)

- **PASS (host)** — AOT ARM64 GOAL executes from RX-only mappings with
  permission + no-write evidence; `call_goal` ARM64 wired and proven;
  static C-export shim proven; listener code-receive compile-disabled under
  `OTTSEL_NO_EMIT`.
- Patch: `patches/h2-noemit-runtime-host.patch` (includes H1 changes; applies clean).
- Proofs: `docs/evidence/H2/run-h2-{proof,bridge,shim}.log` — all PASS.
- Emit-site checklist: `docs/evidence/H2/emit-site-checklist.md`.
- Also fixed in H2: ARM64 GPR/vector register-id collision (vectors now 32..63).
- Deferred to H3 (integration, not host-blocking): kernel function objects on
  the GOAL heap, mips2c static table, full EE code/data split, offline prelink
  of symbol/function links, first real GOAL boot.

## H2.5 result (2026-08-07)

- **PASS** — packaging decision recorded in `docs/10-code-packaging-and-signing.md`.
- **Decision:** product path = **generated native code compiled by clang into
  the signed app (Option 2/3)**. Option 1 (runtime RX blob) is research-only,
  not a ship path.
- Proof: real AOT GOAL bytes → `.s` → clang Mach-O (`__TEXT,__text`) → linked
  native executable → runs `aot_loop(10)=45` → code-signs. 3/3 cases.
- Evidence: `docs/evidence/H2.5/run-h25-proof.log`, `{add2,submul,loop}.{s,o}`,
  `aot_loop_native`, `commands.md`.
- Consequence for H3: AOT artifacts are self-contained generated-native images
  with offline-resolved links, not runtime-loaded executable blobs.

## H3 status (2026-08-07, first iteration)

- **Compile slice PASS:** 5 real Jak 1 kernel objects compile for ARM64
  (gcommon, gkernel-h, gstring-h, gstring, dgo-h) through the real codegen
  path with the no-emit data-slot symbol design.
- Patch: `patches/h3-jak1-kernel-arm64-compile.patch` (includes H1/H2/H2.5).
- Compiler fixes this iteration: ISA-aware `Allocator_v2`, ARM64 div/mod
  (SDIV/UDIV/MSUB), int128/vector asm IRs, int<->float, `static_addr` ADR
  semantics + offline patching, symbol data-slot relocations, SP spill asserts.
- **ISO extraction DONE:** legal ISO extracted to `out/jak-project/iso_data/jak1`
  (CGO/DGO/MUS/STR; SCUS-97124); gitignored.
- **Host runtime boots on arm64:** `gk` builds with `OTTSEL_NO_EMIT`, launches
  SDL/OpenGL (M1), stops only for missing compiled level data (fr3).
- **Historical checkpoint:** no-emit object loader in `gk` (data-only relocs,
  RX-after-load), linking full kernel GOAL against C-kernel externs, and first
  real GOAL entry were not yet done at this point. The later H3/S2 sections
  supersede this status.

## H3 status (2026-08-08, second iteration)

- **Boot reaches GOAL top-level entry:** `gk` boots with the no-emit runtime
  (RW EE map, code flipped RX post-link, kernel links via data-only relocs),
  and `call_goal_on_stack` enters the ARM64 top-level. Process then SIGILLs
  (rc=-4) on an unpatched cross-segment `mov-fa` ADR (`identity` function is in
  a different segment than the top-level; `patch_arm64_static_ref` only handles
  same-segment refs). Full detail: `docs/evidence/H3/boot-progress.md`.
- Fixed: ARM64 C-export stub bytes, `_arg_call_arm64` target read, on-stack
  helper restore, goal-stack 16-byte alignment, RW EE map + post-link RX flip
  with correct (16KB) page size.
- **Remaining:** cross-segment ARM64 function/static ADR resolution at AOT
  finalize; then the top-level can set `kernel-dispatcher`.

## H3 status (2026-08-08, fourth iteration — GOAL entry proven)

- Fixed `load32u_gpr64_gpr64_plus_gpr64` in `goalc/emitter/IGenARM64.cpp`
  (missing option bits; emitted invalid `0xb8760801` instead of
  `ldr w1,[x16,x22,sxtx]` = `0xb876ea01`).
- **PASS** — full boot: 8/8 KERNEL.CGO objects link, top-levels run under RX,
  `Got correct kernel version 2.0`, `kernel: machine started`, stub arenas
  A+B RX, and the GOAL `kernel-dispatcher` (fptr `0x70001a5384` in gkernel
  RX main code) executes and loops with zero faults. Runs ended via
  window-close EXIT, not crash.
- Patches regenerated from the pin: `patches/h3-jak1-host-boot.patch`
  (43 files, `git apply --check` verified on a fresh pin worktree).
- Operator constraints recorded: no fullscreen test windows
  (`display-settings.json` set to Windowed; source default changed), one
  `gk` process at a time.
- Evidence: `docs/evidence/H3/dispatcher-loop-2026-08-08.md` +
  `boot-dispatcher-loop-2026-08-08.log`. Honest boundary: dispatcher pool is
  idle (no listener/GAME.CGO), so no game processes yet — S1+ drives those.

## H3 status (2026-08-08, third iteration — handoff)

- Cross-segment function addresses now encode as `ADRP+ADD` (patched by the
  runtime linker), fixing the previous `adr` ±1MB range failure. The top-level
  entry now starts with valid `adrp x0; add x0,x0; sub x0,x0,x22`.
- The process still exits **SIGILL (rc=-4)** at a deeper instruction. The
  faulting PC is unknown; finding it is the next agent's first task.
- Full state, reproduction commands, and the next-bot goal are in
  `docs/13-current-state.md` and `docs/BOT3_HANDOFF.md`.
- Bot 2's session is complete; the repo is documented for continuation.

## Phase 1 archive (research)

- Verdict: CONDITIONAL GO — `docs/02-execution-model-verdict.md`.
- No game assets in git. ISO moved to `~/ottsel-user/iso/` (outside repo) on 2026-08-07.
- Upstream OpenGOAL: no mobile plans; x86_64 product path.

## S2.1 runtime linking (2026-08-09, updated)

- **PASS milestones this session (all verified on the iPad Pro 11-inch (M4)
  Simulator, no-emit runtime):**
  - GAME.CGO linking advances **55 -> 204 of 346 objects**.
  - Six runtime/emitter fixes: ARM64 stack-variable addressing (IR_GetStackAddr
    used ORR-to-xzr for `mov xd, sp`), mips2c ARM64 dispatch + pre-registration
    (jak1 table, ExecutionContext handler, jalr shim), iOS SIF RPC stubs +
    get-irx-version emulation, `_stack_call_arm64` arg-pair order (format calls),
    LDRH imm12 scaling in the 16-bit static-field load (type size/heap-base),
    and the reusable CGO stage slot (heap pressure).
  - GAME.CGO (3,829,760 code words) and KERNEL.CGO (86,016) revalidate PASS.
- **Current blocker:** object 204 (mood-tables) top-level -> `make-village1-light-kit`
  call chain faults with `signal 10 at pc=0x7000000000` (return/jump to the EE
  base).  All symbol/slot values in the chain verified valid; the deep ret-to-x22
  mechanism needs a live debugger that can breakpoint RX-flipped GOAL pages
  (lldb cannot write software breakpoints there).  Evidence:
  `docs/evidence/S2/s21-game-cgo-simboot.md` (updated 2026-08-09).

## Gate realignment (2026-08-09) — A1 active, per docs/15-progress-audit.md

The S2-first loop was stale. The signed-native execution model selected at
H2.5 must be proven before more renderer/touch work. The RX-blob Simulator
transport is diagnostic-only; it is not the product execution path.

| Gate | Title | Status | Evidence |
|---|---|---|---|
| R0 | Recover and normalize the active checkpoint | **DONE (2026-08-09)** — probes preserved as patch artifacts under `docs/evidence/A1/r0-call-trace-probe-*.patch`, stripped from product sources; docs agree on A1 | `docs/evidence/A1/r0-call-trace-probe-*.patch`, loop log |
| **A1.0** | Semantic ARM64 regression layer | **ACTIVE** — extend the H1/H2 harness with focused tests for the known legal-but-wrong defect classes; reduce the object-204 failure below the full boot loop | — |
| A1.1 | Real OpenGOAL code in signed Mach-O text | not started | — |
| A1.2 | Product execution-permission proof | not started | — |
| S2.1 | Complete engine integration (after A1) | paused at object 204 (RX-blob diagnostic) | `docs/evidence/S2/s21-game-cgo-simboot.md` |
| S2.2 | First real Jak 1 frame through Metal | not started (after A1 + S2.1) | — |
| S3 | Touch MVP + lifecycle | not started | — |
| R1 | ROM-safe handoff | not started | — |

Known semantic defect classes needing A1.0 regression tests: SP->xzr moves
(IR_GetStackAddr), loads emitted as stores (static_load_f32 STR/Q), wrong
load/store widths (LDRH imm12 scaling), scaled vs unscaled offsets, swapped
ABI argument pairs (_stack_call_arm64), LR/call/return corruption (object-204
value-0 call/return fault).
