# I1.1c — the sky draw path is alive; the sky geometry is misplaced (2026-09-11)

**Question.** BOT39 closed on "the sky draw path itself is dead". Is that true?

**Answer: no.** One end-of-pass probe retired the whole branch.

## Method

`ottsel-trace-metal-sky-debug-all` now draws `skyDebugFillPipeline`
(`direct_vs` + `directLayout` + a texture-free magenta fragment) and
`ottsel-trace-metal-sky-end` redraws the captured `_skyBatches` with the REAL
product pipeline, both at the **end** of the encoder next to the known-working
touch overlay, under `overlayDepthState` (compare ALWAYS, no depth write).
Both are trigger-gated and emit nothing in product runs.

## Results

- Magenta probe: **clear frac 0.454, `(255,0,255)` = 0.497** of the frame,
  `ottsel-fault.log` 0 bytes. Pipeline, vertex descriptor and encoder all
  reach pixels.
- Sky redraw: **real textured sky geometry paints** (green/magenta/cyan/red
  wedges, upper right) — the generated SkyBlend buffers are not the blocker.
- Same run shows recognizable Village1: huts, palms, cliffs, water, hazy
  horizon. The scene is further along than the docs' "malformed" language.

Frames: `/tmp/ottsel-shots/bot40magenta-c.png`
`eb98d02ed8f92419afe3c19c6d560594772f797028bc21937396fface2c45871`;
`/tmp/ottsel-shots/bot40skyend-c.png`
`bbbfc9c6c7546ad8aa5ea62b8d8919b04b3e9f848bf09a89e1bb63c48d74aca2`.

## Why BOT39 read "dead"

The sky is encoded **before** TFRAG/TIE/Merc/Sprite in the same pass
(`metal_shell.mm:1327`). An in-loop probe is overdrawn by the opaque buckets,
so the sky region still reads clear colour. The BOT39 `SKYREF` result was a
measurement artifact, not a dead path. The older "forced-opaque floods cyan /
debug magenta floods the screen" reading came from a stale installed binary and
stays refuted.

## Where the real defect is

`SKYFRAME` is steady at 1 Hz (`batches=40 tex1=4 tex32=4 tex64=32`) with real
alpha (`alpha0=0 alphaHalf=40 amax=0.502`), and `SKY ENCODE` shows fans whose
raw GS words are 0x4000/0x8000/0xC000 in x. The native Direct/sky conversion
(`metal_gfx.mm:2659-2671`) normalizes by `UINT32_MAX` then applies
`nx=(gx-0.5)*8+0.5` / `clip_y=-(gy-0.5)*32*(512/448)`. Upstream
`direct_basic.vert` applies `(x-0.5)*16` / `-(y-0.5)*32*HEIGHT_SCALE` to a
coordinate that already carries the XYOFFSET origin, and
`PrimitiveBuffer::push` adds `x_off = -65536*(ofx-0x7000)/UINT32_MAX`
(`DirectRenderer.cpp:859-864, 1466-1472`). The native path passes
`rst ? rst->x_off : 0.f` and the `OTTSEL SKY RAW` dump reports
`xyoffset=0x0`, so that origin term is not applied on the sky path.

Net effect: the decoded fans span ~8x the intended NDC extent and land mostly
off-screen, so the sky region keeps the `(0.03,0.04,0.07)` clear colour.

## Next (falsifiable)

One question: **does applying upstream's XYOFFSET origin term to the sky/direct
NDC conversion move the sky onto the screen without disturbing TFRAG/TIE?**
Regress with the `scene-no-merc` / `scene-no-tie` controls and a fresh frame.
Do not add a fake sky texture or gradient.

I1.1c is **PASS** (the path is alive); I1.1e (magnitude/placement) is **OPEN**.
No playability claim.

