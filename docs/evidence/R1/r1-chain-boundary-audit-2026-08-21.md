# R1 mobile chain-boundary audit — 2026-08-21

## Gate

R1 same-transition Sprite3 phase sequence and source-item ownership.

## Audit result

The mobile consumer is not stopping at bucket 67. In
`gfx_send_chain`, the retained product walk reads the table entries at indices
66, 67, and 68, then calls `render_mobile_sprite_bucket` over
`sprite_bucket.addr` through `next_bucket.addr` (66→68). The diagnostic split
also independently reads 66→67 and 67→68.

Fresh live captures support the source audit:

- The split phase window reached 9 groups / 384 sprites with
  `boundary-stops=0` and `rejected=0`.
- A fresh product window reached 10 groups / 448 sprites, also with
  `boundary-stops=0` and `rejected=0`.
- The shared-vsync aggregate completed one full product walk at 9 groups / 384
  sprites, including 8 MSCAL-3 world groups and 64 MSCAL-211 3D sprites.

The count varies by producer phase, but neither capture indicates a parser
early-stop or a 67→68 boundary rejection. Both remain far below the macOS
`render_jak1` dispatch of 51 world blocks plus HUD blocks.

## Verdict

OPEN. The chain-boundary hypothesis is falsified. The first open dependency is
the GOAL/send-chain producer output before the mobile consumer: at the same
Village1 display boundary, mobile emits a smaller/different Sprite3 data family
beginning at `0x2c8d`, while desktop later emits the accepted world family
beginning at `0x24f2`.

No bucket ownership rewrite, TBP remap, camera change, shader change, or native
renderer widening is justified.

## Next gate

Add a bounded producer-side trace at `send_gfx_dma_chain`/the GOAL render handoff
that records chain identity, table entries, and the first Sprite3 phase tuple
for the same `village1 display-self` boundary. Compare that output with the
desktop `render_jak1` pre-Direct→3D→world→HUD order before selecting a product
fix.
