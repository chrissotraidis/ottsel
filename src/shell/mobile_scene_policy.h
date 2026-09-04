#pragma once


constexpr bool ottsel_present_rgba_frame_valid(const unsigned char* rgba,
                                                int width,
                                                int height,
                                                bool direct_fixture) {
  constexpr int kMaxPresentDimension = 4096;
  return direct_fixture ||
         (rgba && width > 0 && height > 0 && width <= kMaxPresentDimension &&
          height <= kMaxPresentDimension);
}

// Mobile scene meshes are stable level resources. Camera motion changes the
// uniforms, not ownership of the uploaded mesh. Rebuild only when there is no
// snapshot yet or the active level changes.
constexpr bool ottsel_mobile_scene_snapshot_needs_rebuild(bool snapshot_ready,
                                                           bool level_changed,
                                                           bool camera_planes_changed) {
  (void)camera_planes_changed;
  return !snapshot_ready || level_changed;
}

// The packet level, rather than asynchronous load order, owns the active
// scene snapshot. Keep this contract explicit for the focused transition test.
constexpr bool ottsel_mobile_scene_snapshot_owner_is_packet_level(
    bool packet_level_matches_snapshot) {
  return packet_level_matches_snapshot;
}

constexpr bool ottsel_mobile_scene_has_geometry(unsigned int geometry_slots) {
  return geometry_slots != 0;
}

constexpr bool ottsel_mobile_scene_geometry_slot_is_populated(unsigned int geometry_count) {
  return geometry_count != 0;
}

constexpr bool ottsel_mobile_scene_geometry_range_is_valid(unsigned int geo,
                                                            unsigned int tree,
                                                            unsigned int geo_count,
                                                            unsigned int tree_count) {
  return geo < geo_count && tree < tree_count;
}

// TIE data stores independent draw intervals. The ordinary TFRAG shader can
// consume NORMAL, TRANS, and WATER; envmap intervals require ETIE normals and
// a separate camera contract, so do not misrender them as ordinary TIE.
constexpr bool ottsel_mobile_tie_category_is_supported(unsigned int category) {
  return category < 3;
}

// OpenGL's background setup uses a second FB_ONLY pass only when depth writes
// are enabled. With depth writes disabled, the first pass accepts alpha from
// zero instead of retaining the GEQUAL reference.
constexpr float ottsel_mobile_alpha_min(unsigned int alpha_test_kind,
                                         bool alpha_test,
                                         unsigned int alpha_fail,
                                         bool depth_write,
                                         unsigned int alpha_reference) {
  if (!alpha_test || alpha_test_kind != 2 || (alpha_fail == 1 && !depth_write)) {
    return 0.f;
  }
  return alpha_reference / 127.f;
}

// FR3 texture IDs are local to a level. Keep negative animated-slot IDs
// untouched and map ordinary IDs into a level-owned range in Metal's cache.
constexpr int ottsel_mobile_scene_texture_slot(unsigned int level_texture_base,
                                                int local_texture_id) {
  return local_texture_id < 0 ? local_texture_id
                              : static_cast<int>(level_texture_base) + local_texture_id;
}

constexpr bool ottsel_mobile_positive_texture_id_is_valid(int texture_id,
                                                          unsigned int texture_count) {
  return texture_id >= 0 && static_cast<unsigned int>(texture_id) < texture_count;
}

constexpr bool ottsel_mobile_mesh_upload_ready(unsigned int pending_texture_uploads) {
  return pending_texture_uploads == 0;
}

// Merc is a latest-snapshot resource, like TFRAG and TIE. An empty producer
// interval means no replacement arrived; it must not erase the last usable
// actor while the camera/level transition is still settling.
constexpr bool ottsel_mobile_merc_snapshot_should_retain(bool pending_empty,
                                                          bool active_snapshot_ready) {
  return pending_empty && active_snapshot_ready;
}

constexpr bool ottsel_mobile_texture_upload_should_queue(bool already_queued) {
  return !already_queued;
}

constexpr bool ottsel_mobile_visibility_group_is_visible(unsigned int visibility_id,
                                                              const unsigned char* visible_nodes,
                                                              unsigned int node_count) {
  return visibility_id == 0xffffu ||
         (visible_nodes && visibility_id < node_count && visible_nodes[visibility_id] != 0);
}

constexpr bool ottsel_mobile_scene_should_cull(bool no_cull_probe) {
  return !no_cull_probe;
}

constexpr bool ottsel_mobile_cpu_frame_should_draw(bool native_tfrag_ready,
                                                    bool native_tie_ready,
                                                    bool explicit_no_cpu_probe) {
  return explicit_no_cpu_probe || !(native_tfrag_ready && native_tie_ready);
}

constexpr bool ottsel_mobile_sprite_trace_trigger_may_consume(bool village1_phase) {
  return village1_phase;
}

// GS alpha mode SRC_SRC_SRC_SRC is a copy operation in the upstream OpenGL
// setup, even when the alpha-blend enable bit is set. Metal uses the ordinary
// pipeline for that mode rather than applying source-alpha blending.
constexpr bool ottsel_mobile_alpha_blend_enabled(bool alpha_blend_enable,
                                                  unsigned int alpha_blend_mode) {
  return alpha_blend_enable && (alpha_blend_mode & 7u) != 0u &&
         (alpha_blend_mode & 7u) != 6u;
}




enum class OttselMobileMeshProjection { PcCamera, MercPerspective };

constexpr bool ottsel_mobile_projection_uses_raw_perspective(
    OttselMobileMeshProjection projection) {
  return projection == OttselMobileMeshProjection::MercPerspective;
}

constexpr bool ottsel_mobile_depth_contract_is_upstream(float clear_depth,
                                                         bool greater_equal) {
  return clear_depth == 0.f && greater_equal;
}

enum class OttselMobileDepthCompare { Never, Always, GreaterEqual, Greater };

// GsTest uses bit 19 to enable depth testing and bits 1..2 for the compare
// function. Keep the mapping explicit so Metal does not collapse all draws
// into the GEQUAL path.
constexpr OttselMobileDepthCompare ottsel_mobile_depth_compare(bool enabled,
                                                               unsigned int test) {
  if (!enabled) {
    return OttselMobileDepthCompare::Always;
  }
  switch (test & 3u) {
    case 0:
      return OttselMobileDepthCompare::Never;
    case 1:
      return OttselMobileDepthCompare::Always;
    case 2:
      return OttselMobileDepthCompare::GreaterEqual;
    default:
      return OttselMobileDepthCompare::Greater;
  }
}

// Kept in the policy header so the focused regression observes the production
// contract instead of duplicating Metal literals.
constexpr float kOttselMobileDepthClear = 0.f;
constexpr bool kOttselMobileDepthGreaterEqual = true;
constexpr bool kOttselMobilePlayerRpcRouteEnabled = true;

// Upstream tfrag3.vert doubles the time-of-day color, then doubles alpha once
// more. The Metal shader must preserve that effective alpha multiplier.
constexpr float kOttselMobileTodAlphaMultiplier = 4.f;

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
