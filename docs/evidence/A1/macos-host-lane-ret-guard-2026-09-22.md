# macOS lane: the .ret guard window is the iPad signed arena - 2026-09-22

Gate: L1 (restore the macOS oracle).  Question: why does the macOS lane fault in the `IR_AsmRet` guard
during boot while the iPad lane boots to the title on the same emitted objects?

Lane layout, measured on the rebuilt host lane (`out/jak-project/build/h1/game/gk`, 2026-09-22 10:04):
- EE is mapped at `0x7000000000` (128 MB; the port's own crash dump prints `base=0x7000000000`).
- Every GOAL code segment goes to one region the no-emit loader logs once:
  `OTTSEL no-emit: dedicated code region 0x3ebc000..0x4ee0000 (page 0x4000)`, base
  `OTTSEL_CODE_BASE = (GLOBAL_HEAP_END + 0x3fff) & ~0x3fff` (klink.cpp:45); the port's own code-address
  test hardcodes the same band (kscheme.cpp:211).
- The iPad signed lane differs by construction: `ARENA_SIZE = 128 MB` (emit-signed-module-arena.py:22)
  and module code must sit at offsets `>= manifest.arena_size` (ottsel_signed_gstate.cpp:109), so its code
  band is exactly `[x22+0x8000000, x22+0x8c30000)` - the guard's window.  This lane's C++ callees also
  modify the GOAL register set: the A1.7b counters read live at the fault gave `calls = 70423`,
  `leaks = 5`, last `jak1::print_string` (kscheme.cpp:1745) in `0x100326adc` -> out `0x1c422b4`
  (sampled before the A1.7c restore, so diagnostics rather than live corruption).

The guard, disassembled live at the first guarded `.ret` of the faulting gkernel frame:

```
0x7003ed6c00: mov x9,#0x8000000 ; add x9,x9,x22  -> x9 = 0x7008000000   (lo)
0x7003ed6c08: mov x10,#0x8c30000 ; add x10,x10,x22 -> x10 = 0x7008c30000 (hi)
0x7003ed6c10: sub x11=x17-x9 ; sub x12=x17-x10 ; lsr #63 both ; sub x12,x12,x11
```

At the fault the slot `x17 = 0x0000007003ed79b4 = ee + 0x3ed79b4` - a real gkernel continuation inside
the logged code region - and `x11 = x12 = 0`, so keep = 0: the guard rejected it and returned through
`x16` (the incoming link register).  `x9`/`x10` are the iPad arena band and this lane has no code at
`ee+0x8000000` at all, so **every guarded `.ret` on the macOS lane rejects its legitimate return value**.
That is the L1 question answered at the mechanism level.

The fault itself (three identical reproductions; same registers as the parity review):
`pc = ee+0x3ed6d54` (gkernel main seg0 +0x6d54, `ldur w0, [x16, #-4]`), `x16 = x24 + x22`,
`x24 = 0x00000001003b95a4 = &EnableMethodSet` (a host pointer into gk's data segment, confirmed with
`nm` and `expr -- (void*)&EnableMethodSet`), `x23 = 0x00000001003b9194 = &s7`, `x22 = g_ee_main_mem`,
`x20 = 0x211194`, `sp = ee+0x7fffe50`, `si_addr = 0x71003b95a0`.  lldb backtrace: `link_and_exec`
(klink.cpp:957) <- `load_and_link_dgo_from_c(name="game", ...)` (kdgo.cpp:197) <- `InitMachineScheme`
(kmachine.cpp:675) <- `InitHeapAndSymbol` <- `goal_main`: the C++ boot DGO link that jumps into GOAL from
`jak1_finish`.  That caller has just run `*EnableMethodSet = (*EnableMethodSet) + 1` (kmachine.cpp:673-677),
so its live callee-saved registers hold exactly `&EnableMethodSet` and `&s7` - the two host addresses
present in the GOAL register file at the fault.

The enclosing GOAL function (gkernel+0x6c54: `str x19/x23/x24/x30`, `mov x24, x0` from
`ldur w0, [x20+ee+0x58]`, #f live) calls the `throw-dispatch` symbol value indirectly just before the
fault, and the guarded `.ret` at 0x6c48 is that asm-func's own return.  Read live, `[sp] = 0x3ed7894`
and `[sp+0x50] = 0x3ed79b4` are bare EE offsets rather than host addresses, and the frame does not carry
this function's saved x19/x23/x24/x30, so the faulting block did not run through that prologue; x24 was
already the C++ value.  Whether the guard's fallback return or a bridge let it through is the next single
measurement.

Fix shape, validated by measurement: accept the slot in either lane's code band -
`[ee+0x3ebc000, ee+0x4ee0000)` (macOS) or `[ee+0x8000000, ee+0x8c30000)` (iPad) - and reject everything
else.  Both bands exclude the iPad lane's module data (measured `0x3ea8000..0x3eb8000`) and the GOAL stack
top (`ee+0x7fffe10`, the A1.11 escape), and the macOS lane has no code in the iPad band.  One widened range
instead of two would be wrong: it would re-admit `ee+0x7fffe10`.
Next: emit that two-band test in goalc, keep `scripts/test-a11-asm-ret-guard.sh` in step, re-emit
(`goalc --game jak1 --isa arm64 -c '(mi)'`), then require the macOS lane to reach the title with a 0-byte
fault log and the iPad lane to keep its two clean strict runs.  Not claimed: the macOS lane is not restored; no playability, audio or lifecycle claim.
