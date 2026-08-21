# R1 mobile/macOS first 3D vector and state comparison — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/resource parity before native composition |
| Source/build identity | Outer checkout `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `78b7541f2072f95dfb55b1257c630805f7a57827454b30d905350e38c71d8a3b` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `07453101-7610-437C-9027-BEFCD391979C`; normal Metal; Simulator shut down. macOS oracle: retained native arm64 Windowed trace in `r1-macos-mobile-first-vector-comparison-2026-08-21.md`. |
| Before failure | Mobile `MSCAL=211` emission was correlated with nonzero 3D particle production, but its first vector and full texture state had not been compared directly with macOS. |
| Change | Added first-vector and full AdGif state fields to the existing trigger-gated mobile source-boundary trace. No rendering or producer behavior changed. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep codesign passed. Fresh marker-synchronized route reached Village1 twice; delegated VSYNC remained active; fault log was 0 bytes. |
| Live proof | Mobile VSYNC `1027`, chain `1026`, first `MSCAL=211` group: 48 sprites, `TBP=0x2b8d`, `TEX0=0x2005aa459930ab8`, `TEX1=0x120`, `CLAMP=0x1010001c0`, `ALPHA=0x48`, first `xyz=(-83876.28,1521.3914,469371.34,9963.493)`, flags `(0,0.9438468,0,18435.535)`, RGBA `(128,128,128,24.88889)`, `pfog0=-0.2847222`, `inv-area=0.09339085`, frame transfer 9, matrix transfer 12. The same chain then emitted world `MSCAL=3` at `TBP=0x2bc1`. |
| macOS comparison | Retained macOS first-vector trace records `MSCAL=211`, `TBP=9710`, 32x32, first `xyz=(-398645.3,115862.33,296381.16,3686.4)`, with setup `pfog0=-0.036405455`, `inv-area=0.036767285`. The resource, vector, and frame-state domains differ before native Metal. |
| Verdict | OPEN — concrete producer/resource/state divergence, not a native Metal visibility proof. The Simulator remained blank/non-audible. No TBP remap, camera correction, shader change, or consumer widening is justified. |
| Next gate | Trace the GOAL-side source/AdGif producer that selects mobile `0x2b8d` versus macOS `9710`, with the same route/frame marker; add a source-side regression before any composition change. |

This is producer/resource evidence only. It is not visual, audio, or iPad
playability acceptance.
