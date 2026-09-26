#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <unordered_map>
#include <vector>

using u8 = uint8_t;
using u16 = uint16_t;
using u32 = uint32_t;
using u64 = uint64_t;
using s16 = int16_t;
using s32 = int32_t;
#include "texture_upload_structs.inc"

namespace tfrag3 {
struct Texture { u16 w = 2, h = 2; u32 combo_id = 0; std::vector<u32> data; bool load_to_pool = true; };
}
std::unordered_map<u32, const tfrag3::Texture*> g_mobile_pool_textures;

struct DirectTextureMetadata {
  u32 width, height, psm, clut_psm, clut_addr, combo_id;
  int upload_mode, mip0_segment;
};
struct DirectRelocatedTexture {
  u32 width, height; std::vector<u8> rgba;
  const tfrag3::Texture* pool_source = nullptr;
};
std::unordered_map<u32, DirectTextureMetadata> g_direct_texture_metadata;
std::unordered_map<u64, DirectRelocatedTexture> g_direct_relocated_textures;
std::unordered_map<u32, unsigned> decode_calls;
std::unordered_map<u64, unsigned> upload_calls;
u8 memory[4096]{};
u8* g_ee_main_mem = memory;
void* g_metal = nullptr;
u8 decoded_color = 17;
u64 direct_texture_cache_key(u32 destination, u32 psm) { return (u64(destination) << 8) | psm; }
std::shared_ptr<std::vector<u8>> download_texture_cached(
    u32 dest, u32, u32 width, u32 height, u32, u32, u32) {
  ++decode_calls[dest];
  return std::make_shared<std::vector<u8>>(width * height * 4, decoded_color);
}
void ottsel_metal_upload_direct_texture(void*, const u8*, u32, u32, u64 key) {
  ++upload_calls[key];
}

// Execute the actual production registration loop; only decoding and GPU
// upload are replaced with deterministic spies. Page mode is passed intact.
static void register_page(const u8* tpage, int mode) {
  (void)mode;
#include "texture_upload_registration.inc"
  (void)direct_uploads;
}

