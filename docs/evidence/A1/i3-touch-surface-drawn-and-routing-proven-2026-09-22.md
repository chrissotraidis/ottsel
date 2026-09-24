# I3: the iPad touch surface is now drawn by default, and touch routing is proven end to end - 2026-09-22

Gate: I3 (iPad control surface).  Question: on a device with no gamepad, can the player see and use
on-screen controls?

**The gap.**  `TouchLayout g_touch_layout` in `src/shell/main.cpp` has always carried nine default regions
(left stick, camera, circle, cross, square, triangle, start, L1, R1) and `ShellPadInput::touch` has always
mapped a finger to them and published the pad state - but `upload_touch_overlay()` uploaded the vertices
only while `g_touch_editor` was on (the double-tap-Start/F6 layout editor), so a player driving by touch
saw nothing at all.  The surface now follows the input actually in use: it is drawn whenever no physical
device has taken over (`g_native_input_mode` is set by keyboard, gamepad and mouse events), and the editor
only controls whether regions can be dragged.

**The surface really is drawn, at the layout's own coordinates.**  Two screenshots with the surface (3 s
apart, so the animation baseline is included) and one after a native-input event hid it, compared inside the
nine region boxes versus everywhere else, for all four 90-degree mappings of the portrait screenshot:

```
rot   inside(A1 vs B)  outside  inside(anim A1 vs A2)  outside  signal
  0            55.0      58.6            19.7            20.0    -3.2
 90           176.3      50.1             8.0            20.8   139.0   <-- the layout's rotation
180            52.6      58.7            19.4            20.0    -5.5
270            50.2      58.9            17.7            20.2    -6.2
```

Only the rotation that matches the layout shows a signal (mean channel difference 176 inside the regions
against 50 outside, while the animation baseline is flat), so the drawn quads sit exactly on the nine
layout regions.  Independently, the same screenshot describes nine solid blocks whose hues are the layout's
own (blue left stick, amber camera and start, red face buttons, grey L1/R1).

**Touch routing is proven end to end.**  New bounded trigger `ottsel-touch-<region>` drives the *same* path
a finger takes (`handle_touch_editor` then `g_input.touch`): create
`<writable>ottsel-touch-<region>` to press that region's centre and remove it to release (the press is
followed by a small drag so the stick regions deflect).  Driving the frontend only with touch:

```
touch start  -> pad0 sample buttons=0x8     -> OTTSEL TITLE: start edge in title-wait abs=8 rel=8
touch cross  -> pad0 sample buttons=0x4000  -> OTTSEL PC PROGRESS: accept screen=27 index=0   (NEW GAME)
touch cross  -> pad0 sample buttons=0x4000  -> OTTSEL PC PROGRESS: accept screen=18 index=0   (save slot)
             -> the game's own prompt: "A JAK AND DAXTER SAVE GAME ALREADY EXISTS ... DO YOU WISH TO
                OVERWRITE THIS?  YES / NO"   (the earlier save is still in the container)
touch left-stick (press + drag) -> pad0 sample buttons=0x0 left=(167, 107)   (stick deflected from 127,127)
```

So the on-screen surface produces the same pad values as the keyboard path and the game consumes them
through its own frontend.  The left-stick pad state is the same channel that the earlier walking measurement
drove, so movement follows from a touch drag as well.

Operational note for the next run: after `simctl install` the data-container UUID reported by
`get_app_container` can change between calls, so the writable directory must be read *after* the app has
launched (the app's own `OTTSEL RUNTIME BOOT ... writable=` line is authoritative); a trigger written to a
stale container path is simply never seen.

Not claimed: this run ended at the game's overwrite prompt (default NO), so it did not re-demonstrate level
entry; touch was not tested on a physical device, and multi-touch (stick + button simultaneously) is untested
here even though the handler keeps those fingers independent.
