# AU1 MUS user-bank probe — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `ba744cda3ef6bd0c5d0774a10cd845b9d4f722be232802ceec38c4e66243f2ff` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | The prior AU1 probe proved only an SBK request; no maintained iOS `FS_LoadMusic` path had been exercised. |
| Change | Added the narrow opt-in `OTTSEL_AUDIO_MUSIC_PROBE` to initialize the validated pack's MUS fake-ISO root and call Jak 1 `FS_LoadMusic` for `VILLAGE1.MUS`, then request sound 0. |
| Focused proof | `scripts/build-ios.sh`; focused GOAL tests 8/8; strict codesign; diff checks. |
| Live proof | With `OTTSEL_DISABLE_METAL=1`, `OTTSEL_AUDIO_BANK_PROBE=1`, and `OTTSEL_AUDIO_MUSIC_PROBE=1`, the runtime loaded `MUS/VILLAGE1.MUS` (563344 bytes), returned handle 2, and mixed 48,000-frame windows with PCM peaks 6503, 6378, 15113, and 10145. |
| Fault scan | App-owned `ottsel-fault.log` was 0 bytes. Two known RAMDISK invalid-read diagnostics remain from the existing VIS path. |
| Verdict | OPEN — MUS loading and playback substrate are proven in Simulator; full IOP/OVERLORD request routing, VAG streaming, physical route/interruption, and audible acceptance remain open. |
| Next gate | AU1 VAG request/stream boundary, beginning with a fixture-backed file discovery and command path. |

The full runtime log is `/tmp/ottsel-au1-music-probe-2026-08-20.log`.
