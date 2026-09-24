# I3: the touch surface now shows pressed/neutral feedback - 2026-09-23

Gate item: the I3 frontend requirement "pressed/neutral feedback" on the control surface.  Before this round
the overlay drew thirteen flat translucent tints from a layout walk and never reflected input; the shell-owned
surface a touch-only iPad player sees looked identical whether or not the game was receiving a button.

## What landed

`src/shell/main.cpp`: `ShellPadInput::pressed_region_mask()` derives the held set from the same state that
routes input (the stick, camera and action fingers), so feedback cannot disagree with what the game is handed;
`build_touch_overlay(int pressed_mask)` lifts a pressed region toward white and deepens its tint;
`update_touch_overlay_feedback()` runs once per frame after input and the touch triggers and rebuilds plus
re-uploads only when the mask changes, so the steady-state cost is one integer compare.  Neutral rendering is
unchanged.  A bounded log (20 lines) records the mask and the pressed region's actual RGBA.

## Data proof (one run, `ottsel-runtime.log`)

    OTTSEL TOUCH: feedback mask=0x0    vertices=78 uploaded=1                      (neutral)
    OTTSEL TOUCH: feedback mask=0x100  vertices=78 uploaded=1  region=8  color=(0.970,0.910,0.990,1.000)
    OTTSEL TOUCH: feedback mask=0x40   vertices=78 uploaded=1  region=6  color=(0.970,0.910,0.990,1.000)
    OTTSEL TOUCH: feedback mask=0x1000 vertices=78 uploaded=1  region=12 color=(0.930,0.930,0.950,0.970)
    OTTSEL TOUCH: feedback mask=0x0    vertices=78 uploaded=1                      (release)

78 vertices is 13 regions x 6; each press rebuilds and uploads, and the pressed region's alpha goes from the
neutral 0.18-0.24 to 0.97-1.00 with the RGB lifted 80% toward white.

## Pixel proof (matched captures, no input vs held)

Method note that cost this round two wrong readings: the shell's surface is **landscape**
(`OTTSEL TOUCH: class=tablet surface=1210x834`, Info.plist landscape-only), while `simctl io screenshot`
captures the **portrait** device frame, so an app-space layout box (x, y, w, h) appears in a capture at
x' = 1-(y+h) .. 1-y, y' = x .. x+w.  Measured fraction of pixels changing by more than 24 per channel, inside
each region's own box:

    region     control   dpad-up held   r1 held
    dpad-up       0.0%          89.2%      0.0%
    r1            0.0%           0.0%     97.2%
    (every other region, including the game's own reaction areas)   0.0%

So a held region changes its own box and nothing else, and the no-input control pair changes nothing anywhere -
the scene in the training level is static enough that a 0.28%-of-frame quad is unambiguous.  The first triple
attempt measured nothing because the harness released the trigger *before* the screenshot; that is fixed in the
probe (hold through the capture).

## Boundary

Proven: pressed/neutral feedback exists, is region-exact, costs one mask compare when idle, and is logged within
a bounded budget.  Not claimed: labels/art for the regions (the surface is still flat translucent tints), the
settings entries, audibility and physical devices.

