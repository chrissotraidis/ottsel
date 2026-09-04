# R1 TIE alpha source parity — 2026-08-22

## Question

Does the native TIE fragment alpha match the completed OpenGL TFRAG3 source
before changing camera, TBP, depth, or Metal policy?

## Source result

`out/jak-project/game/graphics/opengl_renderer/shaders/tfrag3.vert` multiplies
the interpolated time-of-day alpha once (`fragment_color.a *= 2`). The native
Metal shader in `src/shell/metal_shell.mm` multiplied the uploaded time-of-day
alpha by `4.0`, introducing a native-only alpha mismatch for alpha-tested TIE
draws. The native factor is now `2.0`; no camera/TBP/depth policy was changed.

## Fresh verification

- `./scripts/build-ios.sh`: passed; signed `OttselShell.app` produced.
- `codesign --verify --deep --strict`: passed.
- Installed on the single booted iPad Pro 11-inch (M4) Simulator.
- Fresh post-build frame: `/tmp/.../Simulator Screenshot 2026-08-22 at 2.31.49 PM.jpeg`.
- Fresh bounded video: `/tmp/ottsel-video/r1-tie-alpha-factor-2x-1433.mp4` (19 MB).
- Input replay sent native `W` and `D`; runtime recorded left-stick values
  `(127,0)` and `(255,127)` and hid the touch overlay.
- `KeyboardEventEdge`/`PlatformInput`: 8/8 passed; fault log remained 0 bytes.

## Boundary

The seam changed shape but was still visible in a later fresh frame, and the
scene still has malformed geometry, missing regions, no Jak, and no playability
proof. Keep the alpha correction as source-parity work, but leave composition
and the iPad-first completion gate OPEN.
