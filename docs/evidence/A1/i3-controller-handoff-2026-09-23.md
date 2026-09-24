# I3: controller handoff - a gamepad was released every pass, and the path is now verified - 2026-09-23

Gate item: the plan's "controller handoff" (I3), which had never been exercised on this lane because no pad is
attached to the machine.  A bounded virtual-pad diagnostics made the SDL gamepad path testable, and testing it
found a defect that made controller play impossible.

## The defect

The shell acquired a pad on `SDL_EVENT_GAMEPAD_ADDED` and then dropped it in the same pass:
`release_mobile_gamepad("shutdown")` sat **inside the frame loop** (the line before the per-frame drawable
re-query), so every acquisition was followed immediately by `OTTSEL GAMEPAD: pad0 released reason=shutdown
state=neutral`.  With the shell owning no pad, no gamepad button or stick could ever reach the game.  The
call now sits with the other exit calls after the loop (`ottosel_ios_stop_dispatch` and friends).

## The handoff fix

A pad that exists must end up owned.  Acquisition only happened on the add event, so a dropped pad stayed
dropped (a spurious quit that ends the frame loop, a remap, a suspend).  The frame body now re-enumerates at
most once a second while the shell owns no pad, so handoff is self-healing.

## The diagnostics (bounded, off by default)

`<writable>ottsel-virtual-pad` attaches an SDL virtual gamepad (12 buttons and 4 axes; SDL synthesizes the
mapping from the descriptor's mask in ascending order, so the indices are cross(cross-b0), circle(1), square(2),
triangle(3), select(4), start(5), l1(6), r1(7), dpad-up(8), down(9), left(10), right(11)); per-button files
`ottsel-virtual-pad-<name>` and per-axis files `ottsel-virtual-pad-stick-left|right|up|down` are the states,
mirroring the keyboard hold triggers.  Two details were needed and are on record: the diagnostics keeps **its
own** joystick handle (`SDL_GetJoystickFromID` / a borrowed handle is closed with the shell's gamepad and then
silently drops every button), and it claims pad 0 while present, because this environment already exposes a
device named "Gamepad" that otherwise keeps pad 0 and receives nothing the trigger sends.

## Verification (everything below went through the virtual pad)

    route:  OTTSEL TITLE: start edge -> accept screen=27 index=0 -> edge screen=18 index=0..3
            -> accept screen=18 index=4 -> GAMEPLAY: enter training
    stick:  pad0 sample buttons=0x0 left=(0, 127)  and the target moved (-66766.5, -233.0) at pad-max=1.0
    handoff: detach -> attach -> a Cross press still reaches the game
             (pad0 sample buttons=0x4000 ... cross-pressure=255)

Lane health: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log` throughout.

## Boundary

Proven: the SDL gamepad path (discovery, mapping, buttons, analog stick, detach and re-attach handoff) works
end to end, and the defect that blocked it is fixed.  Not proven: physical hardware - the virtual pad exercises
the same code path a real controller takes but is not a device, so G2.7/D1 still owns that claim.  The
diagnostics stays opt-in behind its file trigger.

