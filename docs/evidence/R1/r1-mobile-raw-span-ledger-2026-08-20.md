# R1 mobile raw Sprite3 span ledger — 2026-08-20

## Gate

Separate a producer-side short stream from a consumer-side rejection at the
existing mobile Sprite3 bucket 66→68 handoff. This is a diagnostic slice only;
it does not change bucket ownership, texture mapping, Metal submission, or the
CPU/VU policy.

## Change

`src/shell/metal_gfx.mm` now records, for each explicitly requested phase
window, the bounded DMA transfer count, Sprite3-header candidates, rejected
candidate count, and candidates that reach the bucket boundary while being
validated. The existing accepted-group ledger remains unchanged, so the new
counts can be compared directly with the prior 9-group/384-sprite aggregate.

## Proof

- `goalc-test --gtest_filter='Sprite3Native.*'`: 12/12 passed.
- `scripts/build-ios.sh`: passed; the signed app was rebuilt.
- Fresh app executable SHA-256: `7bdeca9e5c5347c83ae1951ea85cbd012a053af6dd44ddf4b9273e5ff9011dbf`.
- The build emitted only pre-existing deprecation/format warnings; no
  executable-page or runtime-code-generation policy was introduced.
- A fresh iPad Simulator launch reached the shared `village1 display-self`
  marker and left a zero-byte fault log, but emitted no `RAW SPAN` line before
  the bounded run was stopped. This is an incomplete capture, not evidence
  that the producer span is empty.

## Corrected trigger-placement result

After placing the triggers in the authoritative SDL preference directory, a
fresh current-process chain emitted:

```text
OTTSEL SPRITE RAW SPAN: label=product-66-to-68 chain=29905 transfers=28 headers=5 rejected=0 boundary-stops=0
OTTSEL SPRITE PHASE: label=product-66-to-68 chain=29905 vsync=29906 groups=5 sprites=192 world=64 hud=128 3d=0 other=0
```

The split window agreed: bucket 66 had setup only, while bucket 67→68 carried
the same five accepted groups. The current persistent log did not contain a
fresh Village1 marker for this exact chain, so this is a valid non-Village1
producer-span result only. It still falsifies silent consumer rejection for
this phase: every candidate header was accepted and no boundary stop occurred.

## Result and next gate

The runtime capture is now valid for a non-Village1 phase but incomplete for
the product gate. The next valid iPad route capture
must arm `ottsel-trace-mobile-sprite-phase-window` at the shared
`village1 display-self` marker and collect `OTTSEL SPRITE RAW SPAN` for bucket
66 and bucket 67. If headers are present but rejected, inspect the first
failing transfer shape; if headers are absent, continue upstream into the
producer/DMA table population. The simulator remains a blank screen, so this
diagnostic build is not playability proof.
