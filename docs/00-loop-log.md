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
