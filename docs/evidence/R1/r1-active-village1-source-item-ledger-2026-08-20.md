# R1 active Village1 Sprite3 source-item ledger — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity / producer ownership |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `1630716d6cdd671be1dee6c7b405048d2d9244ede9fd1cc7794a99a089dfbf20` |
| Environment | One iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; shut down after capture |
| Before failure | The earlier mobile phase ledger proved a stable active level but did not identify whether its 48+16 result was a parser-boundary artifact or a producer stream. |
| Change | Added the bounded `OTTSEL SPRITE SOURCE ITEM` fields around the existing Sprite3 phase parser: header VIF words, vector/ADGIF byte counts, MSCAL, first vector, and TEX0. No renderer remap or shader/camera change. |
| Focused proof | `scripts/build-ios.sh`; strict `codesign --verify --deep --strict`; prior focused Sprite3/alias test remained 1/1. |
| Live proof | After repeated `slot0=active`/`slot1=active` samples (`slot1 bsp=0x2ef8754`), the phase and product triggers were consumed. The mobile source stream contained seven groups: six textured groups of 48 sprites at `TBP=0x2c8d`, `PSM=19`, `5x5`, `MSCAL=3`, followed by a 32-sprite `TEX0=0` group. The bounded summaries reported `groups=7 sprites=320 world=320`, with raw spans `bucket67 transfers=23 headers=7 rejected=0 boundary-stops=0` and `product transfers=28 headers=7 rejected=0 boundary-stops=0`. The first two source records had `vec-bytes=2304`, `adgif-bytes=3840`, and identical `TEX0=0x2005a0455530ac8d`. |
| macOS oracle | The same-route macOS capture begins with a 55-sprite flush at `TBP=0x24f2`, `PSM=19`, `64x64`, `TEX0=0x2004d1e59930a4f2`; its broader Sprite3 frame is 51 world blocks / 2,432 world sprites. |
| Fault scan | `ottsel-fault.log` was 0 bytes; no assertion/crash/fault marker appeared. The Simulator remained a blank screen and was not treated as visual or playability proof. |
| Verdict | OPEN. The source-item trace proves the discrepancy is upstream of the bounded mobile phase parser: the mobile producer emits a real, route/frame-dependent 320-sprite stream, not a fabricated 48+16 parser split. It still does not identify the missing producer phase/resource owner relative to macOS. |
| Next gate | Align the same New Game→Village1 producer transition and phase ownership on both platforms, then isolate the first differing source resource or frame setup. Do not remap `0x2c8d` to `0x24f2` without that proof. |

## Raw mobile source samples

```text
OTTSEL SPRITE SOURCE ITEM: label=bucket67-window chain=9796 group=1 count=48
  header-vif0=0x01000404 header-vif1=0x6c018000 vec-bytes=2304 adgif-bytes=3840
  mscal=3 vec0=0x4b8c3e29/0x4ae93117/0x4a828395/0x487e722b
  tex0=0x2005a0455530ac8d
OTTSEL SPRITE SOURCE ITEM: label=bucket67-window chain=9796 group=2 count=48
  header-vif0=0x01000404 header-vif1=0x6c018000 vec-bytes=2304 adgif-bytes=3840
  mscal=3 vec0=0xcac6f91b/0x4af0ecb0/0x4b920373/0x488d9d65
  tex0=0x2005a0455530ac8d
OTTSEL SPRITE PHASE: label=bucket67-window chain=9796 vsync=9797
  groups=7 sprites=320 world=320 hud=0 3d=0 other=0
```

This supersedes neither the earlier active-level 48+16 ledger nor the macOS
oracle; it demonstrates that the producer output varies across active route
frames and must be matched by transition/phase identity before renderer edits.
