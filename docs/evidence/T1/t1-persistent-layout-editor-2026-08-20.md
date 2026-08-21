# T1 — persistent touch layout/editor increment — 2026-08-20

| Field | Result |
|---|---|
| Gate | T1 — visible customizable touch controls |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app executable SHA-256 `fbfc681045cdc2ffbf2ac3b209f68f613d4e6d6a9065e2b14a0f639acff3cd0f` |
| Before failure | The visible overlay used hard-coded geometry and touch hit regions; layout changes could not be made or retained. |
| Change | `src/shell/main.cpp` now uses one normalized layout model for overlay rendering and touch hit-testing, chooses separate tablet/phone files, validates and loads persisted geometry/opacity, and exposes a double-tap-on-Start or F6 editor mode that drags a region, adjusts opacity with `[`/`]`, and saves on release/cancel. |
| Focused proof | `out/jak-project/build/h1/goalc-test --gtest_filter='PlatformInput.*:DirectFixture.*'` — 8/8 passed; fresh iOS build and strict codesign passed; diff checks passed. |
| Live proof | Not yet captured. A Simulator replay must enter editor mode, drag one region, save, terminate/relaunch, and prove the same geometry plus simultaneous movement/action/camera and cancellation neutralization. |
| Fault scan | No new runtime claim made; no Simulator was left booted for this source/build checkpoint. |
| Verdict | OPEN — source/build increment only; no T1 acceptance claim. |
| Next gate | One iPad Simulator replay of F6 editor, persistence, multitouch, cancellation, and lifecycle neutralization. |
