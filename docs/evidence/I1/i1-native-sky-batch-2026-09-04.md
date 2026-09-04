# I1 native Sky batch — 2026-09-04

Question: does the new ordered native Sky batch queue produce a usable Sky
pass without destabilizing the existing Metal scene?

Change: add a separate pre-world `_skyBatches` queue and an opt-in
`ottsel-enable-native-sky-product` path. Decoded Sky primitives are intended to
be queued before TFRAG/TIE; the existing Sprite3/HUD queue is unchanged.

Build: signed iOS Simulator app, OttselShell hash
`d9eca18255d8557d9156981e715b55bfce10e41e4546447bb17173b5649dd0d1`.
Runtime: iPad Pro 11-inch (M4), iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`.

Runtime result: the opt-in path stayed alive and reached Village1, but logged
`transfers=11 primitives=0 submitted=0`; no Sky batch was actually encoded.
PCM telemetry remained nonzero later in the run, and no encoder/fault/SIGABRT
marker appeared.

Fresh frame remains malformed with large black regions and debug rectangles:
`/tmp/ottsel-video/bot36-native-sky-product-2026-09-04.png`.

Result: OPEN. The queue/order seam is compiled but not visually validated. The
next falsifiable change is to retain and expose Sky's texture upload/state at
the Direct decode boundary; do not broaden the product trigger or claim Sky
support until `submitted>0` and a fresh frame improves without regressions.
