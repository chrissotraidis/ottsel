# I1 — the full-screen yellow quad is emitted by the mobile 2D sprite path

2026-09-11. iPad Pro 11-inch M4 Simulator (iOS 18.5), UDID 08636791-2675-4675-8335-EF72EF954DCF,
app `com.ottsel.shell` (native, signed, no JIT). `scene-level='training'`. No product source changed.

## Question

Frames intermittently contain a huge flat-yellow polygon over the world. Is that
the mobile 2D sprite/HUD path or the world (TFRAG/TIE/Sky) path?

## Method

Zero-code-change A/B on the existing isolation probe `ottsel-trace-metal-scene-no-sprite`,
which makes the shell skip appending `_spriteBatches` (metal_shell.mm:1680).
Coverage was measured per capture by a pure-Python PNG decoder (r>200, g>200, b<80).

## Result

Baseline (probe unarmed), 23 captures ~1 s apart:

- 19 captures: yellow <= 0.10% of frame (only the "FIND THE CELL ON THE PATH"
  glyphs, bbox inside the centre reticle).
- 4 captures: yellow 35.3-35.5% of frame, bbox spanning the whole drawable
  (y4.png: 1433761 px = 35.52%, bbox (0,0)..(1667,2390)).

Armed (`ottsel-trace-metal-scene-no-sprite`), 30 captures in two runs:

- 30 of 30: yellow 0.03-0.05%, bbox confined to (99,26)..(278,294) of a 289x420
  downscale. Zero full-screen quads.

Inspected frames agree: armed, clean terrain with no banner plate or title text,
while the small cell-icon and red-ring sprites remain (separate consumer).

## Conclusion (proven)

The full-screen yellow quad comes from the mobile 2D sprite/HUD draw path. It is
not a world-geometry, TFRAG, TIE, Sky, depth, or camera defect. That path
submits at least one screen-space quad whose device-space extent is the whole
drawable, in ~17% of observed frames.

This also explains the earlier "frozen frame" misread: the content is a mostly
static HUD pose, so consecutive captures are often bit-identical while the
engine runs (`chain` 8730 -> 9270 in 51 s, ~7/s; `scePadRead` #34001 -> #35001
in 33 s, ~30/s).

## Falsifiable next step

Log, for HUD phase groups only, the four device-space clip vertices plus
`sx`/`sy`/`q` of every submitted sprite, then find the record whose extent is
drawable-sized. If no single record is degenerate, the defect is the group's
inherited `MobileSpriteFrameJak1` (`basis_x`/`basis_y`, `hmge_scale`,
`min_scale`/`max_scale`) rather than a per-record vector.

## Caveats

- Informative logging stops after ~[10:48]; `SUBMITSTAT`/`VU1STAT` last appear
  at `chain=8190` while `chain` runs past 9700. A log budget ended those lines.
- `ottsel_metal_gfx_game_frame()` is still a stub returning 0, so the presented
  image is the Metal TFRAG/TIE/Sprite mesh over the (8,10,18) base.
- Gate N1 unproven. No playability claim.
