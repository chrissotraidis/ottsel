#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <unordered_map>
#include <vector>
using u8 = uint8_t;
using u32 = uint32_t;
using u64 = uint64_t;
namespace tfrag3 { struct Texture {}; }
namespace lg { template<class... T> void info(const char*, T...) {} }
#include "texture_relocation_types.inc"
std::unordered_map<u32, DirectTextureMetadata> g_direct_texture_metadata;
std::unordered_map<u64, DirectRelocatedTexture> g_direct_relocated_textures;
void* g_metal = reinterpret_cast<void*>(1);
unsigned decodes = 0, uploads = 0;
std::vector<u8> last_upload;
u64 direct_texture_cache_key(u32 destination, u32 format) {
  return (u64(destination) << 8) | (format & 0x3f);
}
bool download_texture_rgba8888(u8* pixels, u32, u32, u32 w, u32 h, u32, u32, u32) {
  ++decodes;
  std::fill(pixels, pixels + w * h * 4, 34); // Reused VRAM differs from retained A.
  return true;
}
void ottsel_metal_upload_direct_texture(void*, const u8* pixels, u32 w, u32 h, u64) {
  ++uploads;
  last_upload.assign(pixels, pixels + w * h * 4);
}
#include "texture_relocation_function.inc"
int main() {
  unsigned failures = 0;
  auto check = [&](bool good, const char* name) {
    std::printf("%s: %s\n", name, good ? "PASS" : "FAIL");
    failures += !good;
  };
  tfrag3::Texture retained_identity;
  const std::vector<u8> a(16, 17);
  g_direct_texture_metadata[16] = {2, 2, 19, 0, 1, 0x1910003, -1, 0};
  g_direct_relocated_textures[direct_texture_cache_key(16, 19)] = {2, 2, a, &retained_identity};
  gfx_texture_relocate(32, 16, 44);
  const auto first = g_direct_relocated_textures.find(direct_texture_cache_key(32, 44));
  check(first != g_direct_relocated_textures.end() && first->second.rgba == a &&
        first->second.pool_source == &retained_identity && decodes == 0 && last_upload == a,
        "registered source identity survives VRAM reuse");
  gfx_texture_relocate(48, 32, 0);
  const auto second = g_direct_relocated_textures.find(direct_texture_cache_key(48, 0));
  check(second != g_direct_relocated_textures.end() && second->second.rgba == a && decodes == 0,
        "relocation chain resolves destination metadata and format");
  gfx_texture_relocate(16, 16, 19);
  check(g_direct_relocated_textures.at(direct_texture_cache_key(16, 19)).rgba == a,
        "same-slot relocation preserves source bytes");
  const auto old_uploads = uploads;
  const auto old_destination = g_direct_relocated_textures.at(direct_texture_cache_key(32, 44)).rgba;
  gfx_texture_relocate(32, 999, 44);
  check(uploads == old_uploads && g_direct_relocated_textures.at(direct_texture_cache_key(32, 44)).rgba == old_destination,
        "missing source preserves existing destination");
  g_direct_texture_metadata[64] = {2, 2, 19};
  gfx_texture_relocate(80, 64, 19);
  check(g_direct_relocated_textures.at(direct_texture_cache_key(80, 19)).rgba == std::vector<u8>(16, 34),
        "unregistered legacy source retains raw fallback");
  return failures ? 1 : 0;
}
