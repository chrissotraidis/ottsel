// Ottsel S2.2 — Metal Gfx backend.
//
// Registers a GfxRendererModule with the runtime so the game's texture
// uploads (pc_texture_upload_now -> Gfx::GetCurrentRenderer()) decode the
// tpage's first texture and present it through the shell's CAMetalLayer.
// This is the first visible game frame through Metal (S2.2 sub-gate); the
// full DMA-chain draw decode (send_chain) is the remaining renderer work.

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <array>
#include <cmath>
#include <condition_variable>
#include <cstring>
#include <memory>
#include <mutex>
#include <numeric>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <unistd.h>

#include "common/custom_data/Tfrag3Data.h"
#include "common/util/FileUtil.h"
#include "common/util/Serializer.h"
#include "common/util/compress.h"
#include "game/graphics/gfx.h"
#include "common/texture/texture_conversion.h"
#include "common/dma/dma_chain_read.h"
#include "common/dma/gs.h"
#include "common/dma/ottsel_sprite_math.h"
#include "common/dma/ottsel_data_root.h"
#include "common/dma/ottsel_direct_ir.h"
#include "common/dma/ottsel_sprite_phase.h"

#include "metal_shell.h"
#include "mobile_generic_policy.h"
#include "mobile_scene_policy.h"
#include "game/sce/sif_ee.h"

// BOT22: synthetic pad press state (defined in game/sce/libpad.cpp).
extern int g_ottsel_synthetic_frames;
#include "tfrag_microcode.h"
#include "generic_microcode.h"

#include "vu1.h"
#include "vif_unpack.h"

#include "common/log/log.h"

// The app's bundle and writable directories (src/shell/ios_boot.cpp).
extern std::string ottsel_ios_bundle_dir();
extern std::string ottsel_ios_writable_dir();
extern u32 g_ottsel_ios_vsync_count;

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
// The shell's Metal presenter. CPU raster output remains diagnostic only and
// is never published as a product frame.
OttselMetal* g_metal = nullptr;

// A deliberately short, file-triggered accounting window for the real GS
// Direct path.  It answers one product question without producing a
// frame-by-frame log: does title/menu traffic arrive as DIRECT/GIF packets,
// turn into primitives, and reach the CPU compositor?
struct MobileDirectTrace {
  bool active = false;
  bool decoding_direct = false;
  u32 start_chain = 0;
  u32 direct_transfers = 0;
  u64 direct_bytes = 0;
  u32 gif_tags = 0;
  u32 packed_tags = 0;
  u32 reglist_tags = 0;
  u32 image_tags = 0;
  u32 sprites = 0;
  u32 triangles = 0;
  u32 strips = 0;
  // Sprite3 uses these VU entry points.  Count them separately from the
  // tfrag entries so a title/menu window can identify the missing renderer
  // branch without relying on a guess from packet volume.
  u32 mscal_init = 0;
  u32 mscal_2d_world = 0;
  u32 mscal_2d_hud = 0;
  u32 mscal_3d = 0;
  u32 mscal_other = 0;
  std::array<u16, 16> other_mscal_entries{};
  u32 other_mscal_entry_count = 0;
  u32 unhandled_packed_registers = 0;
  u32 font_packet_samples = 0;
  u32 glyph_packet_samples = 0;
  bool glyph_ir_logged = false;
  bool native_product = false;
  int draw_start = 0;
};
MobileDirectTrace g_mobile_direct_trace;
u32 g_mobile_chain_no = 0;
u32& g_chain_no = g_mobile_chain_no;
bool g_mobile_generic_probe_pending = false;
bool g_mobile_merc_trace = false;
constexpr u32 kMobileDirectTraceChains = 900;

// CPU-side level data shared with the desktop PC renderer.  iOS keeps this
// parsed form independent of the experimental VU/GIF decoder; Metal bucket
// renderers will consume these same tfrag3 trees directly.
std::unordered_map<std::string, std::unique_ptr<tfrag3::Level>> g_mobile_levels;
bool g_mobile_native_sprite_uploaded = false;
bool g_mobile_native_sprite_probe_requested = false;
bool g_mobile_native_sprite_color_only_probe = false;
bool g_mobile_native_sprite_product_requested = false;
bool g_mobile_bucket67_world_probe_active = false;
u32 g_mobile_native_sprite_candidates = 0;
bool g_mobile_sprite_record_trace = false;
u32 g_mobile_sprite_record_trace_count = 0;
bool g_mobile_sprite_identity_auto_armed = false;

// Byte-for-byte mirror of the PC-port packet emitted by the game before a
// TFRAG/TIE bucket. Keep it local to avoid pulling OpenGL renderer headers
// into the Metal shell.
struct OttselPcPortData {
  float planes[4][4];
  s32 itimes[4][4];
  float camera[4][4];
  float hvdf_off[4];
  float fog[4];
  float trans[4];
  float rot[4][4];
  float perspective[4][4];
  char level_name[32];
};
static_assert(sizeof(OttselPcPortData) == 16 * 25, "PC-port packet layout");

OttselPcPortData g_mobile_camera{};
u64 g_mobile_camera_packet_count = 0;
u32 g_mobile_camera_last_chain = 0;
u32 g_mobile_camera_last_transfer = 0;
std::string g_mobile_camera_level;
std::unordered_set<std::string> g_mobile_camera_levels_logged;
bool g_mobile_camera_transition_trace = false;
u32 g_mobile_camera_transition_trace_count = 0;
std::string g_mobile_tie_level;
u32 g_mobile_tie_geo = 0;
u32 g_mobile_tie_tree = 0;
std::array<s32, 16> g_mobile_tie_itimes{};
bool g_mobile_tie_itimes_valid = false;

struct MobileTieColorRange {
  u32 geo = 0;
  u32 tree = 0;
  u32 color_offset = 0;
};
std::vector<MobileTieColorRange> g_mobile_tie_color_ranges;
struct MobileTfragColorRange {
  u32 geo = 0;
  u32 tree = 0;
  u32 color_offset = 0;
};
std::string g_mobile_tfrag_level;
std::string g_mobile_tfrag_visibility_level;
std::vector<MobileTfragColorRange> g_mobile_tfrag_color_ranges;
std::array<s32, 16> g_mobile_tfrag_itimes{};
bool g_mobile_tfrag_itimes_valid = false;
bool g_mobile_tfrag_visibility_ready = false;
bool g_mobile_tfrag_normal_only_probe = false;
std::array<float, 16> g_mobile_tfrag_cull_planes{};
std::array<float, 16> g_mobile_tie_cull_planes{};
bool g_mobile_tie_visibility_ready = false;
std::string g_mobile_tie_visibility_level;
std::array<float, 4> g_mobile_fog_color = {29.f / 255.f, 80.f / 255.f, 200.f / 255.f,
                                            1.f};
std::array<u8, 3> g_mobile_fog_rgb = {29, 80, 200};
std::unordered_set<std::string> g_mobile_missing_levels;
std::unordered_map<const tfrag3::Level*, u32> g_mobile_level_texture_bases;
u32 g_mobile_next_texture_base = 0;

void update_mobile_fog_color(u64 value) {
  const std::array<u8, 3> next = {(u8)(value & 0xff), (u8)((value >> 8) & 0xff),
                                  (u8)((value >> 16) & 0xff)};
  if (next == g_mobile_fog_rgb) {
    return;
  }
  g_mobile_fog_rgb = next;
  for (int i = 0; i < 3; ++i) {
    g_mobile_fog_color[i] = next[i] / 255.f;
  }
  static u32 fog_changes = 0;
  ++fog_changes;
  if (fog_changes <= 4) {
    lg::info("OTTSEL FOGCOL: update={} rgb=({},{},{})", fog_changes, next[0], next[1],
             next[2]);
  }
}

void build_visible_mobile_tie_mesh(const std::string& level_name,
                                   const OttselPcPortData& packet);

void set_mobile_tie_colors(const OttselPcPortData& packet) {
  if (!g_metal || g_mobile_tie_level.empty()) {
    return;
  }
  std::array<s32, 16> itimes{};
  memcpy(itimes.data(), packet.itimes, sizeof(packet.itimes));
  if (g_mobile_tie_itimes_valid && itimes == g_mobile_tie_itimes) {
    return;
  }
  const auto level_it = g_mobile_levels.find(g_mobile_tie_level);
  if (level_it == g_mobile_levels.end()) {
    return;
  }
  if (g_mobile_tie_color_ranges.empty()) {
    return;
  }

  std::array<std::array<u16, 4>, 8> weights{};
  for (int component = 0; component < 8; ++component) {
    const int quad_idx = component / 2;
    const int word_off = component % 2 * 2;
    for (int channel = 0; channel < 4; ++channel) {
      const u32 word = (u32)packet.itimes[quad_idx][word_off + channel / 2];
      weights[component][channel] = (word >> (channel % 2 ? 16 : 0)) & 0xff;
    }
  }
  u32 total_color_count = 0;
  for (const auto& range : g_mobile_tie_color_ranges) {
    const auto& colors = level_it->second->tie_trees[range.geo][range.tree].colors;
    total_color_count = std::max(total_color_count, range.color_offset + colors.color_count);
  }
  if (!total_color_count) {
    return;
  }
  std::vector<u8> result((size_t)total_color_count * 4);
  std::array<u8, 4> min = {255, 255, 255, 255};
  std::array<u8, 4> max = {};
  for (const auto& range : g_mobile_tie_color_ranges) {
    const auto& colors = level_it->second->tie_trees[range.geo][range.tree].colors;
    for (u32 color = 0; color < colors.color_count; ++color) {
      for (int channel = 0; channel < 4; ++channel) {
        u32 value = 0;
        for (int palette = 0; palette < 8; ++palette) {
          value += weights[palette][channel] * colors.read(color, palette, channel);
        }
        const u8 out = (u8)std::min(channel == 3 ? 128u : 255u, value >> 6);
        result[(range.color_offset + color) * 4 + channel] = out;
        min[channel] = std::min(min[channel], out);
        max[channel] = std::max(max[channel], out);
      }
    }
  }
  ottsel_metal_set_tie_colors(g_metal, result.data(), total_color_count);
  g_mobile_tie_itimes = itimes;
  g_mobile_tie_itimes_valid = true;
  static u32 tod_updates = 0;
  ++tod_updates;
  if (tod_updates <= 3 || tod_updates % 120 == 0) {
    lg::info("OTTSEL TIE: TOD update={} colors={} rgba-min=({},{},{},{}) "
             "rgba-max=({},{},{},{})",
             tod_updates, total_color_count, min[0], min[1], min[2], min[3], max[0], max[1],
             max[2], max[3]);
  }
}

void set_mobile_tfrag_colors(const OttselPcPortData& packet) {
  if (!g_metal || g_mobile_tfrag_level.empty() || g_mobile_tfrag_color_ranges.empty()) {
    return;
  }
  std::array<s32, 16> itimes{};
  memcpy(itimes.data(), packet.itimes, sizeof(packet.itimes));
  if (g_mobile_tfrag_itimes_valid && itimes == g_mobile_tfrag_itimes) {
    return;
  }
  const auto level_it = g_mobile_levels.find(g_mobile_tfrag_level);
  if (level_it == g_mobile_levels.end()) {
    return;
  }

  std::array<std::array<u16, 4>, 8> weights{};
  for (int component = 0; component < 8; ++component) {
    const int quad_idx = component / 2;
    const int word_off = component % 2 * 2;
    for (int channel = 0; channel < 4; ++channel) {
      const u32 word = (u32)packet.itimes[quad_idx][word_off + channel / 2];
      weights[component][channel] = (word >> (channel % 2 ? 16 : 0)) & 0xff;
    }
  }
  u32 total_color_count = 0;
  for (const auto& range : g_mobile_tfrag_color_ranges) {
    const auto& colors = level_it->second->tfrag_trees[range.geo][range.tree].colors;
    total_color_count = std::max(total_color_count, range.color_offset + colors.color_count);
  }
  if (!total_color_count) {
    return;
  }
  std::vector<u8> result((size_t)total_color_count * 4);
  for (const auto& range : g_mobile_tfrag_color_ranges) {
    const auto& colors = level_it->second->tfrag_trees[range.geo][range.tree].colors;
    for (u32 color = 0; color < colors.color_count; ++color) {
      for (int channel = 0; channel < 4; ++channel) {
        u32 value = 0;
        for (int palette = 0; palette < 8; ++palette) {
          value += weights[palette][channel] * colors.read(color, palette, channel);
        }
        result[(range.color_offset + color) * 4 + channel] =
            (u8)std::min(channel == 3 ? 128u : 255u, value >> 6);
      }
    }
  }
  ottsel_metal_set_tfrag_colors(g_metal, result.data(), total_color_count);
  g_mobile_tfrag_itimes = itimes;
  g_mobile_tfrag_itimes_valid = true;
  static u32 tod_updates = 0;
  if (++tod_updates <= 3 || tod_updates % 120 == 0) {
    lg::info("OTTSEL TFRAG: TOD update={} colors={}", tod_updates, total_color_count);
  }
}

void set_mobile_tie_camera(const OttselPcPortData& packet) {
  // Desktop's make_new_cam_mat in scalar form. The Metal shader performs the
  // same component-wise world-to-clip calculation as tfrag3.vert.
  const float fog_constant = packet.fog[0];
  const float game_pzw = packet.perspective[2][3];
  const float pc_scale[3] = {
      fog_constant * packet.perspective[0][0] / 256.f,
      -fog_constant * packet.perspective[1][1] / 128.f,
      fog_constant * packet.perspective[2][2] / 8388608.f +
          (packet.hvdf_off[2] / 8388608.f - 1.f) * game_pzw,
  };
  float pc_camera[16] = {};
  for (int row = 0; row < 3; ++row) {
    for (int col = 0; col < 3; ++col) {
      pc_camera[row * 4 + col] = packet.rot[row][col] * pc_scale[col];
    }
    pc_camera[row * 4 + 3] = packet.rot[row][2] * game_pzw;
  }
  pc_camera[3 * 4 + 2] = fog_constant * packet.perspective[3][2] / 8388608.f;
  const float fog_params[4] = {packet.hvdf_off[3], packet.fog[1], packet.fog[2], 1.f / 255.f};
  ottsel_metal_set_tie_camera(g_metal, pc_camera, packet.trans, fog_params,
                               g_mobile_fog_color.data(), packet.hvdf_off, fog_constant);

  static bool clip_equation_logged = false;
  if (!clip_equation_logged && g_mobile_tie_level == "village1") {
    const auto level_it = g_mobile_levels.find(g_mobile_tie_level);
    if (level_it != g_mobile_levels.end() && !level_it->second->tie_trees.empty() &&
        !level_it->second->tie_trees[g_mobile_tie_geo].empty()) {
      const auto& ledger_vertex = level_it->second->tie_trees[g_mobile_tie_geo][g_mobile_tie_tree]
                                      .unpacked.vertices.front();
      const float vx = ledger_vertex.x - packet.trans[0];
      const float vy = ledger_vertex.y - packet.trans[1];
      const float vz = ledger_vertex.z - packet.trans[2];
      const auto project_reference = [&](float sign) {
        float transformed[4] = {
            sign * pc_camera[12], sign * pc_camera[13], sign * pc_camera[14], sign * pc_camera[15]};
        for (int c = 0; c < 4; ++c) {
          transformed[c] += sign * pc_camera[c] * vx;
          transformed[c] += sign * pc_camera[4 + c] * vy;
          transformed[c] += sign * pc_camera[8 + c] * vz;
        }
        const float q = fog_constant / transformed[3];
        float clip[4] = {transformed[0] * q + packet.hvdf_off[0],
                         transformed[1] * q + packet.hvdf_off[1],
                         transformed[2] * q + packet.hvdf_off[2], transformed[3]};
        clip[0] -= 2048.f;
        clip[1] -= 2048.f;
        clip[2] = clip[2] / 8388608.f - 1.f;
        clip[0] /= 256.f;
        clip[1] /= -128.f;
        clip[0] *= clip[3];
        clip[1] *= clip[3];
        clip[2] *= clip[3];
        clip[1] *= 512.f / 448.f;
        return std::array<float, 4>{clip[0], clip[1], clip[2], clip[3]};
      };
      const auto project_native = [&](float sign) {
        float clip[4] = {sign * pc_camera[12], sign * pc_camera[13], sign * pc_camera[14], 0.f};
        for (int c = 0; c < 4; ++c) {
          clip[c] += sign * pc_camera[c] * vx;
          clip[c] += sign * pc_camera[4 + c] * vy;
          clip[c] += sign * pc_camera[8 + c] * vz;
        }
        clip[1] *= 512.f / 448.f;
        clip[2] = (clip[2] + clip[3]) * 0.5f;
        return std::array<float, 4>{clip[0], clip[1], clip[2], clip[3]};
      };
      const auto tie_reference = project_reference(-1.f);
      const auto tfrag_reference = project_reference(1.f);
      const auto tie_native = project_native(-1.f);
      const auto tfrag_native = project_native(1.f);
      lg::info("OTTSEL CLIP LEDGER: level={} vertex=({:.3f},{:.3f},{:.3f}) trans=({:.3f},{:.3f},{:.3f}) "
               "fog={} hvdf=({:.3f},{:.3f},{:.3f},{:.3f}) "
               "tie-ref=({:.6f},{:.6f},{:.6f},{:.6f}) tie-native=({:.6f},{:.6f},{:.6f},{:.6f}) "
               "tfrag-ref=({:.6f},{:.6f},{:.6f},{:.6f}) tfrag-native=({:.6f},{:.6f},{:.6f},{:.6f})",
               g_mobile_tie_level, ledger_vertex.x, ledger_vertex.y, ledger_vertex.z, packet.trans[0],
               packet.trans[1], packet.trans[2], fog_constant, packet.hvdf_off[0], packet.hvdf_off[1],
               packet.hvdf_off[2], packet.hvdf_off[3], tie_reference[0], tie_reference[1], tie_reference[2],
               tie_reference[3], tie_native[0], tie_native[1], tie_native[2], tie_native[3],
               tfrag_reference[0], tfrag_reference[1], tfrag_reference[2], tfrag_reference[3],
               tfrag_native[0], tfrag_native[1], tfrag_native[2], tfrag_native[3]);
      clip_equation_logged = true;
    }
  }

  // A single CPU projection summary is the falsifiable companion to the
  // Metal draw. If no vertices are inside clip space here, debug camera math
  // or mesh selection; if they are, debug the encoder/pipeline instead.
  static std::string clip_logged_for;
  if (clip_logged_for == g_mobile_tie_level) {
    return;
  }
  const auto level_it = g_mobile_levels.find(g_mobile_tie_level);
  if (level_it == g_mobile_levels.end()) {
    return;
  }
  const auto& vertices = level_it->second->tie_trees[g_mobile_tie_geo][g_mobile_tie_tree]
                             .unpacked.vertices;
  u64 finite = 0;
  u64 metal_visible = 0;
  u64 gl_visible = 0;
  float min_ndc_x = 1e30f, max_ndc_x = -1e30f;
  float min_ndc_y = 1e30f, max_ndc_y = -1e30f;
  float min_ndc_z = 1e30f, max_ndc_z = -1e30f;
  const size_t stride = std::max<size_t>(1, vertices.size() / 4096);
  for (size_t i = 0; i < vertices.size(); i += stride) {
    const auto& v = vertices[i];
    const float x = v.x - packet.trans[0];
    const float y = v.y - packet.trans[1];
    const float z = v.z - packet.trans[2];
    float clip[4] = {-pc_camera[12], -pc_camera[13], -pc_camera[14], 0.f};
    for (int c = 0; c < 4; ++c) {
      clip[c] -= pc_camera[c] * x + pc_camera[4 + c] * y + pc_camera[8 + c] * z;
    }
    if (!std::isfinite(clip[0]) || !std::isfinite(clip[1]) || !std::isfinite(clip[2]) ||
        !std::isfinite(clip[3]) || std::abs(clip[3]) < 1e-6f) {
      continue;
    }
    ++finite;
    const float ndc_x = clip[0] / clip[3];
    const float ndc_y = (clip[1] * (512.f / 448.f)) / clip[3];
    const float ndc_z = ((clip[2] + clip[3]) * 0.5f) / clip[3];
    min_ndc_x = std::min(min_ndc_x, ndc_x);
    max_ndc_x = std::max(max_ndc_x, ndc_x);
    min_ndc_y = std::min(min_ndc_y, ndc_y);
    max_ndc_y = std::max(max_ndc_y, ndc_y);
    min_ndc_z = std::min(min_ndc_z, ndc_z);
    max_ndc_z = std::max(max_ndc_z, ndc_z);
    if (std::abs(clip[0]) <= std::abs(clip[3]) && std::abs(clip[1]) <= std::abs(clip[3]) &&
        std::abs(clip[2]) <= std::abs(clip[3])) {
      ++gl_visible;
      // tie_vs converts desktop OpenGL clip depth [-w,w] to Metal's [0,w]
      // before output. Apply that same conversion to this diagnostic; testing
      // the pre-remap value made every valid negative-z sample look culled.
      const float metal_z = (clip[2] + clip[3]) * 0.5f;
      if (metal_z >= 0.f && metal_z <= clip[3]) {
        ++metal_visible;
      }
    }
  }
  clip_logged_for = g_mobile_tie_level;
  lg::info("OTTSEL TIE: clip sample level='{}' finite={}/{} gl-clip-visible={} "
           "metal-clip-visible={} ndc-x=({:.4f},{:.4f}) ndc-y=({:.4f},{:.4f}) "
           "ndc-z=({:.4f},{:.4f})",
           g_mobile_tie_level, finite, (vertices.size() + stride - 1) / stride, gl_visible,
           metal_visible, min_ndc_x, max_ndc_x, min_ndc_y, max_ndc_y, min_ndc_z, max_ndc_z);
}

void build_mobile_tie_mesh(const std::string& level_name) {
  if (!g_metal || g_mobile_tie_level == level_name) {
    return;
  }
  const auto it = g_mobile_levels.find(level_name);
  if (it == g_mobile_levels.end()) {
    return;
  }
  const auto& level = *it->second;
  const u32 texture_base = g_mobile_level_texture_bases.at(&level);
  for (u32 geo = 0; geo < level.tie_trees.size(); ++geo) {
    for (u32 tree_idx = 0; tree_idx < level.tie_trees[geo].size(); ++tree_idx) {
      const auto& tree = level.tie_trees[geo][tree_idx];
      const u32 first = tree.category_draw_indices[(u32)tfrag3::TieCategory::NORMAL];
      const u32 last = tree.category_draw_indices[(u32)tfrag3::TieCategory::TRANS];
      if (first == last || tree.unpacked.vertices.empty()) {
        continue;
      }
      std::vector<u32> triangles;
      std::vector<OttselMetalTieDraw> batches;
      std::vector<bool> used_textures(level.textures.size());
      const auto append_indices = [&triangles](const u32* indices, size_t count, bool strips) {
        if (!strips) {
          for (size_t i = 0; i + 2 < count; i += 3) {
            if (indices[i] == UINT32_MAX || indices[i + 1] == UINT32_MAX ||
                indices[i + 2] == UINT32_MAX) {
              continue;
            }
            triangles.insert(triangles.end(), {indices[i], indices[i + 1], indices[i + 2]});
          }
          return;
        }
        size_t run_start = 0;
        for (size_t i = 0; i <= count; ++i) {
          if (i != count && indices[i] != UINT32_MAX) {
            continue;
          }
          const size_t run_count = i - run_start;
          for (size_t j = 2; j < run_count; ++j) {
            u32 a = indices[run_start + j - 2];
            u32 b = indices[run_start + j - 1];
            const u32 c = indices[run_start + j];
            // GL_TRIANGLE_STRIP alternates winding for each triangle.
            if (j & 1) {
              std::swap(a, b);
            }
            triangles.insert(triangles.end(), {a, b, c});
          }
          run_start = i + 1;
        }
      };
      for (u32 draw_idx = first; draw_idx < last; ++draw_idx) {
        const auto& draw = tree.static_draws[draw_idx];
        const u32 offset = (u32)triangles.size();
        for (const auto& run : draw.runs) {
          std::vector<u32> run_indices(run.length);
          for (u32 i = 0; i < run.length; ++i) {
            run_indices[i] = run.vertex0 + i;
          }
          append_indices(run_indices.data(), run_indices.size(), tree.use_strips);
        }
        append_indices(draw.plain_indices.data(), draw.plain_indices.size(), tree.use_strips);
        const u32 count = (u32)triangles.size() - offset;
        if (count) {
          batches.push_back({offset, count,
                             ottsel_mobile_scene_texture_slot(texture_base, draw.tree_tex_id),
                             draw.mode.as_int()});
          if (draw.tree_tex_id >= 0 && (size_t)draw.tree_tex_id < used_textures.size()) {
            used_textures[draw.tree_tex_id] = true;
          }
        }
      }
      if (triangles.empty() || batches.empty()) {
        continue;
      }
      u32 uploaded_textures = 0;
      for (u32 texture_idx = 0; texture_idx < level.textures.size(); ++texture_idx) {
        if (!used_textures[texture_idx]) {
          continue;
        }
        const auto& texture = level.textures[texture_idx];
        if (texture.data.size() != (size_t)texture.w * texture.h) {
          lg::warn("OTTSEL TIE: invalid texture {} '{}' {}x{} words={}", texture_idx,
                   texture.debug_name, texture.w, texture.h, texture.data.size());
          continue;
        }
        ottsel_metal_set_tie_texture(g_metal, texture_base + texture_idx, texture.data.data(),
                                     texture.w, texture.h);
        ++uploaded_textures;
      }
      std::vector<u8> default_colors((size_t)tree.colors.color_count * 4, 128);
      if (!default_colors.empty()) {
        ottsel_metal_set_tie_colors(g_metal, default_colors.data(), tree.colors.color_count);
      }
      ottsel_metal_set_tie_mesh(g_metal, tree.unpacked.vertices.data(),
                                 (u32)tree.unpacked.vertices.size(), triangles.data(),
                                 (u32)triangles.size(), batches.data(), (u32)batches.size());
      g_mobile_tie_level = level_name;
      g_mobile_tie_geo = geo;
      g_mobile_tie_tree = tree_idx;
      g_mobile_tie_color_ranges = {{geo, tree_idx, 0}};
      g_mobile_tie_itimes_valid = false;
      lg::info("OTTSEL TIE: normal batches level='{}' geo={} tree={} draws={} vertices={} "
               "triangles={} textures={}",
               level_name, geo, tree_idx, last - first, tree.unpacked.vertices.size(),
               triangles.size() / 3, uploaded_textures);
      return;
    }
  }
  lg::warn("OTTSEL TIE: no normal mesh for '{}'", level_name);
}

bool tie_sphere_in_view(const float sphere[4], const OttselPcPortData& packet) {
  for (int component = 0; component < 4; ++component) {
    const float distance = packet.planes[0][component] * sphere[0] +
                           packet.planes[1][component] * sphere[1] +
                           packet.planes[2][component] * sphere[2] -
                           packet.planes[3][component];
    if (distance <= -sphere[3]) {
      return false;
    }
  }
  return true;
}

