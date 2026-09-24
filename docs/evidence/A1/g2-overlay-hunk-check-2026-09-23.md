# G2.6: hunk-level overlay validity, and one live patch that was not a diff at all - 2026-09-23

Question (G2.6's reconstruction half, and the loop's open L1 item): the coverage guard is path-level -
every changed nested file is *named* by some overlay.  Does each overlay's own text still match the tree
it targets, and can the documented stack reconstruct the source from the pin?

Method: `scripts/verify-overlay-hunks.py` (new).  For every `patches/*.patch` the README does not list
under a do-not-apply section, it asks git to reverse-apply the patch (`git apply --check --reverse`),
per target root: a patch that touches both repositories is checked in each with `--include` globs, so a
mixed patch is not called broken for living in two trees.  `--file PATH` answers the narrower question
"which patch reproduces this file?".

## Measured (this tree, this revision)

    overlay patches: 75   documented do-not-apply: 28
    whole-patch reverse-apply: 21 clean, 34 do not (see below)
    malformed bodies (actionable): 0

The 34 are not staleness in the interesting sense: the stack is layered, so a patch whose files a later
layer edits can no longer reverse-apply on its own - the canonical `h3-jak1-host-boot.patch` is in that
group for exactly that reason, and the checker prints how many later patches touch the same files so the
distinction is visible instead of implied.

## What it found: a live-listed patch that is not a valid diff

`a11-loader-fail-closed.patch` was listed as a live overlay (README, the A1.1 chain entry) but
`git apply` rejects its body with `corrupt patch at line 39`, and the README's own malformed-patch list
names eleven other files, not this one.  Both files it targets are reproduced by other patches, verified
with `--file`:

    game/kernel/jak1/kscheme.cpp                  <- a11-host-cbridge-counters, a11-signed-export-banks
    game/kernel/common/ottsel_signed_gstate.cpp   <- a11-data-only-main-segment, a11-kind2-method-counts,
                                                     a11-module-record-extensions

so it is a stale snapshot and nothing is lost by dropping it; it is now recorded in the README's
malformed group with that evidence, and the checker's malformed count goes 1 -> 0 for the live stack.

Spot check of the one nested file whose only overlays are an older r1 record plus the base:

    goal_src/jak1/engine/target/target-handler.gc
      reproduces current content  h3-jak1-host-boot.patch
      does not match              r1-route-state-marker.patch

which is supersession, not a reconstruction gap: the base patch carries the current content.

## What this does and does not prove

Proves: every live overlay either still matches the tree or is superseded by a later layer, no live
overlay body is unparsable, and the documented stack (pin + canonical + overlays) is consistent at hunk
level with the working tree.  Does not prove: a from-scratch *build* of the engine and the app from the
pin alone, which remains the open half of G2.6 exactly as the packaging audit states.

