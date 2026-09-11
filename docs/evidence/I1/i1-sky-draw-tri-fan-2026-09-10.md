# I1.1 SKY_DRAW TRI_FAN completion — 2026-09-10

## Question

Bucket 3 (`SKY_DRAW`) reaches `submit_mobile_native_sky_bucket` with 22-24 GIF
tags yet reports `prim-starts=18 candidates=0 submitted=0`. Does the bucket
carry a PRIM write at all, or does the quad arrive in a form the native walk
skips?

## Change and method

Added a probe-scoped packed-descriptor dump (`OTTSEL PACKED:`, gated on
`native_capture`, bounded to 4 tags per walk) because the REGLIST path already
had one and the packed path did not, and extended the `OTTSEL SKY PRODUCT`
line with the already-counted `triangles`/`sprites`/`strips`/`unhandled-packed`.
Observability only. Built and signed the working tree with the fast relink
script, installed it on the one booted iPad Pro 11-inch (M4) Simulator, and
armed the one-shot `ottsel-enable-native-sky-product` trigger.

The dump shows the packed sky tags carry `pre=1 prim=0x5d` over 4 loops; the
low three bits are `5` = `GsPrim::Kind::TRI_FAN`
(`ref/open-goal-jak-project/repo/common/dma/gs.h:239`). The native `push_vertex`
switch handled only `SPRITE`/`TRI`/`TRI_STRIP` (`src/shell/metal_gfx.mm:2867`)
with no `TRI_FAN` case, so every fan accumulated to the 8-slot cap and never
reached `capture_native_primitive`. Upstream handles it
(`DirectRenderer.cpp:1296`). Added the matching case, keeping vertex 0 as the
fan centre and refilling only slot 1.

## Result: PASS for the fan defect; OPEN for the sky texture

Same session before/after, on the packed population (5 of 8 sampled chains):
`prim-starts=18 vertex-words=76 candidates=0 strips=0` becomes
`candidates=34..40 rejected=0 strips=34..40 unhandled-packed=0`. The walks stay
bounded and terminate on the expected boundary (`end == expected`). The other
three chains are a REGLIST fill quad with `tex0-writes=0`, untextured by
construction; the packed population is the real `SKY_DRAW` list and does carry
PRIM.

The completions still do not render. Every fan samples `tex0-last=0x198005fa0`:
`tbp0=0x1fa0 psm=0 PSMCT32`, 64x64. That address is exact —
`SKY_TEXTURE_VRAM_ADDRS = {8064, 8096}`
(`ref/open-goal-jak-project/repo/game/graphics/texture/TexturePool.h`), and
8096 = `0x1fa0` is the SkyBlend-generated 64x64 buffer (`m_sizes = {32, 64}`,
`SkyBlendCPU.h:20`). It has no VRAM source in the mobile path, so it is pruned
as a texture miss and only the 4-6 untextured fill quads reach `submitted`. No
fake sky texture, gradient, or placeholder is added.

Fresh frame: `docs/evidence/I1/i11-fan-post-2026-09-10.png`,
SHA-256 `10b20554151836625f2d3d299dca51dbf2e1230141b96bf650cc75f8e9bac807`.
TFRAG terrain, buildings, trees, water, and distant mountains are intact with
the black sky retained, the fault log is 0 bytes, and the process stayed alive.
No playability is claimed: the sky is black because its texture source is absent.

Next: bucket 32 is not the source here. A bounded probe of that window
(`TFRAG_TRANS0_AND_SKY_BLEND_LEVEL0`) in the same chains walked 5 transfers
carrying 1 packed tag with `prim-starts=0 image-tags=0`, so it does not
generate `0x1fa0` in these frames. Generate the `0x1fa0`/`0x1f80` buffers
from `SkyBlendHandler`'s contract (accumulate the ADGIF source texture scaled
by intensity, `SkyBlendCPU.cpp:99-186`) before re-examining fan coverage.
