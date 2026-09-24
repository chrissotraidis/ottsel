# BOT9 — continue Ottsel from the proven ARM64 AND encoder fault

Read this as an execution loop, not a request for a retrospective.  The
project goal remains the full verified roadmap:

`R0 → A1.0 → A1.1 → A1.2 → S2.1 → S2.2 → S3 → R1`

The active gate is **S2.1**.  A1.0, A1.1, and A1.2 already passed; only add an
A1.0 regression when it gates a new emitter/runtime correction.  Do not claim
gameplay, a game frame, touch completion, or a product execution proof from a
diagnostic RX-blob boot.

## Read and audit first

1. Read `docs/BOT6_PROMPT.md`, `docs/15-progress-audit.md`,
   `docs/reports/2026-08-10-bot8-handoff.md`, `docs/STATUS.md`, and
   `docs/13-current-state.md`.
2. Read newest-first entries in `docs/00-loop-log.md`.
3. Run: `git log --oneline -8`, `git status --short`,
   `git -C out/jak-project status --short`, `pgrep -fl OttselShell`,
   `xcrun simctl list devices booted`, and `df -h .`.
4. Confirm no app process is live before launching.  Keep one executable and
   one booted Simulator, Windowed only.  Never stage assets/ISOs/CGO/DGO/ROMs
   or scratch binaries.

## First active loop: fix only the proven AND emitter defect

Evidence is in `docs/reports/2026-08-10-bot8-handoff.md`:

- GOAL source uses `(not (logtest? -65536 eye-ctrl))` to skip eye setup when
  `eye-ctrl` is zero.
- Live code emitted ADD where it required AND, so zero wrongly takes the eye
  branch and calls with raw x0=0x10.
- `Compiler::compile_logand` and `IR_IntegerMath` route correctly to
  `IGen::and_gpr64_gpr64`.
- `goalc/emitter/IGenARM64.cpp:2282-2287` encodes that helper as ADD.  This is
  the precise defect.

Perform this bounded sequence:

1. Add a focused A1.0 regression before the code fix.  It must prove ARM64
   AND uses bitwise semantics (e.g. `-65536 & 0 == 0`) and validate the emitted
   instruction/word differs from ADD.  Demonstrate it fails with the current
   implementation.
2. Correct only `and_gpr64_gpr64` to the logical shifted-register AND encoding.
   Do not modify game GOAL source as a workaround or refactor adjacent emitter
   code without evidence.
3. Rebuild the semantic runner and run the full suite.  If it fails, diagnose
   that failure before app work.
4. Regenerate/validate CGOs, rebuild the iOS app, and boot once.  Capture a
   fresh S2 evidence log.  Prove the zero-eye-control case skips the old
   x0=0x10 call and advances beyond the prior fault.
5. If a new fault appears, document only the observed state and choose the
   next smallest falsifiable probe.  Do not declare S2.1 passed until all GAME
   integration reaches a stable renderer-ready boundary.

## Completion disciplines

- The canonical patch must be regenerated/verified when tracked OpenGOAL
  sources change, against pin `641fb572e876750d8618434d9f7c1a531b43b366`.
- After an actual gate pass, update `STATUS.md`, `13-current-state.md`, and
  `00-loop-log.md`, store evidence, commit scoped source/docs changes, then
  continue.  Do not push, merge, publish, or open a PR.
- If a runtime hypothesis is not proved, state it as unproven and leave the
  smallest discriminating experiment—never change the emitter on speculation.
