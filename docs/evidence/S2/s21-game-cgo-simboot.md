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
  (`src/shell/ios_boot.cpp`) plus GPR dumps, the linked instructions at
  the call site, and named objects at the key pointers — kept for the next
  boot fault.
- `scripts/build-ios.sh` bundles `GAME.CGO` into the app.
- `docs/evidence/S2/s21-game-cgo-simboot.md` (this file) + the boot log
  `s21-simboot.log` (captured console tail).

## Next steps

- Identify the symbol at `st + 0x20c0` (dump the interned symbol table or
  the call's argument register at fault) and fix the value-field resolution.
  Refined diagnosis (2026-08-09): the dispatch slot (pad main data +0x404c)
  is **0 at fault** even though the runtime linker DID write `(sym - s7) =
  0x38` into it (confirmed by a post-write re-read: `symlink 'object' wrote
  0x38 at data+0x404c (data=0x6b4000)`). The fault-time dump shows the
  neighbors 0x4040..0x4048 holding runtime-initialized values (1, 0, 0)
  while the sibling `object` slot at 0x4058 is intact (0x38) — so a static
  structure whose data spans 0x4040..0x404c is initialized by the GOAL
  top-level between linking and the dispatch, clobbering the slot. This
  points at a **goalc static-data layout overlap** (the symbol slot at
  0x404c overlaps another static object's space), not the runtime linker.
  Next: inspect pad's static allocation order in the goalc
  (`add_static_to_seg` / finalize layout) to find the overlapping static;
  then fix the layout so symbol slots never share space with initialized
  static objects.
- Continue linking the remaining 310 objects; then the game process tree and
  the Metal renderer module.

## 2026-08-09 update — static_load_f32 STR/Q bug fixed; linking 36 -> 48

Root cause of the pad fault fully resolved: **`static_load_f32` used the STR
base (`0b0011110110` = `str q0`) instead of the LDR base (`0b1011110101` =
`ldr s0`)**, so every `(set! (-> obj float-field) <static-float>)` compiled
to a 16-byte `str q0` **into** the static-data symbol slots instead of a
4-byte load. In `cpad-invalid!` the second such store hit slot offsets
0x4040..0x404c, zeroing the `object` symbol slot the `(object-new ...)`
dispatch in `(method new cpad-info)` reads — the exact clobber observed.
The bug was introduced in the S2.1 ADRP-conversion of `static_load_f32`
(copied the STR base from `static_store_f32`).

- Fix: `goalc/emitter/IGenARM64.cpp` `static_load_f32` -> `Base(0b1011110101,
  10)` (verified against `as`: `ldr s0, [x16]` = `0xbd400200`).
- On-device result: linking now passes objects 36 (pad) .. 48 (display)
  before the next fault. New fault: `signal 11` at `pc=0x700075ca10`
  (display object main + 0xa10), fault addr `0x76d664` (a raw EE-relative
  pointer dereferenced without the host base) inside a structure-copy
  sequence (`ldr q0, [x19], #0x7c` post-index). The display function's
  address model needs the goalc IR to diagnose; next iteration.
- The gated handler is now fault-proof (safe `mincore`-probed reads) so it
  no longer re-crashes while dumping.
- Revalidated: GAME.CGO 3,825,664 words PASS; KERNEL.CGO 86,016 words PASS.

## 2026-08-09 update — linking 55 -> 204 (six fixes); mood-tables fault

### Verified fixes this session (each advanced the on-device link)

1. **Stack-variable addressing (object 35 fault):** `IR_GetStackAddr`'s
   offset==0 ARM64 branch emitted `mov_gpr64_gpr64(dst, SP)` = `orr xd,xzr,xzr`
   (register 31 is xzr in ORR), so `(new 'stack-no-clear 'scf-time)` computed
   EE address 0 and `DecodeTime`'s NUL-write hit the EE base.  Disassembly of
   GAME.CGO's scf-time-to-int64 (`mov x0, xzr; sub x0, x0, x22`) confirmed it;
   fixed by using the ADD-immediate form (accepts SP) for all offsets.
2. **mips2c:** replaced the empty OTTSEL_IOS table with the full jak1 table +
   link callbacks, pre-registered into the executable stub arena before the RX
   flip, an ARM64 `_mips2c_call_arm64` ExecutionContext handler (replacing the
   broken upstream port: it read wrong stack offsets and `blr x8` before
   setting x8), and the `_call_goal8_asm_arm64` jalr declaration.  The 25
   `jak1_functions/*.cpp` build into the app.
3. **iOS SIF RPC:** `sceSifCallRpc` asserted mode==1 but the sound loader calls
   sync mode 0, and deref'd a null IOP; made CallRpc/CheckStatRpc/BindRpc inert
   on iOS and emulate the get-irx-version reply (2.0) so check-irx-version
   passes (was crash!-ing deliberately).
4. **`_stack_call_arm64` arg order:** the stack-arg array came out
   [x1,x0,x3,x2,...]; `(format 0 ...)` passed dest=0 as the string -> NULL.
5. **`load16u_..._plus_s8` LDRH scaling:** imm12 is scaled by 2; the raw offset
   made `(-> type size)` read +0x10 and `(-> type heap-base)` read +0x18.  The
   inline-array-class `new` computed 0x3f9334 (~4MB) for a 4096x16 array ->
   kmalloc !alloc -> NULL perm-list.  Fixed to unscaled LDURH.
6. **CGO stage:** full-22MB staging from the global-heap top left ~3MB free at
   object 195; replaced with a reusable 512KB slot.

### Current fault (object 204, mood-tables) — evidence

- `signal 10 at pc=0x7000000000 fault addr=0x7000000000` (jump to the EE base
  page; the page is RW so execution faults).  `lr = 0x7000000000` = x22.
- GOAL-stack walk (gated handler): stack[0] = 0x3dafa48 = mood-tables top-level
  +0x3a48 (the return address), so the faulting function was called at
  top-level +0x3a44 -> the symbol slot there resolves `make-village1-light-kit`
  (0x2924314).
- All symbols/slots in the chain verified valid at fault time: make-light-kit
  (0x2924004, slots 0xa4b0..), matrix-rotate-y! (0x5ea4e4), sin/cos
  (0x6383f4/0x639554), vector+float*! (0x6d8554), vector*! (0x6d8174),
  vector4-lerp! (0x6dad14), update-mood-shadow-direction (0x29258f4),
  update-mood-erase-color (0x2925ae4).
- Conclusion: a deep `ret`/`br` to x22 inside the make-village1-light-kit call
  chain whose exact site is not yet identified.  lldb cannot set software
  breakpoints on the RX-flipped GOAL pages (error 9), so the next step is a
  live call/return tracer in the runtime or a debugger with hardware
  breakpoint support.  The gated handler now prints the faulting pc/regs and a
  GOAL-stack LR walk via raw stderr (robust even when the fault lands inside a
  log call).
