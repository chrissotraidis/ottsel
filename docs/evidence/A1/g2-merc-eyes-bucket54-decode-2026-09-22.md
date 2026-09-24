# G2.2 item 3 (stage 1): the eye bucket decoder and composition - 2026-09-22

Gate G2.2 item 3 (dynamic MERC eyes).  Question: the eichar's two eye materials
(`eye-id=0x0 tree-tex=323`, `eye-id=0x1 tree-tex=324`, both `ignore-alpha`) draw the level's eye page
on this lane because no eye consumer exists; upstream composes them in bucket 54 and loads the result
into VRAM so the MERC draw samples it.  This stage lands the decoder and the composition.

**Oracle read (`out/jak-project`).**  `BucketId::MERC_EYES_AFTER_PRIS = 54` (`buckets.h:61`).
`EyeRenderer::handle_eye_dma2` (`EyeRenderer.cpp:355-395`) consumes: a 128-byte GS offset/FLUSHA packet, a
32-byte alpha setup, a NEXT/NOP, then per eye slot `get_draws` walks an ADGIF (iris TEX0), the background
draw, iris L, [optional right-ADGIF +] iris R, a test packet, an ADGIF (pupil), pupil L/R, a test packet,
an ADGIF (lid), lid L/R and an end packet.  Each draw is a 32-byte scissor plus a 96-byte sprite whose
`uv0` field carries the FNV hash of the merc-ctrl that reads the eye and whose two xyz pairs are the quad.

**Composition.**  The window is GS 512..1024 at four units per texel (`shaders/eye.vert`:
`gl_Position = (xyst - 768) / 256`), so a vertex at raw `xyz` lands at
`target_px = (xyz - eye_offset)/4 - 128` for the 32-unit layout and `/8 - 128` for the 64-unit one, with
`eye_offset` `(lr*512, pair*512)` or `(lr*1024, (pair/4)*1024)`.  The target starts as the iris page's
(0,0) texel, then iris and lid are copies and only the pupil blends (SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
the result is loaded at `EYE_BASE_BLOCK_JAK1 (8160) + slot`, which is how
`Merc2.cpp:1175`'s `eye_id == 0xff ? tree_tex_id : (0xefffff00 | eye_id)` resolves through
`lookup_eye_texture(eye_id % 40)`.

**Landed (this lane).**  `submit_mobile_native_eye_bucket` in `src/shell/metal_gfx.mm`: the decode above,
a CPU composition into a 128x128 RGBA buffer per slot, submitted once per vsync while a gameplay level is
resident (the sky consumer's gate).  It composes and, when `ottsel-trace-eye-dump` is armed, writes PPMs
of the composed slots and of the source pages.  **It does not bind yet, so no rendering changes.**

**Measured (iPad Pro 11-inch M4, strict signed profile, `scene-level='training'`, 346 ENTER = 346
RETURNED, 0-byte fault log).**  The decode walks the real packets:
```
OTTSEL EYE ADGIF: addr0=0x6 addr1=0x1cf06a14 addr2=0x34 addr3=0x8 addr4=0x42
  -> TEX0_1 / TEX1_1 / MIPTBP1_1 / CLAMP_1 / MIPTBP2_1: the ADGIF block is read correctly
OTTSEL EYE: pair=0 using64=0 iris=0x2004f3e51130a76f pupil=0x200446e51130a231
            lid=0x200446651130a232 lrect=(480,564..936,1020) prect=(596,680..820,904)
  -> remapped into 128x128: iris (-8,13..106,127), pupil (21,42..77,98), i.e. inside the target
OTTSEL EYE SRC: iris tbp0=0x276f psm=19 cpsm=0 cbp=0x279f registry=1 16x16
```
The three layers are separate 16x16 PSMT8 pages with their own CLUTs, resolved from the registered
(uploaded) images the rest of the renderer samples, so the page decode path is the same one the sprite
and sky consumers use.

**Verified visually (dumps in `/tmp/ottsel-g22/src2-*.png`, `eye0b-big.png`).**  The pupil page decodes as
a clean soft black disc - a pupil layer - so the page decode is right.  Two gaps remain: the iris page
carries speckled green/magenta blocks, and the composed slot is blocky because this composition samples
nearest while the oracle uses LINEAR.

**Next (one variable each).**  (a) bilinear sampling in the composition; (b) decide whether the iris
page's speckles are the game's data or a palette issue, by comparing the page with the level texture the
MERC eye draw samples today (slots 323/324); (c) bind: the MERC eye draws (`eye_id != 0xff`) must sample
the composed slot instead of the level slot, which is what makes the eyes right in game.

Not claimed: **the in-game eyes are not fixed yet** - nothing is bound, the rendered eichar still samples
the level page.  No playability, audio or device claim.
