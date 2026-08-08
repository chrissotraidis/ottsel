# 14 — Progress review: why the loop is stalling and what to do next

Date: 2026-08-08 (evening). Author: review pass (operator-requested).
Scope: whole-repo review of the Phase 2 build loop (H1 → H3 PASS) with the
question "the system is encountering major problems with progressing — why,
and what are the next steps." Read alongside `13-current-state.md` (which
remains the authoritative technical snapshot) and the revised
`BOT4_HANDOFF.md` (the next builder's goal prompt).

## Bottom line

The technical work is in good shape: H1, H2, H2.5, and H3 are PASS with
solid evidence, and the pinned OpenGOAL tree boots to the GOAL kernel
dispatcher loop on host ARM64. The **progression problems are structural,
not technical**: the next gate (S1) was declared IN PROGRESS but has zero
scaffolding, the debug loop that got H3 done will not scale to S1/S2, and
two small handoff chores were never executed. None of these require new
research; they require decomposition and tooling.

## Findings

### F1 — S1 is marked IN PROGRESS but nothing exists

`BOT4_HANDOFF.md` (as Bot 3 left it) and `STATUS.md` put S1 next, but:

- `src/` and `scripts/` are empty (never created).
- No `docs/evidence/S1/` directory, no loop-log entry, no Xcode/CMake iOS
  target, no SDL3 iOS wiring.
- The roadmap's S1 bar ("iPad Simulator launches app, runtime init succeeds
  or fails with explicit gated error, logs captured") hides 5-6 independent
  unknowns (app target build, iOS lifecycle, EE memory map under the
  Simulator, asset packaging into the bundle, log capture, audio).

A gate with that many unknowns and no decomposition is where builder
sessions stall. **Fix: split S1 into sub-gates S1.0–S1.4 (below).**

### F2 — The debug loop that passed H3 will not scale to S1/S2

H3's last three iterations were each **one ARM64 encoder bug**, found by
the same expensive cycle: 10–20 min rebuild → full boot → SIGILL at an
unknown PC → lldb hunt → one-line fix. The only test layer below "boot the
whole kernel" is the H1 proof, which covers 5 toy functions. S1/S2 will run
far more code: GAME.CGO, mips2c statics, and engine paths that need the 15
still-NYI IRs (vector swizzle/blend/splat/sqrt, partial float math).
Continuing the boot-and-hunt cycle there means days per bug.

**Fix: add one fast feedback tool before S1 heavy lifting** — an emitter
validation harness that disassembles/validates every word the ARM64
emitter produces for a compiled object (capstone or `as` round-trip), so
invalid encodings fail in seconds at compile time instead of as a SIGILL
minutes into a boot. This is a host-side tool, small scope, and directly
extends the H1 harness pattern. (Nice-to-have, not a gate blocker: a
differential kernel run comparing x86 vs ARM64 boot logs.)

### F3 — Graphics reality must shape S1 scope now

The OpenGOAL renderer is desktop OpenGL 4.1/4.3 (~45k LOC). iOS has no
desktop OpenGL; Metal is the durable path (docs 03, 11). If Bot 4 tries to
make the full `gk` renderer run on the Simulator, S1 will sink into a GL
dead end. **Fix: S1 is explicitly a headless-renderer shell** — window +
runtime + dispatcher loop + log surface, renderer stubbed out (the H3 boot
already tolerates missing graphics via the empty-`fr3` fallback). First
pixels belong to S2's Metal spike, as the roadmap already intends.

### F4 — Bot 3's two pre-S1 chores were never executed

Both handoffs recorded them; neither was done:

1. **Durable stderr capture is still missing.** `grep -c call_goal_on_stack`
   over `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log` returns **0** —
   the per-dispatch lines (the actual dispatcher-loop proof) exist only in
   the evidence README, not the captured log.
2. **`gk` rebuild for the Windowed source default** is unverified.

Ten minutes of work; without them the H3 evidence is weaker than claimed
and every future boot risks a fullscreen surprise.

### F5 — Patch and repo hygiene risks

- `patches/` holds 4 patches with overlapping/superseded content; doc 13
  says "apply the newest one" but the filenames don't say which that is.
  Canonical = `h3-jak1-host-boot.patch`; the others are historical.
  **Fix: add `patches/README.md` stating this.**
- The repo has 2 commits, one of them "Add files via upload". Per-gate
  commits would make regression triage much cheaper.
- Disk: **~16 GiB free** (doc 13 said ~17 GB — drifting down). iOS
  Simulator runtimes and a second build tree will consume several GB; keep
  one build dir, delete stale ones.

### F6 — What is NOT a problem

For balance: the pinned worktree builds, `gk`/`goalc` binaries exist, the
ISO is extracted, Simulator devices (incl. iPad Pro 11-inch M4, iOS 18.5)
are available, no stray `gk` processes, and the H3 patch applies clean to
the pin. The foundation is real.

## Next steps (the S1 plan, logged)

Sub-gates, in order. S1 as a whole passes when the roadmap bar is met:
iPad Simulator launches the app, the no-emit runtime boots to the kernel
dispatcher loop (or fails with an explicit gated error, no crash loop), and
logs/screenshots are captured under `docs/evidence/S1/`.

| Sub-gate | Work | Done when |
|---|---|---|
| **S1.0** | Chores: one clean host boot capturing stderr (`2>&1`) into the durable H3 log; rebuild `gk` so the Windowed default is in the binary; write `patches/README.md` (canonical patch). | Log contains `call_goal_on_stack ... returned` lines; windowed boot verified |
| **S1.1** | Emitter validation harness (F2): disassemble every emitted word of an ARM64-compiled kernel object; fail on any invalid encoding. Host tool, reuses H1 harness pattern. | Whole KERNEL.CGO validates; known-bad word (e.g. old `0xb8760801`) is caught by the tool |
| **S1.2** | iOS Simulator app target: CMake/Xcode shell (new `src/`), SDL3 iOS window, renderer stubbed (`OTTSEL_NO_RENDERER`-style flag), listener/REPL hard-disabled, one Simulator at a time. | App launches on iPad Pro 11-inch (M4) Simulator, window visible, clean lifecycle |
| **S1.3** | Runtime boot in-app: EE memory map + RW→RX flip verified under the Simulator; KERNEL.CGO (ARM64, ~404 KB) bundled as an app resource; kernel boots to dispatcher loop; logs captured to file + visible surface. | Dispatcher-loop lines in Simulator log; no crash loop; gated error if it stops earlier |
| **S1.4** | Evidence + handoff: screenshots, logs in `docs/evidence/S1/`, STATUS.md S1 PASS, patch regenerated + `git apply --check`, `BOT5_HANDOFF.md` (S2 = Metal/first-frame spike). | Repo continues from docs alone |

Ordering notes:

- S1.0 and S1.1 are host-side and independent of the app work; do them
  first because they de-risk everything after.
- Do **not** attempt OpenGL/GLES on the Simulator inside S1 (F3).
- Do **not** start S2 (renderer, first frame) before S1 passes.
- If the same root cause blocks a sub-gate 3 times with no new angle, write
  `docs/reports/YYYY-MM-DD-stop-S1.md` per the loop rules.

## Files changed by this review

- Added: `docs/14-progress-review.md` (this file)
- Revised: `docs/BOT4_HANDOFF.md` (rewritten as the S1 goal prompt with the
  sub-gates above; the original text is in git history at `346a9da`)
- Updated: `docs/INDEX.md`, `docs/00-loop-log.md` (pointers only)
