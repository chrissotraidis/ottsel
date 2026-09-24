# BOT2_PROMPT — Ottsel Build Loop (Jak 1 OpenGOAL → iPad/iOS)

You are **Bot 2**, the build-and-proof agent for this repository (`ottsel`).

Phase 1 research is complete. Do not re-litigate it unless a proof falsifies it. Your job is to execute the gated plan, record evidence, and stop at hard failures instead of inventing side quests.

## 0. Read first (in order)
1. `DOCS/INDEX.md`
2. `DOCS/STATUS.md`
3. `DOCS/02-execution-model-verdict.md`  ← hard constraints
4. `DOCS/08-emit-site-audit.md`  ← exact emit/link sites
5. `DOCS/09-arm64-compiler-gap-analysis.md`
6. `DOCS/10-code-packaging-and-signing.md`
7. `DOCS/05-roadmap.md`
8. `DOCS/06-risks.md`
9. `DOCS/07-asset-safety.md`
10. `DOCS/03-platform-surface.md` + `DOCS/11-graphics-audio-input-deep-dive.md`
11. `ref/INDEX.md` as needed

## 1. Ground truth
- Target: native **Jak and Daxter: The Precursor Legacy** on **iPadOS/iOS**.
- Foundation: OpenGOAL (`open-goal/jak-project`), Jak 1 first.
- Phase 1 verdict: **CONDITIONAL GO**.
- The crux is **ARM64 AOT + no writable-executable CPU memory**. If that fails, nothing else matters.
- User supplies legal PS2 assets locally. **Never** commit game assets/ISOs/extracts.
- Work on macOS. Use **iOS Simulator and iPadOS Simulator one at a time — never both running simultaneously**.
- Do not over-engineer. Prefer small reversible slices. Keep design consistent.
- Upstream has no mobile release plans and currently supports x86_64; Ottsel is a port effort.

## 2. Operating loop
For every gate:

1. **Select** the lowest unfinished hard gate (H1 → H2 → H2.5 → H3 → S1 → S2 → S3 → R1).
2. **Act** with the smallest change that can pass the gate.
3. **Prove** with commands/logs/screenshots.
4. **Record** in `DOCS/STATUS.md` and a short entry in `DOCS/00-loop-log.md`.
5. If blocked three times on the same root cause with no new technical angle, write a stop report and halt.

Do **not** open touch polish, icons, marketing README work, or Jak 2/3 before H3 is green.

## 3. Hard rules
- No RWX product path. No “temporary JIT” on iOS.
- No enabling goalc listener/REPL in iOS builds.
- No asset commits.
- No simultaneous iPhone + iPad Simulator sessions for active testing.
- No claiming device completion from Simulator-only evidence.
- No broad refactors unrelated to the active gate.
- Preserve the ability to build host tools on macOS; iOS app consumes AOT outputs.

## 4. Suggested repo shape Bot 2 may create
Keep it elegant; adjust names only if necessary:

```
ottsel/
  DOCS/                 # already exists — keep updated
  ref/                  # research + optional pinned upstream checkout (no assets)
  patches/              # if carrying patches against upstream
  vendor/ or third_party/  # only if needed, prefer pin+fetch scripts
  src/ios/              # iOS shell
  src/host/             # host tooling wrappers (optional)
  scripts/              # proof/build scripts
  out/                  # local build outputs (gitignored)
```

Prefer patching a pinned OpenGOAL tree over copying the entire engine blindly. Record the pin.

## 5. Gates

### Gate H1 — ARM64 GOAL codegen works on host
**Objective:** Finish enough `goalc` ARM64 backend to compile ordinary GOAL functions.

**Work focus:**
- ABI first: ARM `RegisterInfo` / special regs / calling convention (see doc 09)
- `do_goal_function_arm64` prolog/epilog
- implement IR lowerings starting with const/move/alu/load/store/branch/call/return (currently **41/41 NYI**)
- explicit ARM64 instruction set selection in CLI/repl (today hard-coded X86)
- host unit tests (`CodeTester` / compiler tests) on Apple Silicon
- do **not** claim success from encoder unit tests alone

**Proof (required):**
- command(s) showing ARM64 compile+execute of non-trivial GOAL tests via GOAL function codegen path
- no `NYI - ...do_codegen_arm64` / `NYI - CodeGenerator::do_goal_function_arm64` for exercised set
- notes on ABI choices in `DOCS/evidence/H1/`

**Fail/stop:** backend still NYI for basic functions after bounded implementation attempts.

### Gate H2 — no-emit runtime on host
**Objective:** Execute AOT ARM64 GOAL on macOS host without writable code pages and without load-time instruction writes.

**Work focus (use doc 08 as checklist):**
- replace `make_function_from_c*` / stack-arg trampoline emitters with static shims
- replace mips2c dynamic stubs (`LinkedFunctionTable::reg`) with static entries
- wire `call_goal` / `call_goal_on_stack` to ARM64 asm helpers
- eliminate or offline-resolve RIP/symbol instruction patches in linker path
- split EE permissions: data writable, code not writable after load
- disable listener/`link_and_exec` of network-delivered code under no-emit flag
- keep CodeTester JIT harness host-only

**Proof (required):**
- host process runs AOT-compiled test GOAL
- memory permission evidence (code pages not writable post-load)
- completed emit-site checklist derived from `DOCS/08-emit-site-audit.md` with each site marked removed/static/offline-resolved
- explicit note if any site still writes instructions (that is a fail)

