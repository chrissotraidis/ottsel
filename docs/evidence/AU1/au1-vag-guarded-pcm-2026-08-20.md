# AU1 guarded VAG PCM — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `261d318ac0afd8c42fe83370d63a025d2fa9475d0e3665993e8a7ecc56679d43` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | The 8-chunk diagnostic voice used `0x7fff` volume, which overflowed the signed internal volume level and produced peak 1; its finite sample buffer could also be read past, producing a signal-11 fault. |
| Change | Use the established `0x3fff` voice-volume range and set the retained buffer's final ADPCM block to non-looping end before submitting it. |
| Focused proof | Isolated native voice runner: `voice-preflight-peak=11502`; iOS build; focused GOAL tests 8/8; strict codesign; diff checks. |
| Live proof | Eight WAD reads retained 196608 bytes; runtime submitted the 48 kHz voice; mixer windows recorded `pcm-peak=7670` and `7671`. Later windows reached zero after the finite buffer ended. |
| Fault scan | `ottsel-fault.log` was 0 bytes. Existing VIS RAMDISK invalid-read diagnostics remain. |
| Verdict | OPEN — nonzero decoded PCM and bounded end-of-buffer safety are proven in Simulator. This blank/non-audible Simulator result is not audible correctness, continuous refill/looping, route/interruption, or physical-device acceptance. |
| Next gate | Replace the bounded concatenation with explicit refill/loop state across successive WAD chunks while preserving the end guard. |

The full runtime log is `/tmp/ottsel-au1-vag-guarded-playback-2026-08-20.log`.
