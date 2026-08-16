# S2.2 BOT19: village-load fault chain fixed -- stable full-vis boot, no faults

Date: 2026-08-15.  Status: S2.2 PROGRESS (two falsifiable fixes verified against
the running app; the renderer still needs the tfrag XGKICK -> VU1 -> raster
path for the first composed geometry frame).

## Fix 1 (build data regression): the recompiled TIT.DGO was overwritten

Root cause (app-side probes + offline object-header ground truth):

1. The BOT18 full-data commit (`e97d42d`, "bundle the full DGO/CGO game data")
   copied the retail iso_data DGOs AFTER the recompiled TIT.DGO, so the bundle
   shipped the RETAIL TIT.DGO (md5 9030e442...) instead of the recompiled one
   (md5 3e47f065...).  The retail GOAL code objects (title-obs, static-screen)
   use the PS2 v3 link-block format (first word 0x0), which the no-emit
   runtime cannot link; the DGO RPC skip test (`tag == 0xffffffff ||
   tag == 0x4c414f47`) classified them "non-GOAL" and skipped them.
2. `title-obs.gc` defines the `target-title` state; with the object skipped,
   the `target-title` symbol value stayed 0 (verified: symbol slot 0x19c8b4,
   value 0x0, while `enter-state` = 0x3eec2d4).
3. `(go target-title)` (target-death.gc:148, in target-continue's :code) ran
   the go-hook: `(set! pp->next-state target-title)` stored 0, then
   `enter-state` (gstate, 0x3eec2d4) read next-state=0, new-state=0,
   `(-> new-state enter)` = *(EE+0x18) = 0 != #f, and `blr` to EE+0 faulted
   (signal 10, pc=0x7000000000, fault addr=0x7000000000).

Fix: `scripts/build-ios.sh` -- the retail DGO copy loop now SKIPS TIT.DGO and
the recompiled `out/jak1/iso/TIT.DGO` is copied LAST.  Verified: the bundle's
TIT.DGO md5 = 3e47f065 (recompiled); the boot then passed the title into the
village load.  This is the same fix as the S2.1 BOT13 milestone, re-applied
after the BOT18 data-bundling regression.

## Fix 2 (goalc ARM64 emitter): mov_vf_vf OR-ed every 128-bit copy with V0

With the village VIS load flowing, a second fault appeared at
entity-nav-login: `(new 'loading-level 'engine 'nav-engine
(res-lump-value arg0 'nav-max-users int :default 32))`:

1. `res-lump-value` expands to res-lump `get-property-value(lump, name, mode,
   time, default uint128, tag-addr, buf)`; the uint128 default (32) is passed
   in the XMM arg register V1 per the ARM64 ABI (XMM args start at V1, return
   in V0).
2. get-property-value's compiled prologue copies the default with
   `orr.16b v8, v1, v0` -- the emitter's `mov_vf_vf` encodes the ARM64 MOV
   idiom `ORR Vd.16B, Vn.16B, Vn.16B` but set Rn only and left Rm=0, so every
   128-bit register copy became `ORR Vd, Vn, V0` (OR-ed with the stale return
   register V0).
3. The default (low half 32) was OR-ed with V0 (a res-tag pointer,
   0x001920b4); the returned value's low half = 0x001920b4.  entity-nav-login
   read it via `fmov x3, d0` as the engine-new `length`; the engine-new size
   `type_size + ((length-1) << 5)` exploded, `object-new` returned 0, and the
   engine-new method faulted writing the engine fields at EE+6 (signal 10,
   pc=0x3ffc724, fault addr=0x7000000006, fault-time length register
   x19=0xce6e6b28001920b4).

Fix: `goalc/emitter/IGenARM64.cpp` `mov_vf_vf` now sets Rm = src (the MOV
idiom ORR Vd, Vn, Vn).  Regression added in
`tools/ottsel_a1/semantic_regressions.cpp` (case 23): fails before the fix
(word 0x4ea01c28, rm=0 rn=1) and passes after (rm==rn).

After the fix, KERNEL.CGO/GAME.CGO/TIT.DGO were recompiled with the fixed
goalc (full `out/jak1/obj` cache rebuild; verified 159 ORR-mov words in
GAME.CGO now Rm==Rn; the one remaining Rm!=Rn ORR in collide-mesh is a real
vector OR, not a copy).

## Verified (one boot, one Simulator, Windowed)

- `ottsel-fault.log` = 0 bytes; app alive 4+ minutes at ~53% CPU (dispatch +
  render loops active; timestamps advance 51:34 -> 55:20+).
- Boot sequence: GAME.CGO fully linked -> `GAMEPLAY: enter title` -> `Adding
  level village1` -> vi1.DGO served (all 55 objects, incl. `village1-vis`
  7,479,408 bytes, result=DONE) -> `link finish: village1-vis` -> continuous
  DMA/render activity.
- 6 texture frames presented through Metal ("presented game frame ...").
- ~1200 GIF PRIM packets decoded (TRI_STRIP chains 149-151+) but with
  degenerate/raw vertices (0x70000000/0x90000000 pattern) -- the tfrag
  XGKICK output still needs the VU1 transform; the rasterizer's draw_count
  stays 0 and the Simulator window is black (screenshot
  `s22-bot19-frame1.png`).

## Next step (S2.2 gate: first composed frame)

Wire the tfrag XGKICK output through the VU1 interpreter
(`tools/ottsel_vu1`, validated to the output-phase divide loop with crafted
data) into `OttselRaster` in `src/shell/metal_gfx.mm` so the transformed
strips produce real primitives (draw_count > 0 -> `ottsel_metal_present`).
The app keeps writing `tfrag-vu-data.bin` (2.3MB captured from this boot) for
offline XGKICK analysis.

## BOT19c update (same day) — real dump analysis (absolute dests confirmed)

The VU1 tool's dump loader used `0x2a0 + (imm & 0x3ff)` for the per-draw
records; the BOT18c VIF semantics (dest = (imm & 0x8000 ? TOPS : 0) +
(imm & 0x3ff), all observed imms bit15=0 -> ABSOLUTE) are now applied in the
tool.  The real captured layout (8334 records: 4000 DIRECT captures + 3998
UNPACK_V4_32 + 336 MSCAL imm=0):

- 0x381: the per-draw 10-qword constant block (starts `7f7fffff c1cb7538
  c37e7538 ffff0018 ...`), 2769 records.
- 0x384: the frag batch (614 records, `ff000000 ...`).
- 0x3d4: the page batch (307 records, 41 qwords, `0000def0 ffffd818 ...`).
- 0x160: the vertex batch (308 records, 139 qwords).
- 0x2a0..0x2a8 (the microcode's frag-list block: vi14 hardcoded = 0x2a0,
  count/pointers at +1/+2/+4, camera matrix rows at +5..+8) is NOT written
  by any captured UNPACK -- the tfrag-data init upload (0x290, once per
  frame) that carries it falls outside the capture window.  The next app-side
  probe must capture the frame's INITIAL records (the 0x290 tfrag-data
  upload) so the interpreter can run the real frag list end-to-end.

