# R1 typed launch-control correlation — R11 — 2026-08-22

## Method

- Rebuilt and signed the iPad app with the bounded
  `patches/r1-sparticle-launch-control-timing.patch` diagnostic.
- Used exactly one booted iPad Pro 11-inch (M4) Simulator and one runtime.
- Replayed title-wait → Start → Cross → Down×4 → Cross with the validated
  pack, waited for Village1, armed the existing owner trace, and captured
  fresh before/after frames.
- The trace reads `t0`, which is the fifth argument of
  `sp-launch-particles-var` and is the typed `sparticle-launch-control`.
  Its offsets follow `inline-array-class`’s `0x10` child-data start.

## Observed control state

| phase | control address | length | allocated-length | local-clock raw | last-spawn-frame | last-spawn-time | frame-time x/y |
|---|---:|---:|---:|---:|---:|---:|---|
| title-side owners 1951/1950/1949 | `0x00212734` | 3 | 0 | `0x3f800000` | 49844 | 0 | `0x0080000a` / `0x41200000` |
| Village1 owners 29/28/27 | `0x00212694` | 3 | 0 | `0x3f800000` | 53598 and later increments | 0 | `0x0080000a` / `0x41200000` |

The raw producer transition is the same one seen previously: title-side
owners emit `0x00203500` and `0x00200400`, while Village1 owners emit
`0x00200f00` (page 2/index `0xf`). The control object changes at the same
phase boundary, but frame-time words remain stable and the captured control
fields do not yet identify a divergent timing policy. No TBP, camera, shader,
culling, or Metal-policy remap was made.

## Visual result

Fresh before/after frames show the same direct non-playability failure:
rotated/dislocated composition, a detached vertical band, large black areas,
and oversized colored rectangles. The fault log is 0 bytes. The live H.264
capture from the preceding fresh replay remains available at
`artifacts-2026-08-22-ipad-r1-launch-timing-r9/exact-route-timing.mp4`; the
R11 recorder could not start because the Simulator host still reported an
active recording resource.

Artifacts:

- [R11 runtime log](artifacts-2026-08-22-ipad-r1-control-timing-r11/ottsel-runtime.log)
- [R11 fault log](artifacts-2026-08-22-ipad-r1-control-timing-r11/ottsel-fault.log)
- [R11 before frame](artifacts-2026-08-22-ipad-r1-control-timing-r11/village1-before-control.png)
- [R11 after frame](artifacts-2026-08-22-ipad-r1-control-timing-r11/village1-after-control.png)
- [control trace patch](../../patches/r1-sparticle-launch-control-timing.patch)
