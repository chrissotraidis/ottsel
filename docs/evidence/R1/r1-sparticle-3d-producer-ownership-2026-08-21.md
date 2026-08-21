# R1 3D particle producer ownership trace — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/phase ownership |
| Source/build identity | Outer checkout `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; maintained diagnostic patch `patches/r1-sparticle-3d-ownership.patch`; signed executable SHA-256 `d10eb47666a1f4f7468d11ac6919d10a647d4b74e448e581cf3d6ec51c718275` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `49E22B4A-E791-4EF1-994F-68A409DE8F24`; normal Metal; Simulator shut down after capture |
| Before failure | The earliest mobile Sprite3 window was world-only, while a later aggregate contained 64 3D sprites. It was unknown whether the mobile 3D particle source itself was empty. |
| Change | Added a diagnostic-only, 32-line-capped trace after `process-particles` updates `*sp-particle-system-3d*` and `*sprite-array-3d*`. It records only zero/nonzero states and does not alter particle or draw state. Regenerated `GAME.CGO`, rebuilt, and strictly signed the app. |
| Focused proof | GOAL regenerated all 338 targets; `scripts/build-ios.sh` completed; strict deep codesign passed. |
| Live proof | Fresh marker-synchronized route logged `start edge in title-wait` and `GAMEPLAY: enter village1` twice. After Village1, repeated producer lines reported `alloc-state="nonzero" valid-state="nonzero" blocks-state="nonzero"`. Delegated VSYNC remained active; `ottsel-fault.log` was 0 bytes. |
| Verdict | OPEN — mobile is producing 3D particle data, so the absent `MSCAL=211` in the earliest captured Sprite3 window is not explained by an empty source array. The remaining mismatch is DMA chain/bucket timing or phase ownership. The Simulator remained blank/non-audible. |
| Next gate | Add one trigger-gated producer/DMA chain identity at the `sprite-draw` boundary and correlate the first nonzero 3D-particle frame with the Sprite3 bucket containing `MSCAL=211`; do not change renderer/resource/camera policy yet. |

This is producer evidence only. It is not visual, audio, or iPad playability
acceptance.
