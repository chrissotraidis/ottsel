# I2: the overwrite dialog is answerable by touch, and save metadata survives a relaunch - 2026-09-22

Gate I2 (saves), the item the safe-area document opened as `memcard-data-exists` and every later NEW GAME
landing there.

**The dialog is answerable; my probe was pressing the wrong way.**  Screen 11 is
`progress-screen memcard-data-exists` with `*yes-no-options*`, and the choice lives in
`*progress-state* yes-no-choice`.  Only the **left** and **right** D-pad handlers touch it
(`progress.gc:890-900`: `(cpad-pressed? 0 left)` sets it `#t` = YES; the right block sets `#f` = NO);
up/down only move the option index.  The earlier reading pressed right and down, i.e. the NO path, which is
why it looked unanswerable.  Measured on a settled dialog (the trace's `a=128`, not the `a=8/23` fade):

```
dpad-down, then Cross   -> edge screen=11 index=0 abs=64 ... accept screen=11 index=0   <- reaches it, takes NO
dpad-left, then Cross   -> GAMEPLAY: enter misty / village1 / training, scene-level='training'  <- overwrites
```

**A save written in one session is named, dated and loadable in the next.**  The port writes
`OpenGOAL/jak1/saves/BASCUS-97124AYBABTU!/bank0.bin` (67584 bytes = `BANK_SIZE` + 2 x `McHeader`); with that
file in place and the app relaunched, the save screen draws slot 0 as **`GEYSER ROCK`**, **`9/22/2026 18:13`**
(the moment the previous session wrote it) with the other three rows `EMPTY`, and accepting that slot loads
the training level.  So write -> presence flag -> name/date -> load all round-trip across a relaunch; what is
still unproven is whether the *loaded progress* equals what was saved.

**Instrument correction.**  The `OTTSEL G1: str=~A` line prints the *option's* own name, and the save/load
rows draw their text from the slot info instead, so their option name is null **by design** - the `NONE` in
that line was the trace's own placeholder, not evidence of an empty slot, which is exactly how the previous
document misread it.  The desktop draw path (`progress-draw.gc`, this repo's `a11-diagnostic-traces.patch`)
now prints `<null-name>`; the iOS lane's lines are emitted from `pc/progress-pc.gc`, which sits inside the
canonical `h3-jak1-host-boot.patch`, so that copy was left alone and the caveat was recorded in
`patches/README.md` instead of drifting the canonical patch.

**Workflow found while landing the instrument change.**  `scripts/build-ios.sh` does not re-emit GOAL: it
copies only `KERNEL.CGO` and `GAME.CGO` into the bundle (the `ENGINE.CGO` there is a stale leftover) while
the signed modules are emitted from `out/jak1/obj/<module>.o`.  A GOAL edit therefore needs
`build/h1/goalc/goalc --game jak1 --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'` (546 targets,
23 s) **before** the app build; without it the app silently keeps the old code, which is what the first
attempt showed (the trace still printed `NONE`).

**State.**  Verified on the iPad lane only, one Simulator at a time: 346 SIGNED MODULE ENTER = 346 RETURNED,
`ottsel-fault.log` 0 bytes, `class=tablet surface=1210x834 min-region=60x46 safe-lrtb=0x24x0x25`, and after
the re-emit the guards re-ran green (8/8 guarded `.ret` sites, 90112 KERNEL code words, overlay coverage
including the regenerated `a11-diagnostic-traces.patch`).  Not claimed: the phone was not re-run for the
dialog gesture (same source path); audio and physical devices untouched.
