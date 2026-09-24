# Apple audio pause/open recovery

Actual Player lifecycle regression reproduces lost pause intent while SDL device opening is pending; all nine checks pass after preserving intent under the existing mutex. Covers pause before/during open, resume, shutdown during open, close and reopen.

Run `python3 test/audio_output_lifecycle_test.py`. Maintained overlay: `patches/apple-audio-lifecycle-intent.patch`; pin + H3 + overlay reconstructs player.cpp exactly.

Full build/install SHA256683a97aa34f9c47cc7929df91125676b7488fcf10de553c1664e793f7faabe7b matched on sole iPad08636791-2675-4675-8335-EF72EF954DCF. PID79167 completed normal New Game/Continue Without Saving route to game-start.
Simulator Home at23:51:49 paused audio; foreground at23:52:14 resumed the same PID. Nonzero PCM peak3086 followed at23:52:15. Logs: `/tmp/ottsel-recovery-2026-09-12/audio-lifecycle-events.log`.
After resume, two-second forward input changed target position, followed by pad0 neutral. Screenshot `/tmp/ottsel-video/recovery-audio-lifecycle-resumed.png` shows visible Jak and terrain; scene defects remain. Input evidence: `audio-lifecycle-resumed-input.log` beside events.
App stopped with zero fault bytes; preserved runtime under `/tmp/ottsel-recovery-2026-09-12/audio-lifecycle-runtime/`.

This is one bounded Simulator pause/resume check. Actual audibility, interruptions, held-input suspension, controller disconnect, saves and physical devices remain open. Audio command ownership/spatial changes were applied to source afterward and are not part of this executable.

## Native command and bank follow-up
Actual SIF/command/registry/spatial source regressions now42/42; iOS build includes shared ssound/sbank sources while excluding absent IOP bootstrap. Maintained overlays cover all source deltas.
Full build/installb34ad6196f9281143e5d4efe9fec1492c7c242f4d1674504e8f3a6bed5c1481d, PID87215 reached normal Training with zero fault bytes at stop. Real GOAL loader commands loaded COMMON461, EMPTY1/2, VILLAGE1, MISTY and TRAINING6. After Training load, previously missing training-amb and water-lap-cls started native handles13/14; later water one-shots replayed. Nonzero PCM follows. Evidence `/tmp/ottsel-recovery-2026-09-12/audio-bank-live.log`; full runtime `hud-matrix-banks-runtime/`.
This closes the demonstrated missing Training bank route; it does not establish audibility, dialogue/VAG, music loading or complete bank eviction/lifecycle acceptance.
