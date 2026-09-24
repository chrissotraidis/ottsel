#pragma once
// Ottsel G2.2 - GS ALPHA register decode for the native blend pipelines.
//
// The PS2 GS ALPHA register packs four 2-bit blend sources (common/dma/gs.h,
// GsAlpha::BlendMode {SOURCE=0, DEST=1, ZERO_OR_FIXED=2}: a=bits0-1, b=bits2-3,
// c=bits4-5, d=bits6-7, fix()=data>>32) and the RGB equation is
//   (Cs - Cd) * a + (Cd - 0) * b + Cd
// so the desktop's DirectRenderer handles exactly six combinations and logs
// every other value as 'unsupported blend (direct)':
//   S/D/S/D -> SRC_ALPHA, ONE_MINUS_SRC_ALPHA, ADD           (0x44) source-over
//   S/Z/S/D -> SRC_ALPHA, ONE, ADD                           (0x48) additive
//   Z/S/S/D -> SRC_ALPHA, ONE, REVERSE_SUBTRACT
//   S/D/Z/D -> CONSTANT_ALPHA, ONE_MINUS_CONSTANT_ALPHA, ADD (fix/127)
//   S/S/S/S -> disable blend                                 (0x00) copy
//   S/Z/D/D -> DST_ALPHA, ONE, ADD (color_mult 0.5)
//
// The native path needs the decode to tell the additive case apart from the
// source-over case it already draws; the other keys are decoded (and
// regression-tested) so a new population can never be silently mis-blended,
// but no pipeline is selected for them until a ledger proves a live site asks
// for one.
//
// A zero register means the bucket wrote no ALPHA_1 at all (both native capture
// paths reset the decoder's draw state before walking a bucket), so it is
// 'Unspecified', not a decoded copy.

enum class OttselMobileBlendKey {
  Unspecified = 0,
  Copy = 1,
  SourceOver = 2,
  Additive = 3,
  ReverseSubtract = 4,
  ConstantAlpha = 5,
  DestinationAlpha = 6,
  Unsupported = 7,
};

constexpr unsigned int ottsel_mobile_alpha_field(unsigned long long alpha, int index) {
  return (unsigned int)((alpha >> (2 * index)) & 3ull);
}

constexpr OttselMobileBlendKey ottsel_mobile_blend_key_from_alpha(unsigned long long alpha) {
  if (alpha == 0ull) return OttselMobileBlendKey::Unspecified;
  const unsigned int a = ottsel_mobile_alpha_field(alpha, 0);
  const unsigned int b = ottsel_mobile_alpha_field(alpha, 1);
  const unsigned int c = ottsel_mobile_alpha_field(alpha, 2);
  const unsigned int d = ottsel_mobile_alpha_field(alpha, 3);
  // a=SOURCE(0) b=ZERO_OR_FIXED(2) c=SOURCE(0) d=DEST(1) -> (Cs-0)*As + Cd
  if (a == 0 && b == 2 && c == 0 && d == 1) return OttselMobileBlendKey::Additive;
  // a=SOURCE b=DEST c=SOURCE d=DEST -> Cs*As + Cd*(1-As)
  if (a == 0 && b == 1 && c == 0 && d == 1) return OttselMobileBlendKey::SourceOver;
  // a=ZERO b=SOURCE c=SOURCE d=DEST -> Cd - Cs*As
  if (a == 2 && b == 0 && c == 0 && d == 1) return OttselMobileBlendKey::ReverseSubtract;
  // a=SOURCE b=DEST c=ZERO_OR_FIXED d=DEST -> constant alpha
  if (a == 0 && b == 1 && c == 2 && d == 1) return OttselMobileBlendKey::ConstantAlpha;
  // a=SOURCE b=SOURCE c=SOURCE d=SOURCE -> copy (blend disabled)
  if (a == 0 && b == 0 && c == 0 && d == 0) return OttselMobileBlendKey::Copy;
  // a=SOURCE b=ZERO_OR_FIXED c=DEST d=DEST -> Cd*Ad + Cs*As
  if (a == 0 && b == 2 && c == 1 && d == 1) return OttselMobileBlendKey::DestinationAlpha;
  return OttselMobileBlendKey::Unsupported;
}

constexpr const char* ottsel_mobile_blend_key_name(OttselMobileBlendKey key) {
  switch (key) {
    case OttselMobileBlendKey::Unspecified: return "unspecified";
    case OttselMobileBlendKey::Copy: return "copy";
    case OttselMobileBlendKey::SourceOver: return "source-over";
    case OttselMobileBlendKey::Additive: return "additive";
    case OttselMobileBlendKey::ReverseSubtract: return "reverse-subtract";
    case OttselMobileBlendKey::ConstantAlpha: return "constant-alpha";
    case OttselMobileBlendKey::DestinationAlpha: return "destination-alpha";
    case OttselMobileBlendKey::Unsupported: return "unsupported";
  }
  return "unknown";
}
