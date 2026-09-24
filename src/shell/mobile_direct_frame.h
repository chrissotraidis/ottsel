#pragma once
#include <mutex>
#include <optional>
#include <utility>
#include <vector>

// Direct bucket 67 is a complete GOAL-frame image, replayed until replacement.
// Buffers retired here must enter the existing pool only after completion of
// the presentation command buffer receiving Snapshot::retired (same queue).
template <typename Batch>
class OttselMobileDirectFrame {
  using Buffer = decltype(std::declval<Batch>().vertices);
 public:
  struct Snapshot { std::vector<Batch> batches; std::vector<Buffer> retired; };
  // G2.2 observability ledger (no behaviour change).  The live Sky decode
  // reports `submitted=2` on every title frame while this store's published
  // snapshot reads empty, so the store counts its own stage transitions and,
  // decisively, a publish that replaces a non-empty ready population with an
  // empty one - the signature of an empty bucket clear dropping strips that
  // were already submitted.
  struct DebugLedger {
    unsigned long begins = 0;
    unsigned long appends = 0;
    unsigned long publishes = 0;
    unsigned long rollbacks = 0;
    unsigned long empty_publishes = 0;
    unsigned long empty_replacements = 0;
    unsigned long published_batches = 0;
  };
  DebugLedger debug_take() {
    std::lock_guard<std::mutex> lock(mutex_);
    DebugLedger out = ledger_;
    ledger_ = DebugLedger{};
    return out;
  }
  void debug_sizes(std::size_t& building, std::size_t& completed, std::size_t& active) {
    std::lock_guard<std::mutex> lock(mutex_);
    building = building_.size();
    completed = completed_ ? completed_->size() : 0;
    active = active_.size();
  }
  void begin(bool rollback = false) {
    std::lock_guard<std::mutex> lock(mutex_);
    ++ledger_.begins;
    if (rollback) ++ledger_.rollbacks;
    retire(building_);
  }
  void append(const Batch& batch) {
    std::lock_guard<std::mutex> lock(mutex_);
    ++ledger_.appends;
    building_.push_back(batch);
  }
  void publish() {
    std::lock_guard<std::mutex> lock(mutex_);
    ++ledger_.publishes;
    if (building_.empty()) {
      ++ledger_.empty_publishes;
      if (completed_ && !completed_->empty()) ++ledger_.empty_replacements;
    }
    ledger_.published_batches += (unsigned long)building_.size();
    if (completed_) retire(*completed_);
    completed_ = std::move(building_);
    building_.clear();
  }
  Snapshot snapshot() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (completed_) {
      retire(active_);
      active_ = std::move(*completed_);
      completed_.reset();
    }
    Snapshot result{active_, std::move(retired_)};
    retired_.clear();
    return result;
  }
  void clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    retire(building_);
    if (completed_) retire(*completed_);
    completed_.reset();
    retire(active_);
  }
 private:
  void retire(std::vector<Batch>& batches) {
    for (const auto& batch : batches) retired_.push_back(batch.vertices);
    batches.clear();
  }
  std::mutex mutex_;
  std::vector<Batch> building_, active_;
  std::optional<std::vector<Batch>> completed_;
  std::vector<Buffer> retired_;
  DebugLedger ledger_;
};
