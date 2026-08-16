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
#include "common/dma/dma_chain_read.h"
#include "common/dma/gs.h"

#include "metal_shell.h"
#include "tfrag_microcode.h"

#include "vu1.h"

#include "common/log/log.h"

// The app's bundle directory (src/shell/ios_boot.cpp), for evidence dumps.
extern std::string ottsel_ios_bundle_dir();

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

// Symbol lookup into the linked GOAL world.  The Metal headers typedef Ptr
// (MacTypes.h) so the runtime's kmachine.h cannot be included here; declare
// the exact wrapper type to keep the mangled symbol identical.
struct InternFromCInfo {
  u32 offset;
  u32 value;
};
struct CommonPCPortFunctionWrappers {
  std::function<InternFromCInfo(const char*)> intern_from_c;
  std::function<u64(const char*)> make_string_from_c;
};
extern CommonPCPortFunctionWrappers g_pc_port_funcs;

namespace {
// The shell's Metal presenter + the current drawable size.
OttselMetal* g_metal = nullptr;
std::vector<unsigned char> g_frame;  // RGBA8 frame buffer for the presenter
int g_fw = 0, g_fh = 0;

// Fake GS VRAM (4 MB).  The game stores every texture pre-scrambled so it can
// be uploaded to VRAM as a plain PSMCT32 transfer 128 pixels wide
// (texture.gc upload-vram-data: gs-bitbltbuf dbw=2 dbp=seg.dest/64,
// gs-trxreg rrw=128 rrh=size/128).  We replay that placement here, then
// un-swizzle with the texture's own format (download_rgba8888-style).
std::vector<u8> g_vram(4 * 1024 * 1024);

// Place `size_words` 32-bit words of pre-scrambled texture data into fake VRAM
// exactly as the GS would for a PSMCT32 IMAGE transfer 128 px wide.
void vram_place_ct32(const u8* data, u32 seg_dest_words, u32 size_words) {
  u32 words = std::min(size_words, 1024u * 1024u);  // 4 MB / 4 bytes
  for (u32 i = 0; i < words; i++) {
    u32 x = i % 128;
    u32 y = i / 128;
    u32 addr = psmct32_addr(x, y, 128) + seg_dest_words * 4;
    if (addr + 4 <= g_vram.size()) {
      memcpy(g_vram.data() + addr, data + i * 4, 4);
    }
  }
}

// Un-swizzle a texture from fake VRAM into linear RGBA8888 (top-left origin).
// Mirrors common/texture/TextureConverter.cpp download_rgba8888.
bool download_texture_rgba8888(u8* result,
                               u32 vram_addr,
                               u32 goal_tex_width,
                               u32 w,
                               u32 h,
                               u32 psm,
                               u32 clut_psm,
                               u32 clut_vram_addr) {
  u32 out_offset = 0;
  auto get32 = [&](u32 addr) -> u32 {
    if (addr + 4 > g_vram.size()) {
      return 0;
    }
    u32 v = 0;
    memcpy(&v, g_vram.data() + addr, 4);
    return v;
  };
  auto get16 = [&](u32 addr) -> u16 {
    if (addr + 2 > g_vram.size()) {
      return 0;
    }
    u16 v = 0;
    memcpy(&v, g_vram.data() + addr, 2);
    return v;
  };
  auto get8 = [&](u32 addr) -> u8 {
    if (addr >= g_vram.size()) {
      return 0;
    }
    return g_vram[addr];
  };
  if (psm == 0) {  // PSMCT32, no clut.
    int read_width = 64 * goal_tex_width;
    for (u32 y = 0; y < h; y++) {
      for (u32 x = 0; x < w; x++) {
        u32 addr = psmct32_addr(x, y, read_width) + vram_addr * 256;
        u32 v = get32(addr);
        memcpy(result + out_offset, &v, 4);
        out_offset += 4;
      }
    }
    return true;
  }
  if (psm == 0x13 && (clut_psm == 0 || clut_psm == 2)) {  // PSMT8 + clut.
    int read_width = 64 * goal_tex_width;
    for (u32 y = 0; y < h; y++) {
      for (u32 x = 0; x < w; x++) {
        u32 addr8 = psmt8_addr(x, y, read_width) + vram_addr * 256;
        u8 value = get8(addr8);
        // CSM1 CLUT scramble (GS manual 2.7.3, IDTEX8).
        u32 clut_chunk = value / 16;
        u32 off_in_chunk = value % 16;
        u8 clx = 0, cly = 0;
        if (clut_chunk & 1) {
          clx = 8;
        }
        cly = (clut_chunk >> 1) * 2;
        if (off_in_chunk >= 8) {
          off_in_chunk -= 8;
          cly++;
        }
        clx += off_in_chunk;
        u32 clut_addr = psmct32_addr(clx, cly, 64) + clut_vram_addr * 256;
        u32 clut_value =
            (clut_psm == 0) ? get32(clut_addr) : (u32)rgba16_to_rgba32(get16(clut_addr));
        memcpy(result + out_offset, &clut_value, 4);
        out_offset += 4;
      }
    }
    return true;
  }
  if (psm == 0x14 && (clut_psm == 0 || clut_psm == 2)) {  // PSMT4 + clut.
    int read_width = 64 * goal_tex_width;
    for (u32 y = 0; y < h; y++) {
      for (u32 x = 0; x < w; x++) {
        u32 addr4 = psmt4_addr_half_byte(x, y, read_width) + vram_addr * 512;
        u8 value = get8(addr4 / 2);
        if (addr4 & 1) {
          value >>= 4;
        } else {
          value &= 0x0f;
        }
        u8 clx = value & 0x7;
        u8 cly = value >> 3;
        u32 clut_addr = (clut_psm == 0) ? psmct32_addr(clx, cly, 64) : psmct16_addr(clx, cly, 64);
        clut_addr += clut_vram_addr * 256;
        u32 clut_value =
            (clut_psm == 0) ? get32(clut_addr) : (u32)rgba16_to_rgba32(get16(clut_addr));
        memcpy(result + out_offset, &clut_value, 4);
        out_offset += 4;
      }
    }
    return true;
  }
  if (psm == 2) {  // PSMCT16, no clut.
    int read_width = 64 * goal_tex_width;
    for (u32 y = 0; y < h; y++) {
      for (u32 x = 0; x < w; x++) {
        u32 addr = psmct16_addr(x, y, read_width) + vram_addr * 256;
        u32 v = rgba16_to_rgba32(get16(addr));
        memcpy(result + out_offset, &v, 4);
        out_offset += 4;
      }
    }
    return true;
  }
  return false;
}

// Decode the largest texture of a tpage into RGBA8 (top-left origin).
// The texel data is pre-scrambled for a 128-px CT32 upload; we place the
// page's segments into fake VRAM (as the GS would) and then un-swizzle.
// Returns false if no texture can be decoded.
bool decode_largest_texture(const u8* tpage, int mode, u32 s7, u8* out_rgba, int& out_w,
                            int& out_h, u32* out_tex_id) {
  OttselGoalTexturePage page;
  memcpy(&page, tpage, sizeof(OttselGoalTexturePage));
  if (page.length <= 0 || page.length > 512) {
    return false;
  }
  bool seg_ok[3] = {false, false, false};
  if (mode == -1) {
    seg_ok[0] = seg_ok[1] = seg_ok[2] = true;
  } else if (mode == 0) {
    seg_ok[0] = true;
  } else if (mode == -2) {
    seg_ok[0] = seg_ok[1] = true;
  } else if (mode == 2) {
    seg_ok[2] = true;
  } else {
    return false;
  }
  const u8* memory_base = g_ee_main_mem;
  // Place the page's segment data (pre-scrambled CT32) into fake VRAM.
  for (int s = 0; s < 3; s++) {
    if (!seg_ok[s]) {
      continue;
    }
    u32 ptr = page.segment[s].block_data_ptr;
    u32 sz = page.segment[s].size;
    u32 dest = page.segment[s].dest;
    if (!ptr || ptr >= 0x08000000 || sz == 0 || sz > 1024u * 1024u) {
      continue;
    }
    vram_place_ct32(memory_base + ptr, dest, sz);
  }
  // Pick the largest texture description (pointer array after the header).
  int best_idx = -1;
  s32 best_area = 0;
  OttselGoalTexture best;
  for (int i = 0; i < page.length; i++) {
    u32 desc_ptr = 0;
    memcpy(&desc_ptr, tpage + sizeof(OttselGoalTexturePage) + 4 * i, 4);
    if (desc_ptr == s7 || desc_ptr == 0 || desc_ptr >= 0x08000000) {
      continue;
    }
    OttselGoalTexture tex;
    memcpy(&tex, memory_base + desc_ptr, sizeof(OttselGoalTexture));
    s32 area = tex.w * tex.h;
    if (tex.w > 0 && tex.h > 0 && tex.w <= 2048 && tex.h <= 2048 && area > best_area) {
      best_area = area;
      best_idx = i;
      best = tex;
    }
  }
  if (best_idx < 0) {
    return false;
  }
  out_w = best.w;
  out_h = best.h;
  if (out_tex_id) {
    *out_tex_id = (u32)best_idx;
  }
  return download_texture_rgba8888(out_rgba, best.dest[0], best.width[0], out_w, out_h, best.psm,
                                   best.clutpsm, best.clut_dest);
}

int gfx_init(GfxGlobalSettings&) { return 0; }
std::shared_ptr<GfxDisplay> gfx_make_display(int, int, const char*, GfxGlobalSettings&,
                                             GameVersion, bool) {
  return nullptr;
}
void gfx_exit() {}
u32 gfx_vsync() { return 0; }
u32 gfx_sync_path() { return 0; }
// S2.2 renderer core: walk the DMA chain with the runtime's own DmaFollower,
// decode the VIF DIRECT / GIF draw packets (register state + prims), and log
// the first few completed prims per chain so the title-screen draws can be
// inspected.  This is also the draw-state machine the rasterizer will use.

namespace {
struct OttselVertex {
  u32 x = 0, y = 0, z = 0;  // GS coordinates (x/y in 2^16 units)
  float s = 0, t = 0, q = 1;
  u8 r = 128, g = 128, b = 128, a = 128;
  bool has_st = false;
  bool has_uv = false;
  u32 uv_u = 0, uv_v = 0;
};

struct OttselDrawState {
  u64 prim = 0;
  u64 tex0 = 0;
  u64 tex1 = 0;
  u64 alpha = 0;
  u64 zbuf = 0;
  u64 test = 0;
  u64 clamp = 0;
  u64 frame = 0;
  u64 xyoffset = 0;
  u64 scissor = 0;
  u64 texa = 0;
  float st[3] = {0, 0, 1};
  u32 rgba[4] = {128, 128, 128, 128};
  bool st_valid = false;
  bool rgba_valid = false;
  bool uv_valid = false;
  u32 uv_u = 0, uv_v = 0;
};

// ---------------------------------------------------------------------------
// Direct-bucket rasterizer (S2.2 renderer core, second piece).
// Rasterizes the decoded TRI/TRI_STRIP/SPRITE prims into a 512x448 RGBA
// buffer using the reference DirectRenderer math, samples textures from the
// fake VRAM via the TEX0 state, and presents the composed frame.
// ---------------------------------------------------------------------------

struct OttselTexCache {
  u32 tbp = 0;
  u32 w = 0, h = 0;
  u32 psm = 0, cpsm = 0, cbp = 0;
  std::vector<u8> rgba;  // linear RGBA8
};

struct OttselRaster {
  std::vector<u8> fb;  // 640x448 RGBA8 (the GS framebuffer)
  int fb_w = 640, fb_h = 448;
  float x_off = 0, y_off = 0;
  u32 scissor[4] = {0, 0x7ff, 0, 0x7ff};
  bool scissor_enable = false;
  OttselTexCache tex;
  int draw_count = 0;

