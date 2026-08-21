# R1 — TIE queue, trigger lookup, and Sprite3 transform boundary

## Result

**OPEN — meaningful renderer progress, but no Sprite3 native-draw or R1 pass.**

This replay used app executable SHA-256
`955f4aa161b1c9ee7a0675f425341c8d99eb8ebe4adcfb2e667f073093936383` and
the focused `DirectFixture.*` regression remained 6/6. It was a single bounded
iPad Pro 11-inch (M4) Simulator run with no concurrent host `gk` or Ottsel
runtime.

## Changes exercised

- Direct texture pages are copied into a keyed presentation-thread queue and
  drained at most eight per frame, avoiding the previous boot-thread burst.
- TIE texture uploads use the same bounded queue and presentation-thread drain.
- Diagnostic trigger files resolve from the writable app directory before the
  bundle, so an installed Simulator app can consume the trigger without a
  bundle mutation.

## Observed trace

The fresh replay reached the Sprite3 bucket-66 consumer and emitted the
expected payload shape:

```text
frame transfer=9 size=656 imm=0x3d4
matrix transfer=12 size=80 imm=0x384
header transfer=13 count=48
payload vectors=2304 adgif=3840 run-vif=0x14000003
```

The native candidate ledger then rejected the bounded candidates. Representative
entries were:

```text
candidate=0 index=0 bounds=(-1.091,0.095)..(3.485,7.844) usable=false
candidate=1 index=1 bounds=(-1.709,0.919)..(4.103,7.020) usable=false
candidate=2 index=2 bounds=(-0.044,2.314)..(2.438,5.624) usable=false
```

All observed candidates were outside the full clip-space rectangle. No
`native group=...` or `cpu-raster=skipped-for-native-candidate` line was
observed, so native Sprite3 ownership remains unproven. The late bounded run
ended in the known Simulator drawable-host failure (`MTLSimDevice
newTextureWithDescriptor` / `CAMetalLayer nextDrawable` / `SimMetalHost` XPC
loss), not in a Sprite3 parser assertion or a product-frame proof.

Screenshot: `r1-tie-queue-trigger-replay-2026-08-20.png`.

## Follow-up transform trace

The maintained desktop shader was checked before changing the expansion. Its
`sprite_transform2` path uses `transformed_pos = -matrix_transform(camera,
pos)` before calculating `Q`; the current shell expansion had been using the
unnegated camera result. A diagnostic log now records both values for the first
Sprite3 vector, without changing the native probe or CPU fallback. The focused
6/6 regression and signed build pass for executable SHA-256
`b0454ee3f0125fcf7605c7e270b5e022f55fbd18b3a8c67aa6158bb4f16780f3`.
This sign hypothesis is not yet live-validated.

## Next falsifiable increment

Reconcile `sprite_shader_clip_vertex` and the preceding CPU expansion against
the maintained desktop `sprite3_3d.vert` order, especially the perspective
factor, HVDF offset, and final 2048/256/128/scissor adjustment. Add a focused
trace or regression that exposes the first divergent transformed vertex before
changing the native eligibility gate. Do not claim R1 until a selected native
quad is visually attributable and the CPU-skip line is captured in a clean
replay.
