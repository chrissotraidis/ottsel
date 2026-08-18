# I1 fullscreen composed-frame checkpoint — 2026-08-18

## Scope

One iPad Pro 11-inch (M4) iOS 18.5 Simulator (`08636791-2675-4675-8335-EF72EF954DCF`),
one `com.ottsel.shell` runtime, and no macOS `gk` process.

## Fixes verified

The old diagnostic Direct/GIF frame was retained indefinitely and then used as
the main present surface.  `metal_gfx.mm` now marks a raster publication as
pending and consumes it once.  Live PC-port TFRAG/TIE rendering therefore
returns to the current shell surface rather than sitting behind a stale white
rectangle.

The app was also running in iPhone compatibility mode because `Info.plist`
did not declare the iPad device family.  Adding `UIDeviceFamily` entries 1
and 2, and retaining landscape-only iPad orientations, changed the live
`CAMetalLayer` from 480x320 to 1210x834.  Once a background bucket is live,
the shell stops painting its diagnostic log over the game frame.

## Live evidence

- Simulator screenshot: `i1-fullscreen-composed-frame-2026-08-18.png`.
- Unified log: `OttselShell` reported `layer-drawable=1210x834` for the
  rebuilt bundle; the prior bundle reported 480x320.
- Runtime log loaded `village1.fr3`, then emitted one opaque-TFRAG snapshot
  with 77 batches / 75,960 vertices / 53,304 triangles and a normal-TIE
  visibility submission.  The captured frame visibly contains the Village1
  hill, tower, terrain, trees, and water.

## Boundary

This verifies a full-screen composed iPad game frame.  It does not verify
title-to-gameplay interaction, a visible/customizable touch overlay,
controller hardware, transparent/effect buckets, audio, iPhone layout, or
physical-device acceptance.  Keep this as the P2 renderer baseline, not a
playability pass.

## Shared-input seam checkpoint

On the same live app, a right-side touch and a captured external-keyboard
Space press each produced the same sampled state: Cross `0x4000`, pressure
255, then neutral `0x0`.  A Home/background followed by launch/resume emitted
two bounded lifecycle traces with buttons `0x0`, both sticks `(127,127)`, and
Cross pressure 0; the Village1 frame returned after resume.  This verifies
the transport and neutral contract only.  It is not a visible touch-control
or physical-controller acceptance result.

## Direct/GIF next-gate discriminator

The live Direct trace covered 180 chains: 5,149 transfers, 4,872,064 bytes,
and 24,883 packed GIF tags reached the shell, but the old diagnostic raster
emitted zero sprites, triangles, and strips.  A one-shot probe then copied the
live VIF data for the observed `MSCAL 46` into the retail generic VU program.
It executed the 50,000-instruction guard, capped at PC 332, and emitted zero
XGKICKs/GIF words; the app and composed Village1 frame stayed live afterward.

Do not promote the generic VU interpreter into the product path or raise its
limit.  The remaining sky/effects work is a Direct/GS consumer with explicit
offscreen render-target and final-composition semantics, matching the desktop
`DirectRenderer`/sky path.
