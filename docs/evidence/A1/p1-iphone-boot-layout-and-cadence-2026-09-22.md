# P1: the iPhone lane boots, routes and runs - and it was reading the tablet touch layout - 2026-09-22

Gate P1 (iPhone parity).  Question: does the accepted iPad route run on one iPhone profile, and what
differs?  The iPad lane was stopped first (`xcrun simctl shutdown 08636791-...`); exactly one Simulator was
booted, iPhone 16 Pro / iOS 18.5 (`12A4163C-33A0-4936-8024-77A6D36698C5`), same strict signed-GAME control
as the iPad lane (`config/signed-game-cgo-tit-vi1-control.json`, 346 ENTER = 346 RETURNED, `ottsel-fault.log`
0 bytes).  Install `out/jak-project/out/ios/app/OttselShell.app` -> `scripts/import-ios-user-data.sh <udid>
/tmp/ottsel-user-pack` (1.5 GB) -> `SIMCTL_CHILD_OTTSEL_TRACE_INPUT=1 xcrun simctl launch`.

**The phone boots to the title and plays.**  It reaches `OTTSEL TITLE: title-play received wait; entering
title-wait` and renders the title with its village background (the device surface is 1206x2622 portrait
because the app's landscape-only contract rotates the content; the drawable is 874x402).  The touch-only
route runs end to end: Start -> `edge screen=27 index=0` -> Cross -> `accept screen=27 index=0` (NEW GAME)
-> D-pad down -> `edge screen=18 index=0` -> Cross -> `GAMEPLAY: enter misty` / `village1` / `training`
with `scene-level='training'` and eichar 17 -> 2065.  `/tmp/ottsel-p1/phone-route-land.png` shows Jak
mid-jump over the training level with the touch surface drawn on top.

**Defect found: the layout class was resolved before the surface existed.**  `g_touch_layout_path` was
computed from `g_surf_w` ~20 lines *before* the CAMetalLayer reports its drawable, so it used
`kSurfWDefault` = 1024 and every device took the tablet file.  Measured with both files present in the
phone container (phone opacity 0.5 / tablet 1.0): the phone logged `loaded persistent layout
...touch-layout-tablet.cfg`.  Fix: `refresh_touch_layout_path()` re-resolves the path from the current
surface width on every size change - boot, the first Metal drawable, and the per-frame resize block
(`src/shell/main.cpp`).  After it, with the same two files present: phone `...touch-layout-phone.cfg`,
iPad `...touch-layout-tablet.cfg`.  The save side follows the same variable: three `saved persistent
layout ...phone.cfg` lines and the phone file mutated by an editor drag (circle 0.785 0.615 -> 0.865 0.575,
start 0.43 0.08 -> 0.59 0).

**Surfaces, measured from the driver's own present log** (`simctl spawn log show`): phone
`presentRGBA 874x402 layer-drawable=874x402`, iPad `presentRGBA 1210x834 layer-drawable=1210x834`, so the
phone presents 2.87x fewer pixels (351k against 1009k).

**Cadence.**  In the training level the phone holds 45 fps at `game-time-ratio=1.000` (vsync 541 -> 1171,
90 frames per 1.7-2.5 s) and 22-26 fps at ratio 3.000 later in the same level when the host load rose; the
title/village window reads 11-45 fps.  That is the iPad lane's band at 2.87x fewer pixels - no phone-specific
cadence defect, and no fps claim (the host carries the Codex app).

**Two defects found and NOT fixed (next P1 items).**
(1) *The compiled default table cannot be persisted.*  Its triangle row is `0.965 0.665 0.055 0.055`, so
x+w = 1.020 and `load_touch_layout()`'s bounds check rejects the whole file - so an editor save (which
writes the whole table) is silently discarded on the next boot.  A/B on the iPad with one otherwise
identical file: triangle 0.965 -> no load line, triangle 0.945 -> `loaded persistent layout ...tablet.cfg`.
(2) *The layout editor can be entered by touch but not left.*  While `g_touch_editor` is set,
`handle_touch_editor` consumes every finger event, so the Start double-tap that toggles it never reaches
`g_input.touch`; only F6 exits.  Measured: the second double-tap produced no `editor=off` line and instead
dragged and saved the Start region.

**Phone reachability numbers for the next step.**  Regions are fractions of each axis, so on the 874x402
surface the face buttons are 48x22 pt and the D-pad arms 44x20 pt against 67x46 and 61x42 pt on the iPad's
1210x834 - the same region is less than half the tap height on the phone.

Not claimed: no physical device; no audio audibility; save-state fidelity untouched.  Test state removed -
neither container has a persisted layout file now, so both lanes are on the compiled defaults.
