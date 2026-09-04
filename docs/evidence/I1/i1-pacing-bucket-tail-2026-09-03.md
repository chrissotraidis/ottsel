# I1 bucket-tail pacing — 2026-09-03

Status: OPEN. The bounded bucket jump is regression-covered and stable for the
route, but it does not establish scene correctness or playability.

Question: can native camera/Merc PC_PORT packets be found by jumping to the
Jak 1 bucket-table neighborhood instead of linearly walking the 4096-transfer
tail after the 512-transfer decoder budget?

Before-failing regression: `MobilePcPortTailUsesJak1BucketTableCandidates`
failed to compile because the candidate predicate was absent. After the
implementation, `goalc-test --gtest_filter='PlatformInput.*'` passed 27/27.

Change: the tail now visits only buckets 10, 11, 49, 50, and 56, each bounded
by its next table boundary. The full diagnostic decoder remains capped at 512;
diagnostic dump files and the generic VU snapshot remain environment-gated.

Build: signed `out/jak-project/out/ios/app/OttselShell.app` completed at 08:47.

Fresh route/frame: bounded title → New Game route on iPad Pro 11-inch
Simulator `08636791-2675-4675-8335-EF72EF954DCF`; frame:
`/tmp/ottsel-video/bot36-bucket-tail-2026-09-03.png`.
SHA-256: `224f81f946129e0321778bb513b909c45627c1bf3804cb99e497739f6259ede0`.

Observed: black/sparse output with scattered geometry and debug rectangles;
Jak is not visibly controllable. Runtime reached VU1STAT chain 1080 with no
fault bytes and logged PLAYER RPC playback. No encoder/linker crash appeared.

Post-run `local.ottsel` size: 1,601,200 KiB. A same-container growth delta was
not claimed because reinstall created a new app container before this run.

Next: inspect the bucket-jump runtime ledger against the packet-level camera
and Merc snapshots before making another renderer change.

Current signed runtime additionally logs `cpu-diagnostic-path=disabled`; no
`tfrag-vif-replay.bin` or `tfrag-vu-data.bin` was created, and the measured
`local.ottsel` directory remained 1,601,200 KiB while VU1STAT advanced through
chain 2,070. PLAYER audio remained live with `pcm-peak=15,476`. This confirms
the diagnostic I/O gate, not the required playable-scene gate.
