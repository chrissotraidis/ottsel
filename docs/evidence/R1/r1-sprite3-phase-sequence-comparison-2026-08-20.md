# R1 Sprite3 phase-sequence comparison — 2026-08-20

| Field | macOS reference | iPad mobile capture |
|---|---|---|
| Source phase order | `Sprite3::render_jak1`: pre-Direct, distorter, frame/matrix setup, 3D, group-0 world, shadow, group-1 HUD | Current mobile parser scans bucket data for frame/matrix and sprite headers, classifies MSCAL 211/3/109/other, but renders only MSCAL 3 group-0 |
| 3D phase | Included in Sprite3 producer sequence; separate draw ownership is not expanded in the current macOS bounded draw ledger | 2 groups, `48+16=64` sprites, MSCAL 211 |
| World phase | `51` group-0 blocks / `2,432` sprites; first world draw TBP `0x24f2` (`9458`) | `8` MSCAL-3 groups / `384` sprites; first/last world TBP `0x2c8d` |
| HUD phase | `3` blocks / `128` sprites | `0` classified HUD sprites in the captured bucket |
| Other phase | Not separately counted in the macOS bounded Sprite3 ledger | `0` classified Other sprites |
| Fault/proof boundary | Mac trace is a behavioral oracle, not mobile parity proof | Prepared-pack route reached Village1; fault log `0` bytes; Simulator blank and non-audible; focused suite `21/21` |

## Decision

The mobile phase classifier is behaving correctly and makes the missing phase
ownership visible. The capture is not a same-phase equivalent of macOS Sprite3:
the mobile bucket ends after a small 3D/world subset and never exposes the HUD
phase. This is still a producer/DMA-chain ownership problem, not evidence for a
TBP remap, shader change, alpha policy, or CPU fallback.

The next falsifiable slice is to trace the mobile bucket-table entries and
CALL/RET chain transitions across the complete Sprite3 dispatch, then align
those boundaries with the macOS pre-Direct/distort/group-0/shadow/group-1
sequence. No native consumer widening is justified until that alignment exists.

No visual, audio, playability, iPhone, or physical-device claim is made. No
protected data, MAP_JIT, runtime executable page, dynamic trampoline, or
external Metal shell was introduced.
