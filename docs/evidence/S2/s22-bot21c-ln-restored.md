# S2.2 BOT21c: mips2c `ln` restored -- the game's tfrag draw pipeline now runs

Date: 2026-08-16.  Status: S2.2 PROGRESS (the game-side tfrag pipeline is
engaged and verified live; the composed frame still needs the SPR->VIF1
renderer step -- precisely scoped at the end).

## What was done (falsifiable fix)

`goal_src/jak1/engine/gfx/tfrag/tfrag-methods.gc` had every
`(draw-inline-array-tfrag ...)` call commented out (the port disabled the
mips2c frag-list builder).  Restored the 4 far calls (draw-drawable-tree-
tfrag, -trans-tfrag, -dirt-tfrag, -ice-tfrag) matching the retail
decompiler reference, recompiled GAME.CGO via goalc ARM64
(`(load-project "goal_src/jak1/game.gp") (make "out/jak1/iso/GAME.CGO")`,
338 targets, 11s; bundle md5 c7fa4149 -> 7d44395a).

## Verified against the running app (one boot, zero faults)

- The TFASM probe inside `draw_inline_array_tfrag::execute` now FIRES
  (previously silent): `a0=0x1d38b0 (vis-list) a1=0x22978c4 (tfragments)
  a2=1 (one far tfragment) a3=0xcdcf54 (dma-buffer)`.
- The mips2c ln writes `*tfrag-work*` +0xb0 = 0xcdcf54 (the dma-buffer) --
  the draw-state field that was 0 when the calls were disabled.
- The tfragment's dma-chain[0] = 0x2297920, qwc = 128: the STORED per-draw
  VIF stream (the level data the game DMA's through the scratchpad on real
  hardware).  It contains the frag-list header UNPACK (V4-16 num=5
  addr=0x000 -> VU words 0-4) plus small batches at VU 0x1a/0x16 and the
  geometry/frag data.
- The vis-list byte for the tfragment reads 0x0 (the port's draw-node-cull
  is disabled, so the vis-list never gets set) -> the far tfragment is
  skipped.  With a diagnostic vis-force the SPR TO transfer runs
  (`madr=0x22978c0 sadr=0x1d0010 qwc=64`), copying the tfragment + dma
  data into the fake scratchpad (`*fake-scratchpad-data*` value 0x1d0000).

## Renderer-side scaffold (shell)

The port has no SPR->VIF1 DMA, so `gfx_send_chain` now emulates the first
step: when ln stashes the dma-chain (tfrag-work +0xb8/+0xbc), the shell
parses the stored VIF words (UNPACKs -> VU mem, DIRECT skip) and populates
the frag-list at VU 0x0 (verified: `OTTSEL SPR UNPACK addr=0x0 num=5
d0=00000004...`).  The microcode's far path then reads data[0].x (strip
count 4) / data[0].z (frag count 0) / data[1].z / data[2].z / data[3].w;
gif_out is still 0 because (a) the far strip geometry at VU 27+ is not
uploaded (the parser does not yet consume the stream's DIRECT-embedded VIF
commands / the later UNPACKs) and (b) the vis bit 0 skips the tfragment
without the diagnostic force.

## Next step (precise, falsifiable)

1. Parse the tfragment dma data with the REAL VIF/DMA semantics: the stream
   is `[dma tags + IR]` with VIF commands embedded in the DIRECT payloads
   (e.g. `05000001` DIRECT-1 whose data is the next UNPACK words); consume
   exactly per command so the geometry UNPACKs (the far strips at VU 27+)
   upload, then the frame-init MSCAL's far path transforms + XGKICKs.
2. Resolve the vis-list: either restore the game's draw-node-cull (a mips2c
   extern in the port) or verify the terrain-context vis-list base/offset
   (the vis read at 0x1d38b0 may be out of bounds if the vis-list base is
   not where the port's scratchpad-object math puts it).
3. Success: tfrag MSCAL produces gif_out (draw_count > 0) and the raster
   presents a composed frame.

## Files

- `goal_src/jak1/engine/gfx/tfrag/tfrag-methods.gc` (ln calls restored),
  recompiled GAME.CGO (7d44395a).
- `game/mips2c/jak1_functions/tfrag.cpp`: TFASM/TFASM2/SPADTO/TFRAGSTASH
  probes (runtime lib; regenerate patches/h3-jak1-host-boot.patch).
- `src/shell/metal_gfx.mm`: SPR->VIF1 scaffold (parses the stashed dma
  data, UNPACKs -> VU mem) + the BOT21 probes.
- Runtime log: `OTTSEL TFASM/TFRAGSTASH/SPADTO/SPR` lines.
