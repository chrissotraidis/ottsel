#include <cstdio>
#include <cstdlib>
#include "../src/shell/mobile_direct_depth_policy.h"
#include "../src/shell/metal_shell.h"

static void check(bool value, const char* message) {
  if (!value) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}

int main() {
  for (unsigned compare=0; compare<4; ++compare) {
    for (unsigned masked=0; masked<2; ++masked) {
      const unsigned long long test=(1ull<<16) | (static_cast<unsigned long long>(compare)<<17);
      auto policy=ottsel_mobile_direct_depth_policy(test, static_cast<unsigned long long>(masked)<<32);
      check(policy.supported && policy.compare==compare && policy.write==!masked, "compare/ZMSK matrix");
      policy=ottsel_mobile_direct_depth_policy(test | 3, static_cast<unsigned long long>(masked)<<32);
      check(policy.supported && policy.compare==compare && policy.write==!masked, "alpha ALWAYS matrix");
    }
  }
  constexpr auto gequal=(1ull<<16) | (2ull<<17);
  auto policy=ottsel_mobile_direct_depth_policy(gequal | 1, 0);
  check(policy.supported && policy.compare==0 && !policy.write, "NEVER/KEEP discards");
  policy=ottsel_mobile_direct_depth_policy(gequal | 1 | (1ull<<12), 0);
  check(policy.supported && policy.compare==2 && !policy.write, "NEVER/FB_ONLY tests depth without writing");
  check(!ottsel_mobile_direct_depth_policy(0, 0).supported, "disabled ZTE is explicitly unsupported");
  for (unsigned atst=0; atst<8; ++atst) {
    for (unsigned afail=0; afail<4; ++afail) {
      const auto state=gequal | 1 | (static_cast<unsigned long long>(atst)<<1) |
                       (static_cast<unsigned long long>(afail)<<12);
      const bool supported=atst==1 || (atst==0 && afail<=1);
      check(ottsel_mobile_direct_depth_policy(state, 0).supported==supported, "alpha support boundary");
    }
  }
  check(OttselMetalSpriteVertex{}.z==0 && OttselMetalOverlayVertex{}.z==0, "legacy Sprite/HUD depth defaults");
  static_assert(sizeof(OttselMetalSpriteVertex)==40);
  static_assert(sizeof(OttselMetalOverlayVertex)==40);
  std::puts("PASS: GS compare/ZMSK, supported alpha outcomes, explicit unsupported modes, legacy z0 defaults");
}
