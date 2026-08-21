# R1 iPad texture lookup divergence — 2026-08-21

## Ledger

| Field | Required value |
|---|---|
| Gate | R1 source/resource parity |
| Source/build identity | Outer `b2e36fc8037f3f1a7984ede59f7114cd03604b2f`; upstream pin `641fb572e876750d8618434d9f7c1a531b43b366`; patch SHA-256 `0ee0723919c2404874c314feff849d4623166ccc3da9a6619d125595190e30b8`; signed executable SHA-256 `e7bf1f19a8636ef2727b6dff50e1fa814cd590d01455d6fdb21d1217adeb3e20` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`, iOS 18.5; app PID 24144; normal Metal; fresh validated user pack |
| Before failure | No completed iPad page/index lookup proof existed, so the first mobile/macOS resource divergence could not be attributed to lookup order |
| Change | Diagnostic-only bounded page-2 `lookup-texture-by-id` trace plus the iOS-safe float/newline formatter fix in `patches/r1-texture-lookup-trace.patch`; no lookup, allocation, TBP, camera, shader, or Metal policy change |
| Focused proof | ARM64 `(mi)` rebuilt all 546 GOAL targets; `Sprite3Native.*` passed 16/16; strict deep codesign passed; reverse-apply check against the pinned tree passed |
| Live proof | Fresh same-boot route consumed Start at [38:38], Cross at [38:41], four Down edges at [38:44]–[38:50], and reached Village1 twice. The source boundary armed at chain 21151 / VSYNC 21152 and closed with two MSCAL=211 groups followed by six MSCAL=3 groups. |
| Fault scan | Replay-window crash/assert/Metal-validation/unsupported/placeholder/bounds/link-mismatch scan returned no matches; no fault file existed after capture |
| Verdict | OPEN — ordered iPad lookup sequence diverges from macOS before downstream TEX0/TBP |
| Next gate | Trace page-directory login/order, FR3/DGO texture ordering, and `texture-page-default-allocate`/VRAM allocation state |

## Capture chronology

The first 21-index block in the raw log was an earlier diagnostic run from the
same boot. The later replay begins near line 493000 of the 90 MB stdout log.
Its tail exactly matches the corrected post-Start artifact:

```text
4,53,4,18,15,28,27,3,54,49,48,42,44,24,25,10,41,0,30,34,9
```

The macOS oracle is:

```text
4,53,4,18,15,30,0,28,3,41,24,35,31,36,9,10,25,34
```

The ordered divergence begins at position 5: macOS selects index 30 while iPad
selects 28 → 27 → 3 and reaches 30 much later. iPad omits macOS indices 35,
31, and 36 while adding 54, 49, 48, 42, and 44 plus non-page-2 families
(`1032.x` and `463.x`). Shared page-2 indices have matching dimensions and PSM.

## Same-boot correlation

The fresh route's raw input records show Start `buttons=0x8`, Cross
`buttons=0x4000` with pressure 255, and Down `buttons=0x40`, with neutral
sticks between edges. The source-boundary capture then reported:

- MSCAL=211, 48 sprites, TBP `0x2b8d`, TEX0 `0x2005aa459930ab8d`;
- MSCAL=211, 16 sprites, TBP `0x2be0`;
- six MSCAL=3 world groups at TBPs `0x2d7c`, `0x2d8c`, and `0x2c8d`×4;
- stable frame transfer 9, matrix transfer 12, camera-source chain 21151,
  camera-source transfer 508, and `items=8`.

This correlates the differing lookup family with the already-known iPad
AdGif/native resource family rather than proving a native-consumer remap.

## Interpretation

**OPEN.** The first observed mismatch is now the raw logical lookup/page-index
sequence itself. Because shared entries have identical dimensions/PSM but their
order and membership differ, the next falsifiable boundary is directory login
order, FR3/DGO texture ordering, or default texture-page allocation state—not
a TBP remap or renderer-policy change.

## Boundaries

The Simulator remained blank or partially corrupted during this diagnostic
route. This is not visual composition, audio, interaction, playability,
iPhone-parity, or physical-device evidence. The post-route screenshot is
lifecycle/route context only. The dirty maintained upstream worktree remains
user-owned and untouched except for the canonical diagnostic patch mechanism.
