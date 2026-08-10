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

## Bounded call trace (2026-08-10): the pc-prof caller is identified

Re-enabled the goalc call-recorder shim (`OTTSEL_TRACE_GOAL_CALLS`) for one
diagnostic build and re-booted.  The last GOAL->GOAL calls before the fault
(`docs/evidence/S2/s21-trace-pc0-fault.log`) are:

```text
site=0x2475014 target=0x060c8b4 caller-lr=0x2480a9c pp=0x24b844   ; game process code
site=0x1f0ca4  target=0x1e4774  caller-lr=0x00000000 pp=0x24b844  ; gkernel fn
site=0x1f0f80  target=0x04f02fd4 caller-lr=0x00000000 pp=0x24b844 ; pc-prof stub (LAST)
```

Proven facts from the trace + in-process reads:

- The pc-prof C-export stub at EE+0x04F02FD4 is correct: its embedded target
  is the native `pc_prof` address and its trampoline is `_arg_call_arm64`
  (`stp x29,x30; ldr x8,[sp,#16]; ...; blr x8`), verified in-process.  The
  whole C-export path (shim -> stub -> trampoline -> pc_prof -> return) is
  sound.
- The faulting function is a **gkernel** function (kernel main code
  0x1e4000-0x1f9328, per the boot log's per-object `main seg 0` offsets):
  the profiler-calling family (`kernel-dispatcher` / its
  `execute-process-tree` lambda at `goal_src/jak1/kernel/gkernel.gc:1334`).
- The function was **entered with x30 = 0 and zeroed callee-saved registers
  on a fresh, all-zero stack** (fault sp = 0x2004be0 with the tracer build /
  0x1f4be0 product; the 4 saved-register slots at sp-0x40..sp and the
  tracer's pushed slots below are 0/EE-garbage, no pushed return address).
- Its body ran completely (the pc-prof call was recorded), and the fault is
  the function's epilogue `ldr x30,[sp]; ret` returning through the saved
  x30 = 0 -> pc = 0, lr = 0.  The caller-lr = 0 recorded for BOTH of the
  function's last calls confirms x30 was already 0 during its body.
- The pp context (x20 = 0x24b844) is a game process; the immediately
  preceding recorded calls are that process's code (game-object sites
  0x2474xxx -> 0x060cxxx), so the kernel function was entered from the game
  process execution context via a tail call (`br`) with x30 = 0 - the
  signature of the process-thread start machinery (`reset-and-call`,
  `gkernel.gc:495`, ends in `.jr func` - a tail jump that does not set x30,
  running the callee on the thread's fresh stack).

Root-cause boundary (honest): the defect is in the process-thread execution
contract - a kernel/thread function is entered on a fresh zeroed stack with
x30 = 0 and no pushed return address, so its epilogue returns to pc = 0.
The exact caller transition (which game function tail-calls the gkernel
function) is not yet proven.  The next probe is static: name the functions
at 0x1f0xxx and 0x2475014/0x2480a9c via the object debug info, then read the
GOAL source of the transition.  Do not patch game source around this.

Diagnostic hygiene: the tracer was reverted (goalc/CMakeLists.txt), the
product KERNEL.CGO/GAME.CGO were regenerated (22,795,344 / 403,920 bytes)
and revalidated, the app rebuilt, and one product boot re-captured
(`s21-pc0-product-boot.log`): the same pc=0 fault reproduces
(sp=0x70001f4be0).  The fault handler keeps a bounded trace dump (reads the
always-compiled recorder ring; harmless with the tracer disabled).

## Crash reports (Simulator DiagnosticReports)

`s21-crash-eichar-stageslot-135713.ips` (13:57:10, pid 52224) is the SIGABRT
of the FIRST boot after the AND-fix CGOs: `gated_fail` from
`ottsel_ios_link_cgo_from_bundle` with the faulting thread's x25 =
0x1495a0 = 1,349,024 - exactly `eichar`'s blob size exceeding the old
512 KB stage slot ("object blob larger than the reusable stage slot").
This is the failure the STAGE_SLOT resize (512 KB -> 2 MB, committed in
`cf2fe37`) fixes; the current app reaches the pc=0 dispatcher fault instead
of aborting here.

`s21-crash-methodset-assert-142208.ips` (14:22:08, pid 54744) is a separate,
non-deterministic failure on the same binary: `private_assert_failed` inside
`jak1::method_set` called through the C-export trampoline
(`arg_call_arm64`) from a GOAL top-level (EE ~0x3ab0004) during a link
`jak1_finish`.  Only one boot hit it; the others reached the pc=0 fault.
It is consistent with the same broken GOAL-call-context class as the pc=0
fault (a GOAL call into a C export carrying corrupted state), and it is
recorded here as evidence, not yet root-caused.

## Function identity (2026-08-10): the faulting function is the
execute-process-tree lambda

`tools/ottsel_a1/kernel_fn_dump.cpp` (target `ottsel-kernel-fn-dump`)
compiles the real kernel group in order through the ARM64 goalc and names
every gkernel function with its emitted code size
(`docs/evidence/S2/s21-kernel-fn-dump.log`):

```text
iterate-process-tree  code=468 bytes
execute-process-tree   code=468 bytes
anon-function-5        code=2444 bytes
kernel-dispatcher      code=0 (emit skipped)
```

`anon-function-5` (2444 bytes) is the anonymous lambda passed to
`execute-process-tree` inside `kernel-dispatcher`
(`goal_src/jak1/kernel/gkernel.gc:1334`).  Its emitted code has the same
shape as the faulting function's live disassembly: multiple calls with
`(static-string, 1)` arguments (including the pc-prof profiler-start with
`x1 = 1`), stores into `[x19+0x20]` / `[x23+0x14]`, and a `mov x0, x21`
return path.  This matches the trace's last calls
(`0x1f0ca4 -> 0x1e4774`, `0x1f0f80 -> pc-prof`, both caller-lr = 0).

`execute-process-tree`'s emitted lambda call uses the full call shim
(`str x30; adr x17; str x17; add x16,x16,x22; blr x16`) - so a normal
dispatch sets the lambda's x30.  The faulting run therefore did NOT enter
the lambda through execute-process-tree's shim: the observed entry state
(x30 = 0, x20 = the process 0x24b844, sp = *kernel-dram-stack* top
0x1f4be0, all callee-saved registers zero, no pushed return address) is the
signature of the process-thread machinery - `reset-and-call`
(`gkernel.gc:495`) / `set-to-run-bootstrap` (`gkernel.gc:1832`) both end in
a tail jump (`.jr func`) that does not set x30 and run the callee on the
thread's (dram) stack.  A tail-call chain with x30 = 0 into the lambda
makes its epilogue `ret` (restoring x30 = 0) fault at pc = 0.

Root cause is thereby narrowed to the process-thread entry/return contract,
not the C-export path (verified correct) and not a compiler encoding bug.
The next probe: verify the exact tail-call transition into the lambda (which
game function / thread entry leaves x30 = 0 and sp on the dram stack) and
fix the entry contract so a GOAL function entered with x30 = 0 cannot return
through a zeroed x30 on a fresh stack.  Do not patch game source around
this.

## pc-prof event resolution + entry-chain confirmation (2026-08-10)

- `pc-prof-event` (`goal_src/jak1/kernel-defs.gc:603`) is `begin=0, end=1,
  instant=2`.  The faulting pc-prof call emits `x1 = 1` = the profiler-END
  event - which runs AFTER the lambda's process execution, fully consistent
  with the trace order (game process code first, then the lambda's
  profiler-end calls).
- The trace's caller-lr values that looked like EE addresses in the
  5.3 MB/84 MB range (e.g. 0x50e2cd4) are the LOW 32 BITS of native
  addresses: the recorder stores `(caller_lr & 0xffffffff)` and the
  bridge's post-blr is native 0x1050e2cd4-ish.  The dispatcher was entered
  normally by the bridge; there is no dispatcher-entry anomaly.
- A below-sp fault dump (`s21-pc0-belowsp-fault.log`) shows the lambda's
  frame slots at sp-0x40..sp are all zero (entered with zeroed callee-saved
  registers), and the pc-prof call chain's pushes sit below the frame with
  `[sp-0x10] = 0` (the shim's saved x30 = 0) and `[sp-0x20] = 0x1e5fec`
  (the post-call continuation in the product gkernel code).  The lambda
  ran its ENTIRE body on the fresh zeroed stack at sp = 0x70001f4be0 with
  x30 = 0 and no pushed return trampoline - a plain tail-call (`br`) entry
  from a context with x30 = 0.
- The defect is the ARM64 GOAL call/return fragility exposed by the
  process-thread tail jumps: a function entered with x30 = 0 restores x30 =
  0 in its epilogue and `ret`s to pc = 0.  The exact `br` source (which
  thread/process function chain) remains the next probe; the fix must make
  the entry set x30 (or make the epilogue not depend on the entry x30).

## Sky-process identification + ABI mechanism refinement (2026-08-10)

- The trace's "game process code" (sites 0x2474xxx -> targets 0x060cxxx) is
  the **sky** object's code (sky-tng is the caller; the targets are
  `trigonometry`), so the process being processed by the faulting lambda is
  the sky background process (pp = 0x24b844).  The sky code calls
  trigonometry helpers in a loop, then the lambda's profiler-end runs and
  the epilogue rets to pc = 0.
- The ARM64 GOAL asm `.ret` convention (A1.0 test 11) loads x30 from [sp]
  WITHOUT post-index, and the caller's post-call pops the pushed
  continuation + its own x30 - so the thread-suspend/return-from-thread
  return path is internally consistent.  The lambda's x30 = 0 at its
  profiler-end therefore reflects its ENTRY x30 = 0 (a tail-call / .jr
  entry), not a mid-body corruption.
- The below-sp dump shows 0x1e5fec (a gkernel code address) in the slot
  region below the frame - consistent with a pushed return/trampoline
  value being present but the entry x30 (the actual return register) being
  0, so the epilogue rets to pc = 0 instead of the pushed value.
- Remaining probe: identify the exact tail-call/.jr entry into the lambda
  (reset-and-call sets pp = the process, matching the observed pp; the
  trampoline slot value needs one more in-process read to confirm which
  entry pushed it).  The fix: ensure the entry sets x30 (or the GOAL
  epilogue returns via the pushed stack return like the asm .ret), then
  re-verify the full boot.

## Thread-entry x30 fix applied; the fault moved (2026-08-10)

The ARM64 GOAL function epilogue returns via its ENTRY x30 (the caller's
blr value).  The process-thread tail jumps (`reset-and-call`'s `.jr func`,
`set-to-run-bootstrap`'s `.jr s0`) leave x30 unset, so the entered function
returns to a stale/zero x30 -> pc = 0.  Fix applied in
`goal_src/jak1/kernel/gkernel.gc` (both functions): bind `lr :reg x30` in
the rlet and add `.mov lr temp` after pushing the return trampoline, so the
entered function's epilogue returns to return-from-thread /
return-from-thread-dead like the x86 model.

Result (verified boot): **the pc=0 dram-stack fault is gone**.  The new
fault (`s21-pc0-x30fix-fault.log`) is on the kernel GOAL stack
(sp = 0x7007fffdf0, lr = 0x70001e5470, x20 = 0):

```text
signal 11 at pc=0x000000708b36e010 fault addr=0x000000708b36e010
x1=0x8b36e010 x16=0x7008b36e010   ; a code word (add x16,x0,x22,sxtx) as a target
```

The thread now returns through the trampoline, but the return-from-thread
kernel-stack return slot is misaligned: a code word is popped/used as a
function pointer in the kernel-stack return path.  This is the next layer
of the same process-thread return ABI issue; the x30 fix stays (it is
proven to move the boot forward).

## Dispatch-loop milestone + next fault (2026-08-10)

The x30 fix unblocked the kernel dispatcher: the boot now runs
`call_goal_on_stack(kernel-dispatcher)` **10,482 times** (the dispatcher
loop iterates and returns cleanly; `s21-dispatch-loop-x30fix.log`).  This
is the first time the dispatcher has ever looped on the Simulator with
GAME.CGO loaded - a significant S2.1 milestone (still not a game frame).

The new fault (`s21-dispatch-loop-x30fix-fault.log`) is a method dispatch in
the process-tree path:

```text
signal 11 at pc=0x000000708b36e010 fault addr=0x000000708b36e010
lr=0x70001e5470 x16=0x7008b36e010 x1=0x8b36e010 (a code word)
```

The dispatch (`ldur w1,[type+0x40]; add x16,x1,x22; blr x16`) runs on an
object at 0x22f9f4 whose type tag at [obj-4] = 0x2381704 - a GAME CODE
address, not a Type (in-process reads show code words there).  The method
table read therefore returns a code word and the call faults.  Next probe:
identify which object/process 0x22f9f4 is and why its type tag is a code
address (corrupt object or wrong `this` in the process-tree iteration).

## Offline-link confirmation (2026-08-10)

The host-side offline link (`game/ottsel_cgolink_dump.cpp`, extended with
the fault-region dumps; `s21-cgolink-dump.log`) links KERNEL.CGO + GAME.CGO
with the same runtime linker and confirms:

- The faulting dispatch function at sim 0x1e53e0 matches the live
  disassembly byte-for-byte (the word at sim 0x1e5450 is exactly
  `0x8b36e010` = `add x16,x0,x22,sxtx`, the value that became the fault's
  method pointer).
- The object 0x22f9f4 and the "type" 0x2381704 are RUNTIME state (the
  host-linked image holds zeros there) - both are created during the
  Simulator boot (the process-tree / game process setup), not in the static
  link.

So the fault is a runtime process-tree object whose type tag was set to (or
overwritten with) a game-code address.  The next probe is to identify the
object's role (its pool/parent fields, vs *active-pool*) and which code
writes its type tag.

## Faulting function identified: execute-process-tree's run-logic? dispatch

The kernel-fn-dump tool now flags every compiled function whose emitted code
contains the dispatch pattern (`ldur w0,[x16,#-4]; add x16,x0,x22,sxtx;
ldur w1,[x16,#0x40]`).  It matches **`execute-process-tree`** - the
`(run-logic? this)` method call on the iterated tree node.  So the fault is
execute-process-tree dispatching the run-logic? method on a tree node whose
type tag is a game-code address.

In-process node reads (`s21-node-fields.txt`): the node at 0x22f9f4 has
real pool/neighbor pointers (0x232b7c, 0x230a7c, 0x22f94c, 0x22f934, st),
so it is a genuine heap-allocated tree node - but its type tag at [obj-4] =
0x2381704 is a game-code address whose contents are code words, so the
run-logic? method read returns a code word and the dispatch faults.

Next probe: determine why the node's type tag is a game-code address -
whether the game's deftype/type objects are missing/corrupt (the type at
0x2381704 should be a game Type, but its symbol field reads as code), or
whether a memory overlap placed game code over the type region.

The *active-pool* symbol's value = 0x1982c4 (kernel heap); the faulting
node 0x22f9f4 is ~620 KB above it, with real pool/neighbor pointers - a
genuine process-tree node in the pool region whose type tag is the
game-code address 0x2381704.  The probe for the next iteration: trace the
node's creation (the pool's process spawn / `(new 'process-tree ...)`) and
the write of its type tag, and check whether the game's Type objects exist
at all (a missing/corrupt game type table would resolve type pointers to
code).

## Code/data overlap identified (2026-08-10)

The type tag 0x2381704 falls inside the **`time-of-day` object's main code
segment** (0x2380000-0x2388434, from the boot log's per-object main-seg
layout).  The node's type pointer therefore points at game code, and the
run-logic? method read returns a code word.

The game's code placements (cumulative, ~0x574000-0x248xxxx) sit INSIDE the
global heap range (0x13fd20-0x3eb82e0), so runtime heap allocations (the
game's Type objects, created by the deftype top-levels during the link) can
land in the same region the code later occupies - a code/data overlap that
turns Type objects into code words.  The kernel's small data footprint
never collided; the game's larger allocations reach the code region.

Next probe: verify the overlap by comparing the game's heap allocation
addresses (the Type objects) against the code placements, then fix the
loader/link placement so code and heap allocations do not collide.

Verification (in-process, `s21-overlap-boot.log`): the "type" at 0x2381704
reads as 0x910b4210 (an ADD-immediate code word), consistent with the
time-of-day code segment covering it.  The earlier trace's sky-process
addresses differ per boot (heap state), so a single-boot pointer check is
not conclusive, but the type-at-code-address pattern is confirmed.  The
fix direction is the loader/link placement: keep the game code placements
out of the global heap's allocation range (or allocate the runtime Type
objects above the code region) so deftype-created Types are not overwritten
by code.

## Honest status

S2.1 is NOT PASS: there is no stable renderer-ready boundary and no Jak
frame.  The AND fix and the all-346-object link are integration progress.
A1.0/A1.1/A1.2 remain PASS (not reopened).
