# R1 in-bounds native Sprite3 candidate — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 — native Sprite3 route/parity discriminator |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app Mach-O SHA-256 `c4228d159cc58fbb546457ccf2ddd79a0d0d3686edb584f7eadefb2d5deb235b` |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated pack imported before Metal; readback trigger pre-seeded |
| Before failure | The first real native Sprite3 probe selected an edge-of-screen quad, so its readback could not establish a visible candidate. |
| Change | No product source change. Used the existing `ottsel-bg-village1` route trigger and armed the native Sprite3/readback probes after staging the validated pack. |
| Focused proof | Existing Direct/Sprite/input/compiler suite: 18/18 passed; strict codesign and `git diff --check` passed. |
| Live proof | Native group 0/index 0 accepted texture `0x2bc1` (64×64), `blend=enabled`, `alpha-test=gequal/2`, CPU raster skipped, bounds `(0.437,0.484)..(0.618,0.789)`, uploaded alpha `0.8448`, texture alpha max 128, and 2,615 nonzero-alpha texels. The 1210×834 drawable readback SHA-256 was `fd738d399eafc55a4d8f5726eed1ecf0069d7a7a4e09f1e16f48451b357a488b`; its candidate rectangle contained 8,605 non-clear pixels. |
| Fault scan | `ottsel-fault.log` was 1,395 bytes. The requested `village1.DGO` was absent from the staged user pack and the bounded run faulted later; therefore this is not a clean Village1 or playability replay. |
| Verdict | OPEN / useful native Sprite3 image/liveness discriminator, not a pass. It establishes a meaningful in-bounds real candidate and its native state tuple, but same-phase macOS tuple parity and clean fault-free route completion remain open. |
| Next gate | Reconcile texture `0x2bc1` and the full alpha/blend/depth tuple against a macOS Sprite3 record from the same title phase; separately close the missing generated/scene DGO route dependency before calling it Village1 proof. |

The PPM, pack, and runtime/fault logs remain local artifacts.
