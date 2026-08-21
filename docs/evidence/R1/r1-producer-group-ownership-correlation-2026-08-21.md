# R1 producer group ownership correlation — 2026-08-21

## Gate

R1 source-item/group ownership and phase selection before native composition.

## Identity

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Desktop binary: rebuilt `game/gk` after adding the bounded group ledger.
- Desktop focused test: `./build/h1/goalc-test --gtest_filter='Sprite3Native.*'`,
  14/14 passed.
- Mobile app identity and route are from
  `r1-resource-content-identity-capture-2026-08-21.md`.

## Change

The desktop Sprite3 trace now records world group ordinal, DMA chunk start,
sprite count, MSCAL, first TBP/TEX0, and dimensions. This is diagnostic-only;
it does not alter bucket traversal, culling, texture lookup, or rendering.

## Correlated evidence

The valid fresh desktop trace recorded:

```text
desktop world group=0 count=48 mscal=3 first-tbp=9478 (0x2506)
desktop first-tex0=0x2004d0e59930a506 size=64x64
desktop rgba-hash=0xc8679915dfac0e15 alpha-max=128 nonzero-alpha=2615
desktop world group=1 count=16 first-tbp=0
```

The synchronized mobile trace recorded:

```text
mobile group=0 count=48 mscal=3 first-tbp=0x2bc1
mobile tex0=0x2005a8459930abc1 size=64x64
mobile rgba-hash=0xc8679915dfac0e15 alpha-max=128 nonzero-alpha=2615
mobile group=1 count=16 first-tbp=0
```

Thus the mobile `0x2bc1` and desktop `0x2506` records are the same decoded
texture content in different VRAM addresses and TEX0 packing. The retained
accepted macOS world phase remains `0x24f2` with content hash
`0x03be77a789505b65`; that is a later/different phase, not the same group-0
record as the mobile capture.

## Verdict

OPEN, corrected. A direct texture-owner mismatch is not proven. The first
proven divergence is phase selection/transition: mobile begins the captured
world window at the content represented by desktop `0x2506`, while the
accepted macOS world oracle begins at `0x24f2`. No TBP remap, camera correction,
shader change, or native policy widening is justified.

## Next gate

Capture one fresh macOS trace after the same synchronized New Game -> Village1
transition with a reliable current-log selector, and align the complete
world-group sequence (`0x2506`-family -> `0x24f2`-family) against mobile group
ordinals and DMA bucket boundaries. Add a regression only if that phase handoff
shows a concrete missing transfer or producer-state contract.

