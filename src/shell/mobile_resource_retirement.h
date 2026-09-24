#pragma once

#include <algorithm>
#include <utility>
#include <vector>

// Call under the pool's existing mutex. A command buffer owns only resources
// it encoded; resources borrowed by a producer after its snapshot stay pending.
// The returned resources may become reusable only after that command completes.
template <typename T>
std::vector<T> ottsel_mobile_take_encoded_resources(std::vector<T>& pending,
                                                    const std::vector<T>& encoded) {
  std::vector<T> retired;
  size_t write = 0;
  for (size_t read = 0; read < pending.size(); ++read) {
    if (std::find(encoded.begin(), encoded.end(), pending[read]) != encoded.end()) {
      retired.push_back(std::move(pending[read]));
    } else {
      if (write != read) {
        pending[write] = std::move(pending[read]);
      }
      ++write;
    }
  }
  pending.resize(write);
  return retired;
}
