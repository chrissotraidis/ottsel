# AU1 VAG bounded chunk progression — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `18b61871f3c32b108de0182390e1d07a4d9f26d34de21cf5a929aad07a7c7c39` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | The voice probe retained only one `0x6000` chunk, so it could not distinguish voice submission from a short-lived first-buffer effect. |
| Change | The opt-in probe now keeps one `FS_OpenWad` handle and performs eight successive `FS_BeginRead` calls, retaining 196608 bytes before submitting the header-stripped ADPCM to the diagnostic voice. |
| Focused proof | `scripts/build-ios.sh`; focused GOAL tests previously pass 8/8; strict codesign; diff checks. |
| Live proof | Runtime logged `entry=SA3INTRO offset=25585 chunks=8 bytes=196608 read-status=4294967295 header=valid-voice-started`; mixer callbacks continued through windows 10–50. |
| Fault scan | App-owned `ottsel-fault.log` was 0 bytes. Two known VIS RAMDISK invalid-read diagnostics remain. |
| Verdict | OPEN — bounded multi-chunk transport and voice submission are proven. PCM was only `1` at window 10 and `0` in later windows; the blank Simulator cannot establish audible correctness. Continuous refill/loop semantics, route/interruption behavior, and physical listening remain open. |
| Next gate | Decode/stream continuity: make refill state explicit and prove a nonzero decoded window across a chunk boundary before device acceptance. |

The full runtime log is `/tmp/ottsel-au1-vag-chunk-progression-2026-08-20.log`.
