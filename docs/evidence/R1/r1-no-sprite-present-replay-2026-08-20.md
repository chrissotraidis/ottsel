# R1 — no-Sprite normal-Metal present replay (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal startup/drawable liveness |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; existing clean signed app SHA-256 `bc10f91b8e97b684d491313c31d1a57ac994af86443e07ec490770deb9ff128f` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; normal Metal; one runtime at a time |
| Before failure | The latest Sprite3/game-route attempt aborted at the Simulator drawable/resource boundary, while prior generic readback proved only an isolated base present. |
| Change | No product source change. Installed the existing clean app, launched without Village1 or Sprite3 triggers, and placed the diagnostic readback marker in the runtime’s actual writable directory. |
| Focused proof | The launch emitted repeated `ottsel metal presentRGBA 1210x834 layer-drawable=1210x834` lines, retained a zero-byte `ottsel-fault.log`, and reached `OTTSEL AUDIO: output callback observed after 1024 frames`. The Sprite3 readback marker remained unconsumed because no Sprite3 resource became active. |
| Live proof | No screenshot, PPM, visual, audio-quality, or playability claim. The Simulator surface remains blank/non-audible; this replay measures only present-path liveness. |
| Fault scan | No new `OttselShell` or `SimMetalHost` diagnostic report was produced for the corrected no-Sprite replay; the app fault log was 0 bytes. The Simulator was shut down afterward. |
| Verdict | PASS for this bounded no-Sprite present liveness slice; OPEN for Sprite3/game-resource lifetime, R1 parity, and the product goal. The result narrows the known failure to the Sprite3/game-resource route but does not identify its root cause. |
| Next gate | Capture one matching iPad Sprite3 bucket/texture phase, then compare its full state/resource lifetime tuple against macOS before changing native batching or state mapping. |

The Jak 2 ARM64 report remains supplemental. No MAP_JIT, runtime executable
pages, external Metal shell, or Jak 2 game-specific source was imported.
