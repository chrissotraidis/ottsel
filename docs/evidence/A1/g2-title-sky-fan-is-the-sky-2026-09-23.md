# G2.2: the fan is the title's sky; the gate relaxation was tried, measured and reverted - 2026-09-23

Carried item: the title's banded/rainbow sky, and the question of which draw fills the title's sky region.

## Measured: the title's sky is the fan

Same run, same title, one variable - the existing `ottsel-trace-sky-skip-draw` control - read through a
sky-only strip of the capture (app-space sky mapped into the portrait device frame by x' = 1-y, y' = x):

    fan drawn    meanRGB=(63.1,144.4,233.6)  blueish=91.5%   high-chroma=87.0%
    fan skipped  meanRGB=(27.6, 27.6, 32.7)  blueish= 0.0%   high-chroma= 2.7%

The capture pair is unambiguous (blue sky with terrain in front, against near-black), so the title's sky **is**
the fan: skipping it removes the sky rather than revealing another producer.

## The early frames agree, on both profiles

Two launches per profile, the skip trigger set before the app launched for the control, captures from 0.3 s
after `title-wait-ready` through 15 s:

    iPad  1210x834   fan: s00 (109.3,178.9,236.5) blue=91.4% ... s14 blue=91.4%
                     skip: every capture (27.6,27.6,32.7) blue=0.0% dark=88.3%
    phone 667x375    fan: s00 (105.0,178.6,236.5) blue=91.4% ... s14 blue=91.3%
                     skip: every capture (27.6,27.6,32.7) blue=0.0% dark=88.3%

There is no early window in which another draw fills the sky: with the fan the sky is blue and drifting to a
sunset from the first capture, and without it the region is the same constant fill at every moment, on both
profiles.  The carried "fan first-frame garbage" reading is therefore not reproducible on this source.
Artifacts: `/tmp/ottsel-route-2026-09-23/title-sky-earlyipad-{fan,skip}/` (iPad, 1668x2420) and
`title-sky-early-{fan,skip}/` (phone, 750x1334).

## The gate relaxation, tried and reverted

The title window also carries the `after-setup-qwc == 6` form of the same bucket (same start pointer, same
64-byte setup, one extra qword), which the sky path's `qwc == 5` condition rejects.  I relaxed the condition,
measured it, and reverted it: on the un-relaxed build the settled title's sky strip is already blue (blueish
91.1%, high-chroma 86.3%), so the earlier banded/rainbow reading is not reproduced here and the change had no
evidence behind it.  The comment beside the condition records the attempt and the reason.

## Two method findings

1. `OTTSEL SKY SHAPE` is **racy**: the same bucket start reads both `after-setup-qwc` values within one
   run (the probe walks a chain the game is rewriting), so its `qwc` field cannot classify a bucket - that is
   how "the title is the qwc==6 form" and "the producer runs at the title" were both readable from it.
2. Rectangular sky windows are confounded by the logo and terrain (the wide band read 21.8% high-chroma with the
   fan and 21.7% without; the edge strip 86.3% before and 87.0% after).  The frame-edge strip used above is
   sky-only, which the control proves by returning a flat fill.

## Boundary

Nothing landed this round: the source is the verified state with the relaxation reverted, and the code comment
beside the condition carries the evidence.  No audio, device or playability claim.