  void clear(u32 rgb = 0) {
    std::fill(fb.begin(), fb.end(), (u8)rgb);
    draw_count = 0;
  }

  // Convert GS 16.16 x/y to screen pixels (reference DirectRenderer
  // shader: x normalized to 0-1 -> NDC (x-0.5)*16 -> viewport 640px, so the
  // screen pixel is simply x*fb_w; y is flipped with the -32 factor).
  void to_screen(u32 x16, u32 y16, float& sx, float& sy) const {
    float gx = (float)x16 / (float)UINT32_MAX + x_off;
    float gy = (float)y16 / (float)UINT32_MAX + y_off;
    sx = gx * (float)fb_w;
    sy = (1.f - gy) * (float)fb_h;
  }

  // Decode the texture referenced by the current TEX0 state from fake VRAM.
  void load_tex(u32 tbp, u32 tw, u32 th, u32 psm, u32 cbp, u32 cpsm) {
    u32 w = 1u << tw;
    u32 h = 1u << th;
    if (tex.tbp == tbp && tex.w == w && tex.h == h && tex.psm == psm && tex.cbp == cbp &&
        tex.cpsm == cpsm && !tex.rgba.empty()) {
      return;
    }
    tex.tbp = tbp;
    tex.w = w;
    tex.h = h;
    tex.psm = psm;
    tex.cbp = cbp;
    tex.cpsm = cpsm;
    tex.rgba.assign((size_t)w * h * 4, 0);
    if (w > 2048 || h > 2048 || w == 0 || h == 0) {
      return;
    }
    // The TEX0 width in 64-texel units for download_texture_rgba8888.
    u32 tw64 = w / 64;
    download_texture_rgba8888(tex.rgba.data(), tbp, tw64, w, h, psm, cpsm, cbp);
  }

  void blend_px(int x, int y, u8 r, u8 g, u8 b, u8 a) {
    if (x < 0 || y < 0 || x >= fb_w || y >= fb_h) {
      return;
    }
    u8* o = fb.data() + ((size_t)y * fb_w + x) * 4;
    if (a >= 255) {
      o[0] = r;
      o[1] = g;
      o[2] = b;
      o[3] = 255;
      return;
    }
    u32 ia = 255 - a;
    o[0] = (u8)(((u32)r * a + o[0] * ia) / 255);
    o[1] = (u8)(((u32)g * a + o[1] * ia) / 255);
    o[2] = (u8)(((u32)b * a + o[2] * ia) / 255);
    o[3] = 255;
  }

  // Rasterize a triangle with per-vertex xyz(16.16), stq, rgba.
  // tex_mode: 0 = untextured flat color, 1 = textured ST, 2 = textured UV.
  void tri(const OttselVertex& a,
           const OttselVertex& b,
           const OttselVertex& c,
           bool tme,
           bool fst,
           bool abe,
           u8 ta0) {
    float ax, ay, bx, by, cx, cy;
    to_screen(a.x, a.y, ax, ay);
    to_screen(b.x, b.y, bx, by);
    to_screen(c.x, c.y, cx, cy);
    float area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    if (area == 0.f) {
      return;
    }
    float minx = std::max(0.f, std::min(ax, std::min(bx, cx)));
    float maxx = std::min((float)fb_w - 1.f, std::max(ax, std::max(bx, cx)));
    float miny = std::max(0.f, std::min(ay, std::min(by, cy)));
    float maxy = std::min((float)fb_h - 1.f, std::max(ay, std::max(by, cy)));
    // Sample only fragments that pass the scissor.
    if (scissor_enable) {
      float s0 = (float)scissor[0], s1 = (float)scissor[1];
      float t0 = (float)scissor[2], t1 = (float)scissor[3];
      minx = std::max(minx, s0);
      maxx = std::min(maxx, s1);
      miny = std::max(miny, t0);
      maxy = std::min(maxy, t1);
      if (minx > maxx || miny > maxy) {
        return;
      }
    }
    for (int y = (int)miny; y <= (int)maxy; y++) {
      for (int x = (int)minx; x <= (int)maxx; x++) {
        float px = (float)x + 0.5f, py = (float)y + 0.5f;
        float wa = ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area;
        float wb = ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area;
        float wc = 1.f - wa - wb;
        if (wa < 0.f || wb < 0.f || wc < 0.f) {
          continue;
        }
        // interpolate rgba (gouraud)
        float r = wa * a.r + wb * b.r + wc * c.r;
        float g = wa * a.g + wb * b.g + wc * c.g;
        float bl = wa * a.b + wb * b.b + wc * c.b;
        float al = wa * a.a + wb * b.a + wc * c.a;
        u8 out_r = (u8)(r * 0.5f), out_g = (u8)(g * 0.5f), out_b = (u8)(bl * 0.5f);
        u8 out_a = (u8)(al);
        if (tme) {
          // perspective-correct ST or direct UV
          float s, t;
          if (fst) {
            // UV mode: u,v in 1/16 texel units, no perspective correction.
            float u = wa * (float)(a.uv_u >> 4) + wb * (float)(b.uv_u >> 4) +
                      wc * (float)(c.uv_u >> 4);
            float v = wa * (float)(a.uv_v >> 4) + wb * (float)(b.uv_v >> 4) +
                      wc * (float)(c.uv_v >> 4);
            s = u / (float)tex.w;
            t = v / (float)tex.h;
          } else {
            float sq = wa * (a.s / a.q) + wb * (b.s / b.q) + wc * (c.s / c.q);
            float tq = wa * (a.t / a.q) + wb * (b.t / b.q) + wc * (c.t / c.q);
            float iq = wa * (1.f / a.q) + wb * (1.f / b.q) + wc * (1.f / c.q);
            s = (iq != 0.f) ? sq / iq : 0.f;
            t = (iq != 0.f) ? tq / iq : 0.f;
          }
          int tx = (int)(s * (float)tex.w);
          int ty = (int)(t * (float)tex.h);
          tx = tx < 0 ? 0 : (tx >= (int)tex.w ? (int)tex.w - 1 : tx);
          ty = ty < 0 ? 0 : (ty >= (int)tex.h ? (int)tex.h - 1 : ty);
          if (!tex.rgba.empty()) {
            const u8* tp = tex.rgba.data() + ((size_t)ty * tex.w + tx) * 4;
            // modulate: color = frag_color * tex * 2 (the reference shader
            // doubles after modulation); alpha from TCC/TA0.
            out_r = (u8)std::min(255.f, r * 2.f * tp[0] / 255.f);
            out_g = (u8)std::min(255.f, g * 2.f * tp[1] / 255.f);
            out_b = (u8)std::min(255.f, bl * 2.f * tp[2] / 255.f);
            out_a = tp[3] != 0 ? (u8)std::min(255.f, al * 2.f * tp[3] / 255.f) : ta0;
          }
        }
        if (abe) {
          blend_px(x, y, out_r, out_g, out_b, out_a);
        } else {
          if (x >= 0 && x < fb_w && y >= 0 && y < fb_h) {
            u8* o = fb.data() + ((size_t)y * fb_w + x) * 4;
            o[0] = out_r;
            o[1] = out_g;
            o[2] = out_b;
            o[3] = 255;
          }
        }
      }
    }
    draw_count++;
  }
};

// The draw decoder: tracks GS registers and emits completed prims.
struct OttselGifDecoder {
  OttselDrawState st;
  OttselRaster* rst = nullptr;
  OttselVertex verts[8];
  int vert_count = 0;
  u32 prims_logged = 0;
  u32 chain_no = 0;
  u32 reglist_dumps = 0;

  void on_prim_start(u64 prim) {
    st.prim = prim;
    vert_count = 0;
  }

