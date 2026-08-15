# S2.2 BOT14: Metal Gfx backend wired -- first game-driven present through CAMetalLayer

Date: 2026-08-15.  Status: IN PROGRESS (backend verified; correct first frame
needs the renderer texture-data flow).

## What is verified (one boot, one Simulator, Windowed, zero faults)

- A Metal GfxRendererModule (`src/shell/metal_gfx.mm`) is registered into the
  runtime's `Gfx::GetCurrentRenderer()` (the iOS stub previously returned
  nullptr, so the game's draw/upload calls were dropped).  All module
  callbacks are set (the previous `bad_function_call` crash from the unset
  `set_pmode_alp` in `PutDisplayEnv` is fixed).
- The game's texture uploads (`pc_texture_upload_now` ->
  `GetCurrentRenderer()->texture_upload_now`) now route through the module:
  bundle logs show "OTTSEL GFX: presented game frame 64x64" (the tpage 0x370
  ocean texture) and the CAMetalLayer presents it scaled fullscreen
  (screenshot `s22-bot14-metal-backend.png`): the shell's log surface is
  replaced by game-driven content through Metal for the first time.
- Boot remains stable (fault log 0 bytes, dispatcher past 86k iterations).

## What is NOT yet correct (honest boundary)

- The decoded frame is NOT a correct Jak image: the tpage's texel data is
  not at the segment[0].block_data directly (that region holds
  pointers/descriptions; e.g. tpage 0x370's block_data begins with
  {0,0,0,0, ptr, ptr, ...}), and the PSMT8 CLUT is located by a heuristic
  that picks the wrong palette (the presented 64x64 frame is pixel noise).
- The correct texture-data flow in the real renderer: the GS texture texels
  are uploaded via the DMA chains (GIF IMAGE packets, e.g. chain
  bank-off 0x50c810 -> CALL tag 0x506310 holding the first GIF IMAGE data)
  into the TextureConverter's VRAM model (psmct32_addr/psmt8_addr swizzle),
  and the tpage (texture_upload_now) supplies the format/layout.  The
  renderer's `send_chain` + `texture_upload_now` must cooperate: chain IMAGE
  payloads -> VRAM, then the draw's give_texture -> download_rgba8888.

## Next steps (renderer core)

1. Parse the DMA chain GIF packets (DmaTag kinds + the GIFtag: nloop/eop/
   flg/nreg) in `send_chain`; route IMAGE payloads into a VRAM array using
   the common swizzle functions (common/texture/texture_conversion.h).
2. In `texture_upload_now`, decode the tpage's texture with the CLUT (the
   correct clut data region; the GoalTexture clutpsm/dest fields) and
   download_rgba8888-style unswizzle.
3. Then the direct draws (the title background quad) can be rasterized from
   the DMA draw GIFs; the title backdrop (tpage-1609) is the expected first
   correct visible frame.

## Files

- `src/shell/metal_gfx.mm` / `metal_shell.h`: the Metal GfxRendererModule +
  the game-frame present path.
- `game/ios_stubs.cpp`: `Gfx::GetCurrentRenderer()` returns the registered
  module (`g_ottsel_metal_renderer`).
- `scripts/build-ios.sh`: compiles/links metal_gfx.mm.
- Evidence: `s22-bot14-metal-backend.png`, `s22-bot14-metal-backend.log`
  (head/tail sample), fault log 0 bytes.


## DMA chain structure (decoded 2026-08-15, second pass)

The first submitted chain (bank-off 0x50c810, captured by the OTTSEL CHAIN
probe) has this structure (DmaTag kinds per common/dma/dma.h):

- 0x50c810: tag {0x50000000, addr 0x506310} = kind CALL (qwc=0) -> jumps to
  the default-registers chain at 0x506310; the renderer expects this first
  CALL to be the common GS register setup ("The first thing the DMA chain
  should be a call to a common default-registers chain" -
  OpenGLRenderer::dispatch_buckets_jak1).
- 0x50c820+: tags {0x20000000, addr 0xce8360..} = kind NEXT (qwc=0) -> the
  bucket draw data (each NEXT points at a tag list like
  {CALL 0x506310, NEXT 0x50c830, ...}).
- At 0x506310: {0x1000000a, 0x00000000} = DmaTag kind CNT (qwc=0x000a = 10
  qwords) -> the transfer data = 160 bytes at 0x506320; followed by
  {0x60000000,...} = kind RET (returns from the CALL).
- The transfer at 0x506320 begins with a GifTag {data[0]=0x9000000000008001:
  nloop=1, eop=1, flg=2 (IMAGE), nreg=2}, then the A+D register values
  (0x44=DIMX, 0x42=ALPHA_1, 0x4e=ZBUF_1, 0x0e=TEX1_1?/0x47=TEST_1,
  0x49=PABE, 0x3b=TEXA, 0x3d=FOGCOL, 0x1c=TEXCLUT, 0x60=SIGNAL ...) - the
  per-frame GS register setup.

The bucket draws (the NEXT-tagged data) are what the renderer's
bucket dispatcher rasterizes; the background/direct draws come first.  The
texture texels arrive as GIF IMAGE payloads (routed into the
TextureConverter's VRAM by the renderer), and the tpage
(texture_upload_now) supplies the format.  The minimal Metal renderer must
implement: DmaFollower walk -> GifTag parse -> register-setup state ->
IMAGE texel -> VRAM swizzle -> draw rasterize (direct/background first).
