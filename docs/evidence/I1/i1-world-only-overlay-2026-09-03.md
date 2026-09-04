# I1 world-only overlay isolation — 2026-09-03

## Question

Are the large colored rectangles in the iPad frame part of the malformed world
renderer, or are they the separate touch/Sprite3 overlay layer?

## Change and method

Added the trigger-gated `ottsel-trace-metal-scene-no-overlay` probe. It skips
native Sprite3/Direct-style overlay batches and the touch-control overlay only
at Metal draw time; it does not change scene data, camera math, or input.

Built and signed the current source with `scripts/build-ios.sh`, installed it
on the single iPad Pro 11-inch (M4) Simulator, and armed the trigger in the
actual SDL writable directory:
`Library/Application Support/local.ottsel/OttselShell/`.

## Result: PASS for isolation; OPEN for I1 playability

Fresh frame: `/tmp/ottsel-video/bot36-world-only-overlay-2026-09-03.png`.
SHA-256: `611fae90c39cff39c1c4bb5fee2c1363ccceb55cf8a21bdb749f8a267415a8f8`.

All colored rectangles disappear, confirming they are overlay output rather
than corrupted TFRAG/TIE geometry. The underlying scene still has large black
regions, missing sky/ocean/environment families, and badly composed geometry;
Jak is not identifiable. The portrait-encoded simctl orientation is retained
as a capture property, not classified as a render defect.

Next: compare the world-only TFRAG submission against the macOS reference at
the same camera packet and repair one proven world-family contract at a time.
