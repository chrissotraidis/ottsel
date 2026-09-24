# BOT58 — the intro stream blocks gameplay; the renderer and player already work

Date 2026-09-11. iPad Pro 11 M4 Simulator `08636791`, `ottsel-fault.log` 0 bytes, disk `13Gi` free / zero `tmp_pack_*`. No product change; file triggers only. Gate I0/I1 not passed.

## The frame is real, and volatile

A 15:45 capture shows a fully textured Village1 — huts, palm fronds, the red-shingled tower, a totem pole, water, shore, bridge — at 41.4% drawn. Four captures two seconds apart in one run measured drawn% 44.9 / 100.0 / 19.8 / 17.7. Single-screenshot A/Bs are worthless here; every claim below uses an N-frame sample.

## The blocker — the game never leaves the logo stream

`LOLOOP.STR` chunks 3/4 reload continuously, `587 -> 655` in 20 s (~3.4/s), at the title, alongside `LOI2.STR`, `LOINTRO.STR`, `NDINTRO.STR`, `0COMMON.TXT`, `0SUBTIT.TXT` and `model='logo-cam-lod0' level='title'` with `logo-intro`, `ndi-intro`, `logo-loop`. Live: the camera is frozen (consecutive frames byte-identical), `eichar=4 eichar-attempts=4` never moves, `merc-submits` still climbs to 92799 so the engine runs and submits other mercs, and injected input is delivered and inert.

## Input is exonerated (new)

`OTTSEL MOBILE INPUT: source=keyboard` carries the decoded buttons: `event=2 buttons=0x8` (START), `event=4 buttons=0x4000` (CROSS), `event=6,8,10,12 buttons=0x40` (four DOWN). Gate I0's own route `title-wait -> Start -> Cross -> Down x4 -> Cross` reaches the app intact and changes nothing. The stall is downstream of input.

## The unblock — the game's own `(bg 'village1)`

`ottsel-bg-village1` (`main.cpp:1025`) issues the game's own background change. In one run `eichar` went `4 -> 35 -> 125 -> 215 -> 305` — one submit per game frame from a standing start, `eichar == eichar-attempts` exactly, so nothing is rejected between attempt and submit.

| stage | drawn% | clear% | sky region painted |
|---|---|---|---|
| boot, title spool | 41.4 | 58.6 | 7.6% (not sky) |
| after `(bg 'village1)` | 95.2 | 4.8 | 88.4% (not sky) |
| after Cross | 93.6 | 6.4 | 84.5% (not sky) |

**Correction (later 2026-09-11 session): the "sky region painted" column is
wrong.** The classifier cannot tell sky from the HUD sprite banner already
proven in `i1-hud-sprite-giant-quad-2026-09-11.md`. Those pixels are pure
`(255,255,0)` yellow, the banner, not sky. Real sky content (lavender
`(142,147,197)`) appears lower in one state and black in another. Any sky
metric must exclude the banner first. This does not change the drawn% column.

Post-bg frames are a ground-level third-person gameplay camera: dirt path, grass, fence, windmill, huts, 93.9% drawn / 6.1% clear. **The renderer, camera and frame loop work in village1 gameplay; what blocks playability is the game's own state machine staying in the intro stream.**

**Correction: "the player-submit path works" above is refuted.** `eichar`
climbing to 305 was the game submitting the model, not the model reaching the
screen. The MERC path placed every vertex behind the near plane, so Jak drew
zero fragments regardless of the submit count. Cause, arithmetic and the
frozen-camera A/B are in `BOT59-merc-z-near-plane.md`. The intro-stream
finding in this document stands unchanged; the player's submit count was never
evidence that he was visible.

## Audio is not zero (corrects BOT35/BOT37)

`PLAYER RPC loaded COMMON bank sounds=461`, `VILLAGE1 bank sounds=43`, named `fly7`/`bird-2` plays, `mixed 48000 frames` windows ramp `window 1 pcm-peak=0` to `window 260 pcm-peak=8113` (sustained 7000-10000).

## Sky — bounded observation, mechanism not isolated

With `-sky-debug-fill -sky-debug-all` armed, 1 of 5 captures hit drawn%=100.0 / clear%=0.0 with the sky band dominated by **pure black (0,0,0)**, not the pass clear `(8,10,18)` — so sky geometry can rasterize there. Magenta stayed 0.00%, so the debug-fill pipeline did not paint. `SKYFRAME batches=34 tex1=6 tex32=6 tex64=22 alphaHalf=34 amax=0.502`. Which encode produced the black is not isolated; do not claim a mechanism yet.

## Refuted / retracted

- `SKYFRAME`/`SKYRGB` are `NSLog`, absent from `ottsel-runtime.log` by log target, not by failure. Read via `simctl spawn <udid> log show --predicate 'eventMessage CONTAINS "ottsel metal"'`.
- The RGBAQ decode is correct (packed `rec[0],rec[4],rec[8],rec[12]`; reglist `rec[0..3]` + Q at `rec+4`) against `DirectRenderer.cpp:1127-1132` and `:923-928`. Do not chase a decode fix.
- `mercON` vs `scene-no-merc` is not usable yet: 82.4% of pixels differ between runs, so launch camera state is not deterministic.

## Next falsifiable step

Why does input not advance the spool? Log the spool's own loop counter and exit test for 30 s while pressing Start. Branch A: the spool never gets its completion signal. Branch B: it exits and the title re-enters it. Then localise Jak with a deterministic route so the merc A/B reads.
