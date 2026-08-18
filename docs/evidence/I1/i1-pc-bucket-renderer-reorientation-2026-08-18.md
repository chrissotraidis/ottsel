# I1 — iPad scene-state / PC-renderer boundary (2026-08-18)

## Scope

One iPad Pro 11-inch (M4) Simulator runtime, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, launched with `simctl` after a signed
`scripts/build-ios.sh` bundle rebuild. No macOS `gk` process was running.
The app was terminated and the Simulator shut down before source inspection.

## Visible result

Computer Use captured a black game surface with the small teal shell loading
indicator. This is not a rendered-title or playable-scene pass.

## Live facts

The app log recorded all of the following in the same run:

- `village1-vis` loaded and linked successfully.
- `LEVELSTAT` reported `slot0=active` and `slot1=active` with nonzero BSPs.
- `BGWORK` reported `tfrag-count=0x1` and `tie-count@476=0x3`.
- The shell's existing VU diagnostic recorded TFRAG execution and occasional
  small GIF output, but did not produce a visible scene frame.

An opt-in trace at the mips2c `draw-inline-array-instance-tie` scratchpad copy
did not fire. This is expected from the actual PC-port source, not evidence of
a failed level transition.

## Source explanation

`goal_src/jak1/engine/gfx/tie/tie-methods.gc` deliberately comments out the
normal TIE VU calls `draw-inline-array-instance-tie` and
`draw-inline-array-prototype-tie-asm`. Its adjacent comment says non-generic
TIE is drawn in C++ for the PC port. The iOS shell has no equivalent renderer;
therefore routing arbitrary `MSCAL` traffic through TFRAG microcode cannot
produce the active Village1 TIE geometry.

## Decision

Do not extend the VU/software-rasterizer as the product path. The next mobile
renderer gate is a platform-neutral seam fed by the same PC-port bucket inputs
as macOS, beginning with the live TIE bucket. It must produce matching bounded
submission/cull/texture-miss counters and a visibly composed iPad frame before
the title or Village1 renderer gate can pass.
