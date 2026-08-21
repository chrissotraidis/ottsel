# AU1 — playback substrate increment — 2026-08-20

| Field | Result |
|---|---|
| Gate | AU1 — mobile IOP, streaming, and playback-only audio |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `5b66a333ad9e91c1af15de2176d3c0b5538359ce0ea4c495782a8cb42f540c3b` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5; one SDL diagnostic runtime with Metal disabled |
| Before failure | The iOS build omitted the maintained `989snd`/SDL sound closure and started no playback device; AU1 had no callback or mixer evidence. |
| Change | Added the existing `game/sound` closure to `scripts/build-ios.sh`, added the Apple-only SDL output path to the iOS runtime lifecycle, and stopped emitting unused non-Apple Cubeb methods on Apple. The shell now starts `snd_StartSoundSystem()`, pumps it per frame, and stops it before SDL teardown. IOP/OVERLORD bank requests remain unimplemented. |
| Focused proof | All 17 sound translation units compiled for arm64 iOS Simulator. The standalone iOS closure link passed after the Apple Cubeb-method guard. `goalc-test --gtest_filter='PlatformInput.*:DirectFixture.*'` passed 8/8; fresh signed build, codesign, and `git diff --check` passed. |
| Live proof | `/tmp/ottsel-au1-playback-2026-08-20.log` records `SDL output-only playback stream started device=21`, `output callback observed after 1024 frames`, and repeated `mixed 48000 frames` windows through window 90. Every recorded PCM peak was `0`, correctly showing that the mixer is running but no sound bank/IOP request has reached it. |
| Fault scan | `ottsel-fault.log` was zero bytes. The same diagnostic run still logged two existing `OTTSEL RAMDISK: invalid read` errors during title/level loading; those are preserved and prevent a clean route/production claim. No microphone permission was requested. |
| Verdict | OPEN — playback output and callback/mixer substrate are proven; game-bank loading, IOP/OVERLORD behavioral parity, nonzero PCM, pause/resume, route/interruption recovery, and human audible acceptance remain open. |
| Next gate | Add a fixture-backed user-pack sound-bank request path at the IOP/OVERLORD boundary, then prove a nonzero mixed-PCM title/gameplay event before claiming AU1. |
