# Upstream OpenGL renderer on iOS (GLES 3.0) - title screen

Date: 2026-09-24. Lane: iPad Pro 11-inch (M4) Simulator `08636791`, strict build (518/518 signed).

## Question

Can OpenGOAL's own renderer (`game/graphics/opengl_renderer`, desktop GL 4.1) replace the custom Metal
renderer on iOS without being rewritten?

## Change

- `scripts/build-ios.sh`: `OTTSEL_RENDERER=gl` compiles upstream graphics, HID, settings and imgui into
  `out/ios-gl`; `game/graphics/ottsel_gles_compat.h` is force-included only into `game/graphics/*`.
- `scripts/translate-gl-shaders.py`: glslang parses each GLSL 4.10 shader, SPIRV-Cross writes GLSL ES
  3.00 with explicit int/float conversions and highp precision; each output is re-validated. 92/92 pass.
- ES differences live in one header plus `ottsel_gles.cpp`: 1D palettes folded into 1024-wide rows
  (8192 texels > the ES minimum of 2048), framebuffer 0 -> SDL's UIKit view FBO, MSAA 1, desktop-only
  debug calls are no-ops.
- `pipelines/opengl.cpp` `ottsel_gl_render`: the `GLDisplay::render` sequence (render, limiter, swap,
  `frame_idx++` + notify); the view renderbuffer is rebound before the swap.

## Root causes found on the way

| Symptom | Cause |
| --- | --- |
| deadlock at the first vsync | glue swapped without `frame_idx++`/notify |
| black screen, GL 0x502 at every swap | UIKit presents the bound renderbuffer; the renderer left a depth one bound |
| black level geometry, 0x501 then 0x502 | 8192-wide 1D time-of-day textures exceed ES limits |

## Result

- Title screen shows the logo, PRESS START, windmill, palms, sunset sky and ocean, matching the macOS
  `gk` build of the same tree (screenshots `/tmp/ottsel-gl8-t2r.png`, `/tmp/ottsel-mac-title.png`).
- 0 GL errors in the run; strict exec on; 0-byte fault log.
- The Simulator's GL is Apple's CPU rasterizer (40-130 ms per frame). Not a product number; G3 measures
  on the device.

## Open

## Intro and Metal removal (same day)

- The shell's touch controls and status surface are drawn by the GL glue (`ottsel_gl_view.h`).
- New Game -> Continue Without Saving plays the whole intro (Sony logo with particles, Sandover, Misty,
  Samos) to `GAMEPLAY: enter training`; Jak and Daxter on Geyser Rock; strict exec, 0-byte fault log
  (`/tmp/ottsel-gl10-d.png`). The Simulator ran it at 1.3-2.4 fps with time-ratio 4.
- The Metal renderer (71 files: `metal_gfx.mm`, `metal_shell.mm`, VU1 emulator, policies, tests) was
  deleted; the GL-only build boots to the status screen, then the title.

## Open

Gameplay input on this renderer, a level transition, and every frame-rate number (device only).
