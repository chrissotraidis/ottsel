# S2.2 BOT21i: the village1 level's BSP is never loaded (bsp=0, verified live); the vi1.DGO v3 raw objects are the missing geometry

Date: 2026-08-16.  Status: S2.2 PROGRESS (the composed-frame blocker is now
pinned to the level-load path: the level's BSP is 0 in the running app, and
the vi1.DGO objects that carry the level data are the jak1 v3 link objects
the port's serve rule skips because the linker has no v3-PS2 path).

## Live level-state probe (one boot, one Simulator, Windowed, zero faults)

Added a shell probe (src/shell/metal_gfx.mm) that reads `*level*` -> the
level-group and resolves the level fields.  Offsets come from the goal types
(level: name+4 load-name+8 nickname+12 index+16 status+20 other+24 heap+28
bsp+48 with the basic type tag at -4; level-group: level0 inline at +92,
confirmed by the level0 type tag 0x507c84 = the `level` type object) and
the symbol addresses are matched by interning candidate names:

```
OTTSEL LEVEL: *level* sym=0x185974 group=0x3fdc1b4
OTTSEL LEVELGRP: +0.. = 00000002 0018fe04 03fdd674 ...
OTTSEL LEVEL: level0(inline +92) type-tag=0x507c84   ; the level TYPE
OTTSEL LEVEL0: name=0x18fe04 load-name=0x0 status=0x19c18c bsp=0x0 heap=0
OTTSEL LVLSYMADDR: 'inactive' sym=0x19c18c           ; level0 status = inactive
OTTSEL LVLSYMADDR: 'village1' sym=0x19cd44
OTTSEL LVLSYMADDR: 'village1-vis' sym=0x18d3fc  'vi1' sym=0x19b474
OTTSEL LVLSYMADDR: 'loading' sym=0x1955f4  'loaded' sym=0x19c704
```

The level0 slot is INACTIVE with bsp=0 and an all-zero kheap; the
loading-level (level-group +8 = 0x3fdd674, type-tag 0x507c84 = the level
type, index 2 = village1 per level-info.gc) also reads bsp=0.  So the
village1 level object exists but its BSP (the drawable trees: tfrag/tie
geometry) is never linked -- consistent with the placeholder tfrag tree
(1 fragment, empty far LOD) observed since BOT21d.

## The missing geometry: vi1.DGO raw objects are jak1 v3 link objects

The vi1.DGO serve skips every object whose first word is not 0xffffffff
(v2/v4) or "GOAL" (no-emit v3):

```
skip non-GOAL obj 9 (village1-part, 36768 bytes, tag=0x0)
skip non-GOAL obj 10 (village1-part2, 56560 bytes, tag=0x0)
skip non-GOAL obj 0 (villagep-obs) ... (oracle, farmer, explorer, assistant,
  sage, yakow, village-obs, fishermans-boat, sequence-a-village1)
```

The village1-part object bytes are exactly the jak1 LinkHeaderV3:
`{0x0, 0x6f0, 0x3, 0x3, "village1-part"...}` = {type_tag=0, length=0x6f0,
version=3, segments=3, name[64], segment_info[3]} (the decompiler's
LinkHeaderV3 in LinkedObjectFileCreation.cpp; obj.txt lists them as
version 3, ".o" objects).  The port's linker (game/kernel/jak1/klink.cpp)
has no jak1 v3-PS2 path: `m_version == 3` asserts `m_opengoal`, so the
previous agent's serve rule skips them (they crashed link_and_exec).
Result: the level geometry parts never reach the level heap, the BSP never
links (bsp=0), and the level sits in the draw loop with the stub tfrag
tree.

## Next falsifiable step (the actual fix)

Implement the jak1 v3 PS2 link path in the port's linker (relocate the
segment data/link tables like the decompiler's c_symlink2/v3 handling),
serve the v3 objects instead of skipping them, and re-verify live: the
level's bsp becomes nonzero, the tfrag tree's fragment count grows past 1
with real far/near LOD data, and the per-draw VIF gains the frag-list
header (gif_out > 0).

## REVISION (BOT21i rev, same day) — v3 objects are MIPS code; bsp-header linked but the bsp stayed 0

Live re-verification with corrected offsets and symbol resolution:
- The v3 objects are MIPS code, not geometry: village1-part seg0 words
  start 0x67bdffb0 (addiu sp,sp,-0x50) / 0xffbf0000 (sd ra) and seg2 has
  115 lui/addiu split-pointer relocs into seg0/seg1 (decode verified in
  Python against the decompiler's link_v3 seek/fix algorithm).  They are
  the level's code objects; the previous "missing geometry" attribution
  was wrong.
- The bsp-header DID link: village1-vis (last vi1.DGO object) linked with
  type 0x14e6024 whose name symbol is 'bsp-header (0x19dde4); the linker's
  relocate call ran (no invalid-type assert, no "ERROR: file" version/
  type format messages).  The served object's linked data at 0x2ef8080:
  v4 header {0xffffffff,0xfa00,4,0x712660} + code; the info.file-type
  points into the object (0x2ef8264), major-version=0.
- The level slots still read bsp=0: level0/level1 inline slots (type tag
  0x507c84) have name '#f' (0x18fe04) / status 'inactive' (0x19c18c) /
  bsp=0; the loading-level (0x3fdd674, index 2, info=0x1c83994) reads
  bsp=0 at +40.  So the level died at/after login-begin.
- The remaining open question: why the bsp-header relocate did not set
  (-> loading-level bsp) -- the file-info checks (file-type/major-version
  vs level-bt 30) or the loading-level pointer used by the relocate.
  Next probe: log inside the bsp-header relocate / the level login state
  machine.

## Files

- `src/shell/metal_gfx.mm`: level-state probe (BOT21i).
- `docs/evidence/S2/s22-bot21i-level-state.log` (fresh boot capture).
