# R1 iOS graphics-sync delegation — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 — runtime producer timing before Sprite3 composition |
| Before failure | macOS `sceGsSyncV` delegates to `Gfx::vsync()`, while the iOS `ios_stubs.cpp` implementation returned immediately and never invoked the registered Metal renderer. `sceGsSyncPath` was also an unconditional no-op. |
| Change | Restored delegation from the iOS stubs to the registered renderer’s `vsync` and `sync_path` callbacks, retaining zero-return fallback when no renderer is registered. This is a platform-seam correction, not a Sprite3/TBP/renderer-policy change. |
| Focused proof | `scripts/build-ios.sh` completed and strict codesign passed. The signed executable SHA-256 is `aad4f9d9e5ddbca62bda3e13dd253c3ba84fb87f08fe27714c3665559df0eb67`. |
| Live proof | A fresh iPad Pro 11-inch (M4) Simulator launch reached the graphics path and logged `OTTSEL IOS VSYNC: call=1..8 mode=0 renderer-delegated=true` and call 60 with `renderer-delegated=true`. The registered Metal callback was therefore reached instead of the old stub-only path. |
| Fault scan | `ottsel-fault.log` was 0 bytes. No Simulator visual/audio pass is claimed; the surface remains blank/non-audible. |
| Verdict | OPEN. The shared graphics-sync callback contract is now restored and runtime-proven. The remaining R1 phase/resource divergence still requires a fresh same-transition Sprite3 capture with this synchronization change. |
| Next gate | Re-run the synchronized Village1 source/phase aggregate and compare whether phase order/resource ownership moves toward the macOS dispatch before considering any renderer change. |

The maintained patch is `patches/r1-ios-gfx-sync.patch`; it must remain applied
alongside the existing iOS substrate patch before further route comparisons.