int main() {
  OttselGoalTexturePage page{};
  page.length = 3;
  std::vector<u8> page_bytes(sizeof(page) + 3 * sizeof(u32));
  std::memcpy(page_bytes.data(), &page, sizeof(page));
  unsigned failures = 0;
  // Desktop TexturePool mode mapping, written as explicit expected membership.
  const int modes[] = {-1, 0, -2, 2};
  const bool expected[4][3] = {{true,true,true}, {true,false,false},
                              {true,true,false}, {false,false,true}};
  for (unsigned mode_index = 0; mode_index < 4; ++mode_index) {
    for (u32 segment = 0; segment < 3; ++segment) {
      OttselGoalTexture texture{};
      texture.w = texture.h = 2;
      texture.num_mips = segment + 1;  // Actual segment_of_mip(0): 0,1,2.
      texture.psm = 19;
      texture.width[0] = 1;
      texture.dest[0] = 16 + segment;
      texture.clut_dest = 1;
      const u32 offset = 256 + segment * 128;
      std::memcpy(memory + offset, &texture, sizeof(texture));
      std::memcpy(page_bytes.data() + sizeof(page) + 4 * segment, &offset, 4);
    }
    decoded_color = 17;
    register_page(page_bytes.data(), -1);  // Seed a known valid prior registry.
    decode_calls.clear();
    upload_calls.clear();
    decoded_color = 34;  // Simulate different/current VRAM after partial upload.
    for (u32 segment = 0; segment < 3; ++segment) {
      OttselGoalTexture texture;
      std::memcpy(&texture, memory + 256 + segment * 128, sizeof(texture));
      texture.clut_dest = 8;
      std::memcpy(memory + 256 + segment * 128, &texture, sizeof(texture));
    }
    register_page(page_bytes.data(), modes[mode_index]);
    for (u32 segment = 0; segment < 3; ++segment) {
      const u32 dest = 16 + segment;
      const u64 key = direct_texture_cache_key(dest, 19);
      const bool allowed = expected[mode_index][segment];
      const bool good = decode_calls[dest] == unsigned(allowed) &&
          upload_calls[key] == unsigned(allowed) &&
          g_direct_relocated_textures.at(key).rgba.front() == (allowed ? 34 : 17) &&
          g_direct_texture_metadata.at(dest).clut_addr == (allowed ? 8u : 1u);
      if (!good) {
        ++failures;
        std::fprintf(stderr, "FAIL mode=%d mip0-segment=%u expected-upload=%d "
                     "decode=%u upload=%u registry-byte=%u clut=%u\n",
                     modes[mode_index], segment, allowed, decode_calls[dest],
                     upload_calls[key], g_direct_relocated_textures.at(key).rgba.front(),
                     g_direct_texture_metadata.at(dest).clut_addr);
      }
    }
  }
  // A verified loaded PcTextureId must win over different current VRAM.
  page.length = 1;
  std::memcpy(page_bytes.data(), &page, sizeof(page));
  tfrag3::Texture pool;
  pool.data.assign(4, 0x33333333);
  for (int control = 0; control < 4; ++control) {
    g_mobile_pool_textures.clear();
    pool.w = control == 2 ? 4 : 2;
    pool.load_to_pool = control != 3;
    g_mobile_pool_textures[control == 1 ? 99 : 0] = &pool;
    decoded_color = 34;
    decode_calls.clear();
    upload_calls.clear();
    register_page(page_bytes.data(), -1);
    const auto key = direct_texture_cache_key(16, 19);
    const bool verified = control == 0;
    if (g_direct_relocated_textures.at(key).rgba.front() != (verified ? 51 : 34) ||
        decode_calls[16] != unsigned(!verified)) {
      ++failures;
      std::fprintf(stderr, "FAIL PcTextureId control=%d verified=%d source-byte=%u decode=%u\n",
                   control, verified, g_direct_relocated_textures.at(key).rgba.front(), decode_calls[16]);
    }
    if (verified) {
      upload_calls.clear();
      register_page(page_bytes.data(), -1);
      if (upload_calls[key] != 0 || decode_calls[16] != 0) {
        ++failures;
        std::fprintf(stderr, "FAIL stable verified identity should reuse registry/upload\n");
      }
    }
  }
  // GS TBP zero is a valid texture slot (Hud left), not an absent descriptor.
  OttselGoalTexture slot_zero{};
  slot_zero.w = 128; slot_zero.h = 512; slot_zero.num_mips = 1;
  slot_zero.psm = 19; slot_zero.width[0] = 2; slot_zero.dest[0] = 0;
  const u32 slot_zero_descriptor = 256;
  std::memcpy(memory + slot_zero_descriptor, &slot_zero, sizeof(slot_zero));
  std::memcpy(page_bytes.data() + sizeof(page), &slot_zero_descriptor, 4);
  page.id = 0x408;
  std::memcpy(page_bytes.data(), &page, sizeof(page));
  pool.w = 128; pool.h = 512; pool.load_to_pool = true; pool.combo_id = 0x04080000;
  pool.data.assign(128 * 512, 0x33333333);
  g_mobile_pool_textures.clear(); g_mobile_pool_textures[pool.combo_id] = &pool;
  g_direct_relocated_textures.erase(direct_texture_cache_key(0, 19));
  g_direct_texture_metadata.erase(0); decode_calls.clear();
  register_page(page_bytes.data(), -1);
  const auto zero = g_direct_relocated_textures.find(direct_texture_cache_key(0, 19));
  if (zero == g_direct_relocated_textures.end() || zero->second.rgba.front() != 51 ||
      g_direct_texture_metadata.count(0) != 1 ||
      g_direct_texture_metadata.at(0).combo_id != 0x04080000 || decode_calls[0] != 0) {
    ++failures;
    std::fprintf(stderr, "FAIL valid slot0 registers exact PcTextureId without raw decode\n");
  }
  // Replaying unchanged Hud must restore slot ownership after a different
  // PSM/page took slot0; retaining old PSM-keyed pixels alone is insufficient.
  tfrag3::Texture hold;
  hold.w = hold.h = 4; hold.combo_id = 0x01a00000; hold.data.assign(16, 0x77777777);
  g_mobile_pool_textures[hold.combo_id] = &hold;
  auto hold_descriptor = slot_zero;
  hold_descriptor.w = hold_descriptor.h = 4; hold_descriptor.psm = 2;
  std::memcpy(memory + slot_zero_descriptor, &hold_descriptor, sizeof(hold_descriptor));
  page.id = 0x1a0; std::memcpy(page_bytes.data(), &page, sizeof(page));
  register_page(page_bytes.data(), -1);
  if (g_direct_texture_metadata.at(0).combo_id != hold.combo_id) ++failures;
  std::memcpy(memory + slot_zero_descriptor, &slot_zero, sizeof(slot_zero));
  page.id = 0x408; std::memcpy(page_bytes.data(), &page, sizeof(page));
  upload_calls.clear(); decode_calls.clear();
  register_page(page_bytes.data(), -1);
  if (g_direct_texture_metadata.at(0).combo_id != 0x04080000 ||
      g_direct_texture_metadata.at(0).psm != 19 ||
      g_direct_relocated_textures.at(direct_texture_cache_key(0,19)).rgba.front() != 51 ||
      upload_calls[direct_texture_cache_key(0,19)] != 0 || decode_calls[0] != 0) {
    ++failures;
    std::fprintf(stderr, "FAIL unchanged Hud replay restores owner after charHOLD without image re-upload\n");
  }
  if (failures) return 1;
  std::puts("PASS actual texture registration: all four desktop modes; excluded segments preserve registry; verified PcTextureId wins and reuses upload, mismatches fall back");
}
