# R1 Sprite3 phase classifier live capture — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/consumer phase ownership |
| Build | Signed Simulator executable SHA-256 `2b503d9d224bad61c8ac83592577828a7c22dd81e339b168a9ca2b2858140767`; outer `dc60af3`; upstream `641fb572` |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; validated pack prepared before Metal; one runtime |
| Route | Fresh process `67831`; title marker, synthetic Start/Cross/Down/Cross route, and `GAMEPLAY: enter village1` logged twice. |
| Live phase summary | Populated bucket 66 at chain `22690`: MSCAL 211 accounted for `64` 3D sprites; MSCAL 3 accounted for `384` world sprites across `8` groups; HUD2D and Other accounted for `0`. First/last world TBP was `0x2c8d`. |
| macOS comparison | Same-route macOS trace remains `51` world blocks / `2,432` world sprites, beginning with TBP `0x24f2`. |
| Focused proof | `goalc-test --gtest_filter='Sprite3Native.*:DirectFixture.*:PlatformInput.*:ARM64EmitterFloatMath.*'` passed `21` tests. Strict codesign, executable-marker scan, and canonical patch reverse-check passed. |
| Fault scan | `ottsel-fault.log` was `0` bytes. |
| Interpretation | The phase classifier cleanly separates the mobile 3D and world programs, but no HUD/other phase appeared in this populated bucket. The large world-count/TBP mismatch remains open and is not a shader or alpha-policy decision. |
| Verdict | OPEN — phase ownership is now explicit; producer parity is not. |
| Next gate | Compare the mobile bucket’s complete DMA chain against the macOS Sprite3 phase sequence, including the pre-Direct/distort/shadow/HUD boundaries, before changing the native consumer. |

The Simulator was blank and non-audible. No visual, audio, playability,
iPhone, or physical-device claim is made. No protected data or runtime
executable-code generation was introduced.
