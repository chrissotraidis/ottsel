# G2.2 item 2 ledger: which blend equations the live sites actually request - 2026-09-22

Gate G2.2 item 2.  Question: the loop wants an additive (`Cs*As + Cd`, GS ALPHA 0x48 / DrawMode
AlphaBlend enum 2) Metal state landed *only at the sites a ledger proves request it*, and TIE's
`(draw.mode >> 24) & 7` was reported to collapse the additive enum into the source-over pipeline.
So record, per live site, the raw GS blend register the population carries.

**Method.**  `ottsel_metal_arm_blend_ledger` (`src/shell/metal_shell.mm`, declared in
`src/shell/metal_shell.h`) re-arms a bounded per-site sample on every scene-level selection
(`select_mobile_scene_level`, `src/shell/metal_gfx.mm`), so the ledger covers the title backdrop,
Village1 and the routed level instead of only the process' first frames.  Each site then emits at most:
4 `SKYREG` lines (textured Sky batches), 4 `DIRECTREG` lines (Direct batches) and one `TIEREG`
histogram after 200 post-arm TIE draws.  Observability only; no pipeline selection changed.
`diagnostic_alpha` is the decoder's `GsRegisterAddress::ALPHA_1` value (`metal_gfx.mm:3872`,
attached at `:3483`), i.e. the raw GS ALPHA register, not the vertex alpha.

**Route measured.**  iPad Pro 11-inch M4 `08636791-...`, one Simulator, strict signed profile
`config/signed-game-cgo-tit-vi1-control.json`; `scripts/replay-ios-normal-route.py` drove title ->
NEW GAME -> CONTINUE WITHOUT SAVING -> `GAMEPLAY: enter title/village/misty`,
`scene-level='training'`, eichar 112, `ottsel-fault.log` 0 bytes.  18 ledger arms ran across the route;
every arm repeated the same numbers:

```
SKYREG    i=0..3 blended=1 diagnostic-alpha=0x44 va=0.502 tex=32x32 n=3
DIRECTREG i=0..3 blended=1 diagnostic-alpha=0x0  tex=256x512 n=3
TIEREG    draws=200 enable=196/4 blend=196/4 preset=0,199,0,0,1,0,0,0
```

**Reading.**  The live Sky cloud batch requests ALPHA 0x44 - the port's own source-over packing
(`gs.h:205-220`, the same decode that calls 0x48 additive) - on both the title snapshot and the
post-route arms, so the shell's `directBlendPipeline` (source-over, `metal_shell.mm` sky loop) matches
what the batch asks for.  No Sky batch carried 0x48 in any sampled window.  The live TIE population asks
for the 3-bit AlphaBlend preset 1 on 199 of 200 draws and preset 4 on one; preset 2 (the additive enum)
appears zero times.  The blend-enable bit is clear on 4 draws and `alpha_blend_enabled` is false on the
same 4, i.e. today's policy (0 / 6 are copy modes, everything else is source-over) is the one the
population exercises.  The Direct text/logo batches carry register 0 (no ALPHA_1 transfer in those
buckets) with `blended=1`.

**Consequence.**  Additive pipeline states would still be unverifiable on this population, but for the
right reason: the live registers are source-over (0x44 / preset 1), measured directly, not because the
selection site is dead (that premise is refuted in
`evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md`).  If the retained 2026-09-12 host capture
really carries ALPHA 0x48 for cloud batches 4-34, that is a *different* population (a Training capture on
the desktop lane) and it has to be reproduced on a lane where it occurs before a blend change is landed;
the GS/DrawMode equation decoder regression the loop asks for also needs that population as its input.

Not claimed: no blend change landed, no renderer fix, no playability or audio claim.

Limitation: the arm and the counters live on the shell object and are touched from the draw pass
(main thread) and the camera/level-selection path (game thread) without a lock, so an arm can race
a count.  Every measured arm still printed the same numbers, and the ledger never feeds rendering -
it is a diagnostic, not an input.
