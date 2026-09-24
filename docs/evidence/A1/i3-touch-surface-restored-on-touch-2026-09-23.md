# I3: the touch surface comes back when touch is the input again - 2026-09-23

Gate item: I3's touch surface, found while capturing an in-level acceptance frame - the frame came back with **no
controls drawn**, and the log named the cause.

## The defect

`ShellPadInput::keyboard()`, `mouse_motion()` and `mouse_button()` all call
`hide_touch_overlay_for_native_input()`, which sets `g_native_input_mode` and clears the surface.  Nothing ever
cleared that flag, so one keyboard, mouse or gamepad event removed the touch controls **for the rest of the
run**.  On the iPad lane that is a real playability hazard: the surface is the only control a touch-only
player has, and the lane does see stray host events (the log shows `OTTSEL INPUT: native keyboard/mouse
active; touch overlay hidden` at 15:06, after which every capture was control-less).  The harness's own
`ottsel-hold-*` triggers reproduce it, because they inject through the same keyboard path.

## The fix (src/shell/main.cpp)

A `FINGER_DOWN` now clears `g_native_input_mode` before the region hit-test.  `SURFACE VISIBLE = AUTO` is
documented as "follows the input actually in use", so a touch means touch is in use again; the frame loop's
existing upload gate (`!g_touch_overlay_uploaded && !g_native_input_mode && g_frame >= 60`) then rebuilds and
re-uploads the surface with no other change.

## Verification (same build, in level, matched A/B)

Holding `ottsel-hold-stick-left` (keyboard path) then releasing, then one `ottsel-touch-cross`; the overlay is
detected by counting its own left-stick tint (82,204,204) in the capture:

    after the keyboard hold, before any touch   0 overlay pixels      (surface gone)
    after one touch                          74,595 overlay pixels    (surface back)

The in-level acceptance stills (`/tmp/ottsel-accept/acceptance-inlevel*.png`) then show the controls drawn over
live gameplay (74,608 / 75,739 tint pixels), which is the frame the earlier keyboard-driven route could not
produce.  Lane health: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`,
`scene-level='training'`.

## Boundary

Proven: AUTO no longer loses the touch surface permanently, on a matched in-level A/B.  Not proven: that a
physical gamepad or keyboard being actively used should keep the surface hidden while a touch is in flight -
the flag is per touch-down, so the surface follows whichever input arrived last.  No audio, device or
playability claim here.