The XGKICK output produced by the interpreter (gif_out) then feeds the
existing OttselRaster; the degenerate PRIM packets currently decoded
(vertices 0x70000000/0x90000000) come from the raw DIRECT/GIF data and are
not the VU1-transformed strips.

## BOT19d update (same day) — fresh frame capture; frag-list source still open

The dump probe now captures EVERY UNPACK from the frame start (window
0..12000; the once-per-frame 0x290 tfrag-data init is inside: 1 record,
224 bytes = 14 qwords, 0x290..0x29e).  Verified dests (V4-32): 5, 0x14d,
0x290, 0x160, 0x381, 0x384, 0x3d4 -- plus 75 small DIRECT-capture markers
(imm = 0x80000000 | kind; kind 0x00/0x08/0x50 = the uninitialized DMA gaps).

The frag-list block at the microcode's draw base is still NOT written by any
captured UNPACK.  The VIF code stream per chain is `MSCAL imm=0` +
`UNPACK_V4_16 n=10` (the 160-byte per-draw constant block) with an ITOP
(imm=0) command; the VIF TOP register state that fixes the frag-list base is
the missing piece.  Next: emulate the VIF registers (TOP/TOPS/STCYCL/ITOP)
in the tool while replaying the capture so the frag-list address resolves,
then run the microcode to XGKICK and rasterize.

## BOT19e update (same day) — VU1 interpreter wired into the app; frag-list empty

Architecture (committed): `tools/ottsel_vu1/vu1.cpp` is now compiled into the
shell; `src/shell/tfrag_microcode.h` embeds the 1867 tfrag microcode words
(generated from `test/decompiler/vu_reference/tfrag.txt`); `gfx_send_chain`
processes every transfer's VIF commands live (STCYCL/BASE/OFFSET tracked,
UNPACK -> VU data memory at (addr?TOPS:TOP)+(imm&0x3ff), MSCAL/MSCALF ->
`execute()` with XTOP = the VIF TOP, XGKICK gif_out fed through the existing
GIF decoder/rasterizer).

