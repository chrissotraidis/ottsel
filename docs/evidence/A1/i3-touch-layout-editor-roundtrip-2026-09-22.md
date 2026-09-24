# I3/P1: the touch layout editor round-trips on a touch-only device - 2026-09-22

Gate I3 (frontend/controls), the piece P1's layout rework depends on.  Question: can a player with no
keyboard open the touch layout editor, move a region, leave the editor and get the same layout back after a
relaunch?  The previous document measured two "no" answers; this one fixes both.

**Defect 1 - the app could not persist its own default layout.**  The compiled default table's triangle row
was `0.965 0.665 0.055 0.055`, so x+w = 1.020 and `load_touch_layout()`'s bounds check rejected the whole
file; since the editor saves the whole table, the first save was silently discarded on the next boot.  The
default triangle is now `0.945` (right edge exactly on screen), and `save_touch_layout()` runs every region
through `clamp_touch_region()` - w,h clamped to [`kTouchRegionMinSize`, 1], x,y to [0, 1-w] - so every state
the editor can produce is loadable by construction.  The loader keeps the same bounds and only gains a
`kTouchRegionBoundTolerance` = 1e-4 of slack so a clamped 1.0 cannot be rejected by float rounding.

**Defect 2 - the editor could be entered by touch but not left by one.**  While `g_touch_editor` is set,
`handle_touch_editor()` returns true for every finger event, so the Start double-tap that toggles it (which
lives on the game-input path) could never run; only F6 closed it.  The double-tap now lives in a shared
`start_double_tap()` that both the game-input path and `handle_touch_editor()` consult, so the gesture that
opens the editor also closes it.

**Measured on both device classes**, one lane at a time, each from a container with zero layout files, same
strict signed-GAME build (phone iPhone 16 Pro 874x402, iPad Pro 11-inch M4 1210x834):

```
baseline                     load lines = 0                     (compiled defaults in memory)
double-tap Start             OTTSEL TOUCH: editor=on layout=...touch-layout-phone.cfg / ...tablet.cfg
press+drag a region          OTTSEL TOUCH: saved persistent layout ...touch-layout-phone.cfg
double-tap Start             OTTSEL TOUCH: editor=off layout=...
restart                      OTTSEL TOUCH: loaded persistent layout ...   <- the pre-fix build never got here
```

The saved file is the compiled default table with the triangle clamped to `0.945 0.665 0.055 0.055` and the
dragged region moved (circle `0.785 0.615` -> `0.865 0.575`), i.e. the write is the clamp plus the edit.

**Negative control - the validator was not loosened.**  Writing the pre-fix row back into the same file
(`0.965`) and relaunching gives 0 load lines, so an out-of-bounds file is still refused; the fix is the
default value and the save-side clamp, not a wider check.

**Regressions.**  A single Start tap still reaches the game after the double-tap refactor
(`OTTSEL TITLE: start edge in title-wait`, `entering screen=27 state=27`), and the iPad lane still reports
346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='village1'` and a 0-byte `ottsel-fault.log`.  The
overlay-coverage guard and the `.ret` guard both PASS.

**Not claimed.**  The loaded regions were not pixel-compared against their pre-relaunch positions in this
run (the evidence is the reload line plus the file's content); the phone still uses the shared default
*sizes*, so its face buttons are 48x22 pt and its D-pad arms 44x20 pt - the reachability item is the next
step.  No physical device was used.
