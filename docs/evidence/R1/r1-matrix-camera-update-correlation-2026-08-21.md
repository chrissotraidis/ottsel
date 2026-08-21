# R1 matrix/camera update correlation — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 producer/frame-state attribution before native composition |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed mobile executable `430adcf5a1a6410c756699900777d3826ea14e78f21ba5dcea9bc5ac32d60701` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one run; shut down afterward |
| Before failure | Raw frame hashes match the desktop reference, but mobile matrix hashes differ. The remaining question was whether the matrix was stale relative to the frame data or merely produced from a different camera state. |
| Change | Added a bounded mobile `camera-packets` counter to the existing Sprite3 producer setup trace. It counts accepted `OttselPcPortData` packets and changes no camera, matrix, or renderer behavior. |
| Focused proof | `scripts/build-ios.sh` completed and strict signing passed. No Simulator remained booted after capture. |
| Live proof | Village1 `display-self` was reached. In the final capture, mobile chain 252 had frame hash `0xd73152f7c4464110`, matrix hash `0x94d1a3b75d400ffc`, `camera-packets=6`, and the latest camera source at chain 252 transfer 465; chain 253 had frame hash `0xff7ea32dd0db8048`, the same matrix hash, `camera-packets=11`, source chain 253 transfer 468; chain 254 had frame hash `0xd73152f7c4464110`, the same matrix hash, `camera-packets=12`, source chain 254 transfer 427; chain 255 had frame hash `0xff7ea32dd0db8048`, matrix hash `0x879e99b3d367f4a9`, `camera-packets=13`, source chain 255 transfer 281. Every chain preserved frame 9 → matrix 12 → MSCAL3 13 and first `TBP=0x2bc1`. |
| macOS comparison | The corresponding desktop frames paired frame hash `0xd73152f7c4464110` with matrix hash `0xda600b5ce07b134a`, then frame hash `0xff7ea32dd0db8048` with matrix hash `0x23e240c06317fa34`. Desktop’s matrix changed with the frame phase; mobile held its first matrix across alternating frame hashes and changed it only after the later camera-packet update. |
| Fault scan | Simulator shut down. The app-container fault file had an older persisted mtime and was not attributed to this capture; it is not reported as a clean zero-fault run. |
| Verdict | OPEN, narrowed to update cadence/phase pairing. The camera packet and Sprite3 bucket are emitted in the same chain but at different transfer positions; mobile reuses one matrix across alternating frame hashes and accepts the next matrix only after the later camera packet. This is producer sequencing evidence, not permission to swap matrices in Metal. |
| Next gate | Trace the GOAL-side camera packet producer and Sprite3 matrix DMA emission order in the same chain, then add a before-failing phase-pair regression at that shared producer boundary. |

The source contract confirms that `sprite-draw` emits frame data, then
`sprite-add-matrix-data` mode 0, then the 3D sprite groups from one DMA buffer;
the separate `finish-background` path emits the PC-port background/camera
packets. The live mismatch is therefore between those producer/update paths or
their consumption order, not an intentional Metal-side transform choice.

The Simulator remained blank and non-audible. This is producer timing evidence only, not visual, audio, playability, iPhone, or physical-device acceptance.
