# S2.2 BOT21: present-path regression fixed -- real game texture visible again

Date: 2026-08-16.  Status: S2.2 PROGRESS (the Metal present path is
verified visible again; the composed-frame gate still needs the frag-list
construction -- see BOT19g/BOT19f findings).

## Symptom

Since BOT19 the Simulator window was BLACK even though presents fired every
frame with real pixels:

```
ottsel metal presentRGBA 480x320 layer-drawable=480x320 w=480 h=320 pipeline=1
ottsel metal px0-15: 080a12 ff080a 12ff08 0a12ff ...   (navy log surface)
```

The layer geometry was correct (480x320 window, attached, visible, opacity
1.0, foreground scene), the CAMetalLayer drawables presented, and even a
forced solid-magenta fill was invisible.  `simctl io screenshot` captured a
fully black device framebuffer while the CPU surface PPM (`surface.ppm`)
contained the real navy log surface with 23,823 text pixels.

## Root cause (two-layer diagnosis)

1. **Simulator display state (red herring).**  The app runs in the iOS 18.5
   simulator's windowed presentation: its own 480x320-point virtual screen
   (UIScreen mode 640x960), composited into the main framebuffer at a
   centered 960x640-px window.  When the simulator is in the floating-window
   ("Move & Resize") mode the app's content is NOT composited into the main
   framebuffer at all -- every app (even Settings) screenshots black.  This
   was excluded by comparing against Settings and by the fact that the BOT20
   magenta overlay DID show once the simulator returned to the device view.
   Geometry probes (`ottsel geo setup/late`) confirmed the window/layer were
   attached and visible.
2. **The BOT20 "present every decode" gate let uniform (empty) tpages
   clobber the visible frame.**  `gfx_texture_upload_now` presented EVERY
   decoded texture, and `g_frame` is what main.cpp presents (scaled) instead
   of the shell log surface.  In the village boot the decode order is:
   - tpage 0x1cf tex 44 (128x64, real brown/gold pixels) -> g_frame set,
     VISIBLE
   - tpage 0x2 tex 43 (128x128, ALL ZERO), tpage 0x370 tex 0 (64x64, all
     0x80), tpage 0x100 tex 0 (64x64, ALL ZERO) -> each overwrites g_frame
     with a uniform page -> the window shows pure black (614,400 px all
     (0,0,0) in the window region).

   BOT16's best-area gate had the opposite flaw (small real village textures
   never replaced the title backdrop).  Both heuristics were replaced by a
   uniformity check.

## The fix (runtime-side only; no game source patched)

`src/shell/metal_gfx.mm` `gfx_texture_upload_now`: after decoding, sample
~256 pixels across the page; if every sampled pixel equals the first pixel
the page is UNIFORM (an empty/black region) and the decode is skipped
("keeping the last real frame").  Real game textures are never perfectly
uniform, so the last real frame stays on screen while uniform pages (shadow
masks, empty CLUT regions) no longer blank it.

Also kept: the drawable-size sync in `metal_shell.mm` (harmless, correct)
and the first-8-presents probe (drawable size + first pixels) for evidence.
Removed: the BOT20 magenta overlay and the BOT21 geometry probe block after
the diagnosis.

## Verified (one boot, one Simulator, Windowed, zero faults)

- `ottsel-fault.log` = 0 bytes; app stable (continuous VIFSEQ/DMA activity,
  dispatcher + render loops alive).
- The window region (960x640 px centered) now shows the real decoded Jak
  texture: 598,612 non-black pixels, 5,192 unique colors, dominated by
  (254,227,92) -- the tpage 0x1cf tex 44 village tpage
  (`s22-bot21-texture-visible.png`).
- The uniform pages are skipped and logged:
  `OTTSEL GFX: skip uniform 4x4 tpage=0x1a0 ...`,
  `OTTSEL GFX: skip uniform 512x256 tpage=0x18e ...` -- the last real frame
  persists (pixel-identical across repeated screenshots 25s apart).
- The frame is presented continuously by both the decode path and the
  `gfx_send_chain` re-present (every 90 chains).

## Honest boundary

This restores the BOT16 milestone (a real game texture visible through
Metal) on the current village boot.  It is NOT the S2.2 composed frame: the
VU1 still runs with gif_out=0 because the frag-list block (VU words 0-4) is
never written by the game's compiled draw path (BOT19e-g).  The renderer
gate is unchanged: feed the frag-list count/pointers into the live VU1 so
the XGKICK output reaches `OttselRaster`.

## Files

- `src/shell/metal_gfx.mm`: uniform-page skip in `gfx_texture_upload_now`.
- `src/shell/metal_shell.mm`: drawable-size sync + first-8-presents probe.
- `docs/evidence/S2/s22-bot21-texture-visible.png` (on-screen texture),
  `s22-bot21-texture-visible.log` (boot + decode + DGO-serve lines).
