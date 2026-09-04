# I1 TFRAG NORMAL-only isolation — 2026-09-03

## Question

Are TRANS or DIRT TFRAG families manufacturing the malformed Village1 frame?

## Method

Fresh signed diagnostic app on the single booted iPad Pro 11-inch (M4)
Simulator, with the existing one-shot
`ottsel-trace-metal-scene-tfrag-normal-only` probe and exact no-TIE/no-MERC
controls. Route: title-wait → Start → Cross → Down×4 → Cross. App terminated
after screenshot.

## Result: OPEN

NORMAL-only still produces the same oversized, black-gapped composition with
debug controls; Jak is not visibly controllable. Fresh frame:
`/tmp/ottsel-video/bot36-tfrag-normal-only-2026-09-03.png`, SHA-256
`08d66677e0f6e9f70ab7fed48477b31f146fcd7ffac36728aeb4613e409a41d3`.

Runtime logged a Village1 TFRAG mesh of `75960` vertices and `62284`
triangles. Since TRANS and DIRT were excluded, they are not the primary
source of the composition failure. This narrows the next investigation to
NORMAL TFRAG vertex submission/transform/composition; no camera math, TBP/
lookup, or strip-restart change is authorized by this result. Playability
remains OPEN.
