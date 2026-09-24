# BOT64 — the shell's VU1 interpreter yields zero in gameplay; the desktop uses mips2c

Proven 2026-09-11 ~20:36-20:41 CDT with the installed binary
(`com.ottsel.shell`, UDID 08636791-…-EF72EF954DCF, bundle container
4E4CDF7B-…, bundle binary mtime 19:47 — matches current dirty source).
No product source was changed to obtain any of this.

## 1. The 20:24 crash was diagnostic-induced, not product (control run)

Clean launch, **no probes armed**, route to Village1 (launch -> +45 s START ->
+15 s CROSS -> +15 s, 4x DOWN @5 s -> +2 s CROSS -> +22 s), 210 s total:
`fault before: 0` / `fault after ~90s: 0` / `fault after ~210s: 0`, process
alive throughout. Frames at +22 s, +112 s, +232 s differ (propeller angle,
HUD banner cleared). The 20:24 GOAL-space type-tag fault came from four
cumulative sky probes armed together, each allocating a fresh `MTLBuffer` per
frame in the `SKYCOPY` path (`metal_shell.mm:1532-1550`).

**Rule: one diagnostic probe per run.**

## 2. The scene is live and textured; the sky is not the whole defect

`/tmp/ottsel-look2/skylog-rot.png` (20:35:45): textured huts, grass, water,
HUD glyph sprites, Jak correctly shaded blue/tan. Measured on that frame:
black `(8,10,18)` = 29.9 %, pure yellow `(255,255,0)` = 26.1 % in a wedge with
a diagonal boundary (band 0 = 94 % yellow, band 10-11 = 0 %). So the top of the
frame is a hard-edged wrong-colour region, not merely "the sky is dark".

## 3. Sky submission is healthy; the per-class math is not

`ottsel metal: SKYFRAME batches=44 tex1=6 tex32=6 tex64=32 texother=0
alpha0=0 alphaHalf=44 amax=0.502 cmax=(0.502,0.502,0.502)` — stable across six
consecutive seconds. The pre-world block at `metal_shell.mm:1465` is entered,
so "the block is skipped" is refuted. `SKYRGB 1x1=(0.000,0.000,0.000)
32=(0.502,0.502,0.502) 64=(0.078,0.078,0.118)`. The 64x64 cloud batches decode
`rgba=(20,20,20,0..128)` with UVs 0.60-1.0 into a 64x64 texture
(`OTTSEL SKY RAW`, `ottsel-runtime.log`); `SKYBOUND` shows the 1x1 fans reaching
the drawable at ndc=(-4.000,-4.009)..(4.000,3.991).

## 4. The shell's VU1 interpreter produces ZERO output in gameplay

Same binary, `SIMCTL_CHILD_OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1`, live run:

| chain (state) | vu1-runs | capped | xgkicks | gif-words | raster draws |
|---|---|---|---|---|---|
| 90 (logo/title) | 3485 | 2417 | 108391 | 433564 | 177 |
| 180 (title) | 10199 | 8644 | 124145 | 496580 | 0 |
| 270 (Village1) | 7924 | 6324 | **0** | **0** | 0 |
| 360 (Village1) | 7290 | 5670 | **0** | **0** | 0 |
| 450 (Village1) | 7290 | 5670 | **0** | **0** | 0 |

`last-pc=1694` and `vu1-runs` stay high, so the interpreter is running and
reaching the strip-output phase; it simply emits no GIF words from gameplay
chains. `OTTSEL VU1DRAW: result executed=50000 capped=true pc=1384 xgkicks=0
gif=0` in the same window. `g_raster` is never presented in any case
(`ottsel_metal_gfx_game_frame` returns 0 while `ottsel_metal_present` draws).

**BOT57's "interpreter works" numbers were the title spool. BOT63's premise is
refuted for gameplay.** Wiring `gif_out` would present nothing.

## 5. The desktop's VU1 solution is already half-linked into the iOS app

`scripts/build-ios.sh` compiles `game/mips2c/jak1_functions/tfrag.cpp`,
`generic_tie.cpp`, `generic_merc.cpp`, `sky_tng.cpp`, `ocean.cpp`,
`bones.cpp`, `shadow.cpp` … and `game/mips2c/mips2c_table.cpp` into
`libottsel-runtime.a`. It does **not** compile
`game/graphics/opengl_renderer/*` — the runner that walks the DMA chain, does
the VIF unpack, dispatches MSCAL to the matching mips2c program, and hands the
GIF words to a generic GS draw. The shell instead loads raw microcode into
`tools/ottsel_vu1/vu1.cpp` (`metal_gfx.mm:6990-6992`) — the path measured as
zero output above.

## 6. Ground truth captured

The macOS oracle was run and driven to Village1 for the first time this session
(`out/Ottsel.app`, keyboard: Return=START, Space=CROSS, Down=DOWN):
`/tmp/ottsel-diag/mac/village1.png` — correct blue sky, correct terrain, Jak on
the ground. This is the reference frame the iPad frame should match.

Next: `docs/BOT64_PROMPT.md` Gate N3. No playability claim.

