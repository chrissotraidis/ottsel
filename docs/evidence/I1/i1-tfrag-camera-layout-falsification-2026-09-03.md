# I1 TFRAG camera layout falsification — 2026-09-03

## Question

Is the malformed iPad TFRAG scene caused by treating the OpenGL camera bytes as
row vectors in the Metal shader instead of reconstructing GLSL columns?

## Method

Added a focused matrix-layout regression, changed the normal TFRAG/TIE shader
to reconstruct columns, and changed the diagnostic CPU ledger to the same
column contraction. Built and signed the iPad Simulator app, then replayed the
title → New Game → Village1 route on the single iPad Pro M4 Simulator.

## Result: OPEN; proposed fix falsified

The focused layout test passed. The fresh frame was:
`/tmp/ottsel-video/bot36-column-camera-village1-2026-09-03.png`
(SHA-256 `a4cf8677f7f4722a6155964f95eff0622b7743e4b67162ff96e8a2f100a32135`).

The actual Metal image became a radial warp and was materially worse than the
before frame. The corrected CPU ledger later reported `finite=4315/4315`,
`gl-clip-visible=4315`, `metal-clip-visible=330`, and compact NDC bounds, so
the CPU calculation and the submitted shader still do not describe one proven
ABI. The experiment did not consume the first trigger because it was placed at
the container parent; the corrected trigger confirmed the compact CPU result.

The column shader change was reverted. No camera math, TBP/lookup, or
strip-restart code was changed. Fault log remained 0 bytes. Playability stays
OPEN.

Next: instrument one actual Metal draw's packed vertex bytes and uniform bytes,
then compare that capture with the CPU equation before changing projection.
