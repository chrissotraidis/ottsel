# I1 Sky native-capture boundary — 2026-09-04

Question: does the opt-in native Sky product walk reach decoded primitives, or
does it fail earlier at the bucket/GIF boundary?

Change: add bounded counters to `OttselGifDecoder` for native-capture primitive
candidates, rejection, texture misses, PRIM starts, and XYZ vertex words. The
product walk temporarily enables the existing direct/GIF counters and restores
their state afterward. No camera, depth, topology, texture, or draw behavior
was changed by this experiment.

Build: `scripts/build-ios.sh` completed and ad-hoc signed the iPad Simulator
app. The app was installed/launched on UDID
`08636791-2675-4675-8335-EF72EF954DCF`; the runtime was then terminated.

Observed in a fresh Village1 run:

`OTTSEL SKY PRODUCT: transfers=11 direct-transfers=6 gif-tags=24
prim-starts=0 vertex-words=0 candidates=0 rejected=0 texture-misses=0
primitives=0 submitted=0 end=0x50a180 expected=0x50a180`

Result: OPEN. The Sky bucket is reached and contains six DIRECT transfers and
24 GIF tags, but this product walk never reaches PRIM/XYZ decoding. Do not add
a fake sky texture or gradient. Next: compare the exact bucket-start/data
address and GIF tag forms against the existing `SKY IR` trace, then implement
only the missing upstream Sky generated-texture/copy contract once source
evidence identifies it. The overall iPad frame remains malformed and Jak is
not visible/controllable; no playability claim is made.
