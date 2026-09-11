# BOT45 - the sky texel probe clamps on the CPU and cannot see the sky

Round BOT45, 2026-09-11. Same device and build, `/tmp/ottsel-clean2.log`.

## What the probe reported

    OTTSEL SKY TEXEL: tex0=0x0000000198005fa0 psm=0 tw=6 th=6 64x64 q=59.511513
      uv=(-3.844238,-3.688477) px=(0,0) rgba=(121,193,121,193) registry=1

read against the carried lead that a wrong VRAM decode makes the sky flat cyan.

## Why that reading is not evidence

The probe indexes the decoded page with

    tx = clamp((int)(uv[0] * texture_width), 0, texture_width - 1)

so any out-of-range coordinate is forced to texel (0,0) and reported as the
sampled colour. It reports the CPU clamp, not the texel the fragment shader
fetches.

The GPU sampler does not clamp. `directSampler` is built with
`MTLSamplerAddressModeRepeat` by default (`src/shell/metal_shell.mm:671-672`),
and the per-draw sampler switches to `ClampToEdge` only when the GS CLAMP
register sets the axis bit (`metal_shell.mm:2655-2656`). Under repeat,
`uv = (-3.844,-3.688)` wraps to `fract = (0.156, 0.312)`, a legal interior
texel. The value is legal, not degenerate.

## What this removes

- The uv magnitude is not a defect, so this line does not implicate
  `decode_direct_vram_texture`.
- The sky source is present and correctly keyed:
  `OTTSEL SKY REGISTRY: tbp=0x14 adgif-psm=19 adgif-cbp=0x4c reloc-size=486
  key-present=1 meta-size=478 meta-same-dest=1`, and
  `OTTSEL SKY BLEND ... produced copies=3 misses=0` over live destinations
  (`rgb-texels-live=4096/4096 peak=242`). The carried
  `g_direct_texture_metadata`-keyed-by-`dest`-alone lead is not confirmed.

## Still open

The sky is still not a gradient in the composed frame. Its 40 submitted
primitives carry `ndc=(-4.000,-4.009)..(4.000,3.991)`, four times the
drawable range, but that matches the reference transform `(x-0.5)*16`
(`ref/open-goal-jak-project/repo/game/graphics/opengl_renderer/shaders/direct_basic.vert`),
so the projection is not the fault either. The flat sky is unattributed and
needs a probe that reports the GPU fetch rather than a CPU clamp.
