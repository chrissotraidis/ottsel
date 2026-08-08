# STATUS — Ottsel

Date: 2026-08-07  
Repo: `ottsel`  
Mode: Phase 2 build loop (Bot 2) — Gate H1 active

## Gate board

| Gate | Title | Status | Evidence |
|---|---|---|---|
| G0–G5 | Phase 1 research (see archive below) | PASS | `docs/` 00–12 |
| **H1** | **ARM64 GOAL codegen works on host** | **PASS (2026-08-07)** | `docs/evidence/H1/` |
| **H2** | **No-emit runtime on host** | **PASS (2026-08-07, host)** | `docs/evidence/H2/` |
| **H2.5** | **Packaging form decision** | **PASS (2026-08-07)** | `docs/evidence/H2.5/`, `docs/10-code-packaging-and-signing.md` |
| H3 | Jak 1 host AOT boot proof | **PASS (2026-08-08, host)** — GOAL kernel dispatcher executes and loops under RX, no faults; evidence captured | `docs/evidence/H3/dispatcher-loop-2026-08-08.md`, `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log`, `docs/13-current-state.md`, `docs/BOT4_HANDOFF.md` |
| S1 | Simulator shell loads runtime | **BLOCKED (2026-08-08)** — S1.0/S1.1/S1.2 PASS; S1.3 reaches the gated-error fallback (explicit stop, no crash loop) but NOT the dispatcher loop: the no-emit symbol-slot resolution is order-dependent and reads empty/garbage function pointers on iOS (GOAL-side vs C-side resolve different entries for the same name). Stop report: `docs/reports/2026-08-08-stop-S1.md` | `docs/evidence/S1/` (S1.0-S1.2 evidence + s13 gated-stop logs/screenshots), `docs/reports/2026-08-08-stop-S1.md` |
| S2 | First frame proof | — | — |
| S3 | Touch MVP + lifecycle | — | — |
| R1 | Handoff package | — | — |

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
- **Boot slice NOT done:** no-emit object loader in `gk` (data-only relocs,
  RX-after-load), linking full kernel GOAL against C-kernel externs, and first
  real GOAL entry. 15 IRs still NYI (Asm family, vector swizzle/blend/sqrt).

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
