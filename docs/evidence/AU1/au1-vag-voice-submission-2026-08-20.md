# AU1 VAG voice submission — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `5e14202aab10b36c2707c6c46fa47f454161302c95538386c3631c7c3debe5a0` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | The prior VAG proof stopped at a valid first chunk; no mobile voice object had been submitted from VAG ADPCM data. |
| Change | Reused the maintained `snd::Voice` PS2-ADPCM decoder for an opt-in diagnostic voice: strips the 48-byte VAG header, retains the first `0x6000` chunk, configures 48 kHz pitch/ADSR/volume, and submits one permanent voice to the playback synthesizer. The fixture uses long-form `SA3INTRO` at sector offset 25585. |
| Focused proof | `scripts/build-ios.sh`; focused GOAL tests 8/8; strict codesign; diff checks. |
| Live proof | Runtime logged `VAG diagnostic voice started bytes=24528 sample-rate=48000` and `header=valid-voice-started`. Mixer callbacks continued through windows 10–50. |
| Fault scan | App-owned `ottsel-fault.log` was 0 bytes. Existing VIS RAMDISK invalid-read diagnostics remain. |
| Verdict | OPEN — VAG discovery, first-chunk read, and voice submission are proven. The Simulator is a blank/non-audible environment; sustained nonzero VAG PCM, chunk progression/looping, physical audio routes, and human audible correctness remain unproven. |
| Next gate | VAG chunk progression: retain/refill successive `0x6000` chunks and prove a continuous decoded voice before attempting physical audio acceptance. |

The full runtime log is `/tmp/ottsel-au1-vag-decode-2026-08-20.log`.
