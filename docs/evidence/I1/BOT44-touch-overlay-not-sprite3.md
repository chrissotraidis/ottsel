# BOT44 - the flat rectangles are the touch overlay, not Sprite3

Round BOT44, 2026-09-11. iPad Pro 11-inch M4, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, `com.ottsel.shell`. Method: fresh
`simctl terminate` + `launch` with every `$W/ottsel-*` trigger moved out first,
then layer-subtraction screenshots (`sips -r 270`, rotated 2420x1668) and
programmatic flat-colour detection (one pass, step=2).

## Result: `-scene-no-overlay` removes the rectangles; `-scene-no-sprite` does not

| arm | flat rectangles |
|---|---|
| baseline, no probes armed | present; 30.08% of samples are flat `rgb(0,255,255)` sky, plus quads |
| `-scene-no-sky` | present |
| `-scene-no-sky -scene-no-sprite` | **present**: solid `rgb(166,167,72)` quad bbox `(1696,602)-(2080,766)` `fill=1.000`; grey `(186,186,189)`; pink `(245,172,172)` |
| all three incl. `-scene-no-overlay` | **absent**: nothing above 0.35%; top entries are `rgb(8,10,18)` sky dither |

`no-sprite` alone leaves every rectangle standing; only `-scene-no-overlay`
clears them. The probe log confirms all three latches fired (`scene no-SKY`,
`no-SPRITE`, `world-only overlay probe enabled`).

## Cause: the app's own touch-control overlay

`src/shell/main.cpp` `build_touch_overlay()` emits one vertex-coloured quad per
`TouchRegion` (`LeftStick, Camera, Circle, Cross, Square, Triangle, Start, L1,
R1`) via `add_touch_rect()`; `upload_touch_overlay()` pushes them to
`ottsel_metal_set_touch_overlay`. `metal_shell.mm:2402` binds a 1x1 white
texture and `metal_shell.mm:1678` draws them with the Direct pipeline - a 1x1
white texture modulated by one flat per-vertex colour is exactly a flat solid
rectangle, which is what the detector measures. The palette at `main.cpp:631`
matches: blue `(0.20,0.70,1.0)` LeftStick, yellow `(0.95,0.75,0.20)` Camera,
red `(1.0,0.35,0.35)` x4 Circle/Cross/Square/Triangle, grey `(0.65,0.65,0.75)`
x2 L1/R1. Regions are translucent (alpha 0.16-0.24), so each rectangle takes the
colour of the geometry behind it.

## Why BOT43 said "Sprite3 overlay" - both readings withdrawn

`metal_shell.mm:1592` gates sprite batches on `!sceneNoOverlayProbe &&
!sceneNoSpriteProbe`, so a frame captured with `no-overlay` armed also has
sprites off. BOT43's "no-sprite removes every rectangle" arm therefore had the
overlay disabled too, and the grey/pink colours were read as Sprite3 `rgba`.
Neither reading survives.

Still true from BOT43: the camera and scene are live and the world is correctly
textured (`scene-level='village1'`, `cam-accepted` rising 1:1 with `chain`, one
`merc-submits` per frame); `tbp=0x24f2` 64x64 PSM19 decodes to `alpha-max=0`.

## Confirmed logging defect that taints prior readings

`format` `~D`/`~X` emit nothing here: raw `od -c` at the byte offset of
`OTTSEL PROGRESS: entering` shows `screen= state=` with no digits, while `~A`
and `~S` on the same line render normally. Prior conclusions from an "empty"
numeric field in an OTTSEL print (`request screen=`, `abs= rel=`) are unsupported.

## Not proven

Which rectangle maps to which region index; whether the overlay is intended
product behaviour with the touch frontend enabled; whether any GC sprite renders
visibly. The measured fade term `sx*sy*Q*inv_area` (Q ~ 1e-12 at these camera
distances) is a candidate for invisible sprites, untested.
