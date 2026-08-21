# R1 matrix/vsync correlation — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 producer/frame-state attribution before native composition |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed mobile executable `280186b79b8179fcd337510e296b4faa31f5a0bbc2c6e58da6b6f834b1f3b66b` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one run; shut down after capture |
| Before failure | The matrix remained stale across alternating frame hashes, but the earlier trace did not identify whether those groups crossed a display-frame boundary. |
| Change | Added the current iOS vsync number to the existing bounded Sprite3 producer trace. No renderer or producer behavior changed. |
| Focused proof | `./build/h1/goalc-test --gtest_filter='Sprite3Native.*'` passed all 14 tests. `scripts/build-ios.sh` completed and strict signing passed. |
| Live proof | Village1 `display-self` was reached. Chain 254/vsync 255 used frame `0xd73152f7c4464110` and matrix `0x94d1a3b75d400ffc`; chain 255/vsync 256 used frame `0xff7ea32dd0db8048` with the same matrix; chain 256/vsync 257 used frame `0xd73152f7c4464110` with the same matrix; chain 257/vsync 258 used frame `0xff7ea32dd0db8048` and matrix `0x879e99b3d367f4a9`. All preserved frame transfer 9 → matrix transfer 12 → MSCAL3 transfer 13 and first `TBP=0x2bc1`. |
| Fault scan | Simulator was shut down. The container fault file had persisted older diagnostic content and was not attributed to this run; no clean zero-fault claim is made. |
| Verdict | OPEN, corrected by the identity audit below. The matrix crosses vsync boundaries while the raw payload hash alternates, but the hash includes non-camera GIF/TBP/state fields. This does not yet prove stale camera/matrix association. No matrix reuse, swap, camera sign, texture remap, or visibility-policy change is justified. |
| Next gate | Establish a camera-only frame signature or direct GOAL producer trace, then add a phase-pair regression only if that camera identity mismatches. |

The Simulator remained blank and non-audible. This is timing/producer evidence only, not visual, audio, playability, iPhone, or physical-device acceptance.

See `r1-matrix-vsync-identity-correction-2026-08-21.md` for the required
interpretation correction.
