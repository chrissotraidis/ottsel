// Ottsel S2.2 — Metal Gfx backend.
//
// Registers a GfxRendererModule with the runtime so the game's texture
// uploads (pc_texture_upload_now -> Gfx::GetCurrentRenderer()) decode the
// tpage's first texture and present it through the shell's CAMetalLayer.
// This is the first visible game frame through Metal (S2.2 sub-gate); the
// full DMA-chain draw decode (send_chain) is the remaining renderer work.

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include <cstring>
#include <vector>

#include "game/graphics/gfx.h"
#include "common/texture/texture_conversion.h"

#include "metal_shell.h"

#include "common/log/log.h"

// The in-game texture-page structures (mirrored from
// game/graphics/texture/TexturePool.h; defined here to keep the iOS shell
// free of the GL/glad dependency chain).
struct OttselGoalTexture {
  s16 w;
  s16 h;
  u8 num_mips;
  u8 tex1_control;
  u8 psm;
  u8 mip_shift;
  u16 clutpsm;
  u16 dest[7];
  u16 clut_dest;
  u8 width[7];
  u32 name_ptr;
  u32 size;
  float uv_dist;
  u32 masks[3];

  s32 segment_of_mip(s32 mip) const {
    if (2 >= num_mips) {
      return num_mips - mip - 1;
    } else {
      return std::max(0, 2 - mip);
    }
  }
};
static_assert(sizeof(OttselGoalTexture) == 60, "OttselGoalTexture size");

struct OttselGoalTexturePage {
  struct Seg {
    u32 block_data_ptr;
    u32 size;
    u32 dest;
  };
  u32 file_info_ptr;
  u32 name_ptr;
  u32 id;
  s32 length;
  u32 mip0_size;
  u32 size;
  Seg segment[3];
  u32 pad[16];
};
static_assert(sizeof(OttselGoalTexturePage) == 124, "OttselGoalTexturePage size");

// The runtime's EE memory base (declared in game/runtime.h).
extern u8* g_ee_main_mem;

namespace {
// The shell's Metal presenter + the current drawable size.
OttselMetal* g_metal = nullptr;
std::vector<unsigned char> g_frame;  // RGBA8 frame buffer for the presenter
int g_fw = 0, g_fh = 0;

// Decode a tpage's first texture into RGBA8 (top-left origin).
// Returns false if the texture can't be decoded.
bool decode_first_texture(const u8* tpage, u32 s7, u8* out_rgba, int& out_w, int& out_h) {
  OttselGoalTexturePage page;
  memcpy(&page, tpage, sizeof(OttselGoalTexturePage));
  if (page.length <= 0 || page.length > 512) {
    return false;
  }
  // description pointer array after the header
  u32 desc_ptr = 0;
  memcpy(&desc_ptr, tpage + sizeof(OttselGoalTexturePage), 4);
  if (desc_ptr == s7 || desc_ptr >= 0x08000000) {
    return false;
  }
  const u8* memory_base = g_ee_main_mem;  // extern from runtime.h
  const u8* desc = memory_base + desc_ptr;
  OttselGoalTexture tex;
  memcpy(&tex, desc, sizeof(OttselGoalTexture));
  out_w = tex.w;
  out_h = tex.h;
  if (out_w <= 0 || out_h <= 0 || out_w > 2048 || out_h > 2048) {
    return false;
  }
  int w = out_w, h = out_h;
  // texel data: the mip0 segment (segment_of_mip(0) for mip 0).
  int seg = tex.segment_of_mip(0);
  if (seg < 0 || seg > 2) {
    return false;
  }
  u32 block_data = page.segment[seg].block_data_ptr;
  if (block_data >= 0x08000000) {
    return false;
  }
  const u8* texel = memory_base + block_data;

  // PSMCT32: 32-bit RGBA texels, stored linearly in the tpage.
  if (tex.psm == 0) {  // PSMCT32
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        const u8* p = texel + (y * w + x) * 4;
        u8* o = out_rgba + (y * w + x) * 4;
        o[0] = p[0];
        o[1] = p[1];
        o[2] = p[2];
        o[3] = p[3];
      }
    }
    return true;
  }
  // PSMT8 (0x13): 8-bit indices + a PSMCT32 CLUT.
  if (tex.psm == 0x13) {
    // locate the CLUT: the tpage stores the palette data after the texels;
    // use the segment's block data + size as a bounded search window.
    u32 seg_size = page.segment[seg].size;
    // First pass: build the palette from the 4KB-aligned region following
    // the texel block (bounded by the segment size), assuming PSMCT32 CLUT.
    // The CLUT size for 256 entries = 1024 bytes; try common offsets.
    const u8* clut = nullptr;
    for (u32 off = 0; off + 1024 <= seg_size && off < 0x8000; off += 16) {
      // heuristic: the CLUT typically starts with a repeating alpha pattern
      // (RGBA entries where alpha == 0x80).  Look for a run of plausible
      // RGBA values.
      const u8* c = texel + off;
      if (c[3] == 0x80 && c[7] == 0x80) {
        clut = c;
        break;
      }
    }
    if (!clut) {
      return false;
    }
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        u8 idx = texel[y * w + x];
        const u8* c = clut + idx * 4;
        u8* o = out_rgba + (y * w + x) * 4;
        o[0] = c[0];
        o[1] = c[1];
        o[2] = c[2];
        o[3] = c[3];
      }
    }
    return true;
  }
  return false;
}

