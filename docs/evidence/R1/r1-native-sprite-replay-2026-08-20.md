# R1 native Sprite3 replay — 2026-08-20

## Result

This is a stable diagnostic reproduction of the current mobile Sprite3 phase;
it does not pass R1. A clean normal-Metal iPad Simulator launch reached the
Village1 runtime, accepted the bounded file-trigger route, and selected a
native Sprite3 candidate without a fault, but the selected texture phase still
does not match the fresh macOS reference.

## Evidence

| Field | Result |
|---|---|
| Runtime | One signed `OttselShell.app`, iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; Simulator shut down after the replay |
| Build | `2460f9b20a133e3ce5e296d5d6da450b2cd384c3f02f179511b2837b2717f566` |
| Data | Host-validated local user pack `/tmp/ottsel-user-pack-real.HGuXcA`; no protected data was added to the repository or bundle |
| Route/liveness | Village1 FR3 camera records continued after the bounded Start/Cross/four-Down/Cross route; fault log remained 0 bytes |
| Native candidate | Group 0/index 2, `tbp=0x2bc1`, PSM 19, 64×64, bounds `(0.975,0.560)..(1.265,0.864)`, usable in the bounded clip test |
| Native state | Source-over blend, GEQUAL/2 alpha test, color alpha `0.8448`, texture alpha max `128`, `2,615` nonzero-alpha texels, CPU raster skipped after native upload |
| Readback state | `texture=64x64`; the diagnostic present-state recorded `pendingSprite=1` but no visual acceptance is claimed |
| macOS comparison | The fresh Village1 reference group remains `tbp=0x24f2`, 64×64, blend 2, ztest 2, zwrite false, alpha-test 2, aref 0.000 |

## Interpretation

The route and native upload are repeatable, and the zero-byte fault log removes
the earlier DGO/startup ambiguity for this slice. The mobile candidate is still
from a different texture phase (`0x2bc1` versus `0x24f2`), so the compatible
state shape is not enough to justify changing alpha, depth, or blend semantics.
The remaining R1 dependency is deterministic Sprite3 bucket/texture-phase
attribution and a matching macOS/mobile record comparison. The Simulator was
blank and non-audible; the PPM/present files are diagnostic only.

## Next falsifiable slice

Retain bounded Sprite3 records by bucket, texture, and state tuple, then compare
one identified mobile record against the same-phase macOS group before widening
the native batch or changing shader policy. Keep the one-runtime/one-Simulator
rule and do not call this visual parity or mobile playability.

No MAP_JIT, runtime executable page, dynamic trampoline, external Metal shell,
or protected game data was imported.
