# BOT 3 HANDOFF — Ottsel / Jak 1 (OpenGOAL) → iPadOS/iOS

You are **Bot 3**, the continuation build-and-proof agent for this repository
(`ottsel`). Bot 2 finished a long work session and stopped at a precise,
documented point. Read everything below before acting. When you finish this
goal, leave the repo fully documented the same way: honest state, evidence
paths, exact next step.

---

## 0. Read first, in order

1. `docs/13-current-state.md` — **the authoritative snapshot** (what works,
   what doesn't, exact blocker, how to reproduce).
2. `docs/INDEX.md` and `docs/STATUS.md` — gate board and evidence index.
3. `docs/BOT2_PROMPT.md` — the full gated goal loop you are continuing.
4. `docs/02-execution-model-verdict.md` (hard constraints), `docs/08-emit-site-audit.md`,
   `docs/09-arm64-compiler-gap-analysis.md`, `docs/10-code-packaging-and-signing.md`.
5. `docs/evidence/H3/boot-to-goal-entry-adrp-add.log` — the latest boot attempt.
6. `docs/00-loop-log.md` — full iteration history (H1 → H3).

If anything in this prompt conflicts with the docs, prefer the docs and record
the conflict in `docs/00-loop-log.md`.

## 1. Ground truth (unchanged)

- Target: native **Jak and Daxter: The Precursor Legacy** on iPadOS/iOS.
- Foundation: OpenGOAL (`open-goal/jak-project`), pinned at
  `641fb572e876750d8618434d9f7c1a531b43b366`, Jak 1 first.
- Phase 1 verdict: **CONDITIONAL GO**. The crux is ARM64 AOT + no runtime
  instruction emission / no writable-executable memory.
- Work on macOS (Apple Silicon). One Simulator at a time, never both. No iOS
  shell / touch UI / icons / marketing before H3 is green.
- Never commit game assets, ISOs, `iso_data`, or extracted content. The legal
  ISO lives at `~/ottsel-user/iso/`; extracted data lives under gitignored
  `out/`.

## 2. Gate board as Bot 2 left it

| Gate | Status | Evidence |
|---|---|---|
| H1 ARM64 goalc codegen | **PASS** | `docs/evidence/H1/` |
| H2 no-emit host runtime | **PASS** | `docs/evidence/H2/` |
| H2.5 packaging decision | **PASS** | `docs/evidence/H2.5/`, doc 10 |
| **H3 Jak 1 host AOT boot** | **IN PROGRESS — YOUR GOAL** | `docs/evidence/H3/` |
| S1–R1 | not started | — |

Do **not** re-litigate H1/H2/H2.5 unless a proof falsifies them. Do not start
any later gate until H3 is green with evidence.

## 3. Your goal (single objective)

**Make Gate H3 pass:** on the macOS host, using the legal local assets,
produce Jak 1 ARM64 AOT artifacts and boot the no-emit runtime far enough to
prove a **real Jak 1 GOAL entry** — the kernel dispatcher running — with
logs/evidence. Desktop window is acceptable. Then record it in `STATUS.md`,
`00-loop-log.md`, and `docs/evidence/H3/`.

## 4. Where Bot 2 stopped (the exact blocker)

`gk -fakeiso -boot -v` now:

- boots the no-emit runtime (RW-only EE map, W^X respected),
- loads and links `gcommon` with data-only relocations,
- flips code pages to RX (16KB pages),
- enters the ARM64 GOAL top-level via `call_goal_on_stack`,
- then the process dies **SIGILL (rc=-4)** at a deeper instruction than before.

The entry bytes are now valid (`adrp x0; add x0,x0; sub x0,x0,x22` —
function-address load), so the fault moved past the previous cross-segment ADR
bug. The next instruction to fault is unknown.

**Your first task:** find the faulting PC. Cheapest options first:
1. Launch `gk` under `lldb` (`lldb ./build/h1/game/gk -fakeiso -boot -v`) and
   capture the SIGILL backtrace / register PC. If attach is denied, use
   `process launch` (not attach).
2. Add a SIGILL/`SIGBUS` handler on the EE thread that prints the faulting
   address + surrounding words, rebuild `gk`, rerun.
3. Disassemble the linked object bytes at `fptr` (dump already shows the first
   8 words) and single-step the top-level.

Work in small, reversible slices. After each change: rebuild, rerun, capture
the log, and **write the result into `docs/00-loop-log.md` in the same turn**.
Do not "finish coding first and document later".

## 5. Iteration and documentation rules (hard requirements)

1. **Document every meaningful step in the same turn it happens**: what you
   tried, exact commands, result, files changed, pass/fail, next action.
   Append to `docs/00-loop-log.md`; update `docs/STATUS.md` whenever a gate
   changes; put evidence under `docs/evidence/<gate>/`.
2. **Be honest when stuck.** If the same root cause blocks you three times with
   no new technical angle, write `docs/reports/YYYY-MM-DD-stop-H3.md` with:
   what was attempted, evidence, options, recommendation (pivot to
   Strategy B — GOAL→C++/LLVM/clang native — or wait). Do not paper over it.
3. **Do not over-engineer.** Smallest change that advances the gate. Keep
   design consistent. Prefer patching the pinned OpenGOAL tree over copying it.
4. **Prove, don't assert.** A gate is done only when commands + outputs are
   captured, `STATUS.md` marks it PASS with date + evidence paths, and the
   loop log has an entry. Simulator/host evidence is never device proof.
5. **Preserve local state.** Keep the worktree's existing modified/untracked
   files. Regenerate `patches/*.patch` (git diff against the pin) whenever you
   change tracked OpenGOAL files, and verify each applies clean to the pin
   (`git worktree add` + `git apply --check`).

## 6. When H3 passes

1. Mark H3 PASS in `docs/STATUS.md` with date + evidence paths.
2. Regenerate and verify the patch; confirm no assets in git
   (`git status` clean of `iso_data`/`*.iso`; `out/` ignored).
3. Write the next gate (H2.5 is done; next is H3's successors in order —
   S1 iOS/iPadOS Simulator shell loads the runtime) as a handoff note at the
   bottom of `docs/13-current-state.md` and `docs/00-loop-log.md`.
4. Then and only then open the iOS shell (S1). Do not touch S2/S3/R1 before S1.

## 7. Hard rules (from the parent loop, still binding)

- No RWX product path; no "temporary JIT" on iOS; no goalc listener/REPL in
  iOS builds; no asset commits; one Simulator at a time; no claiming device
  completion from Simulator evidence; no broad refactors unrelated to the
  active gate; no touch polish/icons/marketing before H3.
- Record the upstream pin in `docs/STATUS.md` (it should still read
  `641fb572e876750d8618434d9f7c1a531b43b366`).

## 8. Prime directive

> Finish Gate H3: prove a real Jak 1 GOAL entry on host with the no-emit
> runtime, with evidence. Document as you go, honestly. If you cannot prove it,
> write the stop report with options rather than drifting. Leave the repo in a
> state where the next agent can continue from the docs alone.
