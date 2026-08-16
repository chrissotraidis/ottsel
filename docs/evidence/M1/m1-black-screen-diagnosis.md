# M1 — BOT25: the black screen diagnosed (2026-08-16)

## What the black screen IS

Not a renderer failure and not an instability: the game itself is
holding the screen black.  The title flow's first act is the NDI intro
movie (a spooled STR animation); until that animation's file-status is
`'active`, the logo/title states run `set-blackout-frames` every frame,
and the display is intentionally black.  The renderer, its fr3 assets,
the IOP, and the game loop are all live underneath it.

## Where the chain stalls (probe ground truth)

The spool pipeline is: title/target `:trans` → `spool-push` ("ndi-intro")
→ `(update *art-control*)` assigns a stream buffer → buffer update calls
`str-load` → STR RPC → overlord `LoadSTRFileToEE` → file-status 'active.

- The overlord log shows **zero .STR loads ever requested** (only the
  boot splash + the two text files, which use the same str-load path and
  work — so str-load itself is healthy post-BOT24).
- A per-second raw dump of `*art-control*` (OTTSEL ARTC/ARTB probes in
  libpad.cpp) shows **no spool request is ever recorded**: the rec array
  stays empty, active-stream = #f, both stream buffers idle at
  SPOOL_PRIORITY_LOWEST with no pending/load file, `*load-str-lock*` #f.
- `spool-push` unconditionally records into the top-3 recs when called —
  so it is **never being called**.
- The pusher is the target's `target-title` `:trans` (and the logo
  process's spool-push in its `:trans`).  The target process is alive
  and handling events ("GAMEPLAY: enter title" is printed by the
  target's 'level-enter handler) — but it is evidently **not sitting in
  the target-title state**, so its per-frame spool-push never runs.

## Next lead (one probe away)

Dump the target's (and the title-level logo processes') current state
names per second (process `state` → state `name` symbol) to see where
the state machine actually is, then trace why `(go target-title)` (or
the event that triggers it) never fired.  Suspects: the title-obs init
event chain ('logo/'ndi spawn events), or another stack-arg/ABI-class
runtime issue in the state-transition path.

## Immediate human workaround (untested, for the running build)

The default keyboard binding maps **Enter → START** (SDL, verified in
input_bindings.cpp).  The `ndi`/`startup` logo states carry the PC-port
shortcut: START/circle/X with village1 `'loaded` sets bg-a and displays
village1 behind the title (title-obs.gc :trans).  Click the game window
and press Enter — if the logo process is in one of those states, the
village should appear; if nothing happens, that further confirms the
state machine never reached the logo states, matching the probe.
