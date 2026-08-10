# S2.1 — host-side offline CGO link+dump analysis (2026-08-10)

Purpose: reproduce the Simulator's linked KERNEL.CGO + GAME.CGO image
host-side and disassemble the throw/process machinery that faults in
`s21-trace4-boot.log`, without burning full Simulator boot cycles.

## Reproduction commands

```sh
# tool: out/jak-project/game/ottsel_cgolink_dump.cpp (built in build/h1)
# it links the same CGOs with the same runtime linker, then dumps regions.
out/jak-project/build/h1/game/ottsel-cgolink-dump out/jak-project/out/jak1/iso
# -> prints "throw-dispatch pattern found @ 0x001b1bf4" (the scan), plus
#    region dumps (see the tool source for the current dump list).
# disassemble a dumped region:
awk '/<region header>/{f=1;next} /^=====/{if(f)exit} f&&/^0x/{print "    .word " $2}' \
  <dump.log> > /tmp/x.s
printf '.text\n.globl _x\n_x:\n' | cat - /tmp/x.s > /tmp/x2.s
clang -target arm64-apple-darwin -c /tmp/x2.s -o /tmp/x2.o
llvm-objdump -d /tmp/x2.o   # Xcode toolchain: .../Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-objdump
```

## Layout mapping

- Kernel-region offsets reproduce the Simulator with a constant -0x40000
  delta: `throw-dispatch` scan hit at offline 0x001b1bf4 = sim 0x001f1bf4
  (matches trace[-1] target exactly); rfn at offline 0x001b2df4 = sim
  0x001f2df4.
- GAME main-seg offsets do NOT map with the same delta (dump at
  offline 0x0240a5e0 = zeros). For GAME-region ground truth, read the LIVE
  Simulator process memory (ee base 0x7000000000) via lldb instead.

## Verified findings

1. **throw-dispatch (sim 0x1f1bf4) is CORRECT.** Its tail matches the GOAL
   source (gkernel.gc:1531): restore pp->stack-frame-top, saved regs,
   `sp = this->sp + off`, pop a word, push `this->ra + off` (ABSOLUTE), ret.
   Arithmetic: with x22 = 0x7000000000 and a 32-bit `this->ra` (sign-extended
   by ldursw), the result can never be the observed raw 0x001f2df4. Therefore
   the faulting `ret` in s21-trace4-boot.log is NOT throw-dispatch's tail.
2. **catch-frame-new (gkernel.gc:1444)** computes `this->ra =
   (popped call value) - off`; `this->sp = sp - off`. The call shim
   (IR_FunctionCall, IR.cpp) pushes the caller's PRE-blr x30.
3. **rfn = run-function-in-process (sim 0x1f2df4)** prologue saves x19,x23,x30;
   its `(new 'stack 'catch-frame 'initialize func param-array)` call pushes
   rfn's x30 = 0x0244a6c0 (the trampoline continuation) => the rfn catch-frame
   gets ra = 0x0244a6c0, which is what the fault-time stack shows at
   [0x7007fffec0]. That ra is semantically wrong (should be rfn's post-call
   continuation, where its status-case lives) — a real defect in the shim
   contract for asm-funcs — but it does NOT explain the raw-0x1f2df4 fault.
4. **Shim defect (candidate root cause, unproven):** x86 `call` pushes the
   call-site continuation; the ARM64 shim pushes the caller's return address.
   Fix candidate: push the post-blr continuation (adr-based). Requires an
   A1.0 regression first, then CGO recompile + boot. Do NOT change the
   emitter until the faulting ret is identified (step below).

## Next probe (deterministic, still actionable)

- The trace4 app (OttselShell, built 04:22) was held at the fault
  (`HELD AT FAULT for lldb attach`); check `pgrep -fl OttselShell` first.
- lldb attach to the held pid, then:
  1. `memory read` the catch-frame fields at 0x7007fffeb4 with exact
     alignment (type@-4, name@+0, next@+4, sp@+8, ra@+0xc).
  2. `disassemble` the trampoline at ee+0x0244a63c and the continuation at
     ee+0x0244a6c0 (the call site into rfn and where the rfn catch-frame
     dispatches to) — GAME main-seg ground truth lives in live memory.
  3. Identify the FAULTING ret instruction (the last executed instruction;
     the exception PC is the ret target 0x001f2df4, so use the stack return
     chain: 0x7007fffe80 holds the raw 0x001f2df4, 0x7007fffe70 = 0x0244a6c0,
     0x7007fffe50 = 0x0244a668, 0x7007fffe30 = 0x001f2fdc, 0x7007fffe20 =
     0x001f1bb0).
- If the held process is gone: rerun the 2-min ios_boot probe cycle with the
  same app build and capture a fresh s21-traceN-boot.log, then attach.
