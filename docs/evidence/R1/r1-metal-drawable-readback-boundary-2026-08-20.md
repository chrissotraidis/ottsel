# R1 Metal drawable readback boundary — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `3799da32af87f02baf0a8208b6130efe2a8f0afa72c82c7234d22219c43b11d6`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The Simulator surface is blank, so native Sprite3 image output could not be inspected from the UI. Logs proved state binding but not drawable pixels. |
| Change | Added a one-shot `ottsel-dump-native-sprite-metal` trigger that blits the actual composed drawable into a shared buffer and writes a diagnostic PPM after command completion. It does not publish `g_frame`, feed `OttselRaster`, or alter product presentation. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep codesign verification passed; `git diff --check` passed. |
| Live proof | A clean base-present replay without Sprite3/Village1 triggers produced a `1210x834` PPM from the actual Metal drawable; inspection shows the shell text rendered on the GPU surface. A later targeted Sprite3-gated replay reached candidate 0, created the `64x64` native resource, and produced a fresh PPM containing the yellow Sprite3 flare over the shell text. |
| Host result | The targeted attempt remains an open drawable/resource boundary; the prior `SimMetalHost-2026-08-20-072749.ips` report is `EXC_BAD_ACCESS` with `MTLSimApplicationContext::newIOSurfaceTexture`. The generic PPM proves readback/present works in isolation, not that Sprite3 pixels are blank. |
| Simulator boundary | Simulator remained blank/non-audible and was shut down. The temporary readback trigger was removed. No visual, audio, or playability claim is made. |
| Verdict | OPEN / PARTIAL — generic and Sprite3-gated GPU readback both work; native Sprite3 pixels are now observed, but parity and product-route completion remain open. |
| Next gate | Isolate the drawable-host/resource lifetime failure with a minimal no-Sprite readback or bounded present replay before changing Sprite3 composition again. |
