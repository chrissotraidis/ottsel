# I1 depth isolation after bucket-tail change — 2026-09-03

Status: OPEN. This probe does not prove the depth contract is the remaining
cause of the malformed scene.

Question: does disabling the scene depth test turn the sparse native output
into a coherent scene, proving that depth rejection is the dominant failure?

Build under test: signed `out/jak-project/out/ios/app/OttselShell.app`, with
the bucket-table PC_PORT tail and 27/27 focused PlatformInput tests passing.

Route: one iPad Pro 11-inch Simulator
(`08636791-2675-4675-8335-EF72EF954DCF`), bounded title → New Game route with
the `scene-no-depth` trigger.

Fresh frame: `/tmp/ottsel-video/bot36-bucket-tail-no-depth-2026-09-03.png`.
SHA-256: `7b027b85e1299ebe12afe66451c9d01fd1443dc0982fb99cc8b182168383378b`.

Observed: the debug rectangles remain, while the already-sparse scattered
geometry disappears. The result is still black and not playable; disabling
depth does not reveal Jak or a coherent Village1 scene.

Runtime reached VU1STAT chain 1260, logged Village1 TFRAG/TIE snapshots and
PLAYER RPC playback, and recorded a zero-byte fault log. The packet-level
camera ledger remained live; no camera matrix, TBP/lookup, or strip-restart
code changed.

Conclusion: depth remains an upstream contract requirement, but this probe
does not justify another depth change. Next investigation should target the
material/fragment visibility or final composition boundary using a focused
source mismatch and a paired `scene-no-merc`/`scene-no-tie` frame.
