#pragma once

#include <algorithm>
#include <cstdint>

// G2.2 (2026-09-23): the SkyBlend copy equation, extracted so a host regression
// can pin it.  Upstream SkyBlendCPU.cpp blends every qwc == 6 copy pair into one
// of two destination buffers: the first draw of that buffer overwrites
// (PRIM.ABE == 0) and later draws accumulate, both scaling the source by
// intensity / 128:
//     initial: out = (in * intensity) >> 7
//     blend:   out = min(255, out + ((in * intensity) >> 7))
// The native producer in metal_gfx.mm composes the 32x32 (tbp 0x1f80) and 64x64
// (tbp 0x1fa0) buffers the sky bucket's fans sample with exactly this arithmetic,
// and the intensity is clamped to a byte because the port reads it from a raw
// qword where upstream asserts <= 128.
inline std::uint8_t ottsel_sky_blend_scale(std::uint8_t in, std::uint32_t intensity) {
  const std::uint32_t clamped = std::min(intensity, 255u);
  const std::uint32_t scaled = (static_cast<std::uint32_t>(in) * clamped) >> 7;
  return static_cast<std::uint8_t>(std::min(scaled, 255u));
}

inline std::uint8_t ottsel_sky_blend_accumulate(std::uint8_t out, std::uint8_t in,
                                                std::uint32_t intensity) {
  const std::uint32_t sum = static_cast<std::uint32_t>(out) +
                            static_cast<std::uint32_t>(ottsel_sky_blend_scale(in, intensity));
  return static_cast<std::uint8_t>(std::min(sum, 255u));
}
