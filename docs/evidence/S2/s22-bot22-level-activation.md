# S2.2 BOT22 — village1 ACTIVATES: the "level never activates" blocker is resolved (2026-08-16)

## Result (verified live, zero faults)

- village1 (slot1) reaches **`'active`** with bsp=0x2ef80d4; the title level
  is discarded cleanly ("Discarding level title" / "----------- kill").
- The background-work list **fills every frame**: `tfrag-count=1`
  (tree 0x308df04) and `tie-count=3` (tie tree 0x32670c4 = the bsp's tree1).
- The restored tie-ln (`draw-inline-array-instance-tie`) **runs**
  (OTTSEL TIELN with the instance arrays 0x326a174/0x33a5934/0x3403884) —
  the tie bucket chains appear.
- Visibility is populated: `vis0=0xffffffff` on both the tfrag assembler
  (TFASM2) and the tie-ln after the all-visible fix (below).
- Evidence: s22-bot22-activation.log, s22-bot22-village1-active.png,
  LEVELSTAT steady state `slot0=inactive slot1=active bsp=0x2ef80d4`.

## What was actually wrong (the handoff's premise was false)

1. **The relocate's bsp write always landed correctly.**  The BOT21t/u
   "bsp write lands nowhere" conclusion came from probing one word short:
   the level's inline kheap is 16-byte aligned at mem+32 (not mem+28), so
   `bsp` is at **mem+48 = ref+44**, not ref+40.  The BOT21u probe's own
   scan line even said `bsp-hdr ref at lvl+44`.  Decoded correctly, the
   RELOC7RET dump shows loading-level=0x3fdcc44 (slot1, index 1, village1)
   with a REAL kheap (base 0x2c21230 / top 0x36df230 / current 0x360a730)
   and bsp=0x2ef80d4 immediately after the relocate.
2. **0x3fdd674 is `level-default`** (slot 2 ref = group mem 0x3fdc1b0 + 96
   + 2*0xa30 + 4), not the loading level.  `loading-level` points there
   whenever no load is in flight (`level-update-after-load` resets it), and
   during the early [58:54] texture-page relocates.  The "zero kheap"
   observation was this default slot, which legitimately has no heap.
3. **The level pipeline was never broken.**  Live status tracing
   (LEVELSTAT probe, corrected offsets) showed village1 progress
   `'loading -> 'login -> 'loaded` with the bsp set and login completed.
   It stalls at `'loaded` because the game is **waiting for input on the
   title screen**: the title flow displays village1 only from the logo
   intro's spooled-animation command list (frame 400 `display-level
   village1 display`) or the PC-port START shortcut in the `ndi` state.
4. **No input path existed.**  `scePadRead` pulls from the PC port's
   Display input manager, which is null in the headless iOS shell — every
   button read as unpressed forever (verified: `has-display=false`).
5. **The title intro can never play**: iso_data contains **no STR files**
   (only CGO/DGO + TIT.VIS), so the spooled logo/ndi animations never
   reach `'active` file-status; the logo process waits in blackout forever.
   A synthetic START press verifiably reached GOAL (`abs0=0x8 rel0=0x8`
   edge on cpad0) but no live state listens for it before the spool.

## The fix chain (runtime/shell layer only; no game-source changes)

1. **Synthetic pad bridge** (game/sce/libpad.cpp + src/shell/main.cpp):
   taps/clicks/keys and a file trigger (`ottsel-press-start`) press START
   on the synthetic pad; neutral analogs when no input manager exists.
2. **`(bg 'village1)` driver** (libpad.cpp, EE thread; file trigger
   `ottsel-bg-village1`): calls the game's own boot-to-level entry — the
   canonical OpenGOAL debug flow — once the title has village1 preloaded.
   This activates the already-'loaded village1 via level-get-for-use ->
   birth -> 'alive -> 'active and hooks add-bsp-drawable into
   *background-draw-engine*.
3. **`(-> *level* play?) = #f`** after the bg call: the genuine (bg) debug
   flow runs with play? #f; our boot ran (play) first, and with play? #t +
   `all-visible? = 'loading` cam-update's "in between vis" branch leaves
   vis-bits all-zero forever (goal_src .. cam-update.gc:153).
4. **`*artist-all-visible* = #t`** (the engine's own artist debug toggle):
   with the camera inside village1's boxes, level-update sets the self-vis
   flag and cam-update takes the update-vis! branch, which can never
   succeed without VIS data.  The toggle makes cam-update copy the bsp's
   `all-visible-list` into vis-bits every frame (cam-update.gc:110) —
   vis0=0xffffffff verified on the tie/tfrag assemblers.

## The next blocker (composed pixels)

The game now emits real tfrag/tie bucket chains, and the shell's VU1
interpreter runs constantly — but emits **zero GIF output**:
`OTTSEL VU1STAT: vu1-runs=2080 nonzero-gif=0 gif-words=0 draws=0`.
The MSCAL imm=0 runs execute with top=0x0 and exit before any XGKICK
(empty frag list at VU 0x2a0), and the tie bucket chains run against the
TFRAG microcode because the tie microcode (test/decompiler/vu_reference/
tie.txt, 994 instr) is not embedded in the shell yet — that is exactly
Track B step 2-3 of s22-reorientation.md.  The S2.2 composed-frame gate
now depends only on this renderer-side data path, not on game state.

## Probe corrections for future bots

- level (basic), ref-relative: name@0, load-name@4, nickname@8, index@12,
  status@16, other@20, pad@24, **heap@28..44 (base,top,current,top-base),
  bsp@44, art-group@48, info@52** (kheap 16-aligned at mem+32).
- level-group ref-relative: length@0, log-in-level-bsp@4, loading-level@8,
  entity-link@12, border?@16, vis?@20, want-level@24, receiving-level@28,
  load-commands@32, play?@36; slot0 mem = grp_ref+92, stride 0xa30
  (slot refs: grp+96, grp+96+0xa30, grp+96+2*0xa30).
- cpad-info ref-relative: valid@0, status@1, button0@2 (u16),
  button0-abs[0]@40, button0-rel[0]@56; #t = s7+8, START = bit 3 (0x8).
