# BOT48 — the PC progress path shadows the engine path, and the title menu does submit all six entries

Proven live on iPad Pro 11-inch M4, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, app `com.ottsel.shell`, screen 1668x2420
(portrait; screenshots need `sips -r 270`).

## Question

BOT46 carried Gate G1 as "why do 3 of the 4 `*title*` entries not draw". Is the
title menu failing to submit entries, or is something else happening?

## Root cause of three rounds of dead probes (proven)

`goal_src/jak1/pc/progress-pc.gc` overrides both paths the earlier rounds
instrumented in `engine/ui/progress/`:

- `pc/progress-pc.gc:2972` redefines `draw-options`, replacing
  `engine/ui/progress/progress-draw.gc:841`.
- `pc/progress-pc.gc:3453` `(set! (-> progress-normal post) ...)` replaces the
  dispatch in `progress.gc:1152` that routes `(progress-screen title)` to
  `draw-options`.

So the BOT46 probes at `progress-draw.gc:977-997` and the `:post` probe at
`progress.gc:1305` are **dead code on this build**. Verified: the installed
`GAME.CGO` contains `OTTSEL G1` twice and the log produced 0 lines from them.

## The title screen is the PC menu (proven)

`*options-remap*` maps screen 27 to `*title-pc*` (`pc/progress-pc.gc:747`), not
`*title*`. Six entries: `NEW GAME, LOAD GAME, OPTIONS, SECRETS, QUIT GAME, BACK`.
"SECRETS" is the PC-only entry, which is why BOT46's single visible word did not
match its assumed four-item list.

## Gate G1 result: entries are all submitted (proven)

Probe added to the live path (`pc/progress-pc.gc:3315`, guard-free, one line per
entry per frame):

```
OTTSEL G1: i=0 nm=#x15c ty=6 y=40 oi=0 len=6
OTTSEL G1:   str="NEW GAME"
OTTSEL G1:  draw i=0 tpi=1000 sa=1000 oy=40 a=128
... i=1 "LOAD GAME" y=65 ... i=2 "OPTIONS" y=90 ... i=3 "SECRETS" y=115
... i=4 "QUIT GAME" y=140 ... i=5 "BACK" y=165
```

All six resolve a string, draw at `tpi=1000` (`transition-percentage-invert`=1.0),
`sa=1000` (scroll amount 1.0) and alpha 128, with `len=6 <= PROGRESS_PC_PAGE_HEIGHT`
(7, `pc/progress-pc.gc:11`) so the scroll window is fully open. **Nothing in the
menu layer is failing.** "Only OPTIONS renders" is refuted.

## The real visible defect (proven, now Gate G1)

Text does reach the screen, but only in fragments that change frame to frame. On a
pixel-identical static scene (`/tmp/b48/burst_*.png`, 0.30% of pixels differ), one
frame shows "LOAD GAME" + "OPTIONS" and another shows "SECRETS" + "QUIT". Every
label is rendered twice, light glyph plus black drop shadow
(`font-flags shadow ...`, `pc/progress-pc.gc:3011`; `print-game-text ... font #f
128 22`): the light pass is intermittently missing, leaving the black shadow, and
parts of words disappear entirely. So G1 is a glyph-pass legibility defect in the
sprite/text draw path, not menu logic.

## Route gate N1 is open (partial)

`NEW GAME` + Cross reached the save-game-title screen
(`OTTSEL G1: str="CONTINUE WITHOUT SAVING"`, frame shows "...TO ...EMPTY"), fault
log 0 bytes, `scene-level='village1'`, `merc-submits=4812`, `eichar=294`.
Reaching gameplay with Jak visible and input-accepted is still unproven.

## Correct input seam (proven, machine-checked)

`docs/BOT46_PROMPT.md` Gate N1 is wrong: there is no `/tmp/ottsel-press-button`.
`src/shell/main.cpp:983-1025` polls these every 30 frames and unlinks each after
firing, in `<data-container>/Library/Application Support/local.ottsel/OttselShell/`
first, else the bundle:

- `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE,
  `ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN,
  `ottsel-bg-village1` -> `(bg 'village1)`.

Inject with `: > "$W/ottsel-press-start"`. Reinstalling the app recreates the data
container, so re-resolve `get_app_container ... data` after every `simctl install`.

## Build under test

GAME.CGO `d5a09f0d59816f90b893b37ea72fc38f6c628b8c3667f9b983924cd507f467df`
(identical in `out/jak1/iso/` and the installed bundle), ENGINE.CGO carries the same
probe, TIT.DGO `7421fc02714448e47c30995878f03449b5138025a40c4983ebc69a2a385b0588`
(unchanged). Build 34.2s / 546 targets. Fault log 0 bytes.

