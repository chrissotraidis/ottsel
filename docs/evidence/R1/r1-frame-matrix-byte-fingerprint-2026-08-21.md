# R1 Sprite3 frame/matrix byte fingerprint — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 producer/frame-state attribution before native composition |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed mobile executable `1f3d295affa5078a12feb0b70f99194564035d31eab66e8e30ffa3a8182149fd` |
| Environment | One iPad Pro 11-inch (M4) Simulator run, then one Windowed native arm64 macOS `gk` run; never concurrent; both stopped afterward |
| Before failure | Mobile and macOS had visibly different Sprite3 resource families and setup tuples, but it was not known whether the source frame data itself differed or whether only the matrix/phase differed. |
| Change | Added bounded FNV-1a fingerprints of the raw Jak 1 frame and 3D matrix DMA transfers in the mobile and desktop diagnostic consumers. No rendering, camera, texture, or phase behavior changed. |
| Focused proof | `ninja -C build/h1 gk` passed; `scripts/build-ios.sh` passed and strict signing completed. The transfer-order probe still recorded mobile frame 9 → matrix 12 → MSCAL3 13. |
| Mobile live proof | Village1 `display-self` was reached. Stable mobile phase A recorded frame hash `0xd73152f7c4464110`, matrix hash `0x94d1a3b75d400ffc`, camera `t=(227569.38,47488.31,-5.7278464e9,-31.885628)`, and first `TBP=0x2bc1`. Phase B recorded frame hash `0xff7ea32dd0db8048`, matrix hash `0x879e99b3d367f4a9`, camera `t=(-389687.25,58981.883,1.02667206e9,5.6293917)`, still first `TBP=0x2bc1`. |
| macOS live proof | After Village1 `display-self`, desktop frame 2 recorded frame hash `0xd73152f7c4464110` with matrix hash `0xda600b5ce07b134a`; desktop frame 3 recorded frame hash `0xff7ea32dd0db8048` with matrix hash `0x23e240c06317fa34`. The desktop setup tuples were camera `t=(227569.38,47488.31,-5.8724347e9,-32.68868)` and then `t=(-389687.25,58852.34,1.0293441e9,5.6442327)`. Its first world draw remained `TBP=0x24f2`, 55 sprites. |
| Fault scan | The Simulator was shut down. The fault file in the new app container had an older mtime matching pre-run persisted diagnostics; no new fault timestamp was attributed to this capture. It is not counted as a clean fault-free run. |
| Verdict | OPEN, narrowed. The raw frame bytes match across corresponding mobile/desktop phases, while the raw matrix bytes differ. The first mismatch is therefore the matrix/camera producer or its phase timing, not frame-data packing, transfer ordering, texture remapping, or native Metal visibility. |
| Next gate | Trace the matrix producer’s source camera inputs and update cadence at the exact frame corresponding to the matching frame hash. Add a before-failing regression for the matrix/camera contract before changing transforms or renderer policy. |

The Simulator remained blank and non-audible. This is byte-level producer evidence, not visual, audio, playability, iPhone, or physical-device acceptance.
