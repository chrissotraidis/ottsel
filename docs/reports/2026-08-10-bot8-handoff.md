# BOT8 S2.1 stop report — 2026-08-10

## Current gate and honest product state

**Active gate: S2.1 — GAME.CGO engine integration.**  It is not passed.  The
app has not reached a stable renderer-ready boundary and has not produced a
Jak frame.  S2.2, S3, and R1 remain blocked by S2.1.

The completed gates remain valid: H1–H3, S1, S2.0, and A1.0–A1.2.  Do not
reopen them without contradictory evidence.  GAME.CGO's 346 objects compile,
validate, link, and execute far beyond the original process-spawn failure, but
that is integration progress—not a game-playable result.

## Confirmed working work

- The signed-native proof gates are present and passed: A1.0 semantic
  regressions, A1.1 signed `__TEXT` slice, and A1.2 no-runtime-executable-code
  audit.  The RX-blob GAME loader remains diagnostic-only, never product proof.
- Earlier S2.1 fixes moved the boot through the raw run-function-in-process
  return fault, process-context C stub bug, method-set inheritance scope, and
  Mips2C trampoline stack cleanup.  The current fault is later and distinct.
- The Mips2C trampoline fix is specifically supported by live stepping: its
  two 16-byte private `[stack_size, exec]` slots had been left above the
  bridge frame.  `_mips2c_call_arm64` now discards those 32 bytes before
  `ret`; the semantic harness passed after the corresponding test was added.
- The C-to-GOAL stack-switch bridge now preserves x19–x28 and q8–q15.  This
  is consistent with the project’s stronger GOAL vector-state contract.
- The iOS package loader holds `*enable-method-set*` over the whole KERNEL/GAME
  package, matching the host loader’s cross-object inheritance contract.

## Current fault — proven root cause, fix not yet made

The held Simulator process was stopped and killed at handoff.  The live
forensics below came from that one runtime, after the Mips2C stack fix.

1. Linking GAME object 316 (`fuel-cell`) reaches live code at
   `ee+0x01d75a64`.  The receiver is a valid `merc-ctrl` object:
   `x19 = 0x02a315d4`, and its type pointer `0x01768784` resolves through the
   symbol table to the string `merc-ctrl`.
2. `merc-ctrl.header.eye-ctrl` at `x19 + 0x5c` is **zero**.  This is a valid
   no-eye-control value.
3. The source at `goal_src/jak1/engine/gfx/merc/merc.gc:189-202` is:

   ```lisp
   (cond
     ((not (logtest? -65536 (the-as int (-> this header eye-ctrl))))
      (set! (-> this header eye-ctrl) (the-as merc-eye-ctrl 0))
      0)
     (else ... iterate eye shaders ...))
   ```

   With `eye-ctrl = 0`, `logand(-65536, 0) = 0`, so this must select the first
   arm and skip the eye-shader calls.
4. Live disassembly instead emitted `add`, not `and`:

   ```text
   ee+0x01d75a64  ldur w1, [x16,#0x5c]  ; eye-ctrl = 0
   ee+0x01d75a68  add x0, x0, x1        ; x0 was -65536
   ee+0x01d75a74  cmp x0, x1            ; x1 = 0
   ee+0x01d75a78  b.ne ee+0x01d75a94    ; wrongly enters else
   ```

   It consequently constructs `x0 = 0x10` and calls `ee+0x016bde14`, which
   faults at `ldur w0,[x16,#8]` with `x16 = ee + 0x10`.
5. The emitter source confirms the exact defect:
   `goalc/emitter/IGenARM64.cpp:2282-2287`,
   `and_gpr64_gpr64`, is documented as ADD and uses the ADD shifted-register
   opcode `0b10001011000`.  `Compiler::compile_logand` correctly requests
   `IntegerMathKind::AND_64`, and `IR_IntegerMath::do_codegen_arm64` correctly
   calls `and_gpr64_gpr64`.  Therefore this is an **ARM64 AND encoder bug**,
   not a source/game-data issue.

The next change is small and falsifiable: add an A1.0 encoding/semantic
regression that fails while `and_gpr64_gpr64` emits ADD and asserts the AND
word/disassembly plus zero-mask behavior; then change only that emitter opcode,
rebuild the compiler and CGOs, and boot.  Do not touch `merc.gc` to mask this
compiler defect.

## Working tree and cleanup state

- Parent repo is intentionally dirty with docs/evidence and `src/shell/ios_boot.cpp`.
- `out/jak-project` is intentionally dirty with the accumulated ARM64 runtime,
  compiler, and tooling changes.  These are source changes under the canonical
  patch workflow, not assets.  Its `iso_data/jak1/.gitignore` deletion and
  untracked debug/tool files must be audited before staging; do not indiscriminately
  stage the worktree.
- No OttselShell or LLDB process remains.  One iPad Pro 11-inch (M4) Simulator
  is still booted.
- The temporary object-316 `SIGSTOP` probe was removed before this handoff.
- No ISOs, ROMs, CGO/DGO packages, extracted assets, or scratch binaries may
  be committed.  The canonical patch was regenerated after this stop report
  for publication and verified with clean apply and live reverse-apply checks.

## Exact next sequence

1. Read `docs/BOT6_PROMPT.md`, `docs/15-progress-audit.md`, this report, the
   current gate board, and the newest loop-log entries.  Verify the parent and
   worktree status before trusting any historical claim.
2. Add the A1.0 regression for ARM64 `AND_64` first.  It must distinguish AND
   from ADD with operands such as `-65536` and `0`, and inspect the emitted
   machine word or decoded instruction.
3. Correct only `IGen::and_gpr64_gpr64` to emit the ARM64 logical-shifted-
   register AND encoding.  Preserve register fields and avoid broad emitter
   refactors.  Run the full A1 semantic harness.
4. Regenerate/validate KERNEL.CGO and GAME.CGO, rebuild the Windowed iOS app,
   ensure zero stale app processes and only one booted Simulator, then boot.
   Capture the new log under `docs/evidence/S2/`.
5. The minimal runtime pass criterion is: the `merc-ctrl` zero-eye-control
   branch no longer calls `ee+0x016bde14` with x0=0x10 and advances past this
   fault.  That is not S2.1 PASS; continue with the next independently
   evidenced fault.
6. Once a genuine gate passes, update `STATUS.md`, `13-current-state.md`, and
   `00-loop-log.md`, verify/regenerate the canonical patch against pin
   `641fb572e876750d8618434d9f7c1a531b43b366`, then commit only the relevant
   sources/docs/evidence.  Do not push or publish.
