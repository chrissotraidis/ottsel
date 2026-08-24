#pragma once

// Mobile scene meshes are stable level resources. Camera motion changes the
// uniforms, not ownership of the uploaded mesh. Rebuild only when there is no
// snapshot yet or the active level changes.
constexpr bool ottsel_mobile_scene_snapshot_needs_rebuild(bool snapshot_ready,
                                                           bool level_changed,
                                                           bool camera_planes_changed) {
  (void)camera_planes_changed;
  return !snapshot_ready || level_changed;
}

// FR3 texture IDs are local to a level. Keep negative animated-slot IDs
// untouched and map ordinary IDs into a level-owned range in Metal's cache.
constexpr int ottsel_mobile_scene_texture_slot(unsigned int level_texture_base,
                                                int local_texture_id) {
  return local_texture_id < 0 ? local_texture_id
                              : static_cast<int>(level_texture_base) + local_texture_id;
}

// Production telemetry is a bounded first-occurrence ledger. Per-frame draw
// logging distorts frame pacing and can grow Simulator logs by megabytes.
constexpr bool ottsel_mobile_log_within_budget(unsigned int emitted,
                                               unsigned int budget) {
  return emitted < budget;
}

// Full VIF/GIF decoding is intentionally capped because it is expensive on a
// Simulator CPU. A complete gameplay chain can be longer, so a second cheap
// pass scans the tail only for native PC_PORT camera and actor packets.
constexpr unsigned int kOttselMobileDmaDecodeBudget = 512;
constexpr unsigned int kOttselMobilePcPortScanBudget = 4096;

constexpr bool ottsel_mobile_dma_decode_can_continue(bool ended,
                                                      unsigned int transfers) {
  return !ended && transfers < kOttselMobileDmaDecodeBudget;
}

constexpr bool ottsel_mobile_pc_port_scan_can_continue(bool ended,
                                                        unsigned int transfers) {
  return !ended && transfers < kOttselMobilePcPortScanBudget;
}
