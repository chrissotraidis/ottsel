# S2.2 BOT18: VU1 interpreter + tfrag pipeline map

Date: 2026-08-15.  Status: renderer core (the composed-frame path is mapped;
the interpreter runs the tfrag microcode; the GIF output phase + exact frag
format are the next integration steps).

## What is verified (one boot, zero faults)

- The runtime's `tfrag-vu1-block` is a PC-port placeholder (the port's
  `dma-buffer-add-vu-function` uploads qlength=0 in PC_PORT), so the REAL
  microcode must come from the in-checkout extraction:
  `test/decompiler/vu_reference/tfrag.txt` (raw words) + `tfrag-result.txt`
  (disassembled).  1867 instructions = `:length #x74b`.
- The VIF UNPACK `imm` field IS the VU data-memory destination (ground truth
  from the live chains): mtx-0 -> qword 5, mtx-1 -> 0x14d (333),
  tfrag-data -> 0x290 (656; the microcode's hardcoded `lq vf01, 656(vi00)`),
  the per-draw constant block -> 0x381 (897), the vertex batch -> 0x160
  (352), the frag/page batches -> 0x3d4 (980) and 0x384 (900).
- The tfrag-data layout (GOAL `tfrag-data-setup`): fog, val, ambient,
  strgif/fangif/adgif GIF tags, hvdf/hmge/invh/guard, dists.  The VU reads
  the GIF packet headers from here.
- The frag layout (from the microcode L25/L27): count at vi14+1, pointers at
  vi14+2/+4, camera matrix rows at vi14+5..+8; vertices are 16-bit ints
  (upper 16 bits of each word), transformed by `mulaw/maddax/madday/maddz`
  (vf08 translation + vf05/06/07 rows).
- The output phase (L80-L127) builds GIF packets in VU memory and emits them
  with `xgkick vi01` (the address assembled from vf03 = frag/vertex bases).

## The VU1 interpreter (tools/ottsel_vu1/)

`vu1.h`/`vu1.cpp`: a minimal PS2 VU1 interpreter (32 VF, 16 VI, ACC/Q/P/I,
4096-qword data mem, 2048-word code mem, XGKICK->GIF output buffer) with the
decode tables mirrored from `decompiler/VuDisasm/VuDisassembler.cpp`.  It
decodes and executes the full tfrag microcode (1867 instructions) without
crashing; `main.cpp` loads tfrag.txt and runs a synthetic frag.  The
microcode loops on synthetic data (no XGKICK reached) until the real entry
(MSCALF -> TOP -> the jump table) and the real frag/page data are wired.

## Next steps (the integration)

1. Wire the VIF UNPACK simulator (imm = dest) + the MSCALF entry (start at
   the code end = the jump table; the table dispatches to L3/L4/... by the
   top/case) into the shell, feeding the live tfrag bucket data into the
   interpreter's VU memory.
2. Capture the XGKICK GIF output; route it through the existing
   OttselRaster (the direct rasterizer already decodes those packets).
3. Verify a visible composed frame (title-vis tfrag page 416) on the
   Simulator, zero faults.

## Files

- `tools/ottsel_vu1/` (interpreter + loader).
- `src/shell/metal_gfx.mm` (VIF/draw probes: VIFSEQ, VIF payloads, VUFUNC).
