# R1 — corrected Direct offscreen replay still aborts (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `03a61151492afa0ea3c515999cea10d641443dfaa772bb76c74fa30f555bc754` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; freshly installed app with validated local user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` |
| Before failure | The prior offscreen/color-only observation needed a clean replay after auditing and correcting an extra closing brace in the diagnostic Metal shader string. |
| Change | Corrected the `kDirectFixtureShaderSource` string, rebuilt the signed app, copied the validated pack into the fresh app container, and replayed `ottsel-trace-metal-direct-fixture` plus `ottsel-trace-metal-direct-fixture-offscreen`. No product renderer state changed. |
| Focused proof | Focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18; `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | Runtime accepted the generated fixture with `cpu-raster=0`. Unified log at `2026-08-20 10:52:01.632` recorded the corrected color-only/no-depth offscreen draw. At `10:52:01.634`, Metal aborted with `MTLCommandBufferErrorDomain Code=1`; completion status was `5`; at `10:52:01.738`, SimMetalHost disconnected. |
| Fault scan | `ottsel-fault.log` remained 0 bytes. The Simulator was blank/non-audible and shut down after the replay. No screenshot, PPM, visual, audio-quality, or playability claim. The unactivated no-buffer trigger was removed from the app container and produced no evidence. |
| Verdict | OPEN / EXTERNALLY BLOCKED — the corrected shader and validated data path reproduce the same offscreen command-buffer failure without presenting a CAMetalLayer drawable. The next experiment remains a reliable no-vertex-buffer draw or equivalent native Metal command validation, not a product semantic change. |
| Next gate | Add the no-vertex-buffer `vertex_id` triangle only after the fresh-pack activation path is retained, then classify custom vertex-buffer/layout versus the Simulator Metal execution boundary. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
