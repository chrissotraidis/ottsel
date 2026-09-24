// Ottsel G2.2 regression: the GS ALPHA register decode that selects the native
// blend pipeline.  The expected values are the desktop DirectRenderer table
// (six supported combinations) plus the two registers measured live on the iPad
// lane: 0x48 on the Sky cloud tiles and 0x44 on the untextured full-screen strips.
#include <cstdio>

#include "mobile_blend_policy.h"

static int failures = 0;

static void expect(unsigned long long alpha, OttselMobileBlendKey want, const char* note) {
  const OttselMobileBlendKey got = ottsel_mobile_blend_key_from_alpha(alpha);
  if (got != want) {
    std::printf("FAIL alpha=0x%llx -> %s, want %s (%s)\n", alpha,
                ottsel_mobile_blend_key_name(got), ottsel_mobile_blend_key_name(want), note);
    ++failures;
  } else {
    std::printf("ok   alpha=0x%llx -> %s (%s)\n", alpha, ottsel_mobile_blend_key_name(got), note);
  }
}

int main() {
  // The six combinations the desktop handles, in its own order.
  expect(0x44ull, OttselMobileBlendKey::SourceOver, "S/D/S/D source-over");
  expect(0x48ull, OttselMobileBlendKey::Additive, "S/Z/S/D additive (Cs*As+Cd)");
  expect(0x42ull, OttselMobileBlendKey::ReverseSubtract, "Z/S/S/D reverse subtract");
  expect(0x64ull, OttselMobileBlendKey::ConstantAlpha, "S/D/Z/D constant alpha");
  expect(0x00ull, OttselMobileBlendKey::Unspecified, "no ALPHA_1 written in the bucket");
  expect(0x58ull, OttselMobileBlendKey::DestinationAlpha, "S/Z/D/D destination alpha");
  // A FIX-only register is a real decoded copy, not 'no register'.
  expect(40ull << 32, OttselMobileBlendKey::Copy, "S/S/S/S copy with FIX set");
  // The FIX field must not change the equation key.
  expect(0x48ull | (40ull << 32), OttselMobileBlendKey::Additive, "additive with FIX set");
  expect(0x44ull | (40ull << 32), OttselMobileBlendKey::SourceOver, "source-over with FIX set");
  // Anything the desktop rejects must not be mistaken for a supported key.
  expect(0x55ull, OttselMobileBlendKey::Unsupported, "D/D/D/D");
  expect(0x0full, OttselMobileBlendKey::Unsupported, "D/D/D/S");
  expect(0x4full, OttselMobileBlendKey::Unsupported, "D/S/S/D");
  if (failures) {
    std::printf("mobile blend policy: FAIL %d case(s)\n", failures);
    return 1;
  }
  std::printf("mobile blend policy: PASS 12/12\n");
  return 0;
}
