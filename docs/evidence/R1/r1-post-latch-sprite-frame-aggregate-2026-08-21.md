# R1 post-latch Sprite3 frame aggregate — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 and renderer parity |
| Source/build identity | Outer checkout `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `a3af1793efce65018e3829358bb49740e0805388079485167aa07bf39823da69` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `0FA2AB81-D465-41A8-9DC5-ACAF3E43B486`; normal Metal; Simulator shut down after capture |
| Before failure | The VSYNC latch and route were proven, but no post-latch Sprite3 frame aggregate had been captured on the same current boot. |
| Change | No product-source change. Used the GOAL-created title-wait marker file, injected Start/Cross/Down×4/Cross, and armed `ottsel-trace-mobile-sprite-frame-aggregate` after the current boot logged Village1 entry. |
| Focused proof | The run logged delegated VSYNC, current-boot `start edge in title-wait`, `GAMEPLAY: enter village1` twice, and aggregate completion. `ottsel-fault.log` was 0 bytes. |
| Live proof | Aggregate accepted at VSYNC `1118`, chain `1117`; completed on the next VSYNC with `chains=1 groups=5 sprites=192 world=128 hud=0 3d=64 other=0`. Items: 3D `48 @ TBP=0x2b8d, PSM=19, 64x64`; 3D `16 @ TBP=0x2be0, PSM=19, 32x32`; world `48 @ 0x2bc1, 64x64`; world `48 @ 0x2bd3, 32x32`; zero-texture tail `32`. |
| Fault scan | `ottsel-fault.log` 0 bytes; no crash/assert/fault marker from this run. |
| Verdict | OPEN — the latch and a 3D-bearing mobile phase are live-proven, but resource/producer parity and visible composition remain unresolved. The Simulator was blank/non-audible. |
| Next gate | Capture the corresponding macOS aggregate at the same Village1 phase, then trace the producer/source ownership of mobile `0x2b8d/0x2be0` against macOS `0x24f2` before any remap or shader change. |

This is phase and ownership evidence only. It is not an R1 visual pass, audio
pass, or iPad playability proof.
