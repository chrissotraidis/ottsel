#include <cstdint>
#include <cstdio>
#include <cstring>

#include "../src/shell/metal_shell.h"
using u8 = uint8_t;
using u32 = uint32_t;
using u64 = uint64_t;
namespace ottsel { enum class DirectIrKind { St }; }
enum class GsRegisterAddress { RGBAQ };

// Exact product state types, vertex snapshot method, packed writers, AD RGBAQ
// handler (or its absence), REGLIST ST writer, and captured-coordinate mapping.
#include "direct_coordinate_state.inc"

static int failures = 0;
static void expect(const char* label, const OttselVertex& vertex, float s, float t, float q) {
  const auto mapped = map_coordinates(vertex);
  const bool ok = (vertex.has_st || vertex.has_uv) && mapped.uv[0] == s &&
                  mapped.uv[1] == t && mapped.q == q;
  std::printf("%s: %s actual=(%g,%g,%g) expected=(%g,%g,%g)\n", label,
              ok ? "PASS" : "FAIL", mapped.uv[0], mapped.uv[1], mapped.q, s, t, q);
  failures += !ok;
}

static void write_st(Decoder& dec, float s, float t, float q) {
  const float packet[4] = {s, t, q, 0};
  packed_st(dec, reinterpret_cast<const u8*>(packet));
}

static void write_uv(Decoder& dec, u32 u, u32 v) {
  const u32 packet[4] = {u, v, 0, 0};
  packed_uv(dec, reinterpret_cast<const u8*>(packet));
}

static void write_ad_rgbaq(Decoder& dec, float q) {
  u32 bits;
  std::memcpy(&bits, &q, sizeof(bits));
  dec.ad_rgbaq((u64(bits) << 32) | 0x44332211u);
}

int main() {
  Decoder repeated_uv;
  write_uv(repeated_uv, 24, 8);
  repeated_uv.on_vertex();
  repeated_uv.on_vertex();
  expect("UV first vertex", repeated_uv.verts[0], 24, 8, 1);
  expect("UV persists next vertex", repeated_uv.verts[1], 24, 8, 1);

  Decoder uv_then_st;
  write_uv(uv_then_st, 24, 8);
  write_st(uv_then_st, 32, 16, 2);
  uv_then_st.on_vertex();
  uv_then_st.on_vertex();
  expect("ST supersedes UV", uv_then_st.verts[0], 32, 16, 2);
  expect("ST persists", uv_then_st.verts[1], 32, 16, 2);

  Decoder st_then_uv;
  write_st(st_then_uv, 32, 16, 2);
  write_uv(st_then_uv, 24, 8);
  st_then_uv.on_vertex();
  st_then_uv.on_vertex();
  expect("UV supersedes ST and resets Q", st_then_uv.verts[0], 24, 8, 1);
  expect("UV does not resurrect old ST", st_then_uv.verts[1], 24, 8, 1);

  Decoder ad_on_uv;
  write_uv(ad_on_uv, 24, 8);
  write_ad_rgbaq(ad_on_uv, 3);
  ad_on_uv.on_vertex();
  ad_on_uv.on_vertex();
  expect("AD Q updates UV-carried coordinates", ad_on_uv.verts[0], 24, 8, 3);
  expect("AD Q and coordinates persist", ad_on_uv.verts[1], 24, 8, 3);
  const auto& color = ad_on_uv.verts[0];
  const bool rgba_ok = color.r == 0x11 && color.g == 0x22 && color.b == 0x33 && color.a == 0x44;
  std::printf("AD RGBA byte channels: %s\n", rgba_ok ? "PASS" : "FAIL");
  failures += !rgba_ok;

  Decoder ad_on_st;
  write_st(ad_on_st, 7, 9, 2);
  write_ad_rgbaq(ad_on_st, 4);
  ad_on_st.on_vertex();
  expect("AD Q updates ST coordinates", ad_on_st.verts[0], 7, 9, 4);

  Decoder reglist;
  write_uv(reglist, 24, 8);
  write_ad_rgbaq(reglist, 2);
  const float st[2] = {7, 9};
  reglist_st(reglist, reinterpret_cast<const u8*>(st));
  reglist.on_vertex();
  expect("REGLIST ST supersedes UV retaining Q", reglist.verts[0], 7, 9, 2);

  // Production bucket/reset paths replace this exact state with its defaults.
  reglist.st = OttselDrawState{};
  reglist.vert_count = 0;
  reglist.on_vertex();
  const bool reset_ok = !reglist.verts[0].has_uv && !reglist.verts[0].has_st &&
                        reglist.verts[0].q == 1;
  std::printf("explicit reset clears coordinate validity and restores Q1: %s\n",
              reset_ok ? "PASS" : "FAIL");
  failures += !reset_ok;
  return failures ? 1 : 0;
}
