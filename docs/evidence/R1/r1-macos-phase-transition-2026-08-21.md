# R1 macOS Sprite3 phase transition — 2026-08-21

## Gate

R1 same-transition Sprite3 phase sequence and source-item ownership.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Rebuilt native macOS `game/gk`; focused `Sprite3Native.*` passed 14/14.
- One Windowed macOS runtime, `-boot -fakeiso -nosound`; no Simulator
  concurrent.
- Fresh log: `out/jak-project/log/jak1.2026-08-21T02-38-46.log`.

## Before failure

The preceding timestamp-selected window captured only the desktop producer
phase matching mobile: world group 0 at `TBP=0x2506`, followed by a 16-sprite
`TBP=0` group. The accepted desktop `TBP=0x24f2` world phase was not present
in that immediate window, so the missing dependency was the transition itself,
not a justified texture remap.

## Change

Kept the existing diagnostic-only desktop group ledger and armed it twice in
one runtime: once for three frames after the Village1 markers, then again
after a 15-second settled delay. The ledger records group ordinal, sprite
count, MSCAL, first TBP/TEX0, dimensions, and draw buckets. No product
renderer behavior or game content changed.

## Focused proof

```text
./build/h1/goalc-test --gtest_filter='Sprite3Native.*'
14 tests passed
```

The macOS runtime completed both trace windows without a crash, signal, or
renderer assertion. The only `assert` matches in the log are startup object
and code-map names (`assert-h` and `assert`), not assertion failures.

## Live proof

Fresh frames 1–3 at `[39:06]` remained in the pre-transition phase:

```text
world group=0 count=48 mscal=3 first-tbp=9478 (0x2506)
first-tex0=0x2004d0e59930a506 size=64x64
world group=1 count=16 first-tbp=0
```

The first texture decoded to RGBA FNV
`0xc8679915dfac0e15`, alpha max 128, with 2,615 nonzero-alpha texels.
This is the same decoded content previously observed on mobile at
`TBP=0x2bc1`. The frame hashes were `0x8a1fea02f6db4b93`,
`0xe04edddb07b1efc6`, and `0x8a1fea02f6db4b93`.

Fresh frames 4–6 at `[39:21]`, after the settled delay, crossed the phase
boundary:

```text
world group=0 count=48 mscal=211 first-tbp=9458 (0x24f2)
first-tex0=0x2004d1e59930a4f2 size=64x64
world group=1 count=48 first-tbp=9458 (0x24f2)
world group=2/3 first-tbp=9509 (0x2525) size=32x32
world group=4 first-tbp=9682 (0x25d2) size=32x32
```

The accepted post-transition frame completed 51 draw blocks and 2,432
sprites. Its first accepted bucket used `TBP=9458` with 55 sprites; later
draws included `9953`, `9478`, `9509`, `9686`, `9682`, `9395`, `9393`, and
`9401`. This is the first synchronized proof of the `0x2506 -> 0x24f2`
transition and identifies the producer-group ordinal change.

## Verdict

OPEN. Desktop is not missing the accepted resource: it emits the mobile-
matching `0x2506` phase first and later emits the accepted `0x24f2` phase.
The concrete mobile dependency is now to determine whether its 66->68 bucket
walk reaches the equivalent post-transition group sequence. No TBP remap,
camera workaround, or native renderer widening is justified.

## Next gate

The existing shared-vsync mobile aggregate now supplies that alignment:
mobile closes at 9 groups / 384 sprites, with 8 MSCAL-3 world groups beginning
at `0x2c8d` and no HUD phase, while desktop reaches the 51-block post-transition
world sequence beginning at `0x24f2`. Add a before-failing producer phase
regression around this ordered boundary before considering a fix. See
`docs/evidence/R1/r1-mobile-desktop-phase-alignment-2026-08-21.md`.
