# R1 — generated Direct offscreen target still aborts (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `03a61151492afa0ea3c515999cea10d641443dfaa772bb76c74fa30f555bc754` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated local user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` |
| Before failure | The color-only Direct pass still rendered into the CAMetalLayer drawable and then failed; drawable/present ownership remained a possible boundary. |
| Change | Added a trigger-scoped offscreen target, `ottsel-trace-metal-direct-fixture-offscreen`, using a private BGRA8 render target with the same color-only Direct geometry, no depth, no texture/sampler, and no `presentDrawable` call. Completion status and error are logged. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18. `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | Unified log at `2026-08-20 10:37:37.862` recorded the offscreen color-only draw. At `10:37:37.867`, the command buffer aborted with `MTLCommandBufferErrorDomain Code=1`; the completion handler recorded `status=5`; at `10:37:37.967`, SimMetalHost disconnected. |
| Fault scan | The app fault log remained 0 bytes. The Simulator was blank/non-audible and shut down after the replay. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Verdict | OPEN / EXTERNALLY BLOCKED below drawable/present ownership — the same render-command failure occurs without presenting a CAMetalLayer drawable. The remaining bounded split is custom vertex-buffer/layout versus the Simulator Metal render execution boundary. |
| Next gate | Run a no-vertex-buffer `vertex_id` triangle against the same offscreen color target before changing product renderer semantics. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
