# R1 combined 3D producer-to-DMA correlation — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/phase ownership |
| Source/build identity | Outer checkout `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; diagnostic patch `patches/r1-sparticle-3d-ownership.patch`; signed executable SHA-256 `d10eb47666a1f4f7468d11ac6919d10a647d4b74e448e581cf3d6ec51c718275` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `85483785-400D-4ABF-ADE3-672610BBE088`; normal Metal; Simulator shut down after capture |
| Before failure | The producer trace proved 3D particles existed, but separate runs had alternated between world-only and 3D-bearing Sprite3 windows. The same-boot producer-to-DMA correlation was still missing. |
| Change | No product-source change. After current-boot Village1 entry, armed both `ottsel-trace-mobile-sprite-frame-aggregate` and `ottsel-trace-mobile-sprite-source-boundary`. |
| Focused proof | Fresh route logged Start edge and Village1 entry twice; delegated VSYNC remained active; `ottsel-fault.log` was 0 bytes. |
| Live proof | GOAL producer lines reported `alloc-state="nonzero" valid-state="nonzero" blocks-state="nonzero"`. At VSYNC `1001`, chain `1000` emitted `MSCAL=211`, group 0, transfer 13, 48 sprites at `TBP=0x2b8d`, PSM 19, 64x64; transfer 14 was a 16-sprite zero-texture tail. The same chain then emitted `MSCAL=3`, transfer 15, 48 sprites at `TBP=0x2bc1`, followed by its zero-texture tail. The frame aggregate completed with `chains=1 groups=4 sprites=128 world=64 hud=0 3d=64 other=0`. |
| Verdict | OPEN — mobile 3D particle production and `MSCAL=211` DMA emission are now correlated in one boot. Mobile resource/state parity remains open: macOS’s corresponding first 3D/world phase begins at `TBP=0x24f2`, not `0x2b8d`, and the Simulator remained blank/non-audible. |
| Next gate | Compare the same-chain mobile `MSCAL=211` source item and state against the macOS `MSCAL=211` item, including texture identity, first vector, frame/matrix hashes, and source group ownership. Do not remap TBPs or change shaders/camera policy yet. |

This is producer/DMA correlation evidence only. It is not visual, audio, or
iPad playability acceptance.
