// Ottsel G2.2 regression: the SkyBlend copy equation shared by the native sky
// producer and this test.  Expected values are upstream's own arithmetic
// (SkyBlendCPU.cpp blend_sky_initial_fast / blend_sky_fast), not the port's.
#include <cstdio>
#include <vector>

#include "mobile_sky_blend.h"

static int failures = 0;

static void expect_scale(std::uint8_t in, std::uint32_t intensity, std::uint8_t want,
                         const char* note) {
  const std::uint8_t got = ottsel_sky_blend_scale(in, intensity);
  if (got != want) {
    std::printf("FAIL scale in=%u intensity=%u -> %u, want %u (%s)\n", in, intensity, got, want,
                note);
    ++failures;
  } else {
    std::printf("ok   scale in=%u intensity=%u -> %u (%s)\n", in, intensity, got, note);
  }
}

static void expect_accumulate(std::uint8_t out, std::uint8_t in, std::uint32_t intensity,
                              std::uint8_t want, const char* note) {
  const std::uint8_t got = ottsel_sky_blend_accumulate(out, in, intensity);
  if (got != want) {
    std::printf("FAIL accumulate out=%u in=%u intensity=%u -> %u, want %u (%s)\n", out, in,
                intensity, got, want, note);
    ++failures;
  } else {
    std::printf("ok   accumulate out=%u in=%u intensity=%u -> %u (%s)\n", out, in, intensity, got,
                note);
  }
}

int main() {
  // intensity 128 is unity: the copy reproduces the source byte exactly.
  expect_scale(0, 128, 0, "0 stays 0");
  expect_scale(255, 128, 255, "255 stays 255");
  expect_scale(200, 128, 200, "unity for a mid byte");
  // half intensity.
  expect_scale(255, 64, 127, "255 * 64 >> 7 = 127");
  expect_scale(2, 64, 1, "2 * 64 >> 7 = 1");
  // zero intensity clears the destination on the initial draw.
  expect_scale(255, 0, 0, "intensity 0 clears");
  // The clamp: the port reads the intensity from a raw qword, so anything above
  // 255 must behave like 255 rather than wrap.
  expect_scale(200, 255, 255, "clamped intensity saturates");
  expect_scale(100, 1000, 199, "out-of-range intensity clamps to 255");
  // Accumulation clamps at 255 instead of wrapping.
  expect_accumulate(200, 255, 128, 255, "accumulate saturates");
  expect_accumulate(100, 60, 128, 160, "accumulate adds the scaled byte");
  // Against upstream's slow path, over the whole byte range and four intensities.
  const std::uint32_t intensities[4] = {0, 1, 64, 128};
  for (std::uint32_t intensity : intensities) {
    for (int value = 0; value < 256; ++value) {
      std::uint32_t reference = static_cast<std::uint32_t>(value) * intensity;
      reference >>= 7;
      if (reference > 255) {
        reference = 255;
      }
      if (ottsel_sky_blend_scale(static_cast<std::uint8_t>(value), intensity) != reference) {
        std::printf("FAIL reference mismatch value=%d intensity=%u\n", value, intensity);
        ++failures;
      }
    }
  }
  std::printf("ok   scale matches upstream's slow path for 4 intensities x 256 values\n");
  if (failures) {
    std::printf("mobile sky blend: FAIL %d case(s)\n", failures);
    return 1;
  }
  std::printf("mobile sky blend: PASS\n");
  return 0;
}
