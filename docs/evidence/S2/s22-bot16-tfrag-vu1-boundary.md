# S2.2 BOT16b: the composed-frame boundary -- tfrag/sprite content goes through VU1

Date: 2026-08-15.  Status: analysis (the composed title frame blocker is now
precisely identified; the direct bucket alone cannot produce it).

## What the live chains contain (verified, one boot, zero faults)

The title screen's per-frame chains (decoded live with the renderer-core
decoder) contain:

1. The direct bucket: register setup (ALPHA_1=0x44, ZBUF_1=0x10001c0,
   TEST_1=0x5000e, PABE=0, CLAMP_1=5, TEX1_1=0x60, TEXA=0x80000000,
   TEXCLUT=4, FOGCOL=0xc88029) and REGLIST draw packets whose prim is
   `0x4c` (TRI_STRIP, tme=1, abe=1) with all four vertices at
   x = 0x7000/0x9000 and y = 0x7910 (constant).  Rasterizing these with every
   plausible packing interpretation yields zero-area prims (draws=0 in the
   new rasterizer) -- the direct bucket carries no visible geometry at the
   title.
2. The 3D buckets: VIF `UNPACK_V4_32` payloads (e.g. 10-qword per-batch
   constants, a 139-qword vertex batch containing world-space floats like
   -1792.0, a 41-qword batch of 16-bit frag/uv values, and 0x80000000/
   0x7fc00000 (NaN) terminators), plus the tfrag init: `tfrag-init-buffer`
   uploads the `tfrag-vu1-block` microprogram, `add-tfrag-mtx-0/1` (two
   4-qword camera matrices, UNPACK_V4_32) and `add-tfrag-data` (14-qword
   setup), then `MSCAL`/`MSCALF` run the microprogram.

## Why the direct bucket can't produce the title frame (root cause)

The title scene (title-vis: tfrag page 416 + pris 415 + alpha 397 + water
1499) and its 2D sprites are processed by the game's VU1 microprograms
(`tfrag-vu1-block`, `sprite-vu1-block`; `sprite.gc` `sprite-draw` builds the
sprite bucket around `dma-buffer-add-vu-function` + `MSCALF`).  The VU1
microprograms generate the GIF draw packets on the real PS2.  The Ottsel
runtime does not emulate VU1, so the frag -> quad expansion never produces
drawable geometry; the only direct-bucket GIF data is the register setup and
degenerate quad packets.  This is a renderer gap, not a boot fault.

## The reference reimplementation (what the next phase ports)

- The tfrag VU1 microcode (jak1) is in this checkout:
  `test/decompiler/vu_reference/tfrag.txt` (raw words, 1866 qwords) and
  `tfrag-result.txt` (disassembled with labels).
- The DMA builder is already emulated in the runtime:
  `game/mips2c/jak1_functions/tfrag.cpp` (`draw-inline-array-tfrag`).
- The GOAL init code: `goal_src/jak1/engine/gfx/tfrag/` (the decompiled
  jak1 tfrag.gc shows `tfrag-data-setup`, `add-tfrag-mtx-0/1`, `add-tfrag-data`
  layouts: 14-qword UNPACK_V4_32 = the tfrag-data struct; 4-qword = camera
  matrix).
- The modern jak-project never renders raw-ISO tfrag via VIF (tfrag3 uses
  FR3-preloaded trees), so the VU1 decode must be written from the microcode.

## The rasterizer foundation (committed with this evidence)

`src/shell/metal_gfx.mm` now includes an `OttselRaster` (512x448 RGBA
framebuffer, GS->screen transform per the reference DirectRenderer shaders,
barycentric triangle rasterization, texture sampling from fake VRAM via the
TEX0 state, alpha blend + scissor + xy offset) wired into the GIF decoder.
It runs with zero faults; the title's direct prims are zero-area so the
composed present is gated on draw_count>0 (the verified texture frame
presentation stays visible).  The VU1 emulation (tfrag/sprite) is the next
renderer milestone.
