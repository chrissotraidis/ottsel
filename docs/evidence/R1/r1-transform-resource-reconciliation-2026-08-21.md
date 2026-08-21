# R1 transform/resource reconciliation — 2026-08-21

## Gate

R1 Sprite3 phase and image parity.

## Source and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Latest signed app identity remains the build recorded in
  `docs/evidence/R1/r1-post-village1-bucket-ownership-2026-08-20.md`.
- Mobile environment: one iPad Pro 11-inch (M4) Simulator;
  `08636791-2675-4675-8335-EF72EF954DCF`.
- macOS oracle: `out/jak-project/log/jak1.2026-08-20T16-26-06.log`.

## Before failure

The latest fresh mobile bucket-67 probe saw 384 candidates and uploaded none;
their clip bounds were mostly outside the normalized viewport. A camera or
shader change would be unsafe unless the mobile expansion first diverged from
the desktop Sprite3 shader for an attributable, same-phase record.

## Reconciliation

The maintained desktop `sprite3_3d.vert` 2D path performs:

1. `matrix_transform(camera, position)`;
2. `Q = pfog0 / w` and XYZ multiplication by Q;
3. HVDF addition and `w = max(w, fog_min)`;
4. Q-scaled/clamped SX/SY, rotated basis vectors, and XY lookup;
5. subtract 2048, divide by 256/-128, homogeneous multiply, and the
   `512/448` Y scissor adjustment.

The current mobile expansion in `src/shell/metal_gfx.mm` follows that order.
The live route does not supply a same-phase resource for a final transform
comparison: mobile bucket 67 reports seven world groups at `tbp=0x2c8d`
(`48` sprites each), while the macOS complete Sprite3 frame begins its accepted
world group at `tbp=0x24f2` (`64x64`, `55` sprites) and reports 51 world blocks.
The mobile candidate log therefore cannot distinguish a transform defect from
wrong producer/phase ownership.

## Evidence

```text
mobile phase: chain=51039 vsync=51040
world: count=48 tbp=0x2c8d psm=19 tw=5 th=5 (groups 3..9)
native probe: chain=48943 vsync=48944 drawn=384 candidates=384 fixture-uploaded=false cpu-product-frame=0
macOS: SPRITE3 DRAW frame=1 tbp=9458 sprites=55 blend=2 ztest=2 zwrite=false alpha-test=2 aref=0.000
```

The mobile fault log was zero bytes. The Simulator remained blank and
non-audible; no image-parity or playability claim is made.

## Verdict and next slice

OPEN. This audit does not justify changing camera sign, shader math, clip
eligibility, or texture policy. The next falsifiable slice is a producer-side
mobile/macOS Sprite3 phase/resource ledger that identifies where the mobile
`0x2c8d` groups diverge from the macOS `0x24f2` group sequence. Only after a
same-phase record exists should transformed bounds be compared or native
eligibility changed.
