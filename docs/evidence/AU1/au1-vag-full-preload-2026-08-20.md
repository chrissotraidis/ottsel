# AU1 full VAG diagnostic preload — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `2fecbe39f824f59bb0891d1e3e0a5dd4bb93ea74cec43452dfe66a774a736867` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | The 8-chunk diagnostic buffer became silent after its finite payload ended, so it did not establish sustained decoded VAG PCM. |
| Change | Read the VAG header data length, bound it at 16 MiB, read all aligned `0x6000` chunks through one WAD handle, and retain the full payload with a guarded non-looping end block. This is explicitly a diagnostic preload, not runtime refill. |
| Focused proof | `scripts/build-ios.sh`; focused GOAL tests 8/8; strict codesign; diff checks. |
| Live proof | VAG-only run loaded `data-bytes=4298096`, `chunks=175`, `bytes=4298144`; PCM remained nonzero through window 70: `358`, `5321`, `4602`, `7692`, `7667`, `7673`, `6563`, `6113`. |
| Fault scan | `ottsel-fault.log` was 0 bytes. Existing VIS RAMDISK invalid-read diagnostics remain. |
| Verdict | OPEN — sustained decoded PCM over the full local VAG payload is proven in the blank Simulator. No audible, route, interruption, physical-device, or true refill/looping claim is made. |
| Next gate | Replace full preload with bounded refill/producer-consumer state while preserving the end guard and PCM continuity bar. |

The full runtime log is `/tmp/ottsel-au1-vag-full-preload-2026-08-20.log`.
