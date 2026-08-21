# R1 native Sprite3 fragment state live binding — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `3fe8861531e8400c6da1eeaf6404b98bb816fb85bd6d12b5686eef2a2c6339b2`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The alpha/blend fixture was only a CPU oracle, and the Objective-C++ `NSLog` at the encoder boundary was not retained in the runtime log after shutdown. |
| Change | Added a runtime log at the native Sprite3 upload producer carrying the exact state contract passed to Metal: `alpha-test=gequal/2` and `blend=source-over`. No renderer behavior was changed in this logging slice. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep codesign verification passed; `git diff --check` passed. |
| Live proof | One fresh signed replay reached candidate 0 with finite visible bounds, texture `0x2bc1` `64x64`, `uploaded-alpha=0.8448`, `cpu-raster=skipped-for-native-candidate`, and runtime log `alpha-test=gequal/2 blend=source-over`. |
| Fault scan | `ottsel-fault.log` was 0 bytes. No `BOOT FAILED` marker appeared in the bounded scan. |
| Simulator boundary | The Simulator remained blank and non-audible and was shut down. This proves live state binding/liveness only, not fragment output, screenshot parity, audio, or playability. |
| Verdict | OPEN — native state binding is now live-observable and matches the ROM-free oracle; actual Metal discard/blend output and final image parity remain open. |
| Next gate | Capture an attributable native frame or add a Metal-side validation/readback fixture for the selected Sprite3 quad without treating the blank Simulator as visual proof. |

