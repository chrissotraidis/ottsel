# R1 pre-armed phase-owner replay — 2026-08-22

## Verdict

**OPEN — producer/DMA phase ownership remains the active boundary.** The
pre-armed source trace and phase-window trace show that the mobile bucket can
present different Sprite3 families at different chain/vsync phases. This is
not evidence for TBP remapping or a camera/shader/Metal-policy change.

## Evidence

- One iPad Pro 11-inch (M4) Simulator, one `com.ottsel.shell` runtime, and the
  same validated durable pack were used.
- The raw particle/AdGif trace was armed before launch. The early aligned
  pairs remained `0x00203500 -> 0x2004d0e59930a506`,
  `0x00200400 -> 0x2004cfe55530a518`, `0x00201200 ->
  0x2004d0e59930a506`, and `0x00200f00 -> 0x2004c8e55530a5d2`.
- The phase-window trigger was also armed before launch. At
  `chain=146`, `vsync=147`, bucket 67 was world-only; its first item was:

  ```text
  phase=world count=48 tbp=0x2506 tex0=0x2004d0e59930a506
  ```

- The same run later submitted the recurring native 3D family
  `TBP=0x24d2/TEX0=0x2004d2e59930a4d2` and
  `TBP=0x2525/TEX0=0x2014cd655530a525`. The macOS oracle remains a different
  first-world phase beginning at `TBP=0x24f2`.
- `GAMEPLAY: enter village1` was reached twice and the fault log remained
  0 bytes. The fresh screenshot remains partial/corrupted and is not
  playability proof.

Raw log and screenshot:
`artifacts-2026-08-22-ipad-r1-phase-owner/ottsel-runtime.log` SHA-256
`6248efd57442b21c7a404018aff8db367324da75759adcf4712a7e6d7c3f3e96`;
`phase-window.png` SHA-256
`ac5657031e4910074455f59e9370f4a91a9754148e5ecbf8db227cf078b4e1d5`.

## Next experiment

Align the complete producer/DMA chain interval and phase list at the first
`MSCAL=211`/`MSCAL=3` transition, then compare the payload owner against the
native consumer. Keep all texture identity, TBP, camera, shader, and Metal
state policies unchanged until that source-side alignment produces a
falsifiable mismatch.
