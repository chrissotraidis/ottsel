# S2.2 Reorientation (2026-08-16) — connecting the dots: what works, what doesn't, and the new goal

## What IS working (verified against the running app, bundle logs, compiled ground truth)

1. **The no-emit runtime boots and runs the real game.**  KERNEL.CGO + the
   recompiled GAME.CGO link, the GOAL kernel dispatcher loops, title-obs
   runs, the process tree is up, zero faults across many boots.  S2.1 is a
   verified, committed gate.
2. **Metal presents real Jak textures.**  The present path + the GS
   un-swizzle decode work: the real village tpage 0x1cf tex 44 is visible
   on screen (and the BOT16 title texture frames).
3. **The village1 geometry loads into memory.**  The bsp-header linked
   (type 'bsp-header, name 'village1) with 11 drawable trees, including the
   drawable-tree-instance-tie trees with REAL instance data (6+42 and 2+14
   instances at verified addresses).
4. **The bsp-header relocate SUCCEEDS.**  `RELOC7RET: arg=0x2ef80d4
   ret=0x2ef80d4` -- the goal relocate's `(else ... this)` branch ran, all
   its checks passed, and it returned the bsp-header.
5. **The VU1 interpreter + the tfrag microcode + the rasterizer work.**
   The per-draw tfrag groups run (pc0/L11), the direct bucket decodes, the
   NDC->screen mapping is corrected, TRI_STRIP restarts are handled, and
   the renderer-attribution fix is verified offline + live.
6. **The tie-ln call is restored in the game source** (tie-methods.gc) and
   GAME.CGO is recompiled (`--isa arm64`, md5 4e33a7fb, in the bundle).

## What ISN'T working (the blocker chain, all verified)

1. **The level never activates.**  The level0/level1 slots end `'inactive`,
   and the loading-level (0x3fdd674, index 2 = village1, info read) shows
   bsp@40=0, bsp@44=0, bsp@48=0x1c83994, and a ZERO kheap -- even right
   after the relocate that returned success.  Either the relocate set a
   different object's bsp, or the level object's field layout/heap state is
   broken (the zero heap is a strong signal the level object was never
   properly allocated).
2. **The background work stays empty** (`tfrag-count=0`, `tie-count=0`
   every sampled frame) -- the bsp's drawable trees are never added, so the
   background engine never draws the village geometry.  The tfrag VU1
   chains that appear come from a loading-state path, not the bsp's trees.
3. **The tie ln never runs** (the restored call is unreachable while the
   trees are never drawn), so the tie bucket chains never appear.
4. **The visible frame = a real texture only** (no geometry).

## The honest read

The renderer side (Metal, VU1, textures, rasterizer) is solid and verified.
The blocker is the GAME-STATE layer: the level never reaches
`'alive`/`'active`, so the game never draws its own geometry.  The
level-activation investigation has narrowed the failure to after the
relocate (which succeeded), but the exact death point is still open --
the loading-level object's identity/field-layout (and its zero heap) is
the next ground-truth question, plus the login/birth phase after
login-begin.

## The new goal (reoriented, self-assigned)

**Get Ottsel to a verified composed frame, ROM-safe and proof-gated.**

Track A (game-driven, the "proper" fix):
1. Resolve the loading-level's true identity + field offsets (levellayout
   type-system tool or compiled disassembly): is 0x3fdd674 the real
   village1 level (with a zero heap = never allocated), and where does the
   relocate's bsp write land?
2. Trace the level status transitions after login-begin
   (`loading -> loaded -> alive -> active`) and find where the level dies.
3. Fix the smallest falsifiable fault so the level activates, the
   background work fills (tfrag/tie trees added), and the tie bucket
   chains appear; wire the tie microcode (tie.txt) + rasterizer and verify
   the composed village frame with visible interaction evidence.

Track B (evidence frame, the S2.2 gate fallback):
4. Compose a visible frame from the LOADED geometry via the shell's own
   renderer: feed the verified tie instance data + prototypes through the
   tie microcode (tie.txt) + the existing VU1/rasterizer, producing a real
   composed frame from real game data (ROM-safe, no assets committed) --
   while Track A continues.

Constraints: one Simulator, one runtime, Windowed only; verify every claim
against the running app, bundle logs, and compiled-kernel ground truth;
record milestones in docs/evidence/S2/; update STATUS.md/13-current-state.md
only after a verified gate; never commit ROMs/ISOs/assets; stop and report
honestly at any gate that repeats three consecutive blockers.
