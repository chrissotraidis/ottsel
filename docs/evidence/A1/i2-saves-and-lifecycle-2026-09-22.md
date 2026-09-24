# I2: a save is written and loaded back, and the background/foreground round trip is handled - 2026-09-22

Gate: I2 (saves, lifecycle).  Both were listed as open; both are now measured on the strict lane.

## Saves: write and load round trip

**Method.**  The same menu probe drives the frontend by its own markers, and the screen numbers are
`progress-screen` enum values from `goal_src/jak1/engine/ui/progress/progress-h.gc`: **27 = title** (the PC
menu), **18 = save-game-title**, **16 = load-game**.

```
save:  57:24 kernel: "OTTSEL F1: save root=.../OpenGOAL/jak1/saves"
       51:1x OTTSEL TITLE: start edge in title-wait -> activate-progress ... master=progress
             accept screen=27 index=0        (title menu: NEW GAME)
             accept screen=18 index=0        (save-game-title: slot 1, previously EMPTY)
       -> .../saves/BASCUS-97124AYBABTU!/bank0.bin   67584 bytes
load:  accept screen=27 index=1               (title menu: LOAD GAME)
             accept screen=16 index=0        (load-game: the file list, slot 1)
       -> GAMEPLAY: enter title -> enter village1 -> enter training, scene-level='training'
          bank0.bin mtime unchanged (15:50) - the load reads, it does not rewrite
```

So the whole file path works on the iOS lane: the save is written to the F1 save root in the game's own
memcard format, a fresh process recognises it, the load-game screen lists an entry and accepting it enters
the level.  Fault log 0 bytes throughout.

**Not proven - state fidelity.**  This save was taken from the NEW GAME flow, so the saved state *is* the
level's start state and a load of it is indistinguishable from a new game by observation.  Showing that a
load restores a *progressed* state needs an in-game save (pause menu or a checkpoint save) and a
position/progress comparison; that is not done here.  The game does implement this path -
`goal_src/jak1/engine/game/game-save.gc` opens with "The game-save system implements the 'background
autosave' feature", there is a `save-game` screen (17) beside the `save-game-title` one (18) this run used,
and `no-auto-save`/`auto-save-count` are part of its state - but the realistic trigger is mission progress,
which this lane cannot reach yet.

## Lifecycle: background and foreground

**Method.**  With the game running in the training level, launch Settings to background it, then relaunch
the game to foreground it, reading the shell's own lifecycle lines and the lane's counters.

```
background (Settings launched):
  OTTSEL LIFECYCLE: background input neutralized and audio paused
foreground (game relaunched):
  OTTSEL LIFECYCLE: foreground controller rechecked and audio resumed
after the round trip:
  scene-level='training', chain advancing, ottsel-fault.log 0 bytes
  a held stick still reaches the pad: OTTSEL INPUT: pad0 sample buttons=0x0 left=(0, 127)
```

So the port's intent handling fires in both directions, the lane survives the round trip, and input is
consumed again afterwards.  Note that the game keeps rendering while backgrounded on this host (vsync
advanced 901 -> 991 across the background window); whether iOS would suspend it on a device, and how the
port behaves on suspension, is not tested here.

Not claimed: audibility (see `i2-audio-pcm-measured-device-open-blocks-2026-09-22.md`), device behaviour,
long-session stability, and no change to gameplay code - the lane under test is the same build described in
the previous documents.
