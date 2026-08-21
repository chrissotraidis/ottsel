# R1 Direct fixture GPU readback — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 / Direct native-Metal submission discriminator |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app Mach-O SHA-256 `c4228d159cc58fbb546457ccf2ddd79a0d0d3686edb584f7eadefb2d5deb235b` |
| Environment | iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; Metal API validation enabled; one runtime |
| Before failure | The prior normal drawable replay proved one Direct draw and two triangles but could not distinguish a blank drawable from a blank Simulator surface. The first readback attempt correctly failed validation because CAMetalLayer drawables were `framebufferOnly`. |
| Change | Added a trigger-scoped, one-shot drawable readback. The layer is made copyable only when `ottsel-dump-direct-fixture-metal` is pre-seeded; normal presentation remains framebuffer-only. The readback is diagnostic-only and never feeds the product frame path. |
| Focused proof | `goalc-test --gtest_filter='DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*'`: 18/18 passed. `codesign --verify --deep --strict`: passed. `git diff --check`: passed. |
| Live proof | Fresh validated user pack; trigger-scoped START/Cross, Direct trace, and readback. Logs: `Direct fixture active=1 texture=2x2 rect=0.375,0.375 0.250x0.250`; `Direct draw contract draws=1 triangles=2 ... final-target=same-pass`. PPM `1210x834`, SHA-256 `12ea11720626870e86b22c924dd61b823c52b1548da932fd25d26c482442a3e8`; expected fixture rectangle contained 31,408 red and 31,408 black pixels. |
| Fault scan | `ottsel-fault.log` was zero bytes. No Metal validation error, command-buffer abort, or XPC interruption occurred in the corrected replay. The Simulator remained blank/non-audible. |
| Verdict | OPEN / partial R1 GPU image evidence. This proves a non-clear native drawable region for the synthetic fixture, not title/menu composition, audio, playability, iPhone parity, or physical-device readiness. |
| Next gate | R1: compare this isolated native image contract with the macOS reference, then remove or keep the bounded probe according to the first unambiguous renderer mismatch. |

The PPM and user pack remain local Simulator/runtime artifacts and are not repository inputs.
