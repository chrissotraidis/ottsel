# L0: per-lane cadence harness, both lanes - 2026-09-22

Gate: L0 (measurement harness, no behaviour change).  Question: can each lane report its presented
cadence from its own log in one command, so L2/L3 can compare clocks and load-phase wall times?

Harness:
- macOS lane (landed): `cd out/jak-project && OTTSEL_ENABLE_KEYBOARD=1 ./build/h1/game/gk -v --game
  jak1 -- -boot -fakeiso 2>&1 | grep -o 'OTTSEL HOSTFRAME:.*'` - one bounded line every 300 rendered
  frames carrying the cumulative frame count, wall seconds and fps.  It sits at the top of
  `OpenGLRenderer::render`, the per-frame callee of `GLDisplay::render`, and is carried by
  `patches/a11-host-frame-heartbeat.patch` (a delta on top of the h3 host-boot overlay, since both
  files are h3's).  Nothing else changes.
- iPad lane (already present): `OTTSEL SUBMITSTAT ... vsync=` sampled over a fixed wall window.

Measured, same machine (Apple M1), one lane at a time:
- macOS lane, one 90 s run: `frames=3000 wall_s=50.077 fps=59.91` ... `frames=5100 wall_s=85.094
  fps=59.93`, i.e. a steady **59.9 fps** across 17 heartbeat lines, with 0 crash dumps, 348
  `executing top-level` lines and `OTTSEL ROUTE STATE: title-wait-ready` reached.
- iPad lane, two strict-profile runs (the same objects as above): `vsync=361` at 45:29 -> `vsync=631`
  at 46:09 (270 frames / 40 s = **6.75 fps**) and `vsync=361` at 47:14 -> `vsync=631` at 47:55 (270
  frames / 41 s = **6.6 fps**), both with `scene-level='village1'`, 0-byte `ottsel-fault.log` and the
  title screen rendered.

Carry into L2: on the same work the two lanes are ~9x apart (59.9 fps vs 6.6-6.8 fps).  The next
measurement is whether the iPad lane's *game clock* is tied to its frame rate - which would make game
time, loading progress and input all run ~9x slow rather than only presentation - and what the boot
to title and level-link wall times are on each lane.

Not claimed: no playability or route-input claim; the iPad figure is a title/village-load window, not a
steady-state gameplay cadence.
