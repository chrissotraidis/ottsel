# L5 route probes: holds work, the wheel's confirm is not the default - 2026-09-22

Gate: L5.  Question: can the injected holds drive title -> New Game -> Village1, and what do the
current build's press bits and frontend states actually mean?

Decoded and useful for every later script:
- Holds are the working press (`ottsel-hold-*`); taps are one frame of state at 5-8 fps and never move the
  frontend.  With holds, the title advances.
- Pad bits observed with `OTTSEL_TRACE_INPUT=1`: `0x8` = START (`SDLK_RETURN`), `0x4000` = Cross
  (`SDLK_SPACE`), `0x40` = DpadDown (`SDLK_DOWN`).  A combined `0x4040` appeared once, which means the
  shell's hold state overlapped my Down and Cross holds - probes must leave >= 1 s of neutral pad between
  presses or the menu sees a two-button frame.
- `OTTSEL CAMERA ENTRY: accepted-level-candidate ... level='title'` -> `level='village1'` is the *title
  screen's own backdrop*, not a route advance: the title renders a live village1 scene, which is why the
  earlier acceptance runs showed `scene-level='village1'` at the title.  Do not read it as New Game.

What the probes showed: hold START at the title -> the main-menu wheel over the village backdrop
(`/tmp/ottsel-routeA-final.png`, `/tmp/ottsel-routeB-01-menu.png`); a Cross hold at the wheel then
returned the UI to the title (`/tmp/ottsel-routeB-02-after-cross.png`, `/tmp/ottsel-routeB-03-final.png`,
`/tmp/ottsel-routeD-02-after-cross.png`), so Cross at the wheel is not the New Game item on this build,
or the wheel needs a selection change first.  One probe (`/tmp/ottsel-routeC-*`) mixed a Down and a Cross
into the 0x4040 frame, which is exactly the input pollution the decode above warns about; its result
cannot be read as a menu response.

State: lane healthy throughout - boot < 20 s, 346 modules, `ottsel-fault.log` 0 bytes in every probe,
`game-time-ratio` settling to 4.000 at the title with `raster-draws` climbing.  Next probe design: from the
title, hold START, wait for neutral, then press Down exactly once, wait >= 2 s, screenshot, press Cross,
wait, screenshot - one menu item per run until the frame shows the save menu, then Down xN + Cross for
'Continue Without Saving'.  Only then rewrite the driver's expected edges.  Not claimed: no New
Game/Village1 proof, no playability, audio or lifecycle acceptance.
