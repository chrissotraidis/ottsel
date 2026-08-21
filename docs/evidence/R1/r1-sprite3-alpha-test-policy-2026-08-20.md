# R1 Sprite3 primary alpha-test policy — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `60385b1e0f9e751debef438e6501c416f981c957ad6a3e2a157f441064e87fd6`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The native Sprite3 draw reused the Direct fragment state with `alpha_test_enable=0`. The maintained desktop Sprite3 primary pass uses GEQUAL alpha testing and a small `0.016` threshold before its blended draw. |
| Change | Added shared policy constants and a regression for enabled/GEQUAL/`AREF=2` (`2/128=0.015625`), then passed those values into the native Sprite3 fragment state. The existing blended pipeline and no-depth-write state remain unchanged. |
| Focused proof | Rebuilt `goalc-test`; `goalc-test --gtest_filter='Sprite3Native.*'` passed 6/6. `scripts/build-ios.sh` completed and strict deep codesign verification passed. |
| Live proof | One fresh signed replay reached the same finite candidate and native draw with normalized `uploaded-alpha=0.8448`, CPU raster skipped, and zero fault bytes. The alpha policy is source/test-proven; the current draw log does not expose the constant buffer fields, so no stronger fragment-discard/image claim is made. |
| Simulator boundary | The Simulator remained blank and non-audible and was shut down. No visual, audio, or playability claim is made. |
| Verdict | OPEN — primary alpha-test state is now wired and regression-covered, but final image visibility, actual discard behavior, blend equation, and broader Sprite3 parity remain open. |
| Next gate | Add a ROM-free native Sprite3 fragment-state fixture that exercises pass/reject alpha values and the blend contract before widening the live consumer. |

