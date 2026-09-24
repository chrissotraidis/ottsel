# BOT7_PROMPT — Ottsel continuation: AUDIT FIRST, then resume S2.1

This is a handoff from the S2.1 fault-narrowing session of 2026-08-10
(commits `8bab4a8`, `60241e1`). The previous bot stopped at the user's
request. Your first job is to AUDIT that session's work — verify it against
the captured evidence before trusting or continuing it — then resume the
active gate. Do not rewrite or re-litigate passed gates without evidence.

## 1. Read first, in order

1. The governing objective: read the goal-objective attachment for this
   thread, or `docs/BOT6_PROMPT.md` (identical text). It defines the gate
   ladder R0 → A1.0 → A1.1 → A1.2 → S2.1 → S2.2 → S3 → R1 and the binding
   operating rules. Treat it as the roadmap, not as current gate state.
2. `docs/15-progress-audit.md` (corrected execution order).
3. `docs/STATUS.md` and `docs/13-current-state.md` (gate board; the newest
   dated evidence wins over the objective's stale lines).
4. `docs/evidence/S2/s21-trace4-boot.log` (current fault evidence) and
   `docs/evidence/S2/s21-offline-dump-analysis.md` (host-side link+dump
   analysis from the previous session, with reproduction commands).
5. `docs/00-loop-log.md` — newest entries first (the 2026-08-10 entries).
6. Current state: `git log --oneline -8`, `git status --short`,
   `pgrep -fl OttselShell`, `xcrun simctl list devices booted`, `df -h`.

## 2. Reconciliation (do not skip)

- The objective/BOT6_PROMPT says "Gate A1 is now the active gate." That line
   is STALE: A1.0/A1.1/A1.2 all PASSED 2026-08-09 with evidence under
   `docs/evidence/A1/` (semantic regressions 14/14, signed-__TEXT slice,
   execution-permission proof). The active gate is **S2.1**. Verify the A1
   evidence exists and is consistent, but do NOT re-open A1 without
   contradictory evidence.
- R0 (normalize the checkpoint) is satisfied: the dirty state was committed
   (worktree clean at `60241e1`); only docs, evidence logs, and the active
   diagnostic probe in `src/shell/ios_boot.cpp` are in the tree. No assets,
   ISOs, or scratch binaries are staged (verify).

## 3. MANDATORY AUDIT — verify before continuing

For each item, inspect the cited evidence and record PASS / CONTRADICT /
UNVERIFIABLE in `docs/reports/2026-08-10-audit-bot7.md` (or a loop-log
entry). Correct or re-verify anything that fails. Do not proceed on a claim
you cannot reproduce.

1. **Fault shape** — `s21-trace4-boot.log` ends with
   `signal 11 at pc=0x1f2df4 fault addr=0x1f2df4`; the probe inside the
   handler confirms `run-function-in-process sym value@0x19627c =
   0x001f2df4`. Claim: the fault is a `ret` to the RAW GOAL-relative rfn
   func value (EE base missing), and ee+0x1f2df4 = 0x70001f2df4 is rfn's
   mapped RX entry.
2. **Call chain** — the trace tail is gstate 0x550514 -> set-to-run
   0x1f3454/0x1f1d14 -> throw-dispatch 0x001f1bf4 -> fault; pp = 0x24783b
   the whole way; all traced caller-LRs absolute; the raw 0x001f2df4 appears
   only in the throw return path.
3. **Offline reproduction** — `ottsel-cgolink-dump` (source
   `out/jak-project/game/ottsel_cgolink_dump.cpp`, binary in
   `out/jak-project/build/h1/game/`) links the same KERNEL.CGO + GAME.CGO
   from `out/jak-project/out/jak1/iso` and its pattern scan finds
   `throw-dispatch` at offline 0x001b1bf4 = sim 0x001f1bf4 (matches
   trace[-1]). Re-run the tool and confirm the scan hit.
4. **throw-dispatch verified correct** — disassemble offline 0x001b1bf4
   (commands in the analysis doc) and compare with `gkernel.gc:1531`:
   tail is `sp = this->sp + off; pop; push this->ra + off; ret`. Claim: with
   x22 = 0x7000000000 and a 32-bit `this->ra`, this tail can never yield the
   observed raw 0x001f2df4, so the faulting `ret` is NOT throw-dispatch's
   tail. Re-check the arithmetic.
5. **catch-frame-new contract** — `gkernel.gc:1444`:
   `ra = (popped call value) - off`, `sp = sp - off`; the call shim
   (`IR_FunctionCall` in `goalc/compiler/IR.cpp`) pushes the caller's PRE-blr
   x30. Offline rfn (0x001b2df4) shows the `new 'stack 'catch-frame` call
   pushes rfn's x30 = 0x0244a6c0, and the fault stack shows the rfn
   catch-frame ra = 0x0244a6c0 at [0x7007fffec0]. Claim: that ra is
   semantically wrong (should be rfn's post-call continuation) but does NOT
   explain the raw-0x1f2df4 fault.
6. **Shim defect hypothesis (UNPROVEN)** — pushing the caller's return
   address instead of the call-site continuation is wrong for asm-funcs
   (x86 `call` semantics). Fix candidate: push the post-blr continuation via
   `adr`. Do NOT change the emitter on this hypothesis alone; it must be
   gated on identifying the faulting ret first, with an A1.0 regression
   added before the fix.
7. **Git hygiene** — the two handoff commits contain only docs + the
   `src/shell/ios_boot.cpp` diagnostic probe; nothing copyrighted or scratch
   is staged; the canonical patch (`patches/h3-jak1-host-boot.patch`) was
   not touched this session (verify `git status` and the patch applies
   cleanly if you rebuild).

## 4. Where the work stands (if the audit holds)

- Gates: H1–H3, S1, S2.0, A1.0–A1.2 PASS (evidence in `docs/evidence/`).
- S2.1 ACTIVE: all 346 GAME.CGO objects compile and validate; the boot chain
  runs the full time-of-day process spawn and faults on the throw/return
  path with a `ret` to the raw rfn func value.
- The faulting `ret` instruction is NOT yet identified. The previous
  session proved throw-dispatch correct and narrowed the suspect to a caller
  epilogue popping a slot holding the raw func value (fault stack slot
  [0x7007fffe80] = 0x001f2df4; return chain below the fault sp:
  0x0244a6c0 / 0x0244a668 / 0x001f2fdc / 0x001f1bb0).
- A real shim/asm-func return-address contract defect is documented as a
  candidate root cause, explicitly unproven.

## 5. Next action after the audit

1. Check `pgrep -fl OttselShell` — the trace4 app may still be HELD AT FAULT
   (pid ~36153, Simulator booted). If alive, lldb-attach immediately:
   - `memory read` the catch-frame fields at 0x7007fffeb4 with exact
     alignment (type@-4, name@+0, next@+4, sp@+8, ra@+0xc);
   - `disassemble` the trampoline at ee+0x0244a63c and the continuation at
     ee+0x0244a6c0 (GAME main-seg ground truth — live memory, not the
     offline dump, which does not reproduce GAME offsets);
   - identify the FAULTING ret instruction from the return chain.
2. If the process is gone: rerun the 2-min ios_boot probe cycle with the
   existing app build, capture a fresh boot log, then lldb-attach.
3. Once the faulting ret is identified: form the smallest falsifiable
   hypothesis, add an A1.0 regression, fix through the emitter, recompile
   CGO + app, boot, and continue S2.1 to its PASS bar (all 346 objects
   integrate; game reaches a stable renderer-ready boundary).

## 6. Binding operating rules (from the objective, binding)

- At most ONE runtime executable and ONE booted Simulator at a time; stop
  stale processes you own before launching.
- NEVER fullscreen; Windowed only.
- Never commit ISOs, extracted assets, CGO/DGO packages, ROMs, or scratch
  binaries. One build tree; disk is tight (~13 GiB free).
- Smallest reversible change that advances the active gate; no broad
  refactors; no renderer/touch/marketing work out of order.
- Simulator proof is never device proof; compilation is never runtime proof;
  encoding validity is never semantic correctness; a shell surface is never
  a game frame; an RX-blob boot is never signed-AOT product proof.
- After each gate: update STATUS + loop-log + 13-current-state, store
  evidence, regenerate/verify the canonical patch if tracked sources
  changed, commit, and continue to the next gate.
- Do not push, merge, publish, or open a PR unless explicitly authorized.

## 7. Done condition

The roadmap is complete only when S2.1 (engine integration to a stable
renderer-ready boundary), S2.2 (first real Jak 1 frame through Metal from
game systems), S3 (touch + lifecycle MVP), and R1 (ROM-safe reproducible
clean-checkout handoff) are PASS with evidence, STATUS and 13-current-state
agree, the canonical patch verifies against the pin
`641fb572e876750d8618434d9f7c1a531b43b366`, and physical-device acceptance
is either completed or recorded as the only external remaining gate. Do not
write another handoff prompt as a substitute for doing the work.
