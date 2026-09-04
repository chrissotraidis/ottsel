# R1 launch timing trace — fresh iPad replay R9 — 2026-08-22

## Question

Does the route-valid 3D launch owner show a divergent `*sp-frame-time*` or
particle-launch clock state that explains why the iPad remains on the wrong
producer/data family?

## Run and visual evidence

- Fresh signed rebuild from the dirty user-owned checkout; strict deep
  codesign verification passed.
- Exactly one booted Simulator/runtime: iPad Pro 11-inch (M4),
  `08636791-2675-4675-8335-EF72EF954DCF`, runtime PID `50203`.
- The clean route segment began with synthetic START at runtime `59:03`, then
  Cross, Down×4, and final Cross. It logged `GAMEPLAY: enter village1` at
  `59:30` and `59:31`.
- A live H.264 Simulator recording was retained across the launch and route.

Artifacts:

- [runtime log](artifacts-2026-08-22-ipad-r1-launch-timing-r9/ottsel-runtime.log)
- [fault log](artifacts-2026-08-22-ipad-r1-launch-timing-r9/ottsel-fault.log)
- [initial frame](artifacts-2026-08-22-ipad-r1-launch-timing-r9/title-initial.png)
- [Village1 before trace](artifacts-2026-08-22-ipad-r1-launch-timing-r9/village1-before-timing.png)
- [Village1 after trace](artifacts-2026-08-22-ipad-r1-launch-timing-r9/village1-after-timing.png)
- [live H.264 capture](artifacts-2026-08-22-ipad-r1-launch-timing-r9/exact-route-timing.mp4)
- [canonical diagnostic patch](../../patches/r1-sparticle-launch-timing-trace.patch)

## Trace result

The trace was armed after the Village1 marker. The first bounded owner records
included launcher IDs 978, 977, 974, and 973, with raw 3D IDs
`0x00000000` and `0x00200000` (page 2/index 0). The sampled
`*sp-frame-time*` words were stable across those records:

```text
frame-time-x=0x0080000c
frame-time-y=0x41400000
```

The added object-field reads for `local-clock`, `last-spawn-frame`, and
`last-spawn-time` are not accepted as semantic values yet: their offsets have
not been independently validated against the generated GOAL layout, and the
captured numbers are implausible for a direct clock interpretation. They are
retained as raw diagnostic output only.

## Interpretation

This run does not falsify the producer-phase/data-family hypothesis, and it
does not justify a renderer, TBP, camera, shader, culling, or Metal-policy
change. It does show that the timing vector itself is available and stable at
the owner seam. The next source-side step is to validate the generated object
layout or log the launch-control fields through a typed GOAL-side path before
using clock values to explain the R8/R9 owner-ID difference.

The fresh frames and video remain direct non-playability evidence: the scene is
rotated/dislocated with oversized textured regions, detached geometry, and
blank/black areas. The fault log is 0 bytes; that is a stability observation,
not a playability result.
