# L2: the game clock and the loading contract, both lanes - 2026-09-22

Gate: L2.  Question: is the iPad lane's game clock tied to its frame rate, so 6.6-6.75 fps would mean
game time, timers and input all run ~9x slow?

Instrumentation (bounded, no behaviour change):
- macOS lane: the `OTTSEL HOSTFRAME` line now also carries the game's own display clock
  (`game-base=`, `game-game=`, `game-actual=`, `game-real-actual=`, `time-ratio=`), read from `*display*`.
  Overlay `patches/a11-host-frame-heartbeat.patch` (delta on top of h3).
- iPad lane: `OTTSEL SUBMITSTAT` now carries the same fields, read from `*display*` through
  `g_pc_port_funcs.intern_from_c`.  Same offsets on both lanes.
- Offsets were not guessed: `*display*` was dumped at two frame counts on the macOS lane and the fields
  identified by their advance (the eight `time-frame` counters are u64 at 0x304/0x30c/0x314/0x31c/
  0x324/0x32c/0x334/0x33c, then the `old-` copies, then `time-ratio` as a float at 0x384), which matches
  the field order of `(deftype display)` in `goal_src/jak1/engine/gfx/hw/display-h.gc`.

Mechanism, read from the source: the game clock is the EE timer, and this port drives it from the host
clock - `read_ee_timer()` returns `ee_clock_timer.getNs() * 3 / 10` (game/kernel/common/kmachine.cpp),
and `get-bus-clock/256` is that value shifted by 9.  `display-frame-start` (engine/draw/drawable.gc)
turns the elapsed timer into `time-ratio` (elapsed / *ticks-per-frame*, i.e. per 1/60 s) and advances
`base-`/`game-`/`part-frame-counter` by `int(time-ratio) * time-factor` and the integral counters by
`int(time-ratio)`.  The PC-port branch only forces `time-ratio` to 1.0 when it is below 1.3, so a slow
frame keeps its real ratio.  A lane at 300 units/s of `base-frame-counter` is therefore running game
time at exactly wall rate.

Measured (same machine, one lane at a time):
- macOS lane, 90 s run: `frames=3600 wall_s=60.083 fps=59.92 game-base=319000 game-actual=3601
  game-real-actual=3601 time-ratio=1.000` through `frames=5100 wall_s=85.083 fps=59.94 game-base=326500
  game-actual=5101 ...`; i.e. **game-base advances 7500 units per 25.0 s = 300.0/s** and the game's own
  frame counter equals the presented frame count.  0 crash dumps.
- iPad strict lane, two 115 s runs: `vsync` 91 -> 901 with `game-actual` tracking it exactly, and
  `game-base` advancing **299.6, 305.6, 305.9, 312.6, 313.4, 314.5, 316.8, 317.2, 318.3, 325.9, 326.8,
  329.6, 332.2, 337.0, 337.5 units/s** across every window (mean ~316/s; the excess over 300 comes from
  the 1-second log-timestamp granularity and the `int(time-ratio)` rounding).  Presented cadence in the
  same windows was 4.74-10.0 fps (mean ~8), and the logged `time-ratio` samples were 4.000.  Both runs:
  346 ENTER = 346 RETURNED, `signed took oracle`, `scene-level='village1'`, `ottsel-fault.log` 0 bytes.

Answer: **the game clock is not tied to the frame rate on either lane.**  It is derived from the host
monotonic clock, so the iPad lane runs in real time - it is choppy, not slow: at ~8 fps each presented
frame advances game time by ~4-8 frames' worth (`scaled-seconds` = `int(time-ratio) * 5`), where the
macOS lane advances one frame's worth per frame.  Loading is a separate factor and is ~3x, not ~9x:
process start to a linked, active `village1` was ~3 s on macOS ([37:18] -> [37:21], first pad read
included) against ~8-10 s on the iPad lane (first frame [57:09], `signed took oracle` [57:17],
`village1-vis` link [57:18], first `scene-level='village1'` SUBMITSTAT [57:19]).

Consequences carried forward: the lane's game time, timers and animation are wall-correct, so the parity
work is about *cadence* (L3: the present path) and about *step size* - `scaled-seconds` is not clamped
(only `set-particle-frame-time` is, to 0.04 s), so a 4-8 frame step is a real physics/input-quality
question once the cadence improves or a device is slower still.  Input sampling is one sample per
presented frame, i.e. 100-200 ms granularity at the measured cadence.

Not measured yet: a shared boot->title wall-time marker (the host's `OTTSEL ROUTE STATE` probe is
triggered by a file in the shared settings directory, which the iPad container never sees), and the
route/input acceptance itself.  Not claimed: no playability, audio or lifecycle claim.
