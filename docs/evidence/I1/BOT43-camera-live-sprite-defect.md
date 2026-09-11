# BOT43 I1 evidence — camera live, sprite layer is the visible defect (2026-09-11)

Device: iPad Pro 11-inch M4, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`,
bundle `com.ottsel.shell`, binary `756bbd1a35e5`, container
`Application/4DBA89EB-AC76-40D2-ACCF-9BD7EE3A5CFD`.

## Claim 1 — the camera and scene are live (refutes the BOT42 freeze framing)

PROVEN. Two measurements:

- Screenshots 8 s apart in one launch differ on **5.34%** of sampled pixels
  (step=2, sum|dRGB|>24), change bbox `x[670..996] y[592..1854]`. The status-bar
  clock region is outside that bbox, so the capture path is live and the diff is
  content, not a timestamp.
- Four consecutive route screenshots show four different world views after
  START+Cross (island overview, hut exterior, plaza interior, grass slope).
  `OTTSEL SUBMITSTAT` in the same run: `cam-accepted` rises 1:1 with `chain`
  (340 -> 510 -> 610) and `merc-submits` rises ~90 per 90 chains, one Merc
  submission per frame.

Conclusion: the scene is not deduplicated, not latched, and not a frozen
framebuffer. The prior session captured a static title camera and misread it as a rendering freeze.

## Claim 2 — the flat rectangles are the Sprite3 layer

PROVEN by subtraction. The layer probes latch live each frame:

| arm | trigger | result |
|---|---|---|
| baseline | none | 8 flat axis-aligned rectangles over the scene |
| no-sprite | `ottsel-trace-metal-scene-no-sprite` | **every rectangle gone**; correct textured village |
| sky-debug-fill | `ottsel-trace-metal-sky-debug-fill` | rectangles still present |

With sprites off the frame is a correct, fully textured, lit training-level
village: cliff rock, grass, palms, thatched huts, stone walls, wooden walkways,
barrels. Scene correctness is not the blocker; the overlay is.

## Claim 3 — two measured sprite data defects

1. `OTTSEL SPRITE IDENTITY: mobile chain=0 group=0 sprites=48 tbp=0x24f2 ...
   size=64x64 rgba-hash=0xbe7fb0911be00383 alpha-max=0 nonzero-alpha=0` — the
   decoded 64x64 PSM19 page has **zero nonzero alpha**. Group 3 shares that hash.
2. `OTTSEL SPRITE ZERO TEX PRODUCT: chain=6 group=0 count=16 ...
   tex0=0x0000000000000000` and `OTTSEL SPRITE 3D DMA SOURCE: start= count=
   tbp=0.0000 tw=0.0000 th=0.0000` — Sprite3 groups arriving with **no texture
   register**. `src/shell/metal_gfx.mm:4824` drops these (`!adgifs[0].tex0_data`),
   so they cannot be the rectangles without a counter; that counter is the next
   experiment.

Also measured: `hud-sprites=0 3d-sprites=320 other-sprites=0` out of
`groups=54 sprites=2560`, and the native gate at `metal_gfx.mm:4824` accepts only
groups whose `count` is exactly 48 or 16 — most sprite groups per frame are never
candidates for the native 3D path.

## Not proven

- Which group id draws which rectangle. No counter maps a rectangle to a group.
- Whether `tex0 == 0` is a legitimate colour-only draw or a parser defect.
- Why `tbp=0x24f2` decodes to zero alpha.
- Any playability claim. No input moved the player; `AUDIO: pcm-peak=0`.
