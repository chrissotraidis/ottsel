# AU1 — validated user-bank playback probe — 2026-08-20

| Field | Result |
|---|---|
| Gate | AU1 — mobile IOP, streaming, and playback-only audio |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `f5522116e13a6e710642d985ea08e3c5743b2cc7093f9a0d9bf5c6ec2efa4126` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5; one SDL diagnostic runtime with Metal disabled; host-sandbox delivery of the validated temporary pack; `OTTSEL_AUDIO_BANK_PROBE=1` |
| Before failure | The playback substrate produced callbacks but zero PCM because no sound bank request reached the player. The first probe used `TESTTONE.SBK`, which is a raw diagnostic bank and asserted in `BinaryReader` at the maintained loader boundary; that failure was observed and bounded before changing the probe to a standard `SBlk` bank. |
| Change | The bounded probe now uses the validated user-pack `SBK/COMMON.SBK`, applies the same 20,480-byte sound-name-table offset used by `fake_iso`, calls the real `snd_BankLoadEx`, resolves bank references, and requests sound 0. It is opt-in and does not replace IOP/OVERLORD. |
| Focused proof | All 17 sound translation units compile for arm64 iOS Simulator; the iOS closure link passes; `goalc-test --gtest_filter='PlatformInput.*:DirectFixture.*'` passes 8/8; fresh signed build, codesign, and diff checks pass. |
| Live proof | `/tmp/ottsel-au1-bank2-2026-08-20.log` records `bank probe loaded .../SBK/COMMON.SBK offset=20480 bytes=831360`, `bank-sound=0 handle=1`, and `mixed 48000 frames (window 6), pcm-peak=2831`. Later windows return to zero after the one-shot sound completes. |
| Fault scan | `ottsel-fault.log` was zero bytes. The route still logged two existing `OTTSEL RAMDISK: invalid read` diagnostics during title/level loading; no clean playable-route claim is made. |
| Verdict | OPEN — a validated user bank now reaches the maintained player and produces nonzero mixed PCM in the diagnostic path. The game’s IOP/OVERLORD request/callback path, MUS/VAG streaming, pause/resume, route/interruption recovery, and physical audible acceptance remain open. |
| Next gate | Replace the shell-only probe with one fixture-backed IOP/OVERLORD sound-bank request and prove the same nonzero PCM/callback contract on the title/gameplay route. |
