# R1 launch-owner seam typing correction — R10 — 2026-08-22

## Result

The generated signature for the traced function is:

```text
sp-launch-particles-var
  (function sparticle-system sparticle-launcher vector
           sparticle-launch-state sparticle-launch-control float none)
```

The owner trace is at the function entry and therefore its `a1` argument is
an `sparticle-launcher`, not an `sparticle-launch-control`. The R9 attempt to
read launch-control fields at that address was invalid. The GOAL layout itself
is now established from the sources: `inline-array-class` reserves
`length`/`allocated-length` and begins child data at `0x10`; the control fields
would consequently place `local-clock` at `0x18`, `last-spawn-frame` at
`0x24`, and `last-spawn-time` at `0x28`, but those offsets belong at the typed
control object, not the owner argument traced here.

R10’s raw values demonstrate the mistake rather than a gameplay condition:
`length=0`, pointer-like `allocated-length` values, and inconsistent clock
words were observed while the owner IDs/raw particle records changed from
title-side IDs 1951/1950/1949 (`0x00203500`/`0x00200400`) to Village1 owners
29/28/27 (`0x00200f00`). No renderer, TBP, camera, shader, or Metal-policy
change was made. The invalid timing probe has been removed from the product
source and its temporary patch deleted.

## Fresh visual replay

The signed R10 app replayed the route on the one booted iPad Pro Simulator and
reached Village1 twice. Fresh before/after frames remain visibly rotated and
dislocated, with large black regions, detached vertical geometry, and
oversized colored rectangles. The fault log was 0 bytes. The existing fresh
H.264 capture from the preceding active replay remains at
`artifacts-2026-08-22-ipad-r1-launch-timing-r9/exact-route-timing.mp4`; the R10
host recorder was unavailable because a prior recording session still held
the Simulator recording resource.

Artifacts:

- [R10 runtime log](artifacts-2026-08-22-ipad-r1-launch-timing-r10/ottsel-runtime.log)
- [R10 fault log](artifacts-2026-08-22-ipad-r1-launch-timing-r10/ottsel-fault.log)
- [R10 before frame](artifacts-2026-08-22-ipad-r1-launch-timing-r10/village1-before-timing.png)
- [R10 after frame](artifacts-2026-08-22-ipad-r1-launch-timing-r10/village1-after-timing.png)
- [fresh H.264 capture](artifacts-2026-08-22-ipad-r1-launch-timing-r9/exact-route-timing.mp4)
