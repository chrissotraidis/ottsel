# T1 visible overlay increment — 2026-08-20

| Field | Result |
|---|---|
| Gate | T1 — visible customizable touch controls |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app executable SHA-256 `e0ad8db2ee58d5b0911939231c5a9197a6072e05abbbc5cea8fe0a367ee44ff0` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, drawable 1210x834 |
| Before failure | The touch bridge was invisible; the first overlay attempt crashed during launch-time Metal buffer allocation with a `METAL` `SimMetalHost` XPC abort in `setTouchOverlay:count:`. |
| Change | `src/shell/main.cpp` defers the static overlay's one-time shared-buffer upload until after 60 presented frames. `src/shell/metal_shell.mm` draws the uploaded geometry as a final blended pass above TFRAG/TIE/Direct/Sprite. |
| Focused proof | `out/jak-project/build/h1/goalc-test --gtest_filter='DirectFixture.*'` — 6/6 passed; `git diff --check`; D2/D3 patch reverse-apply checks passed. |
| Live proof | One booted Simulator, app opened through the Simulator UI, foreground screenshot captured at `T1-touch-overlay-visible-2026-08-20.png`, then a later scene screenshot at `T1-touch-overlay-scene-2026-08-20.png`. Both show visible left movement controls, right face/shoulder controls, Start, and the rendered app scene. |
| Fault scan | No new `OttselShell` crash report was created after the clean shutdown/boot and deferred-upload replay. Earlier launch-time Metal aborts are preserved in the host diagnostic reports and are not counted as a clean run. |
| Verdict | OPEN — visible static overlay proven; customizable editing, persistence, accessibility, phone layout, simultaneous input, cancellation, and lifecycle neutralization remain unproven. |
| Next gate | T1 — add a small persisted layout model and an editor/cancel path without changing the shared `ShellPadInput` authority. |

The screenshots are product evidence only for the visible-overlay increment; they
do not establish iPad playability or a complete T1 pass.
