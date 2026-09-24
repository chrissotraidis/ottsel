# G2.2 premise check: the Sky cloud-batch blend site is not live in this build - 2026-09-22

The completion plan's first renderer item is the retained 2026-09-12 finding that Sky cloud batches
request GS ALPHA 0x48 (Cs*As + Cd) while the shell draws them through the source-over
`directBlendPipeline`.  Re-checking that against the accepted source and profile refutes it for this
build: the batch draw block never runs, and the live cloud composite is already additive.

**The batch draw block never executes.**  `ottsel metal: SKYLOOP frame=...` (`metal_shell.mm:1902`) and
`ottsel metal: SKYBOUNDFRAME ...` (`:2142`) are that block's own records, both inside
`if (!sky_batches.empty() && !self.directFixtureIsolated && !self.sceneNoSkyProbe)` (`:1871`).
In a full iPad run that reached the title, Village1 and Training on the current strict build, both
counts are 0 for the whole process, so `sky_batches` was empty on every frame and `directBlendPipeline`
was never selected for a Sky batch.  `sceneNoSkyProbe` is only set by the
`ottsel-trace-metal-scene-no-sky` trigger (absent) and `directFixtureIsolated` only by the Direct
fixture flags, so neither explains the empty store.

**The decode does submit batches, so the loss is after the decode.**  `OTTSEL SKY PRODUCT` samples 6-8
(the process's 8-line budget, all in the title phase) report `leading-kind=NEXT transfers=8
direct-transfers=3 gif-tags=3 packed-tags=2 reglist-tags=1 prim-starts=1 vertex-words=4 candidates=2
rejected=0 texture-misses=0 untextured=2 tex0-writes=0 tex0-last=0x0 triangles=0 sprites=0 strips=2
unhandled-packed=0 primitives=2 submitted=2 ndc=(-1.000,-1.000)..(1.000,1.000) end=0x50c8e0
expected=0x50c8e0`.  Both primitives are untextured `PRIM.TME=0` full-screen strips; the decoder gives
them the 1x1 white texel (`metal_gfx.mm:3436-3443`), so the append loop's `!primitive.texture` test
(`:4394`) is not what drops them, and `submitted=2` says both appends returned true.  Why the published
store still reads empty is therefore **open**; the next probe is a bounded per-frame log of the store's
begin/publish/snapshot state, not more reading.

**The live cloud composite is already additive.**  The composite that does run, `OTTSEL SKY BLEND`, is
`dest = source * blend >> 7` on the first draw and `dest + scaled` saturating at 255 afterwards
(`metal_gfx.mm:4838-4849`), i.e. replace-then-add with the GS APIT rule, so it never consults the
source-over Metal pipeline.

**Consequence.**  Landing an additive `directBlendPipeline` variant now would be unverifiable, because
the selection site is dead in this build, so G2.2's Sky item is closed as stale rather than "fixed".
The loop re-scopes to (a) the bounded store-state probe above, and (b) the blend modes that live sites
actually request - TIE's `draw.mode >> 24` still collapses the additive enum value 2 into the
source-over pipeline (`metal_shell.mm:1796-1808` via `ottsel_mobile_alpha_blend_enabled`,
`mobile_scene_policy.h:120-124`), which is a live path and needs its own bounded measurement first.

**State.**  iPad lane (`08636791-2675-4675-8335-EF72EF954DCF`), one Simulator at a time, strict signed
build, 0-byte `ottsel-fault.log`, Training reached through LOAD GAME with a `GAMEPLAY: enter training`
line.  Not claimed: any renderer change (none was made), nor the MERC-eye or HUD/menu items.
