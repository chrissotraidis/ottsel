#include <cstdio>
#include <cstdlib>
#include <memory>
#include <vector>

#include "../src/shell/mobile_resource_retirement.h"
#include "../src/shell/mobile_snapshot_store.h"

static void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

int main() {
  using Buffer = std::shared_ptr<int>;
  const Buffer a = std::make_shared<int>(101);
  const Buffer b = std::make_shared<int>(202);
  std::vector<Buffer> pending{a};
  std::vector<Buffer> free;
  const std::vector<Buffer> encoded_a{a};

  // Deterministic interleaving: producer B arrives after frame A's snapshot.
  pending.push_back(b);
  auto completing_a = ottsel_mobile_take_encoded_resources(pending, encoded_a);
  require(completing_a == encoded_a, "A command must own only A");
  require(pending == std::vector<Buffer>{b}, "B stays pending after A retirement");
  require(free.empty(), "A cannot be reused before GPU completion");

  // Completion moves only A to the reusable list. The next producer may write A,
  // but must never receive or overwrite pending B's vertex bytes.
  free.insert(free.end(), completing_a.begin(), completing_a.end());
  completing_a.clear();
  require(free == encoded_a, "only completed A becomes reusable");
  Buffer reused = free.back();
  free.pop_back();
  *reused = 303;
  pending.push_back(reused);
  require(*b == 202, "pending B content survives a later producer write");

  // A repeated draw/reference of B must not add it to the free list twice.
  auto completing_b = ottsel_mobile_take_encoded_resources(pending, std::vector<Buffer>{b, b});
  require(completing_b == std::vector<Buffer>{b}, "duplicate encoded references retire once");
  require(pending == std::vector<Buffer>{a}, "new pending A survives B retirement");
  require(ottsel_mobile_take_encoded_resources(pending, std::vector<Buffer>{b}).empty(),
          "an already retired resource cannot retire twice");
  require(ottsel_mobile_take_encoded_resources(pending, std::vector<Buffer>{}).empty(),
          "a skipped frame cannot retire pending resources");
  require(pending == std::vector<Buffer>{a}, "empty selection preserves pending resources");

  // Exercise the production batch store, including a late append and an already
  // removed snapshot: only the exact consumed tags may be erased.
  OttselMobileSnapshotStore<int> batches;
  batches.append(101);
  const auto frame_a = batches.snapshot_tagged();
  batches.append(202);
  batches.erase_tags({frame_a[0].first});
  require(batches.snapshot() == std::vector<int>{202}, "late batch survives frame A erasure");
  require(frame_a[0].second == 101, "snapshot A remains stable after retirement");
  batches.erase_tags({frame_a[0].first});
  require(batches.snapshot() == std::vector<int>{202}, "stale tags do not erase next frame");
  const auto frame_b = batches.snapshot_tagged();
  batches.append(303);
  batches.erase_tags({frame_b[0].first});
  require(batches.snapshot() == std::vector<int>{303}, "late batch survives frame B erasure");

  std::puts("PASS: encoded-only retirement, completion ownership, pending bytes, tagged batches");
}
