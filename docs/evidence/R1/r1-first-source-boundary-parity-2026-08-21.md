# R1 first source-boundary parity capture — 2026-08-21

## Result

The fresh signed iPad run armed both the particle trace and
`ottsel-trace-mobile-sprite-source-boundary` before launch, then replayed the
validated title-wait → Start → Cross → Down×4 → Cross route.

The first eligible Village1 source item was:

```text
chain=145 vsync=146 phase=world mscal=3 transfer=13 count=48
tbp=0x2506 psm=19 tw=6 th=6
pfog0=-0.046546843 inv-area=0.10231715
camera-t=(227569.38,47488.31,-5.7278464e9,-31.885628)
frame-transfer=9 matrix-transfer=12
first-tex0=0x2004d0e59930a506 first-tex1=0x120
```

The macOS same-transition reference reports the same first world family:
`first-tbp=0x2506` and raw `0x00203500` →
`TEX0=0x2004d0e59930a506`. The iPad also captured raw `0x00200400` →
`0x2004cfe55530a518`, raw `0x00201200` → `0x2004d0e59930a506`, and raw
`0x00200f00` → `0x2004c8e55530a5d2`, matching the macOS trace.

## Boundaries

The route reached Village1 twice, the page-2 page relocated only once, and the
fault log was empty. Audio mixed but remained `pcm-peak=0`. Fresh screenshot
`/tmp/ottsel-r1-first-boundary-parity.png` has SHA-256
`51a04c5f4e6ff43230c5079dbf76cdfd3be12668b01893663b4035876bab4ed5`.
It shows substantial textured geometry but large missing regions and
diagnostic controls; it is not playable evidence.

This closes the current R1 source/page/TEX0 and first-world-boundary
hypothesis. The remaining gate is native Direct/Sprite/material composition,
followed by audio, lifecycle, touch/controller, iPhone, and physical-device
gates. No TBP remap, camera, shader, or Metal-policy change was made.

## 2026-08-21 — 3D producer-to-DMA boundary capture

A fresh signed iPad replay armed the source-boundary trigger before launch and
restricted it to native MSCAL=211 records so world MSCAL=3 records could not
consume the bounded capture. The first iPad 3D producer record was:

```text
first-tbp=9478 first-size=64x64
first-xyz=-553754.5000,199062.4062,879162.4375,24576.0000
first-flag=0.6402,0.1028,-0.0870,24576.0000
first-rgba=64.0000,54.5059,0.0000,48.0000
```

The corresponding native source-boundary record on the same chain/vsync was:

```text
phase=3d mscal=211 count=48 tbp=0x2506
first-xyz=(-553754.5,199062.4,879162.44,24576)
first-flag=(0.6402084,0.10286378,-0.087075554,24576)
first-rgba=(64,54.505997,0,48)
first-tex0=0x2004d0e59930a506 first-tex1=0x120
```

This is a direct producer→DMA match for the selected iPad family. It also
rules out the native handoff as the first cause of the R1 mismatch. The
completed macOS reference begins its corresponding MSCAL=211 family at TBP
9458 (`0x24f2`), while this iPad route selects TBP 9478 (`0x2506`). The raw
page-2 lookup stream likewise differs: iPad begins `18,15,28,27,3`, while the
completed macOS oracle begins `54,49,48,42,44`. All observed iPad entries are
resident hits with the same page-directory metadata (`dir-length=1610`,
`entry-length=55`, `page-id=2`, identical segment sizes/destinations), so this
capture does not support a simple page-directory corruption or TBP remap.
The next source-side trace must identify why phase/particle-family ownership
selects `0x2506` rather than the macOS `0x24f2` family, including FR3/DGO
ordering and allocation state. No camera, shader, TBP, or Metal-policy change
was made.

Fresh screenshot `/tmp/ottsel-r1-3d-boundary-route.png` has SHA-256
`86a6899e706628ae92e846b9d4a5836c9f01278f52c949c2991bfdaac59fae9d`. It still
has large blank regions and diagnostic color blocks and is not playability
proof. The fault log was 0 bytes; audio mixed but reported `pcm-peak=0`.

## 2026-08-21 — lower-level 3D launch-owner trace

The GOAL queue wrapper was not on this route: it produced no 3D launch trace.
The bounded trace was therefore moved to the actual Jak 1 mips2c
`sp-launch-particles-var` path immediately before `particle-adgif`, gated by
the source `sparticle-system.is-3d` field. The fresh signed replay recorded
the following 3D launch IDs before the first Village1 native packet:

```text
0x00203500 -> page 2 index 53
0x00200400 -> page 2 index 4
0x00201200 -> page 2 index 18
0x00200000 -> page 2 index 0
0x00200f00 -> page 2 index 15
0x00201c00 -> page 2 index 28
```

The first active 3D output selected page 2/index 18, producing TBP `9478`
(`0x2506`). The corresponding native MSCAL=211 source boundary still exactly
matched the producer vector and TEX0. The completed macOS reference’s first
active 3D output is page 2/index 30, TBP `9458` (`0x24f2`), so the first
divergence is now localized to the lower-level 3D launch/particle-family
selection before AdGif/TEX0 generation—not DMA transport or native Metal.

Canonical diagnostic patch: `patches/r1-sparticle-mips2c-launch-owner.patch`
(reverse-check passes). This remains a trace-only change; it does not remap
TBP, alter camera/shader/Metal policy, or change runtime code-generation
behavior.
