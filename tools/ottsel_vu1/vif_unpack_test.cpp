#include "vif_unpack.h"

#include <array>
#include <cstdio>

int main() {
  std::array<uint32_t, 32 * 4> vu{};
  std::array<uint8_t, 8 * 4> payload{};
  for (uint32_t i = 0; i < payload.size(); ++i) {
    payload[i] = uint8_t(i + 1);
  }

  // Exact live shape before MSCAL 0x6: V4-8 num=8 at TOPS+0x0f, STCYCL 0x0102.
  if (!ottsel_vu1::unpack_v4_8(vu.data(), 32, payload.data(), payload.size(), 15, 8, true, 2,
                                1)) {
    return 1;
  }
  for (uint32_t i = 0; i < 8; ++i) {
    const uint32_t qword = 15 + i * 2;
    for (uint32_t lane = 0; lane < 4; ++lane) {
      if (vu[qword * 4 + lane] != i * 4 + lane + 1) {
        return 2;
      }
    }
    if (i < 7 && vu[(qword + 1) * 4] != 0) {
      return 3;
    }
  }
  std::puts("vif_unpack V4-8 cycle regression passed");
  return 0;
}
