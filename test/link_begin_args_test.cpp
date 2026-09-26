#include <cstdio>

#include "game/kernel/jak1/klink.h"

int main() {
  const u64 no_data[5] = {0, 1, 1, 0, 0};
  const u64 no_name[5] = {1, 0, 1, 0, 0};
  const u64 no_size[5] = {1, 1, 0, 0, 0};
  const u64 negative_size[5] = {1, 1, static_cast<u64>(-1), 0, 0};
  const u64 valid[5] = {1, 1, 1, 0, 0};
  struct Case {
    const char* name;
    const u64* args;
    bool expected;
  };
  const Case cases[] = {{"null arguments", nullptr, false},
                        {"null data", no_data, false},
                        {"null name", no_name, false},
                        {"zero size", no_size, false},
                        {"negative size", negative_size, false},
                        {"valid arguments", valid, true}};
  for (const auto& test : cases) {
    if (jak1::link_begin_args_valid(test.args) != test.expected) {
      std::fprintf(stderr, "FAIL: %s\n", test.name);
      return 1;
    }
  }
  std::puts("PASS: production link_begin_args_valid, 6 malformed/valid cases");
}
