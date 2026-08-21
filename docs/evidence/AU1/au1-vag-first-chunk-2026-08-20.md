# AU1 VAG first-chunk probe — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `54657fa3befec7c2cff73789218ee5d8d49cdf653ce4072be7c4c69e242a181d` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | No iOS probe exercised the validated pack's `VAGDIR.AYB`, language WAD, or maintained `FS_OpenWad`/`FS_BeginRead` path. The first VAG-only launch also exposed that the temporary probe was gated behind the existing bank flag; the successful reproduction enabled both opt-in flags. |
| Change | Added an opt-in first-chunk probe that parses the bounded VAG directory header/entry, initializes the VAG fake-ISO root, opens `VAGWAD.ENG` at the recorded sector offset, reads `0x6000` bytes through the fake-ISO stream layer, and validates the `VAGp`/`pGAV` header. |
| Focused proof | `scripts/build-ios.sh`; focused GOAL tests 8/8; strict codesign; diff checks. |
| Live proof | `VAGDIR.AYB` yielded entry `FUCVICTO`, offset `0`; `FS_OpenWad` opened the 174123008-byte `VAGWAD.ENG`; `FS_BeginRead` returned `4294967295` (`CMD_STATUS_IN_PROGRESS`) and the chunk header was valid. |
| Fault scan | App-owned `ottsel-fault.log` was 0 bytes. Two known RAMDISK invalid-read diagnostics remain from the existing VIS path. |
| Verdict | OPEN — VAG discovery and first-chunk routing are proven; ADPCM decode/voice submission, continuous stream progression, pause/resume of a VAG voice, and physical audible acceptance remain open. |
| Next gate | AU1 VAG decode/voice boundary, using the validated header/chunk as the fixture input. |

The full runtime log is `/tmp/ottsel-au1-vag-probe-2026-08-20.log`.
