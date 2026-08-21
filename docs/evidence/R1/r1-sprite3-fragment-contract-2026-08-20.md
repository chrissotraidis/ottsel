# R1 Sprite3 fragment contract fixture — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; current signed executable `60385b1e0f9e751debef438e6501c416f981c957ad6a3e2a157f441064e87fd6` |
| Before failure | The native Metal shader had no ROM-free executable contract test for the primary GEQUAL alpha boundary or its source-over RGB blend equation. |
| Change | Added shared pure contract helpers for the exact `AREF=2/128` pass/reject boundary and `Cs*As + Cd*(1-As)` RGB blend, with boundary tests. The Metal shader/state remains the product implementation; these tests are an oracle, not a substitute for GPU proof. |
| Focused proof | Rebuilt `goalc-test`; `goalc-test --gtest_filter='Sprite3Native.*'` passed 8/8. `git diff --check` passed. |
| Live proof | No new live run was counted for this CPU-only fixture slice; the preceding fresh signed replay remains the authoritative native-draw liveness result. |
| Fault scan | No runtime or package changes were introduced by the fixture-only addition. |
| Simulator boundary | No Simulator image/audio claim is made; the last Simulator remained blank/non-audible and was shut down. |
| Verdict | OPEN — the intended alpha/blend contract is now regression-covered, but the test does not prove Metal fragment output, discard behavior, or final image parity. |
| Next gate | Bind the fixture values to a native Metal validation path or capture a same-phase macOS/native state comparison without widening the Sprite3 route. |

