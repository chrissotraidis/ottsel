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
    // Tag every entry so an encoder can erase exactly what it drew. Erasing
    // all non-persistent entries at end of frame drops groups a producer
    // appended while the command buffer was still being built.
    m_tags.push_back(++m_seq);
  }

  void clear() {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_values.clear();
    m_tags.clear();
  }

  template <typename Predicate>
  void erase_if(Predicate predicate) {
    std::lock_guard<std::mutex> lock(m_mutex);
    size_t write = 0;
    for (size_t read = 0; read < m_values.size(); ++read) {
      if (predicate(m_values[read])) {
        continue;
      }
      if (write != read) {
        m_values[write] = std::move(m_values[read]);
        m_tags[write] = m_tags[read];
      }
      ++write;
    }
    m_values.resize(write);
    m_tags.resize(write);
  }

  // Remove exactly the entries whose tags came back from snapshot_tagged().
  // Anything appended after that snapshot keeps its tag and survives.
  void erase_tags(const std::vector<unsigned long long>& tags) {
    if (tags.empty()) {
      return;
    }
    std::lock_guard<std::mutex> lock(m_mutex);
    size_t write = 0;
    for (size_t read = 0; read < m_values.size(); ++read) {
      bool drop = false;
      for (unsigned long long tag : tags) {
        if (tag == m_tags[read]) {
          drop = true;
          break;
        }
      }
      if (drop) {
        continue;
      }
      if (write != read) {
        m_values[write] = std::move(m_values[read]);
        m_tags[write] = m_tags[read];
      }
      ++write;
    }
    m_values.resize(write);
    m_tags.resize(write);
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

  std::vector<std::pair<unsigned long long, T>> snapshot_tagged() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    std::vector<std::pair<unsigned long long, T>> tagged;
    tagged.reserve(m_values.size());
    for (size_t i = 0; i < m_values.size(); ++i) {
      tagged.emplace_back(m_tags[i], m_values[i]);
    }
    return tagged;
  }

 private:
  mutable std::mutex m_mutex;
  std::vector<T> m_values;
  std::vector<unsigned long long> m_tags;
  unsigned long long m_seq = 0;
};