void build_visible_mobile_tie_mesh(const std::string& level_name,
                                   const OttselPcPortData& packet) {
  if (!g_metal || g_mobile_tie_visibility_ready || level_name != g_mobile_tie_level) {
    return;
  }
  const auto level_it = g_mobile_levels.find(level_name);
  if (level_it == g_mobile_levels.end()) {
    return;
  }
  const auto& level = *level_it->second;
  const u32 texture_base = g_mobile_level_texture_bases.at(&level);
  std::vector<tfrag3::PreloadedVertex> vertices;
  std::vector<u32> triangles;
  std::vector<OttselMetalTieDraw> batches;
  std::vector<MobileTieColorRange> color_ranges;
  std::vector<bool> used_textures(level.textures.size());
  u32 color_offset = 0;
  u32 total_nodes = 0;
  u32 visible_nodes = 0;
  u32 total_groups = 0;
  u32 visible_groups = 0;
  std::unordered_map<u32, u32> mode_counts;
  u32 strip_ledger_logs = 0;
  const auto append_indices = [&triangles](const std::vector<u32>& indices, u32 vertex_base,
                                           bool strips) {
    if (!strips) {
      for (size_t i = 0; i + 2 < indices.size(); i += 3) {
        if (indices[i] == UINT32_MAX || indices[i + 1] == UINT32_MAX ||
            indices[i + 2] == UINT32_MAX) {
          continue;
        }
        triangles.insert(triangles.end(),
                         {vertex_base + indices[i], vertex_base + indices[i + 1],
                          vertex_base + indices[i + 2]});
      }
      return;
    }
    size_t run_start = 0;
    for (size_t i = 0; i <= indices.size(); ++i) {
      if (i != indices.size() && indices[i] != UINT32_MAX) {
        continue;
      }
      const size_t run_count = i - run_start;
      for (size_t j = 2; j < run_count; ++j) {
        u32 a = indices[run_start + j - 2];
        u32 b = indices[run_start + j - 1];
        const u32 c = indices[run_start + j];
        if (j & 1) {
          std::swap(a, b);
        }
        triangles.insert(triangles.end(),
                         {vertex_base + a, vertex_base + b, vertex_base + c});
      }
      run_start = i + 1;
    }
  };

  // Match Tie3::lod(): select one geometry slot, then draw every tree in it.
  // Drawing every slot overlays alternate LODs and manufactures bands.
  const u32 geo = (u32)std::clamp(Gfx::g_global_settings.lod_tie, 0,
                                  (int)level.tie_trees.size() - 1);
  for (u32 tree_idx = 0; tree_idx < level.tie_trees[geo].size(); ++tree_idx) {
      const auto& tree = level.tie_trees[geo][tree_idx];
    const u32 first = tree.category_draw_indices[(u32)tfrag3::TieCategory::NORMAL];
    const u32 last = tree.category_draw_indices[(u32)tfrag3::TieCategory::TRANS];
    if (first == last || tree.unpacked.vertices.empty() ||
        color_offset + tree.colors.color_count > UINT16_MAX + 1u) {
      continue;
    }
    // Upload one stable level snapshot. Camera motion is handled by uniforms;
    // rebuilding this 500k+ vertex mesh on every frustum change causes severe
    // stalls and races a camera-dependent mesh against a newer camera.
    total_nodes += tree.bvh.vis_nodes.size();
    visible_nodes += tree.bvh.vis_nodes.size();
    const u32 vertex_base = (u32)vertices.size();
    const u32 triangle_start = (u32)triangles.size();
    for (u32 draw_idx = first; draw_idx < last; ++draw_idx) {
      const auto& draw = tree.static_draws[draw_idx];
      std::vector<u32> selected_indices;
      u32 index_offset = draw.unpacked.idx_of_first_idx_in_full_buffer;
      bool strip_run_open = false;
      for (const auto& group : draw.vis_groups) {
        total_groups++;
        const bool is_visible = true;
        if (is_visible) {
          visible_groups++;
          selected_indices.insert(selected_indices.end(),
                                  tree.unpacked.indices.begin() + index_offset,
                                  tree.unpacked.indices.begin() + index_offset + group.num_inds);
          // Keep adjacent visible groups in one strip, matching OpenGL's
          // contiguous multidraw run. Insert a restart only at a visibility
          // transition, not after every visible group.
          strip_run_open = tree.use_strips;
        } else if (tree.use_strips && strip_run_open) {
          selected_indices.push_back(UINT32_MAX);
          strip_run_open = false;
        }
        index_offset += group.num_inds;
      }
      const u32 batch_start = (u32)triangles.size();
      append_indices(selected_indices, vertex_base, tree.use_strips);
      const u32 batch_count = (u32)triangles.size() - batch_start;
      if (batch_count) {
        batches.push_back(
            {batch_start, batch_count,
             ottsel_mobile_scene_texture_slot(texture_base, draw.tree_tex_id),
             draw.mode.as_int()});
        mode_counts[draw.mode.as_int()]++;
        if (tree.use_strips && strip_ledger_logs < 12) {
          u32 visible_inds = 0;
          u32 visible_runs = 0;
          bool in_run = false;
          for (const auto index : selected_indices) {
            if (index == UINT32_MAX) {
              in_run = false;
            } else {
              ++visible_inds;
              if (!in_run) {
                ++visible_runs;
                in_run = true;
              }
            }
          }
          lg::info("OTTSEL TIE STRIP LEDGER: geo={} tree={} draw={} groups={} visible-runs={} "
                   "source-indices={} source-tris={} native-tris={} mode=0x{:x}",
                   geo, tree_idx, batches.size() - 1, draw.vis_groups.size(), visible_runs,
                   visible_inds, draw.num_triangles, batch_count / 3, draw.mode.as_int());
          ++strip_ledger_logs;
        }
        if (draw.tree_tex_id >= 0 && (size_t)draw.tree_tex_id < used_textures.size()) {
          used_textures[draw.tree_tex_id] = true;
        }
      }
    }
      if ((u32)triangles.size() == triangle_start) {
        continue;
      }
      vertices.reserve(vertices.size() + tree.unpacked.vertices.size());
      for (auto vertex : tree.unpacked.vertices) {
        vertex.color_index += color_offset;
        vertices.push_back(vertex);
      }
      color_ranges.push_back({geo, tree_idx, color_offset});
      color_offset += tree.colors.color_count;
  }
  if (vertices.empty() || triangles.empty() || batches.empty()) {
    lg::warn("OTTSEL TIE: visibility snapshot produced no normal geometry for '{}'", level_name);
    return;
  }
  u32 uploaded_textures = 0;
  for (u32 texture_idx = 0; texture_idx < level.textures.size(); ++texture_idx) {
    if (!used_textures[texture_idx]) {
      continue;
    }
    const auto& texture = level.textures[texture_idx];
    if (texture.data.size() != (size_t)texture.w * texture.h) {
      continue;
    }
    ottsel_metal_set_tie_texture(g_metal, texture_base + texture_idx, texture.data.data(),
                                 texture.w, texture.h);
    ++uploaded_textures;
  }
  std::vector<u8> default_colors((size_t)color_offset * 4, 128);
  ottsel_metal_set_tie_colors(g_metal, default_colors.data(), color_offset);
  ottsel_metal_set_tie_mesh(g_metal, vertices.data(), (u32)vertices.size(), triangles.data(),
                             (u32)triangles.size(), batches.data(), (u32)batches.size());
  g_mobile_tie_color_ranges = std::move(color_ranges);
  g_mobile_tie_itimes_valid = false;
  g_mobile_tie_visibility_ready = true;
  g_mobile_tie_visibility_level = level_name;
  memcpy(g_mobile_tie_cull_planes.data(), packet.planes, sizeof(packet.planes));
  lg::info("OTTSEL TIE: stable level snapshot lod=0 geos={} trees={} nodes={}/{} groups={}/{} "
           "batches={} vertices={} triangles={} textures={}",
           level.tie_trees.size(), g_mobile_tie_color_ranges.size(), visible_nodes, total_nodes,
           visible_groups,
           total_groups, batches.size(), vertices.size(), triangles.size() / 3, uploaded_textures);
  std::vector<std::pair<u32, u32>> sorted_modes(mode_counts.begin(), mode_counts.end());
  std::sort(sorted_modes.begin(), sorted_modes.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });
  std::string mode_summary;
  for (size_t i = 0; i < sorted_modes.size() && i < 8; ++i) {
    mode_summary += fmt::format("{:#x}:{} ", sorted_modes[i].first, sorted_modes[i].second);
  }
  lg::info("OTTSEL TIE: visible DrawMode histogram [{}]", mode_summary);
}

void build_visible_mobile_tfrag_mesh(const std::string& level_name,
                                     const OttselPcPortData& packet) {
  if (!g_metal || (g_mobile_tfrag_visibility_ready && level_name == g_mobile_tfrag_level)) {
    return;
  }
  const auto level_it = g_mobile_levels.find(level_name);
  if (level_it == g_mobile_levels.end()) {
    return;
  }
  const auto& level = *level_it->second;
  const u32 texture_base = g_mobile_level_texture_bases.at(&level);
  if (!g_mobile_tfrag_normal_only_probe) {
    const std::string trigger = ottsel_ios_writable_dir() +
                                "ottsel-trace-metal-scene-tfrag-normal-only";
    if (access(trigger.c_str(), F_OK) == 0) {
      unlink(trigger.c_str());
      g_mobile_tfrag_normal_only_probe = true;
      lg::info("OTTSEL TFRAG: NORMAL-only data-family probe enabled");
    }
  }
  std::vector<tfrag3::PreloadedVertex> vertices;
  std::vector<u32> triangles;
  std::vector<OttselMetalTieDraw> batches;
  std::vector<MobileTfragColorRange> color_ranges;
  std::vector<bool> used_textures(level.textures.size());
  u32 color_offset = 0;
  u32 total_nodes = 0;
  u32 visible_nodes = 0;
  u32 total_groups = 0;
  u32 visible_groups = 0;
  std::unordered_map<u32, u32> mode_counts;
  const auto append_strip = [&triangles](const std::vector<u32>& indices, u32 vertex_base) {
    size_t run_start = 0;
    for (size_t i = 0; i <= indices.size(); ++i) {
      if (i != indices.size() && indices[i] != UINT32_MAX) {
        continue;
      }
      const size_t run_count = i - run_start;
      for (size_t j = 2; j < run_count; ++j) {
        u32 a = indices[run_start + j - 2];
        u32 b = indices[run_start + j - 1];
        const u32 c = indices[run_start + j];
        if (j & 1) {
          std::swap(a, b);
        }
        triangles.insert(triangles.end(),
                         {vertex_base + a, vertex_base + b, vertex_base + c});
      }
      run_start = i + 1;
    }
  };

  // Match TFragment::lod(): select one geometry slot. TRANS and DIRT retain
  // their source DrawMode bits; the Metal
  // consumer selects blending and depth-write state per draw instead of
  // treating them as opaque normal geometry.
  const u32 geo = (u32)std::clamp(Gfx::g_global_settings.lod_tfrag, 0,
                                  (int)level.tfrag_trees.size() - 1);
  for (u32 tree_idx = 0; tree_idx < level.tfrag_trees[geo].size(); ++tree_idx) {
      const auto& tree = level.tfrag_trees[geo][tree_idx];
    if ((tree.kind != tfrag3::TFragmentTreeKind::NORMAL &&
         tree.kind != tfrag3::TFragmentTreeKind::TRANS &&
         tree.kind != tfrag3::TFragmentTreeKind::DIRT) ||
        (g_mobile_tfrag_normal_only_probe && tree.kind != tfrag3::TFragmentTreeKind::NORMAL) ||
        tree.unpacked.vertices.empty() ||
        color_offset + tree.colors.color_count > UINT16_MAX + 1u) {
      continue;
    }
    total_nodes += tree.bvh.vis_nodes.size();
    visible_nodes += tree.bvh.vis_nodes.size();
    const u32 vertex_base = (u32)vertices.size();
    const u32 triangle_start = (u32)triangles.size();
    for (const auto& draw : tree.draws) {
      std::vector<u32> selected_indices;
      u32 index_offset = draw.unpacked.idx_of_first_idx_in_full_buffer;
      bool strip_run_open = false;
      for (const auto& group : draw.vis_groups) {
        ++total_groups;
        const bool is_visible = true;
        if (is_visible) {
          ++visible_groups;
          selected_indices.insert(selected_indices.end(),
                                  tree.unpacked.indices.begin() + index_offset,
                                  tree.unpacked.indices.begin() + index_offset + group.num_inds);
          // Keep adjacent visible groups in one strip, matching OpenGL's
          // contiguous multidraw run. Insert a restart only at a visibility
          // transition, not after every visible group.
          strip_run_open = tree.use_strips;
        } else if (tree.use_strips && strip_run_open) {
          selected_indices.push_back(UINT32_MAX);
          strip_run_open = false;
        }
        index_offset += group.num_inds;
      }
      const u32 batch_start = (u32)triangles.size();
      if (tree.use_strips) {
        append_strip(selected_indices, vertex_base);
      } else {
        for (const auto index : selected_indices) {
          if (index != UINT32_MAX) {
            triangles.push_back(vertex_base + index);
          }
        }
      }
      const u32 batch_count = (u32)triangles.size() - batch_start;
      if (batch_count) {
        batches.push_back(
            {batch_start, batch_count,
             ottsel_mobile_scene_texture_slot(texture_base, draw.tree_tex_id),
             draw.mode.as_int()});
        mode_counts[draw.mode.as_int()]++;
        if (draw.tree_tex_id >= 0 && (size_t)draw.tree_tex_id < used_textures.size()) {
          used_textures[draw.tree_tex_id] = true;
        }
      }
    }
      if ((u32)triangles.size() == triangle_start) {
        continue;
      }
      vertices.reserve(vertices.size() + tree.unpacked.vertices.size());
      for (auto vertex : tree.unpacked.vertices) {
        vertex.color_index += color_offset;
        vertices.push_back(vertex);
      }
      color_ranges.push_back({geo, tree_idx, color_offset});
      color_offset += tree.colors.color_count;
  }
  if (vertices.empty() || triangles.empty() || batches.empty()) {
    lg::warn("OTTSEL TFRAG: visible opaque mesh produced no geometry for '{}'", level_name);
    return;
  }
  for (u32 texture_idx = 0; texture_idx < level.textures.size(); ++texture_idx) {
    if (!used_textures[texture_idx]) {
      continue;
    }
    const auto& texture = level.textures[texture_idx];
    if (texture.data.size() == (size_t)texture.w * texture.h) {
      ottsel_metal_set_tie_texture(g_metal, texture_base + texture_idx, texture.data.data(),
                                   texture.w, texture.h);
    }
  }
  std::vector<u8> default_colors((size_t)color_offset * 4, 128);
  ottsel_metal_set_tfrag_colors(g_metal, default_colors.data(), color_offset);
  ottsel_metal_set_tfrag_mesh(g_metal, vertices.data(), (u32)vertices.size(), triangles.data(),
                               (u32)triangles.size(), batches.data(), (u32)batches.size());
  g_mobile_tfrag_level = level_name;
  g_mobile_tfrag_color_ranges = std::move(color_ranges);
  g_mobile_tfrag_itimes_valid = false;
  g_mobile_tfrag_visibility_ready = true;
  g_mobile_tfrag_visibility_level = level_name;
  memcpy(g_mobile_tfrag_cull_planes.data(), packet.planes, sizeof(packet.planes));
  lg::info("OTTSEL TFRAG: stable level snapshot lod=0 geos={} trees={} nodes={}/{} groups={}/{} "
           "batches={} vertices={} triangles={}",
           level.tfrag_trees.size(), g_mobile_tfrag_color_ranges.size(), visible_nodes, total_nodes,
           visible_groups,
           total_groups, batches.size(), vertices.size(), triangles.size() / 3);
  std::vector<std::pair<u32, u32>> sorted_modes(mode_counts.begin(), mode_counts.end());
  std::sort(sorted_modes.begin(), sorted_modes.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });
  std::string mode_summary;
  for (size_t i = 0; i < sorted_modes.size() && i < 12; ++i) {
    mode_summary += fmt::format("{:#x}:{} ", sorted_modes[i].first, sorted_modes[i].second);
  }
  lg::info("OTTSEL TFRAG: visible DrawMode histogram [{}]", mode_summary);
}

void load_mobile_level(const std::string& level_name) {
  if (level_name.empty() || g_mobile_levels.contains(level_name)) {
    return;
  }
  const char* selected_root = ee::ottsel_iso_data_dir();
  const std::string root = ottsel::select_user_data_root(
      selected_root ? selected_root : "", ottsel_ios_bundle_dir() + "iso_data");
  const auto path = fs::path(root) / "fr3" / (level_name + ".fr3");
  if (!fs::exists(path)) {
    // A clean ROM-safe install intentionally has no user-owned FR3 pack. The
    // game requests the same level every frame, so report each missing level
    // once instead of turning the remediation state into an unbounded log and
    // I/O stall.
    if (g_mobile_missing_levels.insert(level_name).second) {
      lg::warn("OTTSEL FR3: missing level '{}' at {}", level_name, path.string());
    }
    return;
  }
  g_mobile_missing_levels.erase(level_name);

  auto compressed = file_util::read_binary_file(path);
  auto decoded = compression::decompress_zstd(compressed.data(), compressed.size());
  auto level = std::make_unique<tfrag3::Level>();
  Serializer serializer(decoded.data(), decoded.size());
  level->serialize(serializer);

  u64 trees = 0;
  u64 draws = 0;
  u64 vertices = 0;
  for (auto& geo_trees : level->tie_trees) {
    for (auto& tree : geo_trees) {
      tree.unpack();
      ++trees;
      draws += tree.static_draws.size();
      vertices += tree.unpacked.vertices.size();
    }
  }
  std::array<u64, (size_t)tfrag3::TFragmentTreeKind::INVALID> tfrag_trees{};
  std::array<u64, (size_t)tfrag3::TFragmentTreeKind::INVALID> tfrag_draws{};
  std::array<u64, (size_t)tfrag3::TFragmentTreeKind::INVALID> tfrag_vertices{};
  for (auto& geo_trees : level->tfrag_trees) {
    for (auto& tree : geo_trees) {
      tree.unpack();
      const auto kind = (size_t)tree.kind;
      if (kind >= tfrag_trees.size()) {
        continue;
      }
      ++tfrag_trees[kind];
      tfrag_draws[kind] += tree.draws.size();
      tfrag_vertices[kind] += tree.unpacked.vertices.size();
    }
  }
  lg::info("OTTSEL FR3: loaded '{}' bytes={} tie-trees={} tie-draws={} tie-verts={} "
           "tfrag-normal=({},{},{}) tfrag-trans=({},{},{}) tfrag-dirt=({},{},{}) "
           "tfrag-ice=({},{},{})",
           level_name, decoded.size(), trees, draws, vertices,
           tfrag_trees[(size_t)tfrag3::TFragmentTreeKind::NORMAL],
           tfrag_draws[(size_t)tfrag3::TFragmentTreeKind::NORMAL],
           tfrag_vertices[(size_t)tfrag3::TFragmentTreeKind::NORMAL],
           tfrag_trees[(size_t)tfrag3::TFragmentTreeKind::TRANS],
           tfrag_draws[(size_t)tfrag3::TFragmentTreeKind::TRANS],
           tfrag_vertices[(size_t)tfrag3::TFragmentTreeKind::TRANS],
           tfrag_trees[(size_t)tfrag3::TFragmentTreeKind::DIRT],
           tfrag_draws[(size_t)tfrag3::TFragmentTreeKind::DIRT],
           tfrag_vertices[(size_t)tfrag3::TFragmentTreeKind::DIRT],
           tfrag_trees[(size_t)tfrag3::TFragmentTreeKind::ICE],
           tfrag_draws[(size_t)tfrag3::TFragmentTreeKind::ICE],
           tfrag_vertices[(size_t)tfrag3::TFragmentTreeKind::ICE]);
  const auto* level_ptr = level.get();
  g_mobile_level_texture_bases[level_ptr] = g_mobile_next_texture_base;
  g_mobile_next_texture_base += level->textures.size();
  g_mobile_levels.emplace(level_name, std::move(level));
  if (level_name != "GAME") {
    build_mobile_tie_mesh(level_name);
  }
}

void request_mobile_levels(const std::vector<std::string>& levels, const char* source) {
  static std::vector<std::string> last_requested;
  if (levels != last_requested) {
    std::string joined;
    for (const auto& level : levels) {
      joined += level + " ";
    }
    lg::info("OTTSEL FR3: {} levels [{}]", source, joined);
    last_requested = levels;
  }
  // Desktop loads GAME.fr3 once as the common Merc/model and texture source.
  // Mobile must do the same before resolving Jak, Daxter, and other actors.
  load_mobile_level("GAME");
  for (const auto& level : levels) {
    load_mobile_level(level);
  }
}

void capture_mobile_camera(const void* packet, size_t size) {
  if (!packet || size != sizeof(OttselPcPortData)) {
    return;
  }
  OttselPcPortData candidate{};
  memcpy(&candidate, packet, sizeof(candidate));
  candidate.level_name[sizeof(candidate.level_name) - 1] = '\0';
  const std::string level(candidate.level_name);
  if (level.empty() || !g_mobile_levels.contains(level)) {
    return;
  }
  if (!g_mobile_camera_transition_trace) {
    const std::string trace_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-camera-transition";
    if (access(trace_path.c_str(), F_OK) == 0) {
      unlink(trace_path.c_str());
      g_mobile_camera_transition_trace = true;
      g_mobile_camera_transition_trace_count = 0;
      lg::info("OTTSEL CAMERA PACKETS: bounded transition ledger armed");
    }
  }
  const bool finite = std::isfinite(candidate.camera[0][0]) &&
                      std::isfinite(candidate.camera[1][1]) &&
                      std::isfinite(candidate.camera[2][2]) &&
                      std::isfinite(candidate.trans[0]) && std::isfinite(candidate.trans[1]) &&
                      std::isfinite(candidate.trans[2]);
  if (g_mobile_camera_transition_trace &&
      g_mobile_camera_transition_trace_count < 64) {
    lg::info("OTTSEL CAMERA PACKET: index={} level='{}' finite={} trans=({}, {}, {}) "
             "r0=({}, {}, {}) r2=({}, {}, {}) persp=({}, {}, {}, {}) hvdf=({}, {}) fog={}",
             g_mobile_camera_transition_trace_count, level, finite, candidate.trans[0],
             candidate.trans[1], candidate.trans[2], candidate.rot[0][0], candidate.rot[0][1],
             candidate.rot[0][2], candidate.rot[2][0], candidate.rot[2][1], candidate.rot[2][2],
             candidate.perspective[0][0], candidate.perspective[1][1], candidate.perspective[2][2],
             candidate.perspective[2][3], candidate.hvdf_off[2], candidate.hvdf_off[3],
             candidate.fog[0]);
    ++g_mobile_camera_transition_trace_count;
    if (g_mobile_camera_transition_trace_count >= 64) {
      g_mobile_camera_transition_trace = false;
      lg::info("OTTSEL CAMERA PACKETS: bounded transition ledger complete");
    }
  }
  ++g_mobile_camera_packet_count;
  if (g_mobile_tie_level.empty() || level == g_mobile_tie_level) {
    g_mobile_camera = candidate;
    g_mobile_camera_level = level;
  }
  if (finite && level == g_mobile_tie_level) {
    const auto planes_changed = [](const std::array<float, 16>& previous,
                                   const float current[4][4]) {
      float max_delta = 0.f;
      const float* current_flat = &current[0][0];
      for (size_t i = 0; i < previous.size(); ++i) {
        max_delta = std::max(max_delta, std::abs(previous[i] - current_flat[i]));
      }
      return max_delta > 0.001f;
    };
    const bool tfrag_planes_changed =
        planes_changed(g_mobile_tfrag_cull_planes, candidate.planes);
    const bool tie_planes_changed = planes_changed(g_mobile_tie_cull_planes, candidate.planes);
    const bool rebuild_tfrag = ottsel_mobile_scene_snapshot_needs_rebuild(
        g_mobile_tfrag_visibility_ready, g_mobile_tfrag_visibility_level != level,
        tfrag_planes_changed);
    const bool rebuild_tie = ottsel_mobile_scene_snapshot_needs_rebuild(
        g_mobile_tie_visibility_ready, g_mobile_tie_visibility_level != level,
        tie_planes_changed);
    if (rebuild_tfrag) {
      g_mobile_tfrag_visibility_ready = false;
      g_mobile_tfrag_itimes_valid = false;
    }
    if (rebuild_tie) {
      g_mobile_tie_visibility_ready = false;
      g_mobile_tie_itimes_valid = false;
    }
    build_visible_mobile_tfrag_mesh(level, candidate);
    build_visible_mobile_tie_mesh(level, candidate);
    set_mobile_tie_camera(candidate);
    set_mobile_tfrag_colors(candidate);
    set_mobile_tie_colors(candidate);
  }
  if (g_mobile_camera_levels_logged.insert(level).second) {
    lg::info("OTTSEL FR3: camera '{}' finite={} trans=({:.3f},{:.3f},{:.3f}) fog={:.3f}",
             level, finite, candidate.trans[0], candidate.trans[1], candidate.trans[2],
             candidate.fog[0]);
  }
}

// The maintained Merc2 PC renderer consumes this packet before VU1 skinning.
// Mobile has the same FR3 MercModel data, so perform the equivalent bounded
// CPU skinning here and submit real model triangles to the shared Metal
// material/camera consumer. This is native geometry composition, not a model
// fixture or a replacement actor.
struct MobileMercMatrix {
  float tmat[4][4];
  float nmat[3][4];
};

struct MobileMercFlags {
  u64 enable_mask;
  u64 ignore_alpha_mask;
  u8 effect_count;
  u8 bitflags;
};

bool capture_mobile_merc(const DmaTransfer& setup) {
  if (!g_metal || !setup.data || setup.size_bytes < 416) {
    return false;
  }
  const size_t name_len = strnlen((const char*)setup.data, 128);
  if (name_len == 0 || name_len >= 128) {
    return false;
  }
  for (size_t i = 0; i < name_len; ++i) {
    if (!std::isprint((unsigned char)setup.data[i])) {
      return false;
    }
  }
  const std::string name((const char*)setup.data, name_len);

  const tfrag3::Level* level = nullptr;
  const tfrag3::MercModel* model = nullptr;
  for (const auto& [level_name, level_ptr] : g_mobile_levels) {
    for (const auto& candidate : level_ptr->merc_data.models) {
      if (candidate.name == name) {
        level = level_ptr.get();
        model = &candidate;
        break;
      }
    }
    if (model) {
      break;
    }
  }
  if (!level || !model || level->merc_data.vertices.empty()) {
    return false;
  }
  const u32 texture_base = g_mobile_level_texture_bases.at(level);

  // Packet layout: name, VuLights, Jak1 water padding, matrix-slot string,
  // then one pointer quadword group per slot.
  constexpr size_t kMatrixSlotsOffset = 128 + 112 + 16;
  if (setup.size_bytes < kMatrixSlotsOffset + 128) {
    return false;
  }
  const u8* chain_base = setup.data - setup.data_offset;
  std::array<MobileMercMatrix, 128> matrices{};
  std::array<bool, 128> matrix_valid{};
  const u8* slots = setup.data + kMatrixSlotsOffset;
  const u8* matrix_ptrs = slots + 128;
  int slot_count = 0;
  for (; slot_count < 128 && slots[slot_count] != 0xff; ++slot_count) {
    const u8 slot = slots[slot_count];
    u32 matrix_addr = 0;
    memcpy(&matrix_addr, matrix_ptrs + slot_count * 16, sizeof(matrix_addr));
    if (slot >= matrices.size() || matrix_addr > 0x10000000u) {
      return false;
    }
    memcpy(&matrices[slot], chain_base + matrix_addr, sizeof(MobileMercMatrix));
    matrix_valid[slot] = true;
  }
  const size_t flags_offset = kMatrixSlotsOffset + 128 + slot_count * 16;
  if (flags_offset + sizeof(MobileMercFlags) > setup.size_bytes || !slot_count) {
    return false;
  }
  MobileMercFlags flags{};
  memcpy(&flags, setup.data + flags_offset, sizeof(flags));
  const u8 effect_count = std::min<u8>(flags.effect_count, model->effects.size());
  if (!effect_count) {
    return false;
  }

  std::vector<tfrag3::PreloadedVertex> vertices(level->merc_data.vertices.size());
  for (size_t vertex_index = 0; vertex_index < vertices.size(); ++vertex_index) {
    const auto& source = level->merc_data.vertices[vertex_index];
    auto& output = vertices[vertex_index];
    float px = 0.f, py = 0.f, pz = 0.f;
    float total_weight = 0.f;
    for (int influence = 0; influence < 3; ++influence) {
      const float weight = source.weights[influence];
      const u8 matrix_index = source.mats[influence];
      if (weight <= 0.f || !matrix_valid[matrix_index]) {
        continue;
      }
      const auto& matrix = matrices[matrix_index].tmat;
      const float tx = matrix[0][0] * source.x + matrix[1][0] * source.y +
                       matrix[2][0] * source.z + matrix[3][0];
      const float ty = matrix[0][1] * source.x + matrix[1][1] * source.y +
                       matrix[2][1] * source.z + matrix[3][1];
      const float tz = matrix[0][2] * source.x + matrix[1][2] * source.y +
                       matrix[2][2] * source.z + matrix[3][2];
      px -= tx * weight;
      py -= ty * weight;
      pz -= tz * weight;
      total_weight += weight;
    }
    if (total_weight == 0.f) {
      continue;
    }
    output.x = px;
    output.y = py;
    output.z = pz;
    output.s = source.st[0];
    output.t = source.st[1];
    output.color_index = 0;
  }

  std::vector<u32> indices;
  std::vector<OttselMetalTieDraw> draws;
  std::vector<bool> used_textures(level->textures.size());
  for (u32 effect_index = 0; effect_index < effect_count; ++effect_index) {
    if (!(flags.enable_mask & (u64(1) << effect_index))) {
      continue;
    }
    for (const auto& source_draw : model->effects[effect_index].all_draws) {
      if (source_draw.tree_tex_id < 0 ||
          (size_t)source_draw.tree_tex_id >= level->textures.size() ||
          source_draw.first_index + source_draw.index_count > level->merc_data.indices.size()) {
        continue;
      }
      const u32 index_offset = indices.size();
      indices.insert(indices.end(), level->merc_data.indices.begin() + source_draw.first_index,
                     level->merc_data.indices.begin() + source_draw.first_index +
                         source_draw.index_count);
      draws.push_back(
          {index_offset, source_draw.index_count,
           ottsel_mobile_scene_texture_slot(texture_base, source_draw.tree_tex_id),
           source_draw.mode.as_int()});
      used_textures[(size_t)source_draw.tree_tex_id] = true;
    }
  }
  if (indices.empty() || draws.empty()) {
    return false;
  }
  for (u32 texture_index = 0; texture_index < used_textures.size(); ++texture_index) {
    if (!used_textures[texture_index]) {
      continue;
    }
    const auto& texture = level->textures[texture_index];
    if (texture.data.size() == (size_t)texture.w * texture.h) {
      ottsel_metal_set_tie_texture(g_metal, texture_base + texture_index, texture.data.data(),
                                   texture.w, texture.h);
    }
  }
  ottsel_metal_append_merc_mesh(g_metal, vertices.data(), vertices.size(), indices.data(),
                                indices.size(), draws.data(), draws.size());
  static std::unordered_set<std::string> merc_submit_names;
  if (merc_submit_names.insert(name).second && merc_submit_names.size() <= 32) {
    lg::info("OTTSEL MERC NATIVE: model='{}' level='{}' slots={} effects={} vertices={} "
             "triangles={} draws={}",
             name, level->level_name, slot_count, effect_count, vertices.size(), indices.size() / 3,
             draws.size());
  }
  return true;
}

// Fake GS VRAM (4 MB).  The game stores every texture pre-scrambled so it can
// be uploaded to VRAM as a plain PSMCT32 transfer 128 pixels wide
// (texture.gc upload-vram-data: gs-bitbltbuf dbw=2 dbp=seg.dest/64,
// gs-trxreg rrw=128 rrh=size/128).  We replay that placement here, then
// un-swizzle with the texture's own format (download_rgba8888-style).
std::vector<u8> g_vram(4 * 1024 * 1024);

struct DirectTextureMetadata {
  u32 width = 0;
  u32 height = 0;
  u32 psm = 0;
  u32 clut_psm = 0;
  u32 clut_addr = 0;
};

struct DirectRelocatedTexture {
  u32 width = 0;
  u32 height = 0;
  std::vector<u8> rgba;
};

// Source texture-page descriptors survive long enough for the PC_PORT font
// relocation callback to identify the source image by its GS word address.
std::unordered_map<u32, DirectTextureMetadata> g_direct_texture_metadata;
std::unordered_map<u64, DirectRelocatedTexture> g_direct_relocated_textures;

