# AU1 independent VAG probe — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `09918aea9c91ca69e72bb5d508a9de0dec3f5ac583422e43bd7405f347b98baf` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | VAG probing was coupled to `OTTSEL_AUDIO_BANK_PROBE`, making a VAG-only request silently skip the probe. |
| Change | Bank, MUS, and VAG opt-in probes now have independent gates. |
| Focused proof | `scripts/build-ios.sh`; focused GOAL tests 8/8; strict codesign; diff checks. |
| Live proof | VAG-only launch with `OTTSEL_AUDIO_VAG_PROBE=1` loaded eight chunks from `SA3INTRO`, submitted the voice, and recorded PCM peaks `7684` and `5321`. |
| Fault scan | `ottsel-fault.log` was 0 bytes. Existing VIS RAMDISK invalid-read diagnostics remain. |
| Verdict | OPEN — independent VAG request and nonzero Simulator PCM are proven. The blank Simulator cannot prove audibility; finite-buffer exhaustion, explicit refill/looping, physical routes, and human listening remain open. |
| Next gate | Explicit refill/loop state across chunk boundaries. |

The full runtime log is `/tmp/ottsel-au1-vag-independent-2026-08-20.log`.
