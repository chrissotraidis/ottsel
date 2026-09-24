# I3: the touch layout gains its missing D-pad, and the save's own metadata round-trips - 2026-09-22

Gate: I3 (iPad control surface, with an I2 observation).  Question: can a player with no gamepad actually get
through the frontend by touch alone?

**The gap.**  `ottsel_platform_input.h` carries `DpadUp/Right/Down/Left` as their own digital bits and
nothing synthesises them from the analog stick (`ottsel_platform_input.cpp` maps stick axes and buttons
separately), while the game's frontend navigates with `cpad-pressed? 0 down` and friends.  The default touch
layout had regions for both sticks, the four face buttons, start, L1 and R1 - **no D-pad** - so a touch-only
player could open a menu and then not move in it.

**Change.**  `TouchRegion` gains `DpadUp/DpadRight/DpadDown/DpadLeft` between the face buttons and start; the
default layout gets a compact four-square cross at x 0.215-0.385, y 0.395-0.555 (between the left stick and
the middle of the screen, clear of every other region); the overlay colour table gains its violet entry; and
`ShellPadInput::touch` maps the four regions to the same canonical buttons the keyboard and SDL gamepad paths
use.  The layout file stays version 1 and is validated strictly per region, so a previously saved nine-region
layout is simply rejected and the defaults are used.  The diagnostic trigger list gains
`dpad-up/right/down/left`.

**Touch-only navigation proven.**  Launching with no keyboard and driving only the touch trigger:

```
touch start      -> (pad 0x8)    OTTSEL TITLE: start edge in title-wait
touch dpad-down  -> pad0 sample buttons=0x40  -> OTTSEL PC PROGRESS: edge screen=27 index=0
touch dpad-down  -> pad0 sample buttons=0x40  -> OTTSEL PC PROGRESS: edge screen=27 index=1
touch dpad-up    -> pad0 sample buttons=0x10  -> OTTSEL PC PROGRESS: edge screen=27 index=2
touch cross      -> pad0 sample buttons=0x4000 -> accept screen=27 index=1   (LOAD GAME)
```

(The progress log prints the index *before* it applies the move, so the three navigation edges read 0, 1, 2 and
the accept reports index 1 - two downs and one up, consistent end to end.)  The resulting screenshot shows the
load screen and, among the overlay blocks, the four-square diamond of the new D-pad.

**Bonus I2 observation: the save's own metadata round-trips.**  That load screen - reached by touch alone -
lists four slots with three EMPTY and one populated, and it names the save as
`GEYSER ROCK` (the training level's own name) with `9/22/2026` and `15:50`, which is exactly when the save in
this container was written.  The game therefore read the bank's level-name and timestamp fields back out, so
more of the save content round-trips than the file-level check of the previous document showed.  This is still
not state fidelity: no position/progress comparison against a fresh game has been made.

**Multi-touch, and touch all the way into gameplay.**  The trigger now keeps one finger per present region
instead of a single finger, so several regions can be held at once, and the same run completes the route
past the save screen (NEW GAME, D-pad down to an empty slot, Cross - no overwrite prompt) into the level:

```
touch start, cross, dpad-down, cross -> GAMEPLAY: enter training, scene-level='training' (twice)
hold left-stick AND cross together   -> OTTSEL INPUT: pad0 sample buttons=0x4000 left=(167, 107)
                                        right=(127, 127) cross-pressure=255     <- one sample, two fingers
```

So run-and-jump is one gesture on the touch surface, exactly as it is on a pad, and the whole frontend can be
driven into gameplay without any physical input device.

Not claimed: no physical device was used (the trigger and the Simulator are the only input here), save state
fidelity is still open, and the D-pad positions are a first default that a player can move in the layout
editor.
