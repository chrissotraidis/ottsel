# L3: the group0 sprite atlas stops re-zeroing a megabyte per call - 2026-09-22

Gate: L3 (cadence).  Follow-on from `l3-merc-optimisation-ab`, which left `__bzero` as the largest untouched
leaf (13-18% of the chain walk).  Grouping its leaf samples by enclosing frames put **208 of 215** inside
`render_mobile_sprite_group0` - the World2D product-group sprite path.

**Cause.**  That path built its packing atlas as

```
std::vector<u8> atlas_rgba((size_t)kAtlasWidth * kAtlasTile * kAtlasRows * 4, 0);
```

i.e. a fresh **1 MB zero-filled vector on every call** (512 x 64 x 8 x 4), before packing one to eight 64x64
tiles into it.  The zero fill and the allocation were per call, and this path runs several times a frame.

**Change (one line plus its rationale).**  The buffer is now a function-local `static` sized once.  That is
safe because every byte that leaves the CPU is written: the packing memcpys each tile's `width x height`
rows into its cell (plus alpha fixups for `tcc == 0`), the upload covers only the used columns and rows, and
the emitted vertices' UVs are scaled by those used dimensions so they sample only packed cells.  Stale bytes
can therefore only live in cells that are neither uploaded by size nor sampled by any vertex.

**Measured, in state-matched 3 s samples of the title screen** (the same protocol as the A/B document):

| leaf | before | after |
|---|---|---|
| `__bzero` | **215** | **7** |
| `access` | 156 | 196 |
| `capture_mobile_merc` | 12 | 12 |
| `_platform_memmove` | 64 | 78 |

chain-walk totals 1358 and 1300, main-thread 1492 and 1555, so `__bzero` falls from 7.5% to 0.2% of the two
threads while every other leaf is unchanged within noise - and the "after" sample ran under a *higher* load
(6.38 against ~4.4-5.1), which biases against the change rather than for it.

**Correctness.**  Sprites still draw: `SPRITE FRAME ... drawn=22` in the training level and `drawn=19-73` in
title windows, the atlas still reports used-area sizes (`native World2D atlas vertices=288 sprites=48
textures=7 atlas=448x64`), the gameplay capture `/tmp/ottsel-atlas-level.png` shows the level with its
distant sprite actors rendered, and `ottsel-fault.log` stayed at 0 bytes through every run.

**Next in the same distribution.**  `access` is still 6.9% of the two threads and is spread rather than
concentrated: the main loop's own trigger polls (51 samples - the hold list plus the thirteen
`ottsel-touch-*` polls this session added), `presentRGBA:` (49), the nested Mips2C particle launcher (42) and
`render_mobile_sprite_bucket` (5).  Batching the main loop's 23 per-frame stats and moving the
particle-launcher probe behind its trigger are the remaining bounded targets.

Not claimed: no fps number; these are share measurements in a fixed state, which is what the host's load
behaviour supports.