  void on_vertex() {
    if (vert_count >= 8) {
      return;
    }
    OttselVertex& v = verts[vert_count++];
    v = OttselVertex();
    if (st.st_valid) {
      v.s = st.st[0];
      v.t = st.st[1];
      v.q = st.st[2];
      v.has_st = true;
    }
    if (st.rgba_valid) {
      v.r = st.rgba[0];
      v.g = st.rgba[1];
      v.b = st.rgba[2];
      v.a = st.rgba[3];
    }
    if (st.uv_valid) {
      v.has_uv = true;
      v.uv_u = st.uv_u;
      v.uv_v = st.uv_v;
      st.uv_valid = false;
    }
  }

  void emit_completed() {
    GsPrim gp(st.prim);
    GsTex0 gt(st.tex0);
    if (rst && vert_count >= 3) {
      GsTexa gta(st.texa);
      rst->load_tex(gt.tbp0(), gt.tw(), gt.th(), (u32)gt.psm(), gt.cbp(), gt.cpsm());
      rst->tri(verts[0], verts[1], verts[2], gp.tme(), gp.fst(), gp.abe(), gta.ta0());
    }
    if (prims_logged >= 300) {
      vert_count = 0;
      return;
    }
    prims_logged++;
    lg::info("OTTSEL PRIM: chain={} kind={} tme={} abe={} fst={} tex0(tbp=0x{:x} tw={} th={} "
             "psm=0x{:x} cbp=0x{:x} cpsm=0x{:x} tcc={}) nv={}",
             chain_no, (int)gp.kind(), (int)gp.tme(), (int)gp.abe(), (int)gp.fst(), gt.tbp0(),
             gt.tw(), gt.th(), (u32)gt.psm(), gt.cbp(), gt.cpsm(), gt.tcc(), vert_count);
    for (int i = 0; i < vert_count && i < 4; i++) {
      const OttselVertex& v = verts[i];
      lg::info("OTTSEL PRIM:   v{} xyz=({},{},{}) st=({:.3f},{:.3f},{:.3f}) uv=({},{}) "
               "rgba=({},{},{},{})",
               i, v.x, v.y, v.z, v.s, v.t, v.q, v.uv_u, v.uv_v, v.r, v.g, v.b, v.a);
    }
    vert_count = 0;
  }

  void log_triangle_strip() {
    GsPrim gp(st.prim);
    GsTex0 gt(st.tex0);
    if (rst && vert_count >= 3) {
      GsTexa gta(st.texa);
      rst->load_tex(gt.tbp0(), gt.tw(), gt.th(), (u32)gt.psm(), gt.cbp(), gt.cpsm());
      rst->tri(verts[0], verts[1], verts[2], gp.tme(), gp.fst(), gp.abe(), gta.ta0());
    }
    if (prims_logged >= 300) {
      return;
    }
    prims_logged++;
    lg::info("OTTSEL PRIM: chain={} kind=TRI_STRIP tme={} abe={} tex0(tbp=0x{:x} tw={} th={} "
             "psm=0x{:x}) nv=3",
             chain_no, (int)gp.tme(), (int)gp.abe(), gt.tbp0(), gt.tw(), gt.th(),
             (u32)gt.psm());
    for (int i = 0; i < 3; i++) {
      const OttselVertex& v = verts[i];
      lg::info("OTTSEL PRIM:   v{} xyz=({},{},{}) st=({:.3f},{:.3f},{:.3f}) rgba=({},{},{},{})",
               i, v.x, v.y, v.z, v.s, v.t, v.q, v.r, v.g, v.b, v.a);
    }
  }

  // Consume one vertex set (RGBAQ+XYZ) and build prims per GsPrim kind.
  // restart = the GIF xyz2 bit 47: SET starts a new primitive (the GS
  // inserts degenerate restart vertices; the OpenGOAL DirectRenderer
  // emits a UINT32_MAX index for these).  Dropping the strip on a restart
  // keeps only real triangles.
  void push_vertex(u32 x, u32 y, u32 z, bool restart = false) {
    if (restart) {
      // restart marker: begin a fresh primitive with this vertex.
      vert_count = 0;
    }
    on_vertex();
    OttselVertex& v = verts[vert_count - 1];
    v.x = x;
    v.y = y;
    v.z = z;
    GsPrim gp(st.prim);
    switch (gp.kind()) {
      case GsPrim::Kind::SPRITE:
        if (vert_count == 2) {
          emit_completed();
        }
        break;
      case GsPrim::Kind::TRI:
        if (vert_count == 3) {
          emit_completed();
        }
        break;
      case GsPrim::Kind::TRI_STRIP:
        if (vert_count == 3) {
          log_triangle_strip();
          // keep the last two verts for the next triangle
          verts[0] = verts[1];
          verts[1] = verts[2];
          vert_count = 2;
        }
        break;
      default:
        break;
    }
  }

