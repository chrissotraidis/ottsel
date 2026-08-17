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

## Root cause #4 — u8/u16 field loads double-apply the offset (cycles 15-20)

With trig fixed, boot got past the old wall and died at EE 0x45182e0 —
`vector<-cspace!` reading a bone pointer that was a matrix float.  The
caller (do-joint-math!'s origin-joint-index path in process-drawable)
disassembles to:

    add  x16, x16, #0xb6      ; draw + 0xB6
    ldrb w1, [x16, #0xb6]     ; offset applied AGAIN -> reads draw+0x16C

`IGenARM64 load8u_gpr64_gpr64_plus_gpr64_plus_s32` (and the load16u twin)
fold the offset into X16 via the add/sub helper AND encode it again in the
final LDRB/LDRH imm12 — every unsigned byte/halfword field load with
offset > 127 read base+2*offset.  origin-joint-index came back as garbage
(45), the cspace index walked past the 50-entry node-list into the bones
matrix array, and the "bone" was the float 0.92.  (The crash-time dump of
all 50 real cspaces was healthy — the giveaway that the INDEX, not the
data, was wrong.)

Fix: final LDRB/LDRH imm12 = 0 in both emitters; A1.0 regression 26 pins
it.  The s8 variants and every other width were audited clean (only these
two clones double-encoded).

## Root cause #5 — rbp mapped to X29 leaves X26 unsaved across suspend (cycles 20-26)

With #1-#4 in AND the level DGOs regenerated, the flow reached the title
intro spool and SIGILL'd calling #f (pc = s7) from ja-play-spooled-anim —
its check-func arg (x26) was #f while the caller (title-obs +0x5710,
proven by a GOAL-stack backtrace) verifiably loaded false-func's real
value (slot audit: [s7+0x2e28] = 0x3ebc1f4 ✓).  The value died ACROSS
`(suspend)`: the kernel-asm register map sent `rbp` (GOAL saved-reg s1)
to X29 — the frame pointer, which the ARM64 allocator never allocates —
so thread-suspend/resume saved {X19, X29, X23, X24, X25} while the
allocator's saved set is {X19, X23, X24, X25, X26}.  **X26 was never
saved**: any GOAL local in x26 was clobbered at its first suspend.
Fix: `rbp -> X26` in parse_register (goalc Asm.cpp); A1.0 regression 27
asserts the map covers the saved set exactly.

## RESULT (cycle 26): 5-MINUTE VILLAGE1 SOAK PASS

Boot -> title -> `touch /tmp/ottsel-bg-village1` -> Jak spawns ->
"GAMEPLAY: enter village1" -> **300 s stable soak, zero crashes, zero
collide-list overflows**, camera tracking at real village1 world
coordinates (-657148, 157724, 806641) with live micro-motion; gk still
running after the window.  Log: `m1-village1-soak-2026-08-17.log`.
Visual + physical-keyboard confirmation still needs a human at the
machine (the agent shell lacks Screen Recording permission); the input
PATH is verified separately via the synthetic START injection
(`touch /tmp/ottsel-press-start`).

## Retail flow status (cycles 28-29): VIS + STR STREAMING WORK

An untriggered boot (no /tmp driver) proved the "unwired" premise stale —
it was more codegen collateral:

- `Swapping in vi1 VIS [dumping tit]` + `[OVERLORD RAMDISK] loading file
  vi1.VIS size 617696` — the real overlord RAMDISK VIS path works.
- `LoadISOFileChunkToEE LOLOOP STR : 14336 offset 64/71/78...` — STR spool
  streaming works; the title logo-loop animation PLAYS from streamed data
  (camera flying the attract path, live coords).
- Synthetic input (`touch /tmp/ottsel-press-start`, or hex button0 via
  `echo 4000 > /tmp/ottsel-press-button`) drives the title: START stops
  the logo loop and advances the title state.

NEXT BLOCKER (retail only; the bg-trigger village1 path is unaffected):
after START + X (new game), the **auto-save process spawn jumps to NULL**
(sig=11 pc=0 lr=0; x1='auto-save symbol, proc type 'auto-save'; note
'waiting-to-run' symbol value = 0).  mc-* C exports ARE registered
(kscheme.cpp:2135-2140).  Suspect the auto-save init-function slot or a
state handler is 0 — next session: dump the auto-save type's method/state
table and the process-spawn args at the crash.

## Superseded investigation note (cycles 20-24)

With trig/camera/collide/joint-index all fixed AND the level DGOs
regenerated (`(mi)` — note: GROUP:kernel+GAME.CGO alone leaves TIT/VI1
DGOs stale with old codegen!), the flow now reaches the TITLE INTRO
SPOOL (title-obs.gc ~221, the intro-movie player whose command-list
loads village1).  It crashes calling `#f` as arg3 (the check-func) in
`ja-play-spooled-anim` (loader.o fn24, in-seg +0x66c0 blr; lr 0x431e6d8;
pc = s7).  Callee entry: x19=arg0(spool-anim static, code region)
x25=arg1=#f x23=arg2=#f (matches the title caller's `#f #f false-func`),
x26=arg3=#f — the caller's load of `false-func`'s symbol value produced
#f.  false-func is defined in gcommon (GAME.CGO); its slot offset per
symlink logs is s7+0x2e28 everywhere.  Under investigation: whether the
title-obs (TIT.DGO) call site reads the wrong slot, or false-func's
value is truly #f at that moment.  A GOAL-stack backtrace dump was added
to identify the exact calling frame.

## Instrumentation in the tree (remove before M1 close)

- runtime.cpp: SIGILL hook + genuine-fault crash dump.
- libpad.cpp: ENG / TYPEWATCH / CAMWATCH / cull-test one-shot dumps,
  in-vivo cull test driver.
- collide_cache.cpp (`pc_upload_collide_frag`): overflow log + query/items
  classification dumps.

## Root cause #6 — pext family ported as UZP instead of ZIP (the black screen)

User ground truth: the window showed a black screen with a single
horizontal band despite "GAMEPLAY: enter village1" and healthy telemetry.
Renderer probes proved TFragment was submitting ~6.7M tris/600 calls for
village1 — geometry flowed, pixels didn't.  Dumping the GOAL-built camera
packet in TFragment: the 4x4 was garbage (title: rows 1,2 all-zero and
row3 == row0; village: y-scale 0.0006 -> the image collapses into exactly
the observed band), while hvdf/fog in the same packet were classic sane
values.  Zeroed/duplicated rows are the signature of a broken transpose:
`pextlw/pextuw/pextlh/pextuh/pextlb/pextub` were ported as **UZP1/UZP2
(deinterleave)** but the x86 references are PUNPCKL/H* (**interleave** =
ZIP1/ZIP2) — `matrix-transpose!` and every punpck-based unpack was wrong.
Fixed all six encodings (A1.0 regression 28 pins zip1.4s/zip2.4s).
After the fix the camera matrix is textbook (title diagonal
-0.4/-0.2334/-8184; village view*proj with proper cross terms), 60s+
stable, session left running for visual confirmation.

Honesty note: earlier "playable/visible" claims in this doc were based on
game-logic telemetry plus inherited display claims; the visual gate was
not verified until the user's screenshot forced this investigation.
