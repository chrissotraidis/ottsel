# R1 native input accumulation R15 — 2026-08-22

## Change

`MouseMotionLatch::add` previously replaced the pending camera impulse on
every SDL motion event even though the surrounding contract said to
accumulate events until the next pad read. It now accumulates relative motion
around the neutral value and clamps once, while preserving the existing
bounded eight-read lifetime.

The canonical patch was updated at
`patches/r1-native-mouse-controls.patch` and reverse-apply checked against
the dirty nested worktree.

## Regression and build

- Focused `KeyboardEventEdge.*:PlatformInput.*:Sprite3Native.*`: **25/25**.
- New regression: `KeyboardEventEdge.AccumulatesMouseMotionBeforePadRead`.
- Signed iPad app rebuilt with `scripts/build-ios.sh`.
- `codesign --verify --deep --strict`: passed.
- Exactly one booted Simulator and one `com.ottsel.shell` runtime remained
  active: iPad Pro 11-inch (M4),
  `08636791-2675-4675-8335-EF72EF954DCF`.

## Live evidence

The active Simulator was exercised directly. Existing W/A/S/D logs show the
native bridge receives opposing analog states: W `(127,0)`, A `(0,127)`, S
`(127,255)`, D `(255,127)`. The signed replay also logged mouse Cross input:
`mouse-button buttons=0x4000 cross-pressure=255`, followed by release.

- [fresh signed input screenshot](artifacts-2026-08-22-ipad-r1-mouse-accumulation-r15/fresh-signed-input-replay.png)
- [prior direct visual replay](../r1-visual-runtime-replay-r13-2026-08-22.md)

This proves the input bridge and click mapping, not human acceptance of full
gameplay. The fresh frame remains a diagnostic/title surface and the native
game renderer remains visibly non-playable; R1 and the full completion goal
remain open.
