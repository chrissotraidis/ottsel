# P1: the phone's safe-area insets are measured and the class defaults respect them - 2026-09-22

Gate P1 (safe areas), the item the previous document left open because the stick and the L1/Start/R1 bars
sit where the sensor housing is on an iPhone.

**Seam.**  `ottsel_ios_shell_safe_area(left, top, right, bottom)` (`metal_shell.mm`, declared in
`ios_boot.h`) reports the key window's safe-area insets as *fractions of that window's bounds*, so they share
the touch layout's coordinate space and cannot drift when the CAMetalLayer reports points x contentsScale.

**Use.**  `clamp_touch_region_to_safe_area()` shrinks a region only when the usable strip is narrower than
the region and otherwise just moves it, so the size a class table asked for survives.  The shell applies it
to its *own* class defaults as soon as the drawable exists, retrying until the platform answers, and skips a
persisted layout entirely - those regions are the player's.  The metrics line now carries `safe-lrtb`.

**Measured** (same build, one lane at a time):

```
phone  OTTSEL TOUCH: defaults kept out of the safe area lrtb=62x0x62x21
phone  OTTSEL TOUCH: class=phone  surface=874x402   min-region=48x46 safe-lrtb=62x0x62x21
iPad   OTTSEL TOUCH: class=tablet surface=1210x834  min-region=60x46 safe-lrtb=0x24x0x25   (defaults already clear)
```

iPhone 16 Pro landscape therefore reserves 62 pt on **each** side (the housing does not make the layout
asymmetric, so one placement serves both landscape orientations) plus 21 pt at the bottom for the home
indicator; the iPad Pro 11-inch M4 reserves 24 pt at the top and 25 pt at the bottom and nothing at the
sides.

**What the clamp did, read from the app's own layout file** (opening the editor once makes
`save_touch_layout()` write the live layout).  Against the phone table and the 62/62/21 insets, 11 of 13 rows
came out exactly as arithmetic predicts, with no size change anywhere:

```
stick    x 0.045 -> 0.0709   (62/874, moved out of the housing strip)
cross    x 0.880 -> 0.8601   (1 - 62/874 - 0.069)
triangle x 0.880 -> 0.8601
the other nine rows unchanged
```

the two rows that differ from the prediction are the regions the probe itself dragged while the editor was
open.  On the iPad the clamp is a no-op: every tablet region already clears 24 pt top and 25 pt bottom.

**A persisted layout is not touched.**  With that dumped file in place and the app relaunched, the log shows
`loaded persistent layout ...touch-layout-phone.cfg` and *no* `defaults kept out of the safe area` line,
which is the skip working as designed.

**Routes after the change.**  Phone, touch only, with the clamped layout: Start -> `TITLE: start edge` ->
`entering screen=27`, Cross -> `accept screen=27 index=0`, then through the save flow to
`GAMEPLAY: enter training` with `scene-level='training'` (`/tmp/ottsel-p1/phone-safearea-gameplay-land.png`).
iPad: the same route to `GAMEPLAY: enter training`, 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte
`ottsel-fault.log`.

**New open item, measured on both lanes.**  NEW GAME writes a save, and the *next* NEW GAME lands on a
`~0LYES ~30LNO` confirmation that neither Cross nor the D-pad moved in this probe, while the save screen
still lists 4 x `NONE`: the save is on disk (`OpenGOAL/jak1/saves/BASCUS-97124AYBABTU!`) but not in the
game's own slot list, and the flow ping-pongs 18 <-> 11 at index 0.  Clearing that save returns the flow to
normal, which is how both routes above were completed; whether the port's save *read* path or the dialog's
cursor is at fault needs its own turn.

**Limits.**  These are simulator insets, so a device measurement is still owed for D1.  Both containers were
left with no persisted layout and no saves (the test saves are kept under `/tmp/ottsel-p1/`).
