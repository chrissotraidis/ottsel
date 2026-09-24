# I3: the control surface carries the PS2 button reference, not stand-in letters - 2026-09-23

Gate item: the plan's control layout asks for the PS2 button reference to be recognisable.  The previous rounds
named the controls with short ASCII text (`X`, `O`, `[]`, `TR`, `^`, `>`, `v`, `<`); this round replaces those with the shapes
a PS2 player recognises.

## What landed (src/shell/main.cpp)

The overlay is a triangle list, so a small shape vocabulary is enough:

- `TouchPoint` plus `add_touch_unit_triangle` - a filled triangle given in **unit space** (radius 1) with a
  rotation, mapped into the region as `x = cx + u * radius * aspect`, `y = cy + v * radius`, so a symbol is round on
  screen (the layout stores fractions of each axis) and sized by the region's narrow dimension.
- `add_touch_unit_bar` (two unit triangles) and `add_touch_unit_disc` (a 16-segment fan).
- `add_touch_face_symbol` draws **○** as a disc, **×** as two 45-degree bars, **□** as a filled square and **△**
  as a triangle; `add_touch_dpad_arrow` draws the four arrowheads, rotated per arm.

Each symbol is centred in **its own hit region** at 34% of the narrow dimension and brightens with the held
state exactly as the text labels did, so what is drawn and what is touched cannot drift apart.  The stick,
camera, shoulders and start keep their short text (`STK`, `CAM`, `L1`, `R1`, `ST`) because they are not
symbol-coded controls, and the settings entry keeps its three dots.

## Verified on both profiles

- iPad (`class=tablet surface=1210x834`): `touch-shapes/shapes-neutral.png` shows the four arrowheads on
  the D-pad and ×, □, △ and ○ on the four face buttons, each inside its region; `shapes-cross-held.png` shows the
  Cross region brighter with its × lifted, so the shapes participate in the pressed feedback.
- Phone (`class=phone surface=667x375`): `touch-shapes-phone/phone-shapes.png` shows the same four symbols
  and arrowheads at the smaller surface, each inside its region, with the text marks and the three dots intact.

Lane health in both runs: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`; the touch triggers
used for the held-state capture were removed afterwards.

## Boundary

Proven: the four PS2 face symbols and the D-pad arrowheads are drawn on the control surface, inside their own
regions, on both device classes, and they brighten when held.  The shapes are filled rather than the PS2's
outline art, and VoiceOver accessibility labels for the regions are still open; no audio, device or playability
claim.

