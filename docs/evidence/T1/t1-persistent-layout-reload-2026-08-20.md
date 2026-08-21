# T1 — persistent tablet layout reload (2026-08-20)

| Field | Result |
|---|---|
| Gate | T1 visible customizable touch controls |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app from the current clean build |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; SDL-only; one runtime at a time |
| Before failure | The prior editor replay proved config-file creation and container survival, but did not capture the expected `loaded persistent layout` line after relaunch. |
| Change | No product source change. Installed a valid version-1 tablet layout fixture in the app writable directory, launched SDL-only, terminated, and relaunched the same app/container. |
| Focused proof | Both launches logged `OTTSEL TOUCH: loaded persistent layout .../touch-layout-tablet.cfg`; the fixture passed the runtime’s version, opacity, finite geometry, minimum-size, and bounds validation. |
| Live proof | First launch loaded the fixture at `36:50`; relaunch loaded the same file at `37:12`. |
| Fault scan | `ottsel-fault.log` was 0 bytes on the relaunch run. The Simulator was shut down afterward. |
| Verdict | PASS for durable layout-file reload; OPEN for editor gesture commit, live drag geometry, simultaneous movement/action/camera, cancellation neutralization, accessibility, phone layout, and complete T1. |
| Next gate | T1 editor/multitouch replay: use the visible normal-Metal overlay when the host remains stable, exercise F6 or Start double-tap, drag one region, release/cancel, and verify the changed geometry plus neutral input. |

The Simulator remains blank/non-audible in SDL-only mode; this is persistence
and lifecycle evidence, not visual or playability proof.
