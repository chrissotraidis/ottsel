# I3: the on-screen controls name themselves to the accessibility layer - 2026-09-23

Gate item: accessibility labels for the touch regions (I3 frontend completion).  The shell draws its own
controls into the Metal layer, so UIKit had nothing to name: VoiceOver saw an unlabelled game surface.

## What landed

`src/shell/metal_shell.h` declares `OttselAccessibilityRegion {x,y,w,h,label}` and the two bridges
`ottssel_metal_set_accessibility_regions` / `ottssel_metal_log_accessibility`.  `src/shell/metal_shell.mm`
adds `OttselAccessibilityView`, a transparent container laid over the Metal view that never takes a touch
(`hitTest:` returns nil) and answers the container protocol UIKit uses (`accessibilityElementCount` /
`accessibilityElementAtIndex:` / `indexOfAccessibilityElement:`) with one `UIAccessibilityElement` per region
carrying a spoken label, the button trait and a frame in the container's own space.  `src/shell/main.cpp` maps
each `TouchRegion` to a full word (`Movement stick`, `Camera look`, `Circle`, `Cross`, `Square`, `Triangle`,
`D-pad up/right/down/left`, `Start`, `Left shoulder`, `Right shoulder`, `Settings`) and republishes them from
`upload_touch_overlay`, so the elements follow the drawn surface - the same layout, safe-area and class changes
that move the regions - and are cleared when the surface is hidden.  A bounded `ottsel-trace-a11y` trigger asks
the container what it holds and prints it.

## A correction on record

The first cut flipped the frame's Y (`1 - y - h`), assuming UIKit's origin was opposite the overlay's.  It is
not: `add_touch_rect` maps a region's y=0 to clip y=+1 (the top of the drawable), and UIKit is also top-left
origin, so the element box *is* the drawn box.  Measured with the flip in place, `Start` (surface y 0.075) was
reported near the bottom and `Movement stick` (0.605) near the top; without it, `Start` reads y=62.55 and the
stick y=504.57 on the 834-tall surface, which is where they actually draw.

## Verification

Trigger-driven, no VoiceOver client needed (the container answers the same queries the OS would):

    iPad   class=tablet surface=1210x834  container-elements=14 view-frame=(0,0,1210,834)
           i=0  'Movement stick' (66.550,504.570,157.300,137.610)   i=10 'Start' (520.300,62.550,169.400,45.870)
           i=6  'D-pad up'       (332.750,329.430, 60.500, 45.870)   i=13 'Settings' (750.200,62.550, 72.600,45.870)
    phone  class=phone  surface=667x375   container-elements=14 view-frame=(0,0,667,375)
           i=0  'Movement stick' (30.015,219.375,126.730,86.250)    i=10 'Start' (290.145,6.750, 86.710,43.125)

Independent of the log, the frame was checked against the screen: holding `ottsel-touch-dpad-up` paints that
region near-opaque, and the a11y frame for `D-pad up` mapped through the capture rotation lands on it - iPad
mean (251.4,250.5,249.9) with 95.4% of pixels > 235 inside the box against (89,45,24)/(68,41,15) in the scene
immediately left and right; phone mean (251.3,250.4,249.9) with 94% bright, same contrast.

Lane health: iPad and phone each 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`,
`scene-level='village1'`; the feedback log shows `mask=0x40` while the D-pad-up trigger is held, back to `0x0`.

## Boundary

Proven: every on-screen control is published to the accessibility layer with a spoken label and a frame that
matches where it draws, on both device classes.  Not proven: VoiceOver activation routing (the elements carry
the button trait but `accessibilityActivate` is not wired to the touch path), and the outer shell sources are
still reconstructed by no overlay patch (the documented hunk-level gap).  No audio, device or playability claim.
