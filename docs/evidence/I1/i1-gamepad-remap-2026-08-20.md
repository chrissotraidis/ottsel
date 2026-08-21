# I1 gamepad remap ownership increment — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | I1 — input ownership and lifecycle |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream pin `641fb572e876750d8618434d9f7c1a531b43b366`; signed iPad executable SHA-256 `6c32b65f733f285315d8b78fc166bfa281d58690ec03353f859c15efe2e02863` |
| Before failure | The mobile shell handled gamepad add/remove but had no explicit `SDL_EVENT_GAMEPAD_REMAPPED` path; stale button/axis state could survive a mapping change. |
| Change | Added a platform-neutral selected-instance predicate, routed remap events through neutralization/release/reselection, and rejected sentinel/stale instance IDs. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; `goalc-test --gtest_filter='PlatformInput.*:ARM64EmitterFloatMath.*:DirectFixture.*:Sprite3Native.*'` — 12/12 passed. `scripts/build-ios.sh` completed; strict codesign passed. |
| Live/device proof | No remap hardware was available in this environment; no physical controller acceptance is claimed. |
| Simulator boundary | The blank Simulator cannot prove controller ergonomics or remap behavior; no visual/audio/playability claim is made. |
| Verdict | OPEN — remap ownership behavior is source/regression/build verified; hardware remap/reconnect acceptance remains open. |
| Next gate | Return to R1 Metal startup/Sprite3 parity, while preserving I1 hardware acceptance as a separate requirement. |
