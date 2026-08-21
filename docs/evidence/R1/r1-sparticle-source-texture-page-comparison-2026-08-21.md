# R1 Sprite3 producer texture-page comparison — 2026-08-21

## Gate

Determine whether the first mobile/macOS resource divergence is visible at the
GOAL producer before DMA, without misreading the AdGif overlay fields as a
logical texture ID.

## Identity and environment

- Outer source: `3740d9b22d7409cbf2e128feeecfdb8ab3a8f9dd`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`, with the
  maintained `r1-sparticle-3d-ownership.patch` applied locally.
- Signed Simulator executable SHA-256:
  `05e1554bef9824d40a09e2e9a41dba56d76f40d6b45c785a959d7f425c677033`.
- Environment: one iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`, iOS 18.5; fresh validated external
  pack; normal Metal; Simulator stopped after capture.

## Before failure

The existing mobile AdGif trace proved that the native consumer preserves the
producer's selected TEX0, but the first producer trace needed a clear label for
the overlaid `prims[3]` field. That field is overwritten with the GS `TEX1`
register ID by `particle-setup-adgif`; it is not a logical texture ID.

## Change

Expanded the existing bounded GOAL-side 3D ownership trace in
`sparticle.gc` to report the first producer AdGif's `prims[3]` register field,
TBP, and dimensions.
The first attempt used integer formatting, which printed blank on iOS; that
diagnostic defect was corrected to the known-working floating-point formatter.
No particle, texture, DMA, renderer, or executable-memory behavior was
changed. The canonical patch was updated and reverse-apply validated.

## Focused proof

- ARM64 `(mi)` rebuilt all 546 GOAL targets successfully.
- `ninja -C build/h1 goalc-test` and `Sprite3Native.*` passed 16/16.
- `scripts/build-ios.sh` completed; strict deep code-signature verification
  passed.
- `git -C out/jak-project apply --check --reverse patches/r1-sparticle-3d-ownership.patch`
  passed.

## Live proof

The stable macOS producer trace reached the same Village1 route and reported:

```text
valid=128 first-prims3-reg=20 first-tbp=9458 first-size=64x64
```

That is the GS `TEX1` register ID `0x14`, TBP `0x24f2`, and the existing macOS
first-world AdGif/TEX0 `0x2004d1e59930a4f2`.

The fresh iPad route imported the validated pack, reached Village1, and
reported:

```text
valid=64.0000 first-prims3-reg=20.0000 first-tbp=11201.0000 first-size=64.0000x64.0000
```

That is the same overlaid GS register field, but TBP `0x2bc1` (`11201`) rather
than macOS TBP `0x24f2` (`9458`). The iPad route also reached the current-boot
`title-wait-ready` marker. The earlier native boundary trace remains the
exact hex confirmation that the iPad AdGif/TEX0 is `0x2005aa459930ab8d` for
this phase.

## Interpretation and verdict

**OPEN.** The producer emits different resource pages before DMA, but this
trace alone does not identify the logical texture lookup that selected them.
The earlier raw particle-ID → AdGif trace shows that the mobile and macOS
particle IDs/resources also differ. This keeps the first open dependency at
producer source/phase/resource selection; it does not justify a texture-page
remap, camera change, shader change, or native-consumer widening. The
Simulator render remained non-playable; this is producer/resource evidence
only.

## Next gate

Trace the raw particle texture IDs at the first stable 3D producer phase and
then the resolved texture `dest/width/height` inside the shared
`lookup-texture-by-id` / `adgif-shader<-texture!` path on macOS and iPad.
Compare page-directory identity and allocation order before changing any
renderer consumer or substituting a texture.
