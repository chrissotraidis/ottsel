#pragma once

#include <array>

// Jak 1 buckets consumed by the desktop Generic2 renderer. Keep the mobile
// decoder scoped to these owners instead of interpreting the entire DMA chain
// as one undifferentiated VIF stream.
constexpr std::array<unsigned int, 10> kOttselJak1GenericBuckets = {
    11, 18, 24, 30, 46, 50, 53, 56, 59, 62,
};

constexpr bool ottsel_mobile_is_jak1_generic_bucket(unsigned int bucket_id) {
  for (const auto candidate : kOttselJak1GenericBuckets) {
    if (candidate == bucket_id) {
      return true;
    }
  }
  return false;
}

constexpr std::array<unsigned int, 5> kOttselJak1MercLedgerBuckets = {
    10, 11, 49, 50, 56,
};

constexpr bool ottsel_mobile_is_jak1_merc_ledger_bucket(unsigned int bucket_id) {
  for (const auto candidate : kOttselJak1MercLedgerBuckets) {
    if (candidate == bucket_id) {
      return true;
    }
  }
  return false;
}

// Native PC_PORT packets for the mobile actor/camera path are bounded to the
// same Jak 1 bucket neighborhood used by the Merc ledger, plus the buckets
// that own texture pages. On a PC_PORT build upload-vram-pages replaces the
// PS2 VRAM upload with a 16-byte {page, mode} packet (texture.gc:958), so the
// texture buckets carry the level's resident uploads and the walker has to
// visit them. Jump directly to those bucket windows instead of linearly
// decoding the rest of the chain.
constexpr std::array<unsigned int, 11> kOttselJak1TextureUploadBuckets = {
    5, 12, 19, 25, 31, 38, 48, 51, 57, 60, 65,
};

constexpr bool ottsel_mobile_is_jak1_texture_upload_bucket(unsigned int bucket_id) {
  for (const auto candidate : kOttselJak1TextureUploadBuckets) {
    if (candidate == bucket_id) {
      return true;
    }
  }
  return false;
}

// The PC_PORT camera/tfrag3 packet rides the terrain owners:
// tfrag-0/tfrag-1, tie-0/tie-1 and shrub-generic0/1.  None of
// those ids are in the merc-ledger or texture-upload sets, so a
// curated candidate list walks straight past the camera and
// *math-camera* stays stale.  The 512-transfer linear pass stops
// even earlier: it walks buckets in order, and on a heavy level
// the early buckets (sky, ocean, texture uploads) fill that
// budget before the terrain buckets are reached.  Walk every
// bucket window instead; the fallback pass parses DMA tags and
// acts only on PC_PORT transfers, so the wider coverage costs
// tag reads rather than VIF decoding.
constexpr bool ottsel_mobile_jak1_pc_port_bucket_candidate(unsigned int bucket_id) {
  return bucket_id < 70u;
}

// The submitted Jak 1 chain begins with one CALL qword. Bucket zero starts at
// the following qword, matching OpenGLRenderer::dispatch_buckets_jak1.
constexpr unsigned int ottsel_mobile_jak1_bucket_boundary(unsigned int chain_offset,
                                                          unsigned int bucket_id) {
  return chain_offset + 16u * (bucket_id + 1u);
}
