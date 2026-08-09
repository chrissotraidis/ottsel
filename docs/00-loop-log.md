# 00 — Loop log

## 2026-08-08 — Progress review (operator-requested, no gate work)

- **Acted:** Whole-repo review after the operator reported the system was
  having major problems progressing. Found the problems are structural, not
  technical: S1 was declared IN PROGRESS with zero scaffolding (`src/`,
  `scripts/` empty; no `evidence/S1/`); the H3 debug loop (20-min rebuild →
  boot → SIGILL hunt → one encoder fix) won't scale to GAME.CGO/engine
  code; Bot 3's two pre-S1 chores (stderr capture, windowed rebuild) were
  never executed — the durable H3 log contains **zero** dispatcher-loop
  lines (verified by grep); patch hygiene ambiguous (4 overlapping patches);
  disk down to ~16 GiB.
- **Acted:** wrote `docs/14-progress-review.md` (findings F1–F6 + S1
  sub-gate plan S1.0–S1.4); rewrote `docs/BOT4_HANDOFF.md` as the S1 goal
  prompt with the sub-gates (original preserved in git at `346a9da`);
  updated INDEX. Key scope decision recorded: **S1 is a headless-renderer
  shell — no OpenGL/GLES work inside S1**; first pixels are S2's Metal
  spike. Also recorded: build the emitter-validation harness (S1.1) before
  debugging any further boot fault.
- **Next:** Bot 4 executes S1.0 → S1.4 per `docs/BOT4_HANDOFF.md`.

## 2026-08-07 — Gate H1: ARM64 GOAL function codegen (Bot 2, first build loop)

### Iteration 1 — H1 worktree + ARM ABI
- **Selected:** H1 (lowest unfinished hard gate).
- **Acted:** Read docs 00–12 + BOT2_PROMPT; set up full pinned worktree
  (`out/jak-project` @ `641fb572e876750d8618434d9f7c1a531b43b366`);
  moved the stray ISO out of `ref/` to `~/ottsel-user/iso/`; wrote
  `docs/evidence/H1/arm64-abi.md`; made `RegisterInfo` ISA-aware
  (x86 default preserved; ARM64 args x0-x7, ret x0, pp x20, st x21, off x22).
- **Validated:** CMake configure succeeds on arm64 after dropping `-mavx`.
- **Learned:** ARM64 and x86 register enums overlap by id; RegisterInfo must be
  built per-ISA. Runtime asm helpers confirm x0 return / x20-x22 specials.

### Iteration 2 — function codegen + IR lowerings
- **Acted:** Implemented `do_goal_function_arm64` prolog/epilog; 16 IR lowerings
  (const/move/int+float math/load/store/branch/goto/call/return/null/nop/
  value-reset/stack-addr); added ARM64-aware jump patching (B imm26, B.cond
  imm19) in ObjectGenerator; single-function emit helpers for host proofs;
  `--isa` CLI flag for goalc.
- **Validated:** `ottsel-h1-proof` compiles+executes 5 GOAL functions on
  Apple Silicon: add2=42, const=123, submul=18, branch abs(-7)=7, id=99.
- **Learned:** upstream ARM64 encoder had real bugs (Hw `&4` should be `&3`,
  Imm16 shift 16 should be 5, bounds used `2 ^ N` XOR instead of pow2);
  fixed in patch. Defun top-level registration (FunctionAddr/symbol links)
  stays NYI — that is H2 code-model work, not H1.
- **Files changed:** patch `patches/h1-arm64-goal-function-codegen.patch`
  (15 upstream files + harness tool); `docs/STATUS.md`; `docs/evidence/H1/*`.

### Iteration 3 — CLI + reproducibility
- **Acted:** Verified `goalc --isa x86|arm64` both run; unknown ISA rejected
  cleanly; patch reverse-applies clean against pin.
- **Validated:** `[H1] PASS cases=5` in `docs/evidence/H1/run-h1-proof.log`.
- **Next:** H2 — no-emit runtime (symbol/function links, call_goal ARM wiring,
  static C/mips2c shims, permission proof).

## 2026-08-07 — Gate H2: no-emit runtime on host (Bot 2)

### Iteration 1 — RX-only AOT execution proof
- **Selected:** H2 (lowest unfinished hard gate).
- **Acted:** Wrote `ottsel-h2-proof` — compiles GOAL via real ARM64 codegen,
  maps code RW, then `mprotect` to RX-only (never writable after load);
  queries `mach_vm_region`; hashes bytes before/after execution; probes late
  `mprotect(PROT_WRITE)`.
- **Found (root cause):** the loop test crashed — ARM64 GPR ids (X0..X30=0..30,
  SP=31) and vector ids (V0..V31=0..31) collided, so `is_128bit_simd`/`is_gpr`
  both matched the same ids, corrupting prolog/epilog and spills.
- **Fixed:** disjoint ranges — GPRs 0..31, vectors 32..63; encoder field
  helpers mask `&31`. Added ARM64 symbol/static/function-address IR lowerings
  (LoadSymbolPointer, Set/GetSymbolValue, StaticVarAddr/Load, FunctionAddr,
  RegValAddr) with offline-resolvable link records.
- **Validated:** 5/5 RX-only exec (add2, const, submul, branch, loop), every
  region `R-X`, hashes unchanged, write probe denied.

### Iteration 2 — call_goal ARM64 bridge
- **Acted:** Wired `__aarch64__` branches in `call_goal` /
  `call_goal_on_stack` (common kscheme) to the existing
  `_call_goal_asm_arm64` / `_call_goal_on_stack_asm_arm64`; wrote
  `ottsel-h2-bridge` which assembles the real `asm_funcs_arm64.s` and calls
  AOT GOAL through the real helper; verified kscheme.cpp compiles clean.
- **Validated:** `[H2-bridge] PASS cases=3` (add/const/branch via C->GOAL).

### Iteration 3 — static C-export shim + no-emit flag
- **Acted:** Replaced the runtime-stub-emission pattern with a proven static
  shim: fixed ARM64 trampoline in `__TEXT` (RX) reads the C target from a
  writable `__DATA` slot — registration writes data only, never instructions.
  Added `OTTSEL_NO_EMIT` CMake option with listener code-receive guards
  (jak1 + common klisten) and verified they compile.
- **Validated:** `[H2-shim] PASS` (add(40,2)=42, triple(14)=42; shim RX, slots
  RW). Combined patch `patches/h2-noemit-runtime-host.patch` applies clean.
- **Learned:** upstream `_arg_call_arm64` reads its target off the stack with a
  convention that is awkward for direct shim use; a self-contained static
  shim + data slot is cleaner and provably no-emit.
- **Next:** H2.5 — packaging form decision (RX-blob probe vs Mach-O/generated
  native), updating `docs/10-code-packaging-and-signing.md` ADR table.

## 2026-08-07 — Gate H2.5: packaging form decision (Bot 2)

### Iteration 1 — generated-native path proof
- **Selected:** H2.5 (lowest unfinished hard gate).
- **Acted:** Wrote `ottsel-h25-proof` — real ARM64 codegen output packaged as
  assembly, assembled by clang into Mach-O objects, linked into native
  executables. Also linked the packaged loop into an executable and ran it.
- **Validated:** `[H2.5] MACH-O PACKAGING PATH PASS cases=3`;
  `aot_loop(10)=45` exit 0; `__TEXT,__text` section present; `codesign -s -`
  succeeds. Symbol access (`mov x8, x21` for `#f`) and branch patches
  survived packaging.
- **Learned:** Option 2/3 is not just plausible — the exact byte output of the
  ARM64 backend assembles into a signed native image and runs. This removes
  the "blob must be executed from anonymous memory" assumption entirely.

### Iteration 2 — ADR + evidence
- **Acted:** Updated the ADR table and decision section in
  `docs/10-code-packaging-and-signing.md`; wrote `docs/evidence/H2.5/`
  (commands, proof log, artifacts); updated STATUS.
- **Decision:** generated native code in the signed app (Option 2/3) is the
  product path; Option 1 RX-blob is host/Simulator research only. Accepted
  risks and explicit non-assumptions recorded (no JIT entitlements, no
  runtime executable mappings, Simulator != device).
- **Next:** H3 — Jak 1 host AOT boot proof with legal local assets (untracked),
  emitting self-contained generated-native artifacts per this ADR.

## 2026-08-07 — Gate H3, first iteration: real Jak 1 kernel compile (Bot 2)

