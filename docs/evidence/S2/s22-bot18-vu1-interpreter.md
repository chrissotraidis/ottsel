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

## BOT18b update (same day) — entry + addressing findings

- All 3460 tfrag draws run `MSCALF/MSCAL imm=0`: the VU starts at the TOP
  register (the code end), i.e. the jump table, which dispatches to the case
  handlers (L1-L10).  The observed draw path is the L3 case (`bal vi15, L12`
  strip transform, `bal L26` fan, `bal L48` output).
- The dump (`tfrag-vu-data.bin`, written by the shell probe) contains one
  record per UNPACK {imm, num, size}+payload plus MSCALF markers.  The imm
  values are 5/0x14d/0x290 (the once-per-frame init: mtx-0, mtx-1,
  tfrag-data) and 0x160/0x381/0x384/0x3d4 (per-draw: vertex batch, the
  10-qword per-draw block, and two frag/page batches).
- The microcode's vi14 = 0x2a0 = TOP - OFST (the VIF data base); vf03 (from
   mfir vi14/vi01) feeds the XGKICK address, so 0x2a0 is the output area too.
  The exact dest formula for the per-draw unpacks (absolute vs base+imm) is
  the remaining open question; both mappings were tested in the tool.
- Interpreter robustness fixes: VI register indices are 5-bit but only 16
  registers exist (mask & 0xf); VU data addresses must be masked to 0xfff
  (the LQI/SQ family and XGKICK); the dump loader bounds-checks records.
  The interpreter now runs the full microcode on the real dump without
  crashing (pc=127 = instruction cap on the synthetic frag count).

## BOT18c update (same day) — VIF semantics resolved; frag-list question

- The VIF UNPACK dest = (imm & 0x8000 ? TOPS : 0) + (imm & 0x3ff) -- all
  observed imms have bit15=0, so the dests ARE absolute (5, 0x14d, 0x290,
  0x160, 0x381, 0x384, 0x3d4).  A scan of 82k records confirms only those 7
  addresses are ever written.
- MSCAL/MSCALF starts the VU at imm*2 instructions: all draws use imm=0, so
  the VU starts at pc 0 (the jump table) -> `b L11` -> the strip path with
  vi14 = 0x2a0.  The trace confirms this path (L11 setup, L12 count/pointer
  reads, L14 vertex transform, JR back to the caller).
- The frag data at 0x160/0x381/0x384/0x3d4 = the vertex batch (139 qwords,
  (0,0,0,-1792) patterns), the 10-qword per-draw block, and two frag/page
  batches.  vi14 = 0x2a0 (the frag-list base) is NEVER written by any unpack
  in the capture -- the frag list (count + vertex-list pointers) must be
  written by the game outside the VIF chain (likely the tfrag-work's
  scratchpad path or a boot-time write).  Locating that write is the next
  open question before the XGKICK output can be captured.

## Files

- `tools/ottsel_vu1/` (interpreter + loader).
- `src/shell/metal_gfx.mm` (VIF/draw probes: VIFSEQ, VIF payloads, VUFUNC).

## BOT18d update (same day) — data blocks identified; no reference renderer exists

- The 0x381 (897) per-draw block (10 qwords) = the ADGIF register setup +
  floats (TEST_1=0x5026b at addr 0x47, TEXFLUSH=0x80808080 at 0x3f, and
  floats 0x303e4000/0x42e00000/0x3e600000) -- the output-header data, not
  the frag list.
- The 0x160 (352) block (139 qwords) = degenerate vertex/position floats
  ((0,0,0,-1792.0) every other qword) -- the camera at the origin sees the
  origin, so the title frame is empty at this point in the boot.
- The 0x3d4 (980) block (41 qwords) = 16-bit page/uv values; the 0x384
  (900) blocks (5 + 80 qwords) = 0x80000000/NaN markers.
- The old jak-project never shipped a VIF-based TfragRenderer (the first
  renderer was tfrag3/FR3-preloaded), so the raw-ISO tfrag VIF format must
  be reverse-engineered from the microcode + the game data -- there is no
  reference implementation to port.
