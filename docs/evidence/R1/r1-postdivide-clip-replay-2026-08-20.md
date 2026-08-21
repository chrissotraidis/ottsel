# R1 — post-divide native Sprite3 clip conversion

## Result

**OPEN — native coordinate conversion corrected; this phase still produced no
eligible candidate.**

The signed Simulator executable SHA-256 was
`23aa74e8a426aad37ad6bb0f81080970558b5cac75c685bbb2fe04bbc2199378`. The
focused `DirectFixture.*` regression passed 6/6 before the build. The replay
used one iPad Pro 11-inch (M4) Simulator and was shut down afterward.

## Falsifiable change

`sprite_shader_clip_vertex` now sends post-perspective-divide coordinates to
Metal. The desktop OpenGL shader multiplies `gl_Position.xyz` by `w` and the
GL pipeline divides during rasterization; the native Metal Sprite3 vertex has
implicit `w=1`, so passing the homogeneous x/y values was incorrect.

## Replay evidence

The candidate ledger changed from multi-screen bounds to normalized clip-space
values:

```text
candidate=0 index=0 bounds=(1.006,0.518)..(1.233,0.903) usable=false
candidate=2 index=2 bounds=(0.975,0.559)..(1.264,0.862) usable=false
candidate=6 index=6 bounds=(0.149,-0.592)..(0.152,-0.589) usable=false
candidate=12 index=12 bounds=(5.195,2.121)..(5.198,2.125) usable=false
```

The first two are wholly beyond the right edge; candidate 6 is below the
minimum native-probe size. No `native group=...` or
`cpu-raster=skipped-for-native-candidate` line was captured. The replay later
ended at the known Simulator `CAMetalLayer nextDrawable` /
`SimMetalHost` XPC failure. This is a verified coordinate-space correction,
not R1 PASS.

## Next falsifiable increment

Run the corrected probe through a later Village1 Sprite3 phase or a longer
candidate window, then compare the first partially visible/alpha-bearing
record against the desktop 2D item trace. Keep the safety gate and CPU fallback
until a native upload is attributable.
