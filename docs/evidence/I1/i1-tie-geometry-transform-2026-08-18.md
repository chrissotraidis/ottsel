# I1 — iPad Metal TIE geometry / transform gate (2026-08-18)

## Scope

One iPad Pro 11-inch (M4) Simulator, UDID
`08636791-2675-4675-8335-EF72EF954DCF`. The macOS game was not running. Each
rebuild was installed only after the prior Simulator app was terminated; the
Simulator was shut down after the final Computer Use capture.

## Inputs proven live

The signed `scripts/build-ios.sh` bundle includes local generated FR3 files
and the zstd reader required to load them. Its runtime log reported:

- `village1` FR3: 12 TIE trees, 626 draws, and 1,563,934 unpacked vertices.
- The selected first normal TIE tree: 319,546 vertices, 30 normal draws, and
  253,196 expanded triangles uploaded to the Metal shell.
- A finite `village1` PC-port camera packet with translation
  `(-543372.938, 194381.125, 896867.750)`.

## Falsified first hypothesis

The original untextured Metal draw remained black. A bounded CPU replay of the
same desktop `make_new_cam_mat` and vertex calculation found all 4,097 sampled
vertices finite, with 1,876 in OpenGL clip space (`-w <= z <= w`) but none in
Metal's native depth range (`0 <= z <= w`). This isolated a depth-convention
compatibility error rather than missing FR3 data, an invalid camera, or an
encoder failure.

## Change and observed result

The Metal vertex shader now remaps only clip depth with
`z = (z + w) * 0.5`, preserving the desktop x/y/w calculation. A fresh single
Simulator run, inspected through Computer Use, visibly showed a flat-green
Village1 TIE mesh on the game surface. This is the first mobile scene geometry
frame through the real Metal renderer.

## Gate status

**Passed:** shared FR3 loading, PC-port camera capture, normal-TIE mesh upload,
world-to-clip compatibility, and a visible Metal scene submission.

**Still open:** TIE visibility/BVH selection, textures, time-of-day colors,
fog, depth and blend modes, other TIE categories, TFRAG, Merc, sprites/direct
effects, title visual parity, game input playthrough, iPhone-sized Simulator,
physical device, and audible output-only audio.