### Iteration 1 — ARM64 goalc against real kernel sources
- **Selected:** H3 (lowest unfinished hard gate).
- **Acted:** Ran `goalc --isa arm64` on real `goal_src/jak1/kernel/*.gc`;
  fixed blockers in order: (1) `Allocator_v2` was hardcoded x86 (ARM64 floats
  colored to invalid ids → crash) — made ISA-aware via `RegisterInfo` orders;
  (2) ARM64 div/mod implemented (SDIV/UDIV/MSUB + x17 scratch, GOAL 32-bit
  sign semantics); (3) int128/vector asm IRs + int<->float copied from x86;
  (4) `static_addr` fixed to ADR (LEA) semantics + offline same-segment
  patching; (5) symbol access moved to the no-emit data-slot pattern
  (ADR-to-slot patched offline; runtime linker writes only the writable
  `sym - s7` slot); (6) ARM64 RIP link records suppressed (offline-resolved);
  (7) relaxed over-strict `addr != SP` asserts.
- **Validated:** `gcommon.o`, `gkernel-h.o`, `gstring-h.o`, `gstring.o`,
  `dgo-h.o` written for ARM64. All prior gates re-verified PASS.
- **Learned:** the runtime linker's `symlink_v3` writes `sym - s7` into any
  non-(-1) 32-bit slot — that is the exact data-only reloc doc 08 wanted;
  ARM64 symbol access can be entirely no-emit. `*stdcon*`-style externs are
  C-kernel-defined at boot, so the remaining kernel files need the boot
  pipeline, not more IR work.

### Iteration 2 — ISO extraction + first runtime boot attempt
- **Acted:** Built the host extractor; extracted the legal ISO to
  `out/jak-project/iso_data/jak1` (CGO/DGO/MUS/STR, SCUS-97124); built `gk`
  with `OTTSEL_NO_EMIT` and booted it with `-fakeiso`.
- **Validated:** `gk` launches SDL/OpenGL on Apple M1 (4.1 Metal), reaches the
  GOAL boot path, stops only for missing compiled `fr3` level data (expected —
  that is a later stage). Runtime init itself succeeds on arm64.
- **Learned:** retail `KERNEL.CGO` is MIPS; the boot must link ARM64-recompiled
  GOAL objects through a no-emit loader (data-only relocs, RX-after-load).
  `kernel-dispatcher` is set by the GOAL kernel top-level, then
  `KernelCheckAndDispatch` calls it — that is the first real GOAL entry.
- **Next:** H3 boot slice — implement the no-emit object loader path in `gk`
  (load AOT objects with data-only relocs into RX-after-load memory), link the
  full kernel GOAL, reach `kernel-dispatcher`.

## 2026-08-07/08 — Gate H3, second iteration: boot to GOAL top-level entry

### Iteration 1 — no-emit runtime boot
- **Acted:** Wired `gk` for `OTTSEL_NO_EMIT` boot: RW-only EE map (W^X),
  empty-`fr3` fallback so boot proceeds past graphics, RW→RX code flip after
  link (16KB page fix), ARM64 C-export stub bytes, `_arg_call_arm64` target
  read fix, on-stack helper restore fix, 16-byte goal-stack alignment.
- **Validated:** `gk -fakeiso -boot` boots: IOP starts, KERNEL.CGO (8 objects)
  loads, `gcommon` links with data-only relocs, code pages flip RX,
  `call_goal_on_stack` enters the ARM64 top-level (`fptr=0x70036b72e4`,
  correct st/offset). Process SIGILLs (rc=-4) on the first `mov-fa`
  (`function-identity`) because the ADR target is cross-segment and
  `patch_arm64_static_ref` only resolves same-segment refs.
- **Learned:** 16KB pages on Apple Silicon broke the RX flip (mprotect EINVAL
  on 4KB steps); `sysconf(_SC_PAGESIZE)` fixed it. Cross-segment function
  addresses are the last linker gap before the top-level returns and sets
  `kernel-dispatcher`.
- **Next:** resolve cross-segment ARM64 ADR at AOT finalize using the global
  link layout; then boot to `kernel-dispatcher` = first real GOAL entry.

## 2026-08-08 — H3 third iteration + session close (Bot 2)

### Iteration — ADRP+ADD cross-segment fix, then handoff
- **Acted:** re-enabled ARM64 RIP link records (`emit_link_rip`), made the
  runtime linker (`cross_seg_dist_link_v3`) ARM64-aware (ADR/ADRP+ADD/LDR-literal
  encoding), and changed `static_addr` to emit `ADRP+ADD` (±4GB reach) with
  both immediates patched offline and at link time. Rebuilt goalc/gk, rebuilt
  the ARM64 kernel, booted.
- **Result:** entry now starts `adrp x0; add x0,x0; sub x0,x0,x22` (valid);
  process still exits SIGILL (rc=-4) at a deeper instruction. Log:
  `docs/evidence/H3/boot-to-goal-entry-adrp-add.log`.
- **Learned:** the previous `adr` ±1MB limit was one real blocker; the next
  faulting PC is unknown and needs lldb/signal-handler debugging.
- **Session close:** wrote `docs/13-current-state.md` (authoritative state),
  `docs/BOT3_HANDOFF.md` (next-bot goal prompt), updated `STATUS.md`/`INDEX.md`,
  regenerated `patches/h3-jak1-host-boot.patch`. Stopping here per operator
  instruction; the next agent continues H3 from the docs.

## 2026-08-07 — Phase 1 research loop

### Iteration 1 — G0 scaffold
- **Selected:** G0 scaffold + reconstruct truncated brief.
- **Acted:** Created `DOCS/`, confirmed `ref/`, reconstructed full Phase 1 brief from intact constraints + gate language in the operator prompt.
- **Validated:** Indexes and brief exist; no assets present.
- **Learned:** Committed `jak1-researchloop.md` was truncated at 3167 bytes ending in `Record: update`. Used reconstructed brief as durable source of truth.

### Iteration 2 — G1 OpenGOAL architecture
- **Selected:** G1 architecture corpus.
- **Acted:** Sparse-cloned `open-goal/jak-project` at `641fb572e876750d8618434d9f7c1a531b43b366`; extracted architecture docs, emitter/runtime/kernel paths, macOS notes, ARM64 PRs.
- **Validated:** SOURCE.md + architecture doc cite commit, license, paths.
- **Learned:** Project is intentionally x86_64 native. ARM64 work exists but is incomplete.

### Iteration 3 — G2 execution model (hard gate)
- **Selected:** G2 AOT/no-RWX verdict.
- **Acted:** Mapped every runtime code-generation / executable-memory site found in source; compared Apple iOS constraints and adjacent AOT ports.
- **Validated:** Verdict document written with evidence table and Bot 2 stop conditions.
- **Learned:** Conditional-go only. Emitter lower half is partially present; IR→ARM64 and function prologues are NYI; runtime still needs RWX or a full AOT/no-emit redesign.

### Iteration 4 — G3/G4 platform + prior art
- **Selected:** Platform surface and adjacent prior art.
- **Acted:** Documented OpenGL/SDL3/iOS constraints; summarized HarkinianPad (AOT, no CPU JIT), AnnePad (static recomp), OpenTTDPad (native SDL) transfer lessons.
- **Validated:** Platform matrix + prior-art transfer/non-transfer notes exist.

### Iteration 5 — G5 roadmap + Bot 2
- **Selected:** Complete execution plan and Bot 2 prompt.
- **Acted:** Wrote gated roadmap, risks, safety rules, and self-contained Bot 2 goal loop.
- **Validated:** Phase 1 exit criteria checklist green in `STATUS.md`.


### Iteration 6 — Deep pass after critique
- **Selected:** strengthen Phase 1 evidence quality without reopening build work.
- **Acted:**
  - audited emit/link/call sites in source with counts
  - fetched OpenGOAL porting docs + 2026 progress reports
  - quantified ARM64 NYI surface and OpenGL renderer size
  - wrote docs 08–12; reinforced 01–06 and BOT2 prompt; added packaging gate H2.5
- **Validated:** verdict still CONDITIONAL GO; stop conditions and Bot 2 first proofs are now checklist-grade.
- **Learned:** the weak spot was not the high-level conclusion; it was insufficient mechanism-level evidence and packaging specificity.

## 2026-08-08 — H3 fourth iteration (Bot 3 continuation)

### Iteration — ARM64 load32u fix; dispatcher loop reached
- **Constraints (operator, binding):** test apps must never go fullscreen on
  this macOS; at most one `gk`/runtime process may run at a time.
