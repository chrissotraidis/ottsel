# BOT60 — the Village1 frame is frozen and the route does close (Gate I1)

Date: 2026-09-11. One Simulator, iPad Pro 11 M4
`08636791-2675-4675-8335-EF72EF954DCF`, bundle `com.ottsel.shell`, PID 83987.
No product source was changed this round; this is measurement only.

## Gate result

**Passed:** the game's own front end drives into Village1 gameplay. Log:

```
OTTSEL PC PROGRESS: edge screen=27 index=0 transition=#f abs=16384 rel=16384
OTTSEL PC PROGRESS: accept screen=27 index=0 selected=#f
OTTSEL PC PROGRESS: edge screen=18 index=0 | 1 | 2 | 3 transition=#f abs=64 rel=64
OTTSEL PC PROGRESS: edge screen=18 index=4 transition=#f abs=16384 rel=16384
OTTSEL PC PROGRESS: accept screen=18 index=4 selected=#f
GAMEPLAY: enter village1
OTTSEL CAMERA START: cp "intro-start" expected-r0=(0.6381,0.0000,0.7699)
OTTSEL INTRO: preloading misty before sequence A
```

Title -> New Game -> save-file screen -> Continue Without Saving -> Village1,
driven by real pad input through `ottsel-hold-*` file triggers. Screenshot
shows Jak (white, unlit) on screen with a blue/orange structure: not blank.

**Failed:** the frame does not advance. That is the round's finding.

## Measurement 1 — the 3D scene barely moves, and never transitions

Region-resolved pixel diff of rotated 900x632 captures (`banddiff.py`), base-1
vs base-2 taken **1 s apart with no input injected**:

```
status/top  0-90 : 18320/81000 = 22.62% changed
scene     90-560 :     8/423000 =  0.01% changed
homebar 560-end  :     0/54000 =  0.00% changed
```

An 8 s pair behaves the same. Every moving pixel is the corrupted top strip or
the status bar. The earlier "the frame animates 3.5%/s" reading was that noise.

**Correction after a 60 s window.** Over 60 s with no input the scene band moves
`10465/423000 = 2.47%` (0.04%/s), not zero: a slow drift where the blue
structure slides a few px and a faint teal floor gradient appears. So "frozen"
is too strong; the honest reading is *near-frozen cutscene drift with no state
transition*. What makes it a defect is not the slow drift but that **zero**
`CAMERA START: cp "..."` or `OTTSEL INTRO` lines appear in that whole minute:
the intro never advances to a next sequence and never hands control back.

## Measurement 2 — the game loop is healthy at ~60 Hz

`chain` 44100 -> 45360, `vsync` 44191 -> 45361, `iteration` 44200 -> 45400, all
over 20 s of wall time. The renderer is fed the same scene ~60x/s, so the freeze
is in the simulated state, not in the loop or in the shell's pacing.

## Measurement 3 — input does not change the frame

Jak's silhouette bounds `(n, minx, maxx, miny, maxy)` from `jakcent.py` are
identical to 0.1 px in every capture:

- D-pad LEFT hold 1.5 s x3 and RIGHT hold 1.5 s x3: `650,764,206,382` constant.
- Direct synthetic left stick, `/tmp/ottsel-hold-left-stick = "0 128 700"`
  (full left for 700 pad reads, ~12 s): `650,764,206,382` constant. The app
  accepted it: `OTTSEL PAD: synthetic left stick accepted x=0 y=128
  port0-reads=700`.
- START / CROSS / DOWN holds of 4 s each: `650,764,206,382` constant.

Input is not exonerated as a channel: the same hold-trigger path drove the whole
menu and produced the `accept screen=` transitions above. It reaches the game.
In the current state there is simply nothing that moves.

## What this refutes

- "Input does not move the player" is not the headline: there is no moving
  player and no moving scene to observe. The false term is the frozen state.
- `merc-submits=142043` / `eichar=4` frozen are consequences of the freeze, not
  independent facts about the player.
- `edge index=N` is printed before the increment (`progress-pc.gc:2208`), so the
  recorded index is the option that was pressed. The `0..4` staircase is correct.

## Not claimed

No playability. The scene is frozen, Jak is unlit, the sky is black,
`raster-draws=0`, `pcm-peak=0`. Next: `docs/BOT60_PROMPT.md` Q1.