- The open question remains: the frag list (count + pointers) the microcode
  reads at vi14 = 0x2a0 is not written by any VIF unpack in the capture
  (all 7 dests are absolute and none is 0x2a0).  Candidates: a boot-time /
  tfrag-work write outside the VIF chain, or a second address space (the VU
  reads the frag list from the scratchpad window).

## BOT18e update (same day) — frag list not in the VIF chain (definitive)

- A 3994-record capture confirms the tfrag draws use ONLY V4-32 unpacks at
  the 7 absolute dests (5/0x14d/0x290/0x160/0x381/0x384/0x3d4); the V4-8
  color path (imm 0xc000, TOPS-relative) never fires in the boot/title.
- The small DIRECT GIF transfers in the tfrag chains are uninitialized DMA
  buffer gaps (0xeeeeeeee fill), not the frag list.
- The vertex math fits dest = base + imm (vi14 + word1 = the 0x400 vertex
  list when word1 = 0x160), so the per-draw batches ARE at 0x2a0+imm
  (0x400/0x621/0x624/0x674), but the frag LIST (the count + pointer fields
  the microcode reads at vi14 = 0x2a0) is still not produced by any captured
  transfer.  It is likely written once at boot by a path outside the chain
  (candidate: the tfrag-work scratchpad handoff) - the next probe should log
  the VU data-memory READ addresses the microcode touches (instrument the
  interpreter's LQ/ILW) to discover the expected layout empirically.

## BOT18f update (same day) — interpreter now runs the full tfrag pipeline

Four real VU-semantics bugs fixed (all verified against the disassembler's
decode):
1. Branch delay slots were skipped (the jump-table `xtop vi14` never ran).
2. IADDI dest = the `it` field (bits 16-20), not `id`.
3. IADDI imm5 = bits 6-10 sign-extended; IADDIU/ISUBIU imm15 = bits 0-10 +
   21-24.
4. vi0 is hardwired to 0 (writes ignored) - the microcode's delay-slot NOPs
   were corrupting the count comparisons.

With these, the tfrag microcode now runs the complete pipeline with a crafted
frag list at vi14 = 0x2a0 (XTOP base): the strip transform (vertex list at
0x400, matrix rows at 0x2a5..0x2a8), the fan/level-0 quad loop (counts
4,3,2,1,0), and reaches the output phase's perspective-divide loop
(pc=1396).  The XGKICK GIF emission still needs the real page-data loop
bounds (the game's boot-time frag-list/page writes).  The last mile:
populate the output loop bounds (vi05/vi06) from the real 0x384/0x3d4
batches and capture the GIF output.

## BOT18g update (same day) — tfragment data identified as the frag-list source

- The full chain-3 VIF sequence is captured (register setup, init at
  5/0x14d/0x290, per-draw 897-blocks + MSCALF, frag batches, PC_PORT texture
  markers, DIRECTHL).  The frag list at VU mem 0x2a0 is not written by any
  VIF transfer.
- The frag data comes from the tfragment (the `drawable-inline-array-tfrag`
  in the level data; the mips2c copies its `dma-chain`/data to the
  scratchpad -> DMA).  The frag-list header {count, vertex-offset, page
  pointers} that the microcode reads at vi14 = 0x2a0 is part of the
  tfragment's data, not the per-draw unpacks.  The next probe: dump the
  title-vis tfragment from EE memory (via the drawable-tree) and populate
  the VU frag list + output loop bounds from it.

## BOT18h update (same day) — tfrag-work probe; output-loop bounds are the last step

- The `*tfrag-work*` symbol value is 0 at the boot draws (the tfrag-work is
  allocated later); the mips2c still builds the DMA (its t0-based writes hit
  EE+0 harmlessly).  The frag-list header the microcode reads at 0x2a0 is
  NOT the tfrag-work.
- The interpreter runs the strip + fan transform and enters the output
  phase's L110/L111 perspective-divide loop (pc=1396); the loop's bounds
  (vi05/vi06, from the frag's word4 -> data[vi09] count) need the real
  page-data count, which requires the title-vis tfragment's level data
  (dma-qwc / quad counts).  That read is the next probe; the XGKICK
  capture then feeds the existing direct rasterizer.
