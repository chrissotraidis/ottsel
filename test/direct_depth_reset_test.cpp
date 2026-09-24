#include <cstdint>
#include <cstdio>
#include <string>
#include "../src/shell/metal_shell.h"
#include "../src/shell/mobile_direct_depth_policy.h"
using u8 = uint8_t;
using u32 = uint32_t;
using u64 = uint64_t;
enum class GsRegisterAddress { TEST_1, ZBUF_1 };
#include "direct_depth_reset.inc"

int main() {
  int failures = 0;
  const auto check = [&](bool ok, const char* name) {
    std::printf("%s: %s\n", name, ok ? "PASS" : "FAIL");
    failures += !ok;
  };
  const TestState oracle;
  const u64 expected_test = (u64(oracle.zte) << 16) | (u64(oracle.ztst) << 17);
  check(expected_test == 0x50000 && !oracle.alpha_test_enable && !oracle.date &&
            oracle.depth_writes, "desktop reset contract is GEQUAL/write, alpha/date off");
  OttselDrawState st;
  const auto first = capture_depth(st);
  auto policy = ottsel_mobile_direct_depth_policy(first.test, first.zbuf);
  check(first.test == expected_test && policy.supported && policy.compare == unsigned(oracle.ztst) &&
            policy.write == oracle.depth_writes, "absent TEST uses desktop reset policy");

  write_ad(st, GsRegisterAddress::TEST_1, 0);
  const auto explicit_zero = capture_depth(st);
  check(explicit_zero.test == 0 && !ottsel_mobile_direct_depth_policy(explicit_zero.test, explicit_zero.zbuf).supported,
        "explicit AD TEST0 stays literal zero, not reset default");
  check(first.test == expected_test, "earlier primitive keeps captured reset state");

  write_ad(st, GsRegisterAddress::TEST_1, 0x70000);
  write_ad(st, GsRegisterAddress::ZBUF_1, 1ull << 32);
  const auto updated = capture_depth(st);
  policy = ottsel_mobile_direct_depth_policy(updated.test, updated.zbuf);
  check(updated.test == 0x70000 && policy.supported && policy.compare == 3 && !policy.write,
        "nonzero TEST and ZMSK override reset state");
  const auto following = capture_depth(st);
  check(following.test == updated.test && following.zbuf == updated.zbuf,
        "later primitive inherits current bucket register state");

  st = OttselDrawState{};
  const auto reset = capture_depth(st);
  policy = ottsel_mobile_direct_depth_policy(reset.test, reset.zbuf);
  check(reset.test == expected_test && reset.zbuf == 0 && policy.supported && policy.compare == 2 && policy.write,
        "new bucket reset restores GEQUAL/write");
  return failures ? 1 : 0;
}
