# S2.2 BOT16: correct texture decode -- first real Jak frame via Metal

Date: 2026-08-15.  Status: sub-gate VERIFIED (composed title frame still
needs the 3D bucket renderers; see the honest boundary below).

## What was wrong (the falsifiable fault from the BOT15 handoff)

`decode_first_texture` read the tpage's `segment[0].block_data` as LINEAR
texels and guessed the PSMT8 CLUT with a heuristic.  The result was the
presented 64x64 "pixel noise" frame.  Two things were wrong:

1. The texel data is not linear.  Jak stores every texture PRE-SCRAMBLED so
   it can be uploaded to the GS as a plain PSMCT32 transfer 128 pixels wide
   (`texture.gc` `upload-vram-data`: `gs-bitbltbuf :dbw 2 :dbp seg.dest/64`,
   `gs-trxreg :rrw 128 :rrh size/128`; comment: "all textures are pre-scrambled
   to be uploaded in 32-bit mode").  The GS writes each incoming 32-bit word to
   the swizzled VRAM address `psmct32_addr(x, y, 128)`.
2. The CLUT is not found by a heuristic.  Each texture description carries the
   real fields: `clutpsm` + `clut_dest` (256-byte VRAM units), and the
   texel/CLUT data lives in the tpage's segment blocks in EE memory
   (`page.segment[seg].block_data_ptr`), which ARE valid at `upload-now!` time.

## The fix (runtime-side only; no game source patched)

`src/shell/metal_gfx.mm` now:

1. Keeps a 4 MB fake GS VRAM (`g_vram`).
2. `vram_place_ct32`: replays the GS upload exactly -- each word of the
   segment data is placed at `psmct32_addr(x, y, 128) + seg.dest * 4`
   (segment dest is a 32-bit-word VRAM address; `texture-page` relocate keeps
   `seg.dest` in words and `tex.dest` in 256-byte units, consistent with
   `TexturePool::m_textures[dest]`).
3. `download_texture_rgba8888`: mirrors `TextureConverter::download_rgba8888`
   (PSMT8/PSMT4 + PSMCT32/PSMCT16 CLUTs, CSM1 CLUT scramble, PSMCT16/PSMCT32
   direct) using the texture's `dest[0]`, `width[0]`, `clutpsm`, `clut_dest`.
4. `decode_largest_texture`: places the page's segments (per `mode`) into fake
   VRAM, picks the largest texture description from the pointer array after
   the 124-byte `texture-page` header, and downloads it.
5. Presents the largest decoded texture through the CAMetalLayer (replaces the
   old 64x64 noise frame once a larger correct texture arrives).

Also added the S2.2 renderer-core draw decoder (VIF DIRECT walk + GIF
PACKED/REGLIST register state + prim building) -- the state machine the
rasterizer will use; it logs the first completed prims per chain.

## Verified (one boot, one Simulator, Windowed, zero faults)

- `ottsel-fault.log` = 0 bytes; dispatcher stable; `GAMEPLAY: enter title`
  reached and held.
- The tpage probe confirms the GOAL `texture-page` layout: header 124 bytes,
  `length` texture pointers, segment `{block-data, size, dest}` (e.g. tpage
  0x4fe: len=4, seg0 size=0xa040 words, dest=0x9d180 words; tex0 128x256
  PSMT4 dest0=0x2746 clut_dest=0x29c6).
- Presented real game textures through Metal: 128x64 (tpage 0x1cf tex 44),
  128x128 (tpage 0x2 tex 43), 256x512 (tpage 0x4fe tex 2), 256x512 (tpage
  0x408 tex 3).  The on-screen frame (`s22-bot16-texture-frame.png`) is a
  coherent Jak image (warm red/orange band + green basin -- NOT noise),
  proving the pre-scramble -> CT32 swizzle -> format unswizzle path.
- The title screen's live draw chains are decoded: direct-bucket framebuffer
  copy quads (TRI_STRIP, tme=0, abe=1, tex0 tbp=0x2800/0x3000 tw=9 th=8
  PSMCT32 = the two framebuffers), register setup (DIMX/ALPHA/ZBUF/TEST/PABE/
  TEXA/FOGCOL/TEXCLUT), and VIF UNPACK transfers (the 3D buckets); the title's
  tfrag texture page (tpage 0x1a0 = title-vis-tfrag) uploads with mode=2.

## Honest boundary (S2.2 not fully passed)

The presented frame is a correct real game texture, not yet the COMPOSED title
frame.  The title screen renders a 3D scene (title-vis tfrag/pris/alpha/water
buckets) which needs the TIE/TFRAG renderers (VIF microprogram emulation +
GS state), a large renderer milestone.  The direct-bucket rasterizer (sprite/
triangle draw -> screen) and the framebuffer-copy path are the next renderer
steps; the 3D bucket renderers follow.

## Files

- `src/shell/metal_gfx.mm`: fake VRAM + correct decode + draw-state decoder.
- `docs/evidence/S2/s22-bot16-texture-frame.png` (on-screen frame),
  `s22-bot16-texture-frame.log` (head + presented/probe/title lines).
