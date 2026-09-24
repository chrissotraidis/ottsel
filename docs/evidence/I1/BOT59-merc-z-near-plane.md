# Gate I1 — the MERC near-plane defect (proven 2026-09-11)

The MERC (skinned actor) vertex path placed every vertex nearer than the world
it depth-tests against, so the GEQUAL test rejected the whole model and Jak and
Daxter produced zero fragments. One extra `-1.0` shift was the cause.

## The arithmetic, from live values

Live camera packet (`OTTSEL MERC SETUP[1]`, village1):
`hvdf=(2048,2048,8380365.5,264.3198) fog[0]=-0.036405455
persp2[2]=-8184.262 persp2[3]=-3.5552202e-05 persp3[2]=1.676095e+07`.

`D = fog[0]`, `h2 = hvdf.z`, `p23 = persp[2][3]` (< 0), `p32 = persp[3][2]`.
World path (`tfrag3.vert` + `set_mobile_tie_camera`):

    pc_scale.z = D*p22/8388608 + (h2/8388608 - 1)*p23,  translate.z = D*p32/8388608
    z_world(v) = (-pc_scale.z*v.z - translate.z) / (-p23*v.z) = v.z + 1 + h2/p23

MERC path (`merc2.vert`, scalar-multiplied by `D/w`), same values:

    z = (D*p22*v.z + D*p32)*(D/w) + h2 = v.z + (D*p32 + h2)/p23,  w = p23*v.z
    then /8388608, then **-1.0**:      z_merc(v) = v.z + h2/p23 - 1

So `z_merc = z_world - 2`: exactly one normalised unit too near, behind the
world's near plane and behind everything it must depth-test against. The
`h2/p23` term contributes `+0.9446`: the raw `perspective` matrix already
carries the translation `pc_camera` folds in, so adding `hvdf_offset.z`
double-counts it. The world path survives because `pc_scale.z` bakes the
`-1`; MERC applied a second one.

## Observed before and after the fix

Before: `OTTSEL MERC: clip ledger model='eichar-lod0' vertices=9942 finite=9942
visible=0 clip-x=(-0.3777442,0.59022427) clip-y=(-0.69605064,0.7453661)
clip-z=(-1.1214914,-1.0669475)` — x and y perfectly in range, z out of range in
the same direction for every vertex. `eichar=4 eichar-attempts=4`, frozen for
a whole route.

| mode | z formula | player drawn |
|---|---|---|
| 0 | `z -= 1.0` (shipping) | no |
| 1 | identity | yes |
| 2 | `z = -z` | yes |
| 3 | `z = -z - 1` | yes |
| 4 | `z = z*0.5 + 0.5` | yes |

`eichar` unclogged to 382 -> 472 and climbing. Frames in
`/tmp/ottsel-video/fz{0..4}-v.png`; default-build verification in
`g59-s1-village1-v.png` and `g59-s2-cross-v.png`. `ottsel-fault.log` 0 bytes.

## Limits

Proven: the rejection, and that removing the shift puts MERC at the world's
depth. Not proven: that identity is the exact per-pixel depth the retail GS
produced; modes 1-4 are indistinguishable here. If a MERC-vs-world depth fight
appears later, mode 1 is the term to re-derive. `set_mobile_tie_camera`, TBP,
strip restart and the touch frontend are untouched.
