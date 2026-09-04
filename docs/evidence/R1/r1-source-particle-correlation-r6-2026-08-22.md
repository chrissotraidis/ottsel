# R1 source/particle correlation replay — 2026-08-22

| Field | Result |
|---|---|
| Gate | R1 — raw particle/AdGif/native producer ownership |
| Environment | One iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; one runtime, PID `47462` |
| Route | Fresh launch with validated durable pack; title-wait → Start → Cross → Down×4 → Cross; Village1 reached |
| Fault/audio | Fault log 0 bytes; mobile audio remains non-audible/unproven |
| Artifacts | `docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-particle-correlation-r6/` |
| Verdict | **OPEN** — raw lookup/AdGif parity holds for this family; producer phase/data-family ownership remains divergent |

## Correlation

The fresh MIPS2C particle/AdGif output retained these nonzero pairs:

```text
0x00200400 -> 0x2004cfe55530a518
0x00200f00 -> 0x2004c8e55530a5d2
0x00201200 -> 0x2004d0e59930a506
0x00203500 -> 0x2004d0e59930a506
```

The native source-boundary ledger repeatedly consumed the early family as
world `MSCAL=3` and 3D `MSCAL=211`, 48 sprites at `TBP=0x2506`,
`first-tex0=0x2004d0e59930a506`, followed by the 16-sprite zero-texture
record. Frame and matrix hashes changed across chains, but the selected
resource family did not transition to the macOS accepted `TBP=0x24f2` family
within the 128-record/settled window.

This rules out a first divergence in page-2 lookup, resident allocation, or
the raw particle-to-AdGif mapping for the captured families. It narrows R1 to
the producer phase/data-family selection or DMA handoff after those source
values are resolved. No TBP, camera, shader, culling, or Metal-policy remap
was made.

The fresh after-route screenshot shows the continuing rotated/dislocated frame,
detached vertical geometry, and large blank regions. It is explicitly not
playability proof. The expanded settled H.264 route recording is under
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-boundary-r5-video/`.
The next experiment is a producer-owner trace around the transition from the
early `0x2506` family to the macOS `0x24f2` family.
