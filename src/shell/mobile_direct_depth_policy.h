#pragma once

struct OttselMobileDirectDepthPolicy {
  bool supported;
  unsigned int compare;  // GS NEVER, ALWAYS, GEQUAL, GREATER.
  bool write;
};

// This first depth contract handles no alpha test, ALWAYS, and NEVER's KEEP
// or FB_ONLY outcomes. Other alpha-fail modes need separate draw/color masks.
constexpr OttselMobileDirectDepthPolicy ottsel_mobile_direct_depth_policy(
    unsigned long long test, unsigned long long zbuf) {
  if (!(test & (1ull << 16))) {
    return {false, 1, false};  // Desktop treats disabled ZTE as unsupported.
  }
  const bool ate = (test & 1) != 0;
  const unsigned int atst = (test >> 1) & 7;
  const unsigned int afail = (test >> 12) & 3;
  if (ate && atst != 1 && !(atst == 0 && afail <= 1)) {
    return {false, 1, false};
  }
  if (ate && atst == 0 && afail == 0) {
    return {true, 0, false};  // NEVER/KEEP discards all fragments.
  }
  const bool write = !(zbuf & (1ull << 32)) && !(ate && atst == 0 && afail == 1);
  return {true, static_cast<unsigned int>((test >> 17) & 3), write};
}
