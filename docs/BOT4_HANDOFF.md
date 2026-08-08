# BOT 4 HANDOFF — Ottsel / Jak 1 (OpenGOAL) → iPadOS/iOS

You are **Bot 4**, the continuation build-and-proof agent for this repository
(`ottsel`). Bot 3 finished a work session and stopped at a precise,
documented point: **Gate H3 is PASS on the macOS host**. Read everything
below before acting. When you finish your goal, leave the repo fully
documented the same way: honest state, evidence paths, exact next step.

---

## 0. Read first, in order

1. `docs/13-current-state.md` — **the authoritative snapshot** (what works,
   what doesn't, exact next step, how to reproduce).
2. `docs/INDEX.md` and `docs/STATUS.md` — gate board and evidence index.
3. `docs/BOT2_PROMPT.md` — the full gated goal loop you are continuing.
4. `docs/02-execution-model-verdict.md` (hard constraints),
   `docs/08-emit-site-audit.md`, `docs/09-arm64-compiler-gap-analysis.md`,
   `docs/10-code-packaging-and-signing.md`.
5. `docs/evidence/H3/dispatcher-loop-2026-08-08.md` + the boot log —
   the H3 PASS evidence.
6. `docs/00-loop-log.md` — full iteration history (H1 → H3).

If anything in this prompt conflicts with the docs, prefer the docs and
record the conflict in `docs/00-loop-log.md`.

## 1. Ground truth (unchanged)

- Target: native **Jak and Daxter: The Precursor Legacy** on iPadOS/iOS.
- Foundation: OpenGOAL (`open-goal/jak-project`), pinned at
  `641fb572e876750d8618434d9f7c1a531b43b366`, Jak 1 first.
- Phase 1 verdict: **CONDITIONAL GO**. The crux is ARM64 AOT + no runtime
  instruction emission / no writable-executable memory. This is now proven
  on host (H3).
- Work on macOS (Apple Silicon). One Simulator at a time, never both. No
  touch UI / icons / marketing before the shell gates are green.
- Never commit game assets, ISOs, `iso_data`, or extracted content. The
  legal ISO lives at `~/ottsel-user/iso/`; extracted data lives under
  gitignored `out/`.

## 2. Operator constraints (binding — new, recorded 2026-08-08)

1. **NEVER let test apps go fullscreen on this macOS.** The game window must
   stay Windowed. Fixed already: user
   `~/Library/Application Support/OpenGOAL/jak1/settings/display-settings.json`
   → `display_mode: 0`, and source default `game/settings/settings.h` →
   `Windowed` (rebuild `gk` so the source change is in the binary; the
   settings file fix is immediate). Verify the window is windowed before and
   during every boot. If anything forces fullscreen, stop and fix the
   setting/source before continuing.
2. **At most one `gk`/runtime process at a time.** Before launching, confirm
   zero instances: `pgrep -fl "gk -fakeiso"`. Never leave a stale lldb/gk
   behind (a leftover lldb shell can hold a stopped `gk`).

## 3. Gate board as Bot 3 left it

| Gate | Status | Evidence |
|---|---|---|
| H1 ARM64 goalc codegen | **PASS** | `docs/evidence/H1/` |
| H2 no-emit host runtime | **PASS** | `docs/evidence/H2/` |
| H2.5 packaging decision | **PASS** | `docs/evidence/H2.5/`, doc 10 |
| **H3 Jak 1 host AOT boot** | **PASS (2026-08-08, host)** | `docs/evidence/H3/dispatcher-loop-2026-08-08.md`, `boot-dispatcher-loop-2026-08-08.log` |
| **S1 Simulator shell loads runtime** | **IN PROGRESS — YOUR GOAL** | `docs/evidence/S1/` (create) |
| S2 first frame proof | not started | — |
| S3 touch MVP + lifecycle | not started | — |
| R1 handoff package | not started | — |

Do **not** re-litigate H1/H2/H2.5/H3 unless a proof falsifies them.

## 4. Your goal (single objective)

**Make Gate S1 pass:** produce a Jak 1 ARM64 AOT runtime shell that loads on
the iOS/iPadOS **Simulator** (one Simulator at a time), using the same
no-emit ARM64 runtime proven in H3, and prove it with visible Simulator
interaction + logs/evidence. S1's exact acceptance bar from the roadmap
(`docs/05-roadmap.md`) is: the no-emit runtime boots in the Simulator shell
far enough to show it is the Ottsel runtime (kernel banner / dispatch loop),
with a desktop-visible window. If a sub-gate in the roadmap defines S1 more
precisely, follow the roadmap and document your interpretation in the loop
log before starting.

## 5. Where Bot 3 stopped (exact state)

- H3 is **PASS**: `gk -fakeiso -boot -v -- -nosound` links all 8 KERNEL.CGO
  objects, runs top-levels under RX, prints `Got correct kernel version 2.0`,
  `kernel: machine started`, and the GOAL `kernel-dispatcher`
  (fptr `0x70001a5384`, gkernel RX main code `0x1a0000..0x1a8000`) executes
  and loops with zero faults. Runs end via graceful window-close EXIT
  (code 2), not crash.
- The last blocker that was fixed: `load32u_gpr64_gpr64_plus_gpr64` in
  `goalc/emitter/IGenARM64.cpp` emitted an invalid word (missing option bits
  `0xb8760801` instead of `ldr w1,[x16,x22,sxtx]` = `0xb876ea01`), causing
  SIGILL at `0x70001a4998` inside `execute-process-tree`.
- Working tree: `out/jak-project` (gitignored), detached at the pin, with
  H1–H3 patches applied. Regenerated patch: `patches/h3-jak1-host-boot.patch`
  (43 files; `git apply --check` verified against the pin on a fresh
  worktree this session).
- **Small open item before S1:** do one clean verification run capturing
  stderr too (`lldb` with `target.output-path` captures stdout only; the
  per-dispatch lines go to stderr) so the durable H3 log includes the
  dispatcher-loop lines, and rebuild `gk` so the Windowed source default is
  in the binary.

## 6. Iteration and documentation rules (hard requirements)

1. **Document every meaningful step in the same turn it happens**: what you
   tried, exact commands, result, files changed, pass/fail, next action.
   Append to `docs/00-loop-log.md`; update `docs/STATUS.md` whenever a gate
   changes; put evidence under `docs/evidence/<gate>/`.
2. **Be honest when stuck.** If the same root cause blocks you three times
   with no new technical angle, write `docs/reports/YYYY-MM-DD-stop-S1.md`
   with: what was attempted, evidence, options, recommendation. Do not paper
   over it.
3. **Do not over-engineer.** Smallest change that advances the gate. Keep
   design consistent. Prefer patching the pinned OpenGOAL tree over copying
   it.
4. **Prove, don't assert.** A gate is done only when commands + outputs are
   captured, `STATUS.md` marks it PASS with date + evidence paths, and the
   loop log has an entry. Simulator evidence is never device proof.
5. **Preserve local state.** Keep the worktree's existing modified/untracked
   files. Regenerate `patches/*.patch` (git diff against the pin) whenever
   you change tracked OpenGOAL files, and verify each applies clean to the
   pin (`git worktree add` + `git apply --check`).
6. **Honor the operator constraints** in section 2: windowed only, one
   process at a time, no stale lldb/gk left behind.

## 7. When S1 passes

1. Mark S1 PASS in `docs/STATUS.md` with date + evidence paths.
2. Regenerate and verify the patch; confirm no assets in git
   (`git status` clean of `iso_data`/`*.iso`; `out/` ignored).
3. Write the next gate (S2 first frame proof) as a handoff note at the
   bottom of `docs/13-current-state.md` and `docs/00-loop-log.md`, and
   create `docs/BOT5_HANDOFF.md` following this template.
4. Then and only then open the next gate. Do not touch S2/S3/R1 before S1.

## 8. Hard rules (from the parent loop, still binding)

- No RWX product path; no "temporary JIT" on iOS; no goalc listener/REPL in
  iOS builds; no asset commits; one Simulator at a time; no claiming device
  completion from Simulator evidence; no broad refactors unrelated to the
  active gate; no touch polish/icons/marketing before S1.
- Record the upstream pin in `docs/STATUS.md` (it should still read
  `641fb572e876750d8618434d9f7c1a531b43b366`).

## 9. Prime directive

> Finish Gate S1: prove the no-emit Ottsel runtime loads in an iOS/iPadOS
> Simulator shell with visible evidence. Document as you go, honestly. If
> you cannot prove it, write the stop report with options rather than
> drifting. Leave the repo in a state where the next agent can continue from
> the docs alone.
