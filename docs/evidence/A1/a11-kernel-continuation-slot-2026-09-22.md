# A1.10 - display-loop's lost x19 was a suspend-return defect (2026-09-22)

Gate: G1.18, the strict signed-GAME lane losing `*display*` (x19) in `display-loop`.

Question: at `main+0xbf08` (`display-loop`'s loop-end `(suspend)`) x19 still holds `*display*`
(0x509d34), but at the resume point `main+0xbf0c` it is a host stack address, pp (x20) is 0 and
x30 is the pc, so the loop runs on with a foreign register file and dies at the next x19 use
(`main+0xa328`, or the `draw-string` call at `main+0xb08c` into `font`). Which call changes it?

Method: lldb on the held app.  Hardware breakpoints only (software breakpoints on `__GOAL` text
abort the loader's validate_layout).  lldb `-c` conditions are not reliable with hardware
breakpoints - they were observed true while the stopping frame's own x19 was correct - so the
bisection used lldb Python breakpoint callbacks that read the stopping frame's registers directly.
One bisection per run, `continue` between sites.

Evidence (fresh run, ee = 0x1055d0000):
- Site trace: `off=0x817c val=0x509d34 ok`, `off=0x8248 ok`, `off=0x8388 ok`, `off=0xbf08 ok`
  for whole iterations; the failing iteration stops with
  `off=0x817c val=0x10cfabe10 pp=0x0 x23=0x10cfabe10 BAD` - i.e. already wrong at the first site
  of the new iteration, so the change happens across the (suspend) boundary.
- At the suspend call `main+0xbf08`: x19 = 0x509d34, pp = 0x1f5444 (the cpu-thread), sp = the
  display stack.  The thread object at 0x1f5444 reads `+0x14 pc = 0x88b80cc`, `+0x18 sp = 0x1d7f50`
  (= the live display sp), `+0x20 stack-size = 0x200`, `+0x24 rreg0 = 0x509d34` - the save side
  is correct.
- Breakpoints on `thread-suspend` (gkernel+0x1e44) and `thread-resume` (gkernel+0x20a4): every
  good dispatch prints a thread-resume before the resume point; the failing dispatch prints
  `main+0xbf0c` immediately after the suspend with `x30 == pc == main+0xbf0c`, `pp = 0` and sp in
  the kernel stack.  So the suspend returned through the guarded `.ret` in thread-suspend straight
  into its own caller's continuation, with the kernel's register file, and thread-resume never ran.
- The guard's slot at that `.ret`, read from the live process: `[sp] = 0x00000050ffffffff` (a GOAL
  frame local - the same value the A1.8 note records).  The window test rejects it, and the
  fail-safe then falls back to the incoming x30; for an asm-func entered by a GOAL call that is the
  caller's link register, not the kernel's return address.
- thread-suspend goes back to the kernel by reading `[*kernel-sp* + 0x50]`, exactly where its five
  `.pop s4..s0` end.  That slot only holds a continuation when the kernel left a GOAL synthetic
  slot there; measured, it can hold plain frame data instead.  x30 at thread-resume's entry is the
  kernel's real continuation (lookup: `gkernel_s0_code + 23892`).

Fix - `goal_src/jak1/kernel/gkernel.gc`, overlay `patches/a11-kernel-continuation-slot.patch`:
- thread-resume and reset-and-call push their incoming x30 (new `(lr :reg x30 ...)` rlet binding) as
  the first of the kernel-stack slots, so `*kernel-sp* + 0x50` always holds a real continuation.
- thread-suspend, return-from-thread and return-from-thread-dead pop that sixth slot into lr and
  leave with `(.jr lr)` instead of `(.ret)`, so the kernel resumes at exactly the sp the caller left
  (no drift) and the fallback is never reached on this path.
- Not shipped: the first variant pushed the sixth slot without popping it; the kernel stack then
  drifted 0x10 per dispatch and the run died in a stack-guard region within ~2 minutes.

Verified:
- `goalc --game jak1 --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'` exit 0, objects
  rewritten; strict build (OTTSEL_SIGNED_GSTATE_EXPERIMENT=0, MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json,
  EXPORT_BANKS=1) exit 0.
- Shipped `__GOAL,__text` carries the new prologue at exactly two sites (`str x30,[sp,#-0x10]!`
  then `str x19,...`): file 0x108979dac (reset-and-call) and 0x10897a0d4 (thread-resume).
- Fresh strict run: all 15 DGO objects served (title-vis last), level linked, `OTTSEL TEX REMAP`
  reported, and the display loop runs 6131+ frames at drawn=0, where before it lost x19 inside the
  first four loop iterations.  The display-loop class is retired.
- Open (same shape as the documented A1.1 class, now at `gkernel+0x60a8`): a later `.ret` still
  targets a GOAL data address with pp = 0 (pc = lr = ee + 0x7fffe10, the `*kernel-sp*` slot).  Two
  clean strict runs are not yet achieved, so the pp=0 class stays open.

