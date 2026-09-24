# G2.6: the nested tree reconstructs from the documented pin at file level - 2026-09-23

Gate item: G2.6 asks whether the product can be reconstructed from the documented pin and patches.  The
coverage guard is path-level and the hunk guard only reverse-applies, so neither proves the forward claim.

## Method (the README's own recipe)

`git worktree add --detach /tmp/ottsel-recon <pin> 641fb572e876750d8618434d9f7c1a531b43b366`, then an ordered
forward replay: apply `h3-jak1-host-boot.patch` (the canonical full diff), then every other `patches/*.patch`
that `git apply --check` accepts, in sorted order, repeating passes until none apply.  Each file any applied
patch names is then compared byte-for-byte (sha256) against the current `out/jak-project` worktree.

## Measured

    fresh pin + h3 alone                        153 / 178 files byte-identical
    + the 31 overlays that apply (repeat passes) 182 / 193
    + g2-working-tree-source-gap.patch (new)     193 / 193

Verified end to end a second time from a fresh pin worktree, not just incrementally.

## The gap, named

The 11 files that h3 and the 31 overlays did not reproduce (395 changed lines) were **working-tree diagnostic
and experiment edits that no earlier overlay captured** - each is an additive trace or guard, not product
behaviour that was lost:

    cam-update.gc / target-death.gc   BOT62 per-frame target-position trace (*ottsel-target-trace-left*)
    title-obs.gc                      extra `OTTSEL TITLE:` diagnostic fields (busy=, activate-progress)
    progress-pc.gc                    `OTTSEL G1:` option/draw dumps in the pause progress screen
    sif_ee.cpp                        `#ifndef OTTSEL_SIGNED_GAMEDATA_TEST` around the IRX handshake
    kscheme.cpp                       A1.1 symbol-table-full abort + methodset-symbol trace
    ottsel_signed_gstate.{cpp,h}      loader diagnostics/comment
    player.cpp, gkernel.gc, IR.cpp    audio/AOT diagnostics carried from earlier rounds

They are now captured, and only them, by `patches/g2-working-tree-source-gap.patch` (37 KB, generated against
the h3+overlays state it applies to).  `patches/README.md` records the recipe and the file list.

Overlays that do **not** apply are accounted for: 34 are superseded by h3 (h3 is a later snapshot of the same
hunks), the outer-tree-only ones target `src/shell/*` and cannot apply inside the nested worktree, and
`a11-loader-fail-closed.patch` is the documented corrupt one (marked in `patches/README.md`).

## Boundary

This is a **file-level** proof.  The gate also wants the reconstructed tree to build and run, and no build was
attempted here: the reconstructed source is byte-identical to the tree that already builds, but "reconstructs"
is claimed only for the sources.  No product, audio or device claim.
