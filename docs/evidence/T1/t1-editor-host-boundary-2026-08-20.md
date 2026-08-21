# T1 — normal-Metal editor attempt hit Simulator host boundary (2026-08-20)

| Field | Result |
|---|---|
| Gate | T1 visible customizable touch controls |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; clean signed app hash `bc10f91b8e97b684d491313c31d1a57ac994af86443e07ec490770deb9ff128f` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; normal Metal; one runtime at a time |
| Before failure | The durable layout-file reload sub-gate passed, but no live editor gesture, multitouch, or cancellation trace had been captured. |
| Change | No product source change. Installed the clean signed app with the validated local user pack, launched the normal-Metal route, and attempted to reach the visible overlay/editor boundary. |
| Focused proof | The app reached the normal-Metal presentation path, then aborted while `CAMetalLayer nextDrawable` requested a simulator drawable texture. The crash report records `MTLSimulator_encountered_XPC_error` and `MTLSimDevice newTextureWithDescriptor:iosurface:plane:`. |
| Live proof | No editor gesture or screenshot is claimed. The Simulator returned to the home/black surface before interaction; the known blank/non-audible Simulator state remains the product-observation boundary. |
| Fault scan | `/Users/chrissotraidis/Library/Logs/DiagnosticReports/OttselShell-2026-08-20-093540.ips`: `EXC_CRASH`/`SIGABRT`, Metal termination code 102, `Connection to SimMetalHost ... XPC_ERROR_CONNECTION_INTERRUPTED`; the app fault log was not the source of this failure. |
| Verdict | OPEN for T1 editor/multitouch/cancellation; EXTERNALLY BLOCKED for this normal-Metal interaction attempt at the Simulator `SimMetalHost` drawable boundary. This is not T1 acceptance or playability proof. |
| Next gate | Keep one runtime and continue R1/T1 only with a stable drawable: first capture the selected Sprite3 bucket/texture phase against the macOS reference, then retry the visible editor gesture and cancellation replay when the host boundary permits it. |

The external Jak 2 ARM64 report remains supplemental: it does not change this
renderer/input dependency and no MAP_JIT, runtime executable memory, external
Metal shell, or Jak 2 game-specific change was imported.
