# R1 level-remap texture ledger — 2026-08-21

## Result

The bounded GOAL trace was added at `level-remap-texture`, preserving the
existing binary search and remap result. It records the original and returned
texture page/index without changing either value.

The current-checkout macOS replay and the fresh signed iPad replay both
reported the sampled page-2 remap as an identity:

```text
macOS: iPad:
in page=2 index=1   -> out page=2 index=1
in page=2 index=1   -> out page=2 index=1
```

The iPad replay used a freshly validated user pack, consumed
title-wait → Start → Cross → Down×4 → Cross, and reached Village1 twice. Its
post-route lookup records included resident hits at indices 24, 25, 10, 41,
0, 30, 34, and 9. The remap trace did not show a platform-specific table
result for those sampled page-2 entries.

## Boundary conclusion

This falsifies a differing `level-remap-texture` result as the explanation for
the observed raw 3D family divergence. The remaining source-side boundary is
particle/data-family selection and launch ordering after the remap path and
before AdGif/TEX0/native composition. No TBP, camera, shader, or Metal-policy
change was made.

Fresh iPad artifacts:

* Screenshot: `/tmp/ottsel-r1-remap-ledger-route.png`
* SHA-256: `262e7ffcba331159f5dd1bd901da77dd942c7174f9c5117cdb713481fb2718a5`
* Fault log: 0 bytes
* Audio: mix windows observed, `pcm-peak=0`

The screenshot remains a distorted/partial Simulator frame and is not
playability proof. The canonical diagnostic delta is
`patches/r1-level-remap-texture-trace.patch`; it reverse-checks against the
current nested source.
