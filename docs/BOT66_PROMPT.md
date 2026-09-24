# BOT66 PROMPT — close the sky, then prove playability

Status 2026-09-12. Supersedes BOT64/BOT65 on the iPad frame state. Gates map to
docs/16-ipados-ios-goal-loop-2026-08-23.md (M0/I0/I1/I2/I3/P1/D1). Arm ONE probe per run.

## What is now established (screenshots, this session)

The iPad is **not** stuck at a blank frame. This framing was wrong and is retracted.

- I3 (partial): the app boots, advances to `village1` on the press-start trigger, and
  renders terrain, grass, foliage, palm trees, a thatched hut, the water plane, distant
  mountains, and the Jak model, lit and textured. `OTTSEL SUBMITSTAT` reports
  `tie-ready=true tfrag-ready=true merc-submits=52286 eichar=4`; `OTTSEL AUDIO` plays
  `name=fly7`.
- P1 (new, first real input evidence): with the left stick held up for ~7 s the camera
  **panned from a close hut shot to a wide aerial orbit of the whole village**. Two
  screenshots with different SHA-256. Input reaches the game loop.
- Only one visible defect remains: the sky composites to nothing and leaves the pass
  clear colour `MTLClearColorMake(0.03,0.04,0.07,1)` = rgb(8,10,18) at metal_shell.mm:1212.

## The sky defect — what is exonerated

Armed `ottsel-trace-metal-sky-end`, which redraws the captured sky batches at the **end**
of the pass through the real product pipeline with no later geometry to overdraw them.
Result: 99.3 % of the top 40 % is *exactly* the clear colour. The probe's own documented
matrix says this refutes pass position and state residue, and points at the sampled
texture content.

Also exonerated: vertex layout/stride (32 B), the `directLayout` attribute map, cull mode
(Metal default none), blend math vs upstream `SkyBlendCPU.cpp:94-186`, and the batch
geometry. `SKYVERT` shows real covering fans and the magenta debug-fill paints 99.5 % of
the same region from the same buffers.

Remaining discriminator: a fragment that samples the texture paints nothing, a fragment
that returns a constant paints. The one unshared step is the
`setFragmentTexture`/`setFragmentSamplerState`/`setFragmentBytes` triple.

## BOT66 lane (do these in order, one probe per run)

1. `direct_fs_debug_tex` (metal_shell.mm:~103) — change the body from the texture sample to
   `return float4(fract(in.uv), 0.5, 1.0);`. Arm `-sky-debug-tex`. UV gradient in the sky
   region => fragments interpolate and the texture bind is the defect. Still clear => the
   draw is dropped, and the texture/sampler bind is the only unshared call left.
2. If bound-step is confirmed: add `__strong`/explicit retain verification for
   `NativeSpriteBatch::texture` through `OttselMobileSnapshotStore::snapshot()` and confirm
   `sky.texture` is non-nil and its device matches `self.device` at draw time.
3. Carry BOT65's open CLUT anomaly: sky source `tbp=0x10 psm=19 cbp=0x50` reads an
   all-zero CLUT while `tbp=0x14`/`0x20` read real CLUTs. If the sampled texture is the
   uploaded decode, a zero CLUT is sufficient to make every texel alpha 0 and reproduce
   the no-fragment reading under `srcBlend=SourceAlpha`.
4. Only then, geometry wedges: the magenta field has diagonal boundaries the world does
   not fill.

## Exit bars (unchanged, do not move)

One fresh **inspected** Simulator frame or clip per experiment with SHA-256; paired
controls so a win cannot be coincidental overdraw; `ottsel-fault.log` at 0 bytes;
signed-native, ROM-safe, non-JIT. A Mac boot, counters, logs, title screen, or first frame
is not playability proof. Playability still requires sustained gameplay with input,
camera follow, stability, and audio.
