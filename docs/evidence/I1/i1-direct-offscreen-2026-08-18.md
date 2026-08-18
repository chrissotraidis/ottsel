# I1 Direct/Sprite offscreen decision — 2026-08-18

## Live test

One iPad Pro 11-inch (M4) Simulator runtime was launched from the freshly
built `out/jak-project/out/ios/app/OttselShell.app`. No `gk` process ran
alongside it.

The frame contained real Village1 normal-TIE and opaque-TFRAG terrain, but no
complete title/menu or sky composition. A bounded `ottsel-trace-mobile-direct`
window established that the live title/progress chain contains 14-qword packed
GIF packets (`nloop=1`, `nreg=13`, `prim=0x5c`) and 7,128 triangle strips.

## Rejected CPU diagnostic route

The CPU raster diagnostic decoded those strips but did not compose them into a
foreground frame. The decisive trace sampled the active GS state:

```text
SCISSOR raw=(0,127; 0,127)
triangle screen=(2430,4040)-(2460,4040)
```

Those positions intentionally target an offscreen GS rectangle. The desktop
`DirectRenderer` has explicit offscreen-target handling; the mobile CPU
diagnostic does not. A temporary shader-style transform merely made an
incorrect white bar visible beside the terrain, which confirms that forcing
the data into the final framebuffer is wrong.

## Next falsifiable implementation gate

Implement Direct rendering as a native Metal pass with GS `FRAME`, scissor,
and offscreen render-target state. The first pass is only one title/menu
packet: require a nonzero offscreen Metal draw and a correctly composed title
frame. Do not extend the CPU rasterizer with further coordinate/scissor
guesses.
