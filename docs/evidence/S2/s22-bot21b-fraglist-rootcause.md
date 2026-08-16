# S2.2 BOT21b: frag-list blocker root-caused -- the port's tfrag source
# disables the mips2c `ln` calls

Date: 2026-08-16.  Status: S2.2 PROGRESS (diagnosis complete; the composed
frame now has a precise, falsifiable next step).  The present-path fix that
restored the visible texture is `s22-bot21-present-path-fixed.md`.

## Question

The VU1 interpreter runs on every tfrag MSCAL but `gif_out=0`: the microcode's
frag-count check (`ilwr.z vi02, vi14` + `ibeq vi00, vi02, L32`) skips because
VU data words 0-4 (the frag-list header) are never written.  Which code is
supposed to write them, and why does it never run?

## Ground truth (all verified against the running app / compiled code)

1. **The tfrag microcode's frag-list base is XTOP, not the hardcoded
   `iaddiu vi14, 0x2a0`.**  The microcode entry (pc8, `tfrag-result.txt`) is
   `b L3 | xtop vi14`; L3 is the far path (`bal L12` strip transform, `bal
   L26` frag check, `bal L48`, `b L102`).  L11's `iaddiu vi14, vi00, 0x2a0`
   is a different entry (trans/dirt/ice variants).  With TOP=0 the layout is
   self-consistent:
   - `add-tfrag-mtx-0` (UNPACK imm=0x5) lands the camera matrix at VU 0x5,
     and every transform path reads it from `5(vi14)` .. `8(vi14)`.
   - `add-tfrag-data` (UNPACK imm=0x290) lands the 14-qword tfrag-data at
     VU 0x290, and the microcode reads it from `656(vi00)` (= 0x290)
     absolutely.
   - The frag-list header is VU words 0-4: `data[0].x` = strip vertex count
     (L12), `data[0].z` = frag count (L26), `data[1].z` = vertex list base
     (L12), `data[2].y` / `data[3].z` = frag/page pointers (L26), `data[5..8]`
     = matrix.  None of the captured VIF UNPACKs (0x5, 0x14d, 0x290, 0x160,
     0x381, 0x384, 0x3d4) write words 0-4.
2. **The writer is the mips2c `ln` (draw-inline-array-tfrag), and the
   recompiled game never calls it.**  The retail decompiler reference
   (`test/decompiler/reference/jak1/engine/gfx/tfrag/tfrag-methods_REF.gc`)
   calls `(draw-inline-array-tfrag sv-16 ...)` inside
   `draw-drawable-tree-tfrag` (and `-near`/`-trans`/`-dirt`/`-ice` variants).
   The rewritten `goal_src/jak1/engine/gfx/tfrag/tfrag-methods.gc` has every
   call COMMENTED OUT (lines 93/127/205/231/...), so the recompiled GAME.CGO
   (the one the bundle runs, md5 c7fa4149 = `out/jak1/iso/GAME.CGO`) never
   invokes it.
3. **Compiled-code ground truth:** a live dump of the running
   `draw-drawable-tree-tfrag` (0x42c4244, FNSYM probe + ARM64 disassembly)
   shows its `blr` calls are exactly: tfrag-init-buffer, three perf-stats
   methods, tfrag-end-buffer, dma-bucket-insert-tag.  There is NO call to the
   mips2c `ln` (the TFASM probe inside `draw_inline_array_tfrag::execute`
   stays silent while tfrag DMA flows).  The `ln` symbol value is 0 (the
   def-mips2c stub is registered at table[0x200] but nothing references it).
4. **The per-draw UNPACK batches (0x160 verts / 0x381 const / 0x3d4 pages /
   0x384 frags) are NOT read by the tfrag microcode** -- it never loads from
   those addresses (all loads are 656-669 = 0x290-0x29d and `5..8(vi14)`).
   The captured replay's per-draw groups (`DIRECT-3` + `UNPACK 0x381` +
   `MSCALF`) appear AFTER `tfrag-end-buffer` in the chain, so they belong to
   other VU1 programs (tie/trans) whose microcode the shell does not embed.
   The tfrag tree draw itself is only the frame-init (mtx-0/1 + tfrag-data +
   MSCAL) + end-buffer: with no `ln` call there is no frag-list, so the one
   tfrag MSCAL always takes the `ibeq`-skip path.

## Why this is the blocker (not a VIF/TOP bug)

The earlier BOT19d assumption that TOP=0x2a0 (tool mapping 0x400/0x621/0x674/
0x624) is disproven: TOP=0 is the correct VIF state (`tfrag-init-buffer`
emits `BASE 0` + `OFFSET 0x148` after the init uploads, and the microcode's
absolute tfrag-data read at 0x290 requires it).  The app's VIF emulation is
correct; the game's draw state (frag-list header) is simply never built
because the ported GOAL source dropped the mips2c calls.

## Next step (falsifiable)

Restore the `(draw-inline-array-tfrag ...)` calls in
`goal_src/jak1/engine/gfx/tfrag/tfrag-methods.gc` (all 4+ sites, matching the
retail reference), recompile GAME.CGO, and wire the shell to consume the
mips2c `ln` frag-list output.  The runtime already links
`draw_inline_array_tfrag::execute` (mips2c table[0x200]); the port's
`spad_to_dma` writes the frag data into the fake scratchpad
(`*fake-scratchpad-data*` = EE 0x1d0000), so the shell must either emulate
the SPR->VIF1 stream from the scratchpad or synthesize the VU words 0-4
(count/pointers) from the tfragments at the tfrag MSCAL.  Success = the tfrag
MSCAL produces gif_out (draw_count > 0) and the rasterizer draws the first
composed frame.

## Files

- `goal_src/jak1/engine/gfx/tfrag/tfrag-methods.gc` (commented calls),
  `test/decompiler/reference/jak1/engine/gfx/tfrag/tfrag-methods_REF.gc`
  (retail calls).
- `src/shell/metal_gfx.mm`: FNSYM probe + uniform-skip fix.
- Runtime probes: `OTTSEL FNSYM` (symbol values), `OTTSEL VU1: run`
  (top=0, gif_out=0), replay analysis (tfrag-vif-replay.bin).
