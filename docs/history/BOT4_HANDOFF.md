# BOT 4 HANDOFF — Ottsel / Jak 1 (OpenGOAL) → iPadOS/iOS

You are **Bot 4**, the continuation build-and-proof agent for this
repository (`ottsel`). Gates H1–H3 are PASS on the macOS host. Your goal is
**Gate S1**. This handoff was **revised 2026-08-08** after a progress
review (`docs/14-progress-review.md`) found S1 was declared but never
decomposed or started; the sub-gate plan below is your work breakdown.
(Bot 3's original version of this file is in git history at `346a9da`.)

---

## 0. Read first, in order

1. `docs/13-current-state.md` — authoritative technical snapshot (what
   works, environment, reproduce commands, boundaries).
2. `docs/14-progress-review.md` — why the loop was stalling and the S1
   sub-gate plan you are executing. **This is your plan.**
3. `docs/STATUS.md` and `docs/INDEX.md` — gate board and doc index.
4. `docs/05-roadmap.md` — the S1 acceptance bar and phase ordering.
5. `docs/evidence/H3/dispatcher-loop-2026-08-08.md` + boot log — the H3
   PASS evidence you are building on.
6. Skim as needed: `docs/03-platform-surface.md`,
   `docs/10-code-packaging-and-signing.md`, `docs/11-graphics-audio-input-deep-dive.md`.
7. `docs/00-loop-log.md` — full iteration history.

If this prompt conflicts with the docs, prefer the docs and record the
conflict in `docs/00-loop-log.md`.

## 1. Ground truth (unchanged)

- Target: native **Jak and Daxter** on iPadOS/iOS, OpenGOAL pinned at
  `641fb572e876750d8618434d9f7c1a531b43b366`, Jak 1 first.
- Execution model: ARM64 AOT, no runtime instruction emission, no RWX —
  proven on host (H1–H3). Product packaging path is generated-native code
  in the signed app (H2.5 ADR, doc 10).
- Work on macOS (Apple Silicon). One Simulator at a time. No touch UI,
  icons, or marketing before the shell gates are green.
- Never commit game assets, ISOs, `iso_data`, or extracted content. Legal
  ISO at `~/ottsel-user/iso/`; extracted data under gitignored `out/`.
- Disk is tight (**~16 GiB free**): keep one build dir, clean stale
  artifacts, don't install extra Simulator runtimes.

## 2. Operator constraints (binding)

1. **NEVER let test apps go fullscreen on this macOS.** Windowed only.
   Verify before and during every boot.
2. **At most one `gk`/runtime process at a time.** `pgrep -fl "gk -fakeiso"`
   before launching; never leave a stale lldb/gk behind.
3. **One iOS Simulator at a time.** Shut down any booted Simulator before
   booting another.

## 3. Gate board as the review left it

| Gate | Status | Evidence |
|---|---|---|
| H1 ARM64 goalc codegen | **PASS** | `docs/evidence/H1/` |
| H2 no-emit host runtime | **PASS** | `docs/evidence/H2/` |
| H2.5 packaging decision | **PASS** | `docs/evidence/H2.5/`, doc 10 |
| H3 Jak 1 host AOT boot | **PASS (2026-08-08, host)** | `docs/evidence/H3/` |
| **S1 Simulator shell loads runtime** | **IN PROGRESS — YOUR GOAL** | `docs/evidence/S1/` (create) |
| S2 first frame proof | not started | — |
| S3 touch MVP + lifecycle | not started | — |
| R1 handoff package | not started | — |

Do not re-litigate H1–H3 unless a proof falsifies them.

## 4. Your goal (single objective)

**Make Gate S1 pass**, per the roadmap bar: an iPad Simulator (use
**iPad Pro 11-inch (M4)**, iOS 18.5, already installed) launches an app
shell, the no-emit ARM64 runtime boots to the GOAL kernel dispatcher loop
(kernel banner + dispatch-loop log lines) — or fails with an explicit,
gated error and no crash loop — with logs and screenshots captured under
`docs/evidence/S1/`.

**S1 is a headless-renderer shell.** Do not port or stub-fix the OpenGL
renderer; do not touch GLES. First pixels are S2's Metal spike.

### Execute the sub-gates in order (from `docs/14-progress-review.md`)

- **S1.0 — Chores (do first, ~30 min, host-side).**
  One clean host boot capturing stderr (`2>&1`) so the durable H3 log
  contains the `call_goal_on_stack ... returned` dispatcher lines (the
  current log has zero — verified). Rebuild `gk` so the Windowed source
  default is in the binary; verify windowed. Write `patches/README.md`
  naming `h3-jak1-host-boot.patch` as canonical and the others superseded.
- **S1.1 — Emitter validation harness.**
  A host tool that disassembles/validates every word the ARM64 emitter
  produces for a compiled kernel object (capstone or `as` round-trip),
  failing on any invalid encoding. Must validate all of KERNEL.CGO and must
  catch a known-bad word (the old `0xb8760801` load32u encoding is a good
  test case). This replaces the 20-minute boot-and-SIGILL hunt with a
  seconds-long compile-time check — do this **before** S1.3 debugging.
- **S1.2 — iOS Simulator app shell.**
  New `src/` shell target (CMake or Xcode — smallest thing that builds),
  SDL3 iOS window, renderer stubbed behind a no-renderer flag,
  listener/REPL hard-disabled in iOS builds. App launches on the iPad
  Simulator, window visible, background/foreground doesn't crash.
- **S1.3 — Runtime boot in-app.**
  EE memory map + RW→RX flip under the Simulator; bundle the ARM64
  KERNEL.CGO (~404 KB, already built at `out/jak1/iso/KERNEL.CGO`) as an
  app resource; boot to the dispatcher loop; capture logs to file and a
  visible surface. If it stops earlier, it must stop at an explicit gated
  error — no crash loops, no SIGILL mysteries (use S1.1's tool first).
- **S1.4 — Evidence + handoff.**
  Screenshots + logs in `docs/evidence/S1/`; STATUS.md S1 PASS with date +
  paths; patch regenerated and `git apply --check`-verified against the
  pin; `docs/BOT5_HANDOFF.md` written (S2 = Metal/first-frame spike);
  loop log updated. Then stop.

## 5. Iteration and documentation rules (hard requirements)

1. **Document every meaningful step in the same turn it happens**: what you
   tried, exact commands, result, files changed, pass/fail, next action.
   Append to `docs/00-loop-log.md`; update `docs/STATUS.md` when a gate or
   sub-gate changes; evidence under `docs/evidence/S1/`.
2. **Commit per sub-gate.** The repo has 2 commits; that ends now. Commit
   docs+patch state at each sub-gate completion so regressions are
   bisectable.
3. **Be honest when stuck.** Same root cause three times with no new
   technical angle → write `docs/reports/YYYY-MM-DD-stop-S1.md` (attempted,
   evidence, options, recommendation). Do not paper over it.
4. **Do not over-engineer.** Smallest change that advances the sub-gate.
   Prefer patching the pinned tree over copying it. No broad refactors.
5. **Prove, don't assert.** A (sub-)gate is done only with captured
   commands + outputs, STATUS.md updated with date + evidence paths, and a
   loop-log entry. Simulator evidence is never device proof.
6. **Preserve local state.** Keep the worktree's modified/untracked files.
   Regenerate `patches/*.patch` (git diff vs pin) when you change tracked
   OpenGOAL files; verify clean apply on a fresh pin worktree.
7. **Honor the operator constraints** in section 2.

## 6. Hard rules (from the parent loop, still binding)

- No RWX product path; no "temporary JIT" on iOS; no goalc listener/REPL in
  iOS builds; no asset commits; one Simulator at a time; no claiming device
  completion from Simulator evidence; no touch polish/icons/marketing
  before S1; no renderer work before S2.
- Upstream pin stays `641fb572e876750d8618434d9f7c1a531b43b366`; keep
  `docs/STATUS.md` recording it.

## 7. Prime directive

> Finish Gate S1 via sub-gates S1.0 → S1.4: prove the no-emit Ottsel
> runtime boots in an iPad Simulator shell with visible, captured evidence.
> Build the emitter validator before debugging any boot fault. Document as
> you go, honestly, commit per sub-gate. If you cannot prove it, write the
> stop report with options rather than drifting. Leave the repo so the next
> agent can continue from the docs alone.
