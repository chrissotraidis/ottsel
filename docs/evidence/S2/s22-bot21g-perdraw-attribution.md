# S2.2 BOT21g: per-draw renderer attribution corrected (tfrag pc0/L11), verified offline + live

Date: 2026-08-16.  Status: S2.2 PROGRESS (one falsifiable shell fix verified
against both the offline full-VIF replay and a fresh live boot; the composed
frame remains blocked on the game-data level, now precisely attributed).

## What was wrong

The shell's per-draw VIF handling had three bugs that misattributed every
per-draw tfrag chain to the wrong VU1 program:

1. **Wrong ADDR flag bit.**  The UNPACK destination used bit 21 as the
   `addr?TOPS:TOP` flag; the VIF UNPACK flg/addr bit is bit 15 (0x8000).
   Bit 21 lives inside the `num` field, so the 80-qword page batch
   (UNPACK 0x384, n=0x50) was written to TOPS+0x384 instead of TOP+0x384.
2. **Generic-microcode misattribution.**  Any chain that uploaded the const
   block at VU 0x381 ran the GENERIC (tie/merc) microcode.  The 0x381 const
   (c0 = 0x7f7fffff) is the TFRAG per-draw path's own const (uploaded by
   tfrag-init-buffer); the generic program never produces output for these
   chains (verified: 0 gif words over all 661 mscals in the replay).
3. **Wrong tfrag entry.**  BOT21d's pc=8 (L3, `xtop vi14`) applied to the
   SPR scaffold's manual far-stream execute; the per-draw MSCALF 0s need
   pc = imm*2 = 0 (L11: `iaddiu vi14, vi00, 0x2a0`, frag-list base 0x2a0).

## The offline full-VIF replay experiment (falsifiable)

Built a replay tool (tools/ottsel_vu1 main/replay harness in /tmp) that
processes the app's `tfrag-vif-replay.bin` capture with correct VIF
semantics (BASE/OFFSET/STCYCL/UNPACK flg bit 15, TOP=0 from the live BASE
commands) and runs every reference microcode at each of the 661 MSCALFs:

| microcode | entry | total gif words (cap 200k) |
|---|---|---|
| tfrag | pc0 (L11) | 60,792 (mid-emission; 0 at cap 400k) |
| tfrag | pc8 (L3) | 121,584 (mid-emission) |
| tnear | pc0 | 4,640,220 (runaway loop) |
| generic | pc0/pc8 | 0 |
| tie | pc0 | 5,288 (misinterpreted data) |
| merc | pc0/pc8 | 0 |

With a 400k instruction cap every tfrag mscal exits cleanly with gif_out=0;
the 60k-121k word counts at cap 200k are partial emissions of the L102
loop over the empty frag-list (all-zero VU 0x2a0..0x2a8), not real draws.
The per-draw groups are therefore the TFRAG program at pc0/L11, and the
absence of output is caused by the never-built frag-list, exactly as the
shell's BOT21b finding stated -- now proven with the correct microcode.

## Live verification (one boot, one Simulator, Windowed, zero faults)

Fresh boot of the fixed shell (com.ottsel.shell, PID 95944, fault log 0
bytes, stable 10+ min):

- `OTTSEL CONST381: chain=2 qw=10 c0=7f7fffff ...` -- the per-draw const
  upload is logged as the tfrag path's const (no more generic dispatch).
- `OTTSEL VU1: run#N mscal imm=0x0 top=0x0 pc=1382/1070/1414/141/1506/313/
  1706 gif_out=0 frag[0..2]=0x0/0x0/0x0` -- every per-draw MSCALF 0 now
  runs the tfrag L11 program and exits without output; the exit pcs match
  the offline replay exactly (1382, 1070, ...).
- `OTTSEL GENERIC` count = 0 (misattribution removed).
- The boot reaches the draw state ~8 min in; the visible frame is the real
  Jak texture (tpage 0x1cf tex 44) on black (s22-bot21g-perdraw-tfrag-stable.png).

## Why gif_out is still 0 (game-data-level blockers, now fully attributed)

1. **Frag-list never built.**  The L11 frag-list at VU 0x2a0 stays all-zero:
   the mips2c `ln` (draw-inline-array-tfrag) skips the tfragment because
   its vis bit is 0 at draw time (`OTTSEL TFASM2: vis=0x0`); the port's
   goal_src disables the draw-node-cull pass (the `#| TODO |#` block in
   tfrag-methods.gc), so the terrain-context vis-list is only populated
   AFTER the draw (`OTTSEL VISLIST @+0x38b0: 80808080 ...`).
2. **Far LOD genuinely empty.**  The 0x160 vertex batch (139 qwords) is 63
   (0,0,0,-1792) markers + the LOD offset table (0x160/0x166/.../0x1c8) --
   verified byte-by-byte from the replay; even a built frag-list would draw
   degenerate strips.
3. **Near path unavailable.**  The only village1 tfragment has dma_level1 =
   0x13131310 (garbage, no near chain), draw-inline-array-tfrag-near is
   unlinked (FNSYM val=0), and the near draw code is commented in goal_src.

## Files

- `src/shell/metal_gfx.mm`: UNPACK flg bit 15, tfrag pc0 per-draw entry,
  generic misattribution removed, CONST381 evidence log.
- `docs/evidence/S2/s22-bot21g-perdraw-tfrag.log|png` (fresh boot capture).

## BOT21h addendum (same boot) — the level-load stall: vi1.DGO raw geometry skipped

The same fresh boot's DGO sequence is ART.CGO (21) -> tit.DGO (15,
"title-vis") -> vi1.DGO (55, "village1-vis").  The vi1.DGO serve drops
every non-GOAL record: "skip non-GOAL obj 9 (village1-part, 36768 bytes,
tag=0x0)", "obj 10 (village1-part2, 56560 bytes)", plus villagep-obs,
village-obs, oracle, sage, fishermans-boat, sequence-a-village1.  The
serve rule (game/sce/sif_ee.cpp, DGO_RPC_LOAD_NEXT_FNO) only accepts the
v2/v4 tag 0xffffffff or the no-emit v3 "GOAL" magic (0x4c414f47) blocks;
raw data records are skipped instead of being loaded into the double-
buffer, so the level's raw geometry never reaches the level heap.  After
"link finish: village1-vis" (37:30) no further DGO load begins; the level
process spins in the draw loop with the placeholder tfrag tree (1
fragment, empty far LOD) and no tie trees.  The composed frame cannot
exist until the real level geometry is loaded.  Falsifiable next check:
serve the non-GOAL records into the double-buffer without linking (the
real overlord loads every DGO object; link_and_exec applies only to GOAL
link blocks), then re-verify the tfrag tree's fragment count + far/near
LOD data and whether village1-part/part2 are the real tfrag/tie geometry.
