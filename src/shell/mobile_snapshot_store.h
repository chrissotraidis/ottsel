#pragma once

#include <algorithm>
#include <mutex>
#include <utility>
#include <vector>

// Game-thread uploads and main-thread Metal encoding must never share a live
// std::vector iterator. Snapshotting retains each resource while the encoder
// builds its command buffer and lets producers continue safely.
template <typename T>
class OttselMobileSnapshotStore {
 public:
  void append(T value) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_values.push_back(std::move(value));
  }

  void clear() {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_values.clear();
  }

  template <typename Predicate>
  void erase_if(Predicate predicate) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_values.erase(std::remove_if(m_values.begin(), m_values.end(), predicate), m_values.end());
  }

  template <typename Mutator>
  void mutate_last(Mutator mutator) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_values.empty()) {
      mutator(m_values.back());
    }
  }

  std::vector<T> snapshot() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_values;
  }

 private:
  mutable std::mutex m_mutex;
  std::vector<T> m_values;
};
