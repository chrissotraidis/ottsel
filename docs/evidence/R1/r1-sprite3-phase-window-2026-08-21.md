# R1 Sprite3 phase window — 2026-08-21

## Gate

Producer-side mobile/macOS Sprite3 phase and resource ownership.

## Identity and proof

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed Simulator executable SHA-256:
  `0ef49f935e271c63d333c555ec85a9186b0c3415abdf885648d5be1fd5de5ac2`.
- Focused `Sprite3Native.*` suite: 12/12 passed.
- One iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`; fault log 0 bytes.

## Before failure

The source comments and earlier diagnostics described bucket 66 as the
Sprite3 stream and bucket 67 as a separate Direct stream. That description
could not explain why the bucket-67 phase classifier saw 3D/world Sprite3
records or why the product walk had to stop at bucket 68.

## Change

Added the trigger-gated read-only file trigger
`ottsel-trace-mobile-sprite-phase-window` in `src/shell/metal_gfx.mm`. For one
chain it classifies the data-address interval 66→67 and then 67→68, logging
the table addresses and ordered phase items. It does not change either
consumer, render path, bucket boundary, or Direct decoding.

## Live proof

The fresh prepared-pack route reached `GAMEPLAY: enter village1` twice. The
window emitted:

```text
OTTSEL SPRITE PHASE WINDOW: chain=14402 vsync=14403 bucket66=0x534970 bucket67=0x532f40 bucket68=0x533b50
SPRITE PHASE: label=bucket66-window groups=0 sprites=0 world=0 hud=0 3d=0 other=0 start=0x534970 next=0x532f40
SPRITE PHASE ITEM: label=bucket67-window group=1 phase=3d count=48 tbp=0x2b8d psm=19 tw=6 th=6
SPRITE PHASE ITEM: label=bucket67-window group=2 phase=3d count=16 tbp=0x2be0 psm=19 tw=5 th=5
SPRITE PHASE ITEM: label=bucket67-window groups=9 sprites=384 world=320 hud=0 3d=64 other=0 start=0x532f40 next=0x533b50
```

The five world groups shown in the bounded item tail used `tbp=0x2c8d`,
`PSM=19`, `tw=5`, `th=5`; the complete summary reports seven world groups
and 320 world sprites. The macOS oracle remains 51 world blocks / 2,432
sprites, beginning with `tbp=0x24f2`, so this is not parity.

## Interpretation

The actual Sprite3 payload begins in the bucket-67 data-address interval, but
the product parser must retain the preceding bucket-66 setup and traverse to
bucket 68. The old numeric bucket label is therefore not a safe phase label.
This does not authorize feeding bucket 67 wholesale to the Direct consumer:
its interval contains Sprite3 MSCAL 211/3 and any Direct records must remain
isolated by packet classification.

## Verdict and next slice

OPEN. The phase window is proven and the maintained app remains signed with no
faults, but mobile still lacks the macOS world phase sequence. The next slice
is to add the same interval ledger to the retained bucket-66 product walk,
including frame/matrix/setup and the first return boundary, then reconcile
the 320-world-sprite mobile window against the macOS 2,432-sprite dispatch.
No texture remap, camera change, or broad bucket ownership change is justified.

## Retained product-walk follow-up

The new product-window trigger was then armed on a second fresh Village1
route. It classified the exact interval used by `render_mobile_sprite_bucket`
(`bucket66.addr` through `bucket68.addr`):

```text
SPRITE PHASE: label=product-66-to-68 chain=17697 vsync=17698
groups=10 sprites=448 world=384 hud=0 3d=64 other=0
start=0xd029b0 next=0xd01b90
```

The ordered resources were two world groups at `0x2d8c`, five at `0x2c8d`,
and one at `0x2b84`, alongside the two 3D groups. This differs from the prior
split-window capture (9 groups / 384 sprites, 320 world), even though both
were fresh Village1 routes. The fault log remained zero bytes.

This is evidence that the outstanding comparison must join the complete
product walk to a shared render-frame/vsync window before declaring a stable
producer mismatch. The next slice is frame-aligned aggregation of the
66→68 product walk against one macOS Sprite3 dispatch, not a bucket or shader
change.
