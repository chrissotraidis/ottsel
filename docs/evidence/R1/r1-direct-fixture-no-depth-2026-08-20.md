# R1 — generated Direct no-depth pass still aborts (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `828d6227cebecf5b2ee7e8bd407b85ba0a6dd520c4187fa89f7ef1ea65bdf649` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated local user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` |
| Before failure | The isolated Direct-only pass still used the depth attachment, depth state, and depth-format pipeline. The prior abort therefore left depth compatibility as a falsifiable remaining discriminator. |
| Change | Added a trigger-scoped no-depth pipeline/pass, `ottsel-trace-metal-direct-fixture-no-depth`, using the same generated Direct vertices, 2x2 texture, sampler, drawable, and Direct shader but no depth attachment or depth state. The trigger also isolates the pass from the generic log/TFRAG/TIE/Sprite3 draws. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18. `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | Unified log at `2026-08-20 10:27:06.775` recorded `Direct fixture no-depth submission enabled` and `Direct no-depth draw contract draws=1 triangles=2 depth=disabled final-target=same-pass`. At `10:27:06.780`, Metal again aborted with `MTLCommandBufferErrorDomain error 1`; at `10:27:07.889`, the SimMetalHost XPC service was lost. |
| Fault scan | `ottsel-fault.log` remained 0 bytes and no fresh `SimMetalHost` diagnostic report was created. The Simulator was blank/non-audible and shut down after the replay. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Verdict | OPEN / EXTERNALLY BLOCKED below depth-state compatibility — the same failure occurs with no depth resource or depth state, so depth is not the immediate cause. The remaining bounded suspects are the drawable/pipeline/texture submission or Simulator Metal execution boundary. |
| Next gate | Keep the no-depth discriminator and isolate the remaining color/texture submission contract (generated texture versus shader/drawable) before changing product renderer semantics. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
