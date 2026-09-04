# R1 route-valid particle-launch owner correlation — 2026-08-22

## Question

Does the active Village1 route select a later particle/resource producer
family, or does it remain on the early mobile family already observed by the
native source-boundary trace?

## Run identity and method

- One runtime and one booted Simulator only: iPad Pro 11-inch (M4),
  `08636791-2675-4675-8335-EF72EF954DCF`.
- Signed app built from the current diagnostic source and launched on that
  Simulator.
- Replayed the validated route title-wait → Start → Cross → Down×4 → Cross,
  waited for Village1, captured `village1-before-owner.png`, then armed the
  route-valid owner trace while Village1 was active and captured
  `village1-after-owner.png`.
- The trace trigger was armed after gameplay entry, avoiding the earlier
  title-side owner capture. The fault log was empty.

Artifacts:

- [runtime log](artifacts-2026-08-22-ipad-r1-owner-correlation-r8/ottsel-runtime.log)
- [fault log](artifacts-2026-08-22-ipad-r1-owner-correlation-r8/ottsel-fault.log)
- [before frame](artifacts-2026-08-22-ipad-r1-owner-correlation-r8/village1-before-owner.png)
- [after frame](artifacts-2026-08-22-ipad-r1-owner-correlation-r8/village1-after-owner.png)
- [fresh exact-route/settled video](artifacts-2026-08-22-ipad-r1-source-boundary-r5-video/exact-route-settled.mp4)

## Result

Immediately after the post-Village1 trigger, the active owners repeated:

| launcher id | launcher | raw particle | page/index |
| ---: | ---: | ---: | ---: |
| 29 | `0x043c14b4` | `0x00200f00` | page 2 / `0xf` |
| 28 | `0x043c1384` | `0x00200f00` | page 2 / `0xf` |
| 27 | `0x043c11d4` | `0x00200f00` | page 2 / `0xf` |

The same raw value was emitted by the corresponding `is3d=yes` records. No
route-valid owner emitted the later macOS reference raw family
`0x00201e00`, and the native source-boundary records did not transition from
the early `TBP=0x2506` / `first-tex0=0x2004d0e59930a506` family to the accepted
macOS world family `TBP=0x24f2` / `first-tex0=0x2004d1e59930a4f2` during the
capture.

## Interpretation and next falsifiable boundary

This strengthens the producer launch-owner/phase-selection diagnosis. It does
not support a page-directory, FR3, DGO-order, resident-allocation, TBP, camera,
shader, or Metal-policy remap. The raw lookup/resource and particle→AdGif
correlations already match for the captured families; the mobile route is
still selecting/consuming the early producer family.

The screenshots and video remain direct non-playability evidence: the frame is
rotated/dislocated, with a detached vertical band and large blank/black
regions. Build success, empty fault log, and the presence of a Village1 frame
are not playability proof. The next source-side experiment should correlate
the accepted macOS owner/phase sequence against mobile frame-time/particle
launch selection or DMA handoff, without remapping TBP or changing camera,
shader, culling, or Metal policy.
