# The slow cadence windows are not the CPU base upload; the frame cost model - 2026-09-22

Gate: L3.  Question: is the 16 MB CPU base upload that the last document hypothesised the cause of the
11-15 fps windows, and if not, what does the frame actually cost?

**Instrument (opt-in, behaviour-neutral).**  `OTTSEL_TRACE_BASE=1` makes `presentRGBA:`
(`src/shell/metal_shell.mm`) log `OTTSEL BASEUPLOAD: n= wanted= tfrag-mesh= tie-mesh= live-scene= meshes=
frame-refs=` on every change of `cpu_base_wanted` plus one line in ninety presents.  Without the variable
no code path or output changes.  Built shell-only with the product lane profile and installed; the same run
also had `OTTSEL_TRACE_INPUT=1` so the maintained driver could drive the route into the training level,
followed by stick holds.

**Result - the hypothesis is refuted.**  82 SUBMITSTAT and 129 BASEUPLOAD lines in one run:

| `cpu_base_wanted` | windows | fps min/mean/max | raster-draws seen |
|---|---|---|---|
| false | 121 | 18.0 / 32.8 / 90.0 | 0, 137, 1157, 1353, 1381, 1752, 1780 |
| true | 2 | 18.0 / 24.0 / 30.0 | 0 |

The only two `wanted=true` windows are the boot/level-load frames
(`tfrag-mesh=false tie-mesh=false meshes=0 frame-refs=0`, `live-scene` false then true).  Throughout
gameplay `cpu_base_wanted` is **already false** (`tfrag-mesh=true tie-mesh=true meshes=7 frame-refs=2`),
so the 16 MB upload is not being made and cannot be what makes those windows slow.  The previous
document's `raster-draws=0`-correlates-with-slow reading is refuted by the same run: `raster-draws=0`
appears in both 22.5-30 fps and 45-90 fps windows.

**Frame cost model.**  Twelve paired 3 s `sample` windows (`sample` reports one count per thread per
window, 1687 for this 3 s interval), labelled by the display rate measured from the lane's own counters at
the same moment:

| state | display | game-thread samples / frame | main-thread samples / frame | implied frame |
|---|---|---|---|---|
| fast | 45 fps | ~1014 / 135 = 7.5 (~13 ms) | ~404 / 135 = 3.0 (~5 ms) | ~19 ms |
| slow | 22.5 fps | ~1128 / 68 = 16.7 (~30 ms) | ~522 / 68 = 7.7 (~14 ms) | ~44 ms |

So the frame is saturated in the slow state and the **game thread's per-frame cost roughly doubles**
(13 -> 30 ms) while the displayed frame rate halves: `game-time-ratio` is 1.0 in the fast windows and
3.0-4.0 in the slow ones, and that ratio is the port's wall-clock compensation (L2), so a display drop
raises the game work each displayed frame and drives the cadence down further.  Whether the compensation
should be capped is a product decision (wall-correct game speed against smoothness) and is deliberately not
taken here.

**Present-path detail, and why no single edit is landed now.**  The main thread's largest non-idle item is
`presentRGBA:` -> `drainMercUploads` -> `newBufferWithBytes` (up to six buffers per drain, each a
synchronous XPC into MTLSimDriver, 63 of 1687 samples = ~0.8 ms/frame for all of them, ~0.5 ms for the MERC
part).  That is below the ~10% resolution of the fps windows used to accept a change, so reusing those
buffers is not worth landing alone: it needs to be bundled with the rest of the per-frame simulator
allocation traffic, or measured by a cheaper signal than whole-lane fps.

Not claimed: no fps improvement landed.  The instrument is installed and the state is unchanged from the
product lane's point of view.