- **Acted:**
  - Fixed `load32u_gpr64_gpr64_plus_gpr64` in `goalc/emitter/IGenARM64.cpp`:
    base `0b1011100001100000000010` → `0b1011100001100000111010`
    (was missing option/extend bits 13:10; emitted invalid word `0xb8760801`
    instead of `ldr w1,[x16,x22,sxtx]` = `0xb876ea01`; capstone-verified
    against `as -arch arm64` output).
  - Rebuilt goalc, regenerated KERNEL.CGO (`--isa arm64 -c
    '(load-project "goal_src/jak1/game.gp") (make "GROUP:kernel")'`), rebuilt
    gk.
- **Validated:** fresh lldb boot (`process launch -- -fakeiso -boot -v --
  -nosound`): all 8 KERNEL.CGO objects link; top-levels run under RX;
  `Got correct kernel version 2.0, loaded in 25 ms`; `kernel: machine
  started`; stub arena B flipped RX; then `KernelCheckAndDispatch` calls the
  GOAL `kernel-dispatcher` (fptr=`0x70001a5384`, inside gkernel main-segment
  RX code `0x1a0000..0x1a8000`) **repeatedly, each call returning cleanly**
  (`returned 1375532` = `0x14fd2c`) with no SIGILL for ~47s. Run ended with
  a graceful window-close EXIT (SDL quit → `MasterExit = EXIT`, code 2), not
  a crash. Prior blocker (`EXC_BAD_INSTRUCTION` at `0x70001a4998` from the
  broken load32u) is resolved.
- **Log:** `docs/evidence/H3/` boot capture pending a clean run.
- **Next:** capture verified dispatcher-loop evidence (lldb interrupt showing
  EE thread PC inside RX kernel code), then document H3 PASS in STATUS.md,
  regenerate `patches/h3-jak1-host-boot.patch` from the pin, verify with
  `git apply --check` on a fresh worktree, and write the S1 handoff note.

## 2026-08-08 — H3 fourth iteration, session end (Bot 3)

### Iteration — GOAL kernel dispatcher proven; full documentation + handoff
- **Acted:** fixed `load32u_gpr64_gpr64_plus_gpr64` base (option bits);
  rebuilt goalc + KERNEL.CGO + gk; two fresh lldb boots confirmed the GOAL
  `kernel-dispatcher` executes and loops with zero faults. Regenerated
  `patches/h3-jak1-host-boot.patch` (43 files) and verified
  `git apply --check` against the pin on a fresh worktree. Saved evidence
  log + wrote evidence README. Marked H3 PASS in STATUS.md. Wrote
  `docs/BOT4_HANDOFF.md` for the next agent.
- **Operator constraints (binding, recorded):**
  1. Test apps must never go fullscreen — the game window was opening in
     Borderless (display_mode 2). Fixed both ways: user
     `display-settings.json` → `display_mode: 0` (Windowed) and source
     default `game/settings/settings.h` → `Windowed` (rebuild gk for the
     source change; the settings file is immediate).
  2. At most one `gk`/runtime process at a time — always confirm zero
     instances before launching.
- **Validated:** dispatcher loop `returned 1375532` (idle-tree walk) under
  RX, minutes of uptime, graceful window-close EXIT. No SIGILL.
- **Honest boundary:** process pool idle (no listener/GAME.CGO) — no game
  processes created yet; that is S1+ scope. Durable stderr capture of the
  per-dispatch lines is the next agent's first 5-minute task.
- **Session close:** this run ends here per operator instruction; next agent
  continues from `docs/BOT4_HANDOFF.md`.

## 2026-08-08 — S1.0 chores (Bot 4)

### Iteration — durable stderr capture + Windowed rebuild + patch README
- **Acted:**
  - Verified source default `game/settings/settings.h` = `DisplayMode::Windowed`
    (line 64) and user settings `display-settings.json` `display_mode: 0`.
  - Rebuilt `gk` (binary was stale vs the settings.h change):
    `ninja -C build/h1 game/gk` (821 targets, OK).
  - Clean host boot with full capture: `./build/h1/game/gk -fakeiso -boot -v
    -- -nosound 2>&1 | tee`, ~70 s of dispatcher-loop uptime, stopped by
    operator (SIGINT).
  - Replaced `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log` with the
    full stdout+stderr capture (86,643 lines; superset of the old 216-line
    file). Updated `dispatcher-loop-2026-08-08.md` to document the refresh.
  - Wrote `patches/README.md` naming `h3-jak1-host-boot.patch` canonical;
    verified it reverse-applies cleanly to the worktree.
- **Validated (evidence):**
  - `grep -c call_goal_on_stack` on the durable log = **57,632** (was 0).
  - `grep -c "returned 1375532"` = 28,808 dispatcher-loop returns.
  - `[DISPLAY] windowed mode - resizing window to 1280x960` present (Windowed
    verified in-log); `kernel: machine started` present.
  - `pgrep -fl "gk -fakeiso"` → none after the run. One runtime at a time.
- **Files changed:** `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log`
  (replaced), `docs/evidence/H3/dispatcher-loop-2026-08-08.md` (updated),
  `patches/README.md` (new).
- **Next:** S1.1 emitter validation harness (validate every word of
  KERNEL.CGO; must catch the old `0xb8760801` load32u word).

## 2026-08-08 — S1.1 emitter validation harness + latent-encoding fixes (Bot 4)

### Iteration — harness built, 43 invalid kernel words found and fixed, PASS
- **Acted:**
  - Built `scripts/validate-arm64-emission.py`: decodes every code word of
    each object inside KERNEL.CGO via `as` + `llvm-objdump` (invalid
    encodings = "invalid instruction encoding" warning + address gap), plus
    an as-reassembly round-trip for non-PC-rel words and a hand-computed
    encoding check for PC-relative/literal instructions (Apple `as` cannot
    express cross-page adrp). 0xaeaeaeae function type-tag words skipped.
    `--selftest` must catch the known-bad `0xb8760801`.
  - Ran on the kernel: **43 invalid words** in gcommon/gkernel/pskernel main
    segments (div-family 0x1ac10000/0x1ac30000; 64-bit load-family
    0xf87608xx; vector load/store 0x3ce4/0x3ce3/0x3cb6) — all latent SIGILLs
    in code paths the H3 boot never executes.
  - Fixed `goalc/emitter/IGenARM64.cpp` (7 emitters): sdiv/udiv opcode bits;
    load64, store16, store32_xmm32 (also Rn/Rm swap), loadvf (also
    Rm(addr1)->Rm(addr2)), storevf — all missing the SXTX option bits
    (same class as the H3 load32u fix). Rebuilt goalc, regenerated
    KERNEL.CGO.
- **Validated (evidence in `docs/evidence/S1/`):**
  - `s11-harness-selftest.log`: SELFTEST PASS (catches 0xb8760801 at +0x4).
  - `s11-kernel-validation.log`: PASS — all 86,016 code words across 8
    objects validate (decode + round-trip); 226 type-tag words skipped.
  - `s11-host-boot-after-emitter-fixes.log`: host boot with the fixed
    kernel — `kernel: machine started`, Windowed 1280x960, 43,274
    `call_goal_on_stack` dispatcher-loop lines in 30 s, zero SIGILL.
  - `s11-emitter-validation.md`: family-by-family root cause + fix table.
  - Patch regenerated (`h3-jak1-host-boot.patch`, 37 files) and verified
    `git apply --check` on a fresh pin worktree.
- **Files changed:** `scripts/validate-arm64-emission.py` (new),
  `goalc/emitter/IGenARM64.cpp` (7 fixes), `docs/evidence/S1/*` (new),
  `patches/h3-jak1-host-boot.patch` (regenerated).
- **Next:** S1.2 — iOS Simulator app shell (src/ target, SDL3 window,
  renderer stubbed, listener disabled).

## 2026-08-08 — S1.2 iOS Simulator app shell (Bot 4)

### Iteration — SDL3 iOS shell launches on iPad Pro 11-inch (M4), lifecycle clean
- **Acted:**
  - Built SDL3 3.4.10 static for iphonesimulator arm64 (CMake
    `-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator26.5
    -DCMAKE_OSX_DEPLOYMENT_TARGET=18.5 -DSDL_STATIC=ON`) -> `out/ios/sdl/`.
  - Wrote `src/shell/main.cpp` (video-only SDL3, no renderer, window-surface
    fill, lifecycle logging via SDL_AddEventWatch, log file in app
    container), `src/shell/Info.plist` (bundle com.ottsel.shell, min iOS
    18.5), `scripts/build-ios-shell.sh` (compile with
    `-target arm64-apple-ios18.5-simulator`, full framework list, bundle +
    ad-hoc codesign).
  - Booted iPad Pro 11-inch (M4) simulator (only booted device), installed,
    launched.
