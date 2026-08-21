# R1 ordered Sprite3 group/resource mapping — 2026-08-21

## Gate

Map the first missing mobile Sprite3 group/resource against the macOS dispatch.

## Identity

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed Simulator executable SHA-256:
  `6cf0c7ca32e042a20a8d283fccb663f446a388e08141e102fc76f7d6536088eb`.
- Focused `Sprite3Native.*`: 12/12 passed; strict codesign passed.
- Mobile: one iPad Pro 11-inch (M4) Simulator;
  `08636791-2675-4675-8335-EF72EF954DCF`.
- macOS oracle: `out/jak-project/log/jak1.2026-08-20T16-26-06.log`.

## Before failure

Mobile and macOS had only been compared by aggregate counts and isolated TBP
examples. The next change required identifying the first ordered phase/resource
divergence in one shared-vsync mobile boundary.

## Live proof

After the fresh route logged `GAMEPLAY: enter village1` twice, the aggregate
closed at `vsync=39092`, `chains=1`:

```text
groups=9 sprites=384 world=320 hud=0 3d=64 other=0
item 0: 3d    count=48 tbp=0x2b8d psm=19 tw=6 th=6
item 1: 3d    count=16 tbp=0x2be0 psm=19 tw=5 th=5
item 2: world count=48 tbp=0x2d7c psm=19 tw=6 th=6
item 3: world count=48 tbp=0x2d8c psm=19 tw=6 th=6
item 4: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 5: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 6: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 7: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 8: world count=32 tbp=0x2c8d psm=19 tw=5 th=5
```

The macOS same-route dispatch begins with a 3D item at decimal TBP `9710`,
then its first accepted world draw is decimal TBP `9458` (`0x24f2`), 55
sprites, followed by world TBPs `9953`, `9478`, and other phase-owned groups.
Thus the first divergence is resource/state ownership within the 3D/world
phase, before any native Metal clip or image comparison. The fault log was 0
bytes.

An earlier aggregate at `vsync=27101` occurred before the current fresh route's
valid Village1 boundary because a persisted host waiter armed its trigger from
an old log marker. It is explicitly excluded from this mapping.

## Interpretation

The mobile phase order is structurally 3D → world, but neither its initial 3D
TBPs nor its first world TBP/resource sizes match the macOS dispatch. This is
now a concrete producer/resource-phase mismatch, not an inferred camera or
shader defect.

## Verdict and next slice

OPEN. Do not remap TBPs or feed more phases into Metal yet. The next falsifiable
slice is trace the mobile producer's source/data-root and Sprite3 frame setup
that selects the first 3D/world resource tuple, then compare that setup with
the macOS `Sprite3::handle_sprite_frame_setup` and first `flush_sprites` state.
Keep the CPU consumer diagnostic-only and preserve the Direct boundary.
