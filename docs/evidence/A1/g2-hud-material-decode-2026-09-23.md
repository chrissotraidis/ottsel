# G2.2 item 3 (HUD/menu material): the menu's material renders, and the in-level absence is the game's own state - 2026-09-23

Gate G2.2 item 3's HUD/menu material sub-item.  Question: does the sprite material reach the screen, and
is anything missing?  Supersedes the two earlier same-dated versions of this note; both of their
explanations are refuted below by measurement.

**The pause menu renders with its material.**  A matched *unfilled* capture of the open pause menu on the
current build shows GEYSER ROCK, 0%, OPTIONS, the four face-button icons on their own panels, Daxter's
head and the ring icons over the level.  Atlas uvs, standalone progress textures, alpha and the blend all
reach pixels, so the sub-item's visible surface is drawn.

**The gated fill control covers working material, not empty cells.**  ottsel-trace-sprite-atlas-fill
redraws the atlas-size batches with a 1x1 opaque white texture.  With the menu open it paints eight white
cells exactly where the menu's panels and icons are - so the previous round's reading "those cells read
near-invisible while the text and icons show" is retracted: the fill was covering them.  With the menu
closed the same control paints nothing, because the closed progress screen sits at NDC x ~ 13.8
(measured last round), which is the game's own animation state.

**The zero-alpha atlas cells are transparent by design - measured before any code change.**  New gated
probe ottsel-trace-hud-texel samples the atlas at each submitted quad's own uv, e.g.
uv=(64.0,0.0) texel=(0,199,202,0) color=(0.502,0.502,0.502,0.502) and uv=(192.0,0.0)
texel=(255,255,255,1).  The sprite fragment state hardcodes tcc=1, and upstream's sprite_3d.frag forces
T0.w = 1.0 only when the texture is *not* alpha-modulated (TCC = 0).  Decoding every HUD/menu tex0 in the
run shows TCC = 1 for all of them (tbp0 0x252d, 0x2517, 0x2506, 0x340, 0x100, 0x380 ... psm 19/20), so
the hardcoded TCC matches this population and a zero-alpha texel is meant to be discarded.  The Direct
path's ta0 substitution encodes the same upstream rule where TCC = 0; it is not needed here.

**The title screen has no material defect.**  The settled title renders (logo, PRESS START, the
PRECURSOR LEGACY text over the village).  The dense glyph lattice visible for the first seconds after
title-wait-ready is a transient opening state: it is gone by +20 s, and it survives with the sprite pass
skipped (ottsel-trace-metal-scene-no-sprite), so it is not the sprite pass.  The solid-colour blocks are
the port's own touch overlay - setTouchOverlay builds a 1x1 white texture and tints it per overlay vertex
colour - and hide_touch_overlay_for_native_input() removes it when real touch input is used, so as drawn
here it is a trigger-input artifact of this harness rather than game material.

**Where the sub-item stands.**  The HUD/menu material path draws what the game submits.  With no menu
open the only in-level sprite population the game sends is the closed progress screen (off-screen) plus
its 4.7%-alpha dimmer, so "no in-level HUD in the captures" is the game's state, not a rejected draw, and
no product fix is owed for this sub-item.  The renderer work left in G2.2 is the SkyBlend composite that
item 2 carried forward.

**Next.**  Implement the SkyBlend handlers (buckets 32/39) so the 64x96 sky texture exists, then draw
bucket 3 from its result instead of skipping it.  Carried forward behind it: the eye item's
desktop-capture A/B.

Not claimed: no playability, audio or device claim.
