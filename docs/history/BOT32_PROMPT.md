# BOT32 Goal-Based Loop — make Jak actually playable on macOS, then promote the proven stack to iPad and iPhone

> **Historical handoff (2026-08-17).** This prompt captures the then-current
> macOS-first investigation. It is not the current stage board: newer macOS
> and iPad evidence changed the active renderer plan. Start with
> `docs/STATUS.md` and `docs/15-macos-to-mobile-goal-loop.md` instead; consult
> this file only for its retained probes and reproduction detail.

Date: 2026-08-17.  Starting commit: `6ef5c77`.

## Fixed goal

Make *Jak and Daxter: The Precursor Legacy* **actually playable on macOS**
through the native arm64 OpenGOAL runtime: correct rendered scenes,
responsive player input, a stable retail path, and audible output. Only after
that macOS gate passes, promote the same proven runtime to iPadOS and then
iPhone with evidence-backed platform plans.
Do not shrink that goal to a compiler pass, process liveness, draw counters, a
title log, or an iOS shell launch.

The immediate reference platform is the local macOS `gk` build because it is
the only current path with the upstream fr3 C++ renderers, real IOP/overlord
streaming, and complete local game data.  iPad remains the product target, but
the stale Simulator VU1/software-rasterizer path is diagnostic-only and must
not be extended as the product renderer.

## Reconciled starting state — verify; do not inherit blindly

- The maintained delta is `patches/h3-jak1-host-boot.patch` against
  `641fb572e876750d8618434d9f7c1a531b43b366`.  Assets, extracted ISO data,
  CGOs/DGOs, saves, and build products remain local and untracked.
- The host executable is
  `out/jak-project/build/h1/game/gk`.  It is native arm64 and runs the fr3
  OpenGL 4.1-on-Metal renderer, SDL3, IOP/overlord, and no-emit ARM64 GOAL
  runtime.  The current launch log independently reached `GAMEPLAY: enter
  title`, `Displaying level village1`, and `TFR3` geometry submission without
  a fault.
- This is **not yet a new visual gate pass**. The current user-supplied title
  screenshot proves a rendered but severely corrupted `Jak and Daxter` logo;
  the subtitle and press-start text are substantially more intact. The bare
  SDL `gk` process is not enumerated by the current Computer Use provider, so
  M0 still needs a local accessible launch path. See
  `docs/evidence/M1/m1-title-logo-forensics-2026-08-17.md`.
- The live synthetic pad bridge consumed `0x4000` (X) on this run, but Jak's
  position did not change.  That does not prove player controls work: X is an
  action button, and the current bridge has no deterministic analog-motion
  probe.  Keyboard focus/bind delivery and game-level movement are open.
- Retail VIS/STR streaming has been seen in prior evidence.  The remaining
  fatal compatibility issue is a NULL call in a later `run-function-in-process`
  / process-spawn path (historically observed as an auto-save spawn); ambient
  gameplay can reach it.  Treat it as unproved until reproduced with a fresh
  crash record.

Read first: this file, `docs/STATUS.md`, `docs/BOT31_HANDOFF.md`,
`docs/14-roadmap-to-playable.md`, `docs/evidence/M1/m1-collide-list-overflow.md`,
and newest-first `docs/00-loop-log.md`.  Historical S2.2 VU1 documents explain
the research transport; they are not the renderer plan.

## Non-negotiable loop discipline

1. Use one Windowed runtime and, when testing iOS, one booted Simulator.  Stop
   the runtime you started before rebuilding or changing platform.
2. First inspect `git status --short`, `git -C out/jak-project status --short`,
   process ownership, disk space, current commit, and artifact timestamps.
   Preserve unrelated dirty work.
3. Every compatibility or ARM64 fix starts with a focused semantic regression
   or deterministic runtime probe that fails first.  Disassemble the compiled
   ARM64 function and compare with the x86 emitter before changing an emitter
   or ABI shim.  Never patch Jak GOAL source to hide a runtime fault.
4. After a `goalc` change run the relevant semantic suite, then
   `rm out/jak1/obj/*.o` and `(mi)`; rebuilding only KERNEL/GAME leaves TIT and
   VI1 DGO code stale.  Verify the expected machine-code change in the rebuilt
   object before launching.
5. Save compact evidence under `docs/evidence/M1/` or `docs/evidence/I1/`.
   Update `STATUS.md`, `13-current-state.md`, and `00-loop-log.md` only after a
   gate's stated exit bar is met.  Regenerate and clean/reverse-apply the
   canonical patch after maintained-source changes.
6. Three consecutive reproductions of the same root blocker without a new,
   discriminating experiment require a dated stop report.  Do not spin boots.

## Gate M0 — make the running game observable through Computer Use

**Purpose:** establish a repeatable visual test harness before interpreting
draw logs as player-visible output.

1. Launch from `out/jak-project`:

   ```sh
   ./build/h1/game/gk -v --game jak1 -- -boot -fakeiso
   ```

   Capture the launch command, PID, Windowed setting, and the fresh log path.
   Reject an inherited process or an old log.
2. Use Computer Use (`@oai/sky`) to list applications, obtain the game's
   accessibility tree, and emit a screenshot before any input. After every UI
   action, refresh the tree before choosing a new element. A current
   user-supplied screenshot may guide triage, but cannot replace this
   repeatable harness.
