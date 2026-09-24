# G2.2 sky: bucket 3 draws from the SkyBlend composite by default - 2026-09-23

Carried-forward G2.2 item 2 work.  Question: with the SkyBlend composite in the lane, should the
SKY_DRAW fan still be skipped?

**It should not.**  The native producer (produce_mobile_sky_blend_bucket) already walks the qwc == 6
copy pairs in buckets 32/39, resolves each source, blends with upstream's equation and registers the
32x32 (tbp 0x1f80) and 64x64 (tbp 0x1fa0) results into g_direct_relocated_textures - exactly where the
SKY_DRAW fan lookup already looks.  What remained was the old default: the bucket returned 0 unless
ottsel-trace-sky-draw-legacy existed, a guard written before the composite existed, when the fan sampled
the uncomposited source and the register-driven additive equation turned it into a rainbow.

**Landed, and scoped to the fan.**  The bucket now draws the sky-draw shape by default in a gameplay
level, keeps the previous skip everywhere else, and logs skip-flag / legacy-flag / level-phase / drawn.
The narrowing matters: the same early return also gated this bucket's generic tfrag-trans path, and
un-gating that path draws a translucent sky sheet across the level (measured while the wide change was
in), so it keeps its previous treatment and is named below as its own defect.  Controls:
ottsel-trace-sky-skip-draw (live per frame) removes the draw; ottsel-trace-sky-draw-legacy still forces
it back on for a same-run A/B.  New bridge accessor: ottsel_metal_sky_skip_draw.

**Measured.**  The producer reports composed content, not noise:

    OTTSEL SKY BLEND: dest tbp=0x1f80 32x32 bytes=4096 nonzero=4096 rgb-texels-live=1024/1024 peak=253 mean=149 alpha-zero=0/1024
    OTTSEL SKY BLEND: dest tbp=0x1fa0 64x64 bytes=16384 nonzero=16384 rgb-texels-live=4096/4096 peak=231 mean=121 alpha-zero=0/4096
    OTTSEL SKY BLEND: produced copies=3 misses=0 vsync=63

**Matched captures, same run, same camera, same time of day** (the flag flipped live between captures):

    in-level, shipped binary   drawn=as-sky vs drawn=skipped: 20441 px changed (1.447%), mean |delta| 137.8/channel, box (1098,98)-(1667,846)
    in-level (wide change)      = 22455 px (1.589%), mean |delta| 121.2/channel, box (1090,98)-(1667,846)
    pause menu open            = 14177 px (1.003%), mean |delta|  81.1/channel, box (1493,707)-(1667,846)

Every difference is confined to the sky region - visually blue with the draw on and black with it off -
so no other path moved.  The dusk orange/purple tint some captures show is present with the draw on
*and* off (the menu-open A/B above confines the change to the sky patch), so it is the level's own
time-of-day lighting, not this change.  Lane health on the shipped run: 346 SIGNED MODULE ENTER =
346 RETURNED, 0-byte ottsel-fault.log, scene-level='training'.

**Production regression.**  The copy equation now lives in src/shell/mobile_sky_blend.h and is used by
the producer; scripts/test-mobile-sky-blend.sh compiles test/mobile_sky_blend_test.cpp on the host and
checks the unity/half/zero/clamped cases plus the whole byte range at four intensities against
upstream's own slow path - PASS.

**The two blend questions behind this item are closed by live measurement** (the ledger arms on every
level selection; both records are NSLog, read from the unified log).  TIE: `TIEREG draws=200
enable=195/5 blend=195/5 preset=0,200,0,0,0,0,0,0` - all 200 sampled draws select preset index 1
(source-over) and the additive enum is never requested.  Direct: `DIRECTREG-MIX arm=2 n=460
r0=0x0:460 r1=0x0:0 r2=0x0:0 r3=0x0:0 other=0` - every Direct batch in every sampled frame (44, 176,
356, 460, 464) carries register 0x0, i.e. Unspecified, so a register-driven selection would select
nothing and the primitive's own blend flag stands.

**Named, not landed.**  (1) The composite is registered under (0x1f80|0x1fa0, psm 0), which matches this
level's sky tex0; another psm would miss it.  (2) The sky bucket's generic path is a measured defect, not
a candidate: with ottsel-trace-sky-draw-legacy forcing the bucket to process its non-sky-draw windows the
settled title becomes a full-frame triangular mosaic (71.720% of pixels changed, mean |delta| 72.8) where
the default shows the composite sky, and in-level the same control moves only 0.673% inside the sky box.
Upstream renders TFRAG TRANS/LOWRES_TRANS geometry there and the port decodes that window as Direct/GIF
packets; the landed default keeps it skipped.  (3) The eye item's desktop A/B.

Not claimed: no playability, audio or device claim.
