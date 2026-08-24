#pragma once

#include <array>

// Jak 1 buckets consumed by the desktop Generic2 renderer. Keep the mobile
// decoder scoped to these owners instead of interpreting the entire DMA chain
// as one undifferentiated VIF stream.
constexpr std::array<unsigned int, 10> kOttselJak1GenericBuckets = {
    11, 18, 24, 30, 46, 50, 53, 56, 59, 62,
};

constexpr bool ottsel_mobile_is_jak1_generic_bucket(unsigned int bucket_id) {
  for (const auto candidate : kOttselJak1GenericBuckets) {
    if (candidate == bucket_id) {
      return true;
    }
  }
  return false;
}

// The submitted Jak 1 chain begins with one CALL qword. Bucket zero starts at
// the following qword, matching OpenGLRenderer::dispatch_buckets_jak1.
constexpr unsigned int ottsel_mobile_jak1_bucket_boundary(unsigned int chain_offset,
                                                          unsigned int bucket_id) {
  return chain_offset + 16u * (bucket_id + 1u);
}
