# R1 producer table-slot capture — 2026-08-21

## Gate

R1 same-transition Sprite3 phase sequence and source-item ownership.

## Identity and environment

- Outer source: dc60af38433879ccf65ac30d0c16a5f155e9541e.
- Upstream worktree: 641fb572e876750d8618434d9f7c1a531b43b366.
- Fresh signed iOS Simulator executable:
  a52bc6327fb511e2b167d2d97cd20c1347341ef722dc29b13a56d879504cc534.
- One iPad Pro 11-inch (M4) Simulator, iOS 18.5; container
  896CD452-EE50-4DD9-9514-64A7AB2A3D3D.
- Runtime log:
  Library/Application Support/local.ottsel/OttselShell/ottsel-runtime.log.

## Change

Added a writable-directory-triggered, iOS-only trace in
send_gfx_dma_chain. After the Village1 marker, the trigger logs the raw
64-bit table words for logical positions 65 through 69 before the renderer
receives the chain. It does not alter the DMA walk, table values, or renderer
ownership.

## Live proof

The fresh route reached:

    OTTSEL LEVEL MARKER: level=village1 display=display-self

After the trigger, 64 producer submissions alternated between chains
0x50a0f0 and 0x50c820. Both shapes were stable. Representative raw table
words were:

    chain=0x50a0f0
    bucket65=0x0051d7d020000000
    bucket66=0x0000000000000000
    bucket67=0x0051d7f020000000
    bucket68=0x0000000000000000
    bucket69=0x0051c40020000000

    chain=0x50c820
    bucket65=0x00ceb81020000000
    bucket66=0x0000000000000000
    bucket67=0x00ceb83020000000
    bucket68=0x0000000000000000
    bucket69=0x00cea44020000000

The nonzero words decode as NEXT-tag-shaped entries; slots 66 and 68 are
zero in all 64 captured submissions. The app fault log remained empty for the
bounded run. The Simulator was blank and non-audible.

## Diagnostic correction

The corrected source was rebuilt into the signed iOS Simulator app after this
capture. The rebuilt executable SHA-256 is
`4e6f61bac9ba471bfcae7b2093c50317246d3e001f33efc88bbe35636230db7d`; deep
strict code-signature verification passed. This is the first binary containing
the corrected 16-byte producer-table read and is the required app for the next
route replay.

The first version of this ledger mislabeled the words after bucket 65: it used
consecutive 64-bit array elements even though each DMA table entry is 16 bytes.
The reported even-slot zeros were therefore the second 64-bit VIF words inside
the preceding tags, not bucket tags.

The corrected producer interpretation reads each slot at chain plus index
times 16. The
subsequent synchronized renderer ledger decoded the same chain 0x50a0f0 as:

    bucket65=0x52adf0
    bucket66=0x52ae10
    bucket67=0x529670
    bucket68=0x512800
    bucket69=0x50ef50

The producer raw values at the correctly aligned positions agree for the
captured leading entries. The apparent producer table-slot anomaly is
falsified; no table-origin or off-by-one defect is proven.

## Valid-route follow-up

Using the proven title-wait route (Start, Cross, four settled Down edges,
final Cross) with the same signed build reached Village1 again. The
trigger-gated phase window recorded:

    bucket66=0xcf8e30 bucket67=0xcf7690 bucket68=0xce0820
    label=bucket67-window groups=13 sprites=576 world=384 hud=128 3d=64
    rejected=0 boundary-stops=0

This is valid phase evidence and confirms that the mobile interval includes
world, HUD, and 3D groups, but it remains materially smaller/different from
the macOS 51-block post-transition world dispatch. The Simulator stayed blank
and non-audible.

## Verdict

OPEN. The producer handoff trace is useful after correcting its indexing, but
it does not identify a table-boundary defect. No bucket-index rewrite, TBP
remap, or renderer widening is justified.

## Next gate

Return to the already-proven producer phase/resource divergence and compare
the corrected same-chain source item against the macOS post-transition phase.
Only a new ordered mismatch may become the next before-failing fix.

## Follow-up replay boundary

A subsequent fresh launch of the same signed build was not usable for the
renderer-side half of this comparison. The supported Village1 trigger reached
an empty object load and then stopped at:

    OTTSEL LINK VERSION MISMATCH: object= major=0 minor=0 expected=1.0
    game/kernel/common/klink.cpp:81

The app fault file remained 0 bytes, but this is a real runtime linker
assertion and invalidates that replay's phase evidence. It is recorded as a
separate data/link boundary, not attributed to the producer table trace or
Metal. The valid 64-chain producer capture above remains authoritative.
