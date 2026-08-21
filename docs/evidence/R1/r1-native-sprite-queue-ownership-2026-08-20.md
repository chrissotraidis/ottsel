# R1 — native Sprite3 queue and CPU ownership proof

## Result

**PARTIAL — native Sprite3 ownership is now live-proven for one bounded
candidate; visual parity and R1 completion remain open.**

The signed Simulator executable SHA-256 was
`321ed5af0d91d749c92bc11f683eb977da6850ad05ff7406fe631e52f162decf`. The
focused `DirectFixture.*` regression passed 6/6 before the build. This was one
Simulator runtime; it later terminated at the known drawable-host failure and
the Simulator is now shutdown.

## Live ownership trace

The corrected post-divide conversion and visible-intersection gate selected a
partially clipped candidate:

```text
candidate=2 index=2 bounds=(0.975,0.561)..(1.265,0.864)
size=(0.289,0.304) visible=(0.025,0.304) usable=true
native group=0 index=2 bounds=(0.975,0.559)..(1.264,0.862)
texture=0x2bc1 size=64x64 blend=enabled
cpu-raster=skipped-for-native-candidate
native visibility color-alpha=0.8448 texture-alpha-max=128 texture-alpha-nonzero=2615
```

The CPU fallback was therefore not used for this selected candidate, and the
native upload was accepted from the bounded Sprite3 path. This is stronger
than compile or parser evidence, but it is not yet a product-frame proof: no
same-phase A/B image diff or attributable screenshot was captured before the
late `CAMetalLayer nextDrawable` / `SimMetalHost` XPC failure.

## Remaining R1 work

Capture the same phase with a stable drawable, compare the native quad against
the desktop/CPU reference, and repeat after route/lifecycle transitions. Keep
the trigger gate and preserve CPU fallback for all rejected records until that
visual comparison passes.
