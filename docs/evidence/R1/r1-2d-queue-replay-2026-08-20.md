# R1 — MSCAL 3 2D transform with complete Metal upload queue

## Result

**OPEN — parser and queue stability progressed; native Sprite3 visibility is
still unproven.**

The signed Simulator executable SHA-256 was
`55337d02f7390c19b3e38addc9f87f76f8855169761cba3ec72280a4ab6366be`. The
focused `DirectFixture.*` regression passed 6/6 before the build. This was a
single bounded iPad Pro 11-inch (M4) Simulator run; the Simulator is now
shutdown.

## Queue boundary

Direct, TIE texture, TIE/TFRAG color-table, and TIE/TFRAG mesh Metal resource
allocations now copy into bounded queues and are drained on the presentation
thread. The replay no longer stopped at `setTieColors` or `setTieMesh` from the
GOAL boot thread. It later ended at the known `CAMetalLayer nextDrawable` /
`SimMetalHost` XPC failure, so that late host failure remains separate from the
Sprite3 transform result.

## Sprite3 evidence

The corrected trace identifies the route as MSCAL 3 / desktop `Sprites2dGrp0`:

```text
frame transfer=9 size=656 imm=0x3d4
matrix transfer=12 size=80 imm=0x384
header transfer=13 count=48
payload vectors=2304 adgif=3840 run-vif=0x14000003 run-kind=20 run-imm=3
first camera=(..., ..., ..., 168.814) 2d-w=168.814 3d-negated-w=-168.814
```

The desktop 2D path therefore retains the camera sign; the earlier 3D-sign
experiment was reverted. Representative bounded candidates were:

```text
candidate=0 index=0 bounds=(13.402,0.994)..(19.211,10.831) usable=false
candidate=2 index=2 bounds=(12.617,2.040)..(19.995,9.785) usable=false
candidate=6 index=6 bounds=(-431.980,-1344.245)..(-428.808,-1340.016) usable=false
candidate=12 index=12 bounds=(1269.592,439.213)..(1270.283,440.133) usable=false
```

All sampled candidates were outside clip space. No `native group=...` or
`cpu-raster=skipped-for-native-candidate` line was emitted. This is a valid
2D-transform attribution and queue-stability increment, not R1 PASS.

## Intermediate-value trace

The next diagnostic-only build was executable SHA-256
`ae52c48002322a8bd9e07e039afff708820e746b00a36b970ffe3f411dbf37e0`.
For a later 2D vector it recorded:

```text
2d q=0.0014598063 base=(2380.2073,2117.3237,18819,232.43417)
fog-min=25.5 scale=(3.126265,3.126265) raw-scale=(0,0)
basis-x=(0.41880882,0,0,0) basis-y=(0,0.24430515,0,0)
xy0=(-0.5,-0.5,0,0)
```

For the adjacent world-space vector, Q was negative and the post-Q base was
`(3200.441,4556.9053,-3763.5,441.40912)` while both raw scales were negative
and clamped to `3.126265`. This makes the next comparison concrete: reconcile
the captured desktop `Sprites2dGrp0` vector/matrix representation and Q
application before changing clip eligibility. The replay still ended in the
known drawable-host XPC failure; no native ownership claim is made.

## Next falsifiable increment

Compare the 2D expansion’s retained `camera`, `Q`, `hvdf`, and rotated basis
values against a captured desktop `Sprites2dGrp0` item. The current camera
values are in the millions while the desktop shader expects the post-Q values
to be screen-space; inspect the matrix/position representation and the Q
application order before changing the clip gate. Preserve the native trigger
and CPU fallback until a candidate is attributable.