- **Validated (evidence in `docs/evidence/S1/`):**
  - App visible on Simulator: `s12-shell-launch.png`,
    `s12-shell-window.png`.
  - Log `s12-shell-log.txt`: SDL init ok, window created (no renderer),
    surface filled; background (Settings) -> DID_ENTER_BACKGROUND (alive);
    foreground (relaunch) -> DID_ENTER_FOREGROUND (alive); same PID 53163
    through the cycle. No crash, no fullscreen flag.
- **Files changed:** `src/shell/main.cpp`, `src/shell/Info.plist`,
  `scripts/build-ios-shell.sh`, `docs/evidence/S1/s12-shell.md`,
  `docs/evidence/S1/s12-*.png|txt`.
- **Next:** S1.3 — link the no-emit runtime into the shell: EE memory map +
  RW->RX flip under the Simulator, bundle KERNEL.CGO as an app resource,
  boot to the dispatcher loop, log to file + visible surface.

## 2026-08-08 — S1.3 runtime boot in-app: gated-error fallback reached, root cause characterized (Bot 4)

### Iteration — iOS runtime links all 8 kernel objects with RX flips; dispatcher call faults; honest stop
- **Acted:**
  - Built the iOS runtime lib (common subset + game/kernel + sce + mips2c +
    ios_stubs, 62 objects) with OTTSEL_NO_EMIT + OTTSEL_IOS; app bundles
    KERNEL.CGO and boots the no-emit runtime on a background thread with the
    log tail rendered on the SDL window surface (5x7 bitmap font, no GPU).
  - Patched the worktree under OTTSEL_IOS: InitMachine skips IOP/gfx/sound/
    listener-connect; ksocket WaitForMessageAndAck returns null; mips2c table
    empty; InitHeapAndSymbol loads the kernel from the bundle
    (ottsel_ios_load_kernel_from_bundle) and (later) registers C exports
    before the link; InitListener value=0; gated signal handler installed.
- **Validated (evidence `docs/evidence/S1/s13-*`):**
  - EE memory mapped RW at 0x7000000000; all 8 KERNEL.CGO objects link with
    the same RW->RX code-page flips as the host; `Got correct kernel version
    2.0`; `kernel: machine started`; listener/REPL hard-disabled.
  - The GOAL kernel dispatcher's first calls fault (jump to EE offset 0 /
    SIGSEGV on a raw EE offset as a host address) because the no-emit
    symbol-slot resolution reads empty/garbage function pointers. The GOAL
    side and C side resolve *different symbol-table entries* for the same
    name (0x1982cc vs 0x198cb4) — an order-dependent linear-probe defect in
    OpenGOAL's intern interacting with the H3 no-emit slot scheme.
  - Gated error fallback works: `OTTSEL_IOS BOOT FAILED (gated): signal 10
    at pc=0x7000000000` -> clean exit, no crash loop, visible surface shows
    the log.
  - Host note: the same class of fault showed non-deterministically in one
    early rerun (1/3) but 4/4 clean in a later rerun; the H3 host boot
    remains otherwise reliable.
- **Files changed:** `src/shell/` (ios_boot, main, font, plist),
  `scripts/build-ios.sh`, worktree OTTSEL_IOS guards (kscheme, kmachine,
  klisten, ksocket, kdgo loader via ios_boot, mips2c, common kmachine,
  game/ios_stubs.cpp), `docs/reports/2026-08-08-stop-S1.md`.
- **Stop per loop rules:** same root cause (no-emit symbol-slot resolution)
  blocked S1.3 across 4+ manifestations with no working fix; stop report
  written with options (fix intern order-dependence; offline prelink;
  whack-a-mole patch). S1 = NOT PASSED (gated-error fallback met).

## 2026-08-08 — S1 PASS: dispatcher loop reached on Simulator (Bot 4 continuation)

### Iteration — root cause found: unregistered pc-prof + order-dependent intern; fixed
- **Acted:**
  - Traced the dispatcher fault to the FIRST GOAL statement,
    `(profiler-instant-event "ROOT")`, which calls the C export `pc-prof`.
    An OTTSEL_IOS early-return in `init_common_pc_port_functions` had skipped
    the PC-port registrations, so the symbol the GOAL side reads had value 0
    -> call to EE offset 0. Removed the guards (the headless stubs in
    game/ios_stubs.cpp cover the input/display/GFX symbols they reference).
  - Added an OTTSEL_IOS full-table fallback scan in `find_symbol_from_c`:
    the open-addressing probe is order-dependent; with thousands of kernel
    link interns a name can become unreachable from its hash position, so a
    later intern creates a second entry (measured: GOAL-side pc-prof entry
    0x1982cc vs C-side *listener-function* entry 0x198cac). The scan makes
    every intern of a name find the one canonical entry.
  - Reverted a wrong attempt (listener value = 0): the GOAL when-test
    compares *listener-function* against s7 and skips when equal, so the H3
    s7.offset sentinel is correct; the listener branch is a no-op.
  - Removed the ios_boot slot patch (it had been writing to the pc-prof
    entry); kept the InitHeapAndSymbol reorder (C exports interned before
    the kernel link).
- **Validated (evidence `docs/evidence/S1/s13-dispatcher-loop.*`):**
  - EE main memory mapped RW at 0x7000000000; all 8 KERNEL.CGO objects link
    with RW->RX flips; `Got correct kernel version 2.0, loaded in 8.1 ms`;
    `kernel: machine started`; listener/REPL hard-disabled.
  - **GOAL kernel dispatcher loop runs continuously on the iPad Pro 11-inch
    (M4) Simulator: 48,200+ iterations logged (`GOAL kernel dispatcher
    iteration N (running)`), process alive, zero crash reports.**
  - Visible surface screenshot captured (log rendered on the SDL window).
- **Files changed:** worktree kscheme.cpp (fallback scan + reorder already
  in), klisten.cpp (sentinel reverted), common/kmachine.cpp +
  jak1/kmachine.cpp (PC-port guards removed), kboot.cpp (iteration logging +
  debug dumps), src/shell/ios_boot.cpp (slot patch removed),
  docs/evidence/S1/s13-dispatcher-loop.*, docs/STATUS.md,
  docs/reports/2026-08-08-stop-S1.md (marked superseded).
- **Next:** S1.4 handoff (BOT5_HANDOFF.md for S2 = Metal/first-frame spike);
  regenerate + verify the canonical patch; commit.

## 2026-08-09 — Progress review + S2 loop authored (Bot 4 reviewer)

### Iteration — independently re-verified S1, reviewed BOT5_HANDOFF, wrote BOT5_PROMPT
- **Acted:**
  - Reviewed HEAD (`24c23e5`): S1 PASS commit `4b302cc`, S1.0–S1.3
    sub-gate commits, `docs/BOT5_HANDOFF.md` (S2 spec written by the S1
    agent), STATUS.md gate board, and the S1 evidence set.
  - Independently re-ran the S1 proof from the existing build
    (`xcrun simctl boot/install/launch` of `OttselShell.app` on the iPad
    Pro 11-inch (M4), iOS 18.5): EE map at `0x7000000000`, 8 objects
    linked, `Got correct kernel version 2.0, loaded in 15 ms`,
    `kernel: machine started`, dispatcher iteration lines advancing past
    31,600 in ~40 s, zero faults. Screenshot of the visible log surface
    captured. App terminated; Simulator shut down; verified zero booted
    devices, zero gk/lldb/OttselShell processes afterwards.
  - Read `docs/05-roadmap.md` P5/S2 bar to ground the next loop.
- **Assessment:** S1 PASS is genuine and reproducible; evidence and docs
  are consistent (STATUS, 13-current-state, BOT5_HANDOFF, S1 evidence all
  agree). BOT5_HANDOFF.md is complete and correct as the S2 spec — kept
  as-is. The missing piece was the paste-able goal loop for the next bot,
  which this turn adds as `docs/BOT5_PROMPT.md` (same convention as
  `docs/BOT2_PROMPT.md`).
- **S2 read-ahead (for the next bot):** the S2 bar is a real first frame
  from Jak 1 systems (no clear-color victory unless declared as a
  sub-gate); the product path is Metal; do not port the ~45k-line desktop
  OpenGL renderer; the biggest expected technical risk is the engine-side
  IR lowerings still NYI (15 IRs, incl. vector swizzle/blend/sqrt) plus
  GAME.CGO loading beyond the kernel.
- **Files changed:** `docs/00-loop-log.md` (this entry),
  `docs/BOT5_PROMPT.md` (new).
