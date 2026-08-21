# AU1 lifecycle pause/resume — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed lifecycle implementation build SHA-256 `8e97b419f1076f0218e79e8bf02131cbeebacc8ef012a62f11c843480287a269` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | Existing background handling neutralized input but had no audio output pause/resume seam. |
| Change | Added `Player::PauseOutput/ResumeOutput`, `snd_PauseAudioOutput/snd_ResumeAudioOutput`, and lifecycle wiring in `main.cpp`. The shim makes repeated notifications idempotent. |
| Focused proof | `scripts/build-ios.sh`; `goalc-test --gtest_filter='PlatformInput.*:DirectFixture.*'` (8/8); strict codesign; diff checks. |
| Live proof | Diagnostic Simulator replay on the preceding signed build `02fc679bc9fd997997d830946b9a386ace4325c22f81c9e43bf4abc8d1b37d4f`: background logged audio pause and neutral input; foreground logged audio resume; mixer windows continued afterward. |
| Fault scan | `ottsel-fault.log` was 0 bytes. No duplicate SDL stream-start line occurred; the Simulator delivered duplicate lifecycle notifications, which motivated the idempotent guard. |
| Verdict | OPEN — lifecycle control seam and Simulator behavior are proven; physical route/interruption and audible acceptance remain open. |
| Next gate | AU1 streaming/data requests, beginning with a fixture-backed MUS/VAG request boundary. |

The full runtime log is `/tmp/ottsel-au1-lifecycle-2026-08-20.log`.
