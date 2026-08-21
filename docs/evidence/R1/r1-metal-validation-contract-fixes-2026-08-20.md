# R1 — Metal validation contract fixes reach clean offscreen completion (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `5423c6f7ae8e4afee8ae7af99604aafbe309a9f54fe43fdac5d26326e637adad` |
| Before failure | Metal validation reported three concrete pass-contract defects: generic pipeline depth format `Invalid` versus framebuffer `Depth32Float`; explicit `setDepthStencilState:nil`; and the touch-overlay pipeline using a depth format while the isolated pass had no depth texture. |
| Change | Declared `Depth32Float` on the generic shell pipeline; omitted the no-depth diagnostic setter; added an `Always`/no-write overlay depth state; and excluded the touch overlay only from the trigger-scoped isolated pass. Normal product composition retains its existing scene/order and now binds valid Metal state. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18. `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | With `MTL_DEBUG_LAYER=1`, a fresh validated-pack replay accepted the generated fixture and repeatedly logged `Direct offscreen completion status=4 error=(null)`. No validation error, command-buffer error, or SimMetalHost interruption appeared during the bounded capture. |
| Fault scan | `ottsel-fault.log` was 0 bytes. The Simulator was blank/non-audible and shut down afterward. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Verdict | PARTIAL R1 PASS — the corrected native Metal pass/resource contract now completes in the offscreen diagnostic route under Metal API validation. This is not image parity or product playability proof. |
| Next gate | Replay the corrected generated Direct fixture into the real CAMetalLayer drawable/present path with validation enabled, then inspect native image/readback and normal scene ownership. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
