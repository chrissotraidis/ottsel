# T1 — editor persistence diagnostic replay — 2026-08-20

| Field | Result |
|---|---|
| Gate | T1 — visible customizable touch controls |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `ec6dfc249bffff4cae2930d2ce44115329c6efd89ac9318f68a83a6990da59bf` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5; SDL diagnostic mode with Metal disabled; one runtime at a time |
| Before failure | The editor and persistence path had focused tests and source evidence, but no live runtime artifact showing an editor save followed by a process relaunch. |
| Change | `src/shell/main.cpp` installs the runtime file logger before calling `load_touch_layout()`, so a future reload can be directly observed without changing the touch state model. |
| Focused proof | `out/jak-project/build/h1/goalc-test --gtest_filter='PlatformInput.*:DirectFixture.*'` passed 8/8; fresh iOS build, strict codesign, and `git diff --check` passed. |
| Live proof | Computer Use entered editor mode through F6 on the signed diagnostic app. Typing `[` saved `touch-layout-tablet.cfg` with opacity `0.95` and logged `OTTSEL TOUCH: saved persistent layout`. After termination and relaunch, the 206-byte config remained in the same app container. The expected `loaded persistent layout` line was not captured, so runtime reload is not claimed. |
| Fault scan | `ottsel-fault.log` remained zero bytes; no product-mode or Metal evidence was used. |
| Verdict | OPEN — editor entry and durable save-file creation are live-proven; layout reload, drag geometry, simultaneous movement/action/camera, cancellation, accessibility, and normal-Metal product proof remain open. |
| Next gate | Capture the missing load record in a same-container relaunch, then exercise a real touch drag/cancel sequence before claiming T1. |
