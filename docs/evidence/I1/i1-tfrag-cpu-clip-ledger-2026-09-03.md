# I1 — live NORMAL TFRAG CPU clip ledger — 2026-09-03

## Question

Does live NORMAL TFRAG data fail because no vertices reach the Metal clip
volume, or because the packet/vertex projection produces an oversized scene?

## Method

Added the trigger-gated `ottsel-trace-metal-tfrag-clip-ledger`. After the real
title → New Game → Village1 route loaded the packet-owned level, the trigger
sampled up to 4096 NORMAL TFRAG vertices using the same `pc_camera` and
`packet.trans` equation as the Metal shader. It reports finite samples,
OpenGL clip visibility, Metal remapped-depth visibility, and NDC bounds without
changing rendering.

## Result: OPEN; narrowed input-contract failure

Fresh iPad Pro 11-inch (M4) run, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, logged:

`level='village1' geo=0 finite=4129/4129 gl-clip-visible=996`

`metal-clip-visible=996 ndc-x=(-151.8065,192.3513)`

`ndc-y=(-128.9887,45.4650) ndc-z=(-1.3028,1.9005)`

The ledger follows the exact cull-selected index set, rather than every vertex
in the level. All sampled submitted vertices are finite, but only 996 pass both
clip tests; the extreme NDC bounds agree with the inspected frame's world
collapsing mostly off-screen. This points to the live packet/vertex projection
contract or coordinate-domain handling, not a universally broken Metal
pipeline. Keep
`set_mobile_tie_camera`, TBP/lookup, and strip-restart frozen until the exact
source mismatch is identified.

Fresh frame:
`/tmp/ottsel-video/bot36-tfrag-exact-ledger-village1-2026-09-03.png`
(SHA-256 `ad7230be33f8c3a6d82a2d361710fc4ad8e0e6605c66a55916f2975a3f3c01c4`).
`ottsel-fault.log` was 0 bytes. PCM and VU1STAT remained active.

Next: correlate one live NORMAL TFRAG vertex and its packet camera against the
macOS reference at the same frame, then test the smallest proven domain or
ownership correction with a before-failing regression.
