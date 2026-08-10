# S2.1 progress — ARM64 AND encoder fixed; boot links all 346 GAME objects (2026-08-10)

## Proven fix (regression-first)

The `merc-ctrl` zero-eye-control crash (BOT8 handoff) was caused by
`goalc/emitter/IGenARM64.cpp` `and_gpr64_gpr64` emitting the ADD
shifted-register encoding (`0b10001011000`) instead of the AND
shifted-register encoding (`0b10001010000`).

1. **Regression added first** — `tools/ottsel_a1/semantic_regressions.cpp`
   tests 24-25:
   - Emitter-unit: `and_gpr64_gpr64(X0, X1)` must emit a word with top-11
     opcode `0x450` (AND), never `0x458` (ADD); plus the zero-mask semantics
     check `AND(-65536, 0) = 0` selects the no-eye branch while
     `ADD(-65536, 0) = -65536` would enter the eye path.
   - GOAL-compile: `(defun f ((v int)) (logand -65536 v))` through the real
     ARM64 goalc must contain an AND-shifted word and no ADD-shifted word.
   - Red phase (before the fix): `[A1.0] FAIL: 3 semantic assertion(s)`,
     `word=0x8b010000 op=0x458`; the GOAL function emitted
     `add x1, x1, x0` (`0x8b000021`).
2. **One-word fix**: `and_gpr64_gpr64` now uses `Base(0b10001010000, 11)`
   (logical shifted-register AND). No other emitter code changed.
3. **Green**: full `ottsel-a1-sem` suite passes —
   `[A1.0] PASS all semantic regressions`
   (`docs/evidence/A1/a1-semantic-regressions-andfix-green.log`).

## Regenerated + validated artifacts

- KERNEL.CGO: 86,016 code words PASS (8 objects).
- GAME.CGO: 3,985,408 code words PASS (346 objects).
- The merc-ctrl eye-check site (object `merc`, main seg +0x1a6c) now emits
  `and x0, x0, x1` (`0x8a010000`); the pre-fix word was `add x0, x0, x1`
  (`0x8b010000`).  With `eye-ctrl = 0` the AND result is 0, `cmp` is equal,
  `b.ne` is not taken, and the no-eye branch runs (set eye-ctrl = 0, return
  0) — no raw `x0 = 0x10` call.
- GAME.CGO now contains 4,128 AND-shifted words (the buggy emitter could
  produce zero); KERNEL.CGO 64.

## Boot milestone: all 346 GAME objects link; first kernel-dispatcher call

The rebuilt Windowed iOS app (`scripts/build-ios.sh`, one iPad Pro 11-inch
(M4) Simulator, no stale processes) advances through every GAME object —
`fuel-cell` (316), `eichar` (323), `sidekick` (324), through
`hud-classes-pc` (345) — and logs
`OTTSEL_IOS: GAME.CGO linked (346 objects)`.  The prior `merc-ctrl`
zero-eye fault is gone.  Evidence: `s21-andfix-pc0-boot.log`.

### Stage-slot sizing fix (required by the new objects)

Object 323 `eichar` (1,349,024 B) exceeded the iOS loader's 512 KB reusable
CGO stage slot (`src/shell/ios_boot.cpp`, `STAGE_SLOT`).  Resized to 2 MB
with the measured max (1,349,024 B) documented; `sidekick` (675,936 B) was
the other over-512 KB object.

## New blocker (S2.1 remains ACTIVE): dispatcher first call -> pc = 0

The boot reaches the first `kernel-dispatcher` call (`fptr=0x70001e6054`)
then faults deterministically:

```text
signal 11 at pc=0x0000000000000000 fault addr=0x0000000000000000
sp=0x00000070001f4be0
x0=0x18fe04(st) x1=0x70001e8b68 x2=1 x3=0x239c004
x16=0x<ASLR>402c (pc_prof native) x20=0x23b844 x21=st x22=ee
```

Forensic evidence captured (`s21-andfix-pc0-fault.log`):

- The stack region at and above the fault-time sp (`0x1f4be0`) is all zeros
  for 0x400+ bytes — a fresh, never-pushed stack; `pc=0` and `lr=0` are an
  indirect branch/return through a zero register.
- `x16` is the native address of `pc_prof(unsigned int, ProfNode::Kind)`
  (symbolized via lldb) — the C-export profiler called by the GOAL kernel's
  first statement `(profiler-instant-event "ROOT")` -> `(pc-prof ...)`.
- The pc-prof C-export stub at EE+0x04F02FD4 is intact in-process:
  `ldr x16,[pc,#0x20]; str x16,[sp,#-16]!; ldr x17,[pc,#0x20]; nop;
  br x17` with the target field at +0x20 = the native `pc_prof` address.
- The dispatcher code at 0x1e6054 still contains UNPATCHED ADRP placeholders
  (`adrp x2, #0`) at dispatch time; the raw chain would fault at a garbage
  load (`ldr w2,[0x6aa1601eb]`), which does not match the observed pc=0
  fault, so the faulting call is a *different* pc-prof call site (game /
  process-tree context, pp=0x23b844).
- lldb's external `memory read` is unreliable for the Simulator's EE mapping
  (differs from in-process reads); all EE reads above were done in-process.

The smallest falsifiable next probe: trace the GOAL caller of the pc-prof
C-export call during the first `execute-process-tree` pass (the process
context `pp=0x23b844` / `x3=0x239c004` points at the game process tree) and
verify the fresh-stack / x30=0 entry contract.  Do not patch `merc.gc` or
game source around this; it is a runtime/ABI integration defect.

## Honest status

S2.1 is NOT PASS: there is no stable renderer-ready boundary and no Jak
frame.  The AND fix and the all-346-object link are integration progress.
A1.0/A1.1/A1.2 remain PASS (not reopened).
