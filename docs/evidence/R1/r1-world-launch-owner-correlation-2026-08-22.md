# R1 Village1 world launch-owner correlation — 2026-08-22

## Gate

Trace the producer after `GAMEPLAY: enter village1`, so progress-screen
particles cannot be mistaken for the world Sprite3 phase.

## Fresh route and environment

- Fresh signed iPad build from the regenerated ARM64 Jak 1 artifacts; one
  booted iPad Pro 11-inch (M4) Simulator and one runtime.
- Fresh validated-pack route: title-wait → Start → Cross → Down×4 → Cross;
  `GAMEPLAY: enter village1` was observed twice and the fault log stayed empty.
- MIPS2C launch-owner, AdGif TEX0, and native Sprite3 traces were armed only
  after the fresh post-input Village1 entry.

## Producer/consumer result

The first world owner is static `*part-id-table*` launcher `2895` on system
`0x01bc21a4`; its declared raw texture is `0x00200a00` (page 2, index 10).
The same owner produced AdGif TEX0 `0x2004d2e59930a4d2`, and the GOAL-side
resolved object reports `TBP=9426`, 64×64. Native Sprite3 immediately consumes
`TBP=0x24d2`, `TEX0=0x2004d2e59930a4d2`, 64×64. This is an end-to-end source
owner → AdGif → native consumer correlation, not a renderer-only inference.

The fresh post-Village1 page-2 lookup order begins `24,25,10,41` and later
includes `30,34,9`. The completed macOS route’s first accepted world item is
page-2 index `30`, `TBP=0x24f2`, `TEX0=0x2004d1e59930a4f2`. The mobile owner
selects index 10 before index 30, proving the phase/order divergence before
native Metal. No TBP remap, camera change, shader change, or Metal policy
change is justified.

Source ownership note: no `defpart 2895` exists under `goal_src/jak1`; the
current Jak 1 runtime table still resolves that owner at the live DGO boundary.
The next falsifiable slice is to identify the DGO/link/load ordering that
populates this owner for the Village1 world phase, alongside the page-2 FR3
resource order.

## Visual/audio boundary

Fresh screenshot:
`/var/folders/b1/t1t38j255k53b4j97j63gfkh0000gp/T/com.openai.sky.CUAService/Simulator Screenshot 2026-08-22 at 3.15.21 PM.jpeg`

Fresh bounded video: `/tmp/ottsel-video/r1-world-owner-1515.mp4`.
The live frame shows textured terrain but no Jak, no usable gameplay scene,
debug touch blocks, and a severe incomplete composition. Audio windows remain
`pcm-peak=0`. This is diagnostic evidence, not a playability pass.

## Verdict

R1 remains OPEN. Continue with the source DGO/FR3/link ownership trace before
touching renderer policy; preserve ROM safety and the signed no-runtime-codegen
boundary.