  void handle_ad(u64 value, u8 addr) {
    switch ((GsRegisterAddress)addr) {
      case GsRegisterAddress::PRIM:
        on_prim_start(value);
        break;
      case GsRegisterAddress::TEX0_1:
      case GsRegisterAddress::TEX0_2:
        st.tex0 = value;
        break;
      case GsRegisterAddress::TEX1_1:
        st.tex1 = value;
        break;
      case GsRegisterAddress::ALPHA_1:
        st.alpha = value;
        break;
      case GsRegisterAddress::ZBUF_1:
        st.zbuf = value;
        break;
      case GsRegisterAddress::TEST_1:
        st.test = value;
        break;
      case GsRegisterAddress::CLAMP_1:
        st.clamp = value;
        break;
      case GsRegisterAddress::FRAME_1:
        st.frame = value;
        break;
      case GsRegisterAddress::XYOFFSET_1:
        st.xyoffset = value;
        if (rst) {
          // ofx/ofy are 16.16 values in the upper 16 bits of each 32-bit half.
          s32 ofx = (s32)((value >> 16) & 0xffff);
          s32 ofy = (s32)((value >> 48) & 0xffff);
          rst->x_off = -65536.f * ((float)(ofx - 0x7000) / (float)UINT32_MAX);
          rst->y_off = -65536.f * ((float)(ofy - 0x7300) / (float)UINT32_MAX);
        }
        break;
      case GsRegisterAddress::SCISSOR_1:
        st.scissor = value;
        if (rst) {
          GsScissor sc(value);
          rst->scissor[0] = sc.x0();
          rst->scissor[1] = sc.x1();
          rst->scissor[2] = sc.y0();
          rst->scissor[3] = sc.y1();
          rst->scissor_enable = true;
        }
        break;
      case GsRegisterAddress::TEXA:
        st.texa = value;
        break;
      default:
        break;
    }
  }
};

// Parse GIF packets (PACKED/REGLIST/IMAGE) out of a VIF DIRECT payload.
void decode_gif_packets(const u8* g, u32 size, OttselGifDecoder& dec) {
  u32 offset = 0;
  while (offset + 16 <= size) {
    GifTag tag(g + offset);
    offset += 16;
    u32 nreg = tag.nreg();
    GifTag::RegisterDescriptor reg_desc[16];
    for (u32 i = 0; i < nreg; i++) {
      reg_desc[i] = tag.reg(i);
    }
    if (tag.flg() == GifTag::Format::PACKED) {
      static u32 ottsel_pkt_logged = 0;
      if (ottsel_pkt_logged < 6) {
        ottsel_pkt_logged++;
        lg::info("OTTSEL PKT: chain={} off={} nloop={} nreg={} pre={} prim={:#x} tag0={:016x} "
                 "tag1={:016x}",
                 dec.chain_no, offset - 16, tag.nloop(), nreg, (int)tag.pre(), tag.prim(),
                 *(u64*)(g + offset - 16), *(u64*)(g + offset - 8));
      }
      if (tag.pre()) {
        dec.on_prim_start(tag.prim());
      }
      for (u32 loop = 0; loop < tag.nloop(); loop++) {
        for (u32 r = 0; r < nreg; r++) {
          const u8* rec = g + offset;
          switch (reg_desc[r]) {
            case GifTag::RegisterDescriptor::AD: {
              u64 value = 0;
              memcpy(&value, rec, 8);
              u8 addr = rec[8];
              dec.handle_ad(value, addr);
            } break;
            case GifTag::RegisterDescriptor::ST: {
              memcpy(&dec.st.st[0], rec, 4);
              memcpy(&dec.st.st[1], rec + 4, 4);
              memcpy(&dec.st.st[2], rec + 8, 4);
              dec.st.st_valid = true;
            } break;
            case GifTag::RegisterDescriptor::RGBAQ: {
              dec.st.rgba[0] = rec[0];
              dec.st.rgba[1] = rec[4];
              dec.st.rgba[2] = rec[8];
              dec.st.rgba[3] = rec[12];
              dec.st.rgba_valid = true;
            } break;
            case GifTag::RegisterDescriptor::UV: {
              u32 u = 0, v = 0;
              memcpy(&u, rec, 4);
              memcpy(&v, rec + 4, 4);
              dec.st.uv_valid = true;
              dec.st.uv_u = u;
              dec.st.uv_v = v;
            } break;
            case GifTag::RegisterDescriptor::XYZF2:
            case GifTag::RegisterDescriptor::XYZ2: {
              // PACKED XYZF2: x(4) y(4) then z/f in the upper 8 bytes.
              u32 x = 0, y = 0;
              memcpy(&x, rec, 4);
              memcpy(&y, rec + 4, 4);
              u64 upper = 0;
              memcpy(&upper, rec + 8, 8);
              u32 z = (reg_desc[r] == GifTag::RegisterDescriptor::XYZF2)
                          ? (u32)((upper >> 4) & 0xffffff)
                          : (u32)upper;
              bool restart = (upper & (1ull << 47)) != 0;
              dec.push_vertex(x << 16, y << 16, z, restart);
            } break;
            case GifTag::RegisterDescriptor::PRIM: {
              u64 v = 0;
              memcpy(&v, rec, 8);
              dec.on_prim_start(v);
            } break;
            case GifTag::RegisterDescriptor::TEX0_1:
            case GifTag::RegisterDescriptor::TEX0_2: {
              u64 v = 0;
              memcpy(&v, rec, 8);
              dec.st.tex0 = v;
            } break;
            default:
              break;
          }
          offset += 16;
        }
      }
    } else if (tag.flg() == GifTag::Format::REGLIST) {
      if (dec.reglist_dumps < 12) {
        dec.reglist_dumps++;
        for (u32 r = 0; r < nreg && r < 9; r++) {
          u64 rv = 0;
          memcpy(&rv, g + offset + (size_t)r * 8, 8);
          lg::info("OTTSEL REGLIST: chain={} reg[{}] desc={} val=0x{:016x}", dec.chain_no, r,
                   (int)tag.reg(r), rv);
        }
      }
      for (u32 loop = 0; loop < tag.nloop(); loop++) {
        for (u32 r = 0; r < nreg; r++) {
          const u8* rec = g + offset;
          u64 val = 0;
          memcpy(&val, rec, 8);
          switch (reg_desc[r]) {
            case GifTag::RegisterDescriptor::PRIM:
              dec.on_prim_start(val);
              break;
            case GifTag::RegisterDescriptor::RGBAQ:
              memcpy(dec.st.rgba, rec, 4);
              dec.st.rgba_valid = true;
              memcpy(&dec.st.st[2], rec + 4, 4);  // Q
              break;
            case GifTag::RegisterDescriptor::XYZF2:
            case GifTag::RegisterDescriptor::XYZ2: {
              // REGLIST XYZF2: x(16) | y(16) | z(24) | f(8) in the low 64
              // bits; the renderer converts to 16.16 with <<16.
              u32 x = (u32)(val & 0xffff);
              u32 y = (u32)((val >> 16) & 0xffff);
              u32 z = (u32)((val >> 32) & 0xffffff);
              bool restart = (val & (1ull << 47)) != 0;
              dec.push_vertex(x << 16, y << 16, z, restart);
            } break;
            case GifTag::RegisterDescriptor::ST:
              memcpy(&dec.st.st[0], rec, 4);
              memcpy(&dec.st.st[1], rec + 4, 4);
              dec.st.st_valid = true;
              break;
            default:
              break;
          }
          offset += 8;
        }
      }
    } else if (tag.flg() == GifTag::Format::IMAGE) {
      // IMAGE payloads (texture texels) are skipped here; the upload path
      // (texture_upload_now) already filled fake VRAM from the tpage data.
      offset += tag.nloop() * 16;
    } else {
      break;
    }
    if (tag.eop()) {
      break;
    }
  }
}

// Decode one transfer: if its VIF codes say DIRECT, walk VIF words + GIF data
// like the reference DirectRenderer::render_vif.
void decode_transfer(const DmaTransfer& t, OttselGifDecoder& dec) {
  u32 gif_qwc = 0;
  auto direct_or_nop = [](const VifCode& c) -> u32 {
    if (c.kind == VifCode::Kind::NOP || c.kind == VifCode::Kind::FLUSHA) {
      return 0;
    }
    if (c.kind == VifCode::Kind::DIRECT) {
      return c.immediate == 0 ? 65536 : c.immediate;
    }
    return 0;
  };
  gif_qwc = direct_or_nop(t.vifcode0());
  if (gif_qwc) {
    // vif1 should be a nop in this case
    gif_qwc = direct_or_nop(t.vifcode1()) ? 0 : gif_qwc;
  } else {
    gif_qwc = direct_or_nop(t.vifcode1());
  }
  if (gif_qwc) {
    decode_gif_packets(t.data, std::min(gif_qwc * 16, t.size_bytes), dec);
    return;
  }
  // No DIRECT in the tag's vif fields: walk vif words inside the data.
  u32 off = 0;
  while (off < t.size_bytes) {
    if (gif_qwc) {
      if (off & 0xf) {
        // unaligned: expect a nop vif
        u32 vif = 0;
        memcpy(&vif, t.data + off, 4);
        off += 4;
      } else {
        u32 sz = std::min(gif_qwc * 16, t.size_bytes - off);
        decode_gif_packets(t.data + off, sz, dec);
        off += gif_qwc * 16;
        gif_qwc = 0;
      }
    } else {
      u32 vif = 0;
      memcpy(&vif, t.data + off, 4);
      off += 4;
      gif_qwc = direct_or_nop(VifCode(vif));
    }
  }
}
}  // namespace

void gfx_send_chain(const void* data, u32 offset) {
  if (!data) {
    return;
  }
  static OttselGifDecoder g_dec;
  static OttselRaster g_raster;
  if (g_raster.fb.empty()) {
    g_raster.fb.assign((size_t)g_raster.fb_w * g_raster.fb_h * 4, 0);
  }
  g_dec.rst = &g_raster;
  static u32 g_chain_no = 0;
  g_chain_no++;
  g_dec.chain_no = g_chain_no;
  // Clear the composed frame once per ~90 chains (a coarse frame boundary)
  // and present it periodically so the rasterizer output is visible.
  if (g_chain_no % 90 == 1) {
    g_raster.clear(0);
  }
  if (g_chain_no % 90 == 0 && g_metal && g_raster.draw_count > 0) {
    ottsel_metal_present(g_metal, g_raster.fb.data(), g_raster.fb_w, g_raster.fb_h);
    lg::info("OTTSEL RASTER: presented composed {}x{} (draws={})", g_raster.fb_w, g_raster.fb_h,
             g_raster.draw_count);
  }
  if (g_chain_no % 45 == 0) {
    static u32 ottsel_dc_logged = 0;
    if (ottsel_dc_logged++ < 6) {
      lg::info("OTTSEL RSTR: chain={} draw_count={} fb={}x{}", g_chain_no, g_raster.draw_count,
               g_raster.fb_w, g_raster.fb_h);
    }
  }
  // S2.2 BOT20: keep the last decoded texture on screen (the game uploads
  // tpages continuously; the composed-raster path is not drawing yet).  This
  // gives a persistent visible frame instead of the clear color.
  if (g_chain_no % 90 == 45 && g_metal && g_fw > 0 && g_fh > 0 && !g_frame.empty()) {
    ottsel_metal_present(g_metal, g_frame.data(), g_fw, g_fh);
  }
  static int ottsel_dma_logged = 0;
  bool log_dma = ottsel_dma_logged < 3;
  if (log_dma) {
    ottsel_dma_logged++;
  }
  // TFRAG probe: dump VIF UNPACK payloads (the 3D bucket data) for the first
  // few batches so the tfrag format can be reverse-engineered from ground
  // truth.  Also count the transfer mix per chain.
  static u32 ottsel_tfrag_dumps = 0;
  static u32 ottsel_chain_transfers = 0;
  static u32 ottsel_chain_unpacks = 0;
  // Dump the full tfrag-bucket UNPACK payloads (imm = VU dest) to a file so
  // the VU1 interpreter can be tested offline with the real data.
  static FILE* g_tfrag_dump = nullptr;
  static u32 g_tfrag_dump_recs = 0;
  if (!g_tfrag_dump) {
    std::string path = ottsel_ios_bundle_dir() + "tfrag-vu-data.bin";
    g_tfrag_dump = fopen(path.c_str(), "wb");
    if (g_tfrag_dump) {
      u32 hdr[2] = {0};
      fwrite(hdr, 8, 1, g_tfrag_dump);  // placeholder: entry/count
    }
  }
  // S2.2 BOT19e: full VIF replay capture.  Every transfer's VIF command words
  // (vif0/vif1) plus the payload so the offline tool can simulate the VIF
  // registers (TOP/TOPS/ITOP/BASE/OFFSET/STCYCL/STMOD) and rebuild the VU
  // memory exactly as the hardware would, including the frag-list base that
  // no UNPACK writes directly.
  static FILE* g_vif_replay = nullptr;
  static u32 g_vif_replay_recs = 0;
  if (!g_vif_replay) {
    std::string rpath = ottsel_ios_bundle_dir() + "tfrag-vif-replay.bin";
    g_vif_replay = fopen(rpath.c_str(), "wb");
  }
  const u8* base = (const u8*)data;
  DmaFollower dma(base, offset);
  // S2.2 VU1 emulation: process the DMA chain's VIF commands to build VU
  // memory and run the tfrag microcode on MSCAL/MSCALF, feeding the XGKICK
  // output (gif_out) through the same GIF decoder/rasterizer as DIRECT data.
  static ottsel_vu1::Vu1State g_vu;
  static bool g_vu_init = false;
  static bool g_ottsel_spr_ran = false;
  static bool g_readlog_hook_set = false;
  if (!g_readlog_hook_set) {
    g_readlog_hook_set = true;
    ottsel_vu1::ottsel_vu1_set_readlog_hook([](const char* msg) { lg::info("{}", msg); });
  }
  static u32 g_vu_top = 0;   // VIF TOP register (frag-list base, XTOP)
  static u32 g_vu_tops = 0;  // VIF TOPS register
  static u32 g_vu_vu_stcycl = 0x404;  // STCYCL cl<<8|wl
  if (!g_vu_init) {
    g_vu_init = true;
    g_vu.code_len = ottsel_vu1::kTfragCodeWords;
    for (int i = 0; i < g_vu.code_len; i++) {
      g_vu.code[i] = ottsel_vu1::kTfragMicrocode[i];
    }
  }
  // S2.2 BOT21c: the game's mips2c ln stashes the first tfragment's
  // dma-chain (the per-draw VIF stream incl. the frag-list header at VU
  // 0x0) into tfrag-work+0xb8/+0xbc.  The port has no SPR->VIF1 DMA, so
  // process that stored VIF stream here (once per frame) as the SPR->VIF1
  // emulation: UNPACKs -> VU mem, then run the microcode on the stream's
  // MSCAL/MSCALF so the frag-list is populated before the frame-init draw.
  {
    static bool ottsel_spr_done = false;
    if (!ottsel_spr_done && g_ee_main_mem) {
      auto twi = g_pc_port_funcs.intern_from_c("*tfrag-work*");
      if (twi.offset) {
        u32 tw = 0;
        memcpy(&tw, g_ee_main_mem + twi.offset, 4);
        if (tw) {
          const u8* twp = g_ee_main_mem + tw;
          u32 chain = *(u32*)(twp + 0xb8);
          u32 qwcv = *(u32*)(twp + 0xbc);
          if (chain >= 0x080000 && chain < 0x08000000 && qwcv > 0 && qwcv <= 256) {
            ottsel_spr_done = true;
            lg::info("OTTSEL SPR: process tfrag dma chain=0x{:x} qwc={}", chain, qwcv);
            const u32* w = (const u32*)(g_ee_main_mem + chain);
            u32 nwords = qwcv * 4;
            u32 i = 0;
            int unpacks = 0, mscals = 0;
            // BOT21d: the far path's frag-list points at VU 26+ (the
            // geometry).  The stored dma data's geometry region (qword 20+,
            // byte 0x140) maps to VU 26+; upload it so the strips have
            // vertices.
            if (qwcv >= 128) {
              memcpy(&g_vu.data[26 * 4], &w[20 * 4], (qwcv - 20) * 16);
            }
            while (i + 1 < nwords) {
              u32 vw = w[i];
              VifCode v(vw);
              switch (v.kind) {
                case VifCode::Kind::UNPACK_V4_32:
                case VifCode::Kind::UNPACK_V4_16:
                case VifCode::Kind::UNPACK_V4_8:
                case VifCode::Kind::UNPACK_V3_32:
                case VifCode::Kind::UNPACK_V2_16: {
                  u32 dest = (v.immediate & 0x3ff) & 0xfff;
                  u32 qwords = v.num;
                  if (dest < 4096 && i + 1 + qwords * 4 <= nwords) {
                    memcpy(&g_vu.data[dest * 4], &w[i + 1], qwords * 16);
                    unpacks++;
                    if (unpacks <= 8) {
                      lg::info("OTTSEL SPR UNPACK: addr=0x{:x} num={} d0={:08x} d1={:08x} "
                               "d2={:08x} d3={:08x}",
                               dest, qwords, w[i + 1], w[i + 2], w[i + 3], w[i + 4]);
                    }
                  }
                  i += 1 + qwords * 4;
                  break;
                }
                case VifCode::Kind::MSCAL:
                case VifCode::Kind::MSCALF: {
                  ottsel_vu1::set_top(0);
                  g_vu.pc = 8;
                  g_vu.gif_out.clear();
                  ottsel_vu1::execute(g_vu, 200000);
                  mscals++;
                  lg::info("OTTSEL SPR MSCAL: pc={} gif_out={} frag0={:08x} frag1={:08x} "
                           "frag2={:08x}",
                           g_vu.pc, g_vu.gif_out.size(), g_vu.data[0 * 4], g_vu.data[1 * 4],
                           g_vu.data[2 * 4]);
                  if (!g_vu.gif_out.empty()) {
                    decode_gif_packets((const u8*)g_vu.gif_out.data(),
                                       (u32)g_vu.gif_out.size() * 4, g_dec);
                  }
                  i += 1;
                  break;
                }
                case VifCode::Kind::DIRECT:
                case VifCode::Kind::DIRECTHL: {
                  i += 1 + (v.immediate & 0xffff) * 4;
                  break;
                }
                default:
                  i += 1;
                  break;
              }
            }
            lg::info("OTTSEL SPR done: unpacks={} mscals={} gif_out_total={}", unpacks, mscals,
                     (int)g_vu.gif_out.size());
            g_ottsel_spr_ran = true;
          }
        }
      }
    }
  }
  auto ottsel_handle_vif = [&](u32 vifword, const u8* payload, u32 payload_size) {
    VifCode v(vifword);
    switch (v.kind) {
      case VifCode::Kind::STCYCL:
        g_vu_vu_stcycl = v.immediate;
        break;
      case VifCode::Kind::BASE:
        g_vu_top = (g_vu_top & 0x3c0) | (v.immediate & 0x3f);
        break;
      case VifCode::Kind::OFFSET:
        g_vu_tops = g_vu_top + v.immediate;
        break;
      case VifCode::Kind::MSCAL:
      case VifCode::Kind::MSCALF: {
        // The microcode's XTOP reads the VIF TOP register; run it with the
        // current frag-list base.
        static u32 ottsel_vu1_runs = 0;
        ottsel_vu1::set_top(g_vu_top);
        // BOT21d: the tfrag microcode's real entry is pc=8 (the
        // `b L3 | xtop vi14` dispatch -- frag-list at XTOP/TOP); pc=0 is the
        // L11 header path (hardcoded 0x2a0 base) used by other variants.
        g_vu.pc = (8 + v.immediate * 2) & 0x7ff;
        g_vu.gif_out.clear();
        // BOT21d: trace the first tfrag draw after the SPR upload so the
        // far path's data reads can be verified against the frag-list.
        static bool ottsel_traced = false;
        bool trace_this = g_ottsel_spr_ran && !ottsel_traced && ottsel_vu1_runs >= 9;
        if (trace_this) {
          ottsel_traced = true;
          ottsel_vu1::ottsel_vu1_set_readlog(1);
        }
        // S2.2 BOT20: the empty frag list makes the microcode loop to the
        // cap, burning the game thread (95% CPU, 18-min boot).  The skip
        // path (ibeq vi00, vi02, L32) exits far earlier; a 50k cap keeps the
        // thread responsive while still allowing real frag data (validated
        // runs reached the output phase well within it).
        // BOT21d: the far path's output loop needs more than the 50k cap
        // (it reaches the strip-output phase at pc~1687 but hits the cap
        // before the XGKICK).  Use the original cap for tfrag runs.
        ottsel_vu1::execute(g_vu, g_ottsel_spr_ran ? 400000 : 50000);
        ottsel_vu1::ottsel_vu1_set_readlog(0);
        if (ottsel_vu1_runs < 20) {
          ottsel_vu1_runs++;
          lg::info("OTTSEL VU1: run#{} mscal imm=0x{:x} top=0x{:x} pc={} gif_out={} "
                   "frag[0..2]=0x{:x}/0x{:x}/0x{:x}",
                   ottsel_vu1_runs, v.immediate, g_vu_top, g_vu.pc, g_vu.gif_out.size(),
                   g_vu.data[0 * 4], g_vu.data[1 * 4], g_vu.data[2 * 4]);
        }
        if (!g_vu.gif_out.empty()) {
          decode_gif_packets((const u8*)g_vu.gif_out.data(),
                             (u32)g_vu.gif_out.size() * 4, g_dec);
        }
        break;
      }
      case VifCode::Kind::UNPACK_V4_32:
      case VifCode::Kind::UNPACK_V4_16:
      case VifCode::Kind::UNPACK_V4_8:
      case VifCode::Kind::UNPACK_V3_32:
      case VifCode::Kind::UNPACK_V2_16: {
        // dest = (addr?TOPS:TOP) + (imm & 0x3ff); the addr flag = bit 21 of
        // the VIF word.  All observed tfrag unpacks are TOP-relative.
        u32 base = (vifword & (1 << 21)) ? g_vu_tops : g_vu_top;
        u32 dest = (base + (v.immediate & 0x3ff)) & 0xfff;
        u32 qwords = std::min(payload_size / 16, 4096u - dest);
        if (qwords && dest < 4096) {
          memcpy(&g_vu.data[dest * 4], payload, qwords * 16);
        }
        break;
      }
      default:
        break;
    }
  };
  int count = 0;
  while (!dma.ended() && count < 512) {
    DmaTransfer t = dma.read_and_advance();
    count++;
    if (t.size_bytes == 0) {
      if (g_vif_replay && g_vif_replay_recs < 30000) {
        u32 rec[4] = {t.vif0(), t.vif1(), 0, 0};
        fwrite(rec, 16, 1, g_vif_replay);
        g_vif_replay_recs++;
      }
      continue;
    }
    if (g_vif_replay && g_vif_replay_recs < 30000 && t.size_bytes <= 8192) {
      u32 rec[4] = {t.vif0(), t.vif1(), t.size_bytes, 0};
      fwrite(rec, 16, 1, g_vif_replay);
      fwrite(t.data, t.size_bytes, 1, g_vif_replay);
      g_vif_replay_recs++;
    }
    const u8* g = t.data;
    GifTag tag(g);
    u32 off = (u32)(g - base);
    // S2.2: process the transfer's two VIF commands.  vif1 is the data
    // consumer in the observed tfrag chains (STCYCL+UNPACK, FLUSHA+DIRECT,
    // MSCALF+STMOD); process vif0 first (control), then vif1 with the
    // payload.
    ottsel_handle_vif(t.vif0(), t.data, t.size_bytes);
    ottsel_handle_vif(t.vif1(), t.data, t.size_bytes);
    VifCode v1(t.vif1());
    VifCode v0(t.vif0());
    // Full-transfer capture of the first tfrag-bearing chain (all vif kinds,
    // including qwc=0 base/offset and any frag-list unpacks).
    static u32 ottsel_full_chain = 0;
    if (g_chain_no <= 4) {
      lg::info("OTTSEL FULL: chain={} t{} size={} v0=0x{:x}(k{}) v1=0x{:x}(k{}) off=0x{:x}",
               g_chain_no, count, t.size_bytes, t.vif0(), (u32)v0.kind, t.vif1(), (u32)v1.kind,
               off);
    }
    // qwc=0 transfers carry the VIF base/offset commands - log the first few.
    static u32 ottsel_vifctl = 0;
    if (ottsel_vifctl < 12 && t.size_bytes == 0 &&
        (v0.kind == VifCode::Kind::BASE || v0.kind == VifCode::Kind::OFFSET ||
         v1.kind == VifCode::Kind::BASE || v1.kind == VifCode::Kind::OFFSET ||
         v0.kind == VifCode::Kind::STCYCL || v1.kind == VifCode::Kind::STCYCL)) {
      ottsel_vifctl++;
      lg::info("OTTSEL VIFCTL: chain={} t{} qwc0 v0=0x{:x}(k{}) v1=0x{:x}(k{}) off=0x{:x}",
               g_chain_no, count, t.vif0(), (u32)v0.kind, t.vif1(), (u32)v1.kind, off);
    }
    // S2.2 BOT19: capture EVERY UNPACK from the start of the frame.  The
    // once-per-frame 0x290 tfrag-data init upload writes the frag-list block
    // at vi14 = 0x2a0 (the VU1 reads count@+1, pointers@+2/+4, matrix rows
    // @+5..+8); the previous window began at record 4000 (after the DIRECT
    // captures) and missed it, so the interpreter never saw a real frag list.
    if (g_tfrag_dump && g_tfrag_dump_recs < 12000 &&
        (v1.kind == VifCode::Kind::UNPACK_V4_32 || v1.kind == VifCode::Kind::UNPACK_V4_16 ||
         v1.kind == VifCode::Kind::UNPACK_V4_8 || v1.kind == VifCode::Kind::UNPACK_V3_32 ||
         v1.kind == VifCode::Kind::UNPACK_V2_16 || v0.kind == VifCode::Kind::UNPACK_V4_8 ||
         v0.kind == VifCode::Kind::UNPACK_V4_16)) {
      g_tfrag_dump_recs++;
      u32 rec[4] = {v1.immediate | ((u32)v1.kind << 16), v1.num, t.size_bytes, 0};
      fwrite(rec, 16, 1, g_tfrag_dump);
      fwrite(t.data, t.size_bytes, 1, g_tfrag_dump);
    }
    // Also capture the small DIRECT GIF transfers (BOT18e: mostly
    // uninitialized DMA gaps, kept for reference after the UNPACKs).
    if (g_tfrag_dump && g_tfrag_dump_recs >= 12000 && g_tfrag_dump_recs < 14000 &&
        t.size_bytes <= 256 &&
        (v1.kind == VifCode::Kind::DIRECT || v0.kind == VifCode::Kind::DIRECT ||
         v1.kind == VifCode::Kind::DIRECTHL || v0.kind == VifCode::Kind::DIRECTHL ||
         v1.kind == VifCode::Kind::PC_PORT || v0.kind == VifCode::Kind::PC_PORT)) {
      g_tfrag_dump_recs++;
      u32 rec[4] = {0x80000000 | (u32)v1.kind, v1.num, t.size_bytes, 0};
      fwrite(rec, 16, 1, g_tfrag_dump);
      fwrite(t.data, t.size_bytes, 1, g_tfrag_dump);
    }
    // Dump the tfrag-work once the tfrag draws are actually running.
    static bool ottsel_tw_dumped = false;
    static u32 ottsel_mscal_count = 0;
    if (g_ee_main_mem &&
        ((v1.kind == VifCode::Kind::MSCAL || v1.kind == VifCode::Kind::MSCALF) ||
         (v0.kind == VifCode::Kind::MSCAL || v0.kind == VifCode::Kind::MSCALF))) {
      ottsel_mscal_count++;
    }
    if (!ottsel_tw_dumped && ottsel_mscal_count >= 60 && g_ee_main_mem &&
        ((v1.kind == VifCode::Kind::MSCAL || v1.kind == VifCode::Kind::MSCALF) ||
         (v0.kind == VifCode::Kind::MSCAL || v0.kind == VifCode::Kind::MSCALF)) &&
        (v1.immediate == 0 || v0.immediate == 0)) {
      ottsel_tw_dumped = true;
      // S2.2 BOT21b probe: dump the compiled draw-drawable-tree-tfrag
      // function so the per-draw VIF emission can be attributed (the
      // goal_src mips2c ln call is commented out, yet per-draw UNPACKs
      // flow).  Disassemble the ARM64 words offline.
      for (const char* nm : {"draw-drawable-tree-tfrag", "ln", "tfrag-init-buffer",
                             "draw-drawable-tree-trans-tfrag"}) {
        auto fn = g_pc_port_funcs.intern_from_c(nm);
        lg::info("OTTSEL FNSYM: {} sym=0x{:x} val=0x{:x} val4=0x{:x}", nm, fn.offset,
                 fn.offset ? *(u32*)(g_ee_main_mem + fn.offset) : 0,
                 fn.offset ? *(u32*)(g_ee_main_mem + fn.offset + 4) : 0);
      }
      // S2.2 BOT21c probe: after the mips2c ln runs (restored call), dump
      // the fake scratchpad (where the ported spad_to_dma wrote the tfrag
      // VIF data) and the tfrag-work draw-state so the frag-list can be
      // located.  The scratchpad base comes from *fake-scratchpad-data*
      // (runtime value ~0x7000186964, NOT the old 0x1d0000 guess).
      {
        auto fsp = g_pc_port_funcs.intern_from_c("*fake-scratchpad-data*");
        u32 spad_ee = 0;
        if (fsp.offset) {
          memcpy(&spad_ee, g_ee_main_mem + fsp.offset, 4);
        }
        lg::info("OTTSEL SPADBASE: sym=0x{:x} val=0x{:x}", fsp.offset, spad_ee);
        const u8* spad = g_ee_main_mem + spad_ee;
        for (int q = 0; q < 64; q += 8) {
          lg::info("OTTSEL SPAD {:04x}: {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                   q * 16, *(u32*)(spad + q * 16), *(u32*)(spad + q * 16 + 4),
                   *(u32*)(spad + q * 16 + 8), *(u32*)(spad + q * 16 + 12),
                   *(u32*)(spad + q * 16 + 16), *(u32*)(spad + q * 16 + 20),
                   *(u32*)(spad + q * 16 + 24), *(u32*)(spad + q * 16 + 28));
        }
        // The TFASM a0 (vis-list) — dump the terrain-context vis-list region
        // near the fake scratchpad so the tfragment's vis bit can be checked.
        const u8* vis = spad + 0x38b0;
        lg::info("OTTSEL VISLIST @+0x38b0: {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                 "{:08x}",
                 *(u32*)(vis + 0), *(u32*)(vis + 4), *(u32*)(vis + 8), *(u32*)(vis + 12),
                 *(u32*)(vis + 16), *(u32*)(vis + 20), *(u32*)(vis + 24), *(u32*)(vis + 28));
      }
      auto info = g_pc_port_funcs.intern_from_c("*tfrag-work*");
      if (info.offset) {
        u32 val = 0;
        memcpy(&val, g_ee_main_mem + info.offset, 4);
        lg::info("OTTSEL TFRAGWORK: sym=0x{:x} sym[0..3]={:08x} {:08x} {:08x} {:08x} value=0x{:x}",
                 info.offset, *(u32*)(g_ee_main_mem + info.offset),
                 *(u32*)(g_ee_main_mem + info.offset + 4), *(u32*)(g_ee_main_mem + info.offset + 8),
                 *(u32*)(g_ee_main_mem + info.offset + 12), val);
        if (val) {
          const u8* tw = g_ee_main_mem + val;
          // Dump the tfragment's dma-chain data (the far VIF stream ln
          // processes).  The TFASM a1 from the last run was 0x22978c4 and
          // its dma-chain[0] was 0x2297920 (qwc 0x80 = 128 qwords).
          {
            u32 dma_chain = *(u32*)(tw + 0xb0);  // tfrag-work src-ptr is the dma-buffer
            (void)dma_chain;
            const u8* tfd = g_ee_main_mem + 0x2297920;
            for (int q = 0; q < 128; q += 4) {
              lg::info("OTTSEL TFRAGDMA {:04x}: {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                       "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                       "{:08x}",
                       q * 16, *(u32*)(tfd + q * 16), *(u32*)(tfd + q * 16 + 4),
                       *(u32*)(tfd + q * 16 + 8), *(u32*)(tfd + q * 16 + 12),
                       *(u32*)(tfd + q * 16 + 16), *(u32*)(tfd + q * 16 + 20),
                       *(u32*)(tfd + q * 16 + 24), *(u32*)(tfd + q * 16 + 28),
                       *(u32*)(tfd + q * 16 + 32), *(u32*)(tfd + q * 16 + 36),
                       *(u32*)(tfd + q * 16 + 40), *(u32*)(tfd + q * 16 + 44),
                       *(u32*)(tfd + q * 16 + 48), *(u32*)(tfd + q * 16 + 52),
                       *(u32*)(tfd + q * 16 + 56), *(u32*)(tfd + q * 16 + 60));
            }
          }
          // The vis-list pointer ln received (TFASM a0) points into the
          // scratchpad terrain-context; dump the tfragment ln processed
          // (TFASM a1) so the dma-chain (per-draw VIF data) can be checked.
          // The TFASM a1 is logged by the runtime; probe the known village
          // tfragment from the last run if present.
          lg::info("OTTSEL TFRAGWORK: +0xa8..0xbf = {:08x} {:08x} {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(tw + 0xa8), *(u32*)(tw + 0xac), *(u32*)(tw + 0xb0), *(u32*)(tw + 0xb4),
                   *(u32*)(tw + 0xb8), *(u32*)(tw + 0xbc));
          lg::info("OTTSEL TFRAGWORK: +0xa0..0xdf = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(tw + 0xa0), *(u32*)(tw + 0xa4), *(u32*)(tw + 0xa8), *(u32*)(tw + 0xac),
                   *(u32*)(tw + 0xb0), *(u32*)(tw + 0xb4), *(u32*)(tw + 0xb8), *(u32*)(tw + 0xbc),
                   *(u32*)(tw + 0xc0), *(u32*)(tw + 0xc4), *(u32*)(tw + 0xc8), *(u32*)(tw + 0xcc),
                   *(u32*)(tw + 0xd0), *(u32*)(tw + 0xd4), *(u32*)(tw + 0xd8), *(u32*)(tw + 0xdc));
          lg::info("OTTSEL TFRAGWORK: +0..63 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(tw + 0), *(u32*)(tw + 4), *(u32*)(tw + 8), *(u32*)(tw + 12),
                   *(u32*)(tw + 16), *(u32*)(tw + 20), *(u32*)(tw + 24), *(u32*)(tw + 28),
                   *(u32*)(tw + 32), *(u32*)(tw + 36), *(u32*)(tw + 40), *(u32*)(tw + 44),
                   *(u32*)(tw + 48), *(u32*)(tw + 52), *(u32*)(tw + 56), *(u32*)(tw + 60));
          lg::info("OTTSEL TFRAGWORK: +64..127 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(tw + 64), *(u32*)(tw + 68), *(u32*)(tw + 72), *(u32*)(tw + 76),
                   *(u32*)(tw + 80), *(u32*)(tw + 84), *(u32*)(tw + 88), *(u32*)(tw + 92),
                   *(u32*)(tw + 96), *(u32*)(tw + 100), *(u32*)(tw + 104), *(u32*)(tw + 108),
                   *(u32*)(tw + 112), *(u32*)(tw + 116), *(u32*)(tw + 120), *(u32*)(tw + 124));
          lg::info("OTTSEL TFRAGWORK: +128..191 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(tw + 128), *(u32*)(tw + 132), *(u32*)(tw + 136), *(u32*)(tw + 140),
                   *(u32*)(tw + 144), *(u32*)(tw + 148), *(u32*)(tw + 152), *(u32*)(tw + 156),
                   *(u32*)(tw + 160), *(u32*)(tw + 164), *(u32*)(tw + 168), *(u32*)(tw + 172),
                   *(u32*)(tw + 176), *(u32*)(tw + 180), *(u32*)(tw + 184), *(u32*)(tw + 188));
          u32 tf = 0;
          memcpy(&tf, tw + 168, 4);
          if (tf) {
            const u8* f = g_ee_main_mem + tf;
            lg::info("OTTSEL TFRAGMENT: ptr=0x{:x} dma-chain[0..2] = {:08x} {:08x} {:08x} "
                     "qwc[0..3] = {:02x} {:02x} {:02x} {:02x}",
                     tf, *(u32*)(f + 12), *(u32*)(f + 16), *(u32*)(f + 20), *(u8*)(f + 44),
                     *(u8*)(f + 45), *(u8*)(f + 46), *(u8*)(f + 47));
          }
        }
      }
    }
    if (g_tfrag_dump && g_tfrag_dump_recs < 4000 &&
        (v1.kind == VifCode::Kind::MSCAL || v1.kind == VifCode::Kind::MSCALF ||
         v0.kind == VifCode::Kind::MSCAL || v0.kind == VifCode::Kind::MSCALF)) {
      u32 rec[4] = {0xffffffff, v1.num, v1.immediate, 0};
      fwrite(rec, 16, 1, g_tfrag_dump);
    }
    // Full VIF sequence dump for the first few chains (the tfrag bucket).
    static u32 ottsel_vifseq_chains = 0;
    if (ottsel_vifseq_chains < 4 &&
        (v1.kind == VifCode::Kind::UNPACK_V4_32 || v1.kind == VifCode::Kind::STCYCL ||
         v1.kind == VifCode::Kind::MSCAL || v1.kind == VifCode::Kind::MSCALF ||
         v1.kind == VifCode::Kind::MPG || v1.kind == VifCode::Kind::FLUSHA ||
         v1.kind == VifCode::Kind::FLUSHE || v0.kind == VifCode::Kind::STCYCL ||
         v0.kind == VifCode::Kind::MSCAL || v0.kind == VifCode::Kind::MSCALF ||
         v1.kind == VifCode::Kind::DIRECT)) {
      if (count == 1) {
        ottsel_vifseq_chains++;
        lg::info("OTTSEL VIFSEQ: === chain {} ===", g_chain_no);
      }
      lg::info("OTTSEL VIFSEQ: t{} size={} v0=0x{:x}(k{}) v1=0x{:x}(k{} n{}) off=0x{:x}", count,
               t.size_bytes, t.vif0(), (u32)v0.kind, t.vif1(), (u32)v1.kind, v1.num, off);
    }
    if (v1.kind == VifCode::Kind::UNPACK_V4_32 || v1.kind == VifCode::Kind::UNPACK_V4_16 ||
        v1.kind == VifCode::Kind::UNPACK_V4_8 || v1.kind == VifCode::Kind::UNPACK_V3_32 ||
        v1.kind == VifCode::Kind::UNPACK_V2_16) {
      ottsel_chain_unpacks++;
      if (ottsel_tfrag_dumps < 14) {
        ottsel_tfrag_dumps++;
        lg::info("OTTSEL VIF: chain={} t{} off=0x{:x} size={} v1kind=0x{:x} num={} v0kind=0x{:x} "
                 "data: {:08x} {:08x} {:08x} {:08x} {:08x} {:08x} {:08x} {:08x}",
                 g_chain_no, count, off, t.size_bytes, (u32)v1.kind, v1.num,
                 (u32)VifCode(t.vif0()).kind, *(u32*)(g + 0), *(u32*)(g + 4), *(u32*)(g + 8),
                 *(u32*)(g + 12), *(u32*)(g + 16), *(u32*)(g + 20), *(u32*)(g + 24),
                 *(u32*)(g + 28));
        if (t.size_bytes >= 64) {
          lg::info("OTTSEL VIF:   + {:08x} {:08x} {:08x} {:08x} {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(g + 32), *(u32*)(g + 36), *(u32*)(g + 40), *(u32*)(g + 44),
                   *(u32*)(g + 48), *(u32*)(g + 52), *(u32*)(g + 56), *(u32*)(g + 60));
        }
        // Dump the first 16 qwords of the big payloads (the frag batches).
        if (v1.num > 20 && t.size_bytes >= 256) {
          lg::info("OTTSEL VIF:   imm=0x{:x} q0-3: {:08x} {:08x} {:08x} {:08x} | {:08x} "
                   "{:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x}",
                   v1.immediate, *(u32*)(g + 0), *(u32*)(g + 4), *(u32*)(g + 8),
                   *(u32*)(g + 12), *(u32*)(g + 16), *(u32*)(g + 20), *(u32*)(g + 24),
                   *(u32*)(g + 28), *(u32*)(g + 32), *(u32*)(g + 36), *(u32*)(g + 40),
                   *(u32*)(g + 44), *(u32*)(g + 48), *(u32*)(g + 52), *(u32*)(g + 56),
                   *(u32*)(g + 60));
          lg::info("OTTSEL VIF:   imm=0x{:x} q4-7: {:08x} {:08x} {:08x} {:08x} | {:08x} "
                   "{:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x}",
                   v1.immediate, *(u32*)(g + 64), *(u32*)(g + 68), *(u32*)(g + 72),
                   *(u32*)(g + 76), *(u32*)(g + 80), *(u32*)(g + 84), *(u32*)(g + 88),
                   *(u32*)(g + 92), *(u32*)(g + 96), *(u32*)(g + 100), *(u32*)(g + 104),
                   *(u32*)(g + 108), *(u32*)(g + 112), *(u32*)(g + 116), *(u32*)(g + 120),
                   *(u32*)(g + 124));
        }
      }
    }
    if (g_chain_no <= 6) {
      ottsel_chain_transfers++;
    }
    if (g_chain_no == 6 && count == 1) {
      lg::info("OTTSEL VIF: chain 6 transfer mix: {} transfers, {} unpacks", ottsel_chain_transfers,
               ottsel_chain_unpacks);
    }
    if (log_dma) {
      lg::info("OTTSEL DMA: t{} size={} off=0x{:x} flg={} nloop={} eop={} nreg={} vif0=0x{:x} "
               "vif1=0x{:x}",
               count, t.size_bytes, off, (int)tag.flg(), tag.nloop(), (int)tag.eop(), tag.nreg(),
               t.vif0(), t.vif1());
    }
    decode_transfer(t, g_dec);
  }
}
// Read the tpage id back out of the header (offset 8).
static u32 page_id(const u8* tpage) {
  u32 id = 0;
  memcpy(&id, tpage + 8, 4);
  return id;
}

void gfx_texture_upload_now(const u8* tpage, int mode, u32 s7_ptr) {
  (void)mode;
  if (!g_metal || !tpage) {
    return;
  }
  // Probe: the village-load fault is a null call in the string library
  // (caller resolved to string-get-int32!!).  Check the string function
  // symbol values for a 0 (unlinked) symbol.
  {
    static bool ottsel_str_dumped = false;
    if (!ottsel_str_dumped) {
      ottsel_str_dumped = true;
      const char* names[] = {"string-get-int32!!", "string-get-arg!!", "string->int",
                             "string->float",      "string-char",      "string-length"};
      for (const char* nm : names) {
        auto info = g_pc_port_funcs.intern_from_c(nm);
        u32 v = 0;
        if (info.offset) {
          memcpy(&v, g_ee_main_mem + info.offset, 4);
        }
        u32 v4 = 0;
        if (info.offset) {
          memcpy(&v4, g_ee_main_mem + info.offset + 4, 4);
        }
        lg::info("OTTSEL STRPROBE: {} sym=0x{:x} val0=0x{:x} val4=0x{:x}", nm, info.offset, v, v4);
      }
    }
  }
  // Probe: dump the tfrag-vu1-block vu-function header (length/origin/qlength)
  // so the VU1 entry address can be computed from ground truth.
  {
    static bool ottsel_vufunc_dumped = false;
    static bool ottsel_tfragwork_dumped = false;
    if (!ottsel_tfragwork_dumped && g_ee_main_mem) {
      ottsel_tfragwork_dumped = true;
      auto info = g_pc_port_funcs.intern_from_c("*tfrag-work*");
      if (info.offset) {
        u32 val = 0;
        memcpy(&val, g_ee_main_mem + info.offset, 4);
        const u8* tw = g_ee_main_mem + val;
        lg::info("OTTSEL TFRAGWORK: sym=0x{:x} obj=0x{:x} +160..184 = {:08x} {:08x} {:08x} "
                 "{:08x} {:08x} {:08x} {:08x}",
                 info.offset, val, *(u32*)(tw + 160), *(u32*)(tw + 164), *(u32*)(tw + 168),
                 *(u32*)(tw + 172), *(u32*)(tw + 176), *(u32*)(tw + 180), *(u32*)(tw + 184));
        // The tfragment pointer at +168: dump its dma-chain fields.
        u32 tf = 0;
        memcpy(&tf, tw + 168, 4);
        if (tf) {
          const u8* f = g_ee_main_mem + tf;
          lg::info("OTTSEL TFRAGMENT: ptr=0x{:x} dma-chain[0..2] = {:08x} {:08x} {:08x} "
                   "dma-qwc[0..3] = {:02x} {:02x} {:02x} {:02x}",
                   tf, *(u32*)(f + 12), *(u32*)(f + 16), *(u32*)(f + 20), *(u8*)(f + 44),
                   *(u8*)(f + 45), *(u8*)(f + 46), *(u8*)(f + 47));
          lg::info("OTTSEL TFRAGMENT: data[0..3] = {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(f + 64), *(u32*)(f + 68), *(u32*)(f + 72), *(u32*)(f + 76));
        }
      }
    }
    if (!ottsel_vufunc_dumped && g_ee_main_mem) {
      ottsel_vufunc_dumped = true;
      auto info = g_pc_port_funcs.intern_from_c("tfrag-vu1-block");
      if (info.offset) {
        // intern_from_c returns the SYMBOL address; a GOAL symbol structure is
        // {type, value, ...} so the object address is at symbol+4.
        u32 sym_value = 0;
        memcpy(&sym_value, g_ee_main_mem + info.offset + 4, 4);
        u32 obj_addr = sym_value;
        const u8* obj = g_ee_main_mem + obj_addr;
        u32 length = 0, origin = 0, qlength = 0;
        memcpy(&length, obj, 4);
        memcpy(&origin, obj + 4, 4);
        memcpy(&qlength, obj + 8, 4);
        lg::info("OTTSEL VUFUNC: tfrag-vu1-block offset=0x{:x} value=0x{:x} length=0x{:x} "
                 "origin=0x{:x} qlength=0x{:x}",
                 info.offset, info.value, length, origin, qlength);
        lg::info("OTTSEL VUFUNC: sym[0..3] = {:08x} {:08x} {:08x} {:08x}", *(u32*)(g_ee_main_mem + info.offset),
                 *(u32*)(g_ee_main_mem + info.offset + 4), *(u32*)(g_ee_main_mem + info.offset + 8),
                 *(u32*)(g_ee_main_mem + info.offset + 12));
        lg::info("OTTSEL VUFUNC: obj[0..7] = {:08x} {:08x} {:08x} {:08x} {:08x} {:08x} {:08x} {:08x}",
                 *(u32*)(obj + 0), *(u32*)(obj + 4), *(u32*)(obj + 8), *(u32*)(obj + 12),
                 *(u32*)(obj + 16), *(u32*)(obj + 20), *(u32*)(obj + 24), *(u32*)(obj + 28));
        // First code qword (the entry) + the last (the jump table).
        const u8* code = obj + 16;
        u32 l0 = 0, u0 = 0;
        memcpy(&l0, code, 4);
        memcpy(&u0, code + 4, 4);
        lg::info("OTTSEL VUFUNC: code[0] lower=0x{:08x} upper=0x{:08x}", l0, u0);
      } else {
        lg::info("OTTSEL VUFUNC: tfrag-vu1-block symbol not found");
      }
    }
  }
  // Probe: dump the tpage structure for the first distinct pages so the
  // segment layout and texture descriptions can be verified against the GOAL
  // texture-page type (header 124 bytes, then a pointer array of textures).
  {
    static u32 ottsel_probed_pages = 0;
    static u32 ottsel_probed_ids[24] = {0};
    OttselGoalTexturePage page;
    memcpy(&page, tpage, sizeof(OttselGoalTexturePage));
    bool already = false;
    for (u32 i = 0; i < ottsel_probed_pages && i < 24; i++) {
      if (ottsel_probed_ids[i] == page.id) {
        already = true;
      }
    }
    if (!already && ottsel_probed_pages < 24) {
      ottsel_probed_ids[ottsel_probed_pages++] = page.id;
      lg::info("OTTSEL TPAGE probe: id=0x{:x} len={} size={} mip0={} mode={}", page.id,
               page.length, page.size, page.mip0_size, mode);
      for (int s = 0; s < 3; s++) {
        lg::info("OTTSEL TPAGE probe: seg{} ptr=0x{:x} size=0x{:x} dest=0x{:x}", s,
                 page.segment[s].block_data_ptr, page.segment[s].size, page.segment[s].dest);
      }
      u32 desc_ptr = 0;
      memcpy(&desc_ptr, tpage + sizeof(OttselGoalTexturePage), 4);
      if (desc_ptr && desc_ptr < 0x08000000) {
        OttselGoalTexture tex;
        memcpy(&tex, g_ee_main_mem + desc_ptr, sizeof(OttselGoalTexture));
        lg::info("OTTSEL TPAGE probe: tex0 w={} h={} psm=0x{:x} clutpsm=0x{:x} dest0=0x{:x} "
                 "clutdest=0x{:x} width0={}",
                 tex.w, tex.h, tex.psm, tex.clutpsm, tex.dest[0], tex.clut_dest, tex.width[0]);
        u32 ptr = page.segment[0].block_data_ptr;
        u32 sz = page.segment[0].size;
        if (ptr && ptr < 0x08000000 && sz >= 32) {
          const u32* w = (const u32*)(g_ee_main_mem + ptr);
          lg::info("OTTSEL TPAGE probe: seg0 data[0..7] = {:08x} {:08x} {:08x} {:08x} {:08x} "
                   "{:08x} {:08x} {:08x}",
                   w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7]);
        }
      } else {
        lg::info("OTTSEL TPAGE probe: tex0 desc ptr invalid (0x{:x} s7=0x{:x})", desc_ptr, s7_ptr);
      }
    }
  }
  int w = 0, h = 0;
  std::vector<unsigned char> rgba;
  rgba.resize(4096 * 4096 * 4);
  u32 tex_idx = 0;
  if (decode_largest_texture(tpage, mode, s7_ptr, rgba.data(), w, h, &tex_idx)) {
    // S2.2 BOT21: present decoded textures, but skip UNIFORM (empty) pages.
    // The village boot uploads small all-black/all-gray tpage regions
    // (e.g. tpage 0x2 tex 43 and 0x100 tex 0 decode to a single color); the
    // BOT20 every-decode gate let the LAST such page clobber the visible
    // frame, so the window went black even though presents were firing.  A
    // real game texture is never perfectly uniform, so keeping the previous
    // frame for uniform decodes preserves the last real image.  The
    // best-area gate from BOT16 had the opposite flaw (smaller real village
    // textures never replaced the title backdrop), so both heuristics are
    // replaced by the uniformity check.
    bool uniform = true;
    if (w > 0 && h > 0) {
      const size_t n = (size_t)w * h;
      const u8 r0 = rgba[0], g0 = rgba[1], b0 = rgba[2];
      size_t stride = n / 256 + 1;  // sample ~256 pixels across the page
      for (size_t i = 0; i < n; i += stride) {
        const u8* p = rgba.data() + i * 4;
        if (p[0] != r0 || p[1] != g0 || p[2] != b0) {
          uniform = false;
          break;
        }
      }
    }
    if (uniform) {
      static u32 ottsel_gfx_uniform = 0;
      if (ottsel_gfx_uniform++ < 4) {
        lg::info("OTTSEL GFX: skip uniform {}x{} tpage=0x{:x} tex={} (px0={:02x}{:02x}{:02x}); "
                 "keeping the last real frame",
                 w, h, page_id(tpage), tex_idx, rgba[0], rgba[1], rgba[2]);
      }
      return;
    }
    static u32 ottsel_gfx_presents = 0;
    static u32 ottsel_decode_logged = 0;
    if (ottsel_decode_logged++ < 4) {
      lg::info("OTTSEL GFX: decode tpage=0x{:x} tex={} {}x{} px0-3={:02x}{:02x}{:02x} "
               "{:02x}{:02x}{:02x} {:02x}{:02x}{:02x} {:02x}{:02x}{:02x}",
               page_id(tpage), tex_idx, w, h, rgba[0], rgba[1], rgba[2], rgba[4], rgba[5],
               rgba[6], rgba[8], rgba[9], rgba[10], rgba[12], rgba[13], rgba[14]);
    }
    g_frame.assign(rgba.begin(), rgba.begin() + (size_t)w * h * 4);
    g_fw = w;
    g_fh = h;
    ottsel_metal_present(g_metal, g_frame.data(), g_fw, g_fh);
    if ((ottsel_gfx_presents++ & 0x3f) == 0) {
      lg::info("OTTSEL GFX: presented game frame {}x{} (tpage 0x{:x} tex {})", w, h,
               page_id(tpage), tex_idx);
    }
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
