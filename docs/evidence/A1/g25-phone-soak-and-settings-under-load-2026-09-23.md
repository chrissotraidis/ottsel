# G2.5/G2.4: a phone soak with the settings surface exercised under a live game - 2026-09-23

Two gaps this closes: the phone lane had no sustained-play evidence (and is the only lane where a fault has
been seen), and the settings surface had only ever been driven at the title, never while a game was running.

## Method

Launch the phone lane, drive the accepted route to Training (`replay-ios-normal-route.py`, exit 0), then sixteen
30-second ticks of input through the shell's hold triggers (stick holds, D-pad taps, Cross taps) with three
insertions: **tick 4** the settings surface (touch `menu` -> CONTROLS -> a Cross step on SURFACE OPACITY -> close),
**tick 9** a lifecycle round trip (Settings backgrounds the app, relaunch foregrounds it), **tick 12** the
diagnostics toggle (touch `menu` -> DIAGNOSTICS -> LOG OVERLAY on -> close -> capture -> back off).  Per tick: the
`pad0 sample` lines, `scene-level`, the fault-log size, and a screenshot every second tick.

## Result

    every one of the sixteen ticks: scene=training, fault=0        (fault history: sixteen zeros)
    modules: 346 SIGNED MODULE ENTER = 346 RETURNED;  scenes: village1 (route), training (all ticks)
    input reaching the game: 1-2 pad samples in fourteen ticks (the two D-pad ticks log no sample because
    that line only prints when the pad state moves)
    target trace over the session: 312 samples spanning (-4482456, 3461459) at pad-max 1.00
    lifecycle: "background input neutralized and audio paused" -> "foreground controller rechecked and audio
               resumed", with input continuing afterwards

Settings under load (tick 4):

    OTTSEL SETTINGS: screen open level=0 visible=AUTO music=100 log=0
    OTTSEL SETTINGS: changed section=CONTROLS row=SURFACE OPACITY value=100%
    OTTSEL SETTINGS: screen closed visible=AUTO music=100 log=0

The value was already at its 100% cap, so that step clamped - the flow, the redraw and the save ran, and no
visible change is claimed.

Diagnostics under load (tick 12):

    OTTSEL SETTINGS: changed section=DIAGNOSTICS row=LOG OVERLAY value=ON
    OTTSEL SETTINGS: screen closed visible=AUTO music=100 log=1

and `phone-soak/soak-logoverlay-12.png` shows the shell's own log surface - the `ottsel S2.0 - Metal` header,
`GPU path: Metal` and the live log tail with timestamps - filling the screen over the running game, which is
what that row is for.  The toggle was then turned back off so the soak continued over the game.

## Boundary

Proven: on the phone class the lane holds a bounded gameplay session with sustained input (~4.5 M / 3.5 M units
of target movement), survives a background/foreground round trip, keeps taking input, and reports no fault in
eight minutes; and the settings surface and the diagnostics log overlay both work while a game is live, with the
settings file written (`settings-phone.cfg`).  Not claimed: audibility, physical devices, or device-side
cadence - the ~8 fps here is this Simulator's.

