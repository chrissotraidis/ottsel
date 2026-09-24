# G2.5/G2.1: the frontend save screen writes, on both lanes - 2026-09-23

Question: does the lane's save path write a memory card, and if an accept writes nothing, which input is
missing?  Driven by `scripts/replay-ios-normal-route.py --accept-slot 0` on a fresh launch
(`SIMCTL_CHILD_OTTSEL_TRACE_INPUT=1`).  The port logs every accept and every held-button frame and index
(`OTTSEL PC PROGRESS: edge/accept screen=...`, `progress-pc.gc:2208/2448`), so this is its own trace:

    edge screen=27 index=0 abs=16384 / accept screen=27 index=0   title -> NEW GAME (`*title*` index 0)
    edge screen=18 index=0 abs=16384 / accept screen=18 index=0   save-game-title, slot row accepted
    edge screen=11 index=0 abs=64 / abs=128                       screen probe reads 11; LEFT answers YES
    edge screen=11 index=0 abs=16384 / accept screen=11 index=0   YES accepted -> `memcard-saving` (13)

The accept on 18 sets `next-display-state` from `(-> s5-0 file index present)` (`progress-pc.gc:2833-2841`):
a present slot goes to `memcard-data-exists` (11), a free one straight to `memcard-saving` (13).  The dialog
row is the `yes-no` option bound to `*progress-state* yes-no-choice`, NO by default and answered only by the
LEFT/RIGHT handlers (`progress-pc.gc:2247/2339`); the second accept enters 13, where `enter!` issues
`auto-save-command 'save` (`progress.gc:279-287`).  After that the port stops printing edges, which is itself
the saving screen: 13 has no `*options-remap*` row, so the nav block carrying the trace is skipped.

## Result (measured, not inferred)

| lane | run | file written | sha1 before -> after | lane health |
| --- | --- | --- | --- | --- |
| iPad Pro 11 M4 | 1 | `bank0.bin` 67584 B | `6b8040a7...` -> `a3599ea8...` | 346 = 346, fault log 0 B |
| iPad Pro 11 M4 | 2 | `bank1.bin` 67584 B | `b4e89c5f...` -> `7513e633...` | 346 = 346, fault log 0 B |
| Ottsel iPhone SE3 | 1 | `bank0.bin` 67584 B | `6b8040a7...` -> `526cfe06...` | 346 = 346, fault log 0 B |

`scripts/verify-ios-save-continue-point.py` reads the written banks as real saves: marker/save_count 3 then 4,
continue-point `title-start`, counters `302900 309275 302900 300580` tracking the run's own clock.  The phone
reached `scene-level='training'` afterwards - a title-screen save starts the game with `intro-start`.

**Read-back, on the same files.**  `--load-slot N` drives the title's LOAD GAME row (`*title*` index 1) and the
load screen (16), whose highlight `enter!` puts on `last-slot-saved`, so slot N is N DOWN presses later.  Slot 1
(bank2, the 09-22 save) loads `cp "training-start"`; slot 0 - this round's file - returns to the title
(`GAMEPLAY: enter title`) and its level start then reads `cp "game-start"`, the documented `title-start` shape.

## Why eleven earlier rounds measured "no writer" - a harness defect, not a product defect

- The overwrite dialog defaults to NO and only LEFT/RIGHT answer it, and the driver answered it with
  `ottsel-hold-dpad-left`.  The shell's holds are `ottsel-hold-{start,cross,left,right,up,down}`
  (`src/shell/main.cpp:1288-1298`) and `dpad-left` is only a *touch* region name, so the file was never read,
  LEFT was never delivered, the dialog answered NO and nothing changed - on both lanes.  The slot branch of
  `scripts/replay-ios-normal-route.py` now uses `left`, and it is one command again.
- A present slot goes to the dialog (11) rather than to `save-game` (17), so the earlier "expect an 18 -> 17
  transition" reading was wrong; the earlier "slot accept wrote nothing on either lane" framing is refuted.
- The save-path map's "hashes byte-identical" baseline (`536a64d5...`) predates this container install; this
  round started from bank0 `6b8040a7...`, bank1 `b4e89c5f...`, bank2 `a71760ab...` on both lanes.  The
  no-auto-save conclusion is unaffected (no `auto-save`/`memcard-saving` screen on plain level entry).

## The bank model this exposed (read in `game/kernel/common/kmemcard.cpp`)
Each save *file* has **two banks**: a save writes bank `file*2 + 4 + p4` with `p4 = last_saved_bank ^ 1` and
`save_count + 1` (lines 240-282), and `pc_update_card` treats the higher count as most recent.  UI slot N uses
banks 2N and 2N+1, so consecutive saves land on different files - run 1 wrote bank0, run 2 wrote bank1, the
same slot 0 at save_count 3 then 4.  The verify tool's old "UI slot N maps to bank<N+1>.bin" line is corrected.

## Boundary

Proven: the frontend save writes and reads back on the iPad and phone lanes, at 346 SIGNED MODULE ENTER = 346
RETURNED with 0-byte `ottsel-fault.log`.  Still open: a save after real mid-level progress (the in-game pause
has no save rows of its own), audibility, and physical devices.  No playability, audio or device claim.
