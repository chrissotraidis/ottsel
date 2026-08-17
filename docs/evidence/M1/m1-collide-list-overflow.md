# M1 — BOT30: the "engine-connection crash" is a *collide-list* overflow (camera NaN line-sphere probe) + the add_vf integer-ADD emitter bug (2026-08-17)

## TL;DR (evidence chain, 10 boot cycles)

The village1 post-spawn crash (EE pc=0x3075274, lr=0x41e32bc) is NOT the
engine connection system.  Chain:

1. A **camera line-sphere collide probe with NaN inputs** (collide-box and
   the whole `*collide-work*` inv-mat are NaN, proc=#f — camera los code is
   the only line-sphere caller) runs right after village1 entry.
2. NaN geometry makes every cull comparison false ("never outside") in the
   collide-probe walk, so the probe appends the ENTIRE level:
   **1734 items into the 256-item `*collide-list*`** (412 frag items with
   inst=#f, 1322 instance-tie items — verified real instances with sane
   far-away bspheres; the GOAL cull tests were proven correct in-vivo, so
   only the NaN query explains all-pass).
3. `collide-list` is `{num-items@0, items@16, stride 16}` (all-types
   size-assert 0x1010).  1734*16 bytes of `{mesh,inst}` writes run ~27KB
   past the list end over the global heap, trampling the type objects above
   it — including instance-tie's type (0x153db74) and the drawable-tree
   type 0x153e2d4 whose **method slot 12 (collide-y-probe) at 0x153e314**
   catches an instance pointer (stride-0x40 values = the trampled rows
   BOT29 misread as an "engine connection list").
4. The next `collide-y-probe` on the bsp dispatches tree[0] via that
   trampled slot and calls an instance-tie object as code: EE 0x3075274,
   healed to RX by the exec-healer, then SIGILL.  Registers decoded: the
   crash site is the method dispatch in `(collide-y-probe (bsp-header ...))`
   (`LDUR w3,[type+64]; BLR`), lr=0x41e32bc.

## Fixed this session (real emitter bug, independent of the NaN)

`goalc/emitter/IGenARM64.cpp add_vf` emitted **integer ADD .4S**
(0b0100111010100000100001) instead of **FADD .4S**
(0b0100111000100000110101) — every GOAL-compiled `.add.vf` int-added float
bit patterns (mips2c renderers unaffected, which is why the world drew).
Proven by disassembling the compiled `collide-cache-using-y-probe-test`
(fsub correct, add integer).  Fixed + clean GOAL rebuild (GAME.CGO now has
0 integer ADD .4S / 94 FADD .4S) + **A1.0 semantic regression 24** pins
`fadd.4s v6,v1,v6 = 0x4E26D426`.  The crash persists after this fix — the
NaN probe is the remaining root.

## Verified-correct along the way (do not re-suspect)

- `*background-draw-engine*` connection lists healthy at crash (alive list
  = 1 valid add-bsp-drawable connection; title connection properly dead).
- `collide-cache-using-y-probe-test` (compiled): semantically correct
  end-to-end, including the ppach emulation and the b.ne/#t/#f tail;
  **proven in-vivo** (far sphere culled, inside passes, above culled).
- `collide-cache-using-box-test` (compiled): correct, including the vf0
  static-constant load and the acc chain.
- IR_BlendVF per-lane blends, splat/dup, umov/ins, fcvtzs/scvtf, fmul/
  fdiv/fsqrt/eor encodings.
- Level data layouts (draw-node BVH, instance-tie, collide-frag-mesh) all
  decode correctly; deftype offsets are memory-relative, basic ref = mem+4.

## Root cause #3 — scaled-LDR imm12 in the ADRP static-ref patchers (cycles 10-15)

CAMWATCH showed the camera NaN from the SECOND sample after boot (long
before the title) — a boot-time math fault, not a bg-flow artifact.  The
NaN pattern (nan, 0, nan) = orbit position sin/cos NaN.  In-vivo calls of
the compiled trig: **cos(0) = 0, sin(16384) = 0** — everything returned 0.

Runtime dump of `sin`'s code + lldb attach found the mechanism:

- sin loads its 2pi/65536 constant with `adrp x16, +4pages; ldr s0,
  [x16, #0x540]` — but the constant lives at in-seg 0x4150 (verified in
  the .o header and by lldb memory find at runtime; target 0x...540 reads
  zeros).
- 0x540 = **0x150 written raw into the scaled imm12 field of LDR-S**
  (CPU multiplies by 4).  `ObjectGenerator::patch_arm64_static_ref`'s
  ADRP branch patched the successor word as an ADD (raw lo12), but float/
  vector rip constant loads emit ADRP + LDR whose imm12 is scaled (x4 for
  S, x16 for Q).  The runtime twin in `klink.cpp`'s cross-seg ADRP patch
  had the same cloned bug.
- Every GOAL rip float/vector constant in every object read whatever sat
  lo12*scale bytes past the real static — zeros or garbage.  sin/cos
  returned 0, camera matrices NaN'd at boot, and the NaN camera
  line-sphere probe flooded the collide-list.

Fix: both patchers now decode the successor; LDR/STR unsigned-imm gets
lo12 >> scale (scale from size/opc bits, incl. the 128-bit Q case) with an
alignment assert; ADD keeps raw lo12.  Verified in the rebuilt object:
sin now encodes `ldr s0, [x16, #0x150]`.

## Instrumentation in the tree (remove before M1 close)

- runtime.cpp: SIGILL hook + genuine-fault crash dump.
- libpad.cpp: ENG / TYPEWATCH / CAMWATCH / cull-test one-shot dumps,
  in-vivo cull test driver.
- collide_cache.cpp (`pc_upload_collide_frag`): overflow log + query/items
  classification dumps.
