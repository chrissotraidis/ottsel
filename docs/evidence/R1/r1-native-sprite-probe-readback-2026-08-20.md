# R1 real Sprite3 native probe — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 — native Sprite3 comparison after D0 attribution |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app Mach-O SHA-256 `c4228d159cc58fbb546457ccf2ddd79a0d0d3686edb584f7eadefb2d5deb235b` |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1`; Metal API validation enabled |
| Before failure | The native Sprite3 seam existed, but no fresh real title/Village1 group had been accepted with CPU raster skipped and a drawable artifact. |
| Change | No product source change. Pre-seeded the real mobile Direct/Sprite trace and one-shot native-sprite readback triggers on the validated user-pack route. |
| Focused proof | Existing focused Direct/Sprite/input/compiler suite remained green at 18/18; strict signing and diff checks remained green. |
| Live proof | Runtime accepted the native Sprite3 probe and logged group 0, index 2, texture `0x2bc1`, 64×64, `blend=enabled`, `alpha-test=gequal/2`, CPU raster skipped; texture alpha max was 128 with 2,615 nonzero-alpha texels and uploaded alpha `0.8448`. The drawable readback was 1210×834, SHA-256 `5cecb44da9ff2647181c1f8040191a47b41dbac4f837fdead3f4c1f82e4b822e`, with 187,756 pixels different from the clear color. |
| Fault scan | `ottsel-fault.log` was zero bytes. No validation or command-buffer error was recorded in the retained runtime log. |
| Verdict | OPEN / native Sprite3 upload liveness only. The selected quad bounds were `(0.975,0.563)..(1.266,0.869)`, so it was mostly outside the drawable; the readback cannot establish that this Sprite3 was visibly composed. It is not playability, audio, iPhone, or device proof. |
| Next gate | R1: capture a real native Sprite3 candidate with meaningful in-bounds area and compare its full texture/state tuple against the same-phase macOS Sprite3 record before changing alpha/blend/depth mapping. |

The PPM, validated user pack, and runtime logs remain local artifacts.
