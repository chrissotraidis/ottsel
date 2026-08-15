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
