# T1 touch-region mapping increment — 2026-08-20

| Field | Result |
|---|---|
| Gate | T1 — visible customizable touch controls |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app executable SHA-256 `ac24b48f4f08aa29250c354cc2d84f5bfb62077639945c02b946870378234815` |
| Before failure | The first visible overlay was decorative: all non-left touches mapped to Cross, so face/Start/shoulder/camera visuals did not correspond to their displayed actions. |
| Change | `src/shell/main.cpp` adds per-finger action/camera ownership and maps top bars to L1/Start/R1, face regions to canonical Square/Circle/Triangle/Cross, and the camera gesture region to the right stick. Each finger-up/cancel returns its owned button or axis to neutral. |
| Focused proof | iOS build/sign succeeded; `DirectFixture.*` — 6/6 passed; patch reverse-apply and `git diff --check` passed. |
| Live proof | Updated bundle reached the foreground after a clean Simulator reset and showed the mapped overlay over the Nintendo title in `T1-touch-overlay-mapped-2026-08-20.png`. |
| Fault scan | The app later hit the known broad title texture-upload boundary: `SimMetalHost` XPC loss from `uploadDirectTexture`, not from the touch mapping. No direct multitouch event trace was obtained in this run. |
| Verdict | OPEN — region ownership is implemented and the updated overlay is visible, but simultaneous movement/action/camera, finger cancellation, editor/menu cancellation, and lifecycle-neutral live traces remain open. |
| Next gate | T1 — add persisted layout state and an editor gesture/commit/cancel path after the renderer-host crash boundary is isolated. |
