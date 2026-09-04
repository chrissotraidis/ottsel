# R1 clean-DGO replay — 2026-08-22

## Question

Determine whether stale Jak 1 object files or a stale VI1.DGO caused the mobile
Village1 texture-family/order divergence.

## Reproduction

- Removed all 518 `out/jak1/obj/*.o` files, then ran a clean `(mi)`; 546 targets
  rebuilt successfully.
- Built and signed `OttselShell.app` with `scripts/build-ios.sh` (`build_rc=0`).
- Installed that bundle into the single booted iPad Pro 11-inch (M4) Simulator.
- Replayed title-wait → Start → Cross → Down×4 → Cross.
- Fresh route reached `GAMEPLAY: enter village1` twice; fault log remained empty.

## Result

The clean rebuild does not fix R1. The first world owner remains static launcher
`2895` on system `0x01bc21a4`, declaring raw page 2/index 10
(`0x00200a00`). AdGif and native consume the same family:

`TEX0=0x2004d2e59930a4d2`, `TBP=0x24d2` (9426), 64×64.

The completed macOS world oracle begins page 2/index 30,
`TEX0=0x2004d1e59930a4f2`, `TBP=0x24f2` (9458). The mismatch survives clean
object/DGO regeneration, so it remains a producer/DGO-link/FR3 ordering issue
before Metal. No TBP remap, camera, shader, or Metal-policy change was made.

## Fresh visual boundary

Screenshot:
`/var/folders/b1/t1t38j255k53b4j97j63gfkh0000gp/T/com.openai.sky.CUAService/Simulator Screenshot 2026-08-22 at 3.37.09 PM.jpeg`

Bounded video: `/tmp/ottsel-video/r1-clean-dgo-1537.mp4` (16 MB); recording
was stopped with SIGINT and `lsof -c SimRender` reported `no live recording`.
The frame shows textured terrain but no Jak, incomplete regions, and debug
touch blocks. This is diagnostic evidence, not playability proof. Audio remains
unproven/zero in the route trace.

## Verdict

R1 remains OPEN. Continue source-side DGO/link/load and FR3 ownership tracing.
