# G2.1: the in-game pause saves, and it was never a dead end - 2026-09-23

Question: can a player save *mid-level* on this lane, and does that save record the state it was taken
in?  This was the loop's remaining G2.1 increment ("a second save after real mid-level progress").

## The claim this refutes

The save-path map concluded the pause cannot save: it activates `progress-screen fuel-cell`
(`engine/game/main.gc:127`), `*options-remap*` binds nothing for `fuel-cell`/`money`/`buzzer`, and
the pause draws the level's task list (`pc/progress-pc.gc:3609-3611`), so it has no `game-option` rows
to accept and blind probing moved nothing.  **Refuted**: those rows are irrelevant, because
`respond-progress` pushes another screen outright on CIRCLE (`progress.gc:1128-1135`):

    ((cpad-pressed? 0 circle)
     (logclear! ... circle) (sound-play "start-options")
     (push! this)
     (set! (-> this next-display-state) (progress-screen settings)))

and `progress-screen settings` (3) *is* bound to the main options table, whose index 4 is `save-game`
(`*main-options*` / `*main-options-pc*`, `pc/progress-pc.gc:2053`).  The pause is the entry point, not
the dead end - which is what the 2026-09-22 "pause wheel -> CIRCLE -> SAVE GAME" evidence said before
the map talked itself out of it.

## Why the harness could not press it

The shell maps Circle to the `E` key, but the hold table has no Circle row (`src/shell/main.cpp:353-355`
maps E/F/R to circle/square/triangle; the hold list at 1288-1298 has start, cross, left, right, up, down and
the stick directions), so no hold trigger could deliver it.  `ottsel-touch-circle` already drives the real
finger path - the one an iPad player uses - so the probe uses that.

## The measured run (one launch, `scripts/probe-ios-ingame-save.py --route`)

    gameplay  held left stick: n=29 pad-max=1.0 displacement=(-71327.5, -1490.5) length=71343.1
    start     -> OTTSEL PROGRESS: entering screen=0                       (pause: fuel-cell)
    circle    -> a DOWN probe reads edge screen=3 index=0                 (settings)
    down x4   -> edge screen=3 index=0..3, then accept screen=3 index=4   (the SAVE GAME row)
    cross     -> accept screen=17 index=0                                 (in-game save-game rows)
    down      -> edge screen=11 index=0                                   (overwrite dialog)
    left,cross-> memcard-saving (13)                                      (the write)

`bank0.bin` changed: `a3599ea8...` -> `01a8adfd...` (67584 B, mtime 05:36:24), and
`scripts/verify-ios-save-continue-point.py` reads it as save_count **5**, continue-point
`training-start`, counters `311565 323780 311355 302313` - the saved clock equals the lane's own
`game-base=311565` at the save, at 346 SIGNED MODULE ENTER = 346 RETURNED with a 0-byte fault log and
`scene-level='training'`.

The bank choice is the double-buffer rule again: `bank1` held the higher count (4), so this save went
to `bank0` at count 5 (`game/kernel/common/kmemcard.cpp:240-282`).
A repeat run of the same probe (the landed file, second launch) moved the target 70741.5 units and wrote the
*other* bank of the same slot - `bank1.bin` `7513e633...` -> `bcd64b1b...`, save_count 6, continue-point
`training-start`, counters `311620 323810 311415 302324` - so the in-game write reproduces and obeys the
same double-buffer rule.
Reloaded after termination, slot 0 restores that same point: `--load-slot 0` reports `cp "training-start"`
and enters `training`, so the mid-level save round-trips through a relaunch.
## Boundary

Proven: a mid-level save writes a valid bank whose continue point and clock match the run it was taken
in.  Still open: audibility (Simulator CoreAudio), the renderer items, frontend settings, and physical
devices.  No playability, audio or device claim.

