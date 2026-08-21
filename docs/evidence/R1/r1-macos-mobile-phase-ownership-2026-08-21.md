# R1 macOS/mobile Sprite3 phase ownership comparison — 2026-08-21

## Gate

Identify the first post-setup Sprite3 phase/resource divergence before native
Metal composition.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream source: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Focused `Sprite3Native.*` regression: 15/15 passed.
- macOS runtime: `out/jak-project/build/h1/game/gk -boot -fakeiso -nosound`.
- Fresh macOS log: `out/jak-project/log/jak1.2026-08-21T03-36-48.log`.
- iPad reference: signed executable
  `663c8e0a5199692835189514046fcac942973f3f4c309986d9df4d4a5a868e8f` on
  one iPad Pro 11-inch (M4) Simulator. Simulator was shut down after capture.

## Live proof

The fresh macOS route reached `title-wait-ready`, consumed the same
Start/Cross/Down×4/Cross route, and reached Village1. Its bounded Sprite3
trace captured three active frames. Frames 5 and 6 shared the setup tuple:

```text
pfog0=-0.036405455 inv-area=0.036767285
basis-x=(0.25105703,0,0,0) basis-y=(0,0.14644994,0,0)
```

The first Sprite3 groups in both active frames were:

```text
group 0: MSCAL=211 TBP=9458 (0x24f2), 64x64
group 1: MSCAL=211 TBP=9509, 32x32
group 2: MSCAL=3   TBP=9496, 32x32
```

The first desktop accepted draw used `TBP=9458` with 31 sprites in the first
draw and the maintained desktop mode `0xfabe26fc` (blend 2, z-test 2,
z-write false, alpha-test 2). The trace then continued through the remaining
world groups and completed with 1,792 world sprites and 128 HUD sprites.

The corrected mobile route separately proved the same frame/matrix setup
contract and captured a post-setup stream beginning with 3D `TBP=0x2b8d` and
`0x2be0`, then world `TBP=0x2c8d`; the stable mobile world record is 32×32.

## Verdict

OPEN. The setup packet and frame/matrix transfer order are not the first
divergence. The first phase/resource ownership sequence itself differs before
native Metal: macOS emits two `MSCAL=211` groups beginning at `0x24f2`, then
`MSCAL=3`; mobile emits a different 3D/resource family and begins its world
stream at `0x2c8d`. This is stronger than a renderer-only hypothesis but does
not yet identify whether the producer's route state, phase source, or DMA
handoff selects the wrong family.

No TBP remap, texture substitution, camera change, shader change, or native
consumer widening is justified. The next experiment is a producer-side
ownership trace at the first `MSCAL=211`/`MSCAL=3` boundary, including the
source chain/table identity and exact route-state marker on both platforms.
The Simulator remained blank and non-audible; no playability claim is made.

## Bucket-65 follow-up

The signed follow-up build added a trigger-gated decode of bucket 65 through
bucket 66. On a fresh title-wait route, the same Village1 phase window showed:

```text
bucket65 -> bucket66: headers=0 groups=0
bucket66 -> bucket67: headers=0 groups=0
bucket67 -> bucket68: MSCAL=3 world groups only
```

The first bucket-67 source item was a 48-sprite `MSCAL=3` group at mobile
`TBP=0x2bc1` (`64x64`) in that run, followed by a zero-texture 16-sprite
record. A prior stable run used `0x2c8d`; both are distinct from macOS's first
`MSCAL=211` `0x24f2` group. The bounded result rules out the immediately
preceding bucket 65 as the owner of the missing phase for this route window,
but does not identify the other chain or phase that emitted the mobile 3D
family in the earlier aggregate. No bucket widening or phase merge is
justified yet.
