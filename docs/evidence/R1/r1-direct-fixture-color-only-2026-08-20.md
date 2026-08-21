# R1 — generated Direct color-only pass still aborts (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `599ae156eea811f9e33abb204effd35beec57f3c8c3f1a6e74df07b70e835154` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated local user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` |
| Before failure | The no-depth Direct-only pass still used a generated texture, sampler, and textured fragment shader. The remaining falsifiable split was color-only geometry on the same drawable. |
| Change | Added a trigger-scoped solid-color Direct fragment/pipeline, `ottsel-trace-metal-direct-fixture-color-only`, that retains the generated vertex buffer and drawable but binds no texture or sampler. It also isolates the pass and omits depth. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18. `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | Unified log at `2026-08-20 10:32:57.539` recorded `Direct color-only draw contract draws=1 triangles=2 depth=disabled final-target=same-pass`. At `10:32:57.544`, Metal again aborted with `MTLCommandBufferErrorDomain error 1`; at `10:32:58.618`, the SimMetalHost XPC service was lost. |
| Fault scan | `ottsel-fault.log` remained 0 bytes. The Simulator was blank/non-audible and shut down after the replay. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Verdict | OPEN / EXTERNALLY BLOCKED at the drawable/Metal execution boundary — the same failure occurs with no depth resource/state and no texture/sampler, so those product-side contracts are not the immediate cause. |
| Next gate | Preserve the no-depth/color-only discriminator and inspect the remaining CAMetalLayer drawable/present ownership and Simulator service boundary before changing renderer semantics. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