- **Next:** run the S2 loop from `docs/BOT5_PROMPT.md`.

## 2026-08-09 — Loop expanded: continuous S2 → S3 → R1 (operator-requested)

### Iteration — replaced stop-after-one-gate with checkpoint-continue
- **Operator question:** why does each bot stop after one gate? Analyze
  whether the loop should run longer.
- **Analysis:** the per-gate hard stop was a workaround for sessions dying
  at context limits (each gate ended with a fresh bot re-warming from
  docs). This environment auto-compacts, so a single goal can run for
  many hours — the stop now costs warm context (the S2 bot would re-derive
  renderer-seam knowledge) and an operator round-trip per gate, while
  buying nothing the checkpoints don't already buy. What genuinely
  protects the work is the checkpoint discipline (STATUS + evidence +
  commit + refreshed 13-current-state at every gate), not the stop. The
  real long-loop risks — stale-context drift after compaction and skipping
  proof — are mitigated by a resume rule and by keeping gate ordering
  strict.
- **Acted:**
  - Rewrote `docs/BOT5_PROMPT.md` as a continuous loop: gates S2 → S3 →
    R1 in order, checkpoint-continue semantics (no stop, no new prompt
    between gates), resume rule after compaction, operator constraints
    re-verified at every checkpoint, honest-stop conditions unchanged
    (3x same root cause or unsafe constraint), done condition = R1 PASS +
    "what's next" section in 13-current-state.md instead of a BOT6
    handoff.
  - Amended `docs/BOT5_HANDOFF.md` (§4 scope note + §8 prime directive) so
    it no longer instructs stop-after-S2 / write-BOT6.
- **Files changed:** `docs/BOT5_PROMPT.md` (rewritten),
  `docs/BOT5_HANDOFF.md` (amended), `docs/00-loop-log.md` (this entry).
- **Next:** run the continuous loop from `docs/BOT5_PROMPT.md`.

## 2026-08-09 — S2.0: Metal spike PASS (first frame through CAMetalLayer)

