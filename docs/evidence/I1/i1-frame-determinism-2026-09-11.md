# I1.2 — the iPad frame is not deterministic; single-screenshot A/Bs are void (2026-09-11)

**Question.** Are the scene-level pixel A/Bs recorded in this lane measuring
the renderer, or measuring launch-to-launch and frame-to-frame variation?

**Answer: they are measuring variation.** Every single-screenshot A/B in the
I1 lane sits inside the noise floor and must be re-derived.

## Method

Same installed binary (`b0b0ab11fa76a5b312d1b8dcfbfff18de9c9585d2de853d45d245354f4d5df8d`),
same simulator, no probe triggers, three launches. Screenshots taken with
`xcrun simctl io <udid> screenshot` and compared with `/tmp/diffpng.py`
(tolerance > 8/255, full 8-bit RGBA).

## Results

- **Launch-to-launch, identical config.** `abs-base2` vs `abs-base3`, both at
  t=45 s: **157127 / 398240 px differ (39.5%)**, bbox the full frame. Two runs
  of the same code differ on more than a third of the picture.
- **Within one launch.** Five shots at t=40/44/48/52/56 s differ pairwise by
  **36.3% to 78.7%**. The camera is continuously in motion: t=40 frames the
  island from a distance, t=56 is inside the huts. `scePadRead` is polled
  continuously, so the game loop is live and the renderer follows a moving
  camera.
- **Camera-motion-robust metric.** Non-background fraction (max channel > 40): `base2` 0.248, `base3` 0.265, `nodepth` 0.312, `nomerc` 0.241, `nosky` 0.276. The two baselines alone span 0.017, so only differences well above that are meaningful.

## Consequences

1. Any conclusion in BOT38/BOT39/BOT40 resting on **one screenshot per
   condition** is inside the noise floor. That includes this lane's earlier
   `scene-no-sky` / `scene-no-sprite` counts, which differ by 0.4-0.6% on
   grey/yellow/pink and are therefore consistent with zero effect.
2. `scene-no-depth` raises the non-background fraction from 0.248/0.265 to
   0.312, and its frame shows textured geometry above and behind the island
   that the baselines do not. The effect is larger than the baseline spread,
   so **depth rejection is suppressing real scene content** — but it needs the
   N-sample harness before it is called settled.
3. The flat coloured rectangles are the touch-frontend overlay
   (`src/shell/main.cpp:626-632`), which is the one result here that does not
   depend on frame equality: the cyan/grey/yellow/pink literals are exact and
   are pixel-identical in the baseline, the sky-skipped and the Sprite3-skipped
   frames.

Frames: `/tmp/ottsel-shots/abs-base2.png`, `abs-base3.png`, `abs-nodepth.png`, `il-40.png`..`il-56.png` (session-local, not committed).

## Next (falsifiable)

Build the comparison harness before the next probe: N screenshots per
condition across a fixed wall-clock window, compared as distributions. Then
re-test the depth hypothesis from result 2. Parallel lane: the Merc/Jak clip
ledger reports `visible=0` for all 9942 vertices with
`clip-z=(-1.0543,-1.0405)` and `clip-x=(0.4886,1.3657)`; the native Merc
shader is fed the **scene camera packet's** perspective while upstream feeds
`m_low_memory.perspective` from the Merc packet. Whether those two matrices
are equal is unverified.

I1.2 is **OPEN**. No playability claim.