Live run (one boot, zero faults): the interpreter executes on every MSCAL
(imm=0, TOP=0, e.g. pc exits at 1414/141/1506/313/1706) but gif_out = 0 every
time: the microcode's L26 reads the frag count from data[TOP+0].hi16 and the
`ibeq vi00, vi02, L32` skips the draw when it is 0.  The frag-list block
(count@TOP+0, vertex offset@TOP+1, pointers@TOP+2..4, matrix@TOP+5..8) is
EMPTY at runtime -- no captured UNPACK writes data mem 0..4, and the
`*tfrag-work*` symbol's value is 0 (the runtime's tfrag-work object is not
set up, `OTTSEL TFRAGWORK: ... value=0x0`).  So the port's tfrag draw path
never produces a frag list, and the VU1 correctly skips every draw.

The remaining S2.2 work is the tfrag-work / draw-inline-array-tfrag frag-list
construction (the game's CPU-side draw state), then the XGKICK output will
flow into the rasterizer that is already wired.

## BOT19f update (same day) — tfrag geometry audit: LOD vertices empty, pages real

Live symbol-table ground truth (the earlier TFRAGWORK probe read the WRONG
field): `*tfrag-work*` IS valid -- the symbol's value field is at slot+0
(0x042cc000), not slot+4.  The tfrag-work object's draw-state fields,
however, are all zero: src-ptr(+0xb0)=0, last-call(+0xb4)=0,
dma-buffer(+0xb8)=0, cur/end-vis-bits(+0xa8/+0xac)=0.  `*vu1-enable-user*`
= 0x1bfff8 (nonzero) and `*fake-scratchpad-data*` = 0x1d0000.

Per-draw DMA ground truth (the full VIF replay): the game uploads the
per-draw batches every draw -- 0x381 const (10 qwords, real fog/ambient
values), 0x160 vertex batch (139 qwords), 0x3d4 page batch (41 qwords),
0x384 frag batch (5 + 80 qwords), plus the frame init (mtx-0/mtx-1 at
imm 5/0x14d, tfrag-data at 0x290, BASE+OFFSET 0x190).  BUT:

- The vertex batch (0x160) is EMPTY geometry: 139 qwords, only 13 non-empty
  (the level-1 offset table 0x160/0x166/0x16e/0x178), the rest are the
  `(0,0,0,-1792)` empty-tfrag marker from S2.1.  The far-LOD (L3) strip
  transform has no vertices.
- The PAGE batch (0x3d4) HAS the real near geometry: 23 non-zero qwords of
  16-bit values (0xdef0, 0xd818, 0x78a8, 0x3490, sign-extended) -- the
  village mesh.
- The FRAG batch (0x384) HAS the real frag positions (q5-14: 0x4baa84c8
  world coords) and the frag/page header words.

So the composed-frame path needs (a) the frag-list header (VU data words
0-4: count, vertex offset, page/frag pointers) -- which the game's port
draw path never writes -- and (b) either populated far-LOD vertices or the
near (L6/L7) path over the real page data.  Both are game-side draw-state
issues (draw-inline-array-tfrag / tfrag-work); the VIF emulation, the VU1
interpreter, the XGKICK capture and the rasterizer are all wired and
validated.  Next: decode the game's frag-list/page construction from
draw-inline-array-tfrag (the mips2c tfrag.cpp path) and feed the real
count/pointers into the live VU1.

## BOT19g update (same day) — draw-inline-array-tfrag (mips2c) never runs

The `draw-inline-array-tfrag` symbol resolves to the mips2c stub arena
(0x4f10994: pushes {ctx-ptr, index 0x200} and branches to the mips2c bridge,
whose table[0x200] = `draw_inline_array_tfrag::execute`).  A probe added to
that execute() (lg::info "OTTSEL TFASM") NEVER fires across a 3-minute stable
boot while the tfrag DMA chains flow (MSCAL runs, per-draw UNPACKs at
0x160/0x381/0x3d4/0x384 every frame).  So the game's compiled
draw-drawable-tree-tfrag does NOT call the mips2c draw-inline-array-tfrag;
the per-draw UNPACKs come from the compiled code path, which never writes the
frag-list header (VU words 0-4) and leaves the far-LOD vertex batch (0x160)
empty.  The real village mesh lives in the page batch (0x3d4, 16-bit), which
only the near (L6/L7) microcode path consumes.

Implication for the frame: the S2.2 gate needs either (a) the far-LOD vertex
data populated (the level/tfrag login path), or (b) the near path triggered
with a valid frag-list (count + page pointers).  The app-side VIF/VU1/raster
emulation is complete and validated; the remaining work is on the game's
draw-state side.
