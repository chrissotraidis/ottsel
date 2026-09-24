# Jump works: a measured arc, and the sampling artefact that hid it - 2026-09-22

Gate: I1 (control).  Question: does the Cross/jump control actually move the target?  **Yes - and the
previous turn's "the target never leaves the ground" reading was a measurement artefact, corrected here.**

**Method.**  `scripts/probe-ios-target-control.py <udid> --route --phases ...` drives the route into the
training level and then presses Cross with the shell's hold trigger while the bounded target trace records
`OTTSEL TARGET POS` (one sample in sixteen), `OTTSEL TARGET VEL` (`(-> self control transv)`) and
`OTTSEL TARGET GRAV` (`(-> self control dynam)`).  The velocity line now also prints **immediately**
whenever `|transv.y| > 1000`, which is what makes a short jump impulse visible at all.

**Two runs, seven presses, seven jumps.**  Grouping the impulse samples into arcs and matching each press to
the arc that follows it:

```
presses (pad 0x4000) = 7  -> 7 jumped (3/3 in run 1, 4/4 in run 2)
every arc is the same flight:
  vy +14370  ->  +50185 (apex)  ->  +1033  ->  -15351  ->  -64503 (back to the ground)
  t.y 29713  ->  40371 (apex)   ->  30666
i.e. an arc of ~10.7k-11.4k world units with a sustained rise and fall
```

The three presses before the level loads (the menu's NEW GAME and CONTINUE WITHOUT SAVING) correctly produce
no arc.

**Gravity is set, so the jump's own formula has its input:** `OTTSEL TARGET GRAV: g-len=245760.0000
g-n=(0.0000,1.0000,0.0000)` on every sample.  `init-var-jump` computes the impulse as
`sqrt(2 * gravity-length * height)` along `gravity-normal` (`target.gc:659`), which would have been zero
if `gravity-length` were zero - it is not.

**Why the previous turn read "no vertical motion" (both causes are in my instrument, not the engine):**

1. `OTTSEL TARGET POS` prints one sample in sixteen target-post frames, and a jump lasts roughly half a
   second.  A 2-8 s phase window can therefore contain ground samples only and report a y-range of ~0.4
   units although the jump happened - in these two runs the phase table "saw" 1 of 3 and 2 of 4 jumps while
   the log shows 7 of 7.
2. `OTTSEL TARGET VEL` printed on the same one-in-sixteen cadence, so it reported the standing residual
   (`v=(0.05, 2.00, -0.09)`) and never the impulse; I read "velocity is populated but the position never
   integrates" from samples that simply missed the flight.

The fix was to print the velocity line immediately when the vertical component is large, which catches the
arc regardless of cadence.  The "walking leaves y bit-constant" observation from the previous turn is not
re-measured here and is no longer evidence of an inert axis; a flat stretch of the walked path would explain
it and is the simple explanation.

**Not explained:** the single earlier 8 s Cross window in which neither the position nor the (coarse)
velocity trace showed any impulse - one press out of the eight measured so far.  It is not reproduced by the
seven presses above and it is not evidence of an inert axis, but it is also not dismissed.

Not claimed: no playability acceptance (this is the jump control only), and nothing here changes gameplay
code - the diff is the diagnostic trace and the probe tool.
