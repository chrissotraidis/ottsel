# R1 native Sprite3 GPU repeatability — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; same signed marker/readback executable; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | One native Sprite3 GPU artifact had been captured, but deterministic repeatability had not been established. |
| Change | No product-source change in this slice. Repeated the same trigger-isolated route with the same signed executable and fresh app install. |
| Focused proof | Existing focused Sprite3 suite remained green; `git diff --check` passed. |
| Live proof | The second replay reached the same bounds, texture `0x2bc1` `64x64`, normalized alpha `0.8448`, alpha/blend state, and CPU-raster skip. Its converted 1210×834 PNG SHA-256 was `8255efdb30078193fafeed9dea4d762eb86d25d1c5e08e45c202e7a09ce0bdc1`, byte-identical to the first artifact. |
| Fault scan | `ottsel-fault.log` was 0 bytes. Temporary marker/trigger files were removed. |
| Simulator boundary | Simulator UI remained blank/non-audible and was shut down. The deterministic artifact is direct GPU drawable evidence, not audio or playability proof. |
| Verdict | OPEN / PARTIAL R1 — native Sprite3 output is repeatable for the selected diagnostic candidate; macOS parity, broader bucket coverage, and normal untoggled product behavior remain open. |
| Next gate | Capture a same-phase macOS/fixture reference and compare image/state contracts before widening the native Sprite3 consumer. |

