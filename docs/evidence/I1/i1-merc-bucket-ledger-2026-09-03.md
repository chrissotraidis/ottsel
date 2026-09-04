# I1 Merc bucket ledger — 2026-09-03

Status: OPEN. The targeted bucket trace ran, and it refutes the audit's claim
that `eichar-lod0` is never captured.

Regression-first:

- Added `MercLedgerUsesRequiredJak1BucketNeighborhood`, covering buckets
  10/11/49/50/56 and rejecting a neighboring non-target bucket.
- The regression passed before the signed build.

Runtime evidence:

- Signed executable hash: `e9012f133fcd94cc5e59d9f322283c18aff7399b37776e777346d82d11e998a9`.
- Fresh frame: `/tmp/ottsel-video/bot36-native-merc-ledger-2026-09-03.png`; it
  remains a partial/debug-control composition, not playable Jak 1.
- The native PC_PORT ledger saw `eichar-lod0` VALID at chain 311, transfer 419,
  size 1712, while `LEVEL MARKER: target-trans` was live. The audit's premise
  that Eichar is never captured is refuted; it is submitted as 2253 triangles.
- It also saw the title and Village1 Merc names; the unresolved issue is
  visibility/projection/composition, not capture coverage.
- `VU1STAT` reached chain 810 (~38/s), PCM peaked at 4140, fault log was 0 B,
  and the measured container stayed 1,601,200 KiB (delta 0).

Next experiment: route PLAYER audio buffers into `RPC_Player` and prove
nonzero game PCM.
