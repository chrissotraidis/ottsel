# G2.2 item 3 (stage 2): the composed eyes are bound and visible - 2026-09-23

Gate G2.2 item 3 (dynamic MERC eyes), stage 2.  Question: stage 1 composed the layers but bound
nothing, so the eichar's eye materials still sampled the level's eye page.  What does binding change?

**Bind design (mirrors upstream).**  `MercDraw::eye_id` is `(pair << 1) | is_r`
(`common/custom_data/Tfrag3Data.h:553`), i.e. the composed slot index, and upstream loads the composed
image at `EYE_BASE_BLOCK_JAK1 + slot` and points the draw at `0xefffff00 | eye_id`.  Natively the
equivalent is a reserved texture slot: `mobile_eye_texture_base()` takes 40 slots from
`g_mobile_next_texture_base` (so it can never collide with a level's range), the bucket-54 consumer
composes every pair it walks into `g_mobile_eye_images[pair*2 + lr]`, and the MERC draw builder overrides
`draw_texture_index` for `eye_id != 0xff` when that slot is valid, uploading the composed 128x128 only
when it differs from the last uploaded copy (a blink changes the lid band; otherwise nothing uploads).

**What the eye sampled before.**  The level texture the eye material used (index 323) is a **4x4 flat
blue-grey page** - `OTTSEL EYE LEVEL PAGE: index=323 4x4` - i.e. the eye was a flat colour patch.

**Measured (iPad Pro 11-inch M4, strict signed profile, `scene-level='training'`, 346 SIGNED MODULE
ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`).**
```
OTTSEL EYE BIND: model=eichar-lod0   eye-id=0x0 slot=0 texture-index=1689
OTTSEL EYE BIND: model=eichar-lod0   eye-id=0x1 slot=1 texture-index=1690
OTTSEL EYE BIND: model=sidekick-lod0 eye-id=0x3 slot=3 texture-index=1692
OTTSEL EYE BIND: model=sidekick-lod0 eye-id=0x2 slot=2 texture-index=1691
```
Both actors' eye materials now sample composed slots (the eichar's pair 0, the sidekick's pair 1), and
the composed slots cover both models because the chain's first two pairs are composed.

**Visual.**  Turning Jak with `ottsel-hold-stick-left` and the D-pad brings his face on screen
(`/tmp/ottsel-g22/heads-big.png`): the eye now shows a light-blue iris with a dark pupil and a
skin-coloured lid band above it, and Daxter's eye reads as a blue/dark eye - where before the bind the
eye was the flat 4x4 page.  Bilinear sampling (matching the oracle's LINEAR filter) is in the composition
from this stage.

**The rim speckles were a source-resolution defect, now fixed.**  `mobile_eye_source` first preferred the
relocated-registry copy of a page; for this palettized (PSMT8) page that copy carries garbage palette
colours, so the iris drew with saturated green/magenta rim texels.  Upstream resolves an eye layer through
the *level's texture pool* by TBP0 (`texture_pool->lookup_gpu_texture(adgif.tex0().tbp0())`), so the source
now tries the same route first: the page's metadata `combo_id` -> `g_mobile_pool_textures` -> the level's
own texture.  `OTTSEL EYE SRC: name=iris path=pool tbp0=0x276f psm=19 cpsm=0 cbp=0x279f registry=1 16x16`,
and the resolved page is a clean blue iris disc.  On the actor the eye now reads as white sclera + blue
iris + dark pupil on Jak and white sclera + dark pupil on Daxter
(`/tmp/ottsel-g22/fixc-heads-big.png`), with a single small speck left above Jak's eye.

**Every pair is composed now, and only on change.**  The walk covers all 20 pairs (it was capped at two)
and recomposes a pair only when its packet signature - the three layer textures and their rects - changes,
so the steady-state cost is one comparison.  Measured: `OTTSEL EYE CHAIN: pairs=2 slots=4 composed=2` on
the first pass, then `composed=0` while nothing moves, then `composed=1` when a pair does (a blink moving
a lid rect).  The chains in this level carry one or two pairs and the draws request only slots 0-3 (the
eichar's pair 0 and the sidekick's pair 1).  A close-range capture on this build still shows white sclera
with a blue iris and dark pupil on Jak, and white sclera with a dark pupil on Daxter
(`/tmp/ottsel-g22/fe2-big.png`).

**Open.**  (a) There is no desktop-capture A/B for the whole eye yet.  (b) One frame of the earlier run
showed a large transient white cloud-like overlay that its neighbouring frames do not - camera-dependent
and not attributed; the reserved eye slots cannot alias another consumer's indices
(`g_mobile_next_texture_base` is used only for level bases, and the sprite path uses a fixed `0x3c00`
base).

Not claimed: no eye-parity closure, no playability, audio or device claim.
