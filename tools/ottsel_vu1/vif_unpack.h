#pragma once

#include <cstddef>
#include <cstdint>

namespace ottsel_vu1 {

// VIF UNPACK V4-8 expands four input bytes to one VU qword.  When WL is
// smaller than CL, each WL-sized write group is followed by skipped qwords.
inline bool unpack_v4_8(uint32_t* vu_words,
                        size_t vu_qwords,
                        const uint8_t* payload,
                        size_t payload_size,
                        uint32_t destination_qword,
                        uint32_t count,
                        bool is_unsigned,
                        uint16_t cl,
                        uint16_t wl) {
  if (!vu_words || !payload || count == 0 || wl == 0 || cl == 0 ||
      payload_size < size_t(count) * 4) {
    return false;
  }
  for (uint32_t i = 0; i < count; ++i) {
    const uint32_t cycle_offset = wl >= cl ? i : (i / wl) * cl + (i % wl);
    const uint32_t destination = destination_qword + cycle_offset;
    if (destination >= vu_qwords) {
      return false;
    }
    for (uint32_t lane = 0; lane < 4; ++lane) {
      const uint8_t value = payload[i * 4 + lane];
      vu_words[destination * 4 + lane] =
          is_unsigned ? uint32_t(value) : uint32_t(int32_t(int8_t(value)));
    }
  }
  return true;
}

}  // namespace ottsel_vu1
