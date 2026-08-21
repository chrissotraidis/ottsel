# R1 camera-only signature correlation — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 producer/frame-state attribution before native composition |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed mobile executable `25676a54936e0bf18bcde5308bf5c49c9f945b96eb0b84cbe8cb13dd8c63634b` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one run; shut down after capture |
| Before failure | Full Sprite3 frame hashes alternated, which was insufficient to establish camera-frame identity because the payload includes TBP/GIF/state fields. |
| Change | Added a separate camera-only frame signature over the camera-derived Sprite3 fields: HMGE scale, fog/area constants, basis vectors, inverse HMGE scale, and fog bounds. Full payload and matrix hashes remain diagnostic context. |
| Focused proof | `scripts/build-ios.sh` completed and strict signing passed. `./build/h1/goalc-test --gtest_filter='Sprite3Native.*'` passed 14/14 from the current test binary. |
| Live proof | Village1 `display-self` was reached. Chains 255–257 had alternating full frame hashes `0xff7e…`, `0xd731…`, `0xff7e…` but the same camera-only frame hash `0x6137bebdf6d07123`, identical camera-derived values, and matrix `0x94d1…`. Chain 258 retained the same camera-only frame hash while the PC camera packet changed to `trans=(-659084.9,235454.02,677712.3)` and the matrix changed to `0x879e…`. Transfer order remained 9 → 12 → 13; first resource remained `TBP=0x2bc1`. |
| Verdict | OPEN, corrected and narrowed. The prior stale-matrix interpretation is falsified: full payload variation was non-camera state, while the camera-only signature remained stable; the matrix changed with a changed PC camera packet. No producer phase-pair regression, matrix reuse, matrix swap, camera sign, TBP remap, or visibility-policy change is justified by this evidence. |
| Next gate | Return R1 to the first proven resource/phase divergence: compare the mobile first `TBP=0x2bc1` group and its native texture lookup against the desktop first `TBP=0x24f2` world draw, with a source-item/texture identity discriminator before any remap. |

The Simulator remained blank and non-audible. This evidence does not establish visual parity, audio, playability, iPhone parity, or physical-device readiness.