### Iteration — Metal pipeline in the shell, declared sub-gate S2.0
- **Acted:**
  - Read `docs/13-current-state.md`, `docs/BOT5_HANDOFF.md`, the S1 evidence,
    `docs/05-roadmap.md`, `docs/STATUS.md`, and the loop-log tail (resume
    rule). Operator state verified: zero gk processes, zero booted
    Simulators, 16 GiB free.
  - Built the Metal spike: `src/shell/metal_shell.{h,mm}` (CAMetalLayer
    device/queue/pipeline, textured fullscreen triangle, per-frame texture
    upload of the CPU log surface via SDL3's Metal view), rewired
    `src/shell/main.cpp` to render the log surface into a CPU RGBA buffer
    sized to the drawable and present it through Metal (SDL software
    surface kept as fallback), and updated `scripts/build-ios.sh`
    (`-fobjc-arc` + link the .mm).
  - Iterated on evidence quality: (1) pre-layout drawable is 480x320 and
    the simulator's windowed presentation keeps that size — the surface is
    now re-queried and resized per frame; (2) discovered the **S1 log font
    clipping bug**: `font5x7.h` rows use 7 bit-columns but the draw loop
    used `kFontW = 5`, dropping bits 5-6 of every glyph; fixed `kFontW`
    to 7 (this bug affected every S1/S2 log-surface screenshot).
  - Verified pixel-for-pixel: the presented surface matches an offline
    render of the same strings from the same font table at the same scale
    — title `ottsel S2.0 - Metal` 1746/1746 (100%), `GPU path: Metal`
    1566/1566 (100%).
  - Captured evidence under `docs/evidence/S2/`: Simulator screenshot
    (`s20-metal-frame.png`), the exact presented surface
    (`s20-metal-surface.ppm|png|-4x.png`), and the runtime log
    (`s20-runtime.log`: boot to the GOAL kernel dispatcher loop, 56,800+
    iterations, zero faults). App terminated, Simulator shut down,
    verified zero booted devices / zero gk / zero shell processes.
- **Result:** **S2.0 PASS (declared sub-gate)** — Metal first frame in the
  shell on the iPad Pro 11-inch (M4) Simulator. This is NOT yet a frame
  from Jak 1 game systems (that is S2.1/S2.2).
- **Files changed:** `src/shell/metal_shell.h`, `src/shell/metal_shell.mm`
  (new), `src/shell/main.cpp`, `scripts/build-ios.sh`,
  `docs/evidence/S2/s20-*`, `docs/STATUS.md`, `docs/00-loop-log.md` (this
  entry), `docs/13-current-state.md` (refresh follows).
- **Next:** S2.1 — wire the runtime's renderer-abstraction seams to Metal
  where cheap and identify the first real drawable (background/TIE/texture
  page path); read-ahead on GAME.CGO compile for ARM64 (expected NYI IR
  hits).

## 2026-08-09 — S2.1: GAME.CGO compiles for ARM64; 3.8M code words validate

### Iteration — full game engine codegen, emitter fixes, validation
- **Acted:**
  - Built the decompiler CLI and ran it data-only on the extracted ISO to
    produce the outputs GAME.CGO needs (`tpage-dir.txt`, `game_count.txt`,
    `raw_obj/tpage-*.go`): `Decompiler has finished successfully in 2.08
    seconds`.
  - Compiled the game: `(make "$OUT/iso/GAME.CGO")` -> **all 358 targets**,
    `GAME.CGO` 22 MB / 346 objects.
  - Fixed, in order of the compile failures they caused (each verified
    against clang-verified encodings and/or the emission validator):
    1. vector asm IRs NYI (`IR_BlendVF/SplatVF/SwizzleVF/SqrtVF`) — DUP,
       UMOV/INS cycle rotations (X16/X17 scratch), FSQRT wiring
    2. `VPSHUFLW/VPSHUFHW` — MOV + in-place 16-bit word rotation
    3. vector shift (`pw_sra/srl/sll`, `ph_srl/sll`) immh:immb encodings
    4. `shr/shl/sar_gpr64_u8` range (63 is legal)
    5. static vector load pattern -> `loadvf_rip_plus_s32`
    6. `IR_RegValAddr` stack-slot addressing (was a bogus register read
       that OOB'd the allocator in res.gc)
    7. `store128_gpr64_simd128_s32/s8` STR Q opcode width bug (10-bit
       opcode passed as Base(..., 22)) — this corrupted every 2-vector
       prologue store (`0x0003da09` garbage words)
    8. validator: skip data objects, `-march=armv8.5-a+faminmax`, `as`
       fallback for words Xcode's objdump can't disassemble (FAMIN/FAMAX)
  - Validated: `PASS: all 3801088 code words across 346 objects validate
    (decode + round-trip); 6107 type-tag words skipped`; `--selftest`
    still catches the known-bad word. Rebuilt + re-validated KERNEL.CGO
    (86016 words, 8 objects, PASS).
  - Renderer-seam read-ahead recorded in the evidence doc: first real
    drawable = background path via GfxRendererModule (make_display /
    texture_upload_now / send_chain), driven by the game renderer process
    through sceGraphicsInterface.
- **Result:** S2.1 progress milestone — the compile barrier to a genuine
  game frame is cleared; runtime boot of GAME.CGO + the Metal renderer
  module remain (S2.1/S2.2).
- **Files changed:** worktree `goalc/compiler/IR.cpp`,
  `goalc/emitter/IGenARM64.{h,cpp}`, `goalc/emitter/ObjectGenerator.cpp`
  (debug msg only); repo `scripts/validate-arm64-emission.py`,
  `docs/evidence/S2/s21-*`, `docs/STATUS.md`, `docs/00-loop-log.md` (this
  entry), `docs/13-current-state.md` (refresh follows).
- **Next:** link + boot GAME.CGO on the Simulator (no-emit linker, run
  game top-levels, start the process tree); expect new runtime codegen
  paths. Then the Metal renderer module for the first real drawable.

## 2026-08-09 — S2.1: GAME.CGO links on the Simulator; first runtime fault

### Iteration — on-device game linking, cross-segment load fix, fault located
- **Acted:**
  - Bundled GAME.CGO into the app and added a post-kernel link step
    (`ottsel_ios_link_cgo_from_bundle("GAME.CGO")`).
  - Object 2 (math) hit a **cross-segment LDR-literal overflow**:
    `diff=-37,356,532` on an LDR-S literal (float static load in the
    top-level segment, target 37 MB away). Converted the 32/64-bit and
    float pc-relative static loads to the ADRP + LDR-[X16,#imm12] pattern
    (±4 GB reach; runtime linker already patches ADRP+ADD pairs). GAME.CGO
    revalidated: 3,825,664 words PASS.
  - On-device: **36 of 346 objects link** (kernel + types-h..pad), then a
    gated SIGBUS at `pc=0x70001bfec4` (`st+0x20c0`, inside the GOAL heap):
    `lr=pad main+0x294`, where the disassembly shows a symbol-value call —
    load symbol -> value (+0x10) -> `blr`. The symbol's value field holds a
    heap pointer, not a function: the first runtime symbol-value resolution
    the game code exercises (same class as the S1 intern-order bug).
  - Kept the debug instrumentation (gated handler now logs
    pc/lr/st/offset/x16 + faulting words); evidence + boot log captured;
    app terminated, Simulator shut down (verified zero booted devices, no
    shell process).
- **Files changed:** worktree `goalc/emitter/IGenARM64.cpp` (pcRel loads),
  `game/kernel/jak1/klink.cpp` (overflow diagnostics); repo
  `src/shell/ios_boot.cpp` (GAME.CGO link + fault dump), `scripts/build-ios.sh`
  (bundle GAME.CGO), `docs/evidence/S2/s21-game-cgo-simboot.md`,
  `s21-simboot.log`, `docs/STATUS.md`, `docs/00-loop-log.md` (this entry),
  `docs/13-current-state.md` (refresh follows).
- **Next:** identify the symbol at `st+0x20c0` (or the call's argument) and
  fix the value-field resolution; continue linking the remaining 310
  objects; then the game process tree + Metal renderer module.

## 2026-08-09 — S2.1: first runtime fault localized (symbol-slot dispatch)

### Iteration — fault-site forensics on the Simulator
- **Acted:** instrumented the gated handler to dump GPRs, faulting words,
  the linked instructions at the call site (lr-0x40..), and named objects
  at the key pointers. Ran the boot to fault (pad object 36).
- **Findings (evidence-backed):**
  - Call site: pad main + 0x294 (`blr x3`), preceded by a symbol-slot
    dispatch: `ldrsw x2,[slot]; add x2,x2,x21(st); add x2,x2,x22(offset);
    ldr w2,[x2]; add x16,x2,x22; ldur w3,[x16,#0x10]; add x3,x3,x22;
    blr x3`.
  - The slot (pad main static data + 0x404c) is **0 at fault** — the
    runtime linker did not write (sym - s7) into it, so the dispatch
    resolved through st+0 into heap data and the `blr` hit a non-executable
    data page (SIGBUS, W^X).
  - The call target object (0x1bfec4) has a `function` type tag and a
    +0x10 field of 0x04f00484 (a plausible function region), so the
    correct function value exists — the slot-fill is the missing link.
  - This is the first GOAL method/global-function call the game code
    executes (kernel top-levels never ran this pattern).
- **Result:** root cause narrowed to the symbol-slot fill (the goalc-emitted
  LINK_SYMBOL_OFFSET record vs the runtime symlink_v3 write); the object's
  link-table parsing is the next diagnostic step (v3 per-segment table
  format confusion to resolve first).
- **Files changed:** `src/shell/ios_boot.cpp` (fault instrumentation,
  retained), `docs/evidence/S2/s21-game-cgo-simboot.md` (analysis
  updated), `docs/00-loop-log.md` (this entry).
- **Next:** parse pad's main-seg link table correctly and check the
  LINK_SYMBOL_OFFSET record for the slot at 0x404c; fix the slot-fill
  (emitter emission or runtime write); then continue linking.

## 2026-08-09 — S2.1: slot clobber root-caused (goalc static-layout overlap)

### Iteration — link-table + runtime-write forensics
- **Acted:** parsed pad's main-seg link table (records at the absolute
  object offset; 17 symbol records). Confirmed the `object` record targets
  the dispatch slot at 0x404c. Instrumented symlink_v3 to log every write
  (name, offset, data base, value after write) and dumped the static-data
  neighborhood at fault.
- **Findings:**
  - The runtime linker DID write `(object - s7) = 0x38` into
    data+0x404c (data = pad main 0x6b4000) — verified by post-write
    re-read.
  - At fault, the slot reads 0, while the sibling `object` slot at 0x4058
    is intact (0x38). The neighbors 0x4040..0x4048 hold runtime-written
    values (1, 0, 0) — a static structure spans 0x4040..0x404c and its
    GOAL-side initialization (during the top-level, between linking and the
    dispatch) zeroes the slot.
  - Conclusion: **goalc static-data layout overlap** — the symbol slot at
    0x404c shares space with another static object; the runtime linker is
    behaving correctly.
- **Result:** the next fix is in the goalc static layout
  (`add_static_to_seg` / finalize), not the runtime linker.
- **Files changed:** worktree `game/kernel/jak1/klink.cpp` (symlink write
  logging, retained), `src/shell/ios_boot.cpp` (static-data dumps, kept),
  `docs/evidence/S2/s21-game-cgo-simboot.md` (refined), `docs/00-loop-log.md`
  (this entry).
- **Next:** find the overlapping static in pad's allocation order (goalc
  side) and fix the layout so symbol slots never overlap initialized
  static objects; then continue linking the remaining 310 objects.

## 2026-08-09 — S2.1: static_load_f32 STR/Q bug fixed; linking 36 -> 48

### Iteration — pad slot-clobber root cause resolved
- **Root cause:** `static_load_f32` (my earlier ADRP conversion) used the
  STR base `0b0011110110` (a 16-byte `str q0`) instead of the LDR base
  `0b1011110101` (`ldr s0`). Every `(set! (-> obj float-field)
  <static-float>)` compiled to a 16-byte store INTO the static symbol
  slots; `cpad-invalid!`'s second such store hit 0x4040..0x404c and zeroed
  the `object` slot that `(method new cpad-info)`'s `(object-new ...)`
  dispatch reads. The linker writes were all correct (0x38 at 0x404c,
  verified); the clobber was the compiler's fault.
- **Fix:** `static_load_f32` -> `Base(0b1011110101, 10)` (verified:
  `ldr s0, [x16]` = `0xbd400200`).
- **Result:** linking now passes pad .. display (objects 36-48). Next
  fault: SIGSEGV at display main+0xa10, fault addr 0x76d664 — a raw
  EE-relative pointer dereferenced without the host base in a
  structure-copy sequence (`ldr q0, [x19], #0x7c`); goalc IR needed.
- **Also:** gated handler made fault-proof (mincore-probed safe reads);
  goalc debug prints removed; GAME.CGO (3,825,664 words) + KERNEL.CGO
  (86,016 words) revalidated PASS.
- **Files changed:** worktree `goalc/emitter/IGenARM64.cpp` (the fix +
  cleanup), `goalc/emitter/ObjectGenerator.cpp` + `goalc/compiler/CodeGenerator.cpp`
  (debug prints removed); repo `src/shell/ios_boot.cpp` (safe handler),
  `docs/evidence/S2/s21-game-cgo-simboot.md` (update),
  `docs/00-loop-log.md` (this entry).
- **Next:** dump the goalc IR for the display object's function at
  main+0xa10 (structure copy) and fix the address model; continue linking.

## 2026-08-09 — S2.1: linking 55 -> 204 (six runtime fixes); mood-tables fault localized

### Iteration — stack-alloc, mips2c, SIF, format, load16u, CGO-stage fixes
- **Fixed `IR_GetStackAddr` ARM64 offset==0 branch:** `mov_gpr64_gpr64(dst, SP)`
  emits `orr xd, xzr, xzr` (register 31 = xzr, never SP), so stack-variable
  addresses computed as 0.  scf-time's `(new 'stack-no-clear 'scf-time)` then
  dereferenced EE 0 (`strb wzr,[x1,x22]` fault at object 35).  Fix: always use
  the ADD-immediate form (`lea_reg_plus_off(dst, SP, off)`).
- **mips2c on ARM64 no-emit:** the iOS table was empty (engine wasn't linked
  before).  Implemented the jak1 table + link callbacks, pre-registration into
  the executable stub arena before the RX flip (kboot), an ARM64
  `_mips2c_call_arm64` dispatch (replacing the half-ported upstream block) that
  builds the ExecutionContext like the x86 `_mips2c_call_systemv`, and the
  `_call_goal8_asm_arm64` jalr declaration.  jak1_functions/*.cpp now build
  into the app.
- **SIF RPC stubs on iOS:** `sceSifCallRpc` asserted `mode == 1` (the sound
  loader uses sync mode 0) and deref'd a null IOP.  Made CallRpc/CheckStatRpc/
  BindRpc inert on OTTSEL_IOS + emulate the get-irx-version response (command
  12 -> 2.0) so `check-irx-version` passes instead of crash!-ing.
- **`_stack_call_arm64` arg-pair swap:** the stack-arg array was built as
  [x1,x0,x3,x2,...] instead of [x0..x7]; `(format 0 "IRX version...")` passed
  dest=0 as the format string -> NULL-deref.  Fixed the stp pairing.
- **`load16u_gpr64_gpr64_plus_gpr64_plus_s8` LDRH scaling bug:** the positive
  branch used LDRH's imm12 field (scaled by 2) with the raw offset, so
  `(-> type size)` read [type+0x10] instead of [type+8] and
  `(-> type heap-base)` read [type+0x18] instead of [type+12].  The
  inline-array-class `new` computed ~4MB for `(new 'global 'entity-perm-array
  4096)` -> kmalloc !alloc -> NULL perm-list -> NUL-write through 0.  Fixed to
  the unscaled LDURH form (matches load16s and the store).
- **CGO staging heap pressure:** the shell staged the whole 22MB GAME.CGO from
  the global-heap top (only ~3MB free at object 195).  Replaced with a single
  reusable 512KB stage slot (the linker copies each object out during link).
- **Result:** GAME.CGO linking on the Simulator advances from object 55 to
  **object 204 (mood-tables)**.  GAME.CGO revalidates 3,829,760 code words PASS.
- **Current fault (object 204, mood-tables):** `signal 10 at pc=0x7000000000`
  (jump/return to EE 0); LR = x22 (the EE base), i.e. a `ret`/`br` to x22.
  GOAL-stack walk shows the faulting function was called from the mood-tables
  top-level at +0x3a44 (return addr 0x3dafa48) = `make-village1-light-kit`
  (0x2924314).  Every symbol/slot in the verified chain
  (make-light-kit, matrix-rotate-y!, sin/cos, vector+float*!, vector*!,
  vector4-lerp!) reads a VALID function value; the deep ret-to-x22 mechanism
  is not yet identified (a live debugger that can breakpoint RX GOAL pages is
  the next tool; lldb cannot write breakpoints to RX-flipped pages).
- **Files changed:** worktree IR.cpp (GetStackAddr), IGenARM64.cpp (load16u),
  mips2c_table.{cpp,h}, mips2c_private.h, asm_funcs_arm64.s (mips2c dispatch,
  stack-call pair order), sif_ee.cpp, kboot.cpp, kmachine.cpp (via kscheme
  trace removed), kscheme.cpp (traces removed); repo ios_boot.cpp (reusable
  stage slot, rawlog gated handler with GOAL-stack LR walk),
  scripts/build-ios.sh (jak1 mips2c sources).
- **Next:** instrument a live call/ret tracer (or a debugger that can
  breakpoint RX pages) to find the ret-to-x22 inside the
  make-village1-light-kit call chain; continue linking objects 205-346.

## 2026-08-09 — Whole-repo audit and signed-AOT realignment

- **Reviewed:** all repo-owned planning/handoff docs, commit progression,
  shell/build sources, canonical patch state, evidence summaries/logs, asset
  hygiene, live process/Simulator state, and the active dirty object-204 probe.
- **Verdict:** the ARM64/S1/S2 technical work is valuable and should be kept,
  but the execution order drifted. H2.5 selected generated code in signed
  Mach-O text while S1/S2 expanded the Simulator-only CGO RW→RX transport.
  Renderer/touch work must wait for a real signed-native OpenGOAL proof.
- **Found:** the encoding validator correctly catches illegal words, but the
  latest defects were legal instructions with wrong semantics (STR/LDR,
  SP/xzr, scaled offsets, ABI pair ordering, call/return behavior). Future
  emitter/ABI fixes require focused semantic regression tests.
- **Updated:** `README.md`, `docs/INDEX.md`, `docs/STATUS.md`,
  `docs/05-roadmap.md`, `docs/13-current-state.md`, and historical Bot 5
  prompts. Added `docs/15-progress-audit.md` and the paste-ready
  `docs/BOT6_PROMPT.md`.
- **New order:** preserve the active dirty probe; A1.0 semantic regression
  layer; A1.1 real OpenGOAL artifact in signed Mach-O `__TEXT`; A1.2 no
  runtime-created executable-code proof; only then resume S2.1 -> S2.2 -> S3
  -> R1.
- **Validation during audit:** root/worktree `git diff --check`, build-script
  `bash -n`, validator Python compile, and validator known-bad selftest pass;
  tracked-asset scan found no ISO/CGO/DGO/VAG/STR/MUS/bin/img files. Full iOS
  rebuild was not started because an existing object-204 test process was
  already active.

## 2026-08-09 — R0: recover and normalize the active checkpoint (A1 realignment)

- **Goal realignment:** the user replaced the S2-first loop with the A1-first
  roadmap (BOT6_PROMPT.md). The signed-native execution model selected at H2.5
  must be proven before renderer/touch work; the RX-blob loader is
  diagnostic-only. Gate order: R0 -> A1.0 -> A1.1 -> A1.2 -> S2.1 -> S2.2 ->
  S3 -> R1.
- **Active experiment captured:** the object-204 call-trace probe (goalc
  IR_FunctionCall recorder shim emitting a nested blr to a C ring buffer,
  kscheme recorder + `g_ottsel_call_trace`, kmachine registration, handler
  dumps) was mid-flight with an iOS link failure (undefined symbols from the
  anonymous-namespace extern decl). Its value: the trap/recorder approach and
  the verified object-204 call-chain evidence (make-village1-light-kit ->
  make-light-kit -> matrix-rotate-y! -> sin/cos, all symbols/slots valid) are
  preserved for A1.0's bounded-trace requirement as
  `docs/evidence/A1/r0-call-trace-probe-{shell,goalc}.patch`.
- **Probes stripped:** goalc IR.cpp / kscheme.cpp / kmachine.cpp recorder
  shims removed; ios_boot.cpp restored to the committed gated-handler (rawlog
  pc/regs/GOAL-stack-LR walk, no hard-coded addresses); scratch mlkf/trap .o/.s
  removed; SIGTRAP handler reverted.
- **Docs restored:** docs/15-progress-audit.md and docs/BOT6_PROMPT.md
  (user-owned, untracked) were accidentally removed by a git clean exclusion
  mistake and restored verbatim from captured content.
- **Verified:** `grep` shows no probe remnants in goalc/game sources; the app
  builds clean (OttselShell 4007536 bytes); no runtime processes; Simulator
  shutdown pending; 16 GiB free.
- **Next:** A1.0 — extend the H1/H2 harness (tools/ottsel_h1) with semantic
  regression tests for SP->xzr, load-as-store, wrong widths, scaled offsets,
  ABI arg-pair swap, and LR/call/return preservation; reduce the object-204
  fault below the full boot loop.

## 2026-08-09 — A1.0: semantic regressions PASS; object-204 localized by bounded trace

- **Harness:** `out/jak-project/tools/ottsel_a1/semantic_regressions.cpp` +
  CMake target `ottsel-a1-sem` (same pattern as `ottsel-h1-proof`). 14/14
  assertions PASS: emitter-unit (static_load_f32 is LDR-s; load16u +s8 is
  LDURH; store16 STURH; `_stack_call_arm64` pair order via source scan) and
  goal-compile (SP->xzr ADD fix; u16 LDURH; non-leaf x30 save/restore; 2-level
  nesting).  Negative proofs: reintroducing STR-Q/scaled-LDRH fails 4
  assertions; swapping the asm pairs fails assertion 7 (after fixing the
  harness to include its own `ok` flag in the check).
- **Bounded trace (object-204 localization):** temporary goalc IR_FunctionCall
  recorder shim (push x0-x15+x16,x17; call `ottsel-goal-call-trace` C export;
  pop) + 256-entry ring + gated-handler dump.  First shim version clobbered
  x8 (the function-pointer register) -> every call jumped to garbage
  (display stall, `pc=0x70000000f3`); fixed by saving x8-x15.  Symbol-slot
  resolution needed +offset before the value read (SIGSEGV in the shim
  otherwise).  With the fix, one Simulator boot reproduces the object-204
  fault deterministically: trace-count 30,422; last calls mood-tables
  top-level -> 0x23d8554 -> 0x23d8004 -> 0x5ab0e4 -> 0x5fc574/0x5fd9d4 ->
  0x5a9234 (x3, site 0x23d8408 loop) -> `signal 10 at pc=0x7000000000`
  (x8=lr=0x7000000000 = x22).  The 0x5a9234 target is real SIMD matrix code
  (last-target dump), so the corruption is in the call/return state, not a
  garbage pointer.
- **Validator caveat:** the probe's `adr x1, .` site capture breaks the
  validator PC-rel round-trip (ADR byte immediate; no >>2) — legal A64, and
  the probe build is diagnostic only.  Product CGOs rebuilt clean validate
  PASS (KERNEL 86,016 / GAME 3,829,760 words).
- **Probe preserved** as `docs/evidence/A1/a1-bounded-call-trace-probe.patch`
  (with shim invariants); stripped from product sources (grep clean).
  Evidence: `docs/evidence/A1/a1-object204-bounded-trace.md`,
  `a1-mood-tables-bounded-trace.log`, `a1-semantic-regressions.md`.
- **Next:** A1.1 — real KERNEL.CGO dispatcher slice via the H2.5
  `.word`->clang->Mach-O `__TEXT` route, codesign, execute on the Simulator.

## 2026-08-09 — A1.0 committed (11885e0); A1.1 plan

- A1.0 checkpoint committed: semantic harness + evidence + regenerated patch.
- **A1.1 (next gate) plan — real KERNEL.CGO dispatcher slice in signed
  Mach-O __TEXT:**
  1. Tool: extend the H2.5 `.word`->clang route
     (`tools/ottsel_h2/h2_5_macho_packaging_proof.cpp`) into an A1.1 emitter
     that compiles a small REAL KERNEL slice (2-4 functions that call each
     other, read/write a symbol, and reference a static) through goalc ARM64.
  2. Offline relocation resolution: `emit_function_code_only` patches only
     intra-function jumps; static refs (link_instruction_static /
     link_instruction_to_function -> ADRP/ADD pairs) must be resolved to the
     final Mach-O addresses before assembling.  The runtime linker's
     `patch_arm64_static_ref` logic (ObjectGenerator.cpp) is the reference.
  3. Emit `.word` code + writable `.data` slots; clang -> Mach-O; link into
     OttselShell; `codesign -v`; execute the slice on the iPad Simulator
     with captured output; no runtime relocation of instructions.
  4. Minimum proof: multiple real GOAL functions in signed __TEXT, GOAL ABI
     calls work, static/function refs resolve, writable data works, artifact
     executes with output, no mprotect(PROT_EXEC).

## 2026-08-09 — A1.1 PASS: real KERNEL.CGO slice in signed Mach-O __TEXT on the Simulator

- **Gate A1.1 PASS.** The real Jak 1 kernel functions string=, name=, ref,
  last, nmember (verbatim from gstring.gc/gcommon.gc) execute from the
  OttselShell app's signed __TEXT on the iPad Pro 11-inch (M4) Simulator:
  all 7 checks ok (string=/name= semantics, ref/last on pairs, nmember
  dispatch through name=); `codesign -v` passes; log
  `docs/evidence/A1/a11-simulator-slice-pass.log`.
- **Tool:** `tools/ottsel_a1_1/a11_slice_emitter.cpp` (target
  `ottsel-a11-slice`) compiles the slice, applies the link tables OFFLINE
  (symbol/type slots st-relative, ADRP/ADD emitted as `label@PAGE/PAGEOFF`
  symbolic forms resolved by the Mach-O linker), and emits slice.s +
  a11_slice_map.h.  Address model: x22 = 0x100000000 (u32 GOAL ptrs =
  host - 2^32), x21 = data base + 0xa - off; only writable function/type-
  pointer tables filled at runtime (A1.2-compatible).  The proven
  `_call_goal_asm_arm64` bridge enters each function.
- **Host proof:** same slice passes all 7 checks on the host
  (a11_host_runner.cpp) — independent validation of the offline link model.
- **Key fixes:** test objects must live in the slice __DATA (Simulator
  malloc at 0x600000000000+ overflows u32 GOAL pointers); ADRP+ADD needs
  @PAGEOFF (Mach-O __DATA is not page-aligned); st is GOAL-relative.
- **Next: A1.2** — signed-AOT execution-permission proof: source audit +
  negative proof that the product target excludes the RX-blob execution
  path; runtime mutation limited to writable data/function tables.

## 2026-08-09 — A1.2 PASS: signed-AOT execution-permission proof

- **Gate A1.2 PASS.** Source audit: the signed-AOT path (a11_slice_runner +
  offline slice linker) has zero mprotect/PROT_EXEC/MAP_JIT/mmap calls; no
  CGO bytes read or executed; no code copied to the EE heap; no instruction
  patching at runtime (ADRP/ADD resolved offline by the Mach-O linker);
  runtime mutation limited to writable __DATA function/type-pointer tables.
- **Negative proof:** removed KERNEL.CGO + GAME.CGO from the app bundle,
  re-signed, ran: the slice proof still PASSES all 7 checks — the AOT
  artifact executes without any bundled CGO bytes.
- **Mach-O evidence:** slice code in (__TEXT,__text), data in
  (__DATA,__data); codesign -v PASS; Simulator runtime log PASS.
- **A1 gate complete** (A1.0 semantic regressions + object-204 localization;
  A1.1 real kernel slice in signed __TEXT; A1.2 execution-permission proof).
- **Next: S2.1** — resume GAME.CGO engine integration with the localized
  mood-tables fault (trace chain documented) + every emitter/ABI fix through
  the A1.0 regression harness.

## 2026-08-09 — A1 gate complete; S2.1 resumed (mood-tables fault reproduction)

- **Gate A1 PASS (committed 11885e0/2552c6b/ceca097):** A1.0 semantic
  regressions + object-204 bounded-trace localization; A1.1 real KERNEL.CGO
  slice in signed Mach-O __TEXT on the Simulator (all 7 checks, codesign
  verified); A1.2 execution-permission proof (audit + no-CGO negative
  proof).
- **S2.1 resumed:** the A1.0 call-trace probe is re-applied (product sources
  instrumented; preserved patch docs/evidence/A1/).  The A1.1 slice proof
  call is temporarily disabled (the offline slice linker doesn't resolve the
  trace symbol; re-enable after S2.1).
- **Fault reproduces deterministically:** GAME.CGO links all 346 objects;
  mood-tables (204) top-level faults at `signal 10 pc=0x7000000000`
  (ret/br to EE base); trace-count 30422; last calls: mood main 0x23d8004 ->
  0x5ab0e4 -> 0x5fc574/0x5fd9d4 -> 0x5a9234 (site 0x8408, x2); last-target
  code at 0x5a9234 = real SIMD matrix transform with `ret` at +0x5c.
- **Fault state:** x3 = 0x70005a9234 (the called fn host), x8 = x22 =
  0x7000000000, lr = x22 — a jump through a null/garbage pointer after the
  0x5a9234 call path.  Evidence: docs/evidence/S2/s21-mood-fault-*.log.
- **Next (S2.1):** decode the 0x5a9234 call/return path (post-index ldr q
  clobbers x1/x2; verify the caller's x30 slot) and the loop's next
  iteration; every fix through the A1.0 regression harness.

## 2026-08-09 — S2.1 root-cause analysis (mood-tables): call-site decode

- Decoded the mood main (0x23d8004, mood-tables blob 0x16b73 + 0x4):
  prologue pushes x19,x23-x26,x30 + sub sp,#0x40; calls: blr x2 (+0x12c),
  blr x16 (+0x32c), blr x3 (+0x37c = 0x5a9234 #1), recorder shim
  (+0x430), blr x3 (+0x480 = 0x5a9234 #2), epilogue ret (+0x54c).
  Straight-line static-float writes between the calls and the epilogue.
- Entry path verified: 0x23d8554 calls 0x23d8004 via `add x5,x5,x22;
  blr x5` (a real blr, not a tail call) -> x30 is valid at entry; the
  tail-call hypothesis is rejected for this path.
- Fault state: x3 = 0x70005a9234 (fn host of the in-flight 0x5a9234 call),
  x8 = x22 = 0x7000000000, lr = x22, pc = 0x7000000000 (executing EE base).
  Either a `br x8` through a null fn ptr (x8 = 0 + offset) or a `ret` with
  x30 = x22 after the 0x5a9234 call path.  Fault sp near the GOAL stack top
  suggests the fault is shallow (a call site in the mood main or a callee
  frame near the top-level).
- Next: dump the full GOAL stack + the saved-x30 slots of the faulting
  frame; check whether 0x5a9234's SIMD body (post-index ldr q clobbers
  x1/x2) corrupts the caller's frame; verify every fix through the A1.0
  regression harness.
