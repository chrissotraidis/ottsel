# A1.0 — object-204 (mood-tables) fault localized below the boot loop

## Method

Bounded GOAL->GOAL call trace (probe preserved as
`a1-bounded-call-trace-probe.patch`): a goalc IR_FunctionCall shim records
(call-site address, target GOAL pointer) into a 256-entry C ring buffer; the
gated signal handler dumps the last 48 calls + registers at fault time.
One Simulator boot reproduces the fault deterministically; no repeated
boots are needed.

Shim pitfalls fixed during the probe build (documented in the patch):
- recorder is a C call and clobbers x8-x15/x30 -> shim must save x0-x15 +
  x16/x17 (a first version destroyed the function pointer living in x8 and
  every call jumped to garbage).
- symbol-slot resolution needs the +offset (EE base) add BEFORE reading the
  symbol value (missing it SIGSEGVs inside the shim).
- per-call-site capture uses `adr x1, .`; the validator's PC-rel round-trip
  reassembler mishandles ADR (byte immediate), so the probe build reports
  ADR round-trip mismatches -- legal A64 (clang assembles identically) and
  irrelevant once the probe is stripped (product build validates clean).

## Result (2026-08-09, Simulator UDID 08636791-2675-4675-8335-EF72EF954DCF)

Boot links all 346 GAME.CGO objects; the fault is in object 204
(mood-tables) top-level execution, exactly as recorded in S2.1:

```
OTTSEL link: executing top-level of mood-tables entry=0x3da4004
OTTSEL_IOS: fault sp=0x7007ffffa0
OTTSEL_IOS: regs x0=0x23e57d0 x1=0x23e5790 x2=0x7ffff00 x3=0x70005a9234
             x4=0xffffffffbe978034 x5=0x70023d8004
OTTSEL_IOS: regs x8=0x7000000000 x9=0x23e5d94 ...
OTTSEL_IOS: fault lr=0x7000000000 x21(st)=0x18fe04 x22(offset)=0x7000000000
             x16=0x70023e57e0
OTTSEL_IOS: trace-count=30422
OTTSEL_IOS BOOT FAILED (gated): signal 10 at pc=0x7000000000 fault addr=0x7000000000
```

Signal 10 at pc=0x7000000000 = jump/return to the EE base page (x8 = x22 =
0x7000000000, lr = x22) -- the exact S2.1 signature, now with a trace.

## Call chain (last recorded calls, site=shim address, target=GOAL fn ptr)

```
mood-tables top-level (0x3da4000) sites 0x3da9e0/0x3daa08/0x3dac8c ... call
  0x690554 / 0x690174 / 0x693e54 / 0x23da924  (light-kit build loop)
site 0x3daaf40 -> 0x01768004 ; site 0x0176808c -> 0x4f00afc  (nested)
site 0x3dab68c -> 0x023d8554   (mood main helper)
site 0x023d8620 -> 0x023d8004  (mood main)
site 0x023d80b4 -> 0x005ab0e4  (matrix object fn)
site 0x005ab174 -> 0x005fc574  (matrix helper)
site 0x005ab26c -> 0x005fd9d4
site 0x005fda64 -> 0x005fc574
site 0x023d8304 -> 0x005a9234  (SIMD matrix transform, matrix+0x1234)
site 0x023d8408 -> 0x005a9234  (LOOP: same site, second call)
site 0x023d8408 -> 0x005a9234  (third call) -> then jump to EE base
```

First bad transition: the third call through mood main site 0x023d8408 (the
loop body in the function whose prologue is at matrix... no -- mood main
0x23d8004); afterwards x8/x30 = 0x7000000000 and the CPU faults on the EE
base page.  The last-target code dump at 0x5a9234 shows a real SIMD matrix
transform (ldr q post-index loads + dup/fmul chain + ret) -- the function is
valid code, so the corruption is in the call/return state around it, not a
garbage pointer target.  Full log: `a1-mood-tables-bounded-trace.log`.

## Next

With the trace infrastructure in place, S2.1 can reapply the probe and root-
cause the ret-to-x22 inside the 0x23d8004 loop / 0x5a9234 call path after
the signed-native A1 gates pass.  Per the gate order, A1.1 (real GOAL code
in signed Mach-O __TEXT) comes first.
