# I2 state fidelity: an in-level save restores its own continue point - 2026-09-22

Gate I2 (saves), the board's open `NEXT`.  The board's proposed method - move Jak, save, load, compare
the *position* - cannot work for Jak 1, and this run proves why: the save records a continue point and
the run's counters, not the player's world transform.  The load-relevant state is therefore the
continue point, and that is what was compared.

**The save carries no transform.**  The target's own position trace at the loaded spawn is
`t=(-5393129.0000,28317.4628,4362849.5000)`, and that float triple appears nowhere in `bank0/bank1/
bank2` (searched as float32 words).  Every bank instead holds an ASCII continue-point name in its own
body at `+0x4c0` (block 0x10400 = McHeader 0x400 + bank 0x10000, two copies per file, the second copy
unwritten) plus counters at `+0x470/+0x480/+0x490/+0x4a0`; `bank2`'s `+0x470` = 339985 is exactly the
`game-base=` value the lane's own `OTTSEL SUBMITSTAT` reported in the same session, so those are the
run's clock fields.

**An in-level save was written.**  The in-game pause wheel is the progress screen: `up/down` scroll
levels and only CIRCLE opens settings (`respond-progress`, `progress.gc:1133` -> `progress-screen
settings`).  Driven by the file triggers it reports `edge screen=3 index=4` / `accept screen=3
index=4` (SAVE GAME), the save screen shows slot 0 = `GEYSER ROCK 9/22/2026 18:21` and slots 1-3
`EMPTY`, and saving into slot 1 wrote a new `bank2.bin` (67584 B).  So UI slot 0 maps to `bank1.bin`
and slot 1 to `bank2.bin`; `bank0.bin` is the auto-save card.

The two banks record different continue points, and each slot restores its own after a relaunch:

| UI slot | bank | continue point in the bank body | lane after TERMINATE -> launch -> load |
|---|---|---|---|
| 0 | `bank1.bin` | `title-start` | `GAMEPLAY: enter title` -> `village1` -> `training`, `CAMERA START: cp "game-start"` |
| 1 | `bank2.bin` | `training-start` | `GAMEPLAY: enter training`, `CAMERA START: cp "training-start"` |

Slot 1 is the fidelity claim: the string the in-level save wrote into its own body (`training-start`)
is exactly the continue point the lane reports after a terminate/relaunch/load of that slot, and it
differs from slot 0's, so the loaded state comes from the save rather than from a level default.
`ottsel-fault.log` is 0 bytes in both load runs and both resolve `scene-level='training'`.

**State.**  iPad lane (`08636791-2675-4675-8335-EF72EF954DCF`, iPad Pro 11-inch M4), one Simulator at
a time, strict signed 346-module build.  `bank2.bin` is the test artifact and was left in the
container.  Not claimed: progress-counter fidelity beyond the continue point (the counters track the
run clock), audible output, the phone lane, physical devices.

**Tool.**  `python3 scripts/verify-ios-save-continue-point.py <writable-dir> [--log <ottsel-runtime.log>]
[--slot N --expect-cp NAME]` prints each bank's recorded continue point and counters and the lane's own
load sequence, so the next save/load check is one command.
