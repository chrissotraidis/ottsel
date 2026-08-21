# R1 — isolated generated Direct submission still aborts (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `279d9c2b047841dfee049ab5f0bb5285a608a5af0b311032063f9624d2b0a35b` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated local user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` |
| Before failure | The normal generated Direct fixture pass included unrelated log/TFRAG/TIE/Sprite3 resources and aborted with `MTLCommandBufferErrorDomain error 1`; the failing resource class was not isolated. |
| Change | Added a trigger-scoped diagnostic mode, `ottsel-trace-metal-direct-fixture-isolated`, that skips the generic log triangle, TFRAG/TIE meshes, and Sprite3 draw while retaining the existing drawable, depth attachment, Direct pipeline, generated 2x2 texture, and Direct draw contract. Normal composition is unchanged when the trigger is absent. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18. `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | Unified log at `2026-08-20 10:22:13.124` recorded `Direct fixture isolated submission enabled` followed by `draws=1 triangles=2 ... depth=gequal/write ... final-target=same-pass`. At `10:22:13.494`, the command buffer aborted with `MTLCommandBufferErrorDomain error 1`; at `10:22:14.558`, the SimMetalHost XPC service was lost. |
| Fault scan | `ottsel-fault.log` remained 0 bytes. The Simulator was blank/non-audible and shut down after the replay. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Verdict | OPEN / EXTERNALLY BLOCKED — the failure reproduces with only the generated Direct draw in the pass, so queued scene resources are not the immediate cause. This still does not identify a product-side state defect or justify changing Sprite3 depth semantics. |
| Next gate | Keep the isolated fixture as the command-buffer discriminator and inspect the remaining native pass contract/resource lifetime (drawable/depth/pipeline/texture ownership) before widening product rendering. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
