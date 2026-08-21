# R1 Sprite3 normalized alpha — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `f5b039994b086a9fc16cefd24eaa4a257cf9f4f1ca3e578f4b4d3683ef43bae9`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The macOS Sprite3 shader consumes normalized vector color. The native path divided the live `vector.rgba` values by 255 again; the prior live log showed `color-alpha=0.8448` becoming `uploaded-alpha=0.0033129`. |
| Change | Added a normalized-domain projected-area alpha helper and regression; native Sprite3 now clamps normalized RGB directly and applies normalized alpha fade without a second byte conversion. |
| Focused proof | Rebuilt `goalc-test`; `goalc-test --gtest_filter='Sprite3Native.*'` passed 5/5. `scripts/build-ios.sh` completed; strict deep codesign verification passed. |
| Live proof | One fresh trigger-isolated launch with the new signed executable repeated the finite candidate and native draw. The log now reports `color-alpha=0.8448`, `texture-alpha-max=128`, `area-fade=1`, `uploaded-alpha=0.8448`, `cpu-raster=skipped-for-native-candidate`, and a zero-byte fault log. |
| Simulator boundary | The Simulator remained blank and non-audible. No image, audio, or playability claim is made; it was shut down after the replay. |
| Verdict | OPEN — the native color/alpha upload now matches the normalized desktop shader domain for this candidate, but final image visibility, alpha-test/blend parity, and broader Sprite3 coverage remain unproven. |
| Next gate | Add a bounded native Sprite3 alpha-test/blend fixture or capture a same-phase desktop/native state comparison before widening the consumer. |