u64 direct_texture_cache_key(u32 destination, u32 psm) {
  return (u64(destination) << 8) | (psm & 0x3f);
}

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
  if ((psm == 0x24 || psm == 0x2c) && (clut_psm == 0 || clut_psm == 2)) {
    // PSMT4HL/PSMT4HH address the high byte of a PSMCT32 word.  HL uses the
    // low nibble and HH the high nibble; both use the ordinary 16-entry CSM1
    // palette layout for the resulting index.
    int read_width = 64 * goal_tex_width;
    for (u32 y = 0; y < h; y++) {
      for (u32 x = 0; x < w; x++) {
        u32 texel_addr = psmct32_addr(x, y, read_width) + vram_addr * 256;
        u8 packed = get8(texel_addr + 3);
        u8 value = (psm == 0x24) ? (packed & 0x0f) : (packed >> 4);
        u32 clut_addr = psmct32_addr(value & 0x7, value >> 3, 64) + clut_vram_addr * 256;
        u32 clut_value = (clut_psm == 0) ? get32(clut_addr) : (u32)rgba16_to_rgba32(get16(clut_addr));
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

// A ROM-free 2x2 PSMT4HL fixture.  The indexed texels and four-entry CSM1
// palette are written to generated VRAM, expanded through the same decoder
// used by the Direct path, and only then uploaded as RGBA8 to Metal.
std::array<u8, 16> make_generated_direct_clut_image() {
  constexpr u32 texture_base = 0x3c00;
  constexpr u32 clut_base = 0x3d00;
  constexpr u32 read_width = 64;
  const std::array<u8, 4> indices = {0, 1, 2, 3};
  const std::array<u32, 4> palette = {
      0xff0000ff, 0xff00ff00, 0xffff0000, 0xffffffff};
  for (u32 y = 0; y < 2; y++) {
    for (u32 x = 0; x < 2; x++) {
      const u32 addr = psmct32_addr(x, y, read_width) + texture_base * 256;
      g_vram.at(addr + 3) = indices[y * 2 + x];
    }
  }
  for (u32 i = 0; i < palette.size(); i++) {
    const u32 addr = psmct32_addr(i, 0, 64) + clut_base * 256;
    memcpy(g_vram.data() + addr, &palette[i], sizeof(u32));
  }
  std::array<u8, 16> rgba{};
  const bool decoded = download_texture_rgba8888(rgba.data(), texture_base, 1, 2, 2, 0x24, 0,
                                                 clut_base);
  if (!decoded) {
    rgba.fill(0);
  }
  return rgba;
}

// Decode the texture named by the live Direct TEX0 from the retained GS-VRAM
// mirror.  The mirror is populated by the existing texture-page upload path;
// return an empty image when this title phase has not uploaded the referenced
// page yet so the ROM-free generated D3 discriminator remains deterministic.
std::vector<u8> decode_direct_vram_texture(u64 tex0_value,
                                            u32& out_width,
                                            u32& out_height,
                                            bool& used_vram) {
  used_vram = false;
  out_width = 0;
  out_height = 0;
  const GsTex0 tex0(tex0_value);
  const u32 width = 1u << tex0.tw();
  const u32 height = 1u << tex0.th();
  if (width == 0 || height == 0 || width > 2048 || height > 2048) {
    return {};
  }
  std::vector<u8> rgba((size_t)width * height * 4, 0);
  const bool decoded = download_texture_rgba8888(
      rgba.data(), tex0.tbp0(), std::max(1u, width / 64), width, height,
      (u32)tex0.psm(), tex0.cpsm(), tex0.cbp());
  if (!decoded || std::none_of(rgba.begin(), rgba.end(), [](u8 value) { return value != 0; })) {
    return {};
  }
  out_width = width;
  out_height = height;
  used_vram = true;
  return rgba;
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
static std::mutex g_ios_vsync_mutex;
static std::condition_variable g_ios_vsync_cv;
static u64 g_ios_present_epoch = 0;
static bool g_ios_vsync_stopping = false;

extern "C" void ottsel_metal_gfx_signal_vsync() {
  {
    std::lock_guard<std::mutex> lock(g_ios_vsync_mutex);
    ++g_ios_present_epoch;
  }
  g_ios_vsync_cv.notify_all();
}

extern "C" void ottsel_metal_gfx_stop_vsync_waiters() {
  {
    std::lock_guard<std::mutex> lock(g_ios_vsync_mutex);
    g_ios_vsync_stopping = true;
  }
  g_ios_vsync_cv.notify_all();
}

void ottsel_metal_gfx_note_vsync() {
  static u32 g_mobile_vsync_no = 0;
  static bool trace_active = false;
  const std::string trace_path = ottsel_ios_writable_dir() + "ottsel-trace-mobile-frame-boundary";
  if (!trace_active && access(trace_path.c_str(), F_OK) == 0) {
    unlink(trace_path.c_str());
    trace_active = true;
    lg::info("OTTSEL FRAME: boundary trace accepted at vsync={} chain={}", g_mobile_vsync_no,
             g_mobile_chain_no);
  }
  ++g_mobile_vsync_no;
  if (trace_active && g_mobile_vsync_no <= 8) {
    lg::info("OTTSEL FRAME: vsync={} chain={}", g_mobile_vsync_no, g_mobile_chain_no);
  }
  if (trace_active && g_mobile_vsync_no == 8) {
    trace_active = false;
    lg::info("OTTSEL FRAME: boundary trace complete");
  }
}

u32 gfx_vsync() {
  std::unique_lock<std::mutex> lock(g_ios_vsync_mutex);
  const u64 observed_epoch = g_ios_present_epoch;
  g_ios_vsync_cv.wait(lock, [&] {
    return g_ios_vsync_stopping || g_ios_present_epoch != observed_epoch;
  });
  if (g_ios_vsync_stopping) {
    return 0;
  }
  const u32 parity = (u32)(g_ios_present_epoch & 1);
  lock.unlock();
  ottsel_metal_gfx_note_vsync();
  return parity;
}
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
    static u32 texture_samples_logged = 0;
    if (psm == 0x13 && texture_samples_logged < 16) {
      ++texture_samples_logged;
      const u8* first = tex.rgba.data();
      const size_t middle = ((size_t)(h / 2) * w + (w / 2)) * 4;
      const u8* mid = tex.rgba.data() + middle;
      lg::info("OTTSEL TEX: tbp=0x{:x} {}x{} psm=0x{:x} cbp=0x{:x} first={:02x}{:02x}{:02x}{:02x} mid={:02x}{:02x}{:02x}{:02x}",
               tbp, w, h, psm, cbp, first[0], first[1], first[2], first[3], mid[0], mid[1],
               mid[2], mid[3]);
    }
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

  void sprite(const OttselVertex& a,
              const OttselVertex& b,
              bool tme,
              bool fst,
              bool abe,
              u8 ta0) {
    OttselVertex top_right = b;
    OttselVertex bottom_left = a;
    top_right.y = a.y;
    bottom_left.y = b.y;
    if (fst) {
      top_right.uv_v = a.uv_v;
      bottom_left.uv_u = a.uv_u;
    } else {
      top_right.t = a.t;
      bottom_left.s = a.s;
    }
    tri(a, top_right, b, tme, fst, abe, ta0);
    tri(a, b, bottom_left, tme, fst, abe, ta0);
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
  std::vector<ottsel::DirectIrEvent> ordered_ir;
  u32 direct_min_x = UINT32_MAX;
  u32 direct_min_y = UINT32_MAX;
  u32 direct_max_x = 0;
  u32 direct_max_y = 0;
  float direct_min_s = 0.f;
  float direct_min_t = 0.f;
  float direct_max_s = 1.f;
  float direct_max_t = 1.f;
  ottsel::DirectIrStateSnapshot last_direct_snapshot;
  bool have_direct_snapshot = false;
  bool direct_scissor_seen = false;

  void record_ir(ottsel::DirectIrKind kind, u64 value = 0) {
    if (g_mobile_direct_trace.active && g_mobile_direct_trace.decoding_direct &&
        ordered_ir.size() < 4096) {
      ordered_ir.push_back({kind, value});
    }
    if (kind == ottsel::DirectIrKind::Vertex) {
      const u32 x = (u32)(value & 0xffff);
      const u32 y = (u32)((value >> 32) & 0xffff);
      direct_min_x = std::min(direct_min_x, x);
      direct_min_y = std::min(direct_min_y, y);
      direct_max_x = std::max(direct_max_x, x);
      direct_max_y = std::max(direct_max_y, y);
    }
  }

  void reset_direct_geometry() {
    direct_min_x = UINT32_MAX;
    direct_min_y = UINT32_MAX;
    direct_max_x = 0;
    direct_max_y = 0;
    direct_min_s = 0.f;
    direct_min_t = 0.f;
    direct_max_s = 1.f;
    direct_max_t = 1.f;
  }

  void record_state_snapshot() {
    if (!g_mobile_direct_trace.active || !g_mobile_direct_trace.decoding_direct ||
        ordered_ir.size() >= 4096) {
      return;
    }
    ottsel::DirectIrStateSnapshot snapshot;
    snapshot.prim = st.prim;
    snapshot.tex0 = st.tex0;
    snapshot.tex1 = st.tex1;
    snapshot.alpha = st.alpha;
    snapshot.zbuf = st.zbuf;
    snapshot.test = st.test;
    snapshot.clamp = st.clamp;
    snapshot.frame = st.frame;
    snapshot.xyoffset = st.xyoffset;
    snapshot.scissor = st.scissor;
    snapshot.texa = st.texa;
    memcpy(snapshot.st, st.st, sizeof(snapshot.st));
    memcpy(snapshot.rgba, st.rgba, sizeof(snapshot.rgba));
    snapshot.uv_u = st.uv_u;
    snapshot.uv_v = st.uv_v;
    snapshot.flags = (st.st_valid ? 1 : 0) | (st.rgba_valid ? 2 : 0) |
                     (st.uv_valid ? 4 : 0) | (direct_scissor_seen ? 8 : 0);
    last_direct_snapshot = snapshot;
    have_direct_snapshot = true;
    ordered_ir.push_back({ottsel::DirectIrKind::StateSnapshot, 0, snapshot});
  }

  void record_boundary(ottsel::DirectIrKind kind, u64 value) {
    if (g_mobile_direct_trace.active && ordered_ir.size() < 4096) {
      ordered_ir.push_back({kind, value});
    }
  }

  void record_error(ottsel::DirectIrError error, u64 detail = 0) {
    if (g_mobile_direct_trace.active && g_mobile_direct_trace.decoding_direct &&
        ordered_ir.size() < 4096) {
      ordered_ir.push_back({ottsel::DirectIrKind::Error,
                            (u64(error) << 32) | (detail & 0xffffffffu)});
    }
  }

  void on_prim_start(u64 prim) {
    st.prim = prim;
    vert_count = 0;
    record_ir(ottsel::DirectIrKind::Prim, prim);
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
    if (g_mobile_direct_trace.active && g_mobile_direct_trace.decoding_direct) {
      if (gp.kind() == GsPrim::Kind::SPRITE) {
        g_mobile_direct_trace.sprites++;
      } else if (gp.kind() == GsPrim::Kind::TRI) {
        g_mobile_direct_trace.triangles++;
      }
    }
    if (rst && gp.kind() == GsPrim::Kind::SPRITE && vert_count >= 2) {
      GsTexa gta(st.texa);
      rst->load_tex(gt.tbp0(), gt.tw(), gt.th(), (u32)gt.psm(), gt.cbp(), gt.cpsm());
      rst->sprite(verts[0], verts[1], gp.tme(), gp.fst(), gp.abe(), gta.ta0());
    } else if (rst && vert_count >= 3) {
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
    if (g_mobile_direct_trace.active && g_mobile_direct_trace.decoding_direct) {
      g_mobile_direct_trace.strips++;
    }
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
    if (v.has_st) {
      if (direct_min_s == 0.f && direct_max_s == 1.f) {
        direct_min_s = v.s;
        direct_max_s = v.s;
        direct_min_t = v.t;
        direct_max_t = v.t;
      } else {
        direct_min_s = std::min(direct_min_s, v.s);
        direct_min_t = std::min(direct_min_t, v.t);
        direct_max_s = std::max(direct_max_s, v.s);
        direct_max_t = std::max(direct_max_t, v.t);
      }
    }
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
        record_ir(ottsel::DirectIrKind::Tex0, value);
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
        direct_scissor_seen = true;
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
      case GsRegisterAddress::FOGCOL:
        update_mobile_fog_color(value);
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
    if (g_mobile_direct_trace.active && g_mobile_direct_trace.decoding_direct) {
      g_mobile_direct_trace.gif_tags++;
      switch (tag.flg()) {
        case GifTag::Format::PACKED:
          g_mobile_direct_trace.packed_tags++;
          break;
        case GifTag::Format::REGLIST:
          g_mobile_direct_trace.reglist_tags++;
          break;
        case GifTag::Format::IMAGE:
          g_mobile_direct_trace.image_tags++;
          break;
        default:
          break;
      }
    }
    u32 nreg = tag.nreg();
    if (nreg > 16) {
      dec.record_error(ottsel::DirectIrError::MalformedTag, nreg);
      break;
    }
    u64 payload_bytes = 0;
    switch (tag.flg()) {
      case GifTag::Format::PACKED:
        payload_bytes = u64(tag.nloop()) * nreg * 16;
        break;
      case GifTag::Format::REGLIST:
        payload_bytes = u64(tag.nloop()) * nreg * 8;
        break;
      case GifTag::Format::IMAGE:
        payload_bytes = u64(tag.nloop()) * 16;
        break;
      default:
        dec.record_error(ottsel::DirectIrError::MalformedTag, (u64)tag.flg());
        break;
    }
    if (payload_bytes > size - offset) {
      dec.record_error(ottsel::DirectIrError::OutOfBounds, payload_bytes);
      break;
    }
    GifTag::RegisterDescriptor reg_desc[16];
    for (u32 i = 0; i < nreg; i++) {
      reg_desc[i] = tag.reg(i);
    }
    const bool is_d0_glyph = g_mobile_direct_trace.active &&
                             g_mobile_direct_trace.decoding_direct && tag.nloop() == 1 &&
                             tag.pre() && tag.prim() == 0x5c && tag.nreg() == 13;
    const size_t d0_ir_start = dec.ordered_ir.size();
    if (is_d0_glyph && g_mobile_direct_trace.glyph_packet_samples < 8) {
      ++g_mobile_direct_trace.glyph_packet_samples;
      lg::info("OTTSEL MOBILE DIRECT: glyph candidate sample={} eop={} bytes={}",
               g_mobile_direct_trace.glyph_packet_samples, (int)tag.eop(), size);
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
              u64 raw = 0;
              memcpy(&raw, rec, sizeof(raw));
              dec.record_ir(ottsel::DirectIrKind::St, raw);
              memcpy(&dec.st.st[0], rec, 4);
              memcpy(&dec.st.st[1], rec + 4, 4);
              memcpy(&dec.st.st[2], rec + 8, 4);
              dec.st.st_valid = true;
            } break;
            case GifTag::RegisterDescriptor::RGBAQ: {
              u64 raw = 0;
              memcpy(&raw, rec, sizeof(raw));
              dec.record_ir(ottsel::DirectIrKind::Rgbaq, raw);
              // PACKED RGBAQ is a 128-bit GIF record whose four color
              // components occupy the low byte of each 32-bit lane.  The
              // desktop DirectRenderer consumes the same wire layout.
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
              u64 raw = 0;
              memcpy(&raw, rec, sizeof(raw));
              dec.record_ir(ottsel::DirectIrKind::Vertex, raw);
              // Match the desktop DirectRenderer's PACKED wire format: X
              // and Y occupy their own words and Z/F/ADC occupy the upper
              // qword.  This is distinct from the REGLIST representation.
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
              if (g_mobile_direct_trace.active &&
                  g_mobile_direct_trace.unhandled_packed_registers < 16) {
                lg::info("OTTSEL MOBILE DIRECT: unhandled packed GIF register={} chain={}",
                         (u32)reg_desc[r], dec.chain_no);
                ++g_mobile_direct_trace.unhandled_packed_registers;
              }
              dec.record_error(ottsel::DirectIrError::UnsupportedRegister,
                               (u64)reg_desc[r]);
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
              dec.record_error(ottsel::DirectIrError::UnsupportedRegister,
                               (u64)reg_desc[r]);
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
      if (is_d0_glyph && g_mobile_direct_trace.glyph_packet_samples <= 8) {
        std::string events;
        for (size_t i = d0_ir_start; i < dec.ordered_ir.size(); ++i) {
          if (!events.empty()) {
            events += ",";
          }
          events += ottsel::direct_ir_kind_name(dec.ordered_ir[i].kind);
        }
        lg::info("OTTSEL MOBILE DIRECT IR: glyph sample={} events={}",
                 g_mobile_direct_trace.glyph_packet_samples, events);
      }
      break;
    }
  }
}

// Decode one transfer: if its VIF codes say DIRECT, walk VIF words + GIF data
// like the reference DirectRenderer::render_vif.
void decode_transfer(const DmaTransfer& t, OttselGifDecoder& dec) {
  auto log_ordered_ir = [&](size_t start) {
    if (!g_mobile_direct_trace.active || g_mobile_direct_trace.font_packet_samples == 0 ||
        g_mobile_direct_trace.font_packet_samples > 8 || g_mobile_direct_trace.glyph_ir_logged ||
        start >= dec.ordered_ir.size()) {
      return;
    }
    std::string events;
    for (size_t i = start; i < dec.ordered_ir.size(); ++i) {
      if (!events.empty()) {
        events += ",";
      }
      events += ottsel::direct_ir_kind_name(dec.ordered_ir[i].kind);
    }
    lg::info("OTTSEL MOBILE DIRECT IR: qwc14 sample={} events={}",
             g_mobile_direct_trace.font_packet_samples, events);
    g_mobile_direct_trace.glyph_ir_logged = true;
  };
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
    const u32 bytes = std::min(gif_qwc * 16, t.size_bytes);
    if (g_mobile_direct_trace.active && gif_qwc == 14 &&
        g_mobile_direct_trace.font_packet_samples < 8 && bytes >= 32) {
      const GifTag font_tag(t.data);
      lg::info("OTTSEL MOBILE DIRECT: qwc14 sample={} nloop={} nreg={} pre={} prim=0x{:x} "
               "tag={:016x}/{:016x}",
               ++g_mobile_direct_trace.font_packet_samples, font_tag.nloop(), font_tag.nreg(),
               (int)font_tag.pre(), font_tag.prim(), *(const u64*)t.data,
               *(const u64*)(t.data + 8));
    }
    if (g_mobile_direct_trace.active) {
      g_mobile_direct_trace.direct_transfers++;
      g_mobile_direct_trace.direct_bytes += bytes;
    }
    const bool old_direct_context = g_mobile_direct_trace.decoding_direct;
    const size_t ir_start = dec.ordered_ir.size();
    g_mobile_direct_trace.decoding_direct = true;
    decode_gif_packets(t.data, bytes, dec);
    dec.record_state_snapshot();
    dec.record_boundary(ottsel::DirectIrKind::Flush,
                       u64(ottsel::DirectIrFlushReason::TransferEnd));
    dec.record_ir(ottsel::DirectIrKind::TransferEnd, bytes / 16);
    g_mobile_direct_trace.decoding_direct = old_direct_context;
    log_ordered_ir(ir_start);
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
        if (g_mobile_direct_trace.active) {
          g_mobile_direct_trace.direct_transfers++;
          g_mobile_direct_trace.direct_bytes += sz;
        }
        const bool old_direct_context = g_mobile_direct_trace.decoding_direct;
        const size_t ir_start = dec.ordered_ir.size();
        g_mobile_direct_trace.decoding_direct = true;
        decode_gif_packets(t.data + off, sz, dec);
        dec.record_state_snapshot();
        dec.record_boundary(ottsel::DirectIrKind::Flush,
                           u64(ottsel::DirectIrFlushReason::TransferEnd));
        dec.record_ir(ottsel::DirectIrKind::TransferEnd, sz / 16);
        g_mobile_direct_trace.decoding_direct = old_direct_context;
        log_ordered_ir(ir_start);
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

// Jak 1's PC path deliberately omits Sprite3 VU microcode; the desktop
// renderer consumes these same input records on the CPU.
struct MobileSpriteVec4 {
  float x, y, z, w;
};

struct MobileSpriteFrameJak1 {
  MobileSpriteVec4 xy[8];
  MobileSpriteVec4 st[4];
  MobileSpriteVec4 xyz[4];
  MobileSpriteVec4 hmge_scale;
  float pfog0, deg_to_rad, min_scale, inv_area;
  GifTag adgif_giftag;
  GifTag sprite_2d_giftag;
  GifTag sprite_2d_giftag2;
  MobileSpriteVec4 sincos[5];
  MobileSpriteVec4 basis_x;
  MobileSpriteVec4 basis_y;
  GifTag sprite_3d_giftag;
  AdGifData screen_shader;
  GifTag clipped_giftag;
  MobileSpriteVec4 inv_hmge_scale;
  MobileSpriteVec4 stq_offset;
  MobileSpriteVec4 stq_scale;
  MobileSpriteVec4 rgba_plain;
  GifTag warp_giftag;
  float fog_min, fog_max, max_scale, bonus;
};
static_assert(sizeof(MobileSpriteFrameJak1) == 0x290, "Jak 1 Sprite3 frame layout");

struct MobileSpriteMatrix {
  MobileSpriteVec4 camera[4];
  MobileSpriteVec4 hvdf;
};
static_assert(sizeof(MobileSpriteMatrix) == 5 * 16, "Sprite3 matrix layout");

// Jak 1 HUD Sprite3 uploads a separate 80-qword matrix block at the same VU
// address as the world matrix. Keep it distinct so phase routing cannot feed
// HUD records through the world camera consumer.
struct MobileSpriteHudMatrix {
  MobileSpriteVec4 matrix[4];
  MobileSpriteVec4 hvdf;
  MobileSpriteVec4 user_hvdf[75];
};
static_assert(sizeof(MobileSpriteHudMatrix) == 0x500, "Jak 1 HUD Sprite3 matrix layout");

static u64 ottsel_sprite_trace_hash(const void* data, size_t size) {
  const auto* bytes = static_cast<const u8*>(data);
  u64 hash = 1469598103934665603ull;
  for (size_t i = 0; i < size; ++i) {
    hash ^= bytes[i];
    hash *= 1099511628211ull;
  }
  return hash;
}

static void log_mobile_sprite_texture_identity(const AdGifData& adgif, u32 chain_no,
                                               u32 group_no, u32 sprite_count) {
  const GsTex0 tex(adgif.tex0_data);
  if (!ottsel::sprite3_uses_texture(adgif.tex0_data) || tex.tbp0() == 0) {
    return;
  }
  const u32 width = 1u << tex.tw();
  const u32 height = 1u << tex.th();
  if (width > 2048 || height > 2048) {
    return;
  }
  std::vector<u8> rgba((size_t)width * height * 4);
  if (!download_texture_rgba8888(rgba.data(), tex.tbp0(), std::max(1u, width / 64), width,
                                  height, (u32)tex.psm(), tex.cpsm(), tex.cbp())) {
    lg::warn("OTTSEL SPRITE IDENTITY: mobile decode failed chain={} group={} tbp=0x{:x}",
             chain_no, group_no, tex.tbp0());
    return;
  }
  u8 alpha_max = 0;
  u32 nonzero_alpha = 0;
  for (size_t i = 3; i < rgba.size(); i += 4) {
    alpha_max = std::max(alpha_max, rgba[i]);
    nonzero_alpha += rgba[i] != 0;
  }
  lg::info("OTTSEL SPRITE IDENTITY: mobile chain={} group={} sprites={} tbp=0x{:x} "
           "tex0=0x{:016x} psm={} size={}x{} rgba-hash=0x{:x} alpha-max={} nonzero-alpha={}",
           chain_no, group_no, sprite_count, tex.tbp0(), adgif.tex0_data, (u32)tex.psm(), width,
           height, ottsel_sprite_trace_hash(rgba.data(), rgba.size()), alpha_max, nonzero_alpha);
}

static void ottsel_sprite_trace_hash_bytes(u64& hash, const void* data, size_t size) {
  const auto* bytes = static_cast<const u8*>(data);
  for (size_t i = 0; i < size; ++i) {
    hash ^= bytes[i];
    hash *= 1099511628211ull;
  }
}

static u64 ottsel_sprite_camera_frame_hash(const MobileSpriteFrameJak1& frame) {
  u64 hash = 1469598103934665603ull;
  ottsel_sprite_trace_hash_bytes(hash, &frame.hmge_scale, sizeof(frame.hmge_scale));
  ottsel_sprite_trace_hash_bytes(hash, &frame.pfog0, sizeof(frame.pfog0));
  ottsel_sprite_trace_hash_bytes(hash, &frame.deg_to_rad, sizeof(frame.deg_to_rad));
  ottsel_sprite_trace_hash_bytes(hash, &frame.min_scale, sizeof(frame.min_scale));
  ottsel_sprite_trace_hash_bytes(hash, &frame.inv_area, sizeof(frame.inv_area));
  ottsel_sprite_trace_hash_bytes(hash, &frame.basis_x, sizeof(frame.basis_x));
  ottsel_sprite_trace_hash_bytes(hash, &frame.basis_y, sizeof(frame.basis_y));
  ottsel_sprite_trace_hash_bytes(hash, &frame.inv_hmge_scale, sizeof(frame.inv_hmge_scale));
  ottsel_sprite_trace_hash_bytes(hash, &frame.fog_min, sizeof(frame.fog_min));
  ottsel_sprite_trace_hash_bytes(hash, &frame.fog_max, sizeof(frame.fog_max));
  return hash;
}

struct MobileSpriteVec2d {
  MobileSpriteVec4 xyz_sx;
  MobileSpriteVec4 flag_rot_sy;
  MobileSpriteVec4 rgba;
};
static_assert(sizeof(MobileSpriteVec2d) == 48, "Sprite3 vector layout");

static MobileSpriteVec4 sprite_add(const MobileSpriteVec4& a, const MobileSpriteVec4& b) {
  return {a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w};
}

static MobileSpriteVec4 sprite_scale(const MobileSpriteVec4& a, float s) {
  return {a.x * s, a.y * s, a.z * s, a.w * s};
}

static MobileSpriteVec4 sprite_matrix_transform(const MobileSpriteVec4 matrix[4],
                                                 const MobileSpriteVec4& p) {
  return sprite_add(matrix[3],
                    sprite_add(sprite_scale(matrix[0], p.x),
                               sprite_add(sprite_scale(matrix[1], p.y),
                                          sprite_scale(matrix[2], p.z))));
}

static u8 sprite_color(float value) {
  return (u8)std::clamp((int)value, 0, 255);
}

static bool g_mobile_sprite_parser_trace = false;
static bool g_mobile_sprite_parser_trace_logged = false;
static bool g_mobile_sprite_source_boundary_trace = false;
static u32 g_mobile_sprite_source_boundary_count = 0;
static u32 g_mobile_sprite_3d_trace_groups = 0;
static bool g_mobile_sprite_3d_trace_requested = false;

// Sprite3 traffic is emitted during title and level transitions. Diagnostic
// windows must not consume their one-shot trigger on title traffic when the
// intended comparison is Village1.
static bool mobile_sprite_village1_phase() {
  return g_mobile_camera_level == "village1";
}

static OttselVertex sprite_raster_vertex(const MobileSpriteVec4& transformed,
                                         const MobileSpriteVec4& st,
                                         const MobileSpriteVec4& color,
                                         OttselRaster& raster) {
  // The reference Sprite3 shader multiplies xyz by w before the GPU
  // perspective divide. The CPU path is already producing the post-divide
  // coordinate here; retaining w sends large sprites far off-screen and
  // produces the observed triangular corruption.
  const float ndc_x = ottsel::sprite3_post_divide_component(transformed.x, transformed.w,
                                                            2048.f, 256.f);
  const float ndc_y = ottsel::sprite3_post_divide_component(transformed.y, transformed.w,
                                                            2048.f, -128.f);
  const float pixel_x = (ndc_x + 1.f) * 0.5f * raster.fb_w;
  const float pixel_y = (1.f - ndc_y) * 0.5f * raster.fb_h;
  const float gx = std::clamp(pixel_x / raster.fb_w - raster.x_off, 0.f, 1.f);
  const float gy = std::clamp(1.f - pixel_y / raster.fb_h - raster.y_off, 0.f, 1.f);
  OttselVertex out;
  out.x = (u32)(gx * UINT32_MAX);
  out.y = (u32)(gy * UINT32_MAX);
  out.s = st.x;
  out.t = st.y;
  out.q = 1.f;
  out.has_st = true;
  out.r = sprite_color(color.x);
  out.g = sprite_color(color.y);
  out.b = sprite_color(color.z);
  out.a = sprite_color(color.w);
  return out;
}

static std::array<float, 2> sprite_shader_clip_vertex(const MobileSpriteVec4& transformed) {
  // The desktop shader writes homogeneous gl_Position and the GL pipeline
  // performs the perspective divide. Metal's native Sprite3 vertex carries
  // only x/y (implicit w=1), so upload the post-divide coordinates here.
  const float clip_x = (transformed.x - 2048.f) / 256.f;
  const float clip_y = ((transformed.y - 2048.f) / -128.f) * (512.f / 448.f);
  return {clip_x, clip_y};
}

static bool sprite_world_shader_clips(const MobileSpriteFrameJak1& frame,
                                      const MobileSpriteMatrix& matrix,
                                      const MobileSpriteVec2d& vector,
                                      std::array<float, 2> clips[4],
                                      float* q_out,
                                      float* sx_out,
                                      float* sy_out) {
  const MobileSpriteVec4 camera_transformed =
      sprite_matrix_transform(matrix.camera, vector.xyz_sx);
  if (!std::isfinite(camera_transformed.w) || camera_transformed.w == 0.f) {
    return false;
  }
  const float q = frame.pfog0 / camera_transformed.w;
  if (!std::isfinite(q)) {
    return false;
  }
  MobileSpriteVec4 base = camera_transformed;
  base.x *= q;
  base.y *= q;
  base.z *= q;
  base = sprite_add(base, matrix.hvdf);
  base.w = std::max(base.w, frame.fog_min);
  const float sx = std::clamp(vector.xyz_sx.w * q, frame.min_scale, frame.max_scale);
  const float sy = std::clamp(vector.flag_rot_sy.w * q, frame.min_scale, frame.max_scale);
  const float radians = vector.flag_rot_sy.z * frame.deg_to_rad;
  const float sine = std::sin(radians);
  const float cosine = std::cos(radians);
  const MobileSpriteVec4 x_basis = sprite_scale(
      sprite_add(sprite_scale(frame.basis_x, cosine), sprite_scale(frame.basis_y, -sine)), sx);
  const MobileSpriteVec4 y_basis = sprite_scale(
      sprite_add(sprite_scale(frame.basis_x, sine), sprite_scale(frame.basis_y, cosine)), sy);
  const u32 flags = *(const u32*)&vector.flag_rot_sy.x;
  for (u32 vertex = 0; vertex < 4; ++vertex) {
    const MobileSpriteVec4& offset = frame.xy[vertex + (flags & 15u)];
    const MobileSpriteVec4 transformed =
        sprite_add(base, sprite_add(sprite_scale(x_basis, offset.x),
                                    sprite_scale(y_basis, offset.y)));
    clips[vertex] = sprite_shader_clip_vertex(transformed);
  }
  if (q_out) *q_out = q;
  if (sx_out) *sx_out = sx;
  if (sy_out) *sy_out = sy;
  return true;
}

static u32 render_mobile_sprite_group0(const MobileSpriteFrameJak1& frame,
                                       const MobileSpriteMatrix& matrix,
                                       const MobileSpriteVec2d* vectors,
                                       const AdGifData* adgifs,
                                       u32 count,
                                       OttselRaster& raster) {
  u32 drawn = 0;
  if (g_mobile_sprite_parser_trace && !g_mobile_sprite_parser_trace_logged) {
    g_mobile_sprite_parser_trace_logged = true;
    lg::info("OTTSEL SPRITE TRACE: group count={} pfog0={} scale=({}, {}) camera-t=({}, {}, {}, {}) "
             "hvdf=({}, {}, {}, {}) first=({}, {}, {}, {})",
             count, frame.pfog0, frame.min_scale, frame.max_scale, matrix.camera[3].x,
             matrix.camera[3].y, matrix.camera[3].z, matrix.camera[3].w, matrix.hvdf.x,
             matrix.hvdf.y, matrix.hvdf.z, matrix.hvdf.w, vectors[0].xyz_sx.x,
             vectors[0].xyz_sx.y, vectors[0].xyz_sx.z, vectors[0].xyz_sx.w);
  }
  for (u32 index = 0; index < count; ++index) {
    const auto& vector = vectors[index];
    const MobileSpriteVec4 camera_transformed =
        sprite_matrix_transform(matrix.camera, vector.xyz_sx);
    const bool color_only_sprite = !ottsel::sprite3_uses_texture(adgifs[index].tex0_data);
    // This bucket is MSCAL 3 (desktop Sprites2dGrp0), whose shader keeps the
    // camera transform sign for its 2D path. The 3D shader's negation is not
    // applicable here.
    const float denominator = camera_transformed.w;
    if (g_mobile_sprite_parser_trace && index == 0) {
      lg::info("OTTSEL SPRITE TRACE: first camera=({}, {}, {}, {}) 2d-w={} "
               "3d-negated-w={} finite={} xyz=({}, {}, {}, {})",
               camera_transformed.x, camera_transformed.y, camera_transformed.z,
               camera_transformed.w, denominator, -camera_transformed.w,
               std::isfinite(denominator), vector.xyz_sx.x, vector.xyz_sx.y, vector.xyz_sx.z,
               vector.xyz_sx.w);
    }
    if (!std::isfinite(denominator) || denominator == 0.f) {
      static u32 color_only_transform_rejects = 0;
      if (g_mobile_native_sprite_color_only_probe && color_only_sprite &&
          color_only_transform_rejects < 16) {
        ++color_only_transform_rejects;
        lg::warn("OTTSEL SPRITE COLOR-ONLY TRANSFORM: reject={} index={} tex0=0x{:016x} "
                 "vector=({}, {}, {}, {}) camera=({}, {}, {}, {}) pfog0={} denominator={} "
                 "finite={}",
                 color_only_transform_rejects, index, adgifs[index].tex0_data, vector.xyz_sx.x,
                 vector.xyz_sx.y, vector.xyz_sx.z, vector.xyz_sx.w, camera_transformed.x,
                 camera_transformed.y, camera_transformed.z, camera_transformed.w, frame.pfog0,
                 denominator, std::isfinite(denominator));
      }
      continue;
    }
    const float q = frame.pfog0 / denominator;
    if (!std::isfinite(q)) {
      static u32 color_only_q_rejects = 0;
      if (g_mobile_native_sprite_color_only_probe && color_only_sprite &&
          color_only_q_rejects < 16) {
        ++color_only_q_rejects;
        lg::warn("OTTSEL SPRITE COLOR-ONLY Q: reject={} index={} tex0=0x{:016x} "
                 "pfog0={} denominator={} q={}",
                 color_only_q_rejects, index, adgifs[index].tex0_data, frame.pfog0, denominator, q);
      }
      continue;
    }

    MobileSpriteVec4 base = camera_transformed;
    base.x *= q;
    base.y *= q;
    base.z *= q;
    base = sprite_add(base, matrix.hvdf);
    base.w = std::max(base.w, frame.fog_min);

    const float sx = std::clamp(vector.xyz_sx.w * q, frame.min_scale, frame.max_scale);
    const float sy = std::clamp(vector.flag_rot_sy.w * q, frame.min_scale, frame.max_scale);
    if (g_mobile_sprite_parser_trace && index == 0) {
      lg::info("OTTSEL SPRITE TRACE: 2d q={} base=({}, {}, {}, {}) fog-min={} "
               "scale=({}, {}) raw-scale=({}, {}) basis-x=({}, {}, {}, {}) "
               "basis-y=({}, {}, {}, {}) xy0=({}, {}, {}, {})",
               q, base.x, base.y, base.z, base.w, frame.fog_min, sx, sy,
               vector.xyz_sx.w * q, vector.flag_rot_sy.w * q, frame.basis_x.x,
               frame.basis_x.y, frame.basis_x.z, frame.basis_x.w, frame.basis_y.x,
               frame.basis_y.y, frame.basis_y.z, frame.basis_y.w, frame.xy[0].x,
               frame.xy[0].y, frame.xy[0].z, frame.xy[0].w);
    }
    const float radians = vector.flag_rot_sy.z * frame.deg_to_rad;
    const float sine = std::sin(radians);
    const float cosine = std::cos(radians);
    const MobileSpriteVec4 x_basis = sprite_scale(
        sprite_add(sprite_scale(frame.basis_x, cosine), sprite_scale(frame.basis_y, -sine)), sx);
    const MobileSpriteVec4 y_basis = sprite_scale(
        sprite_add(sprite_scale(frame.basis_x, sine), sprite_scale(frame.basis_y, cosine)), sy);
    const u32 flags = *(const u32*)&vector.flag_rot_sy.x;

    OttselVertex vertices[4];
    std::array<float, 2> shader_clip[4];
    for (u32 vertex = 0; vertex < 4; ++vertex) {
      const MobileSpriteVec4& offset = frame.xy[vertex + (flags & 15u)];
      const MobileSpriteVec4 transformed =
          sprite_add(base, sprite_add(sprite_scale(x_basis, offset.x),
                                      sprite_scale(y_basis, offset.y)));
      vertices[vertex] = sprite_raster_vertex(transformed, frame.st[vertex], vector.rgba, raster);
      shader_clip[vertex] = sprite_shader_clip_vertex(transformed);
    }

    // The CPU raster call below remains diagnostic. The first validated
    // post-Village1 World2D group is now a normal product Metal upload; the
    // resource identity comes from the live phase/shape contract, while TBP
    // remains whatever the current source-side lookup produced.
    bool native_sprite_consumed = false;
    if (!g_mobile_native_sprite_probe_requested) {
      const std::string sprite_probe_path =
          ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-metal";
      const std::string color_only_probe_path =
          ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-metal-color-only";
      if (access(color_only_probe_path.c_str(), F_OK) == 0) {
        unlink(color_only_probe_path.c_str());
        g_mobile_native_sprite_probe_requested = true;
        g_mobile_native_sprite_color_only_probe = true;
        lg::info("OTTSEL SPRITE METAL: color-only probe accepted; awaiting TCC=0 group");
      }
      if (access(sprite_probe_path.c_str(), F_OK) == 0) {
        unlink(sprite_probe_path.c_str());
        g_mobile_native_sprite_probe_requested = true;
        lg::info("OTTSEL SPRITE METAL: probe accepted; awaiting bounded native group");
      }
    }
    if (!g_mobile_native_sprite_product_requested && mobile_sprite_village1_phase() &&
        count == 48 && adgifs[index].tex0_data != 0) {
      const GsTex0 product_tex(adgifs[index].tex0_data);
      if ((u32)product_tex.psm() == 19 && product_tex.tw() == 6 && product_tex.th() == 6) {
        g_mobile_native_sprite_product_requested = true;
        g_mobile_native_sprite_probe_requested = true;
        g_mobile_native_sprite_color_only_probe = false;
        lg::info("OTTSEL SPRITE METAL: product World2D group accepted count={} psm={} size={}x{}",
                 count, (u32)product_tex.psm(), 1u << product_tex.tw(), 1u << product_tex.th());
      }
    }
    if (g_mobile_native_sprite_probe_requested && g_metal) {
      const GsTex0 sprite_tex(adgifs[index].tex0_data);
      const bool uses_texture = ottsel::sprite3_uses_texture(adgifs[index].tex0_data);
      bool allow_native_upload =
          !g_mobile_native_sprite_uploaded &&
          (!g_mobile_native_sprite_color_only_probe || !uses_texture);
      const u32 sprite_w = uses_texture ? 1u << sprite_tex.tw() : 1u;
      const u32 sprite_h = uses_texture ? 1u << sprite_tex.th() : 1u;
      if (sprite_w <= 2048 && sprite_h <= 2048) {
        std::vector<u8> sprite_rgba((size_t)sprite_w * sprite_h * 4, 0);
        bool decoded = false;
        if (!uses_texture) {
          // Desktop Sprite3 treats TEX0.TCC=0 as color-only: keep the normal
          // sampled path alive with a generated opaque white texel, leaving
          // the vertex color as the source of RGB/A semantics.
          std::fill(sprite_rgba.begin(), sprite_rgba.end(), 255);
          decoded = true;
        } else {
          decoded = download_texture_rgba8888(
              sprite_rgba.data(), sprite_tex.tbp0(), std::max(1u, sprite_w / 64), sprite_w,
              sprite_h, (u32)sprite_tex.psm(), sprite_tex.cpsm(), sprite_tex.cbp());
        }
        if (decoded) {
          u32 texture_nonzero_alpha = 0;
          u8 texture_max_alpha = 0;
          for (size_t alpha_offset = 3; alpha_offset < sprite_rgba.size(); alpha_offset += 4) {
            texture_max_alpha = std::max(texture_max_alpha, sprite_rgba[alpha_offset]);
            texture_nonzero_alpha += sprite_rgba[alpha_offset] != 0;
          }
          float min_clip_x = shader_clip[0][0], max_clip_x = shader_clip[0][0];
          float min_clip_y = shader_clip[0][1], max_clip_y = shader_clip[0][1];
          for (u32 vertex = 1; vertex < 4; ++vertex) {
            min_clip_x = std::min(min_clip_x, shader_clip[vertex][0]);
            max_clip_x = std::max(max_clip_x, shader_clip[vertex][0]);
            min_clip_y = std::min(min_clip_y, shader_clip[vertex][1]);
            max_clip_y = std::max(max_clip_y, shader_clip[vertex][1]);
          }
          const float normalized_width = (max_clip_x - min_clip_x) * 0.5f;
          const float normalized_height = (max_clip_y - min_clip_y) * 0.5f;
          const float visible_width =
              (std::min(max_clip_x, 1.f) - std::max(min_clip_x, -1.f)) * 0.5f;
          const float visible_height =
              (std::min(max_clip_y, 1.f) - std::max(min_clip_y, -1.f)) * 0.5f;
          const bool overlaps_view = visible_width > 0.f && visible_height > 0.f;
          const bool usable_probe_bounds = overlaps_view && visible_width >= 0.02f &&
                                           visible_height >= 0.02f;
          const bool visible_probe_texture =
              (!uses_texture || texture_nonzero_alpha != 0) && vector.rgba.w > 0.f;

          if (g_mobile_native_sprite_product_requested && count == 48 && index == 0 &&
              allow_native_upload) {
            struct ProductAtlasEntry {
              u64 tex0 = 0;
              u32 x = 0;
              u32 y = 0;
              u32 w = 1;
              u32 h = 1;
            };
            constexpr u32 kAtlasTile = 64;
            constexpr u32 kAtlasColumns = 8;
            constexpr u32 kAtlasWidth = kAtlasTile * kAtlasColumns;
            constexpr u32 kAtlasRows = 8;
            std::vector<ProductAtlasEntry> atlas_entries;
            std::vector<u8> atlas_rgba((size_t)kAtlasWidth * kAtlasTile * kAtlasRows * 4, 0);
            std::vector<OttselMetalSpriteVertex> atlas_vertices;
            atlas_vertices.reserve((size_t)count * 6);
            auto atlas_entry_for = [&](u64 tex0_data, ProductAtlasEntry** out) {
              for (auto& entry : atlas_entries) {
                if (entry.tex0 == tex0_data) {
                  *out = &entry;
                  return true;
                }
              }
              const GsTex0 tex(tex0_data);
              const bool entry_uses_texture = ottsel::sprite3_uses_texture(tex0_data);
              const u32 width = entry_uses_texture ? 1u << tex.tw() : 1u;
              const u32 height = entry_uses_texture ? 1u << tex.th() : 1u;
              if (width > kAtlasTile || height > kAtlasTile || atlas_entries.size() >=
                                                               kAtlasRows * kAtlasColumns) {
                return false;
              }
              ProductAtlasEntry entry;
              entry.tex0 = tex0_data;
              entry.x = (u32)(atlas_entries.size() % kAtlasColumns) * kAtlasTile;
              entry.y = (u32)(atlas_entries.size() / kAtlasColumns) * kAtlasTile;
              entry.w = width;
              entry.h = height;
              std::vector<u8> decoded_texture((size_t)width * height * 4, 255);
              bool decoded_ok = true;
              if (entry_uses_texture) {
                decoded_ok = download_texture_rgba8888(
                    decoded_texture.data(), tex.tbp0(), std::max(1u, width / 64), width, height,
                    (u32)tex.psm(), tex.cpsm(), tex.cbp());
              }
              if (!decoded_ok) {
                return false;
              }
              for (u32 row = 0; row < height; ++row) {
                memcpy(atlas_rgba.data() +
                           ((size_t)(entry.y + row) * kAtlasWidth + entry.x) * 4,
                       decoded_texture.data() + (size_t)row * width * 4, (size_t)width * 4);
              }
              atlas_entries.push_back(entry);
              *out = &atlas_entries.back();
              return true;
            };
            bool atlas_ok = true;
            const u32 order[6] = {0, 1, 3, 0, 3, 2};
            for (u32 group_index = 0; group_index < count && atlas_ok; ++group_index) {
              ProductAtlasEntry* entry = nullptr;
              atlas_ok = atlas_entry_for(adgifs[group_index].tex0_data, &entry);
              if (!atlas_ok) {
                break;
              }
              std::array<float, 2> group_clip[4];
              float group_q = 0.f, group_sx = 0.f, group_sy = 0.f;
              atlas_ok = sprite_world_shader_clips(frame, matrix, vectors[group_index], group_clip,
                                                   &group_q, &group_sx, &group_sy);
              if (!atlas_ok) {
                break;
              }
              const auto& group_vector = vectors[group_index];
              const float group_color[4] = {
                  std::clamp(group_vector.rgba.x, 0.f, 1.f),
                  std::clamp(group_vector.rgba.y, 0.f, 1.f),
                  std::clamp(group_vector.rgba.z, 0.f, 1.f),
                  ottsel::sprite3_faded_alpha_normalized(group_vector.rgba.w, group_sx, group_sy,
                                                         frame.inv_area)};
              for (u32 out = 0; out < 6; ++out) {
                const u32 source = order[out];
                OttselMetalSpriteVertex native_vertex{};
                native_vertex.pos[0] = group_clip[source][0];
                native_vertex.pos[1] = group_clip[source][1];
                native_vertex.uv[0] = (entry->x + std::clamp(frame.st[source].x, 0.f, 1.f) *
                                       entry->w) /
                                      (float)kAtlasWidth;
                native_vertex.uv[1] = (entry->y + std::clamp(frame.st[source].y, 0.f, 1.f) *
                                       entry->h) /
                                      (float)(kAtlasTile * kAtlasRows);
                memcpy(native_vertex.color, group_color, sizeof(group_color));
                atlas_vertices.push_back(native_vertex);
              }
            }
            if (atlas_ok && !atlas_vertices.empty() && !atlas_entries.empty()) {
              ottsel_metal_set_sprite_mesh_n(
                  g_metal, atlas_vertices.data(), (u32)atlas_vertices.size(), atlas_rgba.data(),
                  kAtlasWidth, kAtlasTile * kAtlasRows, 1);
              g_mobile_native_sprite_uploaded = true;
              native_sprite_consumed = true;
              allow_native_upload = false;
              lg::info("OTTSEL SPRITE METAL: native World2D atlas vertices={} sprites={} "
                       "textures={} atlas={}x{}",
                       (u32)atlas_vertices.size(), count, (u32)atlas_entries.size(), kAtlasWidth,
                       kAtlasTile * kAtlasRows);
            } else {
              lg::warn("OTTSEL SPRITE METAL: World2D atlas rejected textures={} vertices={}",
                       (u32)atlas_entries.size(), (u32)atlas_vertices.size());
            }
          }

          const bool validated_product_group =
              g_mobile_native_sprite_product_requested && count == 48 && index == 0 && uses_texture &&
              (u32)sprite_tex.psm() == 19 && sprite_tex.tw() == 6 && sprite_tex.th() == 6;
          if (validated_product_group && allow_native_upload) {
            std::vector<OttselMetalSpriteVertex> group_vertices;
            group_vertices.reserve((size_t)count * 6);
            bool group_ok = true;
            const u64 group_tex0 = adgifs[0].tex0_data;
            const u32 order[6] = {0, 1, 3, 0, 3, 2};
            for (u32 group_index = 0; group_index < count && group_ok; ++group_index) {
              if (adgifs[group_index].tex0_data != group_tex0) {
                group_ok = false;
                break;
              }
              std::array<float, 2> group_clip[4];
              float group_q = 0.f, group_sx = 0.f, group_sy = 0.f;
              if (!sprite_world_shader_clips(frame, matrix, vectors[group_index], group_clip,
                                             &group_q, &group_sx, &group_sy)) {
                group_ok = false;
                break;
              }
              const auto& group_vector = vectors[group_index];
              const float group_alpha = ottsel::sprite3_faded_alpha_normalized(
                  group_vector.rgba.w, group_sx, group_sy, frame.inv_area);
              const float group_color[4] = {
                  std::clamp(group_vector.rgba.x, 0.f, 1.f),
                  std::clamp(group_vector.rgba.y, 0.f, 1.f),
                  std::clamp(group_vector.rgba.z, 0.f, 1.f), group_alpha};
              for (u32 out = 0; out < 6; ++out) {
                const u32 source = order[out];
                OttselMetalSpriteVertex native_vertex{};
                native_vertex.pos[0] = group_clip[source][0];
                native_vertex.pos[1] = group_clip[source][1];
                native_vertex.uv[0] = frame.st[source].x;
                native_vertex.uv[1] = frame.st[source].y;
                memcpy(native_vertex.color, group_color, sizeof(group_color));
                group_vertices.push_back(native_vertex);
              }
            }
            if (group_ok && !group_vertices.empty()) {
              ottsel_metal_set_sprite_mesh_n(g_metal, group_vertices.data(),
                                             (u32)group_vertices.size(), sprite_rgba.data(),
                                             sprite_w, sprite_h, 1);
              g_mobile_native_sprite_uploaded = true;
              native_sprite_consumed = true;
              allow_native_upload = false;
              lg::info("OTTSEL SPRITE METAL: native World2D group vertices={} sprites={} "
                       "texture=0x{:x} size={}x{}",
                       (u32)group_vertices.size(), count, sprite_tex.tbp0(), sprite_w, sprite_h);
            } else {
              lg::warn("OTTSEL SPRITE METAL: validated World2D group rejected for native upload "
                       "same-texture={}", group_ok);
            }
          }
          if (g_mobile_native_sprite_probe_requested && g_mobile_native_sprite_candidates < 32) {
            lg::info("OTTSEL SPRITE METAL: candidate={} index={} tbp=0x{:x} psm={} bounds=({:.3f},{:.3f}).."
                     "({:.3f},{:.3f}) size=({:.3f},{:.3f}) visible=({:.3f},{:.3f}) usable={}",
                     g_mobile_native_sprite_candidates, index, sprite_tex.tbp0(),
                     (u32)sprite_tex.psm(), (min_clip_x + 1.f) * 0.5f,
                     (min_clip_y + 1.f) * 0.5f, (max_clip_x + 1.f) * 0.5f,
                     (max_clip_y + 1.f) * 0.5f, normalized_width, normalized_height, visible_width,
                     visible_height,
                     usable_probe_bounds && visible_probe_texture);
          }
          ++g_mobile_native_sprite_candidates;
          const bool bucket67_fixture =
              !g_mobile_bucket67_world_probe_active ||
              ottsel::matches_bucket67_world_fixture(ottsel::Jak1SpritePhase::World2D, count,
                                                      sprite_tex.tbp0(), (u32)sprite_tex.psm(),
                                                      sprite_tex.tw(), sprite_tex.th());
          if (allow_native_upload && bucket67_fixture && max_clip_x > min_clip_x &&
              max_clip_y > min_clip_y && usable_probe_bounds && visible_probe_texture) {
            const float faded_alpha = ottsel::sprite3_faded_alpha_normalized(
                vector.rgba.w, sx, sy, frame.inv_area);
            const float color[4] = {std::clamp(vector.rgba.x, 0.f, 1.f),
                                    std::clamp(vector.rgba.y, 0.f, 1.f),
                                    std::clamp(vector.rgba.z, 0.f, 1.f), faded_alpha};
            OttselMetalSpriteVertex native_vertices[6] = {};
            const u32 order[6] = {0, 1, 3, 0, 3, 2};
            for (int out = 0; out < 6; ++out) {
              const u32 source = order[out];
              native_vertices[out].pos[0] = shader_clip[source][0];
              native_vertices[out].pos[1] = shader_clip[source][1];
              native_vertices[out].uv[0] = frame.st[source].x;
              native_vertices[out].uv[1] = frame.st[source].y;
              memcpy(native_vertices[out].color, color, sizeof(color));
            }
            ottsel_metal_set_sprite_mesh(g_metal, native_vertices, sprite_rgba.data(), sprite_w,
                                         sprite_h, 1);
            g_mobile_native_sprite_uploaded = true;
            native_sprite_consumed = true;
            lg::info("OTTSEL SPRITE METAL: native group=0 index={} bounds=({:.3f},{:.3f}).."
                     "({:.3f},{:.3f}) texture=0x{:x} tcc={} size={}x{} blend=enabled "
                     "cpu-raster=skipped-for-native-candidate alpha-test=gequal/2 "
                     "blend=source-over",
                     index, (min_clip_x + 1.f) * 0.5f, (min_clip_y + 1.f) * 0.5f,
                     (max_clip_x + 1.f) * 0.5f, (max_clip_y + 1.f) * 0.5f, sprite_tex.tbp0(),
                     sprite_tex.tcc(), sprite_w, sprite_h);
            lg::info("OTTSEL SPRITE METAL: native visibility color-alpha={} texture-alpha-max={} "
                     "texture-alpha-nonzero={} area-fade={} uploaded-alpha={}",
                     vector.rgba.w, texture_max_alpha, texture_nonzero_alpha,
                     std::clamp(sx * sy * frame.inv_area, 0.f, 1.f), faded_alpha);
          }
        }
      }
    }

    if (g_mobile_native_sprite_product_requested && g_mobile_native_sprite_uploaded &&
        count == 48) {
      native_sprite_consumed = true;
    }

    if (!native_sprite_consumed) {
      const GsTex0 tex0(adgifs[index].tex0_data);
      raster.load_tex(tex0.tbp0(), tex0.tw(), tex0.th(), (u32)tex0.psm(), tex0.cbp(), tex0.cpsm());
      raster.tri(vertices[0], vertices[1], vertices[3], true, false, true, 128);
      raster.tri(vertices[0], vertices[3], vertices[2], true, false, true, 128);
    }
    ++drawn;
  }
  return drawn;
}

static bool render_mobile_sprite_group3d_native(const MobileSpriteFrameJak1& frame,
                                                const MobileSpriteMatrix& matrix,
                                                const MobileSpriteVec2d* vectors,
                                                const AdGifData* adgifs,
                                                u32 count) {
  if (!g_metal || (count != 48 && count != 16) || !adgifs[0].tex0_data) {
    return false;
  }
  if (!g_mobile_sprite_3d_trace_requested) {
    const std::string trace_path = ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-3d";
    if (access(trace_path.c_str(), F_OK) == 0) {
      unlink(trace_path.c_str());
      g_mobile_sprite_3d_trace_requested = true;
      g_mobile_sprite_3d_trace_groups = 0;
      lg::info("OTTSEL SPRITE 3D DATA FAMILY: trigger armed");
    }
  }
  const GsTex0 tex(adgifs[0].tex0_data);
  const bool uses_texture = ottsel::sprite3_uses_texture(adgifs[0].tex0_data);
  const u32 width = uses_texture ? 1u << tex.tw() : 1u;
  const u32 height = uses_texture ? 1u << tex.th() : 1u;
  if (width > 2048 || height > 2048) {
    return false;
  }
  std::vector<u8> rgba((size_t)width * height * 4, 255);
  if (uses_texture && !download_texture_rgba8888(
                          rgba.data(), tex.tbp0(), std::max(1u, width / 64), width, height,
                          (u32)tex.psm(), tex.cpsm(), tex.cbp())) {
    return false;
  }

  // This is a bounded source/data-family ledger at the native 3D consumer
  // boundary. It is diagnostic-only: it records the payload identity that
  // reached MSCAL=211 before composition, without substituting or remapping
  // any resource. The existing parser trigger keeps the window opt-in.
  if (g_mobile_sprite_3d_trace_requested && g_mobile_sprite_3d_trace_groups < 4) {
    const u64 vector_hash = ottsel_sprite_trace_hash(vectors, count * sizeof(MobileSpriteVec2d));
    const u64 adgif_hash = ottsel_sprite_trace_hash(adgifs, count * sizeof(AdGifData));
    const u64 frame_hash = ottsel_sprite_trace_hash(&frame, sizeof(frame));
    const u64 matrix_hash = ottsel_sprite_trace_hash(&matrix, sizeof(matrix));
    lg::info("OTTSEL SPRITE 3D DATA FAMILY: group={} count={} tbp=0x{:x} tex0=0x{:016x} "
             "psm={} tw={} th={} vector-hash=0x{:x} adgif-hash=0x{:x} "
             "frame-hash=0x{:x} matrix-hash=0x{:x} first-xyz=({}, {}, {}, {}) "
             "first-flag=({}, {}, {}, {}) first-rgba=({}, {}, {}, {})",
             g_mobile_sprite_3d_trace_groups, count, tex.tbp0(), adgifs[0].tex0_data,
             (u32)tex.psm(), tex.tw(), tex.th(), vector_hash, adgif_hash, frame_hash,
             matrix_hash, vectors[0].xyz_sx.x, vectors[0].xyz_sx.y, vectors[0].xyz_sx.z,
             vectors[0].xyz_sx.w, vectors[0].flag_rot_sy.x, vectors[0].flag_rot_sy.y,
             vectors[0].flag_rot_sy.z, vectors[0].flag_rot_sy.w, vectors[0].rgba.x,
             vectors[0].rgba.y, vectors[0].rgba.z, vectors[0].rgba.w);
    log_mobile_sprite_texture_identity(adgifs[0], 0, g_mobile_sprite_3d_trace_groups, count);
    ++g_mobile_sprite_3d_trace_groups;
  }

  const auto matrix_transform3 = [](const MobileSpriteVec4 m[4], float x, float y, float z) {
    return MobileSpriteVec4{m[3].x + m[0].x * x + m[1].x * y + m[2].x * z,
                            m[3].y + m[0].y * x + m[1].y * y + m[2].y * z,
                            m[3].z + m[0].z * x + m[1].z * y + m[2].z * z,
                            m[3].w + m[0].w * x + m[1].w * y + m[2].w * z};
  };
  const auto quat_rotation = [](float x, float y, float z) {
    const float qr = std::sqrt(std::abs(1.f - (x * x + y * y + z * z)));
    std::array<MobileSpriteVec4, 3> result{};
    // sprite3_3d.vert writes mat3 columns (GLSL's result[column][row]).
    result[0] = {1.f - 2.f * (y * y + z * z), 2.f * (x * y - z * qr),
                 2.f * (x * z + y * qr), 0.f};
    result[1] = {2.f * (x * y + z * qr), 1.f - 2.f * (x * x + z * z),
                 2.f * (y * z - x * qr), 0.f};
    result[2] = {2.f * (x * z - y * qr), 2.f * (y * z + x * qr),
                 1.f - 2.f * (x * x + y * y), 0.f};
    return result;
  };
  std::vector<OttselMetalSpriteVertex> vertices;
  vertices.reserve((size_t)count * 6);
  const u32 order[6] = {0, 1, 3, 0, 3, 2};
  for (u32 index = 0; index < count; ++index) {
    const auto& vector = vectors[index];
    const auto rotation = quat_rotation(vector.flag_rot_sy.x, vector.flag_rot_sy.y,
                                        vector.flag_rot_sy.z);
    const float sx = vector.xyz_sx.w;
    const float sy = vector.flag_rot_sy.w;
    const MobileSpriteVec4 camera_position =
        matrix_transform3(matrix.camera, vector.xyz_sx.x, vector.xyz_sx.y, vector.xyz_sx.z);
    const float fade_q = frame.pfog0 / camera_position.w;
    // Keep the source shader's fade contract: the vertex shader contributes
    // one Q to sx*sy*Q*inv_area, then its final color/alpha multiplies alpha
    // by two twice. The prior native path incorrectly used Q squared.
    const float area_alpha = std::clamp(
        vector.rgba.w * std::clamp(sx * sy * fade_q * frame.inv_area, 0.f, 1.f) * 4.f,
        0.f, 1.f);
    std::array<float, 2> clips[4];
    for (u32 vertex = 0; vertex < 4; ++vertex) {
      const auto& offset = frame.xyz[vertex];
      MobileSpriteVec4 position = vector.xyz_sx;
      position.x += rotation[0].x * offset.x * sx + rotation[1].x * offset.y +
                     rotation[2].x * offset.z * sy;
      position.y += rotation[0].y * offset.x * sx + rotation[1].y * offset.y +
                     rotation[2].y * offset.z * sy;
      position.z += rotation[0].z * offset.x * sx + rotation[1].z * offset.y +
                     rotation[2].z * offset.z * sy;
      const MobileSpriteVec4 camera_vertex =
          matrix_transform3(matrix.camera, position.x, position.y, position.z);
      MobileSpriteVec4 transformed = {-camera_vertex.x, -camera_vertex.y, -camera_vertex.z,
                                      -camera_vertex.w};
      const float q = frame.pfog0 / transformed.w;
      transformed.x = transformed.x * q + matrix.hvdf.x;
      transformed.y = transformed.y * q + matrix.hvdf.y;
      transformed.z = transformed.z * q + matrix.hvdf.z;
      clips[vertex] = sprite_shader_clip_vertex(transformed);
    }
    const float color[4] = {std::clamp(vector.rgba.x, 0.f, 1.f),
                            std::clamp(vector.rgba.y, 0.f, 1.f),
                            std::clamp(vector.rgba.z, 0.f, 1.f), area_alpha};
    for (u32 out = 0; out < 6; ++out) {
      const u32 source = order[out];
      OttselMetalSpriteVertex vertex{};
      vertex.pos[0] = clips[source][0];
      vertex.pos[1] = clips[source][1];
      vertex.uv[0] = frame.st[source].x;
      vertex.uv[1] = frame.st[source].y;
      memcpy(vertex.color, color, sizeof(color));
      vertices.push_back(vertex);
    }
  }
  if (vertices.empty()) {
    return false;
  }
  ottsel_metal_append_sprite_mesh_n(g_metal, vertices.data(), (u32)vertices.size(), rgba.data(),
                                    width, height, 1);
  static u32 native_3d_logs = 0;
  if (ottsel_mobile_log_within_budget(native_3d_logs, 12)) {
    ++native_3d_logs;
    lg::info("OTTSEL SPRITE METAL: native 3D group sprites={} vertices={} tbp=0x{:x} "
             "tex0=0x{:016x} size={}x{}",
             count, (u32)vertices.size(), tex.tbp0(), adgifs[0].tex0_data, width, height);
  }
  return true;
}

static bool append_mobile_sprite_hud_native(const MobileSpriteFrameJak1& frame,
                                            const MobileSpriteHudMatrix& hud,
                                            const MobileSpriteVec2d* vectors,
                                            const AdGifData* adgifs,
                                            u32 count) {
  if (!g_metal || !g_mobile_native_sprite_product_requested ||
      (count != 48 && count != 32)) {
    return false;
  }
  constexpr u32 kTile = 64;
  constexpr u32 kColumns = 8;
  constexpr u32 kRows = 8;
  constexpr u32 kWidth = kTile * kColumns;
  constexpr u32 kHeight = kTile * kRows;
  struct Entry {
    u64 tex0 = 0;
    u32 x = 0;
    u32 y = 0;
    u32 w = 1;
    u32 h = 1;
  };
  std::vector<Entry> entries;
  std::vector<u8> atlas((size_t)kWidth * kHeight * 4, 0);
  std::vector<OttselMetalSpriteVertex> vertices;
  vertices.reserve((size_t)count * 6);
  auto find_entry = [&](u64 tex0_data, u32* out_index) {
    for (u32 i = 0; i < entries.size(); ++i) {
      if (entries[i].tex0 == tex0_data) {
        *out_index = i;
        return true;
      }
    }
    if (entries.size() >= kColumns * kRows) {
      return false;
    }
    const GsTex0 tex(tex0_data);
    const bool textured = ottsel::sprite3_uses_texture(tex0_data);
    const u32 width = textured ? 1u << tex.tw() : 1u;
    const u32 height = textured ? 1u << tex.th() : 1u;
    if (width > kTile || height > kTile) {
      return false;
    }
    Entry entry;
    entry.tex0 = tex0_data;
    entry.x = (u32)entries.size() % kColumns * kTile;
    entry.y = (u32)entries.size() / kColumns * kTile;
    entry.w = width;
    entry.h = height;
    std::vector<u8> decoded((size_t)width * height * 4, 255);
    if (textured && !download_texture_rgba8888(decoded.data(), tex.tbp0(),
                                                 std::max(1u, width / 64), width, height,
                                                 (u32)tex.psm(), tex.cpsm(), tex.cbp())) {
      return false;
    }
    for (u32 row = 0; row < height; ++row) {
      memcpy(atlas.data() + ((size_t)(entry.y + row) * kWidth + entry.x) * 4,
             decoded.data() + (size_t)row * width * 4, (size_t)width * 4);
    }
    entries.push_back(entry);
    *out_index = (u32)entries.size() - 1;
    return true;
  };
  const u32 order[6] = {0, 1, 3, 0, 3, 2};
  for (u32 index = 0; index < count; ++index) {
    const auto& vector = vectors[index];
    const MobileSpriteVec4 transformed = sprite_matrix_transform(hud.matrix, vector.xyz_sx);
    if (!std::isfinite(transformed.w) || transformed.w == 0.f) {
      return false;
    }
    const float q = frame.pfog0 / transformed.w;
    if (!std::isfinite(q)) {
      return false;
    }
    const MobileSpriteVec4 offset = (int)vector.flag_rot_sy.x == 0
                                        ? hud.hvdf
                                        : hud.user_hvdf[std::clamp((int)vector.flag_rot_sy.x - 1,
                                                                    0, 74)];
    MobileSpriteVec4 base = sprite_add(sprite_scale(transformed, q), offset);
    const float sx = std::max(vector.xyz_sx.w * q, frame.min_scale);
    const float sy = std::max(vector.flag_rot_sy.w * q, frame.min_scale);
    const float radians = vector.flag_rot_sy.z * frame.deg_to_rad;
    const float sine = std::sin(radians);
    const float cosine = std::cos(radians);
    const MobileSpriteVec4 x_basis = sprite_scale(
        sprite_add(sprite_scale(frame.basis_x, cosine), sprite_scale(frame.basis_y, -sine)), sx);
    const MobileSpriteVec4 y_basis = sprite_scale(
        sprite_add(sprite_scale(frame.basis_x, sine), sprite_scale(frame.basis_y, cosine)), sy);
    const u32 flags = *(const u32*)&vector.flag_rot_sy.x;
    std::array<float, 2> clip[4];
    for (u32 vertex = 0; vertex < 4; ++vertex) {
      const MobileSpriteVec4& xy = frame.xy[vertex + (flags & 15u)];
      clip[vertex] = sprite_shader_clip_vertex(
          sprite_add(base, sprite_add(sprite_scale(x_basis, xy.x), sprite_scale(y_basis, xy.y))));
    }
    u32 entry_index = 0;
    if (!find_entry(adgifs[index].tex0_data, &entry_index)) {
      return false;
    }
    const Entry& entry = entries[entry_index];
    const float color[4] = {std::clamp(vector.rgba.x, 0.f, 1.f),
                            std::clamp(vector.rgba.y, 0.f, 1.f),
                            std::clamp(vector.rgba.z, 0.f, 1.f),
                            std::clamp(vector.rgba.w, 0.f, 1.f)};
    for (u32 out = 0; out < 6; ++out) {
      const u32 source = order[out];
      OttselMetalSpriteVertex vertex{};
      vertex.pos[0] = clip[source][0];
      vertex.pos[1] = clip[source][1];
      vertex.uv[0] = (entry.x + std::clamp(frame.st[source].x, 0.f, 1.f) * entry.w) /
                     (float)kWidth;
      vertex.uv[1] = (entry.y + std::clamp(frame.st[source].y, 0.f, 1.f) * entry.h) /
                     (float)kHeight;
      memcpy(vertex.color, color, sizeof(color));
      vertices.push_back(vertex);
    }
  }
  if (vertices.empty() || entries.empty()) {
    return false;
  }
  ottsel_metal_append_sprite_mesh_n(g_metal, vertices.data(), (u32)vertices.size(), atlas.data(),
                                    kWidth, kHeight, 1);
  static u32 native_hud_logs = 0;
  if (ottsel_mobile_log_within_budget(native_hud_logs, 8)) {
    ++native_hud_logs;
    lg::info("OTTSEL SPRITE METAL: native HUD atlas vertices={} sprites={} textures={} "
             "atlas={}x{}",
             (u32)vertices.size(), count, (u32)entries.size(), kWidth, kHeight);
  }
  return true;
}

static u32 render_mobile_sprite_hud(const MobileSpriteFrameJak1& frame,
                                    const MobileSpriteHudMatrix& hud,
                                    const MobileSpriteVec2d* vectors,
                                    const AdGifData* adgifs,
                                    u32 count,
                                    OttselRaster& raster) {
  const bool native_consumed = append_mobile_sprite_hud_native(frame, hud, vectors, adgifs, count);
  u32 drawn = 0;
  for (u32 index = 0; index < count; ++index) {
    const auto& vector = vectors[index];
    const MobileSpriteVec4 hud_transformed =
        sprite_matrix_transform(hud.matrix, vector.xyz_sx);
    if (!std::isfinite(hud_transformed.w) || hud_transformed.w == 0.f) {
      continue;
    }
    const float q = frame.pfog0 / hud_transformed.w;
    if (!std::isfinite(q)) {
      continue;
    }
    MobileSpriteVec4 base = sprite_add(sprite_scale(hud_transformed, q),
                                       (int)vector.flag_rot_sy.x == 0
                                           ? hud.hvdf
                                           : hud.user_hvdf[std::clamp((int)vector.flag_rot_sy.x - 1,
                                                                       0, 74)]);
    const float sx = std::max(vector.xyz_sx.w * q, frame.min_scale);
    const float sy = std::max(vector.flag_rot_sy.w * q, frame.min_scale);
    const float radians = vector.flag_rot_sy.z * frame.deg_to_rad;
    const float sine = std::sin(radians);
    const float cosine = std::cos(radians);
    const MobileSpriteVec4 x_basis = sprite_scale(
        sprite_add(sprite_scale(frame.basis_x, cosine), sprite_scale(frame.basis_y, -sine)), sx);
    const MobileSpriteVec4 y_basis = sprite_scale(
        sprite_add(sprite_scale(frame.basis_x, sine), sprite_scale(frame.basis_y, cosine)), sy);
    const u32 flags = *(const u32*)&vector.flag_rot_sy.x;
    OttselVertex vertices[4];
    for (u32 vertex = 0; vertex < 4; ++vertex) {
      const MobileSpriteVec4& offset = frame.xy[vertex + (flags & 15u)];
      const MobileSpriteVec4 transformed =
          sprite_add(base, sprite_add(sprite_scale(x_basis, offset.x),
                                      sprite_scale(y_basis, offset.y)));
      vertices[vertex] = sprite_raster_vertex(transformed, frame.st[vertex], vector.rgba, raster);
    }
    if (!native_consumed) {
      const GsTex0 tex0(adgifs[index].tex0_data);
      raster.load_tex(tex0.tbp0(), tex0.tw(), tex0.th(), (u32)tex0.psm(), tex0.cbp(), tex0.cpsm());
      raster.tri(vertices[0], vertices[1], vertices[3], true, false, true, 128);
      raster.tri(vertices[0], vertices[3], vertices[2], true, false, true, 128);
    }
    ++drawn;
  }
  return drawn;
}

static bool is_sprite_header(const DmaTransfer& transfer) {
  const VifCode code(transfer.vif1());
  return transfer.size_bytes == 16 && code.kind == VifCode::Kind::UNPACK_V4_32 &&
         (code.immediate & 0x3ff) == 0;
}

struct MobileSpritePhaseSummary {
  u32 groups = 0;
  u32 sprites = 0;
  u32 world = 0;
  u32 hud = 0;
  u32 three_d = 0;
  u32 other = 0;
  struct Item {
    ottsel::Jak1SpritePhase phase = ottsel::Jak1SpritePhase::Other;
    u32 count = 0;
    u32 tbp = 0;
    u32 psm = 0;
    u32 tw = 0;
    u32 th = 0;
    u64 tex0 = 0;
    u64 tex0_addr = 0;
  };
  std::array<Item, 64> items{};
  u32 item_count = 0;
};

static void trace_mobile_sprite_phase_bucket(const void* data,
                                             u32 start_offset,
                                             u32 next_bucket,
                                             u32 chain_no,
                                             const char* label,
                                             MobileSpritePhaseSummary* summary = nullptr,
                                             bool emit_logs = true) {
  DmaFollower dma(data, start_offset);
  u32 groups = 0;
  u32 sprites = 0;
  u32 world = 0;
  u32 hud = 0;
  u32 three_d = 0;
  u32 other = 0;
  u32 transfers = 0;
  u32 header_candidates = 0;
  u32 rejected_headers = 0;
  u32 boundary_stops = 0;
  for (u32 transfer_index = 0; transfer_index < 256 && !dma.ended() &&
                                dma.current_tag_offset() != next_bucket; ++transfer_index) {
    DmaTransfer header = dma.read_and_advance();
    ++transfers;
    if (!is_sprite_header(header) || header.size_bytes < 16) {
      continue;
    }
    ++header_candidates;
    const u32 sprite_count = *(const u32*)header.data;
    if (sprite_count == 0 || sprite_count > 48 || dma.ended() ||
        dma.current_tag_offset() == next_bucket) {
      ++rejected_headers;
      if (dma.current_tag_offset() == next_bucket) {
        ++boundary_stops;
      }
      continue;
    }
    DmaTransfer vectors = dma.read_and_advance();
    DmaTransfer adgifs = dma.read_and_advance();
    DmaTransfer run = dma.read_and_advance();
    const VifCode run_vif(run.vif1());
    if (vectors.size_bytes != sprite_count * sizeof(MobileSpriteVec2d) ||
        adgifs.size_bytes != sprite_count * sizeof(AdGifData) || run.size_bytes != 0 ||
        run_vif.kind != VifCode::Kind::MSCAL) {
      ++rejected_headers;
      if (dma.current_tag_offset() == next_bucket) {
        ++boundary_stops;
      }
      continue;
    }
    ++groups;
    sprites += sprite_count;
    const auto phase = ottsel::classify_jak1_sprite_mscal(run_vif.immediate);
    const char* phase_name = "other";
    switch (phase) {
      case ottsel::Jak1SpritePhase::World2D:
        phase_name = "world";
        world += sprite_count;
        break;
      case ottsel::Jak1SpritePhase::Hud2D:
        phase_name = "hud";
        hud += sprite_count;
        break;
      case ottsel::Jak1SpritePhase::ThreeD:
        phase_name = "3d";
        three_d += sprite_count;
        break;
      case ottsel::Jak1SpritePhase::Other:
        other += sprite_count;
        break;
    }
    const auto* first_adgif = (const AdGifData*)adgifs.data;
    const auto* first_vector = (const MobileSpriteVec2d*)vectors.data;
    const GsTex0 first_tex(first_adgif[0].tex0_data);
    static u32 zero_tbp_dumps = 0;
    if (first_tex.tbp0() == 0 && zero_tbp_dumps < 8) {
      ++zero_tbp_dumps;
      lg::warn("OTTSEL SPRITE ZERO TEX: label={} chain={} group={} count={} dump={} "
               "tex0=0x{:016x} tex0-addr=0x{:016x} tex1=0x{:016x} tex1-addr=0x{:016x} "
               "clamp=0x{:016x} alpha=0x{:016x}",
               label, chain_no, groups + 1, sprite_count, zero_tbp_dumps,
               first_adgif->tex0_data, first_adgif->tex0_addr, first_adgif->tex1_data,
               first_adgif->tex1_addr, first_adgif->clamp_data, first_adgif->alpha_data);
    }
    const bool bucket67_world_fixture = ottsel::matches_bucket67_world_fixture(
        phase, sprite_count, first_tex.tbp0(), (u32)first_tex.psm(), first_tex.tw(), first_tex.th());
    if (emit_logs && groups <= 2) {
      const auto* first_vec = (const u32*)vectors.data;
      lg::info("OTTSEL SPRITE SOURCE ITEM: label={} chain={} group={} count={} "
               "header-vif0=0x{:08x} header-vif1=0x{:08x} vec-bytes={} adgif-bytes={} "
               "mscal={} vec0=0x{:08x}/0x{:08x}/0x{:08x}/0x{:08x} tex0=0x{:016x}",
               label, chain_no, groups, sprite_count, header.vif0(), header.vif1(),
               vectors.size_bytes, adgifs.size_bytes, run_vif.immediate, first_vec[0],
               first_vec[1], first_vec[2], first_vec[3], first_adgif->tex0_data);
    }
    if (summary && summary->item_count < summary->items.size()) {
      summary->items[summary->item_count++] = {phase, sprite_count, first_tex.tbp0(),
                                                (u32)first_tex.psm(), first_tex.tw(), first_tex.th(),
                                                first_adgif->tex0_data, first_adgif->tex0_addr};
    }
    if (emit_logs) {
      lg::info("OTTSEL SPRITE PHASE ITEM: label={} chain={} vsync={} group={} phase={} count={} "
               "tbp=0x{:x} psm={} tw={} th={} tex0=0x{:016x} tex0-addr=0x{:016x} "
               "first-xyz=({}, {}, {}, {}) fixture={}",
               label, chain_no, g_ottsel_ios_vsync_count, groups, phase_name, sprite_count,
               first_tex.tbp0(), (u32)first_tex.psm(), first_tex.tw(), first_tex.th(),
               first_adgif->tex0_data, first_adgif->tex0_addr, first_vector->xyz_sx.x,
               first_vector->xyz_sx.y, first_vector->xyz_sx.z, first_vector->xyz_sx.w,
               bucket67_world_fixture);
    }
  }
  if (summary) {
    summary->groups = groups;
    summary->sprites = sprites;
    summary->world = world;
    summary->hud = hud;
    summary->three_d = three_d;
    summary->other = other;
  }
  if (emit_logs) {
    lg::info("OTTSEL SPRITE RAW SPAN: label={} chain={} transfers={} headers={} rejected={} "
             "boundary-stops={} start=0x{:x} next=0x{:x}",
             label, chain_no, transfers, header_candidates, rejected_headers, boundary_stops,
             start_offset, next_bucket);
    lg::info("OTTSEL SPRITE PHASE: label={} chain={} vsync={} groups={} sprites={} world={} hud={} "
             "3d={} other={} start=0x{:x} next=0x{:x}",
             label, chain_no, g_ottsel_ios_vsync_count, groups, sprites, world, hud, three_d,
             other, start_offset, next_bucket);
  }
}

static u32 render_mobile_sprite_bucket(const void* data,
                                       u32 start_offset,
                                       u32 next_bucket,
                                       OttselRaster& raster,
                                       u32 chain_no,
                                       const MobileSpriteFrameJak1* inherited_frame = nullptr,
                                       const MobileSpriteMatrix* inherited_matrix = nullptr,
                                       const MobileSpriteHudMatrix* inherited_hud = nullptr,
                                       MobileSpriteFrameJak1* frame_out = nullptr,
                                       MobileSpriteMatrix* matrix_out = nullptr,
                                       MobileSpriteHudMatrix* hud_out = nullptr,
                                       bool* frame_valid_out = nullptr,
                                       bool* matrix_valid_out = nullptr,
                                       bool* hud_valid_out = nullptr) {
  if (!g_mobile_sprite_parser_trace) {
    const std::string trace_path = ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite";
    if (access(trace_path.c_str(), F_OK) == 0) {
      g_mobile_sprite_parser_trace = true;
      lg::info("OTTSEL SPRITE TRACE: parser probe armed");
    }
  }
  if (!g_mobile_sprite_record_trace && mobile_sprite_village1_phase()) {
    const std::string record_trace_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-records";
    const bool auto_arm = std::getenv("OTTSEL_TRACE_MOBILE_SPRITE_IDENTITY") != nullptr;
    if (access(record_trace_path.c_str(), F_OK) == 0 ||
        (auto_arm && !g_mobile_sprite_identity_auto_armed)) {
      unlink(record_trace_path.c_str());
      g_mobile_sprite_record_trace = true;
      g_mobile_sprite_record_trace_count = 0;
      g_mobile_sprite_identity_auto_armed = auto_arm;
      lg::info("OTTSEL SPRITE RECORDS: bounded ledger armed bucket=66 chain={} auto={}", chain_no,
               auto_arm);
    }
  }
  if (!g_mobile_sprite_source_boundary_trace && mobile_sprite_village1_phase()) {
    const std::string source_boundary_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-source-boundary";
    if (access(source_boundary_path.c_str(), F_OK) == 0) {
      unlink(source_boundary_path.c_str());
      g_mobile_sprite_source_boundary_trace = true;
      g_mobile_sprite_source_boundary_count = 0;
      lg::info("OTTSEL SPRITE SOURCE BOUNDARY: armed chain={} start=0x{:x} next=0x{:x} "
               "vsync={} level='{}' camera-source-chain={} camera-source-transfer={}",
               chain_no, start_offset, next_bucket, g_ottsel_ios_vsync_count,
               g_mobile_camera_level, g_mobile_camera_last_chain, g_mobile_camera_last_transfer);
    }
  }
  DmaFollower dma(data, start_offset);
  MobileSpriteFrameJak1 frame{};
  MobileSpriteMatrix matrix{};
  MobileSpriteHudMatrix hud{};
  bool have_frame = inherited_frame != nullptr;
  bool have_matrix = inherited_matrix != nullptr;
  bool have_hud = inherited_hud != nullptr;
  if (inherited_frame) {
    frame = *inherited_frame;
  }
  if (inherited_matrix) {
    matrix = *inherited_matrix;
  }
  if (inherited_hud) {
    hud = *inherited_hud;
  }
  u32 frame_transfer_index = UINT32_MAX;
  u32 matrix_transfer_index = UINT32_MAX;
  u64 frame_trace_hash = 0;
  u64 frame_camera_trace_hash = 0;
  u64 matrix_trace_hash = 0;
  bool producer_setup_logged = false;
  bool producer_setup_transfers_logged = false;
  bool first_mscal_logged = false;
  u32 group_no = 0;
  u32 drawn = 0;
  u32 parser_group_count = 0;
  u32 parser_sprite_count = 0;
  u32 parser_hud_sprite_count = 0;
  u32 parser_3d_sprite_count = 0;
  u32 parser_other_sprite_count = 0;
  u32 parser_first_tbp = UINT32_MAX;
  u32 parser_last_tbp = 0;
  for (u32 transfer_index = 0; transfer_index < 256 && !dma.ended() &&
                                dma.current_tag_offset() != next_bucket; ++transfer_index) {
    const u32 header_offset = dma.current_tag_offset();
    DmaTransfer transfer = dma.read_and_advance();
    const VifCode vif1(transfer.vif1());
    if (g_mobile_sprite_record_trace && !producer_setup_transfers_logged && !have_frame) {
      u64 q0 = 0;
      u64 q1 = 0;
      u64 q2 = 0;
      if (transfer.size_bytes >= 8) {
        memcpy(&q0, transfer.data, sizeof(q0));
      }
      if (transfer.size_bytes >= 16) {
        memcpy(&q1, transfer.data + 8, sizeof(q1));
      }
      if (transfer.size_bytes >= 24) {
        memcpy(&q2, transfer.data + 16, sizeof(q2));
      }
      lg::info("OTTSEL SPRITE PRODUCER SETUP TRANSFER: chain={} transfer={} size={} "
               "tag=0x{:016x} vif0=0x{:08x} vif1=0x{:08x} q0=0x{:016x} q1=0x{:016x} "
               "q2=0x{:016x}",
               chain_no, transfer_index, transfer.size_bytes, transfer.transferred_tag, transfer.vif0(),
               transfer.vif1(), q0, q1, q2);
    }
    if (transfer.size_bytes == sizeof(frame) && vif1.kind == VifCode::Kind::UNPACK_V4_32 &&
        (vif1.immediate & 0x3ff) == 0x3d4) {
      memcpy(&frame, transfer.data, sizeof(frame));
      have_frame = true;
      frame_transfer_index = transfer_index;
      frame_trace_hash = ottsel_sprite_trace_hash(transfer.data, sizeof(frame));
      frame_camera_trace_hash = ottsel_sprite_camera_frame_hash(frame);
      producer_setup_transfers_logged = true;
      if (g_mobile_sprite_parser_trace) {
        lg::info("OTTSEL SPRITE TRACE: frame transfer={} size={} imm=0x{:x}", transfer_index,
                 transfer.size_bytes, vif1.immediate);
      }
      continue;
    }
    if (transfer.size_bytes == sizeof(matrix) && vif1.kind == VifCode::Kind::UNPACK_V4_32 &&
        (vif1.immediate & 0x3ff) == 0x384) {
      memcpy(&matrix, transfer.data, sizeof(matrix));
      have_matrix = true;
      matrix_transfer_index = transfer_index;
      matrix_trace_hash = ottsel_sprite_trace_hash(transfer.data, sizeof(matrix));
      if (g_mobile_sprite_record_trace && have_frame && !producer_setup_logged) {
        producer_setup_logged = true;
        lg::info("OTTSEL SPRITE PRODUCER SETUP: chain={} frame-transfer={} matrix-transfer={} "
                 "pfog0={} inv-area={} camera-t=({}, {}, {}, {}) hvdf=({}, {}, {}, {}) "
                 "basis-x=({}, {}, {}, {}) basis-y=({}, {}, {}, {}) frame-hash=0x{:x} "
                 "camera-frame-hash=0x{:x} "
                 "matrix-hash=0x{:x} vsync={} camera-packets={} camera-source-chain={} "
                 "camera-source-transfer={} pc-level='{}' pc-trans=({}, {}, {})",
                 chain_no, frame_transfer_index, matrix_transfer_index, frame.pfog0, frame.inv_area,
                 matrix.camera[3].x, matrix.camera[3].y, matrix.camera[3].z, matrix.camera[3].w,
                 matrix.hvdf.x, matrix.hvdf.y, matrix.hvdf.z, matrix.hvdf.w, frame.basis_x.x,
                 frame.basis_x.y, frame.basis_x.z, frame.basis_x.w, frame.basis_y.x,
                 frame.basis_y.y, frame.basis_y.z, frame.basis_y.w, frame_trace_hash,
                 frame_camera_trace_hash, matrix_trace_hash, g_ottsel_ios_vsync_count,
                 g_mobile_camera_packet_count,
                 g_mobile_camera_last_chain,
                 g_mobile_camera_last_transfer, g_mobile_camera_level, g_mobile_camera.trans[0],
                 g_mobile_camera.trans[1], g_mobile_camera.trans[2]);
      }
      if (g_mobile_sprite_parser_trace) {
        lg::info("OTTSEL SPRITE TRACE: matrix transfer={} size={} imm=0x{:x}", transfer_index,
                 transfer.size_bytes, vif1.immediate);
      }
      continue;
    }
    if (transfer.size_bytes == sizeof(hud) && vif1.kind == VifCode::Kind::UNPACK_V4_32 &&
        (vif1.immediate & 0x3ff) == 0x384) {
      memcpy(&hud, transfer.data, sizeof(hud));
      have_hud = true;
      if (g_mobile_sprite_parser_trace) {
        lg::info("OTTSEL SPRITE TRACE: hud matrix transfer={} size={} imm=0x{:x} hvdf=({}, {}, {}, {})",
                 transfer_index, transfer.size_bytes, vif1.immediate, hud.hvdf.x, hud.hvdf.y,
                 hud.hvdf.z, hud.hvdf.w);
      }
      continue;
    }
    if (!have_frame || !have_matrix || !is_sprite_header(transfer)) {
      continue;
    }

    const u32 sprite_count = *(const u32*)transfer.data;
    if (g_mobile_sprite_parser_trace && have_frame && have_matrix) {
      lg::info("OTTSEL SPRITE TRACE: header transfer={} count={} next=0x{:x}", transfer_index,
               sprite_count, dma.current_tag_offset());
    }
    if (sprite_count == 0 || sprite_count > 48 || dma.ended() ||
        dma.current_tag_offset() == next_bucket) {
      continue;
    }
    DmaTransfer vectors = dma.read_and_advance();
    if (vectors.size_bytes != sprite_count * sizeof(MobileSpriteVec2d) || dma.ended() ||
        dma.current_tag_offset() == next_bucket) {
      continue;
    }
    DmaTransfer adgifs = dma.read_and_advance();
    if (adgifs.size_bytes != sprite_count * sizeof(AdGifData) || dma.ended() ||
        dma.current_tag_offset() == next_bucket) {
      continue;
    }
    DmaTransfer run = dma.read_and_advance();
    const VifCode run_vif(run.vif1());
    if (g_mobile_sprite_parser_trace && have_frame && have_matrix) {
      lg::info("OTTSEL SPRITE TRACE: payload vectors={} adgif={} run-size={} run-vif=0x{:x} "
               "run-kind={} run-imm={}",
               vectors.size_bytes, adgifs.size_bytes, run.size_bytes, run.vif1(),
               (u32)run_vif.kind, run_vif.immediate);
    }
    if (g_mobile_sprite_source_boundary_trace &&
        g_mobile_sprite_source_boundary_count < 128 && run.size_bytes == 0 &&
        run_vif.kind == VifCode::Kind::MSCAL) {
      const auto phase = ottsel::classify_jak1_sprite_mscal(run_vif.immediate);
      if (phase != ottsel::Jak1SpritePhase::Other) {
        const char* phase_name = phase == ottsel::Jak1SpritePhase::ThreeD
                                     ? "3d"
                                     : phase == ottsel::Jak1SpritePhase::World2D ? "world" : "hud";
        const GsTex0 first_tex(((const AdGifData*)adgifs.data)[0].tex0_data);
        const auto& first_vector = ((const MobileSpriteVec2d*)vectors.data)[0];
        const auto& first_adgif = ((const AdGifData*)adgifs.data)[0];
        lg::info("OTTSEL SPRITE SOURCE BOUNDARY: item={} chain={} vsync={} level='{}' "
                 "phase={} mscal={} group={} transfer={} header=0x{:x} start=0x{:x} next=0x{:x} "
                 "count={} tbp=0x{:x} psm={} tw={} th={} frame-transfer={} matrix-transfer={} "
                 "pfog0={} inv-area={} camera-t=({}, {}, {}, {}) hvdf=({}, {}, {}, {}) "
                 "frame-hash=0x{:x} camera-frame-hash=0x{:x} matrix-hash=0x{:x} "
                 "camera-source-chain={} camera-source-transfer={} first-xyz=({}, {}, {}, {}) "
                 "first-flag=({}, {}, {}, {}) first-rgba=({}, {}, {}, {}) first-tex0=0x{:x} "
                 "first-tex1=0x{:x} first-clamp=0x{:x} first-alpha=0x{:x}",
                 g_mobile_sprite_source_boundary_count, chain_no, g_ottsel_ios_vsync_count,
                 g_mobile_camera_level, phase_name, run_vif.immediate, group_no, transfer_index,
                 header_offset, start_offset, next_bucket, sprite_count, first_tex.tbp0(),
                 (u32)first_tex.psm(), first_tex.tw(), first_tex.th(), frame_transfer_index,
                 matrix_transfer_index, frame.pfog0, frame.inv_area, matrix.camera[3].x,
                 matrix.camera[3].y, matrix.camera[3].z, matrix.camera[3].w, matrix.hvdf.x,
                 matrix.hvdf.y, matrix.hvdf.z, matrix.hvdf.w, frame_trace_hash,
                 frame_camera_trace_hash, matrix_trace_hash, g_mobile_camera_last_chain,
                 g_mobile_camera_last_transfer, first_vector.xyz_sx.x, first_vector.xyz_sx.y,
                 first_vector.xyz_sx.z, first_vector.xyz_sx.w, first_vector.flag_rot_sy.x,
                 first_vector.flag_rot_sy.y, first_vector.flag_rot_sy.z, first_vector.flag_rot_sy.w,
                 first_vector.rgba.x, first_vector.rgba.y, first_vector.rgba.z,
                 first_vector.rgba.w, first_adgif.tex0_data, first_adgif.tex1_data,
                 first_adgif.clamp_data, first_adgif.alpha_data);
        ++g_mobile_sprite_source_boundary_count;
      }
    }
    if (run.size_bytes == 0 && run_vif.kind == VifCode::Kind::MSCAL && run_vif.immediate == 3) {
      if (g_mobile_sprite_record_trace && !first_mscal_logged) {
        first_mscal_logged = true;
        lg::info("OTTSEL SPRITE PRODUCER MSCAL3: chain={} group={} transfer={} frame-transfer={} "
                 "matrix-transfer={} frame-pfog0={} frame-inv-area={} first-tbp=0x{:x}",
                 chain_no, group_no, transfer_index, frame_transfer_index, matrix_transfer_index,
                 frame.pfog0, frame.inv_area,
                 GsTex0(((const AdGifData*)adgifs.data)[0].tex0_data).tbp0());
      }
      const auto* parsed_adgifs = (const AdGifData*)adgifs.data;
      const GsTex0 first_product_tex(parsed_adgifs[0].tex0_data);
      static u32 product_zero_tbp_dumps = 0;
      if (first_product_tex.tbp0() == 0 && product_zero_tbp_dumps < 8) {
        ++product_zero_tbp_dumps;
        lg::warn("OTTSEL SPRITE ZERO TEX PRODUCT: chain={} group={} count={} dump={} "
                 "size={} vif0=0x{:08x} vif1=0x{:08x} tex0=0x{:016x} "
                 "tex0-addr=0x{:016x} tex1=0x{:016x} tex1-addr=0x{:016x} "
                 "clamp=0x{:016x} alpha=0x{:016x}",
                 chain_no, group_no, sprite_count, product_zero_tbp_dumps,
                 adgifs.size_bytes, adgifs.vif0(), adgifs.vif1(), parsed_adgifs[0].tex0_data,
                 parsed_adgifs[0].tex0_addr,
                 parsed_adgifs[0].tex1_data, parsed_adgifs[0].tex1_addr,
                 parsed_adgifs[0].clamp_data, parsed_adgifs[0].alpha_data);
        const auto* raw = reinterpret_cast<const u64*>(adgifs.data);
        lg::warn("OTTSEL SPRITE ZERO TEX RAW: q0..4={:016x}/{:016x}/{:016x}/{:016x}/{:016x} "
                 "q5..9={:016x}/{:016x}/{:016x}/{:016x}/{:016x}",
                 raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7], raw[8], raw[9]);
      }
      if (g_mobile_sprite_parser_trace) {
        const GsTex0 first_tex(parsed_adgifs[0].tex0_data);
        parser_first_tbp = std::min(parser_first_tbp, first_tex.tbp0());
        parser_last_tbp = first_tex.tbp0();
        ++parser_group_count;
        parser_sprite_count += sprite_count;
      }
      if (g_mobile_sprite_record_trace && g_mobile_sprite_record_trace_count == 0) {
        log_mobile_sprite_texture_identity(parsed_adgifs[0], chain_no, group_no, sprite_count);
      }
      if (g_mobile_sprite_record_trace && g_mobile_sprite_record_trace_count < 64) {
        const auto* record_vectors = (const MobileSpriteVec2d*)vectors.data;
        const auto* record_adgifs = (const AdGifData*)adgifs.data;
        const u32 records_to_log = std::min(sprite_count, 8u);
        lg::info("OTTSEL SPRITE RECORDS: chain={} group={} count={} frame-pfog0={} "
                 "frame-inv-area={} camera-t=({}, {}, {}, {}) pc-level='{}' "
                 "pc-trans=({}, {}, {}) pc-fog={} pc-r0=({}, {}, {}) pc-r2=({}, {}, {}) "
                 "pc-persp=({}, {}, {}, {}) pc-hvdf=({}, {})",
                 chain_no, group_no, sprite_count, frame.pfog0, frame.inv_area,
                 matrix.camera[3].x, matrix.camera[3].y, matrix.camera[3].z,
                 matrix.camera[3].w, g_mobile_camera_level, g_mobile_camera.trans[0],
                 g_mobile_camera.trans[1], g_mobile_camera.trans[2], g_mobile_camera.fog[0],
                 g_mobile_camera.rot[0][0], g_mobile_camera.rot[0][1],
                 g_mobile_camera.rot[0][2], g_mobile_camera.rot[2][0],
                 g_mobile_camera.rot[2][1], g_mobile_camera.rot[2][2],
                 g_mobile_camera.perspective[0][0], g_mobile_camera.perspective[1][1],
                 g_mobile_camera.perspective[2][2], g_mobile_camera.perspective[2][3],
                 g_mobile_camera.hvdf_off[2], g_mobile_camera.hvdf_off[3]);
        for (u32 record = 0; record < records_to_log &&
                                g_mobile_sprite_record_trace_count < 64; ++record) {
          const auto& vector = record_vectors[record];
          const auto& adgif = record_adgifs[record];
          const GsTex0 tex0(adgif.tex0_data);
          lg::info("OTTSEL SPRITE RECORDS: chain={} group={} index={} tbp=0x{:x} psm={} "
                   "tw={} th={} tcc={} tfx={} tex0=0x{:016x} tex1=0x{:016x} "
                   "clamp=0x{:016x} alpha=0x{:016x} xyz=({}, {}, {}, {}) "
                   "flag=({}, {}, {}, {}) rgba=({}, {}, {}, {})",
                   chain_no, group_no, record, tex0.tbp0(), (u32)tex0.psm(), tex0.tw(),
                   tex0.th(), tex0.tcc(), (u32)tex0.tfx(), adgif.tex0_data, adgif.tex1_data,
                   adgif.clamp_data, adgif.alpha_data, vector.xyz_sx.x, vector.xyz_sx.y,
                   vector.xyz_sx.z, vector.xyz_sx.w, vector.flag_rot_sy.x,
                   vector.flag_rot_sy.y, vector.flag_rot_sy.z, vector.flag_rot_sy.w,
                   vector.rgba.x, vector.rgba.y, vector.rgba.z, vector.rgba.w);
          ++g_mobile_sprite_record_trace_count;
        }
        ++group_no;
        if (g_mobile_sprite_record_trace_count >= 64) {
          g_mobile_sprite_record_trace = false;
          lg::info("OTTSEL SPRITE RECORDS: bounded ledger complete records=64");
        }
      } else if (g_mobile_sprite_record_trace) {
        g_mobile_sprite_record_trace = false;
      }
      drawn += render_mobile_sprite_group0(frame, matrix,
                                           (const MobileSpriteVec2d*)vectors.data,
                                           (const AdGifData*)adgifs.data, sprite_count, raster);
    } else if (run.size_bytes == 0 && run_vif.kind == VifCode::Kind::MSCAL &&
               run_vif.immediate == 211 && have_frame && have_matrix) {
      render_mobile_sprite_group3d_native(
          frame, matrix, (const MobileSpriteVec2d*)vectors.data,
          (const AdGifData*)adgifs.data, sprite_count);
      if (g_mobile_sprite_parser_trace) {
        parser_3d_sprite_count += sprite_count;
      }
    } else if (run.size_bytes == 0 && run_vif.kind == VifCode::Kind::MSCAL &&
               run_vif.immediate == 109 && have_hud) {
      drawn += render_mobile_sprite_hud(frame, hud, (const MobileSpriteVec2d*)vectors.data,
                                        (const AdGifData*)adgifs.data, sprite_count, raster);
    } else if (run.size_bytes == 0 && run_vif.kind == VifCode::Kind::MSCAL &&
               g_mobile_sprite_parser_trace) {
      const auto phase = ottsel::classify_jak1_sprite_mscal(run_vif.immediate);
      switch (phase) {
        case ottsel::Jak1SpritePhase::Hud2D:
          parser_hud_sprite_count += sprite_count;
          break;
        case ottsel::Jak1SpritePhase::ThreeD:
          parser_3d_sprite_count += sprite_count;
          break;
        case ottsel::Jak1SpritePhase::Other:
          parser_other_sprite_count += sprite_count;
          break;
        case ottsel::Jak1SpritePhase::World2D:
          break;
      }
    }
  }
  if (g_mobile_sprite_source_boundary_trace && g_mobile_sprite_source_boundary_count >= 128) {
    g_mobile_sprite_source_boundary_trace = false;
    lg::info("OTTSEL SPRITE SOURCE BOUNDARY: complete items={}",
             g_mobile_sprite_source_boundary_count);
  }
  if (g_mobile_sprite_parser_trace) {
    lg::info("OTTSEL SPRITE TRACE: bucket complete chain={} vsync={} groups={} sprites={} hud-sprites={} "
             "3d-sprites={} other-sprites={} first-tbp=0x{:x} last-tbp=0x{:x} "
             "start=0x{:x} next=0x{:x}",
             chain_no, g_ottsel_ios_vsync_count, parser_group_count, parser_sprite_count,
             parser_hud_sprite_count, parser_3d_sprite_count, parser_other_sprite_count,
             parser_first_tbp == UINT32_MAX ? 0 : parser_first_tbp, parser_last_tbp,
             start_offset, next_bucket);
    g_mobile_sprite_parser_trace = false;
  }
  if (frame_out && have_frame) {
    *frame_out = frame;
  }
  if (matrix_out && have_matrix) {
    *matrix_out = matrix;
  }
  if (hud_out && have_hud) {
    *hud_out = hud;
  }
  if (frame_valid_out) {
    *frame_valid_out = have_frame;
  }
  if (matrix_valid_out) {
    *matrix_valid_out = have_matrix;
  }
  if (hud_valid_out) {
    *hud_valid_out = have_hud;
  }
  return drawn;
}

// Bucket 67 also carries standalone title/progress Direct GIF transfers after
// its Sprite3 records.  The product path keeps the Sprite3 expansion above;
// when the bounded Direct trace is armed, walk only those transfers through
// the shared decoder with no raster consumer so the D0 packet can be compared
// without changing the rendered frame.
static void trace_mobile_direct_bucket(const void* data,
                                       u32 start_offset,
                                       u32 next_bucket,
                                       OttselGifDecoder& decoder) {
  if (!g_mobile_direct_trace.active) {
    return;
  }
  static u32 trace_calls = 0;
  if (trace_calls < 2) {
    lg::info("OTTSEL MOBILE DIRECT: bucket trace begin start=0x{:x} next=0x{:x}",
             start_offset, next_bucket);
  }
  DmaFollower dma(data, start_offset);
  OttselRaster* old_raster = decoder.rst;
  decoder.rst = nullptr;
  u32 transfers = 0;
  u32 glyphs = 0;
  static bool direct_ir_metal_triggered = false;
  // The title Direct records follow the nominal bucket-67 boundary through
  // linked DMA data.  Keep this diagnostic window bounded to the 64-transfer
  // capture used to identify them; the product Sprite3 walk remains bounded by
  // the actual next-bucket address below.
  for (u32 transfer_index = 0; transfer_index < 64 && !dma.ended();
       ++transfer_index) {
    DmaTransfer transfer = dma.read_and_advance();
    ++transfers;
    const VifCode vif0(transfer.vif0());
    const VifCode vif1(transfer.vif1());
    if (vif0.kind == VifCode::Kind::DIRECT || vif1.kind == VifCode::Kind::DIRECT) {
      if (transfer.size_bytes >= 16) {
        const GifTag tag(transfer.data);
        const bool is_d0_glyph = tag.nloop() == 1 && tag.eop() && tag.pre() &&
                                 tag.prim() == 0x5c && tag.nreg() == 13;
        if (is_d0_glyph) {
          ++glyphs;
          if (glyphs == 1) {
            // Isolate one unsplit packet from the normal-chain IR budget so
            // this live comparison cannot be masked by earlier Direct data.
            decoder.ordered_ir.clear();
            decoder.reset_direct_geometry();
            // The desktop D0 packet begins with only A+D(TEX0); its alpha,
            // test, zbuf, and scissor values are the renderer defaults. Do
            // not carry register state from an unrelated linked transfer
            // into this isolated bucket proof.
            decoder.st = OttselDrawState{};
            decoder.have_direct_snapshot = false;
            decoder.direct_scissor_seen = false;
            decoder.record_boundary(ottsel::DirectIrKind::BucketBegin, 67);
            decode_transfer(transfer, decoder);
            decoder.record_boundary(ottsel::DirectIrKind::Flush,
                                    u64(ottsel::DirectIrFlushReason::BucketEnd));
            decoder.record_boundary(ottsel::DirectIrKind::BucketEnd, 67);
            const std::string metal_ir_path =
                ottsel_ios_writable_dir() + "ottsel-trace-metal-direct-ir";
            if (!direct_ir_metal_triggered && g_metal &&
                (g_mobile_direct_trace.native_product ||
                 access(metal_ir_path.c_str(), F_OK) == 0)) {
              if (!g_mobile_direct_trace.native_product) {
                unlink(metal_ir_path.c_str());
              }
              direct_ir_metal_triggered = true;
              // Match DirectRenderer's Jak 1 shader seam: XYZ is normalized
              // from the GS 16-bit range into clip space, with the 512x448
              // game viewport and interlace height adjustment applied before
              // the native Metal drawable transform.
              const auto metal_x = [](u32 value) {
                return std::clamp((value / 65536.f - 0.5f) * 8.f + 0.5f, 0.f, 1.f);
              };
              const auto metal_y = [](u32 value) {
                const float clip_y = -(value / 65536.f - 0.5f) * 32.f * (512.f / 448.f);
                return std::clamp(0.5f - clip_y * 0.5f, 0.f, 1.f);
              };
              const float x = metal_x(decoder.direct_min_x);
              const float y = metal_y(decoder.direct_min_y);
              const float right = metal_x(decoder.direct_max_x + 1);
              const float bottom = metal_y(decoder.direct_max_y + 1);
              u32 direct_texture_width = 2;
              u32 direct_texture_height = 2;
              bool used_live_vram = false;
              std::vector<u8> direct_ir_image;
              if (decoder.have_direct_snapshot) {
                const u64 direct_texture_key = decoder.last_direct_snapshot.tex0;
                const GsTex0 direct_tex0(direct_texture_key);
                const auto relocated_it = g_direct_relocated_textures.find(
                    direct_texture_cache_key(direct_tex0.tbp0(), (u32)direct_tex0.psm()));
                if (relocated_it != g_direct_relocated_textures.end()) {
                  direct_texture_width = relocated_it->second.width;
                  direct_texture_height = relocated_it->second.height;
                  direct_ir_image = relocated_it->second.rgba;
                  used_live_vram = true;
                }
              }
              if (direct_ir_image.empty() && decoder.have_direct_snapshot) {
                direct_ir_image = decode_direct_vram_texture(
                    decoder.last_direct_snapshot.tex0, direct_texture_width,
                    direct_texture_height, used_live_vram);
              }
              if (direct_ir_image.empty()) {
                direct_texture_width = 2;
                direct_texture_height = 2;
                const auto generated = make_generated_direct_clut_image();
                direct_ir_image.assign(generated.begin(), generated.end());
              }
              lg::info("OTTSEL METAL DIRECT: texture upload source={} size={}x{} "
                       "image-checksum={}",
                       used_live_vram ? "relocated-vram" : "generated-fallback", direct_texture_width,
                       direct_texture_height,
                       std::accumulate(direct_ir_image.begin(), direct_ir_image.end(), 0u));
              const u64 texture_key = decoder.have_direct_snapshot
                                          ? decoder.last_direct_snapshot.tex0
                                          : 0;
              const float direct_color[4] = {
                  decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[0] / 255.f : 1.f,
                  decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[1] / 255.f : 1.f,
                  decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[2] / 255.f : 1.f,
                  decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[3] / 255.f : 1.f};
              ottsel_metal_set_direct_fixture(g_metal, direct_ir_image.data(), direct_texture_width,
                                              direct_texture_height, texture_key, x, y,
                                              std::max(0.01f, right - x),
                                              std::max(0.01f, bottom - y), decoder.direct_min_s,
                                              decoder.direct_min_t, decoder.direct_max_s,
                                              decoder.direct_max_t, direct_color);
              if (decoder.have_direct_snapshot) {
                const GsScissor sc(decoder.last_direct_snapshot.scissor);
                const bool scissor_seen = (decoder.last_direct_snapshot.flags & 8) != 0;
                ottsel_metal_set_direct_fixture_state(
                    g_metal, decoder.last_direct_snapshot.prim, decoder.last_direct_snapshot.tex0,
                    decoder.last_direct_snapshot.tex1, decoder.last_direct_snapshot.clamp,
                    decoder.last_direct_snapshot.frame, decoder.last_direct_snapshot.alpha,
                    decoder.last_direct_snapshot.test, decoder.last_direct_snapshot.zbuf,
                    decoder.last_direct_snapshot.texa,
                    scissor_seen ? sc.x0() : 0,
                    scissor_seen ? sc.x1() : 511, scissor_seen ? sc.y0() : 0,
                    scissor_seen ? sc.y1() : 447);
                lg::info("OTTSEL METAL DIRECT: scissor-emitted={}", scissor_seen);
              }
              lg::info("OTTSEL METAL DIRECT: IR geometry accepted x={} y={} right={} bottom={} "
                       "st=({:.3f},{:.3f})..({:.3f},{:.3f}) rgba=({},{},{},{}) cpu-raster=0",
                       decoder.direct_min_x, decoder.direct_min_y, decoder.direct_max_x,
                       decoder.direct_max_y, decoder.direct_min_s, decoder.direct_min_t,
                       decoder.direct_max_s, decoder.direct_max_t,
                       decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[0] : 0,
                       decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[1] : 0,
                       decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[2] : 0,
                       decoder.have_direct_snapshot ? decoder.last_direct_snapshot.rgba[3] : 0);
            }
          }
        }
      }
    }
  }
  decoder.rst = old_raster;
  if (trace_calls < 2) {
    lg::info("OTTSEL MOBILE DIRECT: bucket trace end transfers={} glyphs={}",
             transfers, glyphs);
    ++trace_calls;
  }
}

// Bucket 67 also contains title/progress text as standalone VIF DIRECT GIF
// packets.  The PC renderer consumes these after its Sprite3 blocks; they do
// not have a Sprite3 VU program to run on PC_PORT.  Decode only that bucket
// with isolated GS state so a debug/text packet cannot inherit unrelated
// state from the generic DMA walk.
void trace_mobile_generic_buckets(const void* data, u32 chain_offset) {
  DmaFollower dma(data, chain_offset);

  // Follow the initial CALL into the default-register buffer and its RET back
  // to bucket zero, exactly as the desktop Jak 1 dispatcher does.
  if (dma.ended()) {
    return;
  }
  dma.read_and_advance();
  if (dma.ended()) {
    return;
  }
  dma.read_and_advance();
  if (dma.ended()) {
    return;
  }
  dma.read_and_advance();

  const u32 bucket_zero = ottsel_mobile_jak1_bucket_boundary(chain_offset, 0);
  if (dma.current_tag_offset() != bucket_zero) {
    lg::warn("OTTSEL GENERIC BUCKET: initial dispatch mismatch got=0x{:x} expected=0x{:x}",
             dma.current_tag_offset(), bucket_zero);
    return;
  }

  for (u32 bucket_id = 0; bucket_id < 70; ++bucket_id) {
    const bool generic = ottsel_mobile_is_jak1_generic_bucket(bucket_id);
    const u32 next_boundary =
        ottsel_mobile_jak1_bucket_boundary(chain_offset, bucket_id + 1);
    u32 transfers = 0;
    u64 bytes = 0;
    u32 unpack_v4_32 = 0;
    u32 fragment_uploads = 0;
    u32 mscal = 0;
    std::array<u16, 8> entries{};
    u32 entry_count = 0;

    while (!dma.ended() && dma.current_tag_offset() != next_boundary && transfers < 4096) {
      const DmaTransfer transfer = dma.read_and_advance();
      if (generic) {
        ++transfers;
        bytes += transfer.size_bytes;
        const VifCode v0 = transfer.vifcode0();
        const VifCode v1 = transfer.vifcode1();
        if (v1.kind == VifCode::Kind::UNPACK_V4_32) {
          ++unpack_v4_32;
          if (transfer.size_bytes > 160) {
            ++fragment_uploads;
          }
        }
        const VifCode commands[2] = {v0, v1};
        for (const auto& command : commands) {
          if (command.kind == VifCode::Kind::MSCAL || command.kind == VifCode::Kind::MSCALF) {
            ++mscal;
            if (entry_count < entries.size()) {
              entries[entry_count++] = command.immediate;
            }
          }
        }
      }
    }

    if (dma.current_tag_offset() != next_boundary) {
      lg::warn("OTTSEL GENERIC BUCKET: walk stopped id={} at=0x{:x} expected=0x{:x} ended={}",
               bucket_id, dma.current_tag_offset(), next_boundary, dma.ended());
      return;
    }

    if (generic) {
      std::string entry_text;
      for (u32 i = 0; i < entry_count; ++i) {
        entry_text += i ? "," : "";
        entry_text += std::to_string(entries[i]);
      }
      lg::info("OTTSEL GENERIC BUCKET: id={} transfers={} bytes={} unpack-v4-32={} "
               "fragment-uploads={} mscal={} entries=[{}]",
               bucket_id, transfers, bytes, unpack_v4_32, fragment_uploads, mscal, entry_text);
    }
  }
}
}  // namespace

void gfx_send_chain(const void* data, u32 offset) {
  if (!data) {
    return;
  }
  // The native Metal path owns TIE/TFRAG/Sprite3 composition. The VU1/GIF
  // interpreter below is retained for SDL-only renderer diagnostics, but it
  // must not consume the game thread in the product path when an empty or
  // incomplete fragment list makes the microcode loop to its safety cap.
  const bool run_cpu_vu_diagnostics =
      !g_metal || std::getenv("OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS") != nullptr;
  static bool cpu_vu_policy_logged = false;
  if (!cpu_vu_policy_logged) {
    cpu_vu_policy_logged = true;
    lg::info("OTTSEL VU1: cpu-diagnostic-path={}", run_cpu_vu_diagnostics ? "enabled" : "disabled");
  }
  static bool bucket_trace_consumed = false;
  if (!bucket_trace_consumed) {
    const std::string bucket_trace_path = ottsel_ios_writable_dir() + "ottsel-trace-mobile-buckets";
    if (access(bucket_trace_path.c_str(), F_OK) == 0) {
      unlink(bucket_trace_path.c_str());
      bucket_trace_consumed = true;
      for (u32 index = 65; index < 70; ++index) {
        DmaTag tag(*(const u64*)((const u8*)data + offset + index * 16));
        lg::info("OTTSEL BUCKET: index={} chain=0x{:x} qwc={} kind={} addr=0x{:x}", index,
                 offset, tag.qwc, (u32)tag.kind, tag.addr);
        if ((index == 66 || index == 67) && tag.addr) {
          DmaFollower debug_dma(data, tag.addr);
          for (u32 transfer_index = 0; transfer_index < 64 && !debug_dma.ended(); ++transfer_index) {
            DmaTransfer transfer = debug_dma.read_and_advance();
            u32 w0 = transfer.size_bytes >= 4 ? *(const u32*)transfer.data : 0;
            u32 w1 = transfer.size_bytes >= 8 ? *(const u32*)(transfer.data + 4) : 0;
            lg::info("OTTSEL BUCKET{}: transfer={} size={} vif0=0x{:08x} vif1=0x{:08x} "
                     "data={:08x}/{:08x}",
                     index, transfer_index, transfer.size_bytes, transfer.vif0(), transfer.vif1(), w0,
                     w1);
          }
        }
      }
    }
  }
  static OttselGifDecoder g_dec;
  static OttselRaster g_raster;
  if (g_raster.fb.empty()) {
    g_raster.fb.assign((size_t)g_raster.fb_w * g_raster.fb_h * 4, 0);
  }
  g_dec.rst = &g_raster;
  g_mobile_chain_no++;
  g_dec.chain_no = g_mobile_chain_no;
  const std::string direct_trace_path = ottsel_ios_writable_dir() + "ottsel-trace-mobile-direct";
  const std::string direct_product_path =
      ottsel_ios_writable_dir() + "ottsel-enable-native-direct-product";
  if (!g_mobile_direct_trace.active &&
      (access(direct_trace_path.c_str(), F_OK) == 0 ||
       access(direct_product_path.c_str(), F_OK) == 0)) {
    const bool native_product = access(direct_product_path.c_str(), F_OK) == 0;
    unlink(native_product ? direct_product_path.c_str() : direct_trace_path.c_str());
    g_mobile_direct_trace = {};
    g_mobile_direct_trace.active = true;
    g_mobile_direct_trace.native_product = native_product;
    g_mobile_direct_trace.start_chain = g_mobile_chain_no;
    g_mobile_direct_trace.draw_start = g_raster.draw_count;
    g_dec.ordered_ir.clear();
    lg::info("OTTSEL MOBILE DIRECT: {} accepted at chain={} draw-start={}",
             native_product ? "native product" : "trace", g_mobile_chain_no,
             g_mobile_direct_trace.draw_start);
  }
  static bool direct_fixture_triggered = false;
  const std::string direct_fixture_path =
      ottsel_ios_writable_dir() + "ottsel-trace-metal-direct-fixture";
  if (!direct_fixture_triggered && g_metal && access(direct_fixture_path.c_str(), F_OK) == 0) {
    unlink(direct_fixture_path.c_str());
    direct_fixture_triggered = true;
    // Generated 2x2 red/transparent checkerboard; no protected texels or
    // CPU-raster output enter this native Metal fixture path.
    static constexpr unsigned char kDirectFixtureImage[16] = {
        255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 255};
    static constexpr float kDirectFixtureColor[4] = {1.f, 1.f, 1.f, 1.f};
    ottsel_metal_set_direct_fixture(g_metal, kDirectFixtureImage, 2, 2, 0, 0.375f, 0.375f,
                                    0.25f, 0.25f, 0.f, 0.f, 1.f, 1.f,
                                    kDirectFixtureColor);
    lg::info("OTTSEL METAL DIRECT: fixture accepted image=2x2 rect=0.375,0.375,0.25,0.25 "
             "cpu-raster=0");
  }
  const std::string generic_probe_path = ottsel_ios_writable_dir() + "ottsel-probe-generic-vu";
  if (!g_mobile_generic_probe_pending && access(generic_probe_path.c_str(), F_OK) == 0) {
    unlink(generic_probe_path.c_str());
    g_mobile_generic_probe_pending = true;
    lg::info("OTTSEL GENERIC VU: probe accepted; awaiting MSCAL 46");
  }
  const std::string generic_bucket_trace_path =
      ottsel_ios_writable_dir() + "ottsel-trace-generic-buckets";
  if (access(generic_bucket_trace_path.c_str(), F_OK) == 0) {
    unlink(generic_bucket_trace_path.c_str());
    lg::info("OTTSEL GENERIC BUCKET: trace accepted chain={}", g_chain_no + 1);
    trace_mobile_generic_buckets(data, offset);
  }
  // Keep the CPU rasterizer available only for bounded diagnostics while the
  // native Metal scene owns presentation.
  if (g_chain_no % 90 == 1) {
    g_raster.clear(0);
  }
  if (g_chain_no % 45 == 0) {
    static u32 ottsel_dc_logged = 0;
    if (ottsel_dc_logged++ < 6) {
      lg::info("OTTSEL RSTR: chain={} draw_count={} fb={}x{}", g_chain_no, g_raster.draw_count,
               g_raster.fb_w, g_raster.fb_h);
    }
  }
  // BOT22c: per-boundary VU1/raster stats so the post-activation pipeline is
  // visible (the old 20-run VU1 log cap exhausted during loading).  Also
  // refill a small PRIM log budget each boundary.
  static u32 g_vu1_runs_period = 0;
  static u32 g_vu1_nonzero_period = 0;
  static u32 g_vu1_capped_period = 0;
  static u32 g_vu1_xgkicks_period = 0;
  static int g_vu1_last_pc = 0;
  static u64 g_vu1_gifwords_period = 0;
  if (g_chain_no % 90 == 0) {
    lg::info("OTTSEL VU1STAT: chain={} vu1-runs={} capped={} xgkicks={} last-pc={} nonzero-gif={} "
             "gif-words={} draws={}",
             g_chain_no, g_vu1_runs_period, g_vu1_capped_period, g_vu1_xgkicks_period,
             g_vu1_last_pc, g_vu1_nonzero_period, g_vu1_gifwords_period, g_raster.draw_count);
    g_vu1_runs_period = 0;
    g_vu1_nonzero_period = 0;
    g_vu1_capped_period = 0;
    g_vu1_xgkicks_period = 0;
    g_vu1_gifwords_period = 0;
    g_dec.prims_logged = g_dec.prims_logged > 8 ? g_dec.prims_logged - 8 : 0u;
  }
  if (g_mobile_direct_trace.active &&
      g_chain_no - g_mobile_direct_trace.start_chain >= kMobileDirectTraceChains) {
    lg::info("OTTSEL MOBILE DIRECT: summary chains={} transfers={} bytes={} gif-tags={} "
             "packed={} reglist={} image={} sprites={} triangles={} strips={} "
             "sprite-mscal(init={} world={} hud={} 3d={} other={}) raster-draws={}→{}",
             kMobileDirectTraceChains,
             g_mobile_direct_trace.direct_transfers, g_mobile_direct_trace.direct_bytes,
             g_mobile_direct_trace.gif_tags, g_mobile_direct_trace.packed_tags,
             g_mobile_direct_trace.reglist_tags, g_mobile_direct_trace.image_tags,
             g_mobile_direct_trace.sprites, g_mobile_direct_trace.triangles,
             g_mobile_direct_trace.strips, g_mobile_direct_trace.mscal_init,
             g_mobile_direct_trace.mscal_2d_world, g_mobile_direct_trace.mscal_2d_hud,
             g_mobile_direct_trace.mscal_3d, g_mobile_direct_trace.mscal_other,
             g_mobile_direct_trace.draw_start, g_raster.draw_count);
    if (g_mobile_direct_trace.other_mscal_entry_count) {
      std::string entries;
      for (u32 i = 0; i < g_mobile_direct_trace.other_mscal_entry_count; ++i) {
        entries += i ? "," : "";
        entries += std::to_string(g_mobile_direct_trace.other_mscal_entries[i]);
      }
      lg::info("OTTSEL MOBILE DIRECT: first non-sprite MSCAL entries={}", entries);
    }
    g_mobile_direct_trace.active = false;
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
    std::string path = ottsel_ios_writable_dir() + "tfrag-vu-data.bin";
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
    std::string rpath = ottsel_ios_writable_dir() + "tfrag-vif-replay.bin";
    g_vif_replay = fopen(rpath.c_str(), "wb");
  }
  const u8* base = (const u8*)data;
  DmaFollower dma(base, offset);
  // S2.2 VU1 emulation: process the DMA chain's VIF commands to build VU
  // memory and run the tfrag microcode on MSCAL/MSCALF, feeding the XGKICK
  // output (gif_out) through the same GIF decoder/rasterizer as DIRECT data.
  static ottsel_vu1::Vu1State g_vu;
  static ottsel_vu1::Vu1State g_vu_generic;
  static bool g_vu_init = false;
  static bool g_vu_generic_init = false;
  static bool g_ottsel_spr_ran = false;
  static bool g_readlog_hook_set = false;
  if (!g_readlog_hook_set) {
    g_readlog_hook_set = true;
    ottsel_vu1::ottsel_vu1_set_readlog_hook([](const char* msg) { lg::info("{}", msg); });
  }
  static u32 g_vu_top = 0;   // VIF TOP register (frag-list base, XTOP)
  static u32 g_vu_tops = 0;  // VIF TOPS register
  static u32 g_vu_vu_stcycl = 0x404;  // STCYCL cl<<8|wl
  static u32 g_vu_vu1_perdraw_consts = 0;  // BOT21g: 0x381-const uploads logged
  static bool g_ottsel_spr_pending = false;
  static u32 g_ottsel_spr_source = 0;
  static u32 g_ottsel_spr_qwc = 0;
  if (!g_vu_init) {
    g_vu_init = true;
    g_vu.code_len = ottsel_vu1::kTfragCodeWords;
    for (int i = 0; i < g_vu.code_len; i++) {
      g_vu.code[i] = ottsel_vu1::kTfragMicrocode[i];
    }
  }
  if (!g_vu_generic_init) {
    g_vu_generic_init = true;
    g_vu_generic.code_len = ottsel_vu1::kGenericCodeWords;
    for (int i = 0; i < g_vu_generic.code_len; i++) {
      g_vu_generic.code[i] = ottsel_vu1::kGenericMicrocode[i];
    }
  }
  // The mips2c producer records the fake-scratchpad address and qword count
  // of its real SPR TO copy in tfrag-work+0xb8/+0xbc. This is not an EE DMA
  // chain; inspect the copied source independently before decoding it.
  {
    static bool ottsel_spr_done = false;
    if (!ottsel_spr_done && g_ee_main_mem) {
      auto twi = g_pc_port_funcs.intern_from_c("*tfrag-work*");
      if (twi.offset) {
        u32 tw = 0;
        memcpy(&tw, g_ee_main_mem + twi.offset, 4);
        if (tw) {
          const u8* twp = g_ee_main_mem + tw;
          u32 source = *(u32*)(twp + 0xb8);
          u32 qwcv = *(u32*)(twp + 0xbc);
          if (source >= 0x080000 && source < 0x08000000 && qwcv > 0 && qwcv <= 256) {
            ottsel_spr_done = true;
            g_ottsel_spr_source = source;
            g_ottsel_spr_qwc = qwcv;
            g_ottsel_spr_pending = true;
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
        if (g_mobile_direct_trace.active) {
          switch (v.immediate) {
            case 0:
              g_mobile_direct_trace.mscal_init++;
              break;
            case 3:
              g_mobile_direct_trace.mscal_2d_world++;
              break;
            case 109:
              g_mobile_direct_trace.mscal_2d_hud++;
              break;
            case 211:
              g_mobile_direct_trace.mscal_3d++;
              break;
            default:
              g_mobile_direct_trace.mscal_other++;
              if (g_mobile_direct_trace.other_mscal_entry_count <
                  g_mobile_direct_trace.other_mscal_entries.size()) {
                g_mobile_direct_trace
                    .other_mscal_entries[g_mobile_direct_trace.other_mscal_entry_count++] =
                    v.immediate;
              }
              break;
          }
        }
        // The microcode's XTOP reads the VIF TOP register; run it with the
        // current frag-list base.
        static u32 ottsel_vu1_runs = 0;
        ottsel_vu1::set_top(g_vu_top);
        // This is a diagnostic-only discriminator for the next mobile bucket:
        // it runs one live MSCAL 46 packet through the retail generic VU
        // program without feeding its output to the renderer.  The normal
        // PC-port TFRAG/TIE path below remains unchanged.
        if (g_mobile_generic_probe_pending && v.immediate == 46) {
          g_mobile_generic_probe_pending = false;
          memcpy(g_vu_generic.data, g_vu.data, sizeof(g_vu.data));
          memset(g_vu_generic.vf, 0, sizeof(g_vu_generic.vf));
          memset(g_vu_generic.vi, 0, sizeof(g_vu_generic.vi));
          memset(g_vu_generic.acc, 0, sizeof(g_vu_generic.acc));
          g_vu_generic.q = 0;
          g_vu_generic.p = 0;
          g_vu_generic.i_reg = 0;
          g_vu_generic.status = 0;
          g_vu_generic.pc = 46;
          g_vu_generic.gif_out.clear();
          ottsel_vu1::execute(g_vu_generic, 50000);
          lg::info("OTTSEL GENERIC VU: MSCAL 46 executed={} capped={} pc={} xgkicks={} gif={}",
                   g_vu_generic.executed_instructions, g_vu_generic.hit_instruction_limit,
                   g_vu_generic.pc, g_vu_generic.xgkick_count, g_vu_generic.gif_out.size());
        }
        // BOT21g: the game's tfrag draw (tfrag-end-buffer + ln's saved
        // last-call) issues MSCALF 0, and the per-draw chains in the live
        // replay carry MSCALF imm=0 -- so the tfrag microcode entry is
        // pc = imm*2 = 0, the L11 header path (`iaddiu vi14, vi00, 0x2a0`
        // -- frag-list base 0x2a0, matrix at 0x2a5..0x2a8, tfrag-data at
        // the absolute 0x290).  BOT21d's pc=8 (L3, `xtop vi14`) is the
        // far stored-stream variant the SPR scaffold calls manually below
        // (g_vu.pc = 8) and does NOT apply to the per-draw MSCALF 0s.
        // MSCAL's immediate is already a VU microinstruction address.  The
        // VIF stream's 6/8/10/... draw entries target the dispatcher slots
        // directly; multiplying by two jumps into unrelated instructions.
        g_vu.pc = v.immediate & 0x7ff;
        g_vu.gif_out.clear();
        // The zero entry is TFRAG's setup pass.  Capture the first real
        // dispatcher call separately so a missing SPR->VIF1 handoff can be
        // distinguished from an interpreter failure without tracing every
        // frame.
        static bool ottsel_logged_nonzero_tfrag_entry = false;
        const bool first_nonzero_tfrag_entry =
            v.immediate && !ottsel_logged_nonzero_tfrag_entry;
        if (first_nonzero_tfrag_entry) {
          ottsel_logged_nonzero_tfrag_entry = true;
          lg::info("OTTSEL VU1DRAW: imm=0x{:x} top=0x{:x} mem0={:08x}/{:08x}/{:08x}/{:08x} "
                   "kick={:08x}/{:08x}/{:08x}/{:08x}",
                   v.immediate, g_vu_top, g_vu.data[0], g_vu.data[1], g_vu.data[2],
                   g_vu.data[3], g_vu.data[0x2a0 * 4], g_vu.data[0x2a0 * 4 + 1],
                   g_vu.data[0x2a0 * 4 + 2], g_vu.data[0x2a0 * 4 + 3]);
        }
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
        if (run_cpu_vu_diagnostics) {
          ottsel_vu1::execute(g_vu, g_ottsel_spr_ran ? 400000 : 50000);
        } else {
          g_vu.executed_instructions = 0;
          g_vu.hit_instruction_limit = false;
          g_vu.xgkick_count = 0;
          g_vu.gif_out.clear();
        }
        ottsel_vu1::ottsel_vu1_set_readlog(0);
        if (first_nonzero_tfrag_entry) {
          lg::info("OTTSEL VU1DRAW: result executed={} capped={} pc={} xgkicks={} gif={} "
                   "vi1=0x{:x} vi6=0x{:x} vf3={:08x}/{:08x}/{:08x}/{:08x}",
                   g_vu.executed_instructions, g_vu.hit_instruction_limit, g_vu.pc,
                   g_vu.xgkick_count, g_vu.gif_out.size(), g_vu.vi[1], g_vu.vi[6],
                   g_vu.vf[3].u[0], g_vu.vf[3].u[1], g_vu.vf[3].u[2], g_vu.vf[3].u[3]);
        }
        if (ottsel_vu1_runs < 20) {
          ottsel_vu1_runs++;
          lg::info("OTTSEL VU1: run#{} mscal imm=0x{:x} top=0x{:x} pc={} gif_out={} "
                   "frag[0..2]=0x{:x}/0x{:x}/0x{:x}",
                   ottsel_vu1_runs, v.immediate, g_vu_top, g_vu.pc, g_vu.gif_out.size(),
                   g_vu.data[0 * 4], g_vu.data[1 * 4], g_vu.data[2 * 4]);
        }
        g_vu1_runs_period++;
        g_vu1_capped_period += g_vu.hit_instruction_limit ? 1 : 0;
        g_vu1_xgkicks_period += g_vu.xgkick_count;
        g_vu1_last_pc = g_vu.pc;
        if (!g_vu.gif_out.empty()) {
          g_vu1_nonzero_period++;
          g_vu1_gifwords_period += g_vu.gif_out.size();
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
        // dest = (addr?TOPS:TOP) + (imm & 0x3ff); the VIF UNPACK addr/flg
        // flag is bit 15 (0x8000) of the command word, not bit 21 (which
        // lives inside the num field).  BOT21g verified against the live
        // replay: UNPACK 0x3d4 n41 has the flag set (TOPS-relative), while
        // 0x160/0x384/0x290/0x381/0x5 are TOP-relative.
        u32 base = (vifword & 0x8000) ? g_vu_tops : g_vu_top;
        u32 dest = (base + (v.immediate & 0x3ff)) & 0xfff;
        if (v.kind == VifCode::Kind::UNPACK_V4_8) {
          const u32 count = v.num ? v.num : 256;
          const VifCodeUnpack unpack(v);
          const VifCodeStcycl cycle{VifCode(g_vu_vu_stcycl)};
          if (!ottsel_vu1::unpack_v4_8(g_vu.data, sizeof(g_vu.data) / sizeof(g_vu.data[0]) / 4, payload,
                                        payload_size, dest, count, unpack.is_unsigned, cycle.cl,
                                        cycle.wl)) {
            static u32 failed_v4_8 = 0;
            if (failed_v4_8++ < 4) {
              lg::warn("OTTSEL VIF: malformed V4-8 num={} bytes={} dest=0x{:x} cycle=0x{:04x}",
                       count, payload_size, dest, g_vu_vu_stcycl);
            }
          }
          break;
        }
        u32 qwords = std::min(payload_size / 16, 4096u - dest);
        if (qwords && dest < 4096) {
          memcpy(&g_vu.data[dest * 4], payload, qwords * 16);
          // BOT21g: the const block at VU 0x381 (10 qwords, first word
          // 0x7f7fffff) is the TFRAG per-draw path's own const (uploaded by
          // tfrag-init-buffer; the L11 microcode reads it as tfrag-data
          // extension), NOT the generic tie/merc renderer.  The generic
          // microcode run for these chains produced zero gif_out and was a
          // misattribution (verified offline against the full VIF replay:
          // the tfrag pc0 program is the only one with any output).
          if (dest == 0x381 && qwords >= 4 && g_vu_vu1_perdraw_consts < 4) {
            g_vu_vu1_perdraw_consts++;
            lg::info("OTTSEL CONST381: chain={} qw={} c0={:08x} c1={:08x} c2={:08x} c3={:08x}",
                     g_chain_no, qwords, g_vu.data[0x381 * 4], g_vu.data[0x381 * 4 + 1],
                     g_vu.data[0x381 * 4 + 2], g_vu.data[0x381 * 4 + 3]);
          }
        }
        break;
      }
      default:
        break;
    }
  };
  if (g_ottsel_spr_pending) {
    g_ottsel_spr_pending = false;
    lg::info("OTTSEL SPR: observed scratchpad source=0x{:x} qwc={}; decode disabled",
             g_ottsel_spr_source, g_ottsel_spr_qwc);
    // One-shot, read-only producer trace. Record the actual copied qwords;
    // never feed them into ottsel_handle_vif until their transfer semantics
    // are decoded independently.
    static bool spr_dma_trace_consumed = false;
    if (!spr_dma_trace_consumed && std::getenv("OTTSEL_TRACE_SPR_DMA") && g_ee_main_mem) {
      spr_dma_trace_consumed = true;
      const u32 count = std::min(g_ottsel_spr_qwc, 16u);
      for (u32 index = 0; index < count; ++index) {
        const u32* words = (const u32*)(g_ee_main_mem + g_ottsel_spr_source + index * 16);
        lg::info("OTTSEL SPR SOURCE[{}]: {:08x} {:08x} {:08x} {:08x}", index, words[0],
                 words[1], words[2], words[3]);
      }
    }
  }
  unsigned int count = 0;
  while (ottsel_mobile_dma_decode_can_continue(dma.ended(), count)) {
    DmaTransfer t = dma.read_and_advance();
    count++;
    if (t.size_bytes == 0) {
      if (g_vif_replay && g_vif_replay_recs < 200000) {
        u32 rec[4] = {t.vif0(), t.vif1(), 0, 0};
        fwrite(rec, 16, 1, g_vif_replay);
        g_vif_replay_recs++;
      }
      // DMA control tags carry no payload, but their VIF commands still
      // update BASE/OFFSET/STCYCL before the following payload/MSCAL tag.
      // Skipping them left the mobile VU decoder on stale addressing and
      // detached the generated frag header from its dispatcher call.
      ottsel_handle_vif(t.vif0(), t.data, 0);
      ottsel_handle_vif(t.vif1(), t.data, 0);
      VifCode v0(t.vif0());
      VifCode v1(t.vif1());
      static u32 ottsel_vifctl = 0;
      if (ottsel_vifctl < 24 &&
          (v0.kind == VifCode::Kind::BASE || v0.kind == VifCode::Kind::OFFSET ||
           v0.kind == VifCode::Kind::STCYCL || v1.kind == VifCode::Kind::BASE ||
           v1.kind == VifCode::Kind::OFFSET || v1.kind == VifCode::Kind::STCYCL)) {
        ++ottsel_vifctl;
        lg::info("OTTSEL VIFCTL[{}/24]: chain={} t{} v0=0x{:x}(k{}) v1=0x{:x}(k{})",
                 ottsel_vifctl, g_chain_no, count, t.vif0(), (u32)v0.kind, t.vif1(),
                 (u32)v1.kind);
      }
      continue;
    }
    if (g_vif_replay && g_vif_replay_recs < 200000 && t.size_bytes <= 8192) {
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
    if (v0.kind == VifCode::Kind::PC_PORT || v1.kind == VifCode::Kind::PC_PORT) {
      capture_mobile_merc(t);
    }
    if ((v0.kind == VifCode::Kind::PC_PORT || v1.kind == VifCode::Kind::PC_PORT) &&
        t.size_bytes == sizeof(OttselPcPortData)) {
      g_mobile_camera_last_chain = g_chain_no;
      g_mobile_camera_last_transfer = count;
      capture_mobile_camera(t.data, t.size_bytes);
    }
    static u32 native_merc_trace_count = 0;
    static u32 native_merc_trace_invalid_count = 0;
    static std::unordered_set<std::string> native_merc_trace_names;
    if (!g_mobile_merc_trace) {
      const std::string trace_path = ottsel_ios_writable_dir() + "ottsel-trace-native-merc";
      if (access(trace_path.c_str(), F_OK) == 0) {
        unlink(trace_path.c_str());
        g_mobile_merc_trace = true;
        native_merc_trace_count = 0;
        native_merc_trace_invalid_count = 0;
        native_merc_trace_names.clear();
        lg::info("OTTSEL MERC NATIVE TRACE: bounded PC_PORT ledger armed");
      }
    }
    if (g_mobile_merc_trace && native_merc_trace_count < 32 &&
        (v0.kind == VifCode::Kind::PC_PORT || v1.kind == VifCode::Kind::PC_PORT)) {
      const size_t name_len = t.size_bytes ? strnlen((const char*)t.data, std::min<size_t>(128, t.size_bytes)) : 0;
      bool printable_name = name_len > 0 && name_len < 128;
      for (size_t i = 0; printable_name && i < name_len; ++i) {
        printable_name = std::isprint((unsigned char)t.data[i]);
      }
      const std::string name = printable_name ? std::string((const char*)t.data, name_len)
                                              : "<non-text>";
      bool known_model = false;
      if (printable_name) {
        for (const auto& [level_name, level_ptr] : g_mobile_levels) {
          for (const auto& candidate : level_ptr->merc_data.models) {
            if (candidate.name == name) {
              known_model = true;
              break;
            }
          }
          if (known_model) {
            break;
          }
        }
      }
      const u32 w0 = t.size_bytes >= 4 ? *(const u32*)t.data : 0;
      const u32 w1 = t.size_bytes >= 8 ? *(const u32*)(t.data + 4) : 0;
      if (known_model) {
        if (native_merc_trace_names.insert(name).second) {
          lg::info("OTTSEL MERC PC_PORT VALID: chain={} transfer={} size={} vif0=0x{:x} vif1=0x{:x} "
                   "name='{}' words=0x{:08x}/0x{:08x}",
                   g_chain_no, count, t.size_bytes, t.vif0(), t.vif1(), name, w0, w1);
          ++native_merc_trace_count;
        }
      } else if (native_merc_trace_invalid_count++ < 8) {
        lg::info("OTTSEL MERC PC_PORT ignored: chain={} transfer={} size={} vif0=0x{:x} vif1=0x{:x} "
                 "name='{}' words=0x{:08x}/0x{:08x}",
                 g_chain_no, count, t.size_bytes, t.vif0(), t.vif1(), name, w0, w1);
      }
      if (native_merc_trace_count == 32) {
        g_mobile_merc_trace = false;
        lg::info("OTTSEL MERC NATIVE TRACE: ledger complete");
      }
    }
    // Full-transfer capture of the first tfrag-bearing chain (all vif kinds,
    // including qwc=0 base/offset and any frag-list unpacks).
    static u32 ottsel_full_chain = 0;
    if (g_chain_no <= 4) {
      lg::info("OTTSEL FULL: chain={} t{} size={} v0=0x{:x}(k{}) v1=0x{:x}(k{}) off=0x{:x}",
               g_chain_no, count, t.size_bytes, t.vif0(), (u32)v0.kind, t.vif1(), (u32)v1.kind,
               off);
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
      // BOT21m: the *vu1-enable-user* mask at the draw phase (the tie draw
      // is gated on its tie/generic bits).
      {
        auto v1s = g_pc_port_funcs.intern_from_c("*vu1-enable-user*");
        u32 v = 0;
        if (v1s.offset) {
          memcpy(&v, g_ee_main_mem + v1s.offset, 4);
        }
        lg::info("OTTSEL VU1MASK: draw-phase *vu1-enable-user* = 0x{:x}", v);
      }
      // BOT21i: after the level load, read the linked village1-vis object
      // (the last vi1.DGO object = the bsp-header file per the decompiler's
      // get_bsp_file) + the level bsp field.
      // S2.2 BOT21b probe: dump the compiled draw-drawable-tree-tfrag
      // function so the per-draw VIF emission can be attributed (the
      // goal_src mips2c ln call is commented out, yet per-draw UNPACKs
      // flow).  Disassemble the ARM64 words offline.
      for (const char* nm : {"draw-drawable-tree-tfrag", "ln", "draw-inline-array-tfrag-near",
                             "tfrag-init-buffer", "draw-drawable-tree-trans-tfrag"}) {
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
    // BOT21n: sample the background-work tree counts periodically (per
    // frame) so the draw-phase values can be seen.
    {
      static u32 ottsel_bg_samples = 0;
      static u32 ottsel_bg_logs = 0;
      ottsel_bg_samples++;
      auto bws = g_pc_port_funcs.intern_from_c("*background-work*");
      u32 bw = 0;
      if (bws.offset) {
        memcpy(&bw, g_ee_main_mem + bws.offset, 4);
      }
      if (ottsel_mobile_log_within_budget(ottsel_bg_logs, 8) && bw >= 0x080000 &&
          bw < 0x08000000 && (ottsel_bg_samples % 1500) == 0) {
        ++ottsel_bg_logs;
        lg::info("OTTSEL BGWORK: bg=0x{:x} tfrag-count=0x{:x} tfrag0=0x{:x} tie-count@476=0x{:x}"
                 " tie0@480=0x{:x}",
                 bw, *(u32*)(g_ee_main_mem + bw), *(u32*)(g_ee_main_mem + bw + 4),
                 *(u32*)(g_ee_main_mem + bw + 476), *(u32*)(g_ee_main_mem + bw + 480));
      }
    }
    // BOT22: per-frame level status sampler.  Ground truth from the level
    // deftype: the inline kheap is 16-aligned at mem+32, so from the slot's
    // MEM start: name@+4, index@+16, status@+20, heap@+32..48, bsp@+48.
    // loading-level is level-group ref+8; slots start at grp_ref+92, each
    // 0xa30.  Statuses are decoded by interned symbol address.
    {
      static u32 ottsel_ls_samples = 0;
      static u32 ottsel_ls_logs = 0;
      ottsel_ls_samples++;
      if (ottsel_mobile_log_within_budget(ottsel_ls_logs, 8) && g_ee_main_mem &&
          (ottsel_ls_samples % 1500) == 0) {
        auto lvs = g_pc_port_funcs.intern_from_c("*level*");
        auto dps = g_pc_port_funcs.intern_from_c("*dproc*");
        u32 grp = 0, dproc = 0;
        if (lvs.offset) memcpy(&grp, g_ee_main_mem + lvs.offset, 4);
        if (dps.offset) memcpy(&dproc, g_ee_main_mem + dps.offset, 4);
        if (grp >= 0x080000 && grp < 0x08000000) {
          static const char* kStatusNames[8] = {"inactive", "loading",  "loading-bt",
                                                "loading-done", "loaded", "login",
                                                "alive",    "active"};
          static u32 status_syms[8] = {0};
          if (!status_syms[0]) {
            for (int i = 0; i < 8; i++) {
              status_syms[i] = g_pc_port_funcs.intern_from_c(kStatusNames[i]).offset;
            }
          }
          auto decode = [&](u32 v) -> const char* {
            for (int i = 0; i < 8; i++) {
              if (v == status_syms[i]) return kStatusNames[i];
            }
            return "?";
          };
          u32 ll = *(u32*)(g_ee_main_mem + grp + 8);
          char buf[256];
          int n = 0;
          for (int slot = 0; slot < 3 && n < (int)sizeof(buf) - 48; slot++) {
            u32 so = grp + 92 + slot * 0xa30;  // slot MEM start
            u32 st = *(u32*)(g_ee_main_mem + so + 20);
            u32 bsp = *(u32*)(g_ee_main_mem + so + 48);
            n += snprintf(buf + n, sizeof(buf) - n, "slot%d=%s bsp=0x%x ", slot, decode(st), bsp);
          }
          ++ottsel_ls_logs;
          lg::info("OTTSEL LEVELSTAT: {}loading-level=0x{:x} dproc=0x{:x}", buf, ll, dproc);
        }
      }
    }
    // BOT22b: after a synthetic press, densely log the GOAL-visible cpad0
    // state (valid, button0 raw, abs[0], rel[0]) + *master-mode* so the
    // edge path (scePadRead -> service-cpads -> cpad-pressed?) is verified.
    {
      static int ottsel_pad_watch = 0;
      static u32 ottsel_pw_div = 0;
      if (g_ottsel_synthetic_frames > 0) ottsel_pad_watch = 600;
      if (ottsel_pad_watch > 0 && g_ee_main_mem) {
        ottsel_pad_watch--;
        if ((++ottsel_pw_div % 15) == 0) {
          auto cls = g_pc_port_funcs.intern_from_c("*cpad-list*");
          auto mms = g_pc_port_funcs.intern_from_c("*master-mode*");
          u32 cl = 0, mm = 0;
          if (cls.offset) memcpy(&cl, g_ee_main_mem + cls.offset, 4);
          if (mms.offset) memcpy(&mm, g_ee_main_mem + mms.offset, 4);
          if (cl >= 0x080000 && cl < 0x08000000) {
            u32 pad0 = *(u32*)(g_ee_main_mem + cl + 4);
            if (pad0 >= 0x080000 && pad0 < 0x08000000) {
              lg::info("OTTSEL PADSTAT: valid=0x{:x} button0=0x{:x} abs0=0x{:x} rel0=0x{:x} "
                       "master-mode=0x{:x} synth-left={}",
                       *(u8*)(g_ee_main_mem + pad0 + 0), *(u16*)(g_ee_main_mem + pad0 + 2),
                       *(u32*)(g_ee_main_mem + pad0 + 40), *(u32*)(g_ee_main_mem + pad0 + 56),
                       mm, g_ottsel_synthetic_frames);
            }
          }
        }
      }
    }
    // BOT21i: after the level load, read the linked village1-vis object
    // (the last vi1.DGO object = the bsp-header file per the decompiler's
    // get_bsp_file) so the BSP load result can be checked.  Runs every
    // frame until the served data appears (v4 tag at +64).
    static bool ottsel_obj64_dumped = false;
    if (!ottsel_obj64_dumped && g_ee_main_mem) {
      u32 o = 0x2ef8080u;
      // Wait until the object is LINKED (the v2 link table fixes code[0] =
      // the bsp-header type, so +80 becomes a valid type pointer).
      if (o >= 0x080000 && o < 0x08000000 && *(u32*)(g_ee_main_mem + o + 64) == 0xffffffffu &&
          *(u32*)(g_ee_main_mem + o + 80) >= 0x080000u &&
          *(u32*)(g_ee_main_mem + o + 80) < 0x08000000u) {
        ottsel_obj64_dumped = true;
        lg::info("OTTSEL OBJ64: obj=0x{:x} +56..96 = {:08x} {:08x} {:08x} {:08x} | {:08x} "
                 "{:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                 o, *(u32*)(g_ee_main_mem + o + 56), *(u32*)(g_ee_main_mem + o + 60),
                 *(u32*)(g_ee_main_mem + o + 64), *(u32*)(g_ee_main_mem + o + 68),
                 *(u32*)(g_ee_main_mem + o + 72), *(u32*)(g_ee_main_mem + o + 76),
                 *(u32*)(g_ee_main_mem + o + 80), *(u32*)(g_ee_main_mem + o + 84),
                 *(u32*)(g_ee_main_mem + o + 88), *(u32*)(g_ee_main_mem + o + 92),
                 *(u32*)(g_ee_main_mem + o + 96), *(u32*)(g_ee_main_mem + o + 100));
        // BOT21i: the linked bsp-header candidate: type at +80, then the
        // file-info overlay: file-type sym @+84, file-name @+88,
        // major-version @+92, minor-version @+96.
        u32 type = *(u32*)(g_ee_main_mem + o + 80);
        lg::info("OTTSEL BSPHDR: type=0x{:x} info-filetype=0x{:x} major=0x{:x} minor=0x{:x} "
                 "b0={:02x} b1={:02x}",
                 type, *(u32*)(g_ee_main_mem + o + 84), *(u32*)(g_ee_main_mem + o + 92),
                 *(u32*)(g_ee_main_mem + o + 96), *(u8*)(g_ee_main_mem + o + 84),
                 *(u8*)(g_ee_main_mem + o + 85));
        if (type >= 0x080000 && type < 0x08000000) {
          const u8* t = g_ee_main_mem + type;
          lg::info("OTTSEL BSPTYPE: +0..31 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                   "{:08x}",
                   *(u32*)(t + 0), *(u32*)(t + 4), *(u32*)(t + 8), *(u32*)(t + 12),
                   *(u32*)(t + 16), *(u32*)(t + 20), *(u32*)(t + 24), *(u32*)(t + 28));
          lg::info("OTTSEL BSPTYPE: +32..63 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                   "{:08x}",
                   *(u32*)(t + 32), *(u32*)(t + 36), *(u32*)(t + 40), *(u32*)(t + 44),
                   *(u32*)(t + 48), *(u32*)(t + 52), *(u32*)(t + 56), *(u32*)(t + 60));
          // BOT21q: dump the bsp-header relocate method code (the type's
          // method-table[7] = 0x041e01b4) for offline disassembly -- the
          // checks (file-type/version) + the (-> loading-level bsp) set.
          u32 reloc = *(u32*)(t + 48);
          if (reloc >= 0x080000 && reloc < 0x08000000) {
            const u8* rc = g_ee_main_mem + reloc;
            // BOT21r: dump the full relocate (512 bytes) for offline
            // disassembly of the file-type/version checks + the bsp set.
            for (int off = 0; off < 512; off += 64) {
              lg::info("OTTSEL BSPRELOC {:03x}: {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                       "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                       off, *(u32*)(rc + off), *(u32*)(rc + off + 4), *(u32*)(rc + off + 8),
                       *(u32*)(rc + off + 12), *(u32*)(rc + off + 16), *(u32*)(rc + off + 20),
                       *(u32*)(rc + off + 24), *(u32*)(rc + off + 28), *(u32*)(rc + off + 32),
                       *(u32*)(rc + off + 36), *(u32*)(rc + off + 40), *(u32*)(rc + off + 44),
                       *(u32*)(rc + off + 48), *(u32*)(rc + off + 52), *(u32*)(rc + off + 56),
                       *(u32*)(rc + off + 60));
            }
          }
          u32 nm = *(u32*)(t + 4);
          if (nm >= 0x080000 && nm < 0x08000000) {
            const char* s = (const char*)(g_ee_main_mem + nm);
            lg::info("OTTSEL BSPTYPE name-str(0x{:x}): '{}'", nm, std::string(s, strnlen(s, 48)));
          }
          // The bsp-header's file-type symbol (obj+0 = 0x2ef8264): dump it.
          u32 ftsym = *(u32*)(g_ee_main_mem + o + 84);
          if (ftsym >= 0x080000 && ftsym < 0x08000000) {
            const u8* s2 = g_ee_main_mem + ftsym;
            lg::info("OTTSEL BSPFT: filetype-sym=0x{:x} +0..15 = {:08x} {:08x} {:08x} {:08x}",
                     ftsym, *(u32*)(s2 + 0), *(u32*)(s2 + 4), *(u32*)(s2 + 8), *(u32*)(s2 + 12));
            u32 strp = *(u32*)(s2 + 4);
            if (strp >= 0x080000 && strp < 0x08000000) {
              const char* s3 = (const char*)(g_ee_main_mem + strp + 4);
              lg::info("OTTSEL BSPFT name-str: '{}'", std::string(s3, strnlen(s3, 40)));
            }
          }
          // The bsp-header drawable-trees (entry+36 rel; the linked object
          // fields start at the entry = o+84): dump the tree array.
          u32 dt = *(u32*)(g_ee_main_mem + o + 84 + 36);
          lg::info("OTTSEL BSPDT: drawable-trees=0x{:x}", dt);
          if (dt >= 0x080000 && dt < 0x08000000) {
            const u8* d = g_ee_main_mem + dt;
            lg::info("OTTSEL BSPDT: +0..63 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                     "{:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                     *(u32*)(d + 0), *(u32*)(d + 4), *(u32*)(d + 8), *(u32*)(d + 12),
                     *(u32*)(d + 16), *(u32*)(d + 20), *(u32*)(d + 24), *(u32*)(d + 28),
                     *(u32*)(d + 32), *(u32*)(d + 36), *(u32*)(d + 40), *(u32*)(d + 44),
                     *(u32*)(d + 48), *(u32*)(d + 52), *(u32*)(d + 56), *(u32*)(d + 60));
            // The first 3 trees: dump their type tags and first words.
            for (int ti = 0; ti < 3; ti++) {
              u32 tp = *(u32*)(d + 32 + ti * 4);
              if (tp >= 0x080000 && tp < 0x08000000) {
                const u8* t = g_ee_main_mem + tp;
                lg::info("OTTSEL BSPTREE[{}]: ptr=0x{:x} type-tag=0x{:x} +0..31 = {:08x} {:08x} "
                         "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                         "{:08x} | {:08x} {:08x} {:08x} {:08x}",
                         ti, tp, *(u32*)(t - 4), *(u32*)(t + 0), *(u32*)(t + 4), *(u32*)(t + 8),
                         *(u32*)(t + 12), *(u32*)(t + 16), *(u32*)(t + 20), *(u32*)(t + 24),
                         *(u32*)(t + 28), *(u32*)(t + 32), *(u32*)(t + 36), *(u32*)(t + 40),
                         *(u32*)(t + 44), *(u32*)(t + 48), *(u32*)(t + 52), *(u32*)(t + 56),
                         *(u32*)(t + 60));
                // BOT21j: the tie trees' drawables (the tree's children at
                // +28..+40): dump the first drawable's type + length.
                if (ti >= 1) {
                  for (int ci = 0; ci < 2; ci++) {
                    u32 dp = *(u32*)(t + 28 + ci * 4);
                    if (dp >= 0x080000 && dp < 0x08000000) {
                      const u8* dd = g_ee_main_mem + dp;
                      lg::info("OTTSEL TIEDRAW[{}][{}]: ptr=0x{:x} type-tag=0x{:x} +0..31 = "
                               "{:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | "
                               "{:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                               ti, ci, dp, *(u32*)(dd - 4), *(u32*)(dd + 0), *(u32*)(dd + 4),
                               *(u32*)(dd + 8), *(u32*)(dd + 12), *(u32*)(dd + 16),
                               *(u32*)(dd + 20), *(u32*)(dd + 24), *(u32*)(dd + 28),
                               *(u32*)(dd + 32), *(u32*)(dd + 36), *(u32*)(dd + 40),
                               *(u32*)(dd + 44), *(u32*)(dd + 48), *(u32*)(dd + 52),
                               *(u32*)(dd + 56), *(u32*)(dd + 60));
                    }
                  }
                }
              }
            }
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
    // Bounded VIF sample for the first few relevant transfers.  A prior
    // chain counter only advanced when transfer #1 matched, turning this
    // supposedly narrow trace into megabytes of frame-by-frame noise.
    static u32 ottsel_vifseq_records = 0;
    if (ottsel_vifseq_records < 96 &&
        (v1.kind == VifCode::Kind::UNPACK_V4_32 || v1.kind == VifCode::Kind::STCYCL ||
         v1.kind == VifCode::Kind::MSCAL || v1.kind == VifCode::Kind::MSCALF ||
         v1.kind == VifCode::Kind::MPG || v1.kind == VifCode::Kind::FLUSHA ||
         v1.kind == VifCode::Kind::FLUSHE || v0.kind == VifCode::Kind::STCYCL ||
         v0.kind == VifCode::Kind::MSCAL || v0.kind == VifCode::Kind::MSCALF ||
         v1.kind == VifCode::Kind::DIRECT)) {
      ++ottsel_vifseq_records;
      lg::info("OTTSEL VIFSEQ[{}/96]: chain={} t{} size={} v0=0x{:x}(k{}) v1=0x{:x}(k{} n{}) off=0x{:x}",
               ottsel_vifseq_records, g_chain_no, count,
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
  // Gameplay chains can put the live background camera and foreground Merc
  // requests after the expensive decoder's 512-transfer budget. Continue a
  // lightweight bounded walk that handles only those native PC_PORT packets;
  // running the full VIF/GIF diagnostics through this tail tanks frame pacing.
  while (ottsel_mobile_pc_port_scan_can_continue(dma.ended(), count)) {
    DmaTransfer t = dma.read_and_advance();
    ++count;
    const VifCode v0(t.vif0());
    const VifCode v1(t.vif1());
    if (v0.kind != VifCode::Kind::PC_PORT && v1.kind != VifCode::Kind::PC_PORT) {
      continue;
    }
    capture_mobile_merc(t);
    if (t.size_bytes == sizeof(OttselPcPortData)) {
      g_mobile_camera_last_chain = g_chain_no;
      g_mobile_camera_last_transfer = count;
      capture_mobile_camera(t.data, t.size_bytes);
    }
  }
  if (!dma.ended()) {
    static unsigned int truncated_dma_logs = 0;
    if (ottsel_mobile_log_within_budget(truncated_dma_logs++, 4)) {
      lg::warn("OTTSEL DMA: PC_PORT tail scan hit bounded limit {} on chain {}",
               kOttselMobilePcPortScanBudget, g_chain_no);
    }
  }
  // Jak 1's bucket-66 table entry carries Sprite3 setup; the populated
  // Sprite3 payload begins at the bucket-67 data address and the retained
  // product walk spans through bucket 68. Keep that walk distinct from the
  // bucket-67 Direct packet decoder; classify packet ownership before any
  // Direct consumer is allowed to act.
  const DmaTag setup_bucket(*(const u64*)((const u8*)data + offset + 65 * 16));
  const DmaTag sprite_bucket(*(const u64*)((const u8*)data + offset + 66 * 16));
  const DmaTag debug_bucket(*(const u64*)((const u8*)data + offset + 67 * 16));
  const DmaTag next_bucket(*(const u64*)((const u8*)data + offset + 68 * 16));
  struct SpriteFrameAggregate {
    bool active = false;
    u32 vsync = 0;
    u32 chains = 0;
    MobileSpritePhaseSummary sum{};
  };
  static SpriteFrameAggregate sprite_frame_aggregate;
  const std::string frame_aggregate_path =
      ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-frame-aggregate";
  if (!sprite_frame_aggregate.active && access(frame_aggregate_path.c_str(), F_OK) == 0) {
    unlink(frame_aggregate_path.c_str());
    sprite_frame_aggregate = {};
    sprite_frame_aggregate.active = true;
    sprite_frame_aggregate.vsync = g_ottsel_ios_vsync_count;
    lg::info("OTTSEL SPRITE FRAME AGG: accepted vsync={} chain={}",
             sprite_frame_aggregate.vsync, g_chain_no);
  }
  if (sprite_frame_aggregate.active && sprite_frame_aggregate.chains > 0 &&
      g_ottsel_ios_vsync_count != sprite_frame_aggregate.vsync) {
    lg::info("OTTSEL SPRITE FRAME AGG: complete vsync={} chains={} groups={} sprites={} "
             "world={} hud={} 3d={} other={}",
             sprite_frame_aggregate.vsync, sprite_frame_aggregate.chains,
             sprite_frame_aggregate.sum.groups, sprite_frame_aggregate.sum.sprites,
             sprite_frame_aggregate.sum.world, sprite_frame_aggregate.sum.hud,
             sprite_frame_aggregate.sum.three_d, sprite_frame_aggregate.sum.other);
    for (u32 item = 0; item < sprite_frame_aggregate.sum.item_count; ++item) {
      const auto& entry = sprite_frame_aggregate.sum.items[item];
      const char* phase_name = "other";
      switch (entry.phase) {
        case ottsel::Jak1SpritePhase::World2D:
          phase_name = "world";
          break;
        case ottsel::Jak1SpritePhase::Hud2D:
          phase_name = "hud";
          break;
        case ottsel::Jak1SpritePhase::ThreeD:
          phase_name = "3d";
          break;
        case ottsel::Jak1SpritePhase::Other:
          break;
      }
      lg::info("OTTSEL SPRITE FRAME AGG ITEM: vsync={} item={} phase={} count={} tbp=0x{:x} "
               "psm={} tw={} th={} tex0=0x{:016x} tex0-addr=0x{:016x}",
               sprite_frame_aggregate.vsync, item, phase_name, entry.count, entry.tbp,
               entry.psm, entry.tw, entry.th, entry.tex0, entry.tex0_addr);
    }
    sprite_frame_aggregate.active = false;
  }
  if (sprite_bucket.addr && debug_bucket.addr) {
    MobileSpriteFrameJak1 inherited_frame{};
    MobileSpriteMatrix inherited_matrix{};
    MobileSpriteHudMatrix inherited_hud{};
    bool have_inherited_frame = false;
    bool have_inherited_matrix = false;
    bool have_inherited_hud = false;
    if (sprite_frame_aggregate.active && next_bucket.addr &&
        g_ottsel_ios_vsync_count == sprite_frame_aggregate.vsync) {
      MobileSpritePhaseSummary current{};
      trace_mobile_sprite_phase_bucket(data, sprite_bucket.addr, next_bucket.addr, g_chain_no,
                                       "frame-aggregate", &current, false);
      sprite_frame_aggregate.sum.groups += current.groups;
      sprite_frame_aggregate.sum.sprites += current.sprites;
      sprite_frame_aggregate.sum.world += current.world;
      sprite_frame_aggregate.sum.hud += current.hud;
      sprite_frame_aggregate.sum.three_d += current.three_d;
      sprite_frame_aggregate.sum.other += current.other;
      for (u32 item = 0; item < current.item_count &&
                         sprite_frame_aggregate.sum.item_count <
                             sprite_frame_aggregate.sum.items.size();
           ++item) {
        sprite_frame_aggregate.sum.items[sprite_frame_aggregate.sum.item_count++] =
            current.items[item];
      }
      ++sprite_frame_aggregate.chains;
    }
    static bool sprite_product_window_consumed = false;
    const std::string product_window_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-product-window";
    if (!sprite_product_window_consumed && mobile_sprite_village1_phase() && next_bucket.addr &&
        access(product_window_path.c_str(), F_OK) == 0) {
      unlink(product_window_path.c_str());
      sprite_product_window_consumed = true;
      trace_mobile_sprite_phase_bucket(data, sprite_bucket.addr, next_bucket.addr, g_chain_no,
                                       "product-66-to-68");
    }
    const u32 sprite_drawn =
        render_mobile_sprite_bucket(data, sprite_bucket.addr, next_bucket.addr, g_raster,
                                    g_chain_no, nullptr, nullptr, nullptr, &inherited_frame,
                                    &inherited_matrix, &inherited_hud, &have_inherited_frame,
                                    &have_inherited_matrix, &have_inherited_hud);
    static bool sprite_trace_requested = false;
    if (!sprite_trace_requested) {
      const std::string sprite_trace_path = ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite";
      if (access(sprite_trace_path.c_str(), F_OK) == 0) {
        unlink(sprite_trace_path.c_str());
        sprite_trace_requested = true;
      }
    }
    if (sprite_trace_requested && sprite_drawn > 0) {
      lg::info("OTTSEL SPRITE: chain={} vsync={} group-0 sprites={} debug=0x{:x} next=0x{:x}",
               g_chain_no, g_ottsel_ios_vsync_count, sprite_drawn, sprite_bucket.addr,
               debug_bucket.addr);
      sprite_trace_requested = false;
    }
    if (have_inherited_frame && have_inherited_matrix) {
      const u32 bucket67_sprite_drawn = render_mobile_sprite_bucket(
          data, debug_bucket.addr, next_bucket.addr, g_raster, g_chain_no, &inherited_frame,
          &inherited_matrix, have_inherited_hud ? &inherited_hud : nullptr);
      if (bucket67_sprite_drawn > 0) {
        static u32 bucket67_pass_logs = 0;
        if (bucket67_pass_logs++ < 8) {
          lg::info("OTTSEL SPRITE BUCKET67: Sprite3 pass consumed={} frame/matrix-inherited=1 "
                   "hud-inherited={}",
                   bucket67_sprite_drawn, have_inherited_hud);
        }
      }
    }
  }
  if (debug_bucket.addr && next_bucket.addr) {
    static bool sprite_phase_bucket65_consumed = false;
    const std::string phase_bucket65_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-bucket65";
    if (!sprite_phase_bucket65_consumed && mobile_sprite_village1_phase() &&
        setup_bucket.addr && sprite_bucket.addr && access(phase_bucket65_path.c_str(), F_OK) == 0) {
      unlink(phase_bucket65_path.c_str());
      sprite_phase_bucket65_consumed = true;
      lg::info("OTTSEL SPRITE PHASE WINDOW: chain={} vsync={} bucket65=0x{:x} bucket66=0x{:x}",
               g_chain_no, g_ottsel_ios_vsync_count, setup_bucket.addr, sprite_bucket.addr);
      trace_mobile_sprite_phase_bucket(data, setup_bucket.addr, sprite_bucket.addr, g_chain_no,
                                       "bucket65-window");
    }
    static bool sprite_phase_window_consumed = false;
    const std::string phase_window_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-phase-window";
    if (!sprite_phase_window_consumed && mobile_sprite_village1_phase() &&
        access(phase_window_path.c_str(), F_OK) == 0) {
      unlink(phase_window_path.c_str());
      sprite_phase_window_consumed = true;
      lg::info("OTTSEL SPRITE PHASE WINDOW: chain={} vsync={} bucket66=0x{:x} bucket67=0x{:x} "
               "bucket68=0x{:x}",
               g_chain_no, g_ottsel_ios_vsync_count, sprite_bucket.addr, debug_bucket.addr,
               next_bucket.addr);
      trace_mobile_sprite_phase_bucket(data, sprite_bucket.addr, debug_bucket.addr, g_chain_no,
                                       "bucket66-window");
      trace_mobile_sprite_phase_bucket(data, debug_bucket.addr, next_bucket.addr, g_chain_no,
                                       "bucket67-window");
    }
    static bool sprite_phase_bucket67_consumed = false;
    const std::string phase_bucket67_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-bucket67";
    if (!sprite_phase_bucket67_consumed && mobile_sprite_village1_phase() &&
        access(phase_bucket67_path.c_str(), F_OK) == 0) {
      unlink(phase_bucket67_path.c_str());
      sprite_phase_bucket67_consumed = true;
      trace_mobile_sprite_phase_bucket(data, debug_bucket.addr, next_bucket.addr, g_chain_no,
                                       "bucket67");
    }
    static bool bucket67_world_probe_consumed = false;
    const std::string bucket67_world_probe_path =
        ottsel_ios_writable_dir() + "ottsel-trace-mobile-sprite-bucket67-world-metal";
    if (!bucket67_world_probe_consumed && access(bucket67_world_probe_path.c_str(), F_OK) == 0) {
      unlink(bucket67_world_probe_path.c_str());
      bucket67_world_probe_consumed = true;
      const bool old_probe_requested = g_mobile_native_sprite_probe_requested;
      const bool old_uploaded = g_mobile_native_sprite_uploaded;
      const u32 old_candidates = g_mobile_native_sprite_candidates;
      g_mobile_bucket67_world_probe_active = true;
      g_mobile_native_sprite_probe_requested = true;
      g_mobile_native_sprite_uploaded = false;
      g_mobile_native_sprite_candidates = 0;
      const u32 drawn = render_mobile_sprite_bucket(data, debug_bucket.addr, next_bucket.addr,
                                                    g_raster, g_chain_no);
      const bool uploaded = g_mobile_native_sprite_uploaded;
      const u32 candidates = g_mobile_native_sprite_candidates;
      g_mobile_bucket67_world_probe_active = false;
      g_mobile_native_sprite_probe_requested = old_probe_requested;
      g_mobile_native_sprite_uploaded = old_uploaded;
      g_mobile_native_sprite_candidates = old_candidates;
      lg::info("OTTSEL SPRITE METAL BUCKET67: chain={} vsync={} drawn={} candidates={} "
               "fixture-uploaded={} cpu-product-frame=0",
               g_chain_no, g_ottsel_ios_vsync_count, drawn, candidates, uploaded);
    }
    trace_mobile_direct_bucket(data, debug_bucket.addr, next_bucket.addr, g_dec);
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
  // Probe: level state (BOT21i) -- *level* -> level-group -> level0:
  // status/load-name/bsp so the village1 load phase can be named.  Offsets
  // are from the goal types (level: name+4 load-name+8 status+20 bsp+44;
  // level-group: level0 inline after play? + _hack-pad :offset 90, so
  // level0 at +92); the raw dumps below let them be re-verified against the
  // data pattern (symbol pointers, kheap pointers) and the compiled code.
  {
    static bool ottsel_level_dumped = false;
    if (!ottsel_level_dumped && g_ee_main_mem) {
      ottsel_level_dumped = true;
      auto lv_sym = g_pc_port_funcs.intern_from_c("*level*");
      u32 lg = 0;
      if (lv_sym.offset) {
        memcpy(&lg, g_ee_main_mem + lv_sym.offset, 4);
      }
      lg::info("OTTSEL LEVEL: *level* sym=0x{:x} group=0x{:x}", lv_sym.offset, lg);
      // Dump the compiled level method code so the field offsets can be
      // verified against the disassembly (goal instruction: type-system
      // offsets minus the basic offset, checked against disassembly).
      for (const char* nm : {"(method 9 level)", "(method 10 level)", "(method 14 level)",
                             "(method 8 level)"}) {
        auto fn = g_pc_port_funcs.intern_from_c(nm);
        u32 val = 0;
        if (fn.offset) {
          memcpy(&val, g_ee_main_mem + fn.offset, 4);
        }
        if (val >= 0x080000 && val < 0x08000000) {
          const u8* code = g_ee_main_mem + val;
          lg::info("OTTSEL LVLMETHOD: {} sym=0x{:x} val=0x{:x} code[0..23] = {:08x} {:08x} "
                   "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | "
                   "{:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                   "{:08x} {:08x}",
                   nm, fn.offset, val, *(u32*)(code + 0), *(u32*)(code + 4), *(u32*)(code + 8),
                   *(u32*)(code + 12), *(u32*)(code + 16), *(u32*)(code + 20), *(u32*)(code + 24),
                   *(u32*)(code + 28), *(u32*)(code + 32), *(u32*)(code + 36), *(u32*)(code + 40),
                   *(u32*)(code + 44), *(u32*)(code + 48), *(u32*)(code + 52), *(u32*)(code + 56),
                   *(u32*)(code + 60), *(u32*)(code + 64), *(u32*)(code + 68), *(u32*)(code + 72),
                   *(u32*)(code + 76), *(u32*)(code + 80), *(u32*)(code + 84), *(u32*)(code + 88),
                   *(u32*)(code + 92));
        } else {
          lg::info("OTTSEL LVLMETHOD: {} sym=0x{:x} val=0x{:x}", nm, fn.offset, val);
        }
      }
      if (lg >= 0x080000 && lg < 0x08000000) {
        const u8* g = g_ee_main_mem + lg;
        lg::info("OTTSEL LEVELGRP: +0..63 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                 "{:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                 *(u32*)(g + 0), *(u32*)(g + 4), *(u32*)(g + 8), *(u32*)(g + 12),
                 *(u32*)(g + 16), *(u32*)(g + 20), *(u32*)(g + 24), *(u32*)(g + 28),
                 *(u32*)(g + 32), *(u32*)(g + 36), *(u32*)(g + 40), *(u32*)(g + 44),
                 *(u32*)(g + 48), *(u32*)(g + 52), *(u32*)(g + 56), *(u32*)(g + 60));
        lg::info("OTTSEL LEVELGRP: +64..127 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                 "{:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                 *(u32*)(g + 64), *(u32*)(g + 68), *(u32*)(g + 72), *(u32*)(g + 76),
                 *(u32*)(g + 80), *(u32*)(g + 84), *(u32*)(g + 88), *(u32*)(g + 92),
                 *(u32*)(g + 96), *(u32*)(g + 100), *(u32*)(g + 104), *(u32*)(g + 108),
                 *(u32*)(g + 112), *(u32*)(g + 116), *(u32*)(g + 120), *(u32*)(g + 124));
        // BOT21i: level0 is INLINE at group+92 (goal type: level0 inline
        // after the scalars; _hack-pad :offset 90 aligns level0 to 92).
        // Its first word is the level TYPE tag (0x507c84, matching the
        // loading-level's type tag at -4), so the level fields start at
        // group+96: name+0 load-name+4 nickname+8 index+12 status+16
        // other+20 heap+24 bsp+48 (relative to the level0 struct).
        const u8* lev = g + 92;
        u32 l0 = 0;
        memcpy(&l0, lev, 4);
        lg::info("OTTSEL LEVEL: level0(inline +92) type-tag=0x{:x}", l0);
        {
          lg::info("OTTSEL LEVEL0: +0..95 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                   "{:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | "
                   "{:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x}",
                   *(u32*)(lev + 0), *(u32*)(lev + 4), *(u32*)(lev + 8), *(u32*)(lev + 12),
                   *(u32*)(lev + 16), *(u32*)(lev + 20), *(u32*)(lev + 24), *(u32*)(lev + 28),
                   *(u32*)(lev + 32), *(u32*)(lev + 36), *(u32*)(lev + 40), *(u32*)(lev + 44),
                   *(u32*)(lev + 48), *(u32*)(lev + 52), *(u32*)(lev + 56), *(u32*)(lev + 60),
                   *(u32*)(lev + 64), *(u32*)(lev + 68), *(u32*)(lev + 72), *(u32*)(lev + 76),
                   *(u32*)(lev + 80), *(u32*)(lev + 84), *(u32*)(lev + 88), *(u32*)(lev + 92));
          u32 status = *(u32*)(lev + 20);
          u32 name = *(u32*)(lev + 4);
          u32 load_name = *(u32*)(lev + 8);
          u32 bsp = *(u32*)(lev + 44);
          lg::info("OTTSEL LEVEL0: name=0x{:x} load-name=0x{:x} status=0x{:x} bsp=0x{:x} "
                   "heap=0x{:x}/0x{:x}/0x{:x}/0x{:x}",
                   name, load_name, status, bsp, *(u32*)(lev + 28), *(u32*)(lev + 32),
                   *(u32*)(lev + 36), *(u32*)(lev + 40));
          // BOT21i: scan the level-group's inline level slots (after the
          // level0 at +92) for the level objects (type tag 0x507c84) and
          // report each one's name/status/bsp so the ACTIVE village1 level
          // (and whether its bsp is set) can be identified directly.
          for (int off = 92; off < 3000; off += 4) {
            u32 t = *(u32*)(g + off);
            if (t == 0x507c84u) {
              const u8* lv = g + off;
              u32 nm = *(u32*)(lv + 4);
              u32 st = *(u32*)(lv + 20);
              u32 bsp = *(u32*)(lv + 44);
              u32 ag = *(u32*)(lv + 48);
              if (nm != 0x18fe04u || bsp || st) {
                lg::info("OTTSEL LVLSLOT: off=+{} name=0x{:x} status=0x{:x} bsp=0x{:x} "
                         "art-group=0x{:x}",
                         off, nm, st, bsp, ag);
              }
            }
          }
          // BOT21i: the loading-level (group+8) bsp candidate 0x1c83994:
          // dump the bsp-header object (type + drawable-trees count).
          u32 lv = 0;
          memcpy(&lv, g + 8, 4);
          if (lv >= 0x080000 && lv < 0x08000000) {
            u32 bsp = *(u32*)(g_ee_main_mem + lv + 40);
            u32 lnm = *(u32*)(g_ee_main_mem + lv + 0);
            u32 lst = *(u32*)(g_ee_main_mem + lv + 16);
            auto sym_str = [&](u32 sptr) -> std::string {
              if (sptr < 0x080000 || sptr >= 0x08000000) {
                return "?";
              }
              const u8* sp = g_ee_main_mem + sptr;
              u32 strp = 0;
              memcpy(&strp, sp + 4, 4);
              if (strp < 0x080000 || strp >= 0x08000000) {
                return "?";
              }
              const char* s = (const char*)(g_ee_main_mem + strp + 4);
              return std::string(s, strnlen(s, 40));
            };
            lg::info("OTTSEL LLOAD: loading-level=0x{:x} bsp=0x{:x} name-sym=0x{:x}('{}') "
                     "status-sym=0x{:x}('{}')",
                     lv, bsp, lnm, sym_str(lnm), lst, sym_str(lst));
            if (bsp >= 0x080000 && bsp < 0x08000000) {
              const u8* b = g_ee_main_mem + bsp;
              lg::info("OTTSEL BSPOBJ: +0..79 = {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} "
                       "{:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                       "{:08x} | {:08x} {:08x} {:08x} {:08x}",
                       *(u32*)(b + 0), *(u32*)(b + 4), *(u32*)(b + 8), *(u32*)(b + 12),
                       *(u32*)(b + 16), *(u32*)(b + 20), *(u32*)(b + 24), *(u32*)(b + 28),
                       *(u32*)(b + 32), *(u32*)(b + 36), *(u32*)(b + 40), *(u32*)(b + 44),
                       *(u32*)(b + 48), *(u32*)(b + 52), *(u32*)(b + 56), *(u32*)(b + 60),
                       *(u32*)(b + 64), *(u32*)(b + 68), *(u32*)(b + 72), *(u32*)(b + 76));
            }
          }
          auto sym_name = [&](u32 sptr) -> std::string {
            if (sptr < 0x080000 || sptr >= 0x08000000) {
              return "?";
            }
            const u8* sp = g_ee_main_mem + sptr;
            u32 strp = 0;
            memcpy(&strp, sp + 4, 4);
            if (strp < 0x080000 || strp >= 0x08000000) {
              return "?";
            }
            const char* s = (const char*)(g_ee_main_mem + strp + 4);
            return std::string(s, strnlen(s, 48));
          };
          lg::info("OTTSEL LEVEL0: name='{}' load-name='{}' status='{}'", sym_name(name),
                   sym_name(load_name), sym_name(status));
          // Resolve candidate symbols by address: the level name/status
          // fields hold symbol pointers; match them against known names.
          for (const char* cn : {"village1", "village1-vis", "vi1", "title", "loading",
                                 "loading-bt", "loading-done", "login", "loaded", "alive",
                                 "active", "inactive", "none", "global", "bsp-header",
                                 "file-info", "level-vis-info", "drawable-tree-tfrag",
                                 "link-block", "#f", "level-default", "default-level",
                                 "title", "demo", "target", "draw-inline-array-instance-tie",
                                 "draw-inline-array-prototype-tie-asm",
                                 "draw-inline-array-prototype-tie-near-asm",
                                 "draw-node-cull", "drawable-tree-instance-tie",
                                 "drawable-inline-array-instance-tie", "*vu1-enable-user*",
                                 "*vu1-enable-user-menu*"}) {
            auto s = g_pc_port_funcs.intern_from_c(cn);
            if (s.offset) {
              u32 v = 0;
              if (g_ee_main_mem && s.offset < 0x08000000) {
                memcpy(&v, g_ee_main_mem + s.offset, 4);
              }
              lg::info("OTTSEL LVLSYMADDR: '{}' sym=0x{:x} val=0x{:x}", cn, s.offset, v);
            }
          }
          // BOT21i: the vi1.DGO last object (village1-vis) links at the
          // heap top 0x2ef8080; dump its type tag so the level BSP source
          // can be identified (bsp-header vs vis data).
          for (u32 o : {0x2ef8080u, 0x2821200u}) {
            if (o >= 0x080000 && o < 0x08000000) {
              // The served object = {u32 size, char name[60]} then the link
              // data; the GOAL dgo-header puts the object data at +64 and
              // the linker's basic type tag at data-4 = obj+60.
              u32 tag = *(u32*)(g_ee_main_mem + o + 60);
              lg::info("OTTSEL OBJTYPE: obj=0x{:x} type-tag=0x{:x} tag[0..3]=0x{:x}/0x{:x}/0x{:x}/"
                       "0x{:x}",
                       o, tag, *(u32*)(g_ee_main_mem + o + 56), tag,
                       *(u32*)(g_ee_main_mem + o + 64), *(u32*)(g_ee_main_mem + o + 68));
            }
          }
          if (bsp >= 0x080000 && bsp < 0x08000000) {
            const u8* b = g_ee_main_mem + bsp;
            lg::info("OTTSEL BSP: ptr=0x{:x} +0..63 = {:08x} {:08x} {:08x} {:08x} | {:08x} "
                     "{:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} {:08x} | {:08x} {:08x} {:08x} "
                     "{:08x}",
                     bsp, *(u32*)(b + 0), *(u32*)(b + 4), *(u32*)(b + 8), *(u32*)(b + 12),
                     *(u32*)(b + 16), *(u32*)(b + 20), *(u32*)(b + 24), *(u32*)(b + 28),
                     *(u32*)(b + 32), *(u32*)(b + 36), *(u32*)(b + 40), *(u32*)(b + 44),
                     *(u32*)(b + 48), *(u32*)(b + 52), *(u32*)(b + 56), *(u32*)(b + 60));
          }
        }
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
  const bool decoded_page = decode_largest_texture(tpage, mode, s7_ptr, rgba.data(), w, h,
                                                    &tex_idx);
  if (decoded_page) {
    // Retain every decoded texture in the native keyed cache. The existing
    // largest-texture decode remains the CPU-raster diagnostic, but Direct
    // resolution must be able to select the exact TEX0/TBP upload later.
    OttselGoalTexturePage upload_page;
    memcpy(&upload_page, tpage, sizeof(upload_page));
    u32 direct_uploads = 0;
    for (s32 index = 0; index < upload_page.length; ++index) {
      u32 desc_ptr = 0;
      memcpy(&desc_ptr, tpage + sizeof(OttselGoalTexturePage) + 4 * index, sizeof(desc_ptr));
      if (!desc_ptr || desc_ptr >= 0x08000000) {
        continue;
      }
      OttselGoalTexture tex;
      memcpy(&tex, g_ee_main_mem + desc_ptr, sizeof(tex));
      const u32 tex_width = (u32)std::max<s16>(0, tex.w);
      const u32 tex_height = (u32)std::max<s16>(0, tex.h);
      if (!tex_width || !tex_height || tex_width > 2048 || tex_height > 2048 || !tex.dest[0]) {
        continue;
      }
      std::vector<u8> direct_rgba((size_t)tex_width * tex_height * 4, 0);
      const bool texture_decoded = download_texture_rgba8888(
          direct_rgba.data(), tex.dest[0], std::max(1u, (u32)tex.width[0]), tex_width,
          tex_height, tex.psm, tex.clutpsm, tex.clut_dest);
      if (!texture_decoded) {
        continue;
      }
      g_direct_texture_metadata[tex.dest[0]] = {
          tex_width, tex_height, tex.psm, tex.clutpsm, tex.clut_dest};
      ottsel_metal_upload_direct_texture(g_metal, direct_rgba.data(), tex_width, tex_height,
                                         direct_texture_cache_key(tex.dest[0], tex.psm));
      ++direct_uploads;
    }
    if (direct_uploads) {
      static u32 direct_page_upload_logs = 0;
      if (direct_page_upload_logs++ < 12) {
        lg::info("OTTSEL METAL TEXPAGE: id=0x{:x} keyed-direct-textures={}", upload_page.id,
                 direct_uploads);
      }
    }
    // Decode uploaded textures into fake VRAM for the debug rasterizer, but
    // never present a page directly: it is asset data, not composed graphics.
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
               "keeping the last composed frame",
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
    if ((ottsel_gfx_presents++ & 0x3f) == 0) {
      lg::info("OTTSEL GFX: decoded texture {}x{} (tpage 0x{:x} tex {}) for raster use", w, h,
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
void gfx_texture_relocate(u32 destination, u32 source, u32 format) {
  const auto source_it = g_direct_texture_metadata.find(source);
  if (source_it == g_direct_texture_metadata.end()) {
    lg::info("OTTSEL METAL RELOCATE: source-miss dst=0x{:x} src=0x{:x} format=0x{:x}",
             destination, source, format);
    return;
  }
  const DirectTextureMetadata& metadata = source_it->second;
  DirectRelocatedTexture relocated;
  relocated.width = metadata.width;
  relocated.height = metadata.height;
  relocated.rgba.assign((size_t)relocated.width * relocated.height * 4, 0);
  if (!download_texture_rgba8888(relocated.rgba.data(), source,
                                  std::max(1u, metadata.width / 64), relocated.width,
                                  relocated.height, metadata.psm, metadata.clut_psm,
                                  metadata.clut_addr)) {
    lg::info("OTTSEL METAL RELOCATE: decode-failed dst=0x{:x} src=0x{:x} format=0x{:x}",
             destination, source, format);
    return;
  }
  const u64 cache_key = direct_texture_cache_key(destination, format);
  g_direct_relocated_textures[cache_key] = relocated;
  if (g_metal) {
    ottsel_metal_upload_direct_texture(g_metal, relocated.rgba.data(), relocated.width,
                                       relocated.height, cache_key);
  }
  lg::info("OTTSEL METAL RELOCATE: source=0x{:x} destination=0x{:x} format=0x{:x} size={}x{}",
           source, destination, format, relocated.width, relocated.height);
}
void gfx_set_levels(const std::vector<std::string>& levels) {
  request_mobile_levels(levels, "want");
}
void gfx_set_active_levels(const std::vector<std::string>& levels) {
  request_mobile_levels(levels, "active");
}
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
  (void)rgba;
  (void)w;
  (void)h;
  return 0;
}

int ottsel_metal_gfx_has_live_scene() {
  return g_mobile_tfrag_visibility_ready || g_mobile_tie_visibility_ready;
}