int gfx_init(GfxGlobalSettings&) { return 0; }
std::shared_ptr<GfxDisplay> gfx_make_display(int, int, const char*, GfxGlobalSettings&,
                                             GameVersion, bool) {
  return nullptr;
}
void gfx_exit() {}
u32 gfx_vsync() { return 0; }
u32 gfx_sync_path() { return 0; }
void gfx_send_chain(const void*, u32) {}
void gfx_texture_upload_now(const u8* tpage, int mode, u32 s7_ptr) {
  (void)mode;
  if (!g_metal || !tpage) {
    return;
  }
  int w = 0, h = 0;
  std::vector<unsigned char> rgba;
  rgba.resize(4096 * 4096 * 4);
  if (decode_first_texture(tpage, s7_ptr, rgba.data(), w, h)) {
    g_frame.assign(rgba.begin(), rgba.begin() + (size_t)w * h * 4);
    g_fw = w;
    g_fh = h;
    ottsel_metal_present(g_metal, g_frame.data(), g_fw, g_fh);
    lg::info("OTTSEL GFX: presented game frame {}x{}", w, h);
  } else {
    static int ottsel_gfx_fail = 0;
    if (ottsel_gfx_fail++ < 8) {
      OttselGoalTexturePage page;
      memcpy(&page, tpage, sizeof(OttselGoalTexturePage));
      lg::info("OTTSEL GFX: decode failed (tpage id=0x{:x} len={} mode={})", page.id, page.length,
               mode);
    }
  }
}
void gfx_texture_relocate(u32, u32, u32) {}
void gfx_set_levels(const std::vector<std::string>&) {}
void gfx_set_active_levels(const std::vector<std::string>&) {}
void gfx_force_reload_all() {}
void gfx_force_reload_level(const std::string&) {}
void gfx_force_reload_common() {}
void gfx_set_pmode_alp(float) {}
}  // namespace

const void* ottsel_metal_gfx_register(void* metal) {
  g_metal = static_cast<OttselMetal*>(metal);
  if (!g_metal) {
    return nullptr;
  }
  static GfxRendererModule module;
  module.init = gfx_init;
  module.make_display = gfx_make_display;
  module.exit = gfx_exit;
  module.vsync = gfx_vsync;
  module.sync_path = gfx_sync_path;
  module.send_chain = gfx_send_chain;
  module.texture_upload_now = gfx_texture_upload_now;
  module.texture_relocate = gfx_texture_relocate;
  module.set_levels = gfx_set_levels;
  module.set_active_levels = gfx_set_active_levels;
  module.force_reload_all = gfx_force_reload_all;
  module.force_reload_level = gfx_force_reload_level;
  module.force_reload_common = gfx_force_reload_common;
  module.set_pmode_alp = gfx_set_pmode_alp;
  module.pipeline = GfxPipeline::OpenGL;  // no Metal pipeline enum; value unused
  module.name = "ottsel-metal";
  extern void ottsel_metal_gfx_set_renderer(const GfxRendererModule* m);
  ottsel_metal_gfx_set_renderer(&module);
  return &module;
}

int ottsel_metal_gfx_game_frame(const unsigned char** rgba, int* w, int* h) {
  if (g_fw > 0 && g_fh > 0 && !g_frame.empty()) {
    *rgba = g_frame.data();
    *w = g_fw;
    *h = g_fh;
    return 1;
  }
  return 0;
}
