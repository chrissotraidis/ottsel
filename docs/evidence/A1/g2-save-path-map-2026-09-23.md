# G2.5 save path: what is verified, what is refuted, and where the pause menu comes from - 2026-09-23

Gate G2.5 asks whether the accepted route, the G2.1 save/load sequence and the system checks hold on the
phone profile.  This note is the map of the save path as it now stands, assembled because the findings had
accumulated line by line.

## The menus, both tables verified in source

`goal_src/jak1/engine/ui/progress/progress-static.gc` holds the layouts compiled into ENGINE.CGO/GAME.CGO:

    *main-options* (line 11)  0 game-options 1 graphic-options 2 sound-options 3 load-game 4 save-game 5 quit-game 6 back
    *title*        (line 54)  0 new-game -> save-game-title  1 load-game  2 options -> settings-title  3 back
    *options*      (line 79)  0 game-options 1 graphic-options 2 sound-options 3 back

`goal_src/jak1/pc/progress-pc.gc` mirrors these for the PC/iOS path and adds an auto-save row:
`*main-options-pc*` (line 113) is the same order with 4 save-game, 5 disable-auto-save, 6 quit, 7 back.

`*options-remap*` in `progress.gc` binds screens to tables: `settings -> *main-options*`,
`load-game -> *load-options*`, **`save-game -> *save-options*`**, **`save-game-title -> *save-options-title*`**,
`title -> *title*`, `settings-title -> *options*`, `auto-save -> *ok-options*`, every `memcard-*` screen.
The port's own file re-binds `settings` to `*main-options-pc*` (or the secrets variant when cheats are known)
at `pc/progress-pc.gc:2053`.

The `progress-screen` enum continues past `title 27` with **`settings-title 28`, `auto-save 29`**, the PAL
screens, `no-disc 32`, `bad-disc 33`, `quit 34`, `max 35`.

## Verified on the lane

- **Screen 28 is `settings-title`, and it cannot save.**  Driving the title with long holds worked
  (`accept screen=27 index=2` = OPTIONS) and landed on `edge screen=28 index=0..3`; the table bound to it is
  the 4-entry `*options*`, which has no save row, so the probe wrapped through 0-3 and wrote nothing.
- **The title's NEW GAME is the lane's save screen.**  `*title*` index 0 is `new-game -> save-game-title`
  (the `screen=18` the route reaches).  Accepting a slot there goes to the overwrite dialog (11) when that
  slot already holds a save and is answered with D-pad LEFT, and that path writes the memcard - measured
  2026-09-23 on both lanes, `docs/evidence/A1/g2-save-write-2026-09-23.md`.
- **Entering a level does not auto-save.**  The route reached Training (346 ENTER = 346 RETURNED, 0-byte
  fault log) with all three memcard hashes byte-identical (bank0 `536a64d5fdec8da8`,
  bank1 `39757c172fef9c5b`, bank2 `a8ad9b0968e5e902`, mtimes Sep 22) and no `auto-save`/`memcard-saving`
  screen logged.  `game-save.gc:1176` shows the auto-save does have its own screen (29), so its absence is a
  real absence, not a naming gap.
## The in-game pause: it *does* save - the "no option rows" reading was incomplete

The pause activates `progress-screen fuel-cell` (`engine/game/main.gc:127`), `*options-remap*` binds
**nothing** for `fuel-cell`/`money`/`buzzer`, and the pause draws the level task list, so it really has no
option rows - which is why every probe that pressed a face button left `index` at 0.  Rows were never needed,
though: `respond-progress` pushes `progress-screen settings` (3) straight out on CIRCLE
(`progress.gc:1128-1135`), and screen 3 is bound to the main options table whose index 4 is `save-game`.  The
earlier probes could not press CIRCLE because no hold trigger exists for it.  Measured end to end 2026-09-23,
in-level: `docs/evidence/A1/g2-ingame-save-2026-09-23.md`.

## Next

Superseded in part by `docs/evidence/A1/g2-save-write-2026-09-23.md`: the frontend save screen writes (both
lanes) once the dialog's LEFT/YES answer is delivered, and each slot is double-buffered over banks 2N/2N+1.
What is still open here is a save after real mid-level progress (the pause has no save rows), not the write.
Harness rule on record: hold each button until the game acts; fixed short holds do not register.

Not claimed: nothing here is a playability, audio or device claim.
