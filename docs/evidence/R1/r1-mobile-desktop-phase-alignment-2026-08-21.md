# R1 mobile/macOS phase alignment — 2026-08-21

## Gate

R1 same-transition Sprite3 phase sequence and source-item ownership.

## Reconciled evidence

The fresh macOS transition capture and the existing shared-vsync mobile
aggregate now describe the same boundary at different coverage levels:

| Phase | macOS reference | iPad mobile aggregate |
|---|---|---|
| Early producer phase | World group 0: 48 sprites, `MSCAL=3`, first `TBP=0x2506`; group 1: 16 sprites at `TBP=0` | The matching first mobile group is 48 sprites at `TBP=0x2bc1`, followed by the 16-sprite zero-TEX group |
| Later accepted phase | Group 0: 48 at `0x24f2`; group 1: 48 at `0x24f2`; then `0x2525` and `0x25d2` groups; 51 blocks / 2,432 sprites | The accepted shared-vsync walk closes at 9 groups / 384 sprites: 8 MSCAL-3 world groups / 320 world sprites plus 64 MSCAL-211 3D sprites; no HUD phase |
| First later resource | `0x24f2` 64x64 | `0x2c8d` 32x32 in the retained mobile world walk |

The desktop early group’s decoded RGBA hash
`0xc8679915dfac0e15` matches mobile’s `0x2bc1` content. Therefore the
remaining mismatch is not a direct TBP/content-owner defect. Mobile reaches a
valid early producer phase, but its retained 66→68 interval does not expose
the desktop-equivalent post-transition world/HUD coverage.

## Before-failing discriminator

Before any implementation change, the regression must fail on the ordered
phase contract: a shared phase walk should identify the early `48 + 16`
boundary and then either reach the post-transition first-world tuple or report
the exact mobile end boundary. The current mobile aggregate fails the parity
bar by ending at 9 groups / 384 sprites, while desktop reaches 51 world blocks
and later HUD blocks.

## Verdict

OPEN. This is now a producer/DMA-chain phase-coverage dependency. No TBP remap,
camera workaround, shader change, alpha/depth policy change, or broad native
Sprite3 draw enablement is justified.

## Next gate

Add a focused, ROM-safe phase-sequence regression around the shared Sprite3
classifier/ledger that fails before the smallest producer-boundary fix. Keep
the live mobile route as confirmation only; a blank Simulator remains neither
rendering nor playability proof.
