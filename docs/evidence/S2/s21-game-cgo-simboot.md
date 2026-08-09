# S2.1 evidence — GAME.CGO links on the Simulator; first runtime fault located

Date: 2026-08-09. Status: **in progress** — the game engine now links on
the iPad Pro 11-inch (M4) Simulator (36 of 346 objects) before the first
runtime fault; the fault site and mechanism are identified with debug
instrumentation retained in the shell's gated handler.

## What was done

1. The iOS shell now bundles `GAME.CGO` and links it after the kernel
   (`ottsel_ios_link_cgo_from_bundle("GAME.CGO")` in `src/shell/ios_boot.cpp`,
   same no-emit `link_and_exec` path as the kernel).
2. First attempt hit a **cross-segment LDR-literal overflow** at object 2
   (math): `diff=-37,356,532` on an `0x1c000000` (LDR-S literal) — the
   top-level segment's float static load could not reach a static 37 MB
   away with the ±1 MB imm19. Fixed by converting the 32/64-bit and float
   pc-relative static loads (`load64/32s/32u_pcRel_s32`, `static_load_f32`)
   from LDR-literal to the ADRP + LDR-[X16,#imm12] pattern (±4 GB reach),
   matching the 8/16-bit variants and `loadvf_rip_plus_s32`; the runtime
   linker already patches ADRP+ADD-style pairs in
   `cross_seg_dist_link_v3`.
3. GAME.CGO revalidates after the change:

       PASS: all 3825664 code words across 346 objects validate
       (decode + round-trip); 6107 type-tag words skipped

4. On-device link now reaches object 36 (`pad`), then a gated SIGBUS:

       OTTSEL_IOS: linking object 36 (pad) size 56144
       OTTSEL_IOS BOOT FAILED (gated): signal 10 at pc=0x70001bfec4
       OTTSEL_IOS: fault lr=0x70006b4294 x21(st)=0x18fe04 x22(offset)=0x7000000000 x16=0x70006bc244
       OTTSEL_IOS: faulting words: 0x0018fe14 0x001c01f4 0x00100004 0x00090000

## Fault analysis (evidence-backed)

`lr = pad main + 0x294`; the disassembly of pad's main code at that site:

       adrp x2, slot; add x2, x2, #0x4c     ; address of a symbol slot
       ldrsw x2, [x16]                       ; (sym - s7) offset
       add x2, x2, x21                       ; + st -> symbol address
       add x2, x2, x22                       ; + EE base -> host address
       ldr w2, [x16]                         ; symbol's value (32-bit)
       add x16, x2, x22, sxtx                ; value + EE base
       ldur w3, [x16, #0x10]                 ; value field at +0x10
       add x3, x3, x22
       blr x3                                ; <- SIGBUS: x3 = st + 0x20c0

The call target `st + 0x20c0 = 0x70001bfec4` is inside the GOAL heap (data),
not code — the symbol's value field (+0x10) holds a heap pointer rather than
a function. This is the first runtime symbol-value call the game code
exercises that the kernel never hit; the suspected mechanism is the same
order-dependent symbol interning class as the S1 fix (the C-side symbol the
GOAL code resolves may not be the canonical entry), or a GOAL global whose
value field is a data object while the call expects a function.

## State kept for the next iteration

- The gated handler now logs pc/lr/st/offset/x16 and the faulting words
  (`src/shell/ios_boot.cpp`) — kept for the next boot fault.
- `scripts/build-ios.sh` bundles `GAME.CGO` into the app.
- `docs/evidence/S2/s21-game-cgo-simboot.md` (this file) + the boot log
  `s21-simboot.log` (captured console tail).

## Next steps

- Identify the symbol at `st + 0x20c0` (dump the interned symbol table or
  the call's argument register at fault) and fix the value-field resolution
  (fallback scan / canonical-intern, mirroring the S1 fix).
- Continue linking the remaining 310 objects; then the game process tree and
  the Metal renderer module.
