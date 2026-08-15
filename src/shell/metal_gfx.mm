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

// The draw decoder: tracks GS registers and emits completed prims.
struct OttselGifDecoder {
  OttselDrawState st;
  OttselVertex verts[8];
  int vert_count = 0;
  u32 prims_logged = 0;
  u32 chain_no = 0;

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
    if (prims_logged >= 300) {
      return;
    }
    prims_logged++;
    GsTex0 gt(st.tex0);
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
    if (prims_logged >= 300) {
      return;
    }
    prims_logged++;
    GsTex0 gt(st.tex0);
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
  void push_vertex(u32 x, u32 y, u32 z) {
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
        break;
      case GsRegisterAddress::SCISSOR_1:
        st.scissor = value;
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
              dec.push_vertex(x << 16, y << 16, z);
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
              dec.push_vertex(x << 16, y << 16, z);
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
  static u32 g_chain_no = 0;
  g_chain_no++;
  g_dec.chain_no = g_chain_no;
  static int ottsel_dma_logged = 0;
  bool log_dma = ottsel_dma_logged < 3;
  if (log_dma) {
    ottsel_dma_logged++;
  }
  const u8* base = (const u8*)data;
  DmaFollower dma(base, offset);
  int count = 0;
  while (!dma.ended() && count < 512) {
    DmaTransfer t = dma.read_and_advance();
    count++;
    if (t.size_bytes == 0) {
      continue;
    }
    const u8* g = t.data;
    GifTag tag(g);
    u32 off = (u32)(g - base);
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
    // Present the largest texture seen so far (the title backdrop should
    // replace the boot ocean texture when the title screen draws).
    static int g_best_area = 0;
    if (w * h >= g_best_area) {
      g_best_area = w * h;
      g_frame.assign(rgba.begin(), rgba.begin() + (size_t)w * h * 4);
      g_fw = w;
      g_fh = h;
      ottsel_metal_present(g_metal, g_frame.data(), g_fw, g_fh);
      lg::info("OTTSEL GFX: presented game frame {}x{} (tpage 0x{:x} tex {})", w, h, page_id(tpage),
               tex_idx);
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
