#pragma once

#include <array>
#include <cstddef>

namespace ottsel_mobile_merc {
using Vec4 = std::array<float, 4>;

// Column-major packet matrix, matching Merc2's untransposed uniform upload.
inline Vec4 transform(const float matrix[4][4], const Vec4& position) {
  Vec4 result{};
  for (std::size_t row = 0; row < 4; ++row) {
    for (std::size_t column = 0; column < 4; ++column) {
      result[row] += matrix[column][row] * position[column];
    }
  }
  return result;
}

// Call only for a valid bone. Zero-weight influences must not read the bone:
// the game can leave those slots invalid. Preserve W; affine skinning with
// unit total weight produces -1, but that is not a general input invariant.
inline void accumulate(Vec4& skinned, const float matrix[4][4],
                       const Vec4& position, float weight) {
  if (weight <= 0.f) {
    return;
  }
  const auto transformed = transform(matrix, position);
  for (std::size_t row = 0; row < 4; ++row) {
    skinned[row] -= transformed[row] * weight;
  }
}

// Reference for the mobile MERC shader: merc2.vert followed by OpenGL's
// [-W,+W] to Metal's [0,+W] depth conversion, exactly once.
inline Vec4 project(const Vec4& skinned, const float perspective[4][4],
                    const Vec4& hvdf, float fog_constant) {
  auto clip = transform(perspective, skinned);
  const float q = fog_constant / clip[3];
  for (std::size_t row = 0; row < 3; ++row) {
    clip[row] = clip[row] * q + hvdf[row];
  }
  clip[0] = (clip[0] - 2048.f) / 256.f;
  clip[1] = (clip[1] - 2048.f) / -128.f;
  clip[2] = clip[2] / 8388608.f - 1.f;
  for (std::size_t row = 0; row < 3; ++row) {
    clip[row] *= clip[3];
  }
  clip[1] *= 512.f / 448.f;
  clip[2] = (clip[2] + clip[3]) * .5f;
  return clip;
}
}  // namespace ottsel_mobile_merc
