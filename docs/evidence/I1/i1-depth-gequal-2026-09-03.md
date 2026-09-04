# I1 depth contract — 2026-09-03

Status: OPEN. The depth correction built and ran, but it did not establish
playability or the required runtime gates.

Regression-first:

- Added `MobileDepthKeepsNearOverFarAfterMetalRemap`.
- It failed against the prior production contract (`clear=1.0`, LessEqual),
  then passed after switching the shared policy to `clear=0.0`, GreaterEqual.

Implementation:

- `metal_shell.mm` now applies GreaterEqual to TIE write/no-write states and
  clears the shared depth attachment to 0.0.
- Camera math, TBP/lookup, strip restart, and the raw-MERC projection fix were
  unchanged.
- Signed app: `out/jak-project/out/ios/app/OttselShell.app`.

Verification:

- Focused depth regression: PASS.
- Full `goalc-test`: PASS, 762/762.
- Fresh iPad Pro 11-inch (M4) Simulator frame: `/tmp/ottsel-depth-isolated.png`.
- Frame reached Village1 with the no-MERC/no-TIE controls armed, but Jak was
  not visible and the scene remained incomplete; no playability claim.
- `VU1STAT`: chain 810 at 04:27 to 900 at 04:39, approximately 0.125 chain/s,
  below the required 30/s runtime gate.
- `pcm-peak=0`; fault log 0 bytes.
- `Library/Application Support/local.ottsel` grew from 1,623,596 KiB to
  1,627,952 KiB in the measured run (about +4.3 MiB), above the <1 MiB target.

Next experiment: level ownership, with its regression added before the build.

Follow-up depth-mode parity build: Metal now maps the source z-test enable and
NEVER/ALWAYS/GEQUAL/GREATER bits instead of forcing every draw through one
compare function. The focused mapping regression passed 28/28 and the signed
build completed. Fresh frame:
`/tmp/ottsel-video/bot36-depth-mode-parity-2026-09-03.png`; it remains the
same sparse/debug composition, so this does not establish scene correctness.
