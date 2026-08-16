# S2.2 BOT21d: VU1 microcode entry + ILW/ISW component fixes -- far path now reaches the output phase

Date: 2026-08-16.  Status: S2.2 PROGRESS (two falsifiable VU1-interpreter
fixes verified against the running app; the far path now runs into the
strip-output phase, pc 1687-1707, where it previously skipped).

## Fix 1: the tfrag MSCAL entry is pc=8, not pc=0

The shell ran every tfrag MSCAL from `pc = (imm*2)` = 0.  pc0 is the L11
header path (`iaddiu vi14, vi00, 0x2a0` -- the trans/dirt/ice variants'
hardcoded frag-list base).  The far path's real entry is pc8
(`b L3 | xtop vi14`): vi14 = XTOP = TOP, and the frag-list is at TOP+0..4
with the matrix at TOP+5..8 and tfrag-data at the absolute 0x290.  With the
pc=8 entry the VU1 trace shows the correct reads:
`ILW pc=79 addr=0x1 -> vi5` (vertex base), `LQ pc=98 addr=0x5 -> vf5`
(matrix), `LQ pc=96 addr=0x290 -> vf1` (tfrag-data), `LQI pc=94 addr=0x1a`
(the vertices at VU 26+).  The BOT19e tool already used pc=8; the shell did
not.

## Fix 2: the VU1 ILW/ISW ignored the 16-bit component

The interpreter's ILW/ILWR always read `data[addr].x >> 16` (the .y
component).  The VU ilw selects the component with the dest-mask bits 21-24
(reversed: bit0=w, bit1=z, bit2=y, bit3=x -- verified against the encoded
`ilw.z vi05, 1(vi14)` = 0x08457001 and `ilwr.x vi02, vi14` = 0x810273fe).
With the fix, the frag-list reads resolve correctly (data[0].x = 4 vertex
count, data[1].z = 26 vertex base, data[0].w = 14 strip count).

## Verified (one boot, zero faults)

- run#10 (the first tfrag draw after the SPR upload) exits at pc=1707 (the
  strip-output loop L124) instead of the skip path; run#11 at pc=1419.
- The VU1R trace confirms the far path reads the frag-list (VU 0-4), the
  camera matrix (VU 5-8), the tfrag-data (VU 0x290) and the vertex batch
  (VU 26+) with the correct components.
- gif_out is still 0: the strip-output loop runs to the instruction cap
  (the frags' referenced page/vertex data beyond the 128-qword stored
  stream is not yet uploaded; the far path's loop counters come from that
  data).


## BOT21e update (same day) — tnear/observed-group attribution

The tnear microcode (`test/decompiler/vu_reference/tnear.txt`, 957
instructions) ALSO hardcodes the frag-list base `iaddiu vi14, vi00, 0x2a0`
and reads the tfrag-data at 656-665 (0x290-0x299) — it never reads the
observed per-draw UNPACK destinations (0x160/0x381/0x3d4/0x384).  So the
66 per-draw groups in the DMA chains are neither the far nor the near tfrag
data; they are another renderer (tie-class) whose microcode the shell does
not embed.  Combined with the vis-bit finding (the far tfragment is
legitimately invisible: the level uploads `lev->vis-bits` into the
scratchpad vis-list via `dma-send-to-spr-no-flush`, and the far LOD is
empty), the composed village frame requires the GAME's runtime-built
0x2a0-based tfrag data (the mips2c `ln` VIF assembly the port does not
emulate) AND, for the real mesh, the near path (tnear microcode + the
unimplemented draw-inline-array-tfrag-near).  The direct-bucket prims are
raw placeholder strips (y constant 0x7910), so the rasterizer's
to_screen/restart fixes await real data.


## BOT21f update (same day) — near path unlinked; the observed groups are tie-class

`draw-inline-array-tfrag-near` resolves to sym=0x189d2c val=0 (UNLINKED in
the no-emit runtime), so the near tfrag draw never runs (the goal_src near
draw code is commented out).  The 66 per-draw groups (0x160/0x381/0x3d4/
0x384 + MSCALF) are therefore the TIE renderer's data, which the shell
currently runs with the far tfrag microcode (wrong program -> gif_out=0).
The composed village frame requires: (a) the game's runtime-built 0x2a0
tfrag data (the mips2c ln VIF assembly + the vis-list, which the port does
not emulate), (b) the near tfrag path (tnear microcode exists at
test/decompiler/vu_reference/tnear.txt; the ln-near implementation + the
uncommented near draw code are missing), and (c) the tie microcode for the
tie groups.  The direct bucket is raw placeholder strips.

## Next step

Upload the complete per-draw data the far path references (the frags at
VU 27+ point at page/vertex data at higher VU addresses; the ln's second
SPR TO chunk + the level geometry must land there), then the strip-output
loop terminates and the XGKICK fires.

## Files

- `tools/ottsel_vu1/vu1.cpp|h`: ILW/ISW component fix + readlog hook.
- `src/shell/metal_gfx.mm`: pc=8 MSCAL entry, SPR scaffold (frag-list +
  geometry upload to VU 26+), readlog hook.
