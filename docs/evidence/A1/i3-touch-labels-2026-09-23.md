# I3: the touch surface says which control is which - 2026-09-23

Gate item: legibility of the control surface.  The surface was thirteen flat tints (plus the settings entry's
three dots), so a touch-only player could see where the controls were but not what they did; the plan's control
layout asks for the PS2 button reference to be recognisable on the screen.

## What landed (src/shell/main.cpp)

`add_touch_glyph` / `add_touch_label` emit a glyph as **one quad per lit pixel** of the same column-major
5x7 font the shell status screen already uses (`font5x7.h`, five column bytes per glyph, bit `row` in each),
and `touch_region_label` names the controls: `STK`, `CAM`, `X`, `O`, `[]`, `TR`, `^`,
`>`, `v`, `<`, `ST`, `L1`, `R1`.  The settings entry keeps its three dots as its own label.

They cost only vertices: the overlay's vertices sample a 1x1 white texture with per-vertex colour, so a
three-character label is about forty quads - nothing beside the world's vertex budget, and no pipeline,
texture or bridge change.  Each label is centred inside **its own hit region**, so what is drawn and what is
touched cannot drift apart, and it brightens with the held state (0.85 -> 1.0 alpha, RGB lifted).

## Verification

Capture `/tmp/ottsel-route-2026-09-23/touch-labels/title-labelled.png` (the portrait device frame, so the
surface reads rotated by x'=1-y, y'=x): each label sits inside its region - `STK` in the stick block, `CAM`
in the camera area, `ST` on the start bar, `X`, `[]` and `TR` on the face buttons, the four arrows on the
D-pad cross, `L1`/`R1` on the top bars.

The labels do not disturb the feedback contract from the previous round; the same region-locality check, in the
training level, holding `dpad-up` (fraction of pixels changing by more than 24 per channel, inside each
region's own box, mapped through the same rotation):

    region     control   dpad-up held
    dpad-up       0.0%          73.7%
    (every other region, including the game's own reaction areas)   0.0%

Lane health throughout: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`.

## Boundary

Proven: every control on the surface names itself, inside its own hit region, and the labels participate in
pressed/neutral feedback.  Still open: real button art (the PS2 symbol glyphs rather than ASCII stand-ins),
VoiceOver accessibility labels for the regions, controller handoff, and the Gameplay/Video settings sections.
No audio, device or playability claim.

