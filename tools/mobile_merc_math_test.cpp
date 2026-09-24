#include "../src/shell/mobile_merc_math.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>

using ottsel_mobile_merc::Vec4;
using ottsel_mobile_merc::accumulate;
using ottsel_mobile_merc::project;

static void require(bool value, const char* message) {
  if (!value) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

static void near(double actual, double expected, const char* message,
                 double tolerance = 2e-6) {
  if (!std::isfinite(actual) || std::abs(actual - expected) > tolerance) {
    std::fprintf(stderr, "FAIL: %s actual=%.12g expected=%.12g\n",
                 message, actual, expected);
    std::exit(1);
  }
}

int main() {
  const float identity[4][4] = {{1,0,0,0}, {0,1,0,0}, {0,0,1,0}, {0,0,0,1}};
  const Vec4 point{2,3,4,1};
  Vec4 skin{};
  accumulate(skin, identity, point, 1.f);
  const Vec4 expected_identity{-2,-3,-4,-1};
  require(skin == expected_identity, "identity must negate all four components");

  const float translated[4][4] = {{1,0,0,0}, {0,1,0,0}, {0,0,1,0}, {8,-4,12,1}};
  skin = {};
  accumulate(skin, identity, point, .25f);
  accumulate(skin, translated, point, .75f);
  const Vec4 expected_weighted{-8,0,-13,-1};
  require(skin == expected_weighted, "weighted translated bones");

  const Vec4 before_zero = skin;
  accumulate(skin, nullptr, point, 0.f);
  float garbage[4][4];
  for (auto& column : garbage) {
    for (float& component : column) {
      component = std::numeric_limits<float>::quiet_NaN();
    }
  }
  accumulate(skin, garbage, point, 0.f);
  require(skin == before_zero, "zero-weight null/NaN bone must not contaminate output");

  // Full homogeneous input support: do not hardcode W=-1 or renormalize weights.
  const float projective[4][4] = {{1,0,0,.5f}, {0,1,0,0}, {0,0,1,0}, {0,0,0,2}};
  skin = {};
  accumulate(skin, projective, point, .5f);
  near(skin[3], -1.5, "non-affine W and non-unit weight sum");

  // Independent scalar oracle for the sparse camera shape produced by
  // math-camera.gc, using the recorded BOT59 packet's depth/fog values.
  const float perspective[4][4] = {{-2,0,0,0}, {0,-3,0,0},
      {0,0,-8184.262f,-3.5552202e-5f}, {0,0,1.676095e7f,0}};
  const Vec4 hvdf{2048,2048,8380365.5f,264.3198f};
  const float fog = -.036405455f;
  for (float z : {-20000.f,-40000.f,-80000.f}) {
    for (float skin_w : {-1.f,-1.5f}) {
      const Vec4 input{32,-24,z,skin_w};
      const auto clip = project(input, perspective, hvdf, fog);
      const double w = double(perspective[2][3]) * z;
      const double q = double(fog) / w;
      const double gs_z = (double(perspective[2][2]) * z +
                           double(perspective[3][2]) * skin_w) * q + hvdf[2];
      // Collapse the oracle's z -= 1 and GL->Metal conversion analytically.
      near(clip[0] / clip[3], -2. * input[0] * q / 256., "oracle x");
      near(clip[1] / clip[3], -3. * input[1] * q / -128. * 512. / 448., "oracle y");
      near(clip[2] / clip[3], gs_z / 16777216., "oracle depth");
      near(clip[3], w, "oracle clip W");
    }
  }

  const auto correct = project(Vec4{0,0,-40000,-1}, perspective, hvdf, fog);
  const auto wrong_w = project(Vec4{0,0,-40000,1}, perspective, hvdf, fog);
  const double correct_z = correct[2] / correct[3];
  const double wrong_z = wrong_w[2] / wrong_w[3];
  near(correct_z, .025556177, "recorded camera with preserved W");
  near(wrong_z, -.025594183, "reproduce old clipping defect");
  near(wrong_z + .5, .474405817, "reproduce shipping mode1 compensation");
  require(wrong_z < 0 && correct_z > 0, "lost W changes clip acceptance");
  require(std::abs(wrong_z + .5 - correct_z) > .4,
          "visibility compensation must fail correct depth tolerance");
  std::printf("PASS mobile MERC math: full-W skinning, zero-weight safety, scalar depth oracle; "
              "correct=%.9f old=%.9f mode1=%.9f\n", correct_z, wrong_z, wrong_z + .5);
}
