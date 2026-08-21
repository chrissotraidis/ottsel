# R1 Sprite3 projected-area alpha parity — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream worktree `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `0ba8afdb3dcbfb7398aece1dae9a8085d2ff8d692d7ad4dcc4ad2221fd60e282` |
| Before failure | The native Metal Sprite3 upload used vertex alpha directly, while maintained Jak 1 `sprite3_3d.vert` multiplies `fragment_color.w` by `min(sx * sy * inv_area, 1.0)` before its final color multiplier. |
| Change | Added ROM-free `ottsel::sprite3_faded_alpha` in `common/dma/ottsel_sprite_math.h`; the native Sprite3 upload now uses it for alpha. Added clamping regressions in `test/test_sprite3_native.cpp`. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; `goalc-test --gtest_filter='Sprite3Native.*:DirectFixture.*:PlatformInput.*'` — 10/10 passed. `scripts/build-ios.sh` completed and `codesign --verify --deep --strict` passed. |
| Live proof | A fresh iPad Pro 11-inch (M4), iOS 18.5 Simulator launch reached the 1210x834 Metal surface, then exited before the diagnostic Village1/Sprite3 phase. No Sprite3 fade line was emitted, so no live alpha value or visual result is claimed. |
| Fault scan | `ottsel-fault.log` was 0 bytes for the replay. |
| Simulator boundary | The Simulator remained blank/non-audible for this purpose; no rendered-content, audible, route, or playability conclusion is drawn. |
| Verdict | OPEN — source parity increment and regression are verified; live Sprite3 visual/A-B parity remains unproven. |
| Next gate | Re-run the trigger-gated Village1 Sprite3 phase after fixing the early-exit/route timing, then compare the native candidate against the desktop/CPU reference. |
