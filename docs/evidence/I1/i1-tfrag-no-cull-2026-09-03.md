# I1 TFRAG no-cull isolation — 2026-09-03

## Question

Is packet-plane/BVH visibility selection the cause of the malformed TFRAG
composition?

## Method

One signed diagnostic build with the one-shot
`ottsel-trace-metal-scene-tfrag-no-cull` trigger, plus exact no-TIE and
no-MERC controls, on the single booted iPad Pro 11-inch (M4) Simulator. The
route was title-wait → Start → Cross → Down×4 → Cross, followed by termination.

## Result: OPEN

The no-cull frame is visually unchanged: geometry remains oversized and
miscomposed with large black regions and debug controls; Jak is not visibly
controllable. Fresh frame:
`/tmp/ottsel-video/bot36-tfrag-no-cull-only-2026-09-03.png`, SHA-256
`54d0ab6fcc52f34a03661b50576af8cb5acacb890fa6a631451b89a18cac27dc`.

Runtime confirms `scene no-TIE probe enabled`, `scene no-MERC probe enabled`,
`TFRAG mesh vertices=76264 triangles=53524`, and `no-cull probe enabled`.
Because removing culling does not materially change the frame, the BVH/plane
visibility selection is falsified as the primary cause. No production culling
behavior was changed; the diagnostic is one-shot only. Camera math, TBP/
lookup, and strip-restart remain frozen. Playability remains OPEN.

Next: inspect the TFRAG native draw/material contract and its relationship to
the final drawable, with a before-failing regression before any fix.