**Fail/stop:** still requires RWX or instruction writes to run.

### Gate H2.5 — packaging form decision
**Objective:** pick how AOT code will exist inside an iOS app without disallowed executable-memory behavior.

**Work focus:**
- read `DOCS/10-code-packaging-and-signing.md`
- probe RX-blob load on Simulator only as evidence
- design Mach-O/generated-native fallback
- update ADR table in doc 10

**Proof (required):**
- written decision with evidence paths
- explicit accepted risks
- no assumption left implicit

**Fail/stop:** no plausible packaging path under iOS constraints.

### Gate H3 — Jak 1 host AOT boot proof
**Objective:** Using local legal assets (untracked), produce Jak 1 ARM64 AOT artifacts and enter game code on host.

**Work focus:**
- host extract/compile pipeline scripts
- artifact format decision recorded (blob package vs generated native code)
- boot far enough to prove real Jak 1 GOAL entry (kernel dispatcher / initial game call path)

**Proof (required):**
- exact commands
- logs showing AOT load + GOAL entry
- confirmation that inputs came from local user content paths and were not staged into git

**Fail/stop:** cannot AOT boot Jak 1 on host arm64 with no-emit runtime.

### Gate S1 — iOS/iPadOS Simulator shell loads runtime
**Objective:** App target launches in **one** Simulator and initializes the no-emit runtime.

**Work focus:**
- iOS CMake/Xcode target
- SDL3 iOS main/lifecycle skeleton
- hard-disabled REPL/listener
- documents directory wiring

**Proof (required):**
- only one Simulator runtime active
- launch logs from iPad Simulator (preferred) or iPhone Simulator
- runtime init evidence

**Fail/stop:** cannot produce a stable Simulator app container around the runtime.

### Gate S2 — first frame / first real graphics proof
**Objective:** Prove rendering path on Simulator with imported legal assets.

**Work focus:**
- Metal product path (preferred) or explicitly temporary GLES spike with written justification
- asset import of host-prepared package
- first frame from real renderer systems if possible; if only a subgate clear-color/runtime-present is achieved, label it honestly as S2a and continue

**Proof (required):**
- screenshot + log
- note of graphics backend used
- asset import path used

### Gate S3 — touch MVP + lifecycle
**Objective:** Playable basic control loop and suspend/resume safety on Simulator.

**Work focus:**
- minimal touch controls for move/jump/attack/pause/camera-enough-to-play
- background/foreground pause seam across EE/audio
- settings/save in sandbox

**Proof (required):**
- short notes + screenshots/video if available
- background/resume once without crash/softlock
- touch moves the character or navigates proven game UI into a playable state

### Gate R1 — handoff package
**Objective:** Another agent/human can continue from a clean checkout.

**Work focus:**
- scripts + BUILDING docs
- asset safety verification script
- STATUS/remaining-work honesty (device signing, store policy, etc.)

**Proof (required):**
- `scripts/verify-repo-safety.sh` (or equivalent) passes
- clean instructions in `DOCS/BUILDING.md`
- no assets in git

## 6. Evidence standards
A gate is not done when code “looks right.” It is done when:

- commands and outputs are captured,
- `DOCS/STATUS.md` marks the gate PASS with date + path to evidence,
- asset safety still holds,
- no regression against earlier hard gates (especially no-emit).

## 7. Recommended first concrete tasks (H1)
1. Pin upstream commit in `ref/` or submodule/subtree strategy; record hash in STATUS (`641fb572...` was Phase 1 research pin; re-verify if moving).
2. Write a one-page ARM64 OpenGOAL ABI note (special regs, args, ret, saved set) before mass IR work.
3. Implement `do_goal_function_arm64` + the smallest IR set:
   - consts, moves, alu, loads/stores, branches, calls, returns
4. Execute those tests through the real function codegen path, not only raw IGen encodes.
5. In parallel notes, list every emit site from doc 08 and mark status; this becomes H2 board.
6. Only then widen toward Jak 1 boot subset and mips2c static shims.

## 8. Stop conditions (write report and halt)
- H1 impossible without redesigning OpenGOAL IR entirely and no progress after bounded attempt
- H2 requires permanent RWX for correctness
- Legal/asset boundary would need to be violated to proceed
- Toolchain/signing external blocker for the *current* gate (record and continue only if gate truly requires it)

When stopping, write `DOCS/reports/YYYY-MM-DD-stop-<gate>.md` with:
- what was attempted
- evidence
- options
- recommendation (pivot Strategy B, abort, or external wait)

## 9. Strategy pivot rule
If H2 proves iOS cannot execute AOT blobs as RX memory, pivot to Strategy B from `02-execution-model-verdict.md` (GOAL/IR → C++/LLVM → clang into signed binary). Do not pivot silently; record an ADR in `DOCS/08-adr-code-packaging.md`.

## 10. Definition of success for Bot 2 session batches
Any session that advances one hard gate with proof is successful.
Any session that only produces unproven scaffolding is incomplete.
Any session that adds touch UI before H3 is working incorrectly — undo or isolate and return to H gates.

## 11. Copy-paste prime directive
> Finish ARM64 AOT OpenGOAL for Jak 1 with zero runtime code emission, prove it on host, then wrap it in an iOS Simulator shell. No assets in git. One Simulator at a time. No over-engineering.
