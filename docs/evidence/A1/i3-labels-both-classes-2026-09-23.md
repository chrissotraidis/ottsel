# I3/G2.5: the labelled surface fits both device classes, and the phone profile is checked - 2026-09-23

Gate items: I3 (the labelled control surface, landed on the tablet class last round) and G2.5 (the phone
profile must hold the accepted checks).  The labels were sized for the tablet, and the phone's regions are
narrower, so this round makes the geometry class-agnostic and checks the phone.

## What changed (src/shell/main.cpp)

- **The label fits its own region**: `pixel_y = min(region.h / (kFontH + 2), 0.82 * region.w / (label_units *
  aspect), 0.0115)`.  A fixed pixel overflowed the phone's 0.055-wide D-pad arms; the fit is derived from the
  region the label belongs to, so the tablet's wide bars and the phone's narrow arms both work.
- **Glyphs are square on screen**: the layout stores fractions of *each* axis, so a square needs
  `pixel_x = pixel_y * (g_surf_h / g_surf_w)`.  Without it a glyph is stretched by the surface's aspect
  (1.45x on the tablet, 1.78x on the phone).
- **The overlay is rebuilt when the drawable size changes.**  Both the safe-area clamp and the label aspect are
  derived from the surface size, so keeping the first size's vertices left a stale geometry after a resize.

## Verification

**Phone profile** (Ottsel iPhone SE3, `OTTSEL TOUCH: class=phone surface=667x375 min-region=37x43`):
capture `/tmp/ottsel-route-2026-09-23/phone-labels/phone-title-labelled.png` shows every label inside its own
region on the small class (`STK`, `L1`, `CAM`, `ST`, `X`, `O`, `[]`, `TR`, `R1` and the four D-pad
arrows), and `phone-settings-sections.png` shows the settings section list (CONTROLS, AUDIO, DATA & SAVES,
DIAGNOSTICS, CLOSE) rendering at 667x375; the run logged `OTTSEL SETTINGS: screen open` and `screen closed`
through the touch path.

**iPad regression on the same build** (`class=tablet surface=1210x834`): `ipad-title-labelled.png` shows the
same labelled surface, `ipad-settings-sections.png` the same section list, and `ipad-held-dpad-up.png` the
held D-pad cell visibly brighter than its neutral neighbours, so the pressed/neutral feedback verified last
round is intact with the new geometry.

Lane health in both runs: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`.

One judged limit of this round: the fit is a construction (the size is computed from the region's own box), and
the captures confirm it, but the label pixels were not isolated by a matched A/B this time - the region
locality of the *feedback* was measured last round, and this change touches only label geometry.

## Boundary

Proven: the control surface names itself and fits on both device classes, and the settings entry renders and
responds on both.  Not claimed: gameplay acceptance, audio, physical devices, or the still-missing region art
and VoiceOver labels.

