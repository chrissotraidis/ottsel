# I1 TFRAG Metal submission boundary — 2026-09-03

## Question

What exact vertex and uniform bytes reach the first large Village1 TFRAG draw?

## Method

Added a one-shot trigger-gated NSLog immediately before the TFRAG indexed draw.
The probe reads the shared Metal vertex/index buffers and the copied
`TieUniforms`, after requiring the Village1-sized draw set (at least 80 draws).
It does not alter the encoder state or submitted geometry.

## Result: OPEN; boundary captured

Fresh signed iPad Pro 11-inch (M4) Simulator route reached Village1. The first
large TFRAG submission logged:

`draw=0 index-offset=0 first-index=592`

`vertex=(-21825.334,55550.848,-20032.807) uv=(1.000,0.000)`

`projection=0 sign=1.0 trans=(-659084.875,235454.016,677712.312)`

The copied camera rows were finite and nonzero, including row 0
`(0.000062,-0.000002,0.000021,-0.000021)`, row 1
`(0.000000,-0.000089,-0.000001,0.000001)`, row 2
`(-0.000044,-0.000003,0.000029,-0.000029)`, and row 3
`(0.000000,0.000000,-0.072740,0.000000)`.

Fresh frame:
`/tmp/ottsel-video/bot36-tfrag-submit-boundary-village-2026-09-03.png`
(SHA-256 `8092647c1afbc77319b59e275a0d7e7dc5a860c4654dede1fcacbf5a6e94a644`).
It contains real textured Village1 geometry but remains misoriented and
miscomposed; Jak visibility, control, depth stability, and playability remain
unproven. Fault log was empty.

Next: compare this exact boundary sample with the upstream draw contract and
the final drawable orientation/composition before changing projection math.
