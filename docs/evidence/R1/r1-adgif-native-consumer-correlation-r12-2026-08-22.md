# R1 AdGif → native source-consumer correlation — R12 — 2026-08-22

## Result

On the same fresh Village1 route state, the raw particle, AdGif output, and
native source-boundary traces agree on the captured family:

| boundary | raw/page/index | TEX0 | TBP | other state |
|---|---|---|---|---|
| AdGif output | `0x00200f00`, page 2/index `0xf` | `0x2004c8e55530a5d2` | — | TEX1 `0x120`, clamp `0x1010001c0`, alpha `0x44` |
| native source boundary | — | `0x2004c8e55530a5d2` | `0x25d2` | clamp `0x1010001c0`, alpha `0x48`, `MSCAL=3`, count 48 |

The page-2 lookup was a hit before the AdGif output, and the native boundary
consumed the same TEX0/TEX1/clamp family. This closes the captured lookup,
page-directory, allocation, raw particle→AdGif, and AdGif→native texture-object
branches for this family. The alpha words differ (`0x44` at AdGif output vs
`0x48` at the native source boundary), so the remaining source-side question
is composition/material interpretation after resource resolution, not TBP
remapping or page lookup.

## Visual evidence

The fresh post-trace Simulator frame remains visibly non-playable: rotated and
dislocated scene composition, a detached dark vertical band, large blank/black
areas, and oversized colored rectangles. The fault log is 0 bytes. No camera,
shader, culling, or Metal-policy change was made.

Artifacts:

- [runtime log](artifacts-2026-08-22-ipad-r1-consumer-correlation-r12/ottsel-runtime.log)
- [fault log](artifacts-2026-08-22-ipad-r1-consumer-correlation-r12/ottsel-fault.log)
- [fresh post-trace frame](artifacts-2026-08-22-ipad-r1-consumer-correlation-r12/post-consumer-trace.png)
- [prior fresh H.264 route capture](../artifacts-2026-08-22-ipad-r1-launch-timing-r9/exact-route-timing.mp4)