3. The raw `gk` executable currently has no app identity visible to Computer
   Use.  If that persists, build a **local, ignored debug app wrapper** with a
   unique bundle identifier whose launcher `cd`s to `out/jak-project` and
   execs the same `gk`; it must not alter game code or data.  Prove Computer
   Use can capture the wrapper's game window before continuing.  If macOS
   denies capture, record the exact permission/error and ask the user to grant
   the required Screen Recording permission; do not substitute terminal logs
   for pixels.

**Pass:** fresh Computer Use screenshot shows the actual macOS game window and
its timestamped log reaches title or Village1 without a fault. **Fail:** retain
the UI-harness evidence and fix only the wrapper/permission boundary.

## Gate M1 — prove the host game is playable, not merely rendering

Run all checks from one fresh M0 pass.  Capture before/after screenshots and
the relevant concise log lines.

1. **Visual correctness.** Capture title, then Village1. The current main
   title logo is a known red gate, not cosmetic polish: add only bounded
   producer-to-GL traces, identify its active renderer/packet, and compare a
   before/after visual capture after each falsifiable fix. Use the real title
   path first; the `/tmp/ottsel-bg-village1` driver may be used only as a
   diagnostic shortcut and must be labelled as such.  Test
   `/tmp/ottsel-set-tod` only after recording the current frame.  A blue tint
   is not a renderer bug until side-by-side daylight evidence proves it.
2. **Input contract.** Read the active keyboard mapping and focus the actual
   game window through Computer Use.  Test a documented keyboard action and
   capture its visible result.  Add a temporary, C-side analog-pad injection
   seam only if keyboard delivery remains ambiguous; it must sample neutral,
   held, and neutral states and log game-level target position before/after.
   The seam passes only when position changes during held input and remains
   stable after release.  A button-consumed log is insufficient.
3. **Stability.** Keep Village1 active for five minutes with camera movement
   and input.  Require no EE crash, no collision-list overflow, no stale
   process, and persistent rendered frames.  Record elapsed time and fault
   scan—not an unbounded debug stream.
4. **Audio.** Verify an audible title/level sound through the host output path
   and record the device plus the IOP/989snd evidence.  Do not infer sound
   from bank-load logs.

**Pass:** fresh screenshots show title and Village1, player movement is
visibly and telemetry-confirmed, five-minute soak passes, and audio is heard.
At pass, remove temporary probes, regenerate the canonical patch, validate
clean/reverse apply, and update the three state documents.

## Gate M2 — reproduce and fix the retail NULL-spawn only if it occurs

Drive the retail title/menu flow with M1's verified input, rather than calling
internal functions prematurely.  If no crash occurs during a bounded new-game
and 10-minute ambient play test, record that result and continue; do not revive
the historical issue from prose alone.

If it does crash at NULL:

1. Capture signal, PC/LR, GOAL stack, process type, spawn arguments
   `{proc, function, stack}`, and the compiled function identity for
   `run-function-in-process` / `set-to-run`.
2. Add one focused ARM64 semantic/runtime regression for the failing
   stack-switch, saved-register, or return contract.  Confirm the regression
   fails before any patch.
3. Disassemble both the ARM64 and x86 references.  Repair the runtime/emitter
   seam only, rebuild all affected DGOs with `(mi)`, then repeat M0 and M1.

**Pass:** retail title -> new game -> Village1 plus 10-minute ambient play has
no NULL call and remains visually playable.  **Three repeats:** write an
honest M2 stop report with the captured call contract.

## Gate I1 — promote the proven macOS stack to iPadOS, only after M1

The iPad product path is: signed-native/no-emit GOAL execution + complete user
supplied data bundle + fr3 assets + the upstream bucket renderers + real IOP
and input.  Do not resume the Metal shell VU1/software rasterizer as a product
implementation.

1. Create a separate, reproducible renderer-port subplan (ANGLE/GLES-on-Metal
   first unless a small native-Metal spike disproves it) with one narrow bucket
   renderer and one `fr3` level.  Its exit bar is a Computer Use screenshot on
   the booted iPad Simulator, not a Metal clear or texture counter.
2. Replace the iOS IOP/RPC stubs with the host-proven file/overlord path using
   local user data.  Keep assets ignored and audit the staged set before every
   commit.
3. Port M1's verified pad-state contract to touch/GameController.  Prove both
   active motion and neutral input after menu, background/foreground, and
   resume transitions with current UI screenshots and file-backed logs.
4. Only after I1's rendered, controllable iPad frame is repeatable should
   iPhone screen-size/layout work, device signing, performance, and packaging
   be considered. Simulator success is never physical-device acceptance.

## Gate I2 — iPhone only after iPad I1

Reuse the iPadOS renderer, data, and input contracts. Add only responsive
layout/touch-target work, then prove title, Village1, active input, neutral
input after lifecycle transitions, and one current Computer Use screenshot on
an iPhone Simulator. Do not turn an iPad graphics incompatibility into an
iPhone-specific investigation.

## Handoff checklist

At each actual pass: add compact evidence; reconcile the three state docs;
clean/reverse-apply the patch; run the scoped regression/build; audit for
assets/secrets; commit only maintained source and documentation; then continue
to the next gate.  At a stop: leave one paste-ready next experiment with the
exact command, expected discriminator, and known boundary.
