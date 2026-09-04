# I1 — zte depth-write parity

Date: 2026-09-03  
Status: OPEN

Question: does Metal preserve the upstream distinction between disabled depth
testing and `Always` depth testing?

Evidence:

- Upstream `out/jak-project/common/dma/gs.h` defines DrawMode bit 19 as
  `get_zt_enable()`, while bits 1..2 select NEVER/ALWAYS/GEQUAL/GREATER.
- Upstream `background_common.cpp` disables `GL_DEPTH_TEST` when bit 19 is
  clear; Metal previously mapped that case to `Always` and could still write.
- This change makes depth writes require both `zte` and the source write bit.
  The compare index remains the upstream four-way mapping.
- Build completed and signed `out/jak-project/out/ios/app/OttselShell.app`.
- Generic test runner is OPEN: `out/jak-project/build/goalc-test` is absent;
  `out/jak-project/test.sh` exits 127 before running tests.
- Fresh simulator screenshot SHA-256:
  `6f4a409034817268c4f7712c8732da044e5125659a5800fa59c79421793d3be1`.
  It was captured before the route reached Village1 and shows the
  diagnostic/control surface.
- The same runtime later reached Village1. Normal-depth frame SHA-256:
  `018e7cdc9268ae0a1d5b66a06af3e6f3da07dd8afdc877cbcf4288e541a141a5`.
  The paired no-depth frame SHA-256 is
  `2459f64aab7a50fb4c1cff16ce707204d99d4a980ae02e3ec24c5c9bfb723759`.
- No-depth reveals substantially more textured village geometry, confirming
  depth rejection contributes to the corruption; it remains rotated/raw and
  still lacks a visible Jak, so depth is not the sole remaining defect.
- Required scene-family controls on the same runtime produced fresh frames:
  no-Merc SHA-256 `de74f8f0c70a358948eb4f39cf7d132bbafc1650aca06ad24ee0c23abe0be37f`;
  no-TIE SHA-256 `67b2e78cc974e4c368f69fdd118a5bd422adaa8aac7c093e0b8e877e890c6680`.
- The no-Merc image still contains the malformed world, while no-TIE changes
  the visible family substantially. Neither control makes Jak visible.
- Runtime telemetry recorded repeated `VU1STAT` chain samples and positive
  audio PCM, including `pcm-peak=11869` earlier in the same route.

Decision: source parity is supported and the paired runtime result is
informative, but the product visual regression remains OPEN. Next isolate
projection/composition and actor visibility using the same Village1 route;
do not claim playability.
