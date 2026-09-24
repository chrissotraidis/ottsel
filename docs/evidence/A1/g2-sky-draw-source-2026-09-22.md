# G2.2: the Sky bucket is upstream's SkyBlend consumer, so this lane must not draw it raw - 2026-09-22

Gate G2.2 item 2 follow-through.  Question: the register-driven additive selection is correct per the
batch register, yet enabling it turned village1's sky into a vivid rainbow.  Name the real source.

**Desktop oracle (read, not guessed).**  `SkyRenderer` is bound to `BucketId::SKY_DRAW`, which the
bucket table documents as bucket **3** (`OpenGLRenderer.cpp:676`, comment `// 3 : SKY_DRAW`).  Its
`render` (`SkyRenderer.cpp:158-247`) is a `DirectRenderer`: NEXT/NOP, an optional CALL for empty sky,
then a **64-byte GIF setup packet**, and only when the *following* tag is `qwc == 5` the draw setup
plus the `CNT DIRECT` sky packets.  The texture those packets sample is the **64x96 sky texture the
SkyBlend handlers composite** (clouds 64x64 + sky 32x32, `SkyRenderer.cpp:15-24`); those handlers are
bound to buckets 32/39 (`TFRAG_TRANS0_AND_SKY_BLEND_LEVEL0`, `..._LEVEL1`, `OpenGLRenderer.cpp:762/780`).

**Live shape ledger (`OTTSEL SKY SHAPE`, 1 Hz, this lane).**  The bucket-3 chain is
`payload-kind=CNT payload-qwc=4 payload-size=64` - exactly the setup packet the desktop asserts -
followed by `after-setup-qwc=5` -> `desktop-path=sky-draw` (occasionally `6` -> `generic-vif`).  So this
is the **sky draw**, not a transparent-tfrag list.  Two earlier readings in this round are retracted:
the `qwc != 8 -> tfrag-trans` branch belongs to `SkyBlendHandler` (buckets 32/39), not to bucket 3, and
the sky tiles do **not** decode to garbage colour data - `OTTSEL SKY TEXEL` shows real sky-source texels
(`tex0=0x154005f80 psm=0 32x32 ... rgba=(131,162,189,128)`, `(136,199,253,128)`, `registry=1`).

**The defect.**  This lane does not implement the SkyBlend composite, so drawing bucket 3 samples the
*uncomposited* relocated source while the port's own sky composite (`OTTSEL SKY BLEND`) already draws
the sky region.  The quads' registers are live additive ones (`SKYREG-MIX`: 32x32 cloud tiles 0x48, the
untextured 1x1 strips 0x44), so the double-draw became a vivid rainbow.  Matched tight pairs, same
camera a second or two apart:
```
/tmp/ottsel-g22/disc/new-9.png   default (quads skipped) -> clean sky over the village
/tmp/ottsel-g22/disc/old-9.png   legacy (quads drawn)   -> rainbow sky, same phase
/tmp/ottsel-g22/fin-fixed-2.png vs /tmp/ottsel-g22/fin-legacy-2.png  the same at another phase
```

**Default now.**  The sky draw is skipped (`drawn=skipped`); a fresh default process logs **no** sky
draw/store records at all over title + training, and the title and the Training level render normally
(`/tmp/ottsel-g22/clean-title.png`, `clean-train.png`).  Lane health unchanged: 346 SIGNED MODULE
ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`, `scene-level='training'`.  The register-driven additive
selection stays landed and unconditional (it is what upstream's DirectRenderer does); it is simply not
reached on this lane until the composite exists.

**Store semantics worth knowing for future A/Bs.**  The sky store *retains* its last published
population, so once the legacy control publishes one (44 batches, 23:18:36) that population keeps being
drawn every frame until something replaces it (`SKYFRAME batches=42` afterwards).  Measure the default
in a fresh process, never after using the legacy control in the same one.

**Controls kept.**  `ottsel-trace-sky-skip-draw` (issue no Sky draw) and `ottsel-trace-sky-draw-legacy`
(draw the bucket quads again = the pre-fix behaviour), both re-read every pass.

**Next (the faithful fix).**  Port the SkyBlend composite (`SkyBlendGPU`/`SkyBlendCPU`: sky copies +
cloud copies into the 64x96 sky texture) and then draw bucket 3 from its result; the decoder, the
additive pipeline state and the register-driven selection are already in place for it.

Not claimed: no SkyBlend implementation, no renderer-parity closure, no playability, audio or device
claim.
