# A1.1 — real KERNEL.CGO dispatcher slice in signed Mach-O __TEXT (PASS, 2026-08-09)

## What passed

Real Jak 1 kernel GOAL functions (`string=`, `name=`, `ref`, `last`,
`nmember` — verbatim bodies from goal_src/jak1/kernel/gstring.gc +
gcommon.gc) execute from the OttselShell app's signed Mach-O `__TEXT` on the
iPad Pro 11-inch (M4) Simulator (UDID 08636791-2675-4675-8335-EF72EF954DCF).
`codesign -v` passes.  Log: `a11-simulator-slice-pass.log`.

```
[A1.1] code=0x1022e53d8 data=0x1025f1d3c st=0x25f1d46 off=0x100000000
[A1.1] ok   string=(jak jak) == #t
[A1.1] ok   string=(jak daxter) == #f
[A1.1] ok   name=(jak jak) == #t (type dispatch -> string=)
[A1.1] ok   ref(list,0) == sc
[A1.1] ok   ref(list,1) == sa
[A1.1] ok   last(list) == pairB
[A1.1] ok   nmember(sa, list) == pairB (dispatch -> name=)
[A1.1] SIMULATOR SLICE PASS (signed __TEXT)
```

## Slice contents (all required elements)

- **Multiple functions:** string=, name=, ref, last, nmember.
- **GOAL ABI calls:** name= dispatches to string=; nmember calls name=.
- **Static references:** #f/#t/'() (the fixed symbol objects), the `string`
  and `symbol` type objects.
- **Function references:** the `name=`/`string=` symbol values (function
  pointers) resolved through writable slots; `symbol->string` extern slot.
- **Writable runtime data:** string bytes and pair lists allocated in the
  slice's own writable `__DATA`; the function/type-pointer tables.
- Symbol: `_ottsel_a11_slice_code` (__TEXT), `_ottsel_a11_slice_data`
  (__DATA).

## How it works (offline-linked, slide-safe)

- Tools: `out/jak-project/tools/ottsel_a1_1/a11_slice_emitter.cpp`
  (target `ottsel-a11-slice`) compiles the real kernel functions, generates
  the object with link tables, and applies them OFFLINE against a fixed
  image layout: code at 0, data at 0x4000.
- The emitted ADRP/ADD pairs that reference data are written symbolically
  (`adrp xN, label@PAGE` / `add xN, xN, label@PAGEOFF`) so the Mach-O
  linker resolves the real (section-gap- and slide-safe) distances; no
  runtime instruction writes.
- Address model: offset (x22) = 0x100000000 so u32 GOAL pointers =
  host - 0x100000000; st (x21) = data base + 0xa - off (GOAL-relative), so
  slot + st + off = target host address.  Symbol/type slots hold
  (target_image_off - ST_OFF - OFFSET_BASE); function/type-pointer VALUES
  are filled at runtime into the writable data (allowed by A1.2).
- The proven game bridge `_call_goal_asm_arm64` (asm_funcs_arm64.s) enters
  each GOAL function.

## Host proof

The same slice executes on the host (`a11_host_runner.cpp`, all 7 checks
PASS) — an independent validation of the offline linking + ABI model.

## Gotchas fixed along the way (documented for A1.2/S2.1)

- Test objects must live in the slice's __DATA (Simulator malloc at
  0x600000000000+ overflows the u32 GOAL-pointer model).
- ADRP+ADD must emit @PAGEOFF: the Mach-O __DATA base is not page-aligned,
  so the image-layout lo12 is wrong at runtime.
- st is the GOAL-relative base (data + 0xa - off), not a host address.
