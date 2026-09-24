// Ottsel S2.0 — Metal shell surface (Objective-C++ implementation).
//
// Delivers the CPU-rendered log surface through a real Metal pipeline on
// the SDL window's CAMetalLayer: device, command queue, fullscreen
// textured-triangle pipeline, per-frame texture upload, present.

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

#include <SDL3/SDL.h>
#include <SDL3/SDL_metal.h>

#include <vector>
#include <algorithm>
#include <atomic>
#include <deque>
#include <mutex>
#include <map>
#include <string>
#include <memory>
#include <cmath>
#include <unordered_set>
#include <cstdio>
#include <cstddef>
#include <string>

#include "metal_shell.h"
#include "metal_encoder_guard.h"
#include "mobile_resource_retirement.h"
#include "mobile_command_timing.h"
#include "mobile_direct_depth_policy.h"
#include "mobile_scene_policy.h"
#include "mobile_snapshot_store.h"
#include "mobile_direct_frame.h"
#include "mobile_blend_policy.h"
#include "common/dma/ottsel_sprite_math.h"
#include "common/log/log.h"
#include "ios_boot.h"

namespace {

NSString* kShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct VSOut { float4 pos [[position]]; float2 uv; };\n"
"vertex VSOut vs_main(uint vid [[vertex_id]]) {\n"
"  const float2 pos[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };\n"
"  VSOut o;\n"
"  o.pos = float4(pos[vid], 0.0, 1.0);\n"
"  // flip v so top-left-origin CPU text renders upright\n"
"  o.uv = float2((pos[vid].x + 1.0) * 0.5, 1.0 - (pos[vid].y + 1.0) * 0.5);\n"
"  return o;\n"
"}\n"
"fragment float4 fs_main(VSOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {\n"
"  constexpr sampler s(filter::nearest, address::clamp_to_edge);\n"
"  return float4(tex.sample(s, in.uv).rgb, 1.0);\n"
"}\n";

NSString* kDirectFixtureShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct DirectIn { float2 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; "
"float4 color [[attribute(2)]]; float q [[attribute(3)]]; float z [[attribute(4)]]; };\n"
"struct DirectOut { float4 position [[position]]; float2 uv; float4 color; float q; };\n"
"struct DirectState { uint alpha_test_enable; uint alpha_test; uint alpha_ref; "
"uint tcc; uint tfx; uint ta0; };\n"
"vertex DirectOut direct_vs(DirectIn in [[stage_in]]) {\n"
"  DirectOut out; out.position = float4(in.pos, in.z, 1.0); out.uv = in.uv; "
"  out.q = in.q; out.color = float4(in.color.rgb, in.color.a * 2.0); return out;\n"
"}\n"
"// Sprite-only: pos/z carry homogeneous clip XYZ; q carries clip W.\n"
"vertex DirectOut sprite_vs(DirectIn in [[stage_in]]) {\n"
"  DirectOut out; out.position = float4(in.pos, in.z, in.q); out.uv = in.uv;\n"
"  out.q = 1.0; out.color = float4(in.color.rgb, in.color.a * 2.0); return out;\n"
"}\n"
"float2 direct_uv(DirectOut in) {\n"
"  // Desktop interpolates STQ before dividing. Retain a finite zero-Q fallback.\n"
"  return in.uv / (in.q != 0.0 ? in.q : 1.0);\n"
"}\n"
"fragment float4 direct_fs(DirectOut in [[stage_in]], texture2d<float> tex [[texture(0)]],\n"
"                           sampler s [[sampler(0)]],\n"
"                           constant DirectState& state [[buffer(1)]]) {\n"
"  float4 texel = tex.sample(s, direct_uv(in));\n"
"  // Reference direct_basic_textured.frag substitutes the GS TA0 register for\n"
"  // a zero texture alpha before modulation.  Without it a generated sky\n"
"  // buffer whose alpha is 0 blends to nothing under srcBlend=source alpha.\n"
"  if (texel.a == 0.0) { texel.a = float(state.ta0) / 255.0; }\n"
"  float4 color;\n"
"  if (state.tfx == 1) {\n"
"    color.rgb = texel.rgb * 0.5; color.a = state.tcc != 0 ? texel.a : in.color.a;\n"
"  } else {\n"
"    color.rgb = in.color.rgb * texel.rgb;\n"
"    color.a = state.tcc != 0 ? in.color.a * texel.a : in.color.a;\n"
"  }\n"
"  color *= 2.0;\n"
"  if (state.alpha_test_enable != 0) {\n"
"    float alpha_ref = float(state.alpha_ref) / 128.0;\n"
"    bool pass = true;\n"
"    switch (state.alpha_test) {\n"
"      case 0: pass = false; break;\n"
"      case 1: pass = true; break;\n"
"      case 2: pass = color.a < alpha_ref; break;\n"
"      case 3: pass = color.a <= alpha_ref; break;\n"
"      case 4: pass = color.a == alpha_ref; break;\n"
"      case 5: pass = color.a >= alpha_ref; break;\n"
"      case 6: pass = color.a > alpha_ref; break;\n"
"      case 7: pass = color.a != alpha_ref; break;\n"
"    }\n"
"    if (!pass) { discard_fragment(); }\n"
"  }\n"
"  return color;\n"
"}\n"
"fragment float4 direct_fs_solid(DirectOut in [[stage_in]]) {\n"
"  return in.color;\n"
"}\n"
"fragment float4 direct_fs_debug_fill(DirectOut in [[stage_in]]) {\n"
"  return float4(1.0, 0.0, 1.0, 1.0);\n"
"}\n"
"// Diagnostic-only: the real sampled texel with alpha forced opaque. Shows\n"
"// what texture the sky fan is bound to, independent of its alpha.\n"
"fragment float4 direct_fs_debug_tex(DirectOut in [[stage_in]],\n"
"                                    texture2d<float> tex [[texture(0)]],\n"
"                                    sampler s [[sampler(0)]]) {\n"
"  // BOT66 discriminator A/B, second half.  Continue to fetch the texture,\n"
"  // then clamp the fetched value to zero so the returned colour is a\n"
"  // constant that the compiler cannot fold the sample away from.  Painting\n"
"  // purple proves the bind + sample execute and the sampled VALUE is the\n"
"  // defect; still exactly pass-clear proves merely being a sampling pipeline\n"
"  // is what drops the draw.\n"
"  float4 t = tex.sample(s, direct_uv(in));\n"
"  return float4(0.5 + min(t.r, 0.0), 0.1 + min(t.g, 0.0), 0.9, 1.0);\n"
"}\n";

NSString* kTieShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct TieIn { float3 position [[attribute(0)]]; float2 uv [[attribute(1)]]; "
"ushort color_index [[attribute(2)]]; uchar4 rgba [[attribute(3)]]; float skin_w [[attribute(4)]]; };\n"
"struct TieUniforms { float4 pc_camera[4]; float4 merc_perspective[4]; float4 camera_trans; float4 fog_params; "
"float4 fog_color; float4 hvdf_offset; float fog_constant; float camera_sign; uint projection_mode; "
"uint merc_z_mode; };\n"
"struct TieMaterial { float alpha_min; float alpha_max; uint fog_enable; uint decal; "
"uint merc; };\n"
"struct TieOut { float4 position [[position]]; float2 uv; "
"float4 vtx_color; float fogginess; float3 fog_color; };\n"
"vertex TieOut tie_vs(TieIn in [[stage_in]], uint vertex_id [[vertex_id]], constant TieUniforms& u [[buffer(1)]], "
"constant uchar4* colors [[buffer(2)]], constant TieMaterial& material [[buffer(3)]]) {\n"
"  float original_w = 0.0;\n"
"  float4 transformed;\n"
"  if (u.projection_mode == 2u) {\n"
"    // Diagnostics-only fixture: positions are already Metal clip-space.\n"
"    transformed = float4(in.position, 1.0);\n"
"    original_w = 1.0;\n"
"  } else if (u.projection_mode != 0u) {\n"
"    // MERC vertices are already in bone-skinned camera space. Desktop\n"
"    // applies the raw perspective matrix, not the background pc_camera.\n"
"    transformed = u.merc_perspective[0] * in.position.x;\n"
"    transformed += u.merc_perspective[1] * in.position.y;\n"
"    transformed += u.merc_perspective[2] * in.position.z;\n"
"    transformed += u.merc_perspective[3] * in.skin_w;\n"
"    original_w = transformed.w;\n"
"    float Q = u.fog_constant / transformed.w;\n"
"    transformed.xyz *= Q;\n"
"    transformed.xyz += u.hvdf_offset.xyz;\n"
"    transformed.xy -= float2(2048.0);\n"
"    transformed.z /= 8388608.0;\n"
"    if (u.merc_z_mode == 0u) {\n"
"      transformed.z -= 1.0;\n"
"    } else if (u.merc_z_mode == 2u) {\n"
"      transformed.z = -transformed.z;\n"
"    } else if (u.merc_z_mode == 3u) {\n"
"      transformed.z = -transformed.z - 1.0;\n"
"    } else if (u.merc_z_mode == 4u) {\n"
"      transformed.z = transformed.z * 0.5 + 0.5;\n"
"    }\n"
"    transformed.x /= 256.0;\n"
"    transformed.y /= -128.0;\n"
"    transformed.xyz *= transformed.w;\n"
"  } else {\n"
"    float3 vert = in.position - u.camera_trans.xyz;\n"
"    transformed = -u.pc_camera[3];\n"
"    transformed.w = 0.0;\n"
"    transformed -= u.pc_camera[0] * vert.x;\n"
"    transformed -= u.pc_camera[1] * vert.y;\n"
"    transformed -= u.pc_camera[2] * vert.z;\n"
"    original_w = transformed.w;\n"
"    if (u.camera_sign < 0.0) {\n"
"      float Q = u.fog_constant / transformed.w;\n"
"      transformed.xyz *= Q;\n"
"      transformed.xyz += u.hvdf_offset.xyz;\n"
"      transformed.xy -= float2(2048.0);\n"
"      transformed.z /= 8388608.0;\n"
"      transformed.z -= 1.0;\n"
"      transformed.x /= 256.0;\n"
"      transformed.y /= -128.0;\n"
"      transformed.xyz *= transformed.w;\n"
"    }\n"
"  }\n"
"  transformed.y *= (512.0 / 448.0);\n"
"  transformed.z = (transformed.z + transformed.w) * 0.5;\n"
"  TieOut out; out.position = transformed; out.uv = in.uv; "
"out.vtx_color = material.merc != 0 ? reinterpret_cast<constant float4*>(colors)[vertex_id] "
"                                  : float4(colors[in.color_index]) / 255.0; "
"out.fogginess = 255.0 - clamp(-original_w + u.fog_params.x, u.fog_params.y, u.fog_params.z); "
"out.fog_color = u.fog_color.xyz; "
"return out;\n"
"}\n"
"fragment float4 tie_fs(TieOut in [[stage_in]], texture2d<float> tex [[texture(0)]], "
"constant TieMaterial& material [[buffer(1)]], "
"sampler tex_sampler [[sampler(0)]]) {\n"
"  float4 texel = tex.sample(tex_sampler, in.uv);\n"
"  // Interpolate resolved TFRAG/TIE table colors, matching tfrag3.vert.\n"
"  // MERC retains its own interpolated vertex RGBA shade.\n"
"  float4 tod = in.vtx_color;\n"
"  float4 color = float4(texel.rgb * (material.decal != 0 ? float3(1.0) : tod.rgb * 2.0),\n"
  "                        texel.a * tod.a * 4.0);\n"
  "  // Match tfrag3.vert: the interpolated time-of-day color is doubled once\n"
  "  // alpha is doubled again by the upstream vertex path.\n"
"  if (color.a < material.alpha_min || color.a > material.alpha_max) discard_fragment();\n"
"  if (material.fog_enable != 0) {\n"
"    color.rgb = mix(color.rgb, in.fog_color, clamp(in.fogginess * 0.0039215686, 0.0, 1.0));\n"
"  }\n"
"  return color;\n"
"}\n";

struct TieUniforms {
  float pc_camera[16];
  float merc_perspective[16];
  float camera_trans[4];
  float fog_params[4];
  float fog_color[4];
  float hvdf_offset[4];
  float fog_constant = 0.f;
  float camera_sign = 1.f;
  uint32_t projection_mode = 0;
  uint32_t merc_z_mode = 0;
};

struct TieMaterial {
  float alpha_min;
  float alpha_max;
  uint32_t fog_enable;
  uint32_t decal;
  uint32_t merc;
};

// Layout-compatible diagnostic vertex for the TFRAG pipeline. The fixture
// uses clip-space positions directly and never enters the product path.
struct OttselTfragFixtureVertex {
  float x, y, z;
  unsigned char rgba[4];
  float s, t;
  unsigned int nor;
  unsigned short color_index;
  unsigned short padding;
};
static_assert(sizeof(OttselTfragFixtureVertex) == 32);

struct DirectFixtureVertex {
  float pos[2];
  float uv[2];
  float color[4];
  float q = 1.f;
  float z = 0.f;
};
static_assert(sizeof(DirectFixtureVertex) == 40);
static_assert(sizeof(OttselMetalSpriteVertex) == sizeof(DirectFixtureVertex));
static_assert(sizeof(OttselMetalOverlayVertex) == sizeof(DirectFixtureVertex));
static_assert(offsetof(OttselMetalSpriteVertex, q) == offsetof(DirectFixtureVertex, q));
static_assert(offsetof(OttselMetalOverlayVertex, q) == offsetof(DirectFixtureVertex, q));
static_assert(offsetof(OttselMetalSpriteVertex, z) == offsetof(DirectFixtureVertex, z));
static_assert(offsetof(OttselMetalOverlayVertex, z) == offsetof(DirectFixtureVertex, z));

struct PendingDirectUpload {
  std::vector<unsigned char> rgba;
  NSUInteger width = 0;
  NSUInteger height = 0;
  unsigned long long texture_key = 0;
};

struct PendingTieUpload {
  std::vector<unsigned int> rgba;
  NSUInteger index = 0;
  NSUInteger width = 0;
  NSUInteger height = 0;
};

struct PendingColorUpload {
  std::string level;
  std::vector<unsigned char> rgba;
  bool tfrag = false;
};

struct PendingMeshUpload {
  std::string level;
  std::vector<unsigned char> vertices;
  std::vector<unsigned int> indices;
  std::vector<OttselMetalTieDraw> draws;
  bool tfrag = false;
};

using SceneKey = std::pair<std::string, bool>; // level, TFRAG (otherwise TIE)
struct InstalledSceneMesh {
  id<MTLBuffer> vertices = nil, indices = nil, colors = nil;
  NSUInteger index_count = 0;
  std::vector<OttselMetalTieDraw> draws;
};
struct SceneFrameReference { SceneKey key; TieUniforms uniforms; };
struct SceneFrameTransaction {
  std::vector<SceneFrameReference> refs;
  std::deque<PendingMeshUpload> meshes;
  std::deque<PendingColorUpload> colors;
};

struct PendingSpriteUpload {
  std::vector<OttselMetalSpriteVertex> vertices;
  std::vector<unsigned char> rgba;
  NSUInteger width = 0;
  NSUInteger height = 0;
  NSUInteger vertex_count = 0;
  BOOL blended = NO;
};

struct NativeSpriteBatch {
  id<MTLBuffer> vertices = nil;
  id<MTLTexture> texture = nil;
  NSUInteger vertex_count = 0;
  BOOL blended = NO;
  // GS TA0 for this batch: substituted for a zero texture alpha by direct_fs,
  // matching the reference DirectRenderer fragment shader.
  unsigned char ta0 = 0;
  bool persistent = false;
  OttselMetalDirectDepthState depth{};
  bool has_gs_depth = false;
  unsigned long long diagnostic_alpha = 0;
};

#if TARGET_OS_SIMULATOR
struct CommandPacingTrace {
  std::mutex mutex;
  std::vector<ottsel_command_timing::Sample> samples;
  unsigned submitted=0, received=0, capped=0;
  double first_submit=0,last_submit=0;
  bool finished=false;
};
static void finish_command_pacing(const std::shared_ptr<CommandPacingTrace>& trace,const char* reason) {
  std::lock_guard<std::mutex> lock(trace->mutex);
  if(trace->finished)return;
  trace->finished=true;
  const auto summary=ottsel_command_timing::summarize(trace->samples);
  const unsigned missing=trace->submitted-trace->received;
  const double duration=trace->last_submit-trace->first_submit;
  const double submit_hz=trace->submitted>1&&duration>0 ? (trace->submitted-1)/duration : 0;
  NSLog(@"OTTSEL COMMAND PACING: reason=%s submitted=%u completed=%u missing=%u capped=%u errors=%u "
         "cpu-submit-hz=%.3f cpu-completion-hz=%.3f completion-cadence-valid=%d "
         "gpu-duration-valid=%d gpu-ms-p50=%.3f gpu-ms-p95=%.3f gpu-interval-valid=%d "
         "gpu-start-interval-ms-p95=%.3f invalid-cpu=%u invalid-gpu=%u coverage=%s display-fps=unavailable",
        reason,trace->submitted,trace->received,missing,trace->capped,summary.errors,submit_hz,
        summary.completion_hz,summary.completion_cadence_available,summary.gpu_duration_available,
        summary.gpu_ms_p50,summary.gpu_ms_p95,summary.gpu_interval_available,
        summary.gpu_start_interval_ms_p95,summary.invalid_cpu,summary.invalid_gpu,
        !missing&&!trace->capped&&!summary.errors&&!summary.invalid_cpu ? "complete-cb-sample" : "incomplete-cb-sample");
}
static void trace_command_pacing(id<MTLCommandBuffer> cb) {
  static std::mutex manager_mutex;
  static std::shared_ptr<CommandPacingTrace> active;
  std::lock_guard<std::mutex> manager_lock(manager_mutex);
  if(active) {
    const auto previous=active;
    std::lock_guard<std::mutex> lock(previous->mutex);
    if(previous->finished)active.reset();
  }
  if(!active) {
    const std::string trigger=ottsel_ios_writable_dir()+"ottsel-trace-frame-pacing";
    if(unlink(trigger.c_str())!=0)return;
    active=std::make_shared<CommandPacingTrace>();active->samples.reserve(300);
    const auto timeout_trace=active;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30LL*NSEC_PER_SEC),
      dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{finish_command_pacing(timeout_trace,"30s-timeout");});
    NSLog(@"OTTSEL COMMAND PACING: armed max-buffers=300 max-pending=8 timeout-s=30 display-fps=unavailable");
  }
  const auto trace=active;
  const double submit=CACurrentMediaTime();
  {
    std::lock_guard<std::mutex> lock(trace->mutex);
    if(trace->finished||trace->submitted>=300)return;
    if(trace->submitted-trace->received>=8){++trace->capped;return;}
    if(!trace->submitted)trace->first_submit=submit;
    trace->last_submit=submit;++trace->submitted;
  }
  [cb addCompletedHandler:^(id<MTLCommandBuffer> completed){
    const double cpu_complete=CACurrentMediaTime();
    bool done;
    {
      std::lock_guard<std::mutex> lock(trace->mutex);
      if(trace->finished)return;
      ++trace->received;
      trace->samples.push_back({submit,cpu_complete,completed.GPUStartTime,completed.GPUEndTime,
                               completed.status==MTLCommandBufferStatusCompleted&&!completed.error});
      done=trace->received==300;
    }
    if(done)finish_command_pacing(trace,"300-callbacks");
  }];
}
#endif

#include "metal_sky_isolation.h"

// presentedTime is absent from the installed Simulator SDK. Never substitute
// command completion or draw submission counts for actual display timestamps.
#if !TARGET_OS_SIMULATOR
struct FramePacingTrace {
  std::mutex mutex;
  std::vector<double> timestamps;
  unsigned submitted = 0, received = 0, invalid = 0, capped = 0;
  bool finished = false;
};

static void finish_frame_pacing(const std::shared_ptr<FramePacingTrace>& trace,
                                const char* reason) {
  std::lock_guard<std::mutex> lock(trace->mutex);
  if (trace->finished) return;
  trace->finished = true;
  auto times = trace->timestamps;
  std::sort(times.begin(), times.end());
  times.erase(std::unique(times.begin(), times.end()), times.end());
  const auto missing = trace->submitted - trace->received;
  const auto duplicates = trace->timestamps.size() - times.size();
  if (times.size() < 2) {
    NSLog(@"OTTSEL FRAME PACING: source=presentedTime reason=%s samples=%lu "
          "missing=%u zero-or-invalid=%u duplicates=%lu capped=%u fps=unavailable",
          reason, (unsigned long)times.size(), missing, trace->invalid,
          (unsigned long)duplicates, trace->capped);
    return;
  }
  std::vector<double> intervals;
  for (size_t i = 1; i < times.size(); ++i) {
    intervals.push_back((times[i] - times[i - 1]) * 1000.);
  }
  std::sort(intervals.begin(), intervals.end());
  const auto percentile = [&](double quantile) {
    return intervals[(size_t)std::ceil(quantile * intervals.size()) - 1];
  };
  const double duration = times.back() - times.front();
  const bool complete_coverage = !missing && !trace->invalid && !duplicates && !trace->capped;
  NSLog(@"OTTSEL FRAME PACING: source=presentedTime reason=%s samples=%lu "
        "duration-s=%.6f sampled-fps=%.3f coverage=%s p50-ms=%.3f p95-ms=%.3f "
        "p99-ms=%.3f missing=%u zero-or-invalid=%u duplicates=%lu capped=%u",
        reason, (unsigned long)times.size(), duration, intervals.size() / duration,
        complete_coverage ? "complete" : "incomplete-not-display-fps",
        percentile(.50), percentile(.95), percentile(.99), missing, trace->invalid,
        (unsigned long)duplicates, trace->capped);
}
#endif

static void trace_frame_pacing(id<CAMetalDrawable> drawable, id<MTLCommandBuffer> cb) {
#if TARGET_OS_SIMULATOR
  (void)drawable;
  trace_command_pacing(cb);
#else
  static std::mutex manager_mutex;
  static std::shared_ptr<FramePacingTrace> active;
  std::lock_guard<std::mutex> manager_lock(manager_mutex);
  if (active) {
    const auto previous = active;  // Keep its mutex alive through unlock.
    std::lock_guard<std::mutex> lock(previous->mutex);
    if (previous->finished) active.reset();
  }
  if (!active) {
    const std::string trigger = ottsel_ios_writable_dir() + "ottsel-trace-frame-pacing";
    if (unlink(trigger.c_str()) != 0) return;
    active = std::make_shared<FramePacingTrace>();
    active->timestamps.reserve(300);
    const auto timeout_trace = active;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30LL * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      finish_frame_pacing(timeout_trace, "30s-timeout");
    });
    NSLog(@"OTTSEL FRAME PACING: armed source=presentedTime max-drawables=300 "
          "max-pending=8 timeout-s=30");
  }
  const auto trace = active;
  {
    std::lock_guard<std::mutex> lock(trace->mutex);
    if (trace->finished || trace->submitted >= 300) return;
    if (trace->submitted - trace->received >= 8) {
      ++trace->capped;
      return;
    }
    ++trace->submitted;
  }
  [drawable addPresentedHandler:^(id<MTLDrawable> presented) {
    bool done;
    {
      std::lock_guard<std::mutex> lock(trace->mutex);
      if (trace->finished) return;
      ++trace->received;
      const double time = presented.presentedTime;
      if (std::isfinite(time) && time > 0.) trace->timestamps.push_back(time);
      else ++trace->invalid;
      done = trace->received == 300;
    }
    if (done) finish_frame_pacing(trace, "300-callbacks");
  }];
#endif
}

}  // namespace

// Key for content-keyed quad texture reuse.  FNV-1a over the pixel words,
// seeded with the dimensions so equal-size collisions cannot alias.
static unsigned long long mesh_texture_key(const unsigned char* rgba,
                                           NSUInteger width,
                                           NSUInteger height) {
  const unsigned long long prime = 1099511628211ULL;
  unsigned long long h = 1469598103934665603ULL;
  h = (h ^ (unsigned long long)width) * prime;
  h = (h ^ (unsigned long long)height) * prime;
  const NSUInteger n = width * height * 4;
  // Hash the leading 512 bytes in full (tile headers and palettes live there),
  // then sample the remainder on a 64-byte stride.  The cache only trusts a key
  // once the retained bytes also memcmp equal, so the stride can cost a cache
  // miss but never a wrong texture.  Walking every byte of every tile every
  // frame measured ~11% of the game thread on the Simulator, and re-submitted
  // tiles are byte-identical, so they collide under any deterministic hash.
  const NSUInteger head = n < 512 ? n : 512;
  for (NSUInteger i = 0; i < head; ++i) {
    h = (h ^ rgba[i]) * prime;
  }
  for (NSUInteger i = head; i + 8 <= n; i += 64) {
    unsigned long long w = 0;
    memcpy(&w, rgba + i, sizeof(w));
    h = (h ^ w) * prime;
  }
  if (n >= 8) {
    unsigned long long tail = 0;
    memcpy(&tail, rgba + n - 8, sizeof(tail));
    h = (h ^ tail) * prime;
  }
  return h;
}

// I3: the on-screen controls are drawn by the shell, not by UIKit, so nothing would name them to VoiceOver.
// This transparent container sits over the Metal view, never takes a touch (-hitTest: returns nil) and
// publishes one UIAccessibilityElement per touch region with a spoken label and a frame in its own space.
@interface OttselAccessibilityView : UIView
- (void)setRegions:(const OttselAccessibilityRegion*)regions count:(unsigned int)count;
- (void)logRegions;
@end

@implementation OttselAccessibilityView {
  std::vector<OttselAccessibilityRegion> _regions;
  NSMutableArray<UIAccessibilityElement*>* _elements;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _elements = [NSMutableArray array];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = NO;
  }
  return self;
}

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
  return nil;  // the game keeps every touch
}

- (void)setRegions:(const OttselAccessibilityRegion*)regions count:(unsigned int)count {
  _regions.clear();
  [_elements removeAllObjects];
  if (!regions || count == 0) {
    return;  // an empty publish clears the layer, which is what a hidden surface wants
  }
  _regions.assign(regions, regions + count);
  for (unsigned int i = 0; i < count; ++i) {
    UIAccessibilityElement* element =
        [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
    element.accessibilityLabel =
        [NSString stringWithUTF8String:regions[i].label ? regions[i].label : ""];
    element.accessibilityTraits = UIAccessibilityTraitButton;
    [_elements addObject:element];
  }
}

- (NSInteger)accessibilityElementCount {
  return (NSInteger)_elements.count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)_elements.count) {
    return nil;
  }
  UIAccessibilityElement* element = _elements[(NSUInteger)index];
  const OttselAccessibilityRegion& region = _regions[(NSUInteger)index];
  const CGRect bounds = self.bounds;
  element.accessibilityFrameInContainerSpace =
      CGRectMake(bounds.origin.x + region.x * bounds.size.width,
                 // The overlay's own normalised y runs from the top of the surface down (its rects map
                 // y=0 to clip y=+1), which is UIKit's own convention, so no flip is needed: the element
                 // box is the drawn box.  A flip here put every control on the wrong half of the screen.
                 bounds.origin.y + region.y * bounds.size.height,
                 region.w * bounds.size.width, region.h * bounds.size.height);
  return element;
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
  return (NSInteger)[_elements indexOfObject:element];
}

- (void)logRegions {
  const NSInteger count = [self accessibilityElementCount];
  lg::info("OTTSEL A11Y: container-elements={} view-frame=({:.0f},{:.0f},{:.0f},{:.0f})", (long)count,
           self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
  for (NSInteger i = 0; i < count; ++i) {
    UIAccessibilityElement* element = [self accessibilityElementAtIndex:i];
    const CGRect frame = element.accessibilityFrameInContainerSpace;
    const char* label = element.accessibilityLabel.UTF8String;
    lg::info("OTTSEL A11Y: i={} label='{}' frame=({:.3f},{:.3f},{:.3f},{:.3f}) traits=0x{:x}", (long)i,
             label ? label : "", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
             (unsigned long long)element.accessibilityTraits);
  }
}
@end

@interface OttselMetalRenderer : NSObject

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directBlendPipeline;
// G2.2: GS ALPHA 0x48 (S/Z/S/D) draws as (Cs-0)*As + Cd, so it needs its own
// state; the source-over pipeline stays the fallback for every other key.
@property (nonatomic, strong) id<MTLRenderPipelineState> directAdditivePipeline;
// G2.2 attribution: while `ottsel-trace-sky-skip-draw` exists the Sky batch loop
// issues no draws at all, so whatever is still on screen cannot be a Sky batch.
@property (nonatomic) BOOL skySkipDraw;
// G2.2: the sky bucket's quads sample the composited sky texture upstream
// produces in its SkyBlend buckets.  The native producer
// (produce_mobile_sky_blend_bucket) now builds that composite, so those quads are
// drawn by default and render the real sky; the skip was owed to the composite not
// existing yet, which made the fan sample the uncomposited source and rainbow.
// This flag forces the draw for a same-run A/B.
@property (nonatomic) BOOL skyDrawLegacy;
@property (nonatomic, strong) id<MTLRenderPipelineState> spritePipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> spriteBlendPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directNoDepthPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directColorOnlyPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> tiePipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> tieBlendPipeline;
@property (nonatomic, strong) id<MTLDepthStencilState> tieNoWriteDepthState;
@property (nonatomic, strong) NSArray* tieDepthStates;
@property (nonatomic, strong) NSArray* tieNoWriteDepthStates;
@property (nonatomic, strong) CAMetalLayer* layer;
// I3: the accessibility container over the Metal view (see OttselAccessibilityView above).
@property (nonatomic, strong) OttselAccessibilityView* accessibilityContainer;
// I3 VIDEO: the render scale in percent; the drawable is bounds * contentsScale * this / 100.
@property (nonatomic) NSUInteger renderScalePercent;
@property (nonatomic, strong) id<MTLTexture> logTex;
@property (nonatomic, strong) id<MTLTexture> tfragFixtureTexture;
@property (nonatomic, strong) id<MTLTexture> directTex;
@property (nonatomic, strong) id<MTLSamplerState> directSampler;
@property (nonatomic, strong) NSMutableDictionary* directTextures;
@property (nonatomic, strong) id<MTLBuffer> directVertices;
@property (nonatomic, strong) id<MTLBuffer> spriteVertices;
@property (nonatomic, strong) id<MTLTexture> spriteTex;
@property (nonatomic) BOOL spriteActive;
@property (nonatomic) NSUInteger spriteVertexCount;
@property (nonatomic) BOOL spriteBlendEnabled;
@property (nonatomic, strong) id<MTLBuffer> touchOverlayVertices;
@property (nonatomic, strong) id<MTLTexture> touchOverlayTex;
@property (nonatomic) NSUInteger touchOverlayVertexCount;
// F1/G2.6: the shell status screen, uploaded as one texture and drawn last.
@property (nonatomic, strong) id<MTLTexture> statusOverlayTex;
@property (nonatomic, strong) id<MTLBuffer> statusOverlayVertices;
@property (nonatomic) NSUInteger statusOverlayVertexCount;
@property (nonatomic) BOOL directFixtureActive;
@property (nonatomic) BOOL directFixtureIsolated;
@property (nonatomic) BOOL directFixtureNoDepth;
@property (nonatomic) BOOL directFixtureColorOnly;
@property (nonatomic) BOOL directFixtureOffscreen;
@property (nonatomic) BOOL sceneNoDepthProbe;
@property (nonatomic) BOOL sceneSkyOpaqueProbe;
@property (nonatomic) BOOL sceneSkyDebugFillProbe;
@property (nonatomic) BOOL sceneSkyDebugFillAllProbe;
  // BOT66: draws one private-buffer magenta triangle from INSIDE the sky loop,
  // in isolation, so "the loop's draw calls execute at all" is separable from
  // "the loop's own batch buffers rasterize".  Observability only.
  @property (nonatomic) BOOL sceneSkyInsideProbe;
@property (nonatomic) BOOL sceneSkyEndProbe;
@property (nonatomic, strong) id<MTLRenderPipelineState> skyDebugFillPipeline;
@property (nonatomic) BOOL sceneSkyDebugTexProbe;
@property (nonatomic, strong) id<MTLRenderPipelineState> skyDebugTexPipeline;
@property (nonatomic) BOOL sceneNoTieProbe;
@property (nonatomic) BOOL sceneNoMercProbe;
@property (nonatomic) BOOL sceneNoTfragProbe;
@property (nonatomic) BOOL sceneNoCpuFrameProbe;
@property (nonatomic) BOOL sceneNoOverlayProbe;
@property (nonatomic) BOOL sceneNoSkyProbe;
@property (nonatomic) BOOL sceneNoSpriteProbe;
@property (nonatomic) BOOL sceneTfragFixture;
@property (nonatomic) BOOL sceneTieReferenceProjectionProbe;
@property (nonatomic) BOOL sceneFirstBatchProbe;
@property (nonatomic) NSUInteger sceneDrawLimit;
@property (nonatomic, strong) id<MTLTexture> directOffscreenTarget;
@property (nonatomic) unsigned long long directTex0;
@property (nonatomic) unsigned long long directFrame;
@property (nonatomic) unsigned long long directPrim;
@property (nonatomic) unsigned long long directAlpha;
@property (nonatomic) unsigned long long directTest;
@property (nonatomic) unsigned long long directZbuf;
@property (nonatomic) BOOL directBlendEnabled;
@property (nonatomic) unsigned int directAlphaTestEnable;
@property (nonatomic) unsigned int directAlphaTest;
@property (nonatomic) unsigned int directAlphaRef;
@property (nonatomic) unsigned int directTcc;
@property (nonatomic) unsigned int directTfx;
@property (nonatomic) NSUInteger directDrawCount;
@property (nonatomic) NSUInteger directTriangleCount;
@property (nonatomic) unsigned int directScissorX0;
@property (nonatomic) unsigned int directScissorX1;
@property (nonatomic) unsigned int directScissorY0;
@property (nonatomic) unsigned int directScissorY1;
@property (nonatomic, strong) id<MTLBuffer> tieVertices;
@property (nonatomic, strong) id<MTLBuffer> tieIndices;
@property (nonatomic, strong) id<MTLBuffer> tieColors;
@property (nonatomic, strong) id<MTLBuffer> tfragVertices;
@property (nonatomic, strong) id<MTLBuffer> tfragIndices;
@property (nonatomic, strong) id<MTLBuffer> tfragColors;
@property (nonatomic, strong) id<MTLBuffer> mercVertices;
@property (nonatomic, strong) id<MTLBuffer> mercIndices;
@property (nonatomic, strong) id<MTLBuffer> mercColors;
@property (nonatomic, strong) NSMutableArray* tieTextures;
@property (nonatomic, strong) NSArray* tieSamplers;
@property (nonatomic, strong) id<MTLTexture> tieDepth;
@property (nonatomic, strong) id<MTLDepthStencilState> tieDepthState;
@property (nonatomic, strong) id<MTLDepthStencilState> directDepthState;
@property (nonatomic, strong) id<MTLDepthStencilState> spriteDepthState;
// G2.2 HUD parity: how many sprite batches the store holds right now.
@property (nonatomic, readonly) NSUInteger spriteStoreSize;
@property (nonatomic, strong) id<MTLDepthStencilState> overlayDepthState;
@property (nonatomic) NSUInteger tieIndexCount;
@property (nonatomic) NSUInteger tfragIndexCount;
@property (nonatomic) NSUInteger mercIndexCount;
@property (nonatomic) TieUniforms tieUniforms;
- (void)beginSceneFrame;
- (void)referenceScene:(const char*)level tfrag:(BOOL)tfrag;
- (void)publishSceneFrame;
- (BOOL)setupWithWindow:(SDL_Window*)win width:(int)w height:(int)h;
- (void)presentRGBA:(const unsigned char*)rgba width:(int)w height:(int)h;
- (void)setTieMesh:(const void*)vertices
        vertexCount:(NSUInteger)vertexCount
     triangleIndices:(const unsigned int*)indices
          indexCount:(NSUInteger)indexCount
              draws:(const OttselMetalTieDraw*)draws
          drawCount:(NSUInteger)drawCount level:(const char*)level;
- (void)setTieCamera:(const float*)pcCamera
          mercPerspective:(const float*)mercPerspective
         cameraTrans:(const float*)cameraTrans
           fogParams:(const float*)fogParams
            fogColor:(const float*)fogColor
          hvdfOffset:(const float*)hvdfOffset
        fogConstant:(float)fogConstant;
- (void)setTieTextureAtIndex:(NSUInteger)index
                         rgba:(const unsigned int*)rgba
                        width:(NSUInteger)width
                       height:(NSUInteger)height;
- (void)setTieTextureNowAtIndex:(NSUInteger)index
                            rgba:(const unsigned int*)rgba
                           width:(NSUInteger)width
                          height:(NSUInteger)height;
- (void)drainTieTextureUploads;
- (void)setColorsNow:(const unsigned char*)rgba count:(NSUInteger)count tfrag:(BOOL)tfrag level:(const char*)level;
- (void)setMeshNow:(const void*)vertices
       vertexCount:(NSUInteger)vertexCount
    triangleIndices:(const unsigned int*)indices
         indexCount:(NSUInteger)indexCount
             draws:(const OttselMetalTieDraw*)draws
         drawCount:(NSUInteger)drawCount
            tfrag:(BOOL)tfrag level:(const char*)level;
- (void)drainSceneFrame;
- (void)drainMercUploads;
- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count level:(const char*)level;
- (void)setTfragMesh:(const void*)vertices
         vertexCount:(NSUInteger)vertexCount
      triangleIndices:(const unsigned int*)indices
           indexCount:(NSUInteger)indexCount
               draws:(const OttselMetalTieDraw*)draws
           drawCount:(NSUInteger)drawCount level:(const char*)level;
- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count level:(const char*)level;
- (void)appendMercMesh:(const void*)vertices
          vertexCount:(NSUInteger)vertexCount
            litRGBA:(const float*)litRGBA
       triangleIndices:(const unsigned int*)indices
            indexCount:(NSUInteger)indexCount
                draws:(const OttselMetalTieDraw*)draws
            drawCount:(NSUInteger)drawCount;
- (void)setMercActorMesh:(const void*)vertices
            vertexCount:(NSUInteger)vertexCount
            litRGBA:(const float*)litRGBA
         triangleIndices:(const unsigned int*)indices
              indexCount:(NSUInteger)indexCount
                  draws:(const OttselMetalTieDraw*)draws
              drawCount:(NSUInteger)drawCount;
- (void)setSpriteMesh:(const OttselMetalSpriteVertex*)vertices
                 rgba:(const unsigned char*)rgba
                width:(NSUInteger)width
                height:(NSUInteger)height
                blended:(BOOL)blended;
- (void)setSpriteMeshNow:(const OttselMetalSpriteVertex*)vertices
              vertexCount:(NSUInteger)vertexCount
                    rgba:(const unsigned char*)rgba
                   width:(NSUInteger)width
                 height:(NSUInteger)height
                 blended:(BOOL)blended;
- (void)appendSpriteMeshNow:(const OttselMetalSpriteVertex*)vertices
                vertexCount:(NSUInteger)vertexCount
                      rgba:(const unsigned char*)rgba
                      width:(NSUInteger)width
                     height:(NSUInteger)height
                      blended:(BOOL)blended;
- (id<MTLTexture>)cachedMeshTexture:(const unsigned char*)rgba
                              width:(NSUInteger)width
                             height:(NSUInteger)height;
- (id<MTLBuffer>)borrowVertexBufferBytes:(NSUInteger)bytes;
- (void)recycleVertexBuffers:(const std::vector<id<MTLBuffer>>&)buffers
                      after:(id<MTLCommandBuffer>)cb;
- (void)beginSkyBucket;
- (void)finishSkyBucket:(BOOL)complete;
- (BOOL)appendSkyMeshNow:(const OttselMetalSpriteVertex*)vertices
             vertexCount:(NSUInteger)vertexCount
                   rgba:(const unsigned char*)rgba
                  width:(NSUInteger)width
                 height:(NSUInteger)height
                blended:(BOOL)blended
                    ta0:(unsigned char)ta0
                  depth:(const OttselMetalDirectDepthState*)depth diagnosticAlpha:(unsigned long long)diagnosticAlpha;
- (void)appendDirectMeshNow:(const OttselMetalSpriteVertex*)vertices
                vertexCount:(NSUInteger)vertexCount
                      rgba:(const unsigned char*)rgba
                     width:(NSUInteger)width
                    height:(NSUInteger)height
                   blended:(BOOL)blended
                       ta0:(unsigned char)ta0
                  depth:(const OttselMetalDirectDepthState*)depth diagnosticAlpha:(unsigned long long)diagnosticAlpha;
- (id<MTLDepthStencilState>)depthStateForDirectBatch:(const NativeSpriteBatch&)batch;
- (void)clearSpriteBatches;
- (void)clearTransientSpriteBatches;
- (void)drainSpriteUploads;
- (void)setTouchOverlay:(const OttselMetalOverlayVertex*)vertices
                  count:(NSUInteger)count;
- (void)uploadDirectTexture:(const unsigned char*)rgba
                      width:(NSUInteger)width
                     height:(NSUInteger)height
                textureKey:(unsigned long long)textureKey;
- (void)uploadDirectTextureNow:(const unsigned char*)rgba
                         width:(NSUInteger)width
                        height:(NSUInteger)height
                   textureKey:(unsigned long long)textureKey;
- (void)drainDirectTextureUploads;
@end

@implementation OttselMetalRenderer

{
  std::vector<OttselMetalTieDraw> _tieDraws;
  std::vector<OttselMetalTieDraw> _tfragDraws;
  std::mutex _directUploadMutex;
  std::deque<PendingDirectUpload> _pendingDirectUploads;
  std::unordered_set<unsigned long long> _queuedDirectUploadKeys;
  std::mutex _tieUploadMutex;
  std::unordered_set<NSUInteger> _queuedTieTextureIndices;
  std::mutex _tieUniformMutex;
  std::deque<PendingTieUpload> _pendingTieUploads;
  std::deque<PendingColorUpload> _pendingColorUploads;
  std::deque<PendingMeshUpload> _pendingMeshUploads;
  std::map<SceneKey, InstalledSceneMesh> _sceneMeshes, _sceneStagingMeshes;
  std::unique_ptr<SceneFrameTransaction> _completedSceneFrame;
  std::vector<SceneFrameReference> _buildingSceneFrame, _activeSceneFrame;
  std::mutex _spriteUploadMutex;
  std::deque<PendingSpriteUpload> _pendingSpriteUploads;
  OttselMobileSnapshotStore<NativeSpriteBatch> _spriteBatches;
  OttselMobileDirectFrame<NativeSpriteBatch> _skyFrameStore;
  // G2.2 Sky-store probe budget (observability only; see the SKYSTORE line in
  // the draw pass).  Bounded so the ledger can never flood the runtime log.
  unsigned long _skyStoreProbeLogs;  // zeroed by -alloc like the other ivars
  // G2.2 blend ledger.  Observability only: re-armed on every scene-level
  // selection, then records a bounded sample of the raw GS blend registers the
  // three live sites (Sky batches, TIE draws, Direct batches) actually request.
  BOOL _blendLedgerArmed;
  // Last logged register mix per site, so each distinct population is recorded
  // once instead of once per level selection.
  unsigned long long _skyMixReg[4];
  unsigned long _skyMixCount[4];
  unsigned long _skyMixOther;
  unsigned long _skyMixTextured;
  unsigned long _skyMixUntextured;
  unsigned long _skyMixLines;
  // G2.2 Sky blend selection ledger: the last logged (forced, additive-drawn,
  // per-key counts) so each distinct selection is recorded once.
  unsigned long _skyBlendLogAdditive;
  unsigned long _skyBlendLogKeys[8];
  unsigned long _skyBlendLogLines;
  unsigned long long _directMixReg[4];
  unsigned long _directMixCount[4];
  unsigned long _directMixOther;
  unsigned long _directMixLines;
  unsigned long _blendLedgerTieDraws;
  unsigned long _blendLedgerTiePreset[8];
  unsigned long _blendLedgerTieEnable[2];
  unsigned long _blendLedgerTieBlend[2];
  BOOL _blendLedgerTieLogged;
  unsigned long _blendLedgerArms;
  std::shared_ptr<SkyIsolationProbe> _skyIsolation;
  // Foreground Direct/GIF geometry (title logo, "PRESS START", debug/menu
  // text).  The desktop draws these after the world and after sprites, so they
  // live in their own store with a later draw position rather than in the
  // pre-world sky batch list.
  OttselMobileDirectFrame<NativeSpriteBatch> _directFrameStore;
  // Content-keyed reuse of the sky/Direct quad textures.  On the Simulator
  // every -replaceRegion: is a synchronous XPC round-trip to MTLSimDriver, and
  // the sky bucket re-submits up to 40 byte-identical tiles every frame, so
  // re-uploading them dominated the game thread's DMA chain.  The retained
  // pixels make a hit exact rather than hash-trusted.
  NSMutableDictionary<NSNumber*, id<MTLTexture>>* _meshTexByKey;
  NSMutableDictionary<NSNumber*, NSData*>* _meshTexPixelsByKey;
  NSMutableArray<NSNumber*>* _meshTexKeyOrder;
  NSUInteger _meshTexBytes;
  unsigned long long _meshTexHits;
  unsigned long long _meshTexMisses;
  // Reusable vertex-buffer pool for the per-frame sky/Direct batches.  On the
  // Simulator every -newBufferWithLength: is a synchronous XPC round-trip to
  // MTLSimDriver, and the sky/Direct buckets allocate a fresh buffer per batch
  // per frame.  Buffers are handed out from the free list and only returned
  // once the command buffer that consumed them has completed, so a recycled
  // buffer is never overwritten while the GPU may still be reading it.
  std::mutex _vertexPoolMutex;
  std::vector<id<MTLBuffer>> _vertexPool;
  std::vector<id<MTLBuffer>> _vertexPoolInFlight;
  struct MercFrameTransaction {
    std::vector<unsigned char> vertices, colors, actor_vertices, actor_colors;
    std::vector<unsigned int> indices, actor_indices;
    std::vector<OttselMetalTieDraw> draws, actor_draws;
    TieUniforms uniforms;
  };
  std::unique_ptr<MercFrameTransaction> _completedMercFrame;
  TieUniforms _mercFrameUniforms;
  std::vector<OttselMetalTieDraw> _mercDraws;
  std::mutex _mercMutex;
  std::vector<unsigned char> _pendingMercVertices;
  std::vector<unsigned int> _pendingMercIndices;
  std::vector<OttselMetalTieDraw> _pendingMercDraws;
  std::vector<unsigned char> _pendingMercColors;
  id<MTLBuffer> _mercActorVertices;
  id<MTLBuffer> _mercActorIndices;
  id<MTLBuffer> _mercActorColors;
  NSUInteger _mercActorIndexCount;
  std::vector<OttselMetalTieDraw> _mercActorDraws;
  std::vector<unsigned char> _pendingMercActorVertices;
  std::vector<unsigned int> _pendingMercActorIndices;
  std::vector<OttselMetalTieDraw> _pendingMercActorDraws;
  std::vector<unsigned char> _pendingMercActorColors;
}

- (BOOL)setupWithWindow:(SDL_Window*)win width:(int)w height:(int)h {
  SDL_MetalView view = SDL_Metal_CreateView(win);
  if (!view) {
    return NO;
  }
  self.layer = (__bridge CAMetalLayer*)SDL_Metal_GetLayer(view);
  if (!self.layer) {
    return NO;
  }
  // I3: publish the shell's controls to the accessibility layer; the container is transparent and takes no
  // touches, so the game's input path is unchanged.
  UIView* metal_view = (__bridge UIView*)view;
  self.accessibilityContainer = [[OttselAccessibilityView alloc] initWithFrame:metal_view.bounds];
  [metal_view addSubview:self.accessibilityContainer];
  self.renderScalePercent = 100;

  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (!device) {
    return NO;
  }
  self.device = device;
  self.layer.device = device;
  self.layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  // CAMetalLayer drawables are normally framebuffer-only.  The one-shot
  // diagnostic readback needs a copyable drawable; it is enabled only when
  // the explicit trigger is already present and never changes the product
  // presentation path otherwise.
  const std::string direct_readback_trigger = ottsel_ios_writable_dir() +
                                              "ottsel-dump-direct-fixture-metal";
  const std::string sprite_readback_trigger = ottsel_ios_writable_dir() +
                                              "ottsel-dump-native-sprite-metal";
  self.layer.framebufferOnly =
      access(direct_readback_trigger.c_str(), F_OK) != 0 &&
              access(sprite_readback_trigger.c_str(), F_OK) != 0;

  NSError* err = nil;
  id<MTLLibrary> lib = [device newLibraryWithSource:kShaderSource options:nil error:&err];
  if (!lib) {
    NSLog(@"ottsel metal: library error %@", err);
    return NO;
  }
  id<MTLFunction> vs = [lib newFunctionWithName:@"vs_main"];
  id<MTLFunction> fs = [lib newFunctionWithName:@"fs_main"];
  MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
  pd.vertexFunction = vs;
  pd.fragmentFunction = fs;
  pd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  // The normal shell pass binds the same Depth32Float attachment used by
  // TIE/TFRAG. Metal requires every render pipeline in that pass to declare
  // the matching depth format, even when this diagnostic shell triangle does
  // not enable a depth test.
  pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
  id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:pd error:&err];
  if (!pipeline) {
    NSLog(@"ottsel metal: pipeline error %@", err);
    return NO;
  }
  self.pipeline = pipeline;

  id<MTLLibrary> directLib = [device newLibraryWithSource:kDirectFixtureShaderSource
                                                    options:nil
                                                      error:&err];
  if (!directLib) {
    NSLog(@"ottsel metal: Direct fixture library error %@", err);
    return NO;
  }
  MTLVertexDescriptor* directLayout = [[MTLVertexDescriptor alloc] init];
  directLayout.attributes[0].format = MTLVertexFormatFloat2;
  directLayout.attributes[0].offset = 0;
  directLayout.attributes[0].bufferIndex = 0;
  directLayout.attributes[1].format = MTLVertexFormatFloat2;
  directLayout.attributes[1].offset = sizeof(float) * 2;
  directLayout.attributes[1].bufferIndex = 0;
  directLayout.attributes[2].format = MTLVertexFormatFloat4;
  directLayout.attributes[2].offset = sizeof(float) * 4;
  directLayout.attributes[2].bufferIndex = 0;
  directLayout.attributes[3].format = MTLVertexFormatFloat;
  directLayout.attributes[3].offset = offsetof(DirectFixtureVertex, q);
  directLayout.attributes[3].bufferIndex = 0;
  directLayout.attributes[4].format = MTLVertexFormatFloat;
  directLayout.attributes[4].offset = offsetof(DirectFixtureVertex, z);
  directLayout.attributes[4].bufferIndex = 0;
  directLayout.layouts[0].stride = sizeof(DirectFixtureVertex);
  directLayout.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
  MTLRenderPipelineDescriptor* directPd = [[MTLRenderPipelineDescriptor alloc] init];
  directPd.vertexFunction = [directLib newFunctionWithName:@"direct_vs"];
  directPd.fragmentFunction = [directLib newFunctionWithName:@"direct_fs"];
  directPd.vertexDescriptor = directLayout;
  directPd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  // Sprite3 and Direct share this pipeline and render into the same pass as
  // TIE/TFRAG. Declare the pass depth format explicitly; leaving it implicit
  // while binding a depth state/attachment produces invalid Simulator command
  // buffers during native composition.
  directPd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
  self.directPipeline = [device newRenderPipelineStateWithDescriptor:directPd error:&err];
  if (!self.directPipeline) {
    NSLog(@"ottsel metal: Direct fixture pipeline error %@", err);
    return NO;
  }
  MTLRenderPipelineDescriptor* directBlendPd = [directPd copy];
  MTLRenderPipelineColorAttachmentDescriptor* directBlendColor =
      directBlendPd.colorAttachments[0];
  directBlendColor.blendingEnabled = YES;
  directBlendColor.rgbBlendOperation = MTLBlendOperationAdd;
  directBlendColor.alphaBlendOperation = MTLBlendOperationAdd;
  directBlendColor.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
  directBlendColor.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  directBlendColor.sourceAlphaBlendFactor = MTLBlendFactorOne;
  directBlendColor.destinationAlphaBlendFactor = MTLBlendFactorZero;
  self.directBlendPipeline =
      [device newRenderPipelineStateWithDescriptor:directBlendPd error:&err];
  if (!self.directBlendPipeline) {
    NSLog(@"ottsel metal: Direct blended pipeline error %@", err);
    return NO;
  }
  // G2.2: the additive branch of the desktop's alpha table
  // (DirectRenderer: S/Z/S/D -> SRC_ALPHA, ONE, ADD with alpha ONE/ZERO).
  MTLRenderPipelineDescriptor* directAdditivePd = [directPd copy];
  MTLRenderPipelineColorAttachmentDescriptor* directAdditiveColor =
      directAdditivePd.colorAttachments[0];
  directAdditiveColor.blendingEnabled = YES;
  directAdditiveColor.rgbBlendOperation = MTLBlendOperationAdd;
  directAdditiveColor.alphaBlendOperation = MTLBlendOperationAdd;
  directAdditiveColor.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
  directAdditiveColor.destinationRGBBlendFactor = MTLBlendFactorOne;
  directAdditiveColor.sourceAlphaBlendFactor = MTLBlendFactorOne;
  directAdditiveColor.destinationAlphaBlendFactor = MTLBlendFactorZero;
  self.directAdditivePipeline =
      [device newRenderPipelineStateWithDescriptor:directAdditivePd error:&err];
  if (!self.directAdditivePipeline) {
    NSLog(@"ottsel metal: Direct additive pipeline error %@", err);
    return NO;
  }
  _skyIsolation=std::make_shared<SkyIsolationProbe>();
  _skyIsolation->device=device;
  _skyIsolation->plain=[directPd copy];_skyIsolation->blend=[directBlendPd copy];
  _skyIsolation->source=kDirectFixtureShaderSource;
  _skyIsolation->directory=ottsel_ios_writable_dir();
  MTLRenderPipelineDescriptor* spritePd = [directPd copy];
  spritePd.vertexFunction = [directLib newFunctionWithName:@"sprite_vs"];
  self.spritePipeline = [device newRenderPipelineStateWithDescriptor:spritePd error:&err];
  MTLRenderPipelineDescriptor* spriteBlendPd = [directBlendPd copy];
  spriteBlendPd.vertexFunction = spritePd.vertexFunction;
  self.spriteBlendPipeline = [device newRenderPipelineStateWithDescriptor:spriteBlendPd error:&err];
  if (!self.spritePipeline || !self.spriteBlendPipeline) {
    NSLog(@"ottsel metal: Sprite homogeneous pipeline error %@", err);
    return NO;
  }
  // Diagnostic-only pipeline: identical descriptor and blend factors to
  // directBlendPipeline, but a constant opaque magenta fragment. Isolates the
  // sky's composed fragment colour/alpha from its geometry and encoder path.
  MTLRenderPipelineDescriptor* skyDebugFillPd = [directBlendPd copy];
  skyDebugFillPd.fragmentFunction =
      [directLib newFunctionWithName:@"direct_fs_debug_fill"];
  self.skyDebugFillPipeline =
      [device newRenderPipelineStateWithDescriptor:skyDebugFillPd error:&err];
  if (!self.skyDebugFillPipeline) {
    NSLog(@"ottsel metal: sky debug-fill pipeline error %@", err);
    return NO;
  }
  MTLRenderPipelineDescriptor* skyDebugTexPd = [directBlendPd copy];
  skyDebugTexPd.fragmentFunction =
      [directLib newFunctionWithName:@"direct_fs_debug_tex"];
  self.skyDebugTexPipeline =
      [device newRenderPipelineStateWithDescriptor:skyDebugTexPd error:&err];
  if (!self.skyDebugTexPipeline) {
    NSLog(@"ottsel metal: sky debug-tex pipeline error %@", err);
    return NO;
  }
  // Diagnostic-only no-depth variant for separating depth attachment/pipeline
  // validation from the generated Direct color/texture submission.
  MTLRenderPipelineDescriptor* directNoDepthPd = [directPd copy];
  directNoDepthPd.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
  self.directNoDepthPipeline =
      [device newRenderPipelineStateWithDescriptor:directNoDepthPd error:&err];
  if (!self.directNoDepthPipeline) {
    NSLog(@"ottsel metal: Direct no-depth pipeline error %@", err);
    return NO;
  }
  MTLRenderPipelineDescriptor* directColorOnlyPd = [directNoDepthPd copy];
  directColorOnlyPd.fragmentFunction = [directLib newFunctionWithName:@"direct_fs_solid"];
  self.directColorOnlyPipeline =
      [device newRenderPipelineStateWithDescriptor:directColorOnlyPd error:&err];
  if (!self.directColorOnlyPipeline) {
    NSLog(@"ottsel metal: Direct color-only pipeline error %@", err);
    return NO;
  }
  MTLSamplerDescriptor* directSamplerDesc = [[MTLSamplerDescriptor alloc] init];
  directSamplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
  directSamplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
  directSamplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
  directSamplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
  self.directSampler = [device newSamplerStateWithDescriptor:directSamplerDesc];

  id<MTLLibrary> tieLib = [device newLibraryWithSource:kTieShaderSource options:nil error:&err];
  if (!tieLib) {
    NSLog(@"ottsel metal: TIE library error %@", err);
    return NO;
  }
  MTLVertexDescriptor* tieLayout = [[MTLVertexDescriptor alloc] init];
  tieLayout.attributes[0].format = MTLVertexFormatFloat3;
  tieLayout.attributes[0].offset = 0;
  tieLayout.attributes[0].bufferIndex = 0;
  tieLayout.attributes[1].format = MTLVertexFormatFloat2;
  tieLayout.attributes[1].offset = 16;
  tieLayout.attributes[1].bufferIndex = 0;
  tieLayout.attributes[2].format = MTLVertexFormatUShort;
  tieLayout.attributes[2].offset = 28;
  tieLayout.attributes[2].bufferIndex = 0;
  // tfrag3::PreloadedVertex stores the MercVertex shade in its rgba bytes at
  // offset 12. TFRAG/TIE ignore them and index the level color table instead.
  tieLayout.attributes[3].format = MTLVertexFormatUChar4;
  tieLayout.attributes[3].offset = 12;
  tieLayout.attributes[3].bufferIndex = 0;
  // Synthesized MERC vertices carry homogeneous W in the unused normal word.
  // TFRAG/TIE retain their normal bytes; only the MERC projection reads this.
  tieLayout.attributes[4].format = MTLVertexFormatFloat;
  tieLayout.attributes[4].offset = 24;
  tieLayout.attributes[4].bufferIndex = 0;
  tieLayout.layouts[0].stride = 32;  // tfrag3::PreloadedVertex
  tieLayout.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
  MTLRenderPipelineDescriptor* tiePd = [[MTLRenderPipelineDescriptor alloc] init];
  tiePd.vertexFunction = [tieLib newFunctionWithName:@"tie_vs"];
  tiePd.fragmentFunction = [tieLib newFunctionWithName:@"tie_fs"];
  tiePd.vertexDescriptor = tieLayout;
  tiePd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  tiePd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
  self.tiePipeline = [device newRenderPipelineStateWithDescriptor:tiePd error:&err];
  if (!self.tiePipeline) {
    NSLog(@"ottsel metal: TIE pipeline error %@", err);
    return NO;
  }
  MTLRenderPipelineDescriptor* tieBlendPd = [tiePd copy];
  MTLRenderPipelineColorAttachmentDescriptor* tieBlendColor = tieBlendPd.colorAttachments[0];
  tieBlendColor.blendingEnabled = YES;
  tieBlendColor.rgbBlendOperation = MTLBlendOperationAdd;
  tieBlendColor.alphaBlendOperation = MTLBlendOperationAdd;
  tieBlendColor.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
  tieBlendColor.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  tieBlendColor.sourceAlphaBlendFactor = MTLBlendFactorOne;
  tieBlendColor.destinationAlphaBlendFactor = MTLBlendFactorZero;
  self.tieBlendPipeline = [device newRenderPipelineStateWithDescriptor:tieBlendPd error:&err];
  if (!self.tieBlendPipeline) {
    NSLog(@"ottsel metal: TIE blend pipeline error %@", err);
    return NO;
  }
  MTLDepthStencilDescriptor* depthDesc = [[MTLDepthStencilDescriptor alloc] init];
  // tie_vs remaps PC/OpenGL depth into Metal's [0,1] range. The upstream GS
  // contract clears to zero and keeps the nearer remapped depth with GEQUAL.
  depthDesc.depthCompareFunction = kOttselMobileDepthGreaterEqual
                                       ? MTLCompareFunctionGreaterEqual
                                       : MTLCompareFunctionLessEqual;
  depthDesc.depthWriteEnabled = YES;
  self.tieDepthState = [device newDepthStencilStateWithDescriptor:depthDesc];
  depthDesc.depthWriteEnabled = NO;
  self.tieNoWriteDepthState = [device newDepthStencilStateWithDescriptor:depthDesc];
  NSMutableArray* tieDepthStates = [NSMutableArray arrayWithCapacity:4];
  NSMutableArray* tieNoWriteDepthStates = [NSMutableArray arrayWithCapacity:4];
  const MTLCompareFunction depthFunctions[] = {
      MTLCompareFunctionNever, MTLCompareFunctionAlways, MTLCompareFunctionGreaterEqual,
      MTLCompareFunctionGreater};
  for (NSUInteger i = 0; i < 4; ++i) {
    depthDesc.depthCompareFunction = depthFunctions[i];
    depthDesc.depthWriteEnabled = YES;
    [tieDepthStates addObject:[device newDepthStencilStateWithDescriptor:depthDesc]];
    depthDesc.depthWriteEnabled = NO;
    [tieNoWriteDepthStates addObject:[device newDepthStencilStateWithDescriptor:depthDesc]];
  }
  self.tieDepthStates = tieDepthStates;
  self.tieNoWriteDepthStates = tieNoWriteDepthStates;
  depthDesc.depthWriteEnabled = YES;
  self.directDepthState = self.tieDepthState;
  // Sprite3's maintained Jak 1 GS prefix uses the same GEQUAL convention and
  // leaves the scene depth buffer untouched.
  depthDesc.depthCompareFunction = MTLCompareFunctionGreaterEqual;
  depthDesc.depthWriteEnabled = ottsel::sprite3_depth_write_enabled();
  self.spriteDepthState = [device newDepthStencilStateWithDescriptor:depthDesc];
  depthDesc.depthCompareFunction = MTLCompareFunctionAlways;
  depthDesc.depthWriteEnabled = NO;
  self.overlayDepthState = [device newDepthStencilStateWithDescriptor:depthDesc];
  self.tieTextures = [NSMutableArray array];
  NSMutableArray* samplers = [NSMutableArray arrayWithCapacity:4];
  for (NSUInteger clamp_t = 0; clamp_t < 2; ++clamp_t) {
    for (NSUInteger clamp_s = 0; clamp_s < 2; ++clamp_s) {
      MTLSamplerDescriptor* samplerDesc = [[MTLSamplerDescriptor alloc] init];
      samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
      samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
      samplerDesc.sAddressMode =
          clamp_s ? MTLSamplerAddressModeClampToEdge : MTLSamplerAddressModeRepeat;
      samplerDesc.tAddressMode =
          clamp_t ? MTLSamplerAddressModeClampToEdge : MTLSamplerAddressModeRepeat;
      [samplers addObject:[device newSamplerStateWithDescriptor:samplerDesc]];
    }
  }
  self.tieSamplers = samplers;
  self.queue = [device newCommandQueue];
  if (!self.queue) {
    return NO;
  }

  MTLTextureDescriptor* td = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:(NSUInteger)w
                                  height:(NSUInteger)h
                               mipmapped:NO];
  td.usage = MTLTextureUsageShaderRead;
  self.logTex = [device newTextureWithDescriptor:td];
  if (!self.logTex) {
    return NO;
  }
  MTLTextureDescriptor* fixtureDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:NO];
  fixtureDesc.usage = MTLTextureUsageShaderRead;
  self.tfragFixtureTexture = [device newTextureWithDescriptor:fixtureDesc];
  if (!self.tfragFixtureTexture) {
    return NO;
  }
  const unsigned int fixturePixels[4] = {0xffffffffu, 0xffffffffu, 0xffffffffu, 0xffffffffu};
  [self.tfragFixtureTexture replaceRegion:MTLRegionMake2D(0, 0, 2, 2)
                              mipmapLevel:0
                                withBytes:fixturePixels
                              bytesPerRow:2 * sizeof(unsigned int)];
  return YES;
}

- (void)presentRGBA:(const unsigned char*)rgba width:(int)w height:(int)h {
  // MTLSimDriver serializes this byte range over XPC. Reject malformed
  // callers before replaceRegion can turn a bad signed dimension into an
  // unbounded memmove (the 2026-08-21 presentRGBA crash).
  if (!ottsel_present_rgba_frame_valid(rgba, w, h, self.directFixtureActive)) {
    NSLog(@"ottsel metal: rejected invalid RGBA frame ptr=%p size=%dx%d", rgba, w, h);
    return;
  }
  const std::string readback_state_trigger = ottsel_ios_writable_dir() +
                                             "ottsel-dump-native-sprite-metal";
  if (access(readback_state_trigger.c_str(), F_OK) == 0) {
    bool pending_sprite = false;
    {
      std::lock_guard<std::mutex> lock(_spriteUploadMutex);
      pending_sprite = !_pendingSpriteUploads.empty();
    }
    const std::string state_path = ottsel_ios_writable_dir() +
                                   "ottsel-native-sprite-present-state";
    if (FILE* state = fopen(state_path.c_str(), "wb")) {
      fprintf(state, "spriteActive=%d pendingSprite=%d\n", self.spriteActive ? 1 : 0,
              pending_sprite ? 1 : 0);
      fclose(state);
    }
  }
  // Direct texture pages arrive in bursts from the GOAL boot thread. Drain a
  // small bounded batch on the presentation thread so the Simulator Metal
  // host is not overwhelmed by hundreds of synchronous texture allocations.
  [self drainDirectTextureUploads];
  [self drainTieTextureUploads];
  [self drainSceneFrame];
  [self drainMercUploads];
  [self drainSpriteUploads];
  // Keep the CAMetalLayer drawableSize in sync with the actual layer bounds
  // (the simulator's windowed presentation reports the pre-layout 480x320
  // value at creation; SDL also syncs it on layout, this covers late resizes).
  CGSize layer_bounds = self.layer.bounds.size;
  CGFloat layer_scale = self.layer.contentsScale;
  if (layer_bounds.width > 0 && layer_bounds.height > 0) {
    // I3 VIDEO: the render scale multiplies the drawable, so a smaller drawable is what the game and every
    // native draw render into; the layer scales it back up to the view.  At 100 this is the native size.
    const CGFloat render_scale = (CGFloat)self.renderScalePercent / 100.0;
    CGSize want = CGSizeMake(layer_bounds.width * layer_scale * render_scale,
                             layer_bounds.height * layer_scale * render_scale);
    if (!CGSizeEqualToSize(self.layer.drawableSize, want)) {
      self.layer.drawableSize = want;
    }
  }
  // Present-path probe: log the first few presents (drawable size + first
  // pixels) so a black screen can be traced to the layer vs the content.
  static int ottsel_present_logged = 0;
  if (ottsel_present_logged++ < 8 && !self.directFixtureActive) {
    CGSize ds = self.layer.drawableSize;
    NSLog(@"ottsel metal presentRGBA %dx%d layer-drawable=%.0fx%.0f w=%d h=%d pipeline=%d",
          (int)self.layer.bounds.size.width, (int)self.layer.bounds.size.height, ds.width, ds.height,
          w, h, self.pipeline != nil);
    if (w >= 4 && h >= 1) {
      NSLog(@"ottsel metal px0-15: %02x%02x%02x %02x%02x%02x %02x%02x%02x %02x%02x%02x "
            "%02x%02x%02x %02x%02x%02x %02x%02x%02x %02x%02x%02x",
            rgba[0], rgba[1], rgba[2], rgba[3], rgba[4], rgba[5], rgba[6], rgba[7], rgba[8],
            rgba[9], rgba[10], rgba[11], rgba[12], rgba[13], rgba[14], rgba[15], rgba[16],
            rgba[17], rgba[18], rgba[19], rgba[20], rgba[21], rgba[22], rgba[23]);
    }
  }
  // Ottsel L3 (2026-09-22): decide once, before spending the upload, whether the CPU
  // base surface is still needed this frame.  The rule is the maintained policy
  // (mobile_scene_policy.h): once the live TFRAG and TIE meshes are both ready the base
  // draw is skipped anyway and the render pass already clears to the same neutral
  // colour, so uploading a flat 16 MB surface here costs a synchronous XPC round trip
  // for nothing.  The same value gates the base draw below, so the upload and the draw
  // can never disagree.
  bool cpu_base_wanted = true;
  {
    std::vector<SceneFrameReference> base_scene_frame;
    {
      std::lock_guard<std::mutex> lock(_tieUploadMutex);
      base_scene_frame = _activeSceneFrame;
    }
    const auto base_mesh_ready = [&](bool tfrag) {
      return std::any_of(base_scene_frame.begin(), base_scene_frame.end(),
                         [&](const SceneFrameReference& ref) {
        const auto mesh = _sceneMeshes.find(ref.key);
        return ref.key.second == tfrag && mesh != _sceneMeshes.end() &&
               mesh->second.vertices && mesh->second.indices && mesh->second.colors &&
               mesh->second.index_count;
      });
    };
    const bool base_tfrag_ready = base_mesh_ready(true);
    const bool base_tie_ready = base_mesh_ready(false);
    cpu_base_wanted =
        !self.directFixtureIsolated &&
        (ottsel_mobile_cpu_frame_should_draw(base_tfrag_ready, base_tie_ready,
                                             self.sceneNoCpuFrameProbe) ||
         // F1/G2.6: with no user pack the shell status screen (the DATA line plus the log
         // tail carrying the OTTSEL F1 list) is the only thing worth showing, even though
         // the level meshes are "ready" - they render unresident textures while the intro
         // waits for its streamed animation.
         !ottsel_ios_has_user_data());
    // Ottsel L3 (2026-09-22): the L0 cadence windows separate on raster-draws (every slow window reported
    // 0), so record this decision and its inputs on every change plus one line in ninety to test whether
    // the 16 MB CPU base upload is what makes those windows slow.  Opt-in: without OTTSEL_TRACE_BASE=1 no
    // code path or output changes.
    if (const char* base_trace = getenv("OTTSEL_TRACE_BASE");
        base_trace && base_trace[0] == '1') {
      extern int ottsel_metal_gfx_has_live_scene();
      static int last_wanted = -1;
      static unsigned long long presents = 0;
      ++presents;
      if (last_wanted != (int)cpu_base_wanted || (presents % 90ull) == 0) {
        last_wanted = (int)cpu_base_wanted;
        lg::info("OTTSEL BASEUPLOAD: n={} wanted={} tfrag-mesh={} tie-mesh={} live-scene={} meshes={} "
                 "frame-refs={}",
                 presents, cpu_base_wanted, base_tfrag_ready, base_tie_ready,
                 ottsel_metal_gfx_has_live_scene() != 0, _sceneMeshes.size(),
                 base_scene_frame.size());
      }
    }
  }
  // Recreate the upload texture if the surface size changed (rotation or
  // first frame after the caller adopts the drawable size).
  if (cpu_base_wanted && !self.directFixtureActive && (!self.logTex || self.logTex.width != (NSUInteger)w ||
      self.logTex.height != (NSUInteger)h)) {
    MTLTextureDescriptor* td = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                     width:(NSUInteger)w
                                    height:(NSUInteger)h
                                 mipmapped:NO];
    td.usage = MTLTextureUsageShaderRead;
    self.logTex = [self.device newTextureWithDescriptor:td];
    if (!self.logTex) {
      return;
    }
  }
  if (cpu_base_wanted && !self.directFixtureActive) {
    [self.logTex replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)w, (NSUInteger)h)
                   mipmapLevel:0
                   withBytes:rgba
                 bytesPerRow:(NSUInteger)w * 4];
  }

  // Diagnostic-only discriminator for the validated generated Direct fixture:
  // submit it without unrelated log/TFRAG/TIE/Sprite3 resources in the same
  // command buffer. The trigger is consumed once and never changes the normal
  // composition path.
  if (self.directFixtureActive && !self.directFixtureIsolated) {
    const std::string isolated_trigger = ottsel_ios_writable_dir() +
                                         "ottsel-trace-metal-direct-fixture-isolated";
    if (access(isolated_trigger.c_str(), F_OK) == 0) {
      unlink(isolated_trigger.c_str());
      self.directFixtureIsolated = YES;
      NSLog(@"ottsel metal: Direct fixture isolated submission enabled");
    }
  }
  if (self.directFixtureActive && !self.directFixtureNoDepth) {
    const std::string no_depth_trigger = ottsel_ios_writable_dir() +
                                         "ottsel-trace-metal-direct-fixture-no-depth";
    if (access(no_depth_trigger.c_str(), F_OK) == 0) {
      unlink(no_depth_trigger.c_str());
      self.directFixtureIsolated = YES;
      self.directFixtureNoDepth = YES;
      NSLog(@"ottsel metal: Direct fixture no-depth submission enabled");
    }
  }
  if (self.directFixtureActive && !self.directFixtureColorOnly) {
    const std::string color_only_trigger = ottsel_ios_writable_dir() +
                                           "ottsel-trace-metal-direct-fixture-color-only";
    if (access(color_only_trigger.c_str(), F_OK) == 0) {
      unlink(color_only_trigger.c_str());
      self.directFixtureIsolated = YES;
      self.directFixtureNoDepth = YES;
      self.directFixtureColorOnly = YES;
      NSLog(@"ottsel metal: Direct fixture color-only submission enabled");
    }
  }
  if (self.directFixtureActive && !self.directFixtureOffscreen) {
    const std::string offscreen_trigger = ottsel_ios_writable_dir() +
                                          "ottsel-trace-metal-direct-fixture-offscreen";
    if (access(offscreen_trigger.c_str(), F_OK) == 0) {
      unlink(offscreen_trigger.c_str());
      self.directFixtureIsolated = YES;
      self.directFixtureNoDepth = YES;
      self.directFixtureColorOnly = YES;
      self.directFixtureOffscreen = YES;
      NSLog(@"ottsel metal: Direct fixture offscreen submission enabled");
    }
  }
  if (!self.sceneNoDepthProbe) {
    const std::string scene_no_depth_trigger = ottsel_ios_writable_dir() +
                                               "ottsel-trace-metal-scene-no-depth";
    if (access(scene_no_depth_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_depth_trigger.c_str());
      self.sceneNoDepthProbe = YES;
      NSLog(@"ottsel metal: scene no-depth probe enabled");
    }
  }
  if (!self.sceneNoTieProbe) {
    const std::string scene_no_tie_trigger = ottsel_ios_writable_dir() +
                                              "ottsel-trace-metal-scene-no-tie";
    if (access(scene_no_tie_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_tie_trigger.c_str());
      self.sceneNoTieProbe = YES;
      NSLog(@"ottsel metal: scene no-TIE probe enabled");
    }
  }
  if (!self.sceneSkyOpaqueProbe) {
    const std::string sky_opaque_trigger = ottsel_ios_writable_dir() +
                                            "ottsel-trace-metal-sky-opaque";
    if (access(sky_opaque_trigger.c_str(), F_OK) == 0) {
      unlink(sky_opaque_trigger.c_str());
      self.sceneSkyOpaqueProbe = YES;
      NSLog(@"ottsel metal: sky opaque probe enabled");
    }
  }
  if (!self.sceneSkyDebugFillProbe) {
    const std::string sky_debug_fill_trigger = ottsel_ios_writable_dir() +
                                                "ottsel-trace-metal-sky-debug-fill";
    if (access(sky_debug_fill_trigger.c_str(), F_OK) == 0) {
      unlink(sky_debug_fill_trigger.c_str());
      self.sceneSkyDebugFillProbe = YES;
      NSLog(@"ottsel metal: sky debug-fill probe enabled");
    }
  }
  if (!self.sceneSkyDebugTexProbe) {
    const std::string sky_debug_tex_trigger = ottsel_ios_writable_dir() +
                                               "ottsel-trace-metal-sky-debug-tex";
    if (access(sky_debug_tex_trigger.c_str(), F_OK) == 0) {
      unlink(sky_debug_tex_trigger.c_str());
      self.sceneSkyDebugTexProbe = YES;
      NSLog(@"ottsel metal: sky debug-tex probe enabled");
    }
  }
  if (!self.sceneSkyDebugFillAllProbe) {
    const std::string sky_debug_all_trigger = ottsel_ios_writable_dir() +
                                              "ottsel-trace-metal-sky-debug-all";
    if (access(sky_debug_all_trigger.c_str(), F_OK) == 0) {
      unlink(sky_debug_all_trigger.c_str());
      self.sceneSkyDebugFillAllProbe = YES;
      NSLog(@"ottsel metal: sky debug-all probe enabled");
    }
  }
  if (!self.sceneSkyEndProbe) {
    const std::string sky_end_trigger = ottsel_ios_writable_dir() +
                                        "ottsel-trace-metal-sky-end";
    if (access(sky_end_trigger.c_str(), F_OK) == 0) {
      unlink(sky_end_trigger.c_str());
      self.sceneSkyEndProbe = YES;
      NSLog(@"ottsel metal: sky end-of-pass probe enabled");
    }
  }
  if (!self.sceneSkyInsideProbe) {
    const std::string sky_inside_trigger = ottsel_ios_writable_dir() +
                                           "ottsel-trace-metal-sky-inside";
    if (access(sky_inside_trigger.c_str(), F_OK) == 0) {
      unlink(sky_inside_trigger.c_str());
      self.sceneSkyInsideProbe = YES;
      NSLog(@"ottsel metal: sky inside-loop probe enabled");
    }
  }
  if (!self.sceneNoMercProbe) {
    const std::string scene_no_merc_trigger = ottsel_ios_writable_dir() +
                                               "ottsel-trace-metal-scene-no-merc";
    if (access(scene_no_merc_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_merc_trigger.c_str());
      self.sceneNoMercProbe = YES;
      NSLog(@"ottsel metal: scene no-MERC probe enabled");
    }
  }
  if (!self.sceneTfragFixture) {
    const std::string fixture_trigger = ottsel_ios_writable_dir() +
                                        "ottsel-trace-metal-tfrag-fixture";
    if (access(fixture_trigger.c_str(), F_OK) == 0) {
      unlink(fixture_trigger.c_str());
      self.sceneTfragFixture = YES;
      NSLog(@"ottsel metal: TFRAG pipeline fixture enabled");
    }
  }
  if (!self.sceneNoTfragProbe) {
    const std::string scene_no_tfrag_trigger = ottsel_ios_writable_dir() +
                                                "ottsel-trace-metal-scene-no-tfrag";
    if (access(scene_no_tfrag_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_tfrag_trigger.c_str());
      self.sceneNoTfragProbe = YES;
      NSLog(@"ottsel metal: scene no-TFRAG probe enabled");
    }
  }
  if (!self.sceneNoCpuFrameProbe) {
    const std::string scene_no_cpu_frame_trigger = ottsel_ios_writable_dir() +
                                                   "ottsel-trace-metal-scene-no-cpu-frame";
    if (access(scene_no_cpu_frame_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_cpu_frame_trigger.c_str());
      self.sceneNoCpuFrameProbe = YES;
      NSLog(@"ottsel metal: scene no-CPU-frame probe enabled");
    }
  }
  // G2.2 Sky blend gate (live, not latched): presence of the trigger file enables
  // the register-driven additive selection, so one run can capture both states
  // at one camera and one time-of-day.
  {
    const std::string sky_skip_draw_trigger = ottsel_ios_writable_dir() +
                                              "ottsel-trace-sky-skip-draw";
    self.skySkipDraw = access(sky_skip_draw_trigger.c_str(), F_OK) == 0;
  }
  {
    const std::string sky_draw_legacy_trigger = ottsel_ios_writable_dir() +
                                                "ottsel-trace-sky-draw-legacy";
    self.skyDrawLegacy = access(sky_draw_legacy_trigger.c_str(), F_OK) == 0;
  }
  if (!self.sceneNoOverlayProbe) {
    const std::string scene_no_overlay_trigger = ottsel_ios_writable_dir() +
                                                 "ottsel-trace-metal-scene-no-overlay";
    if (access(scene_no_overlay_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_overlay_trigger.c_str());
      self.sceneNoOverlayProbe = YES;
      NSLog(@"ottsel metal: scene world-only overlay probe enabled");
    }
  }
  if (!self.sceneNoSkyProbe) {
    const std::string scene_no_sky_trigger = ottsel_ios_writable_dir() +
                                             "ottsel-trace-metal-scene-no-sky";
    if (access(scene_no_sky_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_sky_trigger.c_str());
      self.sceneNoSkyProbe = YES;
      NSLog(@"ottsel metal: scene no-SKY probe enabled");
    }
  }
  if (!self.sceneNoSpriteProbe) {
    const std::string scene_no_sprite_trigger = ottsel_ios_writable_dir() +
                                                "ottsel-trace-metal-scene-no-sprite";
    if (access(scene_no_sprite_trigger.c_str(), F_OK) == 0) {
      unlink(scene_no_sprite_trigger.c_str());
      self.sceneNoSpriteProbe = YES;
      NSLog(@"ottsel metal: scene no-SPRITE probe enabled");
    }
  }
  if (!self.sceneTieReferenceProjectionProbe) {
    const std::string scene_tie_reference_projection_trigger =
        ottsel_ios_writable_dir() + "ottsel-trace-metal-scene-tie-reference-projection";
    if (access(scene_tie_reference_projection_trigger.c_str(), F_OK) == 0) {
      unlink(scene_tie_reference_projection_trigger.c_str());
      self.sceneTieReferenceProjectionProbe = YES;
      NSLog(@"ottsel metal: scene TIE reference-projection probe enabled");
    }
  }
  if (!self.sceneFirstBatchProbe) {
    const std::string scene_first_batch_trigger = ottsel_ios_writable_dir() +
                                                  "ottsel-trace-metal-scene-first-batch";
    if (access(scene_first_batch_trigger.c_str(), F_OK) == 0) {
      unlink(scene_first_batch_trigger.c_str());
      self.sceneFirstBatchProbe = YES;
      NSLog(@"ottsel metal: scene first-batch probe enabled");
    }
  }
  if (!self.sceneDrawLimit) {
    const std::string scene_draw_limit_trigger =
        ottsel_ios_writable_dir() + "ottsel-trace-metal-scene-draw-limit";
    if (access(scene_draw_limit_trigger.c_str(), F_OK) == 0) {
      unsigned long limit = 0;
      if (FILE* file = fopen(scene_draw_limit_trigger.c_str(), "r")) {
        fscanf(file, "%lu", &limit);
        fclose(file);
      }
      unlink(scene_draw_limit_trigger.c_str());
      self.sceneDrawLimit = (NSUInteger)std::min<unsigned long>(limit ? limit : 1, 1024);
      NSLog(@"ottsel metal: scene draw-limit probe enabled limit=%lu",
            (unsigned long)self.sceneDrawLimit);
    }
  }
  if (_skyIsolation && _skyIsolation->activeRequest()) self.layer.framebufferOnly=NO;
  id<CAMetalDrawable> drawable = [self.layer nextDrawable];
  if (!drawable) {
    return;
  }
  if (!self.directFixtureNoDepth &&
      (!self.tieDepth || self.tieDepth.width != drawable.texture.width ||
       self.tieDepth.height != drawable.texture.height)) {
    MTLTextureDescriptor* depthDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                     width:drawable.texture.width
                                    height:drawable.texture.height
                                 mipmapped:NO];
    depthDesc.usage = MTLTextureUsageRenderTarget;
    depthDesc.storageMode = MTLStorageModePrivate;
    self.tieDepth = [self.device newTextureWithDescriptor:depthDesc];
  }
  if (self.directFixtureOffscreen &&
      (!self.directOffscreenTarget || self.directOffscreenTarget.width != drawable.texture.width ||
       self.directOffscreenTarget.height != drawable.texture.height)) {
    MTLTextureDescriptor* targetDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:drawable.texture.width
                                    height:drawable.texture.height
                                 mipmapped:NO];
    targetDesc.usage = MTLTextureUsageRenderTarget;
    targetDesc.storageMode = MTLStorageModePrivate;
    self.directOffscreenTarget = [self.device newTextureWithDescriptor:targetDesc];
    if (!self.directOffscreenTarget) {
      NSLog(@"ottsel metal: Direct offscreen target allocation failed");
      return;
    }
  }
  MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
  pass.colorAttachments[0].texture = self.directFixtureOffscreen ? self.directOffscreenTarget
                                                                   : drawable.texture;
  pass.colorAttachments[0].loadAction = MTLLoadActionClear;
  pass.colorAttachments[0].storeAction = MTLStoreActionStore;
  pass.colorAttachments[0].clearColor = MTLClearColorMake(0.03, 0.04, 0.07, 1.0);
  if (!self.directFixtureNoDepth) {
    pass.depthAttachment.texture = self.tieDepth;
    pass.depthAttachment.loadAction = MTLLoadActionClear;
    pass.depthAttachment.storeAction = MTLStoreActionDontCare;
    pass.depthAttachment.clearDepth = kOttselMobileDepthClear;
  }

  id<MTLCommandBuffer> cb = [self.queue commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
  if (!cb || !enc) {
    return;
  }
  RenderEncoderEndGuard encoder_guard(enc);
  // One captured Sky population serves every position in this command buffer.
  // Later producer uploads belong to the next frame, including probe redraws.
  // G2.2 Sky-store probe (observability only, bounded to eight lines): the live
  // Sky decode reports `submitted=2` on every title frame while this snapshot
  // reads empty, so read the store's own ledger for the window that just ended,
  // its sizes immediately before consumption, and the snapshot it yields.  A
  // non-zero empty-replace is a publish that retired a non-empty ready
  // population with an empty one - the drop named without further guessing.
  const OttselMobileDirectFrame<NativeSpriteBatch>::DebugLedger sky_store_ledger =
      _skyFrameStore.debug_take();
  std::size_t sky_pre_building = 0, sky_pre_completed = 0, sky_pre_active = 0;
  _skyFrameStore.debug_sizes(sky_pre_building, sky_pre_completed, sky_pre_active);
  const auto sky_snapshot = _skyFrameStore.snapshot();
  const auto& sky_batches = sky_snapshot.batches;
  if (_skyStoreProbeLogs < 8 &&
      (sky_store_ledger.begins || sky_store_ledger.appends || sky_store_ledger.publishes ||
       sky_store_ledger.rollbacks || sky_pre_completed || !sky_batches.empty())) {
    ++_skyStoreProbeLogs;
    NSLog(@"ottsel metal: SKYSTORE probe=%lu begin=%lu append=%lu publish=%lu rollback=%lu "
          @"empty-publish=%lu empty-replace=%lu published-batches=%lu pre(building=%zu "
          @"completed=%zu active=%zu) snapshot=%zu",
          (unsigned long)_skyStoreProbeLogs, sky_store_ledger.begins, sky_store_ledger.appends,
          sky_store_ledger.publishes, sky_store_ledger.rollbacks,
          sky_store_ledger.empty_publishes, sky_store_ledger.empty_replacements,
          sky_store_ledger.published_batches, sky_pre_building, sky_pre_completed,
          sky_pre_active, sky_batches.size());
  }
  std::vector<id<MTLBuffer>> frame_vertex_buffers = sky_snapshot.retired;
  // BOT66 pass-position bisect.  Three constant-magenta quarter-screen
  // triangles are drawn at three positions in this single encoder:
  //   Q1 top-left  : immediately after the encoder opens, before any draw
  //   Q2 top-right : after the CPU-frame fullscreen draw, before the sky loop
  //   Q3 bot-left  : at the end of the pass (the existing ENCPROBE)
  // The sky region's pixels are exactly the pass clear colour, so the question
  // is not "which pipeline" but "from which position in this encoder does a
  // draw survive to the presented frame".  Observability only.
  if (self.sceneSkyDebugFillAllProbe && self.skyDebugFillPipeline) {
    static id<MTLBuffer> quarter_buffers[2] = {nil, nil};
    static const DirectFixtureVertex quarter_verts[2][3] = {
        {// Q1 top-left: x -1..0, y 0..1
         {{-1.f, 0.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
         {{0.f, 0.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
         {{-1.f, 1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}}},
        {// Q2 top-right: x 0..1, y 0..1
         {{0.f, 0.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
         {{1.f, 0.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
         {{1.f, 1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}}},
    };
    for (int q = 0; q < 2; ++q) {
      if (!quarter_buffers[q]) {
        quarter_buffers[q] = [self.device newBufferWithBytes:quarter_verts[q]
                                                      length:sizeof(quarter_verts[q])
                                                     options:MTLResourceStorageModeShared];
        NSLog(@"ottsel metal: QPROBE q=%d buffer=%p", q + 1, quarter_buffers[q]);
      }
    }
    if (quarter_buffers[0]) {
      [enc setRenderPipelineState:self.skyDebugFillPipeline];
      [enc setDepthStencilState:self.overlayDepthState];
      [enc setVertexBuffer:quarter_buffers[0] offset:0 atIndex:0];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    }
    // BOT66 Q4: draw the FIRST TEXTURED SKY BATCH's own pooled vertex buffer,
    // unmodified, through the very same magenta pipeline at the very same
    // top-of-pass position where Q1 paints.  Q1 painted from its own buffer;
    // if Q4's quad does not, the sky's pooled buffer contents are what the GPU
    // sees wrong, not the pass position, the pipeline, or the encoder state.
    {
      const auto& early_sky = sky_batches;
      unsigned int q4_done = 0;
      for (const auto& sky : early_sky) {
        if (q4_done) {
          break;
        }
        if (sky.texture.width < 32 || sky.texture.height < 32 ||
            sky.vertex_count < 3 || !sky.vertices) {
          continue;
        }
        q4_done = 1;
        const OttselMetalSpriteVertex* sv =
            (const OttselMetalSpriteVertex*)sky.vertices.contents;
        NSLog(@"ottsel metal: QPROBE q=4 batches=%lu n=%lu buf=%p "
              @"v0=(%.4f,%.4f) v1=(%.4f,%.4f) v2=(%.4f,%.4f) alpha=%.3f",
              (unsigned long)early_sky.size(), (unsigned long)sky.vertex_count,
              sky.vertices.contents, sv[0].pos[0], sv[0].pos[1], sv[1].pos[0],
              sv[1].pos[1], sv[2].pos[0], sv[2].pos[1], sv[0].color[3]);
        [enc setRenderPipelineState:self.skyDebugFillPipeline];
        [enc setDepthStencilState:self.overlayDepthState];
        [enc setVertexBuffer:sky.vertices offset:0 atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
                vertexCount:sky.vertex_count];
      }
    }
  }
  // Camera updates arrive on the game thread. Snapshot the complete block
  // before encoding so no draw can observe a partially copied matrix/fog set.
  std::vector<SceneFrameReference> scene_frame;
  { std::lock_guard<std::mutex> lock(_tieUploadMutex); scene_frame = _activeSceneFrame; }
  TieUniforms draw_uniforms;
  {
    std::lock_guard<std::mutex> lock(_tieUniformMutex);
    draw_uniforms = _tieUniforms;
  }
  if (cpu_base_wanted) {
    [enc setRenderPipelineState:self.pipeline];
    [enc setFragmentTexture:self.logTex atIndex:0];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  }
  // BOT66 pass-position bisect Q2: same magenta pipeline, but encoded after the
  // CPU-frame fullscreen draw and still before the sky loop.  Q1 (before that
  // draw) vs Q2 isolates "the pass start is dropped" from "the CPU-frame draw
  // poisons the encoder".  Observability only.
  if (self.sceneSkyDebugFillAllProbe && self.skyDebugFillPipeline) {
    static id<MTLBuffer> q2_buffer = nil;
    if (!q2_buffer) {
      const DirectFixtureVertex q2[3] = {
          {{0.f, 0.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
          {{1.f, 0.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
          {{1.f, 1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
      };
      q2_buffer = [self.device newBufferWithBytes:q2
                                           length:sizeof(q2)
                                          options:MTLResourceStorageModeShared];
      NSLog(@"ottsel metal: QPROBE q=2 buffer=%p", q2_buffer);
    }
    if (q2_buffer) {
      [enc setRenderPipelineState:self.skyDebugFillPipeline];
      [enc setDepthStencilState:self.overlayDepthState];
      [enc setVertexBuffer:q2_buffer offset:0 atIndex:0];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    }
  }
  const auto draw_mesh = ^(id<MTLBuffer> vertices, id<MTLBuffer> indices, id<MTLBuffer> colors,
                           NSUInteger index_count,
                           const std::vector<OttselMetalTieDraw>& draws,
                           bool tfrag_mesh,
                           bool merc_mesh, const TieUniforms& source_uniforms) {
    if (!vertices || !indices || !colors || !index_count) {
      return;
    }
    [enc setVertexBuffer:vertices offset:0 atIndex:0];
    TieUniforms mesh_uniforms = source_uniforms;
    mesh_uniforms.projection_mode =
        (self.sceneTfragFixture && tfrag_mesh)
            ? 2u
            : (ottsel_mobile_projection_uses_raw_perspective(
                   merc_mesh ? OttselMobileMeshProjection::MercPerspective
                             : OttselMobileMeshProjection::PcCamera)
                   ? 1u
                   : 0u);
    // Normal TIE uses the same TFRAG3 shader and derived pc_camera in the
    // desktop renderer. Only the separate wind-TIE path consumes raw camera
    // matrices; this native mesh contains normal static draws.
    // Keep the production path on the native derived-pc-camera equation. The
    // reference-projection switch is a one-shot falsification probe only; it
    // must not silently become the shipping camera policy.
    // The reference equation has opposite signs for TIE and TFRAG. Keep the
    // one-shot probe scoped to TIE; applying its TIE sign to the background
    // TFRAG path makes the diagnostic frame itself invalid.
    mesh_uniforms.camera_sign = self.sceneTieReferenceProjectionProbe && !tfrag_mesh ? -1.f : 1.f;
    if (merc_mesh) {
      // Match merc2.vert's z subtraction followed by the common Metal remap.
      // The former mode-1 default masked discarded homogeneous skin W; it
      // made the actor visible at an incorrect depth. Preserve the explicit
      // diagnostic override, but use the oracle contract in normal rendering.
      mesh_uniforms.merc_z_mode = 0;
      const std::string z_mode_path = ottsel_ios_writable_dir() + "ottsel-merc-zmode";
      if (FILE* z_mode_file = fopen(z_mode_path.c_str(), "r")) {
        int z_mode_value = 0;
        if (fscanf(z_mode_file, "%d", &z_mode_value) == 1) {
          mesh_uniforms.merc_z_mode = (uint32_t)z_mode_value;
        }
        fclose(z_mode_file);
      }
    }
    [enc setVertexBytes:&mesh_uniforms length:sizeof(mesh_uniforms) atIndex:1];
    [enc setVertexBuffer:colors offset:0 atIndex:2];
    static bool merc_draw_probe_armed = false;
    static bool merc_draw_probe_logged = false;
    if (merc_mesh && !merc_draw_probe_armed) {
      const std::string trigger = ottsel_ios_writable_dir() + "ottsel-trace-metal-merc-draw";
      if (access(trigger.c_str(), F_OK) == 0) {
        unlink(trigger.c_str());
        merc_draw_probe_armed = true;
      } else {
        merc_draw_probe_armed = true;
      }
    }
    if (merc_mesh && merc_draw_probe_armed && !merc_draw_probe_logged && !draws.empty() &&
        [vertices contents] && [indices contents]) {
      const auto* index_data = (const unsigned int*)[indices contents];
      const unsigned int first_index = index_data[draws.front().index_offset];
      const auto* vertex_data = (const float*)[vertices contents] + first_index * 8;
      NSLog(@"ottsel metal: MERC draw-probe projection=%u sign=%.1f indices=%lu "
            "first=(%.3f,%.3f,%.3f) pc-row0=(%.6f,%.6f,%.6f,%.6f) "
            "raw-row0=(%.6f,%.6f,%.6f,%.6f) trans=(%.3f,%.3f,%.3f)",
            mesh_uniforms.projection_mode, mesh_uniforms.camera_sign,
            (unsigned long)index_count, vertex_data[0], vertex_data[1], vertex_data[2],
            mesh_uniforms.pc_camera[0], mesh_uniforms.pc_camera[1], mesh_uniforms.pc_camera[2],
            mesh_uniforms.pc_camera[3], mesh_uniforms.merc_perspective[0],
            mesh_uniforms.merc_perspective[1], mesh_uniforms.merc_perspective[2],
            mesh_uniforms.merc_perspective[3],
            mesh_uniforms.camera_trans[0], mesh_uniforms.camera_trans[1],
            mesh_uniforms.camera_trans[2]);
      const std::string output = ottsel_ios_writable_dir() + "ottsel-metal-merc-draw.log";
      if (FILE* file = fopen(output.c_str(), "w")) {
        fprintf(file, "projection=%u sign=%.1f indices=%lu first=(%.3f,%.3f,%.3f) "
                     "pc-row0=(%.6f,%.6f,%.6f,%.6f) raw-row0=(%.6f,%.6f,%.6f,%.6f) "
                     "trans=(%.3f,%.3f,%.3f)\n",
                mesh_uniforms.projection_mode, mesh_uniforms.camera_sign,
                (unsigned long)index_count, vertex_data[0], vertex_data[1], vertex_data[2],
                mesh_uniforms.pc_camera[0], mesh_uniforms.pc_camera[1], mesh_uniforms.pc_camera[2],
                mesh_uniforms.pc_camera[3], mesh_uniforms.merc_perspective[0],
                mesh_uniforms.merc_perspective[1], mesh_uniforms.merc_perspective[2],
                mesh_uniforms.merc_perspective[3], mesh_uniforms.camera_trans[0],
                mesh_uniforms.camera_trans[1], mesh_uniforms.camera_trans[2]);
        for (size_t draw_index = 0; draw_index < draws.size(); ++draw_index) {
          const auto& draw = draws[draw_index];
          fprintf(file, "draw[%lu] offset=%u count=%u owner=%u\n",
                  (unsigned long)draw_index, draw.index_offset, draw.index_count, draw.owner_tag);
        }
        fclose(file);
      }
      merc_draw_probe_logged = true;
    }
    static bool submit_boundary_armed = false;
    static bool submit_boundary_logged = false;
    if (tfrag_mesh && !submit_boundary_armed) {
      const std::string trigger = ottsel_ios_writable_dir() +
                                  "ottsel-trace-metal-tfrag-submit-boundary";
      if (access(trigger.c_str(), F_OK) == 0) {
        unlink(trigger.c_str());
        submit_boundary_armed = true;
        NSLog(@"ottsel metal: TFRAG submit-boundary probe enabled");
      } else {
        submit_boundary_armed = true;
      }
    }
    static unsigned int tfrag_texture_ledger_logs = 0;
    static unsigned int tfrag_texture_skip_count = 0;
    static bool batch_trace_armed = false;
    static bool batch_trace_enabled = false;
    if (!tfrag_mesh && !merc_mesh && !batch_trace_armed) {
      const std::string trigger = ottsel_ios_writable_dir() +
                                  "ottsel-trace-metal-scene-final-batches";
      if (access(trigger.c_str(), F_OK) == 0) {
        unlink(trigger.c_str());
        batch_trace_enabled = true;
      }
      batch_trace_armed = true;
    }
    for (size_t draw_index = 0; draw_index < draws.size(); ++draw_index) {
      if (self.sceneFirstBatchProbe && draw_index > 0) {
        break;
      }
      if (self.sceneDrawLimit && draw_index >= self.sceneDrawLimit) {
        break;
      }
      const auto& draw = draws[draw_index];
      if (batch_trace_enabled && !tfrag_mesh && !merc_mesh && draw_index >= 115) {
        NSLog(@"ottsel metal: TIE final-batch index=%lu texture=%d indices=%u mode=0x%08x",
              (unsigned long)draw_index, draw.texture_index, draw.index_count, draw.mode);
      }
      if (draw.texture_index < 0 || (NSUInteger)draw.texture_index >= self.tieTextures.count) {
        if (tfrag_mesh && tfrag_texture_ledger_logs < 12) {
          ++tfrag_texture_ledger_logs;
          ++tfrag_texture_skip_count;
          NSLog(@"ottsel metal: TFRAG texture skip index=%d count=%lu reason=out-of-range",
                draw.texture_index, (unsigned long)self.tieTextures.count);
        }
        continue;
      }
      id texture = self.tieTextures[(NSUInteger)draw.texture_index];
      if (![texture conformsToProtocol:@protocol(MTLTexture)]) {
        if (tfrag_mesh && tfrag_texture_ledger_logs < 12) {
          ++tfrag_texture_ledger_logs;
          ++tfrag_texture_skip_count;
          NSLog(@"ottsel metal: TFRAG texture skip index=%d count=%lu reason=not-uploaded",
                draw.texture_index, (unsigned long)self.tieTextures.count);
        }
        continue;
      }
      const bool clamp_s = draw.mode & (1u << 5);
      const bool clamp_t = draw.mode & (1u << 23);
      const NSUInteger sampler_idx = (clamp_t ? 2 : 0) + (clamp_s ? 1 : 0);
      const bool alpha_test = draw.mode & (1u << 18);
      const unsigned int alpha_test_kind = (draw.mode >> 16) & 3;
      const unsigned int alpha_fail = (draw.mode >> 21) & 3u;
      const bool depth_test_enabled = (draw.mode & (1u << 19)) != 0;
      const bool alpha_blend_enabled = ottsel_mobile_alpha_blend_enabled(
          (draw.mode & (1u << 20)) != 0, (draw.mode >> 24) & 7u);
      const bool source_depth_write_enabled = (draw.mode & 1u) != 0;
      // G2.2 blend ledger, TIE site (observability only, one line after 200
      // draws following a level selection): the 3-bit AlphaBlend preset and the
      // blend-enable bit this population actually requests, so an additive
      // pipeline state is landed only where the ledger proves it is asked for.
      if (_blendLedgerArmed) {
        const unsigned int tie_reg_preset_index = (unsigned int)((draw.mode >> 24) & 7u);
        ++_blendLedgerTiePreset[tie_reg_preset_index];
        ++_blendLedgerTieEnable[(draw.mode & (1u << 20)) ? 1 : 0];
        ++_blendLedgerTieBlend[alpha_blend_enabled ? 1 : 0];
        if (!_blendLedgerTieLogged && ++_blendLedgerTieDraws >= 200) {
          _blendLedgerTieLogged = YES;
          NSLog(@"ottsel metal: TIEREG draws=%lu enable=%lu/%lu blend=%lu/%lu "
                @"preset=%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu",
                _blendLedgerTieDraws, _blendLedgerTieEnable[0], _blendLedgerTieEnable[1],
                _blendLedgerTieBlend[0], _blendLedgerTieBlend[1], _blendLedgerTiePreset[0],
                _blendLedgerTiePreset[1], _blendLedgerTiePreset[2], _blendLedgerTiePreset[3],
                _blendLedgerTiePreset[4], _blendLedgerTiePreset[5], _blendLedgerTiePreset[6],
                _blendLedgerTiePreset[7]);
        }
      }
      const float alpha_min = ottsel_mobile_alpha_min(
          alpha_test_kind, alpha_test, alpha_fail, source_depth_write_enabled,
          (draw.mode >> 8) & 0xff);
      // OpenGL's NEVER + FB_ONLY setup keeps color but disables depth writes.
      const bool depth_write_enabled =
          depth_test_enabled && source_depth_write_enabled &&
          !(alpha_test && alpha_test_kind == 0 && alpha_fail == 1);
      const NSUInteger depth_compare_index =
          (draw.mode & (1u << 19)) ? ((draw.mode >> 1) & 3u) : 1u;
      [enc setRenderPipelineState:alpha_blend_enabled ? self.tieBlendPipeline
                                                       : self.tiePipeline];
      [enc setDepthStencilState:self.sceneNoDepthProbe
                                  ? self.overlayDepthState
                                  : (depth_write_enabled ? self.tieDepthStates[depth_compare_index]
                                                         : self.tieNoWriteDepthStates[depth_compare_index])];
      const bool fog_enable = (draw.mode & (1u << 29)) != 0;
      const bool decal = (draw.mode & (1u << 28)) == 0;
      TieMaterial material{alpha_min, 10.f, fog_enable ? 1u : 0u, decal ? 1u : 0u,
                           merc_mesh ? 1u : 0u};
      if (tfrag_mesh && draws.size() >= 80 && submit_boundary_armed && !submit_boundary_logged &&
          [vertices contents] && [indices contents]) {
        const auto* index_data = (const unsigned int*)[indices contents];
        const unsigned int first_index = index_data[draw.index_offset];
        const auto* vertex_data = (const float*)[vertices contents] + first_index * 8;
        NSLog(@"ottsel metal: TFRAG submit-boundary draw=%lu index-offset=%u first-index=%u "
              "vertex=(%.3f,%.3f,%.3f) uv=(%.3f,%.3f) mode=0x%08x projection=%u sign=%.1f "
              "camera-row0=(%.6f,%.6f,%.6f,%.6f) camera-row1=(%.6f,%.6f,%.6f,%.6f) "
              "camera-row2=(%.6f,%.6f,%.6f,%.6f) camera-row3=(%.6f,%.6f,%.6f,%.6f) "
              "trans=(%.3f,%.3f,%.3f)",
              (unsigned long)draw_index, draw.index_offset, first_index, vertex_data[0],
              vertex_data[1], vertex_data[2], vertex_data[4], vertex_data[5], draw.mode,
              mesh_uniforms.projection_mode, mesh_uniforms.camera_sign, mesh_uniforms.pc_camera[0],
              mesh_uniforms.pc_camera[1], mesh_uniforms.pc_camera[2], mesh_uniforms.pc_camera[3],
              mesh_uniforms.pc_camera[4], mesh_uniforms.pc_camera[5], mesh_uniforms.pc_camera[6],
              mesh_uniforms.pc_camera[7], mesh_uniforms.pc_camera[8], mesh_uniforms.pc_camera[9],
              mesh_uniforms.pc_camera[10], mesh_uniforms.pc_camera[11], mesh_uniforms.pc_camera[12],
              mesh_uniforms.pc_camera[13], mesh_uniforms.pc_camera[14], mesh_uniforms.pc_camera[15],
              mesh_uniforms.camera_trans[0], mesh_uniforms.camera_trans[1],
              mesh_uniforms.camera_trans[2]);
        submit_boundary_logged = true;
      }
      [enc setFragmentTexture:texture atIndex:0];
      [enc setFragmentSamplerState:self.tieSamplers[sampler_idx] atIndex:0];
      [enc setVertexBytes:&material length:sizeof(material) atIndex:3];
      [enc setFragmentBytes:&material length:sizeof(material) atIndex:1];
      [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                      indexCount:draw.index_count
                       indexType:MTLIndexTypeUInt32
                      indexBuffer:indices
               indexBufferOffset:draw.index_offset * sizeof(unsigned int)];
      // OpenGL's FB_ONLY alpha-fail path draws passing fragments with depth
      // writes, then draws failing fragments again without depth writes.
      if (alpha_test && alpha_test_kind == 2 && alpha_fail == 1 &&
          source_depth_write_enabled) {
        [enc setDepthStencilState:self.sceneNoDepthProbe
                                       ? self.overlayDepthState
                                       : self.tieNoWriteDepthStates[depth_compare_index]];
        TieMaterial alpha_fail_material{-10.f, alpha_min, fog_enable ? 1u : 0u,
                                         decal ? 1u : 0u, merc_mesh ? 1u : 0u};
        [enc setVertexBytes:&alpha_fail_material length:sizeof(alpha_fail_material) atIndex:3];
        [enc setFragmentBytes:&alpha_fail_material length:sizeof(alpha_fail_material) atIndex:1];
        [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:draw.index_count
                         indexType:MTLIndexTypeUInt32
                        indexBuffer:indices
                 indexBufferOffset:draw.index_offset * sizeof(unsigned int)];
      }
    }
  };
  // Pre-world Direct/GIF batches (currently Sky) must be encoded before the
  // opaque world queues. They are separate from Sprite3 so HUD ordering and
  // the existing diagnostic overlay remain unchanged.
  if (!sky_batches.empty() && !self.directFixtureIsolated && !self.sceneNoSkyProbe) {
    unsigned int sky_state[6] = {0, 0, 0, 1, 0, 0};
    // G2.2 blend ledger: the decode outcome and the pipeline this pass selected.
    unsigned long sky_blend_key_counts[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    unsigned long sky_blend_additive_drawn = 0;
    // G2.2 Sky ST/Q ledger (observability only, three batches): the stored ST and
    // Q each vertex carries plus the post-divide uv the fragment shader computes,
    // so a quad that tiles its texture many times can be told apart from a
    // texture whose data is wrong.
    if (_blendLedgerArmed) {
      static unsigned int sky_uv_logs = 0;
      for (const auto& sky : sky_batches) {
        if (sky_uv_logs >= 3) {
          break;
        }
        if (sky.texture.width < 32 || sky.vertex_count < 3) {
          continue;
        }
        ++sky_uv_logs;
        const OttselMetalSpriteVertex* sv =
            (const OttselMetalSpriteVertex*)sky.vertices.contents;
        const float q0 = sv[0].q != 0.f ? sv[0].q : 1.f;
        const float q1 = sv[1].q != 0.f ? sv[1].q : 1.f;
        const float q2 = sv[2].q != 0.f ? sv[2].q : 1.f;
        NSLog(@"ottsel metal: SKYUV i=%u tex=%lux%lu n=%lu q=(%.6g,%.6g,%.6g) "
              @"st0=(%.6f,%.6f) st1=(%.6f,%.6f) st2=(%.6f,%.6f) "
              @"uv0=(%.4f,%.4f) uv1=(%.4f,%.4f) uv2=(%.4f,%.4f)",
              sky_uv_logs - 1, (unsigned long)sky.texture.width,
              (unsigned long)sky.texture.height, (unsigned long)sky.vertex_count, q0, q1, q2,
              sv[0].uv[0], sv[0].uv[1], sv[1].uv[0], sv[1].uv[1], sv[2].uv[0], sv[2].uv[1],
              sv[0].uv[0] / q0, sv[0].uv[1] / q0, sv[1].uv[0] / q1, sv[1].uv[1] / q1,
              sv[2].uv[0] / q2, sv[2].uv[1] / q2);
      }
    }
    // BOT66: the sky block is the first consumer of this pass, so no encoder
    // state can have leaked into it from a later bucket.  Pin viewport and
    // scissor to the whole drawable anyway: "the later reference triangle
    // paints and the sky loop does not" can only be explained by drawable
    // state that is not full-surface, and both are free to re-assert.
    {
      MTLViewport full_viewport = {0.0, 0.0, (double)drawable.texture.width,
                                   (double)drawable.texture.height, 0.0, 1.0};
      [enc setViewport:full_viewport];
      MTLScissorRect full_scissor = {0, 0, drawable.texture.width,
                                     drawable.texture.height};
      [enc setScissorRect:full_scissor];
    }
    // BOT66: per-frame, bounded record of what the sky loop actually encoded.
    // The existing SKYBOUND / SKY ALPHA logs are once-per-process statics, so a
    // frame that encodes 40 batches and a frame that encodes 2 look identical
    // in the log.  Tie the encoded population to the presented frame.
    {
      static unsigned int sky_loop_frame_logs = 0;
      if (sky_loop_frame_logs < 24) {
        ++sky_loop_frame_logs;
        unsigned long textured = 0, small = 0;
        for (const auto& sky : sky_batches) {
          if (sky.texture.width >= 32 && sky.texture.height >= 32) {
            ++textured;
          } else {
            ++small;
          }
        }
        NSLog(@"ottsel metal: SKYLOOP frame=%u batches=%lu textured=%lu small=%lu "
              @"size=%lux%lu",
              sky_loop_frame_logs, (unsigned long)sky_batches.size(), textured, small,
              (unsigned long)drawable.texture.width,
              (unsigned long)drawable.texture.height);
      }
    }
    // G2.2 blend ledger, Sky site (observability only): the raw GS ALPHA register
    // the decoder attached to *every* batch of this population, reported as one
    // line per distinct register mix (up to eight) so an additive (0x48) or copy
    // register cannot hide behind a four-batch sample.  That register, not the
    // vertex alpha, decides whether this site needs an additive (Cs*As + Cd)
    // state.  Only the mix is logged, so a steady population costs one line.
    if (_blendLedgerArmed && !sky_batches.empty()) {
      unsigned long long reg[4] = {0, 0, 0, 0};
      unsigned long count[4] = {0, 0, 0, 0};
      unsigned long other = 0, textured = 0, untextured = 0;
      // G2.2: the vertex colour range of the population, so a vivid additive
      // result can be attributed to the batch colours rather than the equation.
      float cmin[3] = {1.f, 1.f, 1.f};
      float cmax[3] = {0.f, 0.f, 0.f};
      // First textured batch's three vertex colours, verbatim.
      float sample_rgb[3][3] = {{0.f, 0.f, 0.f}, {0.f, 0.f, 0.f}, {0.f, 0.f, 0.f}};
      bool sample_taken = false;
      int used = 0;
      for (const auto& sky : sky_batches) {
        const OttselMetalSpriteVertex* sky_cv =
            (const OttselMetalSpriteVertex*)sky.vertices.contents;
        if (!sample_taken && sky.texture.width >= 32 && sky.vertex_count >= 3) {
          sample_taken = true;
          for (int v = 0; v < 3; ++v) {
            for (int ch = 0; ch < 3; ++ch) {
              sample_rgb[v][ch] = sky_cv[v].color[ch];
            }
          }
        }
        for (NSUInteger v = 0; v < sky.vertex_count; ++v) {
          for (int ch = 0; ch < 3; ++ch) {
            cmin[ch] = std::min(cmin[ch], sky_cv[v].color[ch]);
            cmax[ch] = std::max(cmax[ch], sky_cv[v].color[ch]);
          }
        }
        if (sky.texture.width >= 32 && sky.texture.height >= 32) {
          ++textured;
        } else {
          ++untextured;
        }
        const unsigned long long r = sky.diagnostic_alpha & 0xffull;
        int slot = -1;
        for (int i = 0; i < used; ++i) {
          if (reg[i] == r) {
            slot = i;
            break;
          }
        }
        if (slot < 0 && used < 4) {
          reg[used] = r;
          count[used] = 0;
          slot = used;
          ++used;
        }
        if (slot < 0) {
          ++other;
        } else {
          ++count[slot];
        }
      }
      bool sky_mix_changed = (_skyMixLines == 0) || _skyMixOther != other ||
                             _skyMixTextured != textured || _skyMixUntextured != untextured;
      for (int i = 0; i < 4 && !sky_mix_changed; ++i) {
        if (_skyMixReg[i] != reg[i] || _skyMixCount[i] != count[i]) {
          sky_mix_changed = true;
        }
      }
      if (sky_mix_changed && _skyMixLines < 8) {
        ++_skyMixLines;
        for (int i = 0; i < 4; ++i) {
          _skyMixReg[i] = reg[i];
          _skyMixCount[i] = count[i];
        }
        _skyMixOther = other;
        _skyMixTextured = textured;
        _skyMixUntextured = untextured;
        NSLog(@"ottsel metal: SKYREG-MIX arm=%lu n=%lu textured=%lu untextured=%lu "
              @"r0=0x%llx:%lu r1=0x%llx:%lu r2=0x%llx:%lu r3=0x%llx:%lu other=%lu "
              @"cmin=(%.3f,%.3f,%.3f) cmax=(%.3f,%.3f,%.3f) "
              @"v0=(%.2f,%.2f,%.2f) v1=(%.2f,%.2f,%.2f) v2=(%.2f,%.2f,%.2f)",
              (unsigned long)_blendLedgerArms, (unsigned long)sky_batches.size(), textured,
              untextured, reg[0], count[0], reg[1], count[1], reg[2], count[2], reg[3],
              count[3], other, cmin[0], cmin[1], cmin[2], cmax[0], cmax[1], cmax[2],
              sample_rgb[0][0], sample_rgb[0][1], sample_rgb[0][2], sample_rgb[1][0],
              sample_rgb[1][1], sample_rgb[1][2], sample_rgb[2][0], sample_rgb[2][1],
              sample_rgb[2][2]);
      }
    }
    // BOT58 pass-position A/B: draw a known-good reference triangle with the
    // opaque debug-fill pipeline here, at the TOP of the pass and before the
    // sky loop.  It covers the opposite NDC half from the existing end-of-pass
    // reference triangle, so a pass-position effect reads as 98% magenta (both
    // paint) versus 49% (only the end-of-pass one paints).  Observability only.
    if (self.sceneSkyDebugFillAllProbe && self.skyDebugFillPipeline) {
      static id<MTLBuffer> sky_top_ref_buffer = nil;
      if (!sky_top_ref_buffer) {
        DirectFixtureVertex top_ref[3] = {
            {{1.f, -1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
            {{1.f, 1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
            {{-1.f, 1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
        };
        sky_top_ref_buffer = [self.device newBufferWithBytes:top_ref
                                                      length:sizeof(top_ref)
                                                     options:MTLResourceStorageModeShared];
        NSLog(@"ottsel metal: SKYTOPREF buffer=%p", sky_top_ref_buffer);
      }
      if (sky_top_ref_buffer) {
        [enc setRenderPipelineState:self.skyDebugFillPipeline];
        [enc setDepthStencilState:self.overlayDepthState];
        [enc setVertexBuffer:sky_top_ref_buffer offset:0 atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      }
    }
    // BOT58 diagnostic: how many textured batches have been re-drawn from a
    // fresh, non-pooled buffer this frame.  Reset per frame so every captured
    // frame carries the probe.
    unsigned int sky_vertex_copy_tried = 0;
    unsigned int sky_inside_done = 0;
    for (const auto& sky : sky_batches) {
      // Diagnostic scoping: the untextured 1x1 full-screen fans otherwise
      // dominate any opaque-fragment experiment and hide the textured
      // population, so restrict the debug pipelines to real textured sky.
      if ((self.sceneSkyDebugFillProbe && self.skyDebugFillPipeline) ||
          (self.sceneSkyDebugTexProbe && self.skyDebugTexPipeline)) {
        if (self.sceneSkyDebugFillAllProbe) {
          // Diagnostic: keep every batch.
        } else if (sky.texture.width < 32 || sky.texture.height < 32) {
          continue;
        }
      }
      sky_state[5] = sky.ta0;
      // BOT66 inside-loop isolation probe.  A private-buffer magenta triangle
      // drawn from this exact point in the loop, at the top of the screen where
      // no later world geometry can overdraw it.  Magenta here proves the loop
      // reaches pixels and points the defect at the batch buffers; no magenta
      // proves the loop's draw calls never produce fragments at all.
      if (self.sceneSkyInsideProbe && self.skyDebugFillPipeline && sky_inside_done < 1) {
        static id<MTLBuffer> sky_inside_buffer = nil;
        if (!sky_inside_buffer) {
          const DirectFixtureVertex inside[3] = {
              {{-0.9f, 0.05f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
              {{0.9f, 0.05f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
              {{0.0f, 0.95f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
          };
          sky_inside_buffer = [self.device newBufferWithBytes:inside
                                                       length:sizeof(inside)
                                                      options:MTLResourceStorageModeShared];
          NSLog(@"ottsel metal: INSIDEPROBE buffer=%p", sky_inside_buffer);
        }
        if (sky_inside_buffer) {
          sky_inside_done = 1;
          [enc setRenderPipelineState:self.skyDebugFillPipeline];
          [enc setDepthStencilState:self.overlayDepthState];
          [enc setVertexBuffer:sky_inside_buffer offset:0 atIndex:0];
          [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        }
      }
      // Diagnostic only: forcing replace blending separates "the sky geometry
      // never covers a pixel" from "the sky blends to nothing".
      //
      // G2.2: otherwise the batch's own GS ALPHA register picks the equation, as
      // upstream's DirectRenderer does.  Both capture paths reset the decoder's
      // draw state before walking a bucket, so a non-zero register here is one
      // the chain actually wrote: 0x48 (S/Z/S/D) is additive (Cs-0)*As + Cd,
      // which the source-over pipeline was drawing as a lerp, and 0x44 (S/D/S/D)
      // is the source-over the shell already drew.  Every other key - including a
      // bucket that wrote no register at all - keeps the previous behaviour, so
      // no path outside a proven additive population changes.
      const OttselMobileBlendKey sky_blend_key =
          ottsel_mobile_blend_key_from_alpha(sky.diagnostic_alpha);
      const bool sky_additive = sky_blend_key == OttselMobileBlendKey::Additive;
      // G2.2 attribution control: count the decode, then issue no draw at all.
      if (self.skySkipDraw) {
        continue;
      }
      if (sky.blended) {
        if (sky_blend_key == OttselMobileBlendKey::Additive) {
          ++sky_blend_key_counts[(int)OttselMobileBlendKey::Additive];
          if (sky_additive) ++sky_blend_additive_drawn;
        } else if (sky_blend_key == OttselMobileBlendKey::SourceOver) {
          ++sky_blend_key_counts[(int)OttselMobileBlendKey::SourceOver];
        } else if (sky_blend_key == OttselMobileBlendKey::Unspecified) {
          ++sky_blend_key_counts[(int)OttselMobileBlendKey::Unspecified];
        } else {
          ++sky_blend_key_counts[(int)OttselMobileBlendKey::Unsupported];
        }
      }
      [enc setRenderPipelineState:(self.sceneSkyOpaqueProbe || !sky.blended)
                                      ? self.directPipeline
                                      : (sky_additive ? self.directAdditivePipeline
                                                      : self.directBlendPipeline)];
      if (self.sceneSkyDebugFillProbe && self.skyDebugFillPipeline) {
        [enc setRenderPipelineState:self.skyDebugFillPipeline];
      }
      if (self.sceneSkyDebugTexProbe && self.skyDebugTexPipeline) {
        [enc setRenderPipelineState:self.skyDebugTexPipeline];
      }
      [enc setDepthStencilState:[self depthStateForDirectBatch:sky]];
      [enc setVertexBuffer:sky.vertices offset:0 atIndex:0];
      // BOT66: the magenta debug-fill fragment declares no texture/sampler/state,
      // so binding them is not required for it.  Skipping them under the probe
      // is an A/B on the only still-untested difference between the sky-loop
      // draws (which paint nothing) and the top-of-pass probe draws of the very
      // same pooled vertex buffers (which paint): the fragment binding set.
      const bool sky_fill_probe_draw =
          self.sceneSkyDebugFillProbe && self.skyDebugFillPipeline;
      if (!sky_fill_probe_draw) {
        [enc setFragmentTexture:sky.texture atIndex:0];
        [enc setFragmentSamplerState:self.directSampler atIndex:0];
        [enc setFragmentBytes:sky_state length:sizeof(sky_state) atIndex:1];
      }
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:sky.vertex_count];
      // BOT58 diagnostic: re-draw the first textured batch from a fresh,
      // non-pooled buffer holding a byte-identical copy of the very vertices
      // the pooled draw just used, through the opaque magenta debug-fill
      // pipeline.  Outcome matrix: copy paints and pooled draw does not ->
      // the pooled vertex buffer is the defect; neither paints -> the batch
      // geometry/encoder parameters are.  Observability only.
      if (self.sceneSkyDebugFillProbe && self.skyDebugFillPipeline &&
          sky_vertex_copy_tried == 0 && sky.vertex_count > 0 &&
          sky.texture.width >= 32 && sky.texture.height >= 32) {
        sky_vertex_copy_tried = 1;
        const NSUInteger copy_bytes =
            sky.vertex_count * sizeof(OttselMetalSpriteVertex);
        id<MTLBuffer> copy_buffer =
            [self.device newBufferWithBytes:sky.vertices.contents
                                     length:copy_bytes
                                    options:MTLResourceStorageModeShared];
        NSLog(@"ottsel metal: SKYCOPY n=%lu bytes=%lu src=%p dst=%p",
              (unsigned long)sky.vertex_count, (unsigned long)copy_bytes,
              sky.vertices.contents, copy_buffer.contents);
        if (copy_buffer) {
          [enc setRenderPipelineState:self.skyDebugFillPipeline];
          [enc setDepthStencilState:self.overlayDepthState];
          [enc setVertexBuffer:copy_buffer offset:0 atIndex:0];
          [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
                  vertexCount:sky.vertex_count];
          // BOT58 discriminator: the pooled draw and a fresh byte-identical copy
          // both fail, so the vertex positions the shader fetches are the last
          // suspect.  Draw one more time through the identical pipeline with the
          // first triangle's clip-space positions replaced by the known-good
          // ENCPROBE triangle.  Magenta now -> the submitted positions are the
          // defect; still silent -> this batch's draw is being dropped.
          if (sky.vertex_count >= 3) {
            const OttselMetalSpriteVertex* sky_src =
                (const OttselMetalSpriteVertex*)sky.vertices.contents;
            static unsigned int sky_vert_logs = 0;
            if (sky_vert_logs < 3) {
              ++sky_vert_logs;
              NSLog(@"ottsel metal: SKYVERT stride=%lu count=%lu "
                    @"v0=(%.4f,%.4f) v1=(%.4f,%.4f) v2=(%.4f,%.4f) "
                    @"alpha=(%.3f,%.3f,%.3f) tex=%lux%lu",
                    (unsigned long)sizeof(OttselMetalSpriteVertex),
                    (unsigned long)sky.vertex_count, sky_src[0].pos[0], sky_src[0].pos[1],
                    sky_src[1].pos[0], sky_src[1].pos[1], sky_src[2].pos[0],
                    sky_src[2].pos[1], sky_src[0].color[3], sky_src[1].color[3],
                    sky_src[2].color[3], (unsigned long)sky.texture.width,
                    (unsigned long)sky.texture.height);
            }
            static id<MTLBuffer> sky_ndc_buffer = nil;
            if (!sky_ndc_buffer) {
              OttselMetalSpriteVertex ndc[3] = {sky_src[0], sky_src[1], sky_src[2]};
              ndc[0].pos[0] = -1.0f;
              ndc[0].pos[1] = -1.0f;
              ndc[1].pos[0] = 1.0f;
              ndc[1].pos[1] = -1.0f;
              ndc[2].pos[0] = -1.0f;
              ndc[2].pos[1] = 1.0f;
              sky_ndc_buffer = [self.device newBufferWithBytes:ndc
                                                        length:sizeof(ndc)
                                                       options:MTLResourceStorageModeShared];
            }
            if (sky_ndc_buffer) {
              [enc setVertexBuffer:sky_ndc_buffer offset:0 atIndex:0];
              [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
            }
          }
        }
      }
    }
    // G2.2 Sky blend ledger (observability only, one line per distinct
    // selection, six lines at most): what the decoded GS ALPHA register
    // actually selected, so the A/B control and the production path are both
    // visible in the log next to the capture.
    if (_blendLedgerArmed) {
      // Keyed on the selection outcome alone: the population alternates between
      // passes (2 / 34 / 40 / 46 batches), so counting every variation would
      // spend the budget before anything changes.  The per-population register
      // mix is the SKYREG-MIX ledger's job.
      const bool sky_blend_changed =
          (_skyBlendLogLines == 0) || _skyBlendLogAdditive != sky_blend_additive_drawn;
      if (sky_blend_changed && _skyBlendLogLines < 6) {
        ++_skyBlendLogLines;
        _skyBlendLogAdditive = sky_blend_additive_drawn;
        for (int i = 0; i < 8; ++i) {
          _skyBlendLogKeys[i] = sky_blend_key_counts[i];
        }
        NSLog(@"ottsel metal: SKYBLEND additive-drawn=%lu unspec=%lu "
              @"source-over=%lu additive=%lu unsupported=%lu",
              sky_blend_additive_drawn,
              sky_blend_key_counts[(int)OttselMobileBlendKey::Unspecified],
              sky_blend_key_counts[(int)OttselMobileBlendKey::SourceOver],
              sky_blend_key_counts[(int)OttselMobileBlendKey::Additive],
              sky_blend_key_counts[(int)OttselMobileBlendKey::Unsupported]);
      }
    }
    // Diagnostic reference triangle: same encoder, pipeline and depth state as
    // the sky batches, but a locally-owned vertex buffer.  If this paints and
    // the sky batches do not, the defect is in the batch buffers, not the
    // pipeline or encoder.
    if (self.sceneSkyDebugFillAllProbe) {
      static id<MTLBuffer> sky_ref_buffer = nil;
      if (!sky_ref_buffer) {
        DirectFixtureVertex ref[3] = {
            {{-1.f, -1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
            {{1.f, -1.f}, {1.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
            {{-1.f, 1.f}, {0.f, 1.f}, {1.f, 1.f, 1.f, 1.f}},
        };
        sky_ref_buffer = [self.device newBufferWithBytes:ref
                                                  length:sizeof(ref)
                                                 options:MTLResourceStorageModeShared];
        NSLog(@"ottsel metal: SKYREF buffer=%p", sky_ref_buffer);
      }
      if (sky_ref_buffer) {
        [enc setRenderPipelineState:self.skyDebugFillPipeline];
        [enc setDepthStencilState:self.overlayDepthState];
        [enc setVertexBuffer:sky_ref_buffer offset:0 atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      }
    }
    static bool sky_batch_logged = false;
    if (!sky_batch_logged) {
      sky_batch_logged = true;
      NSLog(@"ottsel metal: native Sky batches=%lu encoded=pre-world/no-depth",
            (unsigned long)sky_batches.size());
      // Alpha distribution across every encoded sky batch: a batch whose
      // vertex alpha is 0 contributes nothing under srcBlend=source alpha.
      unsigned long alpha_zero = 0, alpha_pos = 0, cover_large = 0;
      float alpha_max = 0.f;
      for (const auto& sky : sky_batches) {
        const OttselMetalSpriteVertex* sv =
            (const OttselMetalSpriteVertex*)sky.vertices.contents;
        float a = sv[0].color[3];
        if (a <= 0.f) {
          ++alpha_zero;
        } else {
          ++alpha_pos;
        }
        alpha_max = std::max(alpha_max, a);
        float xspan = 0.f, yspan = 0.f;
        for (NSUInteger i = 0; i < sky.vertex_count; ++i) {
          xspan = std::max(xspan, fabsf(sv[i].pos[0]));
          yspan = std::max(yspan, fabsf(sv[i].pos[1]));
        }
        if (xspan >= 1.f && yspan >= 1.f) {
          ++cover_large;
        }
      }
      NSLog(@"ottsel metal: SKY ALPHA batches=%lu alpha0=%lu alpha+%lu amax=%.3f "
            "fullscreen-cover=%lu",
            (unsigned long)sky_batches.size(), alpha_zero, alpha_pos, alpha_max,
            cover_large);
    }
    // I1.1b diagnostic: per-batch NDC bounds on frames that actually carry a
    // textured sky batch.  A packed fan can be "submitted" and still miss the
    // drawable; this separates the untextured fill quad from the real sky.
    static unsigned long sky_bounds_frames = 0;
    bool sky_frame_textured = false;
    for (const auto& sky : sky_batches) {
      if (sky.texture.width >= 32 && sky.texture.height >= 32) {
        sky_frame_textured = true;
        break;
      }
    }
    if (sky_frame_textured && sky_bounds_frames < 3) {
      ++sky_bounds_frames;
      NSLog(@"ottsel metal: SKYBOUNDFRAME n=%lu",
            (unsigned long)sky_batches.size());
      unsigned long bi = 0;
      for (const auto& sky : sky_batches) {
        if (bi >= 44) {
          break;
        }
        const OttselMetalSpriteVertex* sv =
            (const OttselMetalSpriteVertex*)sky.vertices.contents;
        float mnx = 1e9f, mny = 1e9f, mxx = -1e9f, mxy = -1e9f;
        float amin = 1e9f;
        for (NSUInteger i = 0; i < sky.vertex_count; ++i) {
          mnx = std::min(mnx, sv[i].pos[0]);
          mny = std::min(mny, sv[i].pos[1]);
          mxx = std::max(mxx, sv[i].pos[0]);
          mxy = std::max(mxy, sv[i].pos[1]);
          amin = std::min(amin, sv[i].color[3]);
        }
        NSLog(@"ottsel metal: SKYBOUND i=%lu tex=%lux%lu n=%lu blend=%d a=%.3f "
              "ndc=(%.3f,%.3f)..(%.3f,%.3f)",
              bi++, (unsigned long)sky.texture.width, (unsigned long)sky.texture.height,
              (unsigned long)sky.vertex_count, sky.blended ? 1 : 0, amin, mnx, mny, mxx, mxy);
        // BOT66: min/max bounds cannot distinguish a real triangle from a
        // degenerate (collinear) one, and a degenerate fan rasterizes nothing
        // while still being "submitted".  Dump the three positions verbatim.
        if (sky.vertex_count >= 3 && bi <= 4) {
          NSLog(@"ottsel metal: SKYTRI i=%lu v0=(%.4f,%.4f) v1=(%.4f,%.4f) "
                @"v2=(%.4f,%.4f) area2=%.6f blend=%d tex=%lux%lu",
                bi - 1, sv[0].pos[0], sv[0].pos[1], sv[1].pos[0], sv[1].pos[1],
                sv[2].pos[0], sv[2].pos[1],
                (sv[1].pos[0] - sv[0].pos[0]) * (sv[2].pos[1] - sv[0].pos[1]) -
                    (sv[2].pos[0] - sv[0].pos[0]) * (sv[1].pos[1] - sv[0].pos[1]),
                sky.blended ? 1 : 0, (unsigned long)sky.texture.width,
                (unsigned long)sky.texture.height);
        }
      }
    }
    // I1.1b diagnostic: confirm the vertex words that actually reach the GPU
    // match the NDC the decoder computed.  Bounded; observability only.
    static unsigned int sky_vertex_dumps = 0;
    if (ottsel_mobile_log_within_budget(sky_vertex_dumps, 6)) {
      ++sky_vertex_dumps;
      const OttselMetalSpriteVertex* vp =
          (const OttselMetalSpriteVertex*)sky_batches.front().vertices.contents;
      const NativeSpriteBatch& b = sky_batches.front();
      NSLog(@"ottsel metal: SKY ENCODE batches=%lu n=%lu blend=%d "
            "v0=(%.3f,%.3f) v1=(%.3f,%.3f) v2=(%.3f,%.3f) col=(%.2f,%.2f,%.2f,%.2f) "
            "tex=%lux%lu uv0=(%.4f,%.4f) uv1=(%.4f,%.4f) uv2=(%.4f,%.4f)",
            (unsigned long)sky_batches.size(), (unsigned long)b.vertex_count,
            b.blended ? 1 : 0, vp[0].pos[0], vp[0].pos[1], vp[1].pos[0], vp[1].pos[1],
            vp[2].pos[0], vp[2].pos[1], vp[0].color[0], vp[0].color[1], vp[0].color[2],
            vp[0].color[3], (unsigned long)b.texture.width, (unsigned long)b.texture.height,
            vp[0].uv[0], vp[0].uv[1], vp[1].uv[0], vp[1].uv[1], vp[2].uv[0], vp[2].uv[1]);
    }
  }
  // Per-frame sky composition, throttled to 1 Hz so a screenshot can be
  // correlated with the exact set of batches that were encoded for that
  // frame.  Without this, "the sky is black" and "the captured frame happened
  // to have no sky batches" are indistinguishable.  Observability only.
  if (!sky_batches.empty()) {
    static double last_sky_frame_log = 0.0;
    const NSTimeInterval sky_now = CACurrentMediaTime();
    if (sky_now - last_sky_frame_log >= 1.0) {
      last_sky_frame_log = sky_now;
      unsigned long tex1 = 0, tex32 = 0, tex64 = 0, tex_other = 0;
      unsigned long alpha_zero = 0, alpha_half = 0;
      float amax = 0.f;
      // BOT58 discriminator: the magenta and debug-tex probes bypass the
      // vertex colour entirely, so 'probe paints, product is black' is exactly
      // what a zero vertex RGB would produce.  Record it before blaming the
      // pass slot or the texture.
      float cmax[3] = {0.f, 0.f, 0.f};
      // Per-size colour: the max above hides the case that actually matters.
      // The 1x1 full-screen fans are the ones that cover the whole sky, and
      // the SKY ENCODE log shows their vertex colour as (0.00,0.50,0.50,0.50).
      float rgb_by_size[3][3] = {{0.f, 0.f, 0.f}, {0.f, 0.f, 0.f}, {0.f, 0.f, 0.f}};
      for (const auto& sky : sky_batches) {
        const NSUInteger tw = sky.texture.width;
        const int cls = tw == 1 ? 0 : (tw == 32 ? 1 : (tw == 64 ? 2 : 0));
        if (tw == 1) {
          ++tex1;
        } else if (tw == 32) {
          ++tex32;
        } else if (tw == 64) {
          ++tex64;
        } else {
          ++tex_other;
        }
        const OttselMetalSpriteVertex* sv =
            (const OttselMetalSpriteVertex*)sky.vertices.contents;
        float batch_amax = 0.f;
        for (NSUInteger i = 0; i < sky.vertex_count; ++i) {
          batch_amax = std::max(batch_amax, sv[i].color[3]);
          for (int c = 0; c < 3; ++c) {
            cmax[c] = std::max(cmax[c], sv[i].color[c]);
            rgb_by_size[cls][c] = std::max(rgb_by_size[cls][c], sv[i].color[c]);
          }
        }
        if (batch_amax <= 0.f) {
          ++alpha_zero;
        } else if (batch_amax >= 0.5f) {
          ++alpha_half;
        }
        amax = std::max(amax, batch_amax);
      }
      NSLog(@"ottsel metal: SKYFRAME batches=%lu tex1=%lu tex32=%lu tex64=%lu "
            "texother=%lu alpha0=%lu alphaHalf=%lu amax=%.3f "
            "cmax=(%.3f,%.3f,%.3f) meshHits=%llu meshMisses=%llu",
            (unsigned long)sky_batches.size(), tex1, tex32, tex64, tex_other, alpha_zero,
            alpha_half, amax, cmax[0], cmax[1], cmax[2], _meshTexHits, _meshTexMisses);
      NSLog(@"ottsel metal: SKYRGB 1x1=(%.3f,%.3f,%.3f) 32=(%.3f,%.3f,%.3f) "
            "64=(%.3f,%.3f,%.3f)",
            rgb_by_size[0][0], rgb_by_size[0][1], rgb_by_size[0][2],
            rgb_by_size[1][0], rgb_by_size[1][1], rgb_by_size[1][2],
            rgb_by_size[2][0], rgb_by_size[2][1], rgb_by_size[2][2]);
    }
  }
  // Desktop bucket order draws opaque background TFRAG before normal TIE.
  // They share the exact camera/material shader but have separate meshes and
  // time-of-day color tables.
  if (!self.directFixtureIsolated && !self.sceneNoTfragProbe) {
    if (self.sceneTfragFixture) {
      const OttselTfragFixtureVertex fixture_vertices[6] = {
          {-0.75f, -0.75f, 0.5f, {255, 255, 255, 255}, 0.f, 1.f, 0, 0, 0},
          {0.75f, -0.75f, 0.5f, {255, 255, 255, 255}, 1.f, 1.f, 0, 0, 0},
          {0.75f, 0.75f, 0.5f, {255, 255, 255, 255}, 1.f, 0.f, 0, 0, 0},
          {-0.75f, -0.75f, 0.5f, {255, 255, 255, 255}, 0.f, 1.f, 0, 0, 0},
          {0.75f, 0.75f, 0.5f, {255, 255, 255, 255}, 1.f, 0.f, 0, 0, 0},
          {-0.75f, 0.75f, 0.5f, {255, 255, 255, 255}, 0.f, 0.f, 0, 0, 0},
      };
      const unsigned int fixture_indices[6] = {0, 1, 2, 3, 4, 5};
      const unsigned char fixture_colors[4] = {255, 255, 255, 255};
      id<MTLBuffer> fixture_v = [self.device newBufferWithBytes:fixture_vertices
                                                            length:sizeof(fixture_vertices)
                                                           options:MTLResourceStorageModeShared];
      id<MTLBuffer> fixture_i = [self.device newBufferWithBytes:fixture_indices
                                                            length:sizeof(fixture_indices)
                                                           options:MTLResourceStorageModeShared];
      id<MTLBuffer> fixture_c = [self.device newBufferWithBytes:fixture_colors
                                                            length:sizeof(fixture_colors)
                                                           options:MTLResourceStorageModeShared];
      std::vector<OttselMetalTieDraw> fixture_draws = {{0, 6, 0, 0}};
      id<MTLTexture> saved_texture = self.tieTextures.count ? self.tieTextures[0] : nil;
      while (self.tieTextures.count == 0) {
        [self.tieTextures addObject:[NSNull null]];
      }
      self.tieTextures[0] = self.tfragFixtureTexture;
      draw_mesh(fixture_v, fixture_i, fixture_c, 6, fixture_draws, true, false, draw_uniforms);
      self.tieTextures[0] = saved_texture ? (id)saved_texture : (id)[NSNull null];
      static bool fixture_logged = false;
      if (!fixture_logged) {
        fixture_logged = true;
        NSLog(@"ottsel metal: TFRAG pipeline fixture submitted clip-quad=(-.75,-.75)..(.75,.75)");
      }
    } else {
      for (const auto& ref : scene_frame) {
        if (ref.key.second != true) continue;
        const auto found = _sceneMeshes.find(ref.key);
        if (found == _sceneMeshes.end()) continue;
        const auto& mesh = found->second;
        draw_mesh(mesh.vertices, mesh.indices, mesh.colors, mesh.index_count,
                  mesh.draws, true, false, ref.uniforms);
      }
    }
  }
  if (!self.directFixtureIsolated && !self.sceneNoTieProbe) {
      for (const auto& ref : scene_frame) {
        if (ref.key.second != false) continue;
        const auto found = _sceneMeshes.find(ref.key);
        if (found == _sceneMeshes.end()) continue;
        const auto& mesh = found->second;
        draw_mesh(mesh.vertices, mesh.indices, mesh.colors, mesh.index_count,
                  mesh.draws, false, false, ref.uniforms);
      }
  }
  if (!self.directFixtureIsolated && self.mercIndexCount && !self.sceneNoMercProbe) {
    draw_mesh(self.mercVertices, self.mercIndices, self.mercColors, self.mercIndexCount,
              _mercDraws, false, true, _mercFrameUniforms);
  }
  if (!self.directFixtureIsolated && _mercActorIndexCount && !self.sceneNoMercProbe) {
    draw_mesh(_mercActorVertices, _mercActorIndices, _mercActorColors, _mercActorIndexCount,
              _mercActorDraws, false, true, _mercFrameUniforms);
  }
  // Tagged snapshot: remember which groups this frame encodes so the terminal
  // erase can remove exactly those. Groups the game thread appends while this
  // command buffer is being built must survive to the next frame instead of
  // being cleared unencoded -- that drop is what tore the menu glyphs.
  const auto sprite_tagged = _spriteBatches.snapshot_tagged();
  std::vector<NativeSpriteBatch> sprite_batches;
  std::vector<unsigned long long> ottsel_sprite_drawn_tags;
  sprite_batches.reserve(sprite_tagged.size());
  ottsel_sprite_drawn_tags.reserve(sprite_tagged.size());
  for (const auto& tagged : sprite_tagged) {
    sprite_batches.push_back(tagged.second);
    if (!tagged.second.persistent) {
      ottsel_sprite_drawn_tags.push_back(tagged.first);
    }
  }
  static unsigned int sprite_draw_logs = 0;
  // BOT49 probe: the game thread appends sprite groups while this thread builds
  // the command buffer, so a group produced in that window is cleared without
  // ever being encoded.  Record both sides of that window.
  const size_t ottsel_sprite_batches_drawn = sprite_batches.size();
  if (!sprite_batches.empty() && !self.directFixtureIsolated && !self.sceneNoSpriteProbe) {
    unsigned int sprite_state[6] = {ottsel::sprite3_alpha_test_enabled(),
                                    ottsel::sprite3_alpha_test_gequal(),
                                    ottsel::sprite3_primary_alpha_ref(), 1, 0, 0};
    size_t sprite_draw_index = 0;
    // G2.2 HUD parity: log every batch of one pass per second, so a single-sampled
    // batch cannot hide an atlas/HUD batch that is drawn later in the same pass.
    static double sprite_pass_last = 0.0;
    const double sprite_pass_now = CACurrentMediaTime();
    const bool sprite_pass_log = sprite_pass_now - sprite_pass_last >= 1.0;
    if (sprite_pass_log) {
      sprite_pass_last = sprite_pass_now;
    }
    // G2.2 HUD parity: cap the record at 20 batches per logged pass.  The old
    // 60-line global budget filled inside three passes, so a later in-level
    // group - exactly where the HUD appears - could never be recorded.
    unsigned int sprite_pass_records = 0;
    for (const auto& sprite : sprite_batches) {
      ++sprite_draw_index;
      sprite_state[5] = sprite.ta0;
      [enc setRenderPipelineState:sprite.blended ? self.spriteBlendPipeline
                                                 : self.spritePipeline];
      // G2.2 HUD parity: the sprite pass tests GEQUAL with depth writes off, so a
      // 2D/HUD quad whose z is farther than the world's is rejected.  This gated
      // control draws sprites with the overlay (ALWAYS/no-write) state instead, so
      // "the depth test rejects them" can be separated from "nothing is drawn".
      static int sprite_overlay_depth = -1;
      if (sprite_overlay_depth < 0) {
        const std::string sprite_depth_trigger =
            ottsel_ios_writable_dir() + "ottsel-trace-sprite-overlay-depth";
        sprite_overlay_depth = access(sprite_depth_trigger.c_str(), F_OK) == 0 ? 1 : 0;
      }
      [enc setDepthStencilState:(self.sceneNoDepthProbe || sprite_overlay_depth)
                                  ? self.overlayDepthState
                                  : self.spriteDepthState];
      // G2.2 HUD parity: the vertex buffer is MTLResourceStorageModeShared, so the
      // vertex the GPU is about to fetch can be read back here.  That decides whether
      // the HUD path's vertices (or a fixture's known quad) reach the draw at all.
      {
        static int sprite_vertex_probe = -1;
        static unsigned int sprite_vertex_logs = 0;
        if (sprite_vertex_probe < 0) {
          const std::string sprite_vertex_trigger =
              ottsel_ios_writable_dir() + "ottsel-trace-sprite-first-vertex";
          sprite_vertex_probe = access(sprite_vertex_trigger.c_str(), F_OK) == 0 ? 1 : 0;
        }
        // Per-second record of the batches this pass draws, with the texture size and
        // the post-divide depth.  The previous version kept a 60-line global budget
        // and dropped the draw for every batch outside a q band; the first hid later
        // groups and the second skipped draws it was only supposed to observe.
        if (sprite_vertex_probe && sprite_vertex_logs < 240 && sprite.vertices.contents &&
            sprite.vertex_count && sprite_pass_log && sprite_pass_records < 20) {
          ++sprite_pass_records;
          ++sprite_vertex_logs;
          const OttselMetalSpriteVertex* first =
              (const OttselMetalSpriteVertex*)sprite.vertices.contents;
          lg::info("OTTSEL SPRITE DRAW: store={} idx={} tex={}x{} n={} blend={} "
                   "v0=({:.3f},{:.3f}) q={:.3f} z={:.4f} z/q={:.5f}",
                   (unsigned long)sprite_batches.size(), (unsigned long)sprite_draw_index,
                   (unsigned long)sprite.texture.width, (unsigned long)sprite.texture.height,
                   (unsigned long)sprite.vertex_count, sprite.blended ? 1 : 0, first->pos[0],
                   first->pos[1], first->q, first->z,
                   first->q != 0.f ? first->z / first->q : 0.f);
        }
      }
      [enc setVertexBuffer:sprite.vertices offset:0 atIndex:0];
      [enc setFragmentTexture:sprite.texture atIndex:0];
      [enc setFragmentSamplerState:self.directSampler atIndex:0];
      [enc setFragmentBytes:sprite_state length:sizeof(sprite_state) atIndex:1];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:sprite.vertex_count];
      if (ottsel_mobile_log_within_budget(sprite_draw_logs, 12)) {
        ++sprite_draw_logs;
        NSLog(@"ottsel metal: Sprite3 native draw vertices=%lu blend=%s batches=%lu depth=gequal/no-write "
              "alpha-test=gequal/%u/%u tcc=1 tfx=0 texture=hit",
              (unsigned long)sprite.vertex_count, sprite.blended ? "enabled" : "disabled",
              (unsigned long)sprite_batches.size(), ottsel::sprite3_alpha_test_gequal(),
              ottsel::sprite3_primary_alpha_ref());
      }
    }
    // G2.2 HUD parity positive control (gated, observability only): redraw the
    // atlas-size batches through the sprite pipeline with a 1x1 opaque white texture
    // and the overlay depth state.  "The batch is drawn and its fragments are
    // discarded" (a transparent texel at the sampled uv, a bad uv, the alpha test)
    // then paints white where the HUD belongs, while "the vertices never rasterize"
    // or "the batch is never drawn" stays clean.  The fixture alone could not make
    // that split: its own uv may sample a transparent atlas cell and be discarded.
    static int sprite_atlas_fill = -1;
    if (sprite_atlas_fill < 0) {
      const std::string sprite_atlas_fill_trigger =
          ottsel_ios_writable_dir() + "ottsel-trace-sprite-atlas-fill";
      sprite_atlas_fill = access(sprite_atlas_fill_trigger.c_str(), F_OK) == 0 ? 1 : 0;
    }
    if (sprite_atlas_fill) {
      static id<MTLTexture> sprite_white_texture = nil;
      if (!sprite_white_texture) {
        MTLTextureDescriptor* white_desc = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                         width:1
                                        height:1
                                     mipmapped:NO];
        white_desc.usage = MTLTextureUsageShaderRead;
        sprite_white_texture = [self.device newTextureWithDescriptor:white_desc];
        const unsigned char white[4] = {255, 255, 255, 255};
        [sprite_white_texture replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                                mipmapLevel:0
                                  withBytes:white
                                bytesPerRow:4];
      }
      unsigned int sprite_atlas_fill_redrawn = 0;
      for (const auto& sprite : sprite_batches) {
        if (sprite.texture.width < 320 || !sprite.vertices.contents || !sprite.vertex_count) {
          continue;
        }
        const unsigned int fill_state[6] = {0, 0, 0, 1, 0, 0};
        [enc setRenderPipelineState:self.spritePipeline];
        [enc setDepthStencilState:self.overlayDepthState];
        [enc setVertexBuffer:sprite.vertices offset:0 atIndex:0];
        [enc setFragmentTexture:sprite_white_texture atIndex:0];
        [enc setFragmentSamplerState:self.directSampler atIndex:0];
        [enc setFragmentBytes:fill_state length:sizeof(fill_state) atIndex:1];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
                vertexCount:sprite.vertex_count];
        ++sprite_atlas_fill_redrawn;
      }
      static unsigned int sprite_atlas_fill_logs = 0;
      if (sprite_atlas_fill_logs < 40) {
        ++sprite_atlas_fill_logs;
        lg::info("OTTSEL SPRITE ATLAS FILL: redrawn={} of {} drawn batches",
                 sprite_atlas_fill_redrawn, (unsigned long)sprite_batches.size());
      }
    }
  }
  // Foreground Direct/GIF text: the desktop debug bucket draws after the world
  // and after sprites. Decoded Direct batches carry their GS depth policy;
  // legacy callers retain overlay depth. Only the touch overlay is suppressed
  // by -scene-no-overlay.
  // Replay the last completed Direct image. Never consume the next chain's
  // in-progress geometry. Empty completed frames intentionally erase labels.
  const auto direct_snapshot = _directFrameStore.snapshot();
  const auto& direct_batches = direct_snapshot.batches;
  // These buffers belonged to superseded frames. This command buffer is
  // submitted after their earlier users on the same serial queue; only its
  // completion returns them to the pool. Replayed active buffers stay owned.
  frame_vertex_buffers.insert(frame_vertex_buffers.end(), direct_snapshot.retired.begin(),
                              direct_snapshot.retired.end());
  static unsigned int direct_text_draw_logs = 0;
  static unsigned int ottsel_direct_frame_logs = 0;
  if (ottsel_mobile_log_within_budget(ottsel_direct_frame_logs, 3000)) {
    ++ottsel_direct_frame_logs;
    lg::info("OTTSEL DIRECT FRAME: n={} drawn={}", ottsel_direct_frame_logs,
             (unsigned long)direct_batches.size());
  }
  if (!direct_batches.empty() && !self.directFixtureIsolated) {
    unsigned int direct_text_state[6] = {0, 0, 0, 1, 0, 0};
    for (const auto& direct_batch : direct_batches) {
      direct_text_state[5] = direct_batch.ta0;
      [enc setRenderPipelineState:direct_batch.blended ? self.directBlendPipeline
                                                       : self.directPipeline];
      [enc setDepthStencilState:[self depthStateForDirectBatch:direct_batch]];
      [enc setVertexBuffer:direct_batch.vertices offset:0 atIndex:0];
      [enc setFragmentTexture:direct_batch.texture atIndex:0];
      [enc setFragmentSamplerState:self.directSampler atIndex:0];
      [enc setFragmentBytes:direct_text_state length:sizeof(direct_text_state) atIndex:1];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
              vertexCount:direct_batch.vertex_count];
    }
    // G2.2 blend ledger, Direct site (observability only): one line per distinct
    // register mix over the whole Direct population of this arm.
    if (_blendLedgerArmed) {
      unsigned long long reg[4] = {0, 0, 0, 0};
      unsigned long count[4] = {0, 0, 0, 0};
      unsigned long other = 0;
      int used = 0;
      for (const auto& direct_batch : direct_batches) {
        const unsigned long long r = direct_batch.diagnostic_alpha & 0xffull;
        int slot = -1;
        for (int i = 0; i < used; ++i) {
          if (reg[i] == r) {
            slot = i;
            break;
          }
        }
        if (slot < 0 && used < 4) {
          reg[used] = r;
          count[used] = 0;
          slot = used;
          ++used;
        }
        if (slot < 0) {
          ++other;
        } else {
          ++count[slot];
        }
      }
      bool direct_mix_changed = (_directMixLines == 0) || _directMixOther != other;
      for (int i = 0; i < 4 && !direct_mix_changed; ++i) {
        if (_directMixReg[i] != reg[i] || _directMixCount[i] != count[i]) {
          direct_mix_changed = true;
        }
      }
      if (direct_mix_changed && _directMixLines < 8) {
        ++_directMixLines;
        for (int i = 0; i < 4; ++i) {
          _directMixReg[i] = reg[i];
          _directMixCount[i] = count[i];
        }
        _directMixOther = other;
        NSLog(@"ottsel metal: DIRECTREG-MIX arm=%lu n=%lu r0=0x%llx:%lu r1=0x%llx:%lu "
              @"r2=0x%llx:%lu r3=0x%llx:%lu other=%lu",
              (unsigned long)_blendLedgerArms, (unsigned long)direct_batches.size(), reg[0],
              count[0], reg[1], count[1], reg[2], count[2], reg[3], count[3], other);
      }
    }
    if (ottsel_mobile_log_within_budget(direct_text_draw_logs, 8)) {
      ++direct_text_draw_logs;
      NSLog(@"ottsel metal: direct text draw batches=%lu vertices=%lu texture=%lux%lu blend=%s",
            (unsigned long)direct_batches.size(),
            (unsigned long)direct_batches.front().vertex_count,
            (unsigned long)direct_batches.front().texture.width,
            (unsigned long)direct_batches.front().texture.height,
            direct_batches.front().blended ? "enabled" : "disabled");
    }
  }
  // D0-NORMAL Direct owns the same final drawable as the existing composition.
  // Append it after TFRAG/TIE in this encoder; never replace the scene with a
  // fixture-only early return.
  if (self.directFixtureActive) {
    self.directDrawCount++;
    self.directTriangleCount += 2;
    [enc setRenderPipelineState:self.directFixtureColorOnly
                              ? self.directColorOnlyPipeline
                              : (self.directFixtureNoDepth
                                     ? self.directNoDepthPipeline
                                     : (self.directBlendEnabled ? self.directBlendPipeline
                                                                : self.directPipeline))];
    // DirectRenderer resets each bucket to Jak 1's default GEQUAL/depth-write
    // state. Do not inherit depth ownership from whichever TIE/TFRAG draw ran
    // immediately before this Direct primitive.
    if (!self.directFixtureNoDepth) {
      [enc setDepthStencilState:self.directDepthState];
    }
    [enc setVertexBuffer:self.directVertices offset:0 atIndex:0];
    if (!self.directFixtureColorOnly) {
      [enc setFragmentTexture:self.directTex atIndex:0];
      [enc setFragmentSamplerState:self.directSampler atIndex:0];
    }
    const unsigned int direct_state[6] = {self.directAlphaTestEnable, self.directAlphaTest,
                                          self.directAlphaRef, self.directTcc, self.directTfx, 0};
    [enc setFragmentBytes:direct_state length:sizeof(direct_state) atIndex:1];
    if (self.directScissorX1 > self.directScissorX0 && self.directScissorY1 > self.directScissorY0) {
      // DirectRenderer's fragment shader maps GS scissor through the Jak 1
      // 512x448 game surface into the drawable (with Y inverted).
      const NSUInteger sx = (NSUInteger)self.directScissorX0 * drawable.texture.width / 512;
      const NSUInteger ex = std::min((NSUInteger)(self.directScissorX1 + 1) *
                                         drawable.texture.width / 512,
                                     (NSUInteger)drawable.texture.width);
      const NSUInteger sy = (NSUInteger)(448 - std::min(self.directScissorY1 + 1, 448u)) *
                            drawable.texture.height / 448;
      const NSUInteger ey = (NSUInteger)(448 - std::min(self.directScissorY0, 448u)) *
                            drawable.texture.height / 448;
      if (ex > sx && ey > sy) {
        MTLScissorRect scissor = {sx, sy, ex - sx, ey - sy};
        [enc setScissorRect:scissor];
      }
    }
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    if (self.directDrawCount == 1) {
      if (self.directFixtureNoDepth) {
        NSLog(@"ottsel metal: Direct %s draw contract draws=%lu triangles=%lu "
              "depth=disabled final-target=same-pass",
              self.directFixtureColorOnly ? "color-only" : "no-depth",
              (unsigned long)self.directDrawCount, (unsigned long)self.directTriangleCount);
      } else {
        NSLog(@"ottsel metal: Direct draw contract draws=%lu triangles=%lu blend=%s "
            "alpha=0x%llx test=0x%llx zbuf=0x%llx depth=gequal/write color-mask=rgba "
            "alpha-test=%s/%u/%u final-target=same-pass",
            (unsigned long)self.directDrawCount, (unsigned long)self.directTriangleCount,
            self.directBlendEnabled ? "enabled" : "disabled", self.directAlpha,
            self.directTest, self.directZbuf, self.directAlphaTestEnable ? "enabled" : "disabled",
            self.directAlphaTest, self.directAlphaRef);
      }
    }
  }
  // The Direct batch loop above sets a per-batch GS scissor and never restores it, so the
  // full-screen overlay draws below were clipped to the last batch's rect - which is why
  // the touch overlay and the shell status screen never appeared.  Restore the full
  // drawable rect before either overlay draws.
  {
    const MTLScissorRect full_scissor = {0, 0, drawable.texture.width, drawable.texture.height};
    [enc setScissorRect:full_scissor];
  }
  if (!self.directFixtureIsolated && !self.sceneNoOverlayProbe && self.touchOverlayVertices && self.touchOverlayTex &&
      self.touchOverlayVertexCount) {
    [enc setRenderPipelineState:self.directBlendPipeline];
    [enc setDepthStencilState:self.overlayDepthState];
    [enc setVertexBuffer:self.touchOverlayVertices offset:0 atIndex:0];
    [enc setFragmentTexture:self.touchOverlayTex atIndex:0];
    [enc setFragmentSamplerState:self.directSampler atIndex:0];
    const unsigned int overlay_state[6] = {0, 0, 0, 0, 0, 0};
    [enc setFragmentBytes:overlay_state length:sizeof(overlay_state) atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
            vertexCount:self.touchOverlayVertexCount];
  }
  // F1/G2.6: the shell status screen last of all, so a data-less boot shows the
  // import instruction instead of unresident game frames.
  if (!self.directFixtureIsolated && self.statusOverlayVertices && self.statusOverlayTex &&
      self.statusOverlayVertexCount) {
    // Discriminator (trigger-gated): paint this slot with the known-good opaque magenta
    // fill instead of the status texture, so "the draw runs" can be told from "the
    // uploaded surface is what is wrong".
    static int status_fill_probe = -1;
    if (status_fill_probe < 0) {
      const std::string status_fill_trigger =
          ottsel_ios_writable_dir() + "ottsel-trace-status-fill";
      status_fill_probe = access(status_fill_trigger.c_str(), F_OK) == 0 ? 1 : 0;
    }
    const unsigned int status_state[6] = {0, 0, 0, 1, 0, 0};
    [enc setRenderPipelineState:status_fill_probe ? self.skyDebugFillPipeline
                                                    : self.directPipeline];
    [enc setDepthStencilState:self.overlayDepthState];
    [enc setVertexBuffer:self.statusOverlayVertices offset:0 atIndex:0];
    [enc setFragmentTexture:self.statusOverlayTex atIndex:0];
    [enc setFragmentSamplerState:self.directSampler atIndex:0];
    [enc setFragmentBytes:status_state length:sizeof(status_state) atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
            vertexCount:self.statusOverlayVertexCount];
  }
  // BOT40 I1.1c diagnostic: settle the sky draw path with ONE question.
  // The sky is encoded before every opaque bucket in this pass, so a probe
  // drawn inside the sky loop can be overdrawn by later TFRAG/TIE/Merc/Sprite
  // and read as "dead" even when the pipeline is fine.  Draw the same debug
  // pipeline here, at the END of the pass, with the known-working
  // overlayDepthState (compare ALWAYS, no depth write) and a locally-owned
  // buffer: a magenta full-screen triangle proves vertex layout + pipeline +
  // encoder all reach pixels.  Observability only; never product output.
  if (self.sceneSkyDebugFillAllProbe && self.skyDebugFillPipeline) {
    static id<MTLBuffer> sky_path_probe_vertices = nil;
    if (!sky_path_probe_vertices) {
      const DirectFixtureVertex probe[3] = {
          {{-1.f, -1.f}, {0.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
          {{1.f, -1.f}, {1.f, 0.f}, {1.f, 1.f, 1.f, 1.f}},
          {{-1.f, 1.f}, {0.f, 1.f}, {1.f, 1.f, 1.f, 1.f}},
      };
      sky_path_probe_vertices = [self.device newBufferWithBytes:probe
                                                        length:sizeof(probe)
                                                       options:MTLResourceStorageModeShared];
      NSLog(@"ottsel metal: ENCPROBE buffer=%p", sky_path_probe_vertices);
    }
    if (sky_path_probe_vertices) {
      [enc setRenderPipelineState:self.skyDebugFillPipeline];
      [enc setDepthStencilState:self.overlayDepthState];
      [enc setVertexBuffer:sky_path_probe_vertices offset:0 atIndex:0];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    }
  }
  // BOT40 I1.1c diagnostic: redraw the captured sky batches at the END of the
  // pass with the REAL product pipeline and texture.  The magenta probe above
  // already proved pipeline/layout/encoder reach pixels; if the sky paints here
  // but not in its normal pre-world slot, the defect is pass position or state
  // residue.  If it does not paint here either, the fault is the sampled
  // texture content.  Observability only; never product output.
  if (self.sceneSkyEndProbe) {
    const auto& end_sky_batches = sky_batches;
    unsigned int end_sky_state[6] = {0, 0, 0, 1, 0, 0};
    for (const auto& sky : end_sky_batches) {
      end_sky_state[5] = sky.ta0;
      [enc setRenderPipelineState:sky.blended ? self.directBlendPipeline
                                              : self.directPipeline];
      [enc setDepthStencilState:self.overlayDepthState];
      [enc setVertexBuffer:sky.vertices offset:0 atIndex:0];
      [enc setFragmentTexture:sky.texture atIndex:0];
      [enc setFragmentSamplerState:self.directSampler atIndex:0];
      [enc setFragmentBytes:end_sky_state length:sizeof(end_sky_state) atIndex:1];
      // BOT57 Q3 completion: with the debug-fill probe also armed, redraw the
      // captured sky batches here, at the END of the pass, through the opaque
      // magenta fragment.  The ENCPROBE triangle already proves this slot
      // reaches pixels, so magenta here means the sky's own buffers/vertices
      // rasterize and the pre-world slot is at fault; no magenta means the
      // submitted vertex data never produces a fragment at all.
      if (self.sceneSkyDebugFillProbe && self.skyDebugFillPipeline) {
        [enc setRenderPipelineState:self.skyDebugFillPipeline];
      }
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
              vertexCount:sky.vertex_count];
    }
    static bool end_sky_logged = false;
    if (!end_sky_logged) {
      end_sky_logged = true;
      NSLog(@"ottsel metal: SKYENDREDRAW batches=%lu first=%lux%lu",
            (unsigned long)end_sky_batches.size(),
            end_sky_batches.empty()
                ? 0ul
                : (unsigned long)end_sky_batches.front().texture.width,
            end_sky_batches.empty()
                ? 0ul
                : (unsigned long)end_sky_batches.front().texture.height);
    }
  }
  encoder_guard.end();
  // Dedicated final pass: fixed batch and fixed clear/depth, no world occlusion.
  if (_skyIsolation && !self.directFixtureOffscreen) {
    _skyIsolation->capture(sky_batches,drawable.texture,self.directSampler,
      ^id<MTLDepthStencilState>(const NativeSpriteBatch& batch) { return [self depthStateForDirectBatch:batch]; });
    _skyIsolation->encode(cb,drawable.texture);
  }
  // One-shot diagnostic readback only. This copies the actual composed Metal
  // drawable after all active buckets have rendered; it never feeds the
  // product frame path or OttselRaster. The trigger is consumed once so a
  // blank Simulator surface can be distinguished from a blank GPU drawable.
  static bool native_readback_consumed = false;
  static bool direct_readback_consumed = false;
  const std::string readback_trigger = ottsel_ios_writable_dir() +
                                        "ottsel-dump-native-sprite-metal";
  const std::string direct_readback_trigger = ottsel_ios_writable_dir() +
                                              "ottsel-dump-direct-fixture-metal";
  const bool readback_sprite = self.spriteActive && !native_readback_consumed &&
                               access(readback_trigger.c_str(), F_OK) == 0;
  const bool readback_direct = self.directFixtureActive && !direct_readback_consumed &&
                               access(direct_readback_trigger.c_str(), F_OK) == 0;
  if (readback_sprite || readback_direct) {
    unlink((readback_direct ? direct_readback_trigger : readback_trigger).c_str());
    if (readback_direct) {
      direct_readback_consumed = true;
    } else {
      native_readback_consumed = true;
    }
    const NSUInteger width = drawable.texture.width;
    const NSUInteger height = drawable.texture.height;
    id<MTLBuffer> readback = [self.device newBufferWithLength:width * height * 4
                                                         options:MTLResourceStorageModeShared];
    if (readback) {
      id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
      [blit copyFromTexture:drawable.texture
                sourceSlice:0
                sourceLevel:0
               sourceOrigin:MTLOriginMake(0, 0, 0)
                 sourceSize:MTLSizeMake(width, height, 1)
                   toBuffer:readback
          destinationOffset:0
     destinationBytesPerRow:width * 4
   destinationBytesPerImage:width * height * 4];
      [blit endEncoding];
      const std::string output_path = ottsel_ios_writable_dir() +
                                      (readback_direct ? "ottsel-direct-fixture-metal.ppm"
                                                       : "ottsel-native-sprite-metal.ppm");
      [cb addCompletedHandler:^(id<MTLCommandBuffer> completed) {
        if (completed.status != MTLCommandBufferStatusCompleted) {
          return;
        }
        const unsigned char* pixels = (const unsigned char*)readback.contents;
        FILE* file = fopen(output_path.c_str(), "wb");
        if (!file) {
          return;
        }
        fprintf(file, "P6\n%lu %lu\n255\n", (unsigned long)width, (unsigned long)height);
        for (NSUInteger y = 0; y < height; ++y) {
          for (NSUInteger x = 0; x < width; ++x) {
            const unsigned char* pixel = pixels + (y * width + x) * 4;
            fputc(pixel[2], file);
            fputc(pixel[1], file);
            fputc(pixel[0], file);
          }
        }
        fclose(file);
      }];
    }
  }
  if (self.directFixtureOffscreen) {
    [cb addCompletedHandler:^(id<MTLCommandBuffer> completed) {
      NSLog(@"ottsel metal: Direct offscreen completion status=%ld error=%@",
            (long)completed.status, completed.error);
    }];
  } else {
    trace_frame_pacing(drawable, cb);
    [cb presentDrawable:drawable];
  }
  // Retire only captured transient batches, including deliberately suppressed
  // probe batches. Erase before commit so completion cannot recycle a resource
  // while its old batch is still available to a subsequent snapshot.
  [self recycleVertexBuffers:frame_vertex_buffers after:cb];
  _spriteBatches.erase_tags(ottsel_sprite_drawn_tags);
  [cb commit];
  if (self.directFixtureOffscreen) {
    return;
  }
  static unsigned int ottsel_sprite_frame_logs = 0;
  const size_t ottsel_sprite_batches_late = _spriteBatches.snapshot().size();
  if (ottsel_mobile_log_within_budget(ottsel_sprite_frame_logs, 8000)) {
    ++ottsel_sprite_frame_logs;
    lg::info("OTTSEL SPRITE FRAME: n={} drawn={} appended-during-encode={}",
             ottsel_sprite_frame_logs, ottsel_sprite_batches_drawn,
             ottsel_sprite_batches_late);
  }
}

- (void)beginSceneFrame {
  _directFrameStore.begin();
  // An abandoned producer chain must not contaminate its replacement.
  // This never touches the last completed frame waiting for presentation.
  {
    std::lock_guard<std::mutex> merc_lock(_mercMutex);
    _pendingMercVertices.clear();
    _pendingMercIndices.clear();
    _pendingMercDraws.clear();
    _pendingMercColors.clear();
    _pendingMercActorVertices.clear();
    _pendingMercActorIndices.clear();
    _pendingMercActorDraws.clear();
    _pendingMercActorColors.clear();
  }
  std::lock_guard<std::mutex> lock(_tieUploadMutex);
  _buildingSceneFrame.clear();
}
- (void)referenceScene:(const char*)level tfrag:(BOOL)tfrag {
  if (!level || !*level) return;
  SceneFrameReference ref;
  ref.key = {level, bool(tfrag)};
  { std::lock_guard<std::mutex> lock(_tieUniformMutex); ref.uniforms = _tieUniforms; }
  std::lock_guard<std::mutex> lock(_tieUploadMutex);
  auto existing = std::find_if(_buildingSceneFrame.begin(), _buildingSceneFrame.end(),
      [&](const SceneFrameReference& old) { return old.key == ref.key; });
  if (existing == _buildingSceneFrame.end()) _buildingSceneFrame.push_back(ref);
  else *existing = ref;
}
- (void)publishSceneFrame {
  _directFrameStore.publish();
  // Publish even an empty Merc frame: absence of actors is visible state.
  // Capture the camera with this completed geometry, not at display time.
  {
    auto frame = std::make_unique<MercFrameTransaction>();
    { std::lock_guard<std::mutex> uniform_lock(_tieUniformMutex);
      frame->uniforms = _tieUniforms; }
    std::lock_guard<std::mutex> merc_lock(_mercMutex);
    frame->vertices = std::move(_pendingMercVertices);
    _pendingMercVertices.clear();
    frame->indices = std::move(_pendingMercIndices);
    _pendingMercIndices.clear();
    frame->draws = std::move(_pendingMercDraws);
    _pendingMercDraws.clear();
    frame->colors = std::move(_pendingMercColors);
    _pendingMercColors.clear();
    frame->actor_vertices = std::move(_pendingMercActorVertices);
    _pendingMercActorVertices.clear();
    frame->actor_indices = std::move(_pendingMercActorIndices);
    _pendingMercActorIndices.clear();
    frame->actor_draws = std::move(_pendingMercActorDraws);
    _pendingMercActorDraws.clear();
    frame->actor_colors = std::move(_pendingMercActorColors);
    _pendingMercActorColors.clear();
    _completedMercFrame = std::move(frame);
  }
  std::lock_guard<std::mutex> lock(_tieUploadMutex);
  if (!_completedSceneFrame) _completedSceneFrame = std::make_unique<SceneFrameTransaction>();
  // Latest completed frame wins, but it inherits uninstalled immutable geometry
  // and palettes. CPU readiness must not lose their only queued copy when an
  // older completed frame is superseded before presentation can consume it.
  const auto merge = [](auto& destination, auto& incoming) {
    for (auto& upload : incoming) {
      destination.erase(std::remove_if(destination.begin(), destination.end(),
          [&](const auto& previous) {
            return previous.level == upload.level && previous.tfrag == upload.tfrag;
          }), destination.end());
      destination.push_back(std::move(upload));
    }
    incoming.clear();
  };
  merge(_completedSceneFrame->meshes, _pendingMeshUploads);
  merge(_completedSceneFrame->colors, _pendingColorUploads);
  _completedSceneFrame->refs = std::move(_buildingSceneFrame);
  _buildingSceneFrame.clear();
}

- (void)setTieMesh:(const void*)vertices
        vertexCount:(NSUInteger)vertexCount
     triangleIndices:(const unsigned int*)indices
          indexCount:(NSUInteger)indexCount
              draws:(const OttselMetalTieDraw*)draws
          drawCount:(NSUInteger)drawCount level:(const char*)level {
  if (!vertices || !vertexCount || !indices || !indexCount) {
    return;
  }
  PendingMeshUpload upload;
  upload.level = level ? level : "";
  upload.vertices.assign((const unsigned char*)vertices,
                         (const unsigned char*)vertices + vertexCount * 32);
  upload.indices.assign(indices, indices + indexCount);
  if (draws && drawCount) {
    upload.draws.assign(draws, draws + drawCount);
  }
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    // Replacement is scoped to one resident level and family.
    _pendingMeshUploads.erase(
        std::remove_if(_pendingMeshUploads.begin(), _pendingMeshUploads.end(),
                       [&](const PendingMeshUpload& pending) { return pending.tfrag == upload.tfrag && pending.level == upload.level; }),
        _pendingMeshUploads.end());
    _pendingMeshUploads.push_back(std::move(upload));
  }
}

// Upload a quad texture once per distinct content.  The Simulator turns every
// -replaceRegion: into a synchronous XPC round-trip, and the sky/Direct buckets
// re-submit tens of byte-identical tiles per frame, so uploading unconditionally
// here was the game thread's dominant cost.
- (id<MTLTexture>)cachedMeshTexture:(const unsigned char*)rgba
                              width:(NSUInteger)width
                             height:(NSUInteger)height {
  if (!rgba || !width || !height || !self.device) {
    return nil;
  }
  static unsigned long long mesh_tex_calls = 0;
  if ((++mesh_tex_calls % 8192ull) == 0) {
    lg::info("OTTSELMESHTEX calls={} hits={} misses={} bytes={}", mesh_tex_calls,
             _meshTexHits, _meshTexMisses, _meshTexBytes);
  }
  const NSUInteger bytes = width * height * 4;
  NSNumber* key = @(mesh_texture_key(rgba, width, height));
  id<MTLTexture> cached = _meshTexByKey[key];
  NSData* cached_pixels = _meshTexPixelsByKey[key];
  if (cached && cached.width == width && cached.height == height &&
      cached_pixels.length == bytes && memcmp(cached_pixels.bytes, rgba, bytes) == 0) {
    ++_meshTexHits;
    return cached;
  }
  MTLTextureDescriptor* desc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:width
                                  height:height
                               mipmapped:NO];
  desc.usage = MTLTextureUsageShaderRead;
  id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
  if (!texture) {
    return nil;
  }
  [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
             mipmapLevel:0
               withBytes:rgba
             bytesPerRow:width * 4];
  if (!_meshTexByKey) {
    _meshTexByKey = [[NSMutableDictionary alloc] init];
    _meshTexPixelsByKey = [[NSMutableDictionary alloc] init];
    _meshTexKeyOrder = [[NSMutableArray alloc] init];
  }
  NSData* previous = _meshTexPixelsByKey[key];
  if (previous) {
    _meshTexBytes -= previous.length;
  } else {
    [_meshTexKeyOrder addObject:key];
  }
  _meshTexByKey[key] = texture;
  _meshTexPixelsByKey[key] = [NSData dataWithBytes:rgba length:bytes];
  _meshTexBytes += bytes;
  ++_meshTexMisses;
  constexpr NSUInteger kMeshTextureCacheBytes = 32u * 1024u * 1024u;
  while (_meshTexBytes > kMeshTextureCacheBytes && _meshTexKeyOrder.count > 1) {
    NSNumber* oldest = _meshTexKeyOrder.firstObject;
    NSData* old_pixels = _meshTexPixelsByKey[oldest];
    _meshTexBytes -= old_pixels ? old_pixels.length : 0;
    [_meshTexByKey removeObjectForKey:oldest];
    [_meshTexPixelsByKey removeObjectForKey:oldest];
    [_meshTexKeyOrder removeObjectAtIndex:0];
  }
  return texture;
}
- (BOOL)appendSkyMeshNow:(const OttselMetalSpriteVertex*)vertices
             vertexCount:(NSUInteger)vertexCount
                   rgba:(const unsigned char*)rgba
                  width:(NSUInteger)width
                 height:(NSUInteger)height
                blended:(BOOL)blended
                    ta0:(unsigned char)ta0
                  depth:(const OttselMetalDirectDepthState*)depth diagnosticAlpha:(unsigned long long)diagnosticAlpha {
  if (!vertices || !vertexCount || !rgba || !width || !height || !self.device ||
      !self.directPipeline) {
    return NO;
  }
  id<MTLTexture> texture = [self cachedMeshTexture:rgba width:width height:height];
  if (!texture) {
    return NO;
  }
  const NSUInteger vertex_bytes = vertexCount * sizeof(OttselMetalSpriteVertex);
  id<MTLBuffer> vertex_buffer = [self borrowVertexBufferBytes:vertex_bytes];
  if (!vertex_buffer) {
    return NO;
  }
  memcpy(vertex_buffer.contents, vertices, vertex_bytes);
  NativeSpriteBatch batch{vertex_buffer, texture, vertexCount, blended, ta0, false};
  if (depth) { batch.depth = *depth; batch.has_gs_depth = true; }
  batch.diagnostic_alpha=diagnosticAlpha;
  _skyFrameStore.append(batch);
  return YES;
}

- (void)beginSkyBucket { _skyFrameStore.begin(); }

- (void)armBlendLedger {
  _blendLedgerArmed = YES;
  _blendLedgerTieDraws = 0;
  _blendLedgerTieLogged = NO;
  for (int i = 0; i < 8; ++i) {
    _blendLedgerTiePreset[i] = 0;
  }
  _blendLedgerTieEnable[0] = _blendLedgerTieEnable[1] = 0;
  _blendLedgerTieBlend[0] = _blendLedgerTieBlend[1] = 0;
  NSLog(@"ottsel metal: BLENDLEDGER armed arm=%lu", (unsigned long)(++_blendLedgerArms));
}

- (void)finishSkyBucket:(BOOL)complete {
  if (complete) _skyFrameStore.publish();
  else _skyFrameStore.begin(true); // Roll back only the failed attempt; keep ready Sky.
}

// Foreground Direct/GIF batch.  Same upload contract as the sky batch; only the
- (id<MTLBuffer>)borrowVertexBufferBytes:(NSUInteger)bytes {
  if (!bytes || !self.device) {
    return nil;
  }
  // Round the request up so a later, slightly larger batch can still reuse a
  // freed allocation; only reuse a buffer that genuinely fits.
  const NSUInteger need = (bytes + 255u) & ~(NSUInteger)255u;
  std::lock_guard<std::mutex> lock(_vertexPoolMutex);
  for (std::size_t i = 0; i < _vertexPool.size(); ++i) {
    if (_vertexPool[i].length >= need) {
      id<MTLBuffer> reused = _vertexPool[i];
      _vertexPool.erase(_vertexPool.begin() + (std::ptrdiff_t)i);
      _vertexPoolInFlight.push_back(reused);
      return reused;
    }
  }
  id<MTLBuffer> fresh = [self.device newBufferWithLength:need
                                                 options:MTLResourceStorageModeShared];
  if (fresh) {
    _vertexPoolInFlight.push_back(fresh);
  }
  return fresh;
}

// Return only this frame's captured buffers after its command buffer completes.
// A producer's later uploads stay pending until their own frame is submitted.
- (void)recycleVertexBuffers:(const std::vector<id<MTLBuffer>>&)buffers
                      after:(id<MTLCommandBuffer>)cb {
  if (!cb || buffers.empty()) {
    return;
  }
  std::vector<id<MTLBuffer>> done;
  {
    std::lock_guard<std::mutex> lock(_vertexPoolMutex);
    done = ottsel_mobile_take_encoded_resources(_vertexPoolInFlight, buffers);
  }
  if (done.empty()) {
    return;
  }
  const bool offscreen = self.directFixtureOffscreen;
  [cb addCompletedHandler:^(id<MTLCommandBuffer> completed) {
    static std::atomic<bool> normal_completion_logged{false};
    static std::atomic<unsigned int> completion_error_logs{0};
    if (completed.status == MTLCommandBufferStatusCompleted && !completed.error) {
      if (!offscreen && !normal_completion_logged.exchange(true)) {
        NSLog(@"ottsel metal: GPU completion first-normal status=%ld buffers=%lu error=%@",
              (long)completed.status, (unsigned long)done.size(), completed.error);
      }
    } else if (completion_error_logs.fetch_add(1) < 8) {
      NSLog(@"ottsel metal: GPU completion error status=%ld buffers=%lu offscreen=%d error=%@",
            (long)completed.status, (unsigned long)done.size(), offscreen, completed.error);
    }
    std::lock_guard<std::mutex> lock(_vertexPoolMutex);
    for (const id<MTLBuffer>& buffer : done) {
      _vertexPool.push_back(buffer);
    }
  }];
}

// Foreground Direct/GIF batch.  Same upload contract as the sky batch; only the
// draw position differs (after sprites, so text lands on top of the world).
- (void)appendDirectMeshNow:(const OttselMetalSpriteVertex*)vertices
                vertexCount:(NSUInteger)vertexCount
                      rgba:(const unsigned char*)rgba
                     width:(NSUInteger)width
                    height:(NSUInteger)height
                   blended:(BOOL)blended
                       ta0:(unsigned char)ta0
                  depth:(const OttselMetalDirectDepthState*)depth diagnosticAlpha:(unsigned long long)diagnosticAlpha {
  if (!vertices || !vertexCount || !rgba || !width || !height || !self.device ||
      !self.directPipeline) {
    return;
  }
  id<MTLTexture> texture = [self cachedMeshTexture:rgba width:width height:height];
  if (!texture) {
    return;
  }
  const NSUInteger vertex_bytes = vertexCount * sizeof(OttselMetalSpriteVertex);
  id<MTLBuffer> vertex_buffer = [self borrowVertexBufferBytes:vertex_bytes];
  if (!vertex_buffer) {
    return;
  }
  memcpy(vertex_buffer.contents, vertices, vertex_bytes);
  NativeSpriteBatch batch{vertex_buffer, texture, vertexCount, blended, ta0, false};
  if (depth) { batch.depth = *depth; batch.has_gs_depth = true; }
  // G2.2 ledger: carry the bucket's GS ALPHA register to the draw loop, exactly
  // as the sky path does.  Selection for this site is unchanged this round - a
  // Direct bucket that wrote no ALPHA_1 reports 0, which is not a decoded copy.
  batch.diagnostic_alpha = diagnosticAlpha;
  _directFrameStore.append(batch);
}

- (void)setTieCamera:(const float*)pcCamera
          mercPerspective:(const float*)mercPerspective
         cameraTrans:(const float*)cameraTrans
           fogParams:(const float*)fogParams
           fogColor:(const float*)fogColor
         hvdfOffset:(const float*)hvdfOffset
       fogConstant:(float)fogConstant {
  static int camera_trace_count = 0;
  const bool trace_camera = camera_trace_count++ < 8;
  if (trace_camera) {
    lg::info("OTTSEL CAMERA METHOD: enter");
  }
  if (!pcCamera || !cameraTrans || !fogParams || !fogColor || !hvdfOffset) {
    return;
  }
  std::lock_guard<std::mutex> lock(_tieUniformMutex);
  memcpy(_tieUniforms.pc_camera, pcCamera, sizeof(_tieUniforms.pc_camera));
  if (mercPerspective) {
    memcpy(_tieUniforms.merc_perspective, mercPerspective,
           sizeof(_tieUniforms.merc_perspective));
  }
  memcpy(_tieUniforms.camera_trans, cameraTrans, sizeof(_tieUniforms.camera_trans));
  memcpy(_tieUniforms.fog_params, fogParams, sizeof(_tieUniforms.fog_params));
  memcpy(_tieUniforms.fog_color, fogColor, sizeof(_tieUniforms.fog_color));
  memcpy(_tieUniforms.hvdf_offset, hvdfOffset, sizeof(_tieUniforms.hvdf_offset));
  _tieUniforms.fog_constant = fogConstant;
  if (trace_camera) {
    lg::info("OTTSEL CAMERA METHOD: exit");
  }
}

- (void)setTieTextureNowAtIndex:(NSUInteger)index
                            rgba:(const unsigned int*)rgba
                           width:(NSUInteger)width
                          height:(NSUInteger)height {
  if (!rgba || !width || !height) {
    return;
  }
  while (self.tieTextures.count <= index) {
    [self.tieTextures addObject:[NSNull null]];
  }
  MTLTextureDescriptor* desc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:width
                                  height:height
                               mipmapped:NO];
  desc.usage = MTLTextureUsageShaderRead;
  id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
  [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
             mipmapLevel:0
               withBytes:rgba
             bytesPerRow:width * sizeof(unsigned int)];
  self.tieTextures[index] = texture;
}

- (void)setTieTextureAtIndex:(NSUInteger)index
                         rgba:(const unsigned int*)rgba
                        width:(NSUInteger)width
                       height:(NSUInteger)height {
  if (!rgba || !width || !height || !self.device) {
    return;
  }
  PendingTieUpload upload;
  upload.rgba.assign(rgba, rgba + width * height);
  upload.index = index;
  upload.width = width;
  upload.height = height;
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    const bool already_queued = _queuedTieTextureIndices.contains(index);
    if (!ottsel_mobile_texture_upload_should_queue(already_queued)) {
      return;
    }
    _queuedTieTextureIndices.insert(index);
    _pendingTieUploads.push_back(std::move(upload));
  }
}

- (void)drainTieTextureUploads {
  constexpr unsigned int kUploadBudgetPerFrame = 8;
  for (unsigned int i = 0; i < kUploadBudgetPerFrame; ++i) {
    PendingTieUpload upload;
    {
      std::lock_guard<std::mutex> lock(_tieUploadMutex);
      if (_pendingTieUploads.empty()) {
        return;
      }
      upload = std::move(_pendingTieUploads.front());
      _pendingTieUploads.pop_front();
    }
    [self setTieTextureNowAtIndex:upload.index
                              rgba:upload.rgba.data()
                             width:upload.width
                            height:upload.height];
  }
}

- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count level:(const char*)level {
  if (!rgba || !count) {
    return;
  }
  PendingColorUpload upload;
  upload.level = level ? level : "";
  upload.rgba.assign(rgba, rgba + count * 4);
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    _pendingColorUploads.erase(
        std::remove_if(_pendingColorUploads.begin(), _pendingColorUploads.end(),
                       [&](const PendingColorUpload& pending) { return pending.tfrag == upload.tfrag && pending.level == upload.level; }),
        _pendingColorUploads.end());
    _pendingColorUploads.push_back(std::move(upload));
  }
}

- (void)setColorsNow:(const unsigned char*)rgba count:(NSUInteger)count tfrag:(BOOL)tfrag level:(const char*)level {
  if (!rgba || !count) {
    return;
  }
  id<MTLBuffer> buffer = [self.device newBufferWithBytes:rgba
                                                   length:count
                                                  options:MTLResourceStorageModeShared];
  _sceneStagingMeshes[{level ? level : "", bool(tfrag)}].colors = buffer;
}



- (void)setMeshNow:(const void*)vertices
       vertexCount:(NSUInteger)vertexCount
    triangleIndices:(const unsigned int*)indices
         indexCount:(NSUInteger)indexCount
             draws:(const OttselMetalTieDraw*)draws
         drawCount:(NSUInteger)drawCount
            tfrag:(BOOL)tfrag level:(const char*)level {
  if (!vertices || !vertexCount || !indices || !indexCount) {
    return;
  }
  id<MTLBuffer> vertex_buffer = [self.device newBufferWithBytes:vertices
                                                            length:vertexCount * 32
                                                           options:MTLResourceStorageModeShared];
  id<MTLBuffer> index_buffer = [self.device newBufferWithBytes:indices
                                                           length:indexCount * sizeof(unsigned int)
                                                          options:MTLResourceStorageModeShared];
  auto& installed = _sceneStagingMeshes[{level ? level : "", bool(tfrag)}];
  installed.vertices = vertex_buffer;
  installed.indices = index_buffer;
  installed.index_count = indexCount;
  installed.draws.clear();
  if (draws && drawCount) installed.draws.assign(draws, draws + drawCount);
  NSLog(@"ottsel metal: %@ mesh vertices=%lu triangles=%lu", tfrag ? @"TFRAG" : @"TIE",
        (unsigned long)vertexCount, (unsigned long)(indexCount / 3));
}

- (void)drainSceneFrame {
  // Only completed transactions may alter render-visible terrain. The producer
  // can queue its next frame separately; no partial future palette leaks into
  // the last ready frame. Buffer allocations happen once per changed owner.
  std::lock_guard<std::mutex> lock(_tieUploadMutex);
  if (!_completedSceneFrame ||
      !ottsel_mobile_mesh_upload_ready((unsigned int)_pendingTieUploads.size())) return;
  const auto& transaction = *_completedSceneFrame;
  _sceneStagingMeshes.clear();
  const auto prepare = [&](const auto& upload) {
    const SceneKey key{upload.level, upload.tfrag};
    if (_sceneStagingMeshes.find(key) == _sceneStagingMeshes.end()) {
      const auto old = _sceneMeshes.find(key);
      _sceneStagingMeshes.emplace(key, old == _sceneMeshes.end() ? InstalledSceneMesh{} : old->second);
    }
  };
  for (const auto& upload : transaction.meshes) {
    prepare(upload);
    [self setMeshNow:upload.vertices.data()
         vertexCount:upload.vertices.size() / 32
      triangleIndices:upload.indices.data()
           indexCount:upload.indices.size()
               draws:upload.draws.data()
           drawCount:upload.draws.size()
              tfrag:upload.tfrag level:upload.level.c_str()];
  }
  for (const auto& upload : transaction.colors) {
    prepare(upload);
    [self setColorsNow:upload.rgba.data() count:upload.rgba.size()
                tfrag:upload.tfrag level:upload.level.c_str()];
  }
  const auto ready = [](const InstalledSceneMesh& mesh) {
    return mesh.vertices && mesh.indices && mesh.colors && mesh.index_count;
  };
  // Failure retains the previous frame and the complete pending transaction.
  // Never advance its refs to resources from an earlier palette generation.
  for (const auto& entry : _sceneStagingMeshes) {
    if (!ready(entry.second)) { _sceneStagingMeshes.clear(); return; }
  }
  for (const auto& ref : transaction.refs) {
    const auto changed = _sceneStagingMeshes.find(ref.key);
    const auto old = _sceneMeshes.find(ref.key);
    if (changed == _sceneStagingMeshes.end() &&
        (old == _sceneMeshes.end() || !ready(old->second))) {
      _sceneStagingMeshes.clear(); return;
    }
  }
  for (auto& entry : _sceneStagingMeshes) _sceneMeshes[entry.first] = std::move(entry.second);
  _sceneStagingMeshes.clear();
  _activeSceneFrame = std::move(_completedSceneFrame->refs);
  _completedSceneFrame.reset();
}

- (void)drainMercUploads {
  std::unique_ptr<MercFrameTransaction> frame;
  {
    std::lock_guard<std::mutex> lock(_mercMutex);
    frame = std::move(_completedMercFrame);
  }
  if (frame && (frame->vertices.size() % 32 || frame->actor_vertices.size() % 32 ||
                frame->colors.size() != frame->vertices.size() / 32 * 16 ||
                frame->actor_colors.size() != frame->actor_vertices.size() / 32 * 16)) {
    NSLog(@"ottsel metal: rejected MERC frame with misaligned lighting stream");
    return;
  }
  if (!frame) return;  // No completed replacement: retain geometry AND camera.
  auto& vertices = frame->vertices;
  auto& indices = frame->indices;
  auto& draws = frame->draws;
  auto& colors = frame->colors;
  auto& actor_vertices = frame->actor_vertices;
  auto& actor_indices = frame->actor_indices;
  auto& actor_draws = frame->actor_draws;
  auto& actor_colors = frame->actor_colors;
  const bool has_actor = !actor_vertices.empty() && !actor_indices.empty() && !actor_draws.empty();
  const bool has_general = !vertices.empty() && !indices.empty() && !draws.empty();
  id<MTLBuffer> actor_v = nil, actor_i = nil, actor_c = nil;
  id<MTLBuffer> general_v = nil, general_i = nil, general_c = nil;
  if (has_actor) {
    actor_v = [self.device newBufferWithBytes:actor_vertices.data() length:actor_vertices.size() options:MTLResourceStorageModeShared];
    actor_i = [self.device newBufferWithBytes:actor_indices.data() length:actor_indices.size() * sizeof(unsigned int) options:MTLResourceStorageModeShared];
    actor_c = [self.device newBufferWithBytes:actor_colors.data() length:actor_colors.size() options:MTLResourceStorageModeShared];
    if (!actor_v || !actor_i || !actor_c) return;
  }
  if (has_general) {
    general_v = [self.device newBufferWithBytes:vertices.data() length:vertices.size() options:MTLResourceStorageModeShared];
    general_i = [self.device newBufferWithBytes:indices.data() length:indices.size() * sizeof(unsigned int) options:MTLResourceStorageModeShared];
    general_c = [self.device newBufferWithBytes:colors.data() length:colors.size() options:MTLResourceStorageModeShared];
    if (!general_v || !general_i || !general_c) return;
  }
  // Commit both channels and their camera only after every required allocation.
  // Empty completed channels deliberately replace previous resources with nil.
  _mercFrameUniforms = frame->uniforms;
  _mercActorVertices = actor_v; _mercActorIndices = actor_i; _mercActorColors = actor_c;
  _mercActorIndexCount = has_actor ? actor_indices.size() : 0;
  _mercActorDraws = has_actor ? std::move(actor_draws) : std::vector<OttselMetalTieDraw>{};
  self.mercVertices = general_v; self.mercIndices = general_i; self.mercColors = general_c;
  self.mercIndexCount = has_general ? indices.size() : 0;
  _mercDraws = has_general ? std::move(draws) : std::vector<OttselMetalTieDraw>{};
}

- (void)setTfragMesh:(const void*)vertices
         vertexCount:(NSUInteger)vertexCount
      triangleIndices:(const unsigned int*)indices
           indexCount:(NSUInteger)indexCount
               draws:(const OttselMetalTieDraw*)draws
           drawCount:(NSUInteger)drawCount level:(const char*)level {
  if (!vertices || !vertexCount || !indices || !indexCount) {
    return;
  }
  PendingMeshUpload upload;
  upload.level = level ? level : "";
  upload.vertices.assign((const unsigned char*)vertices,
                         (const unsigned char*)vertices + vertexCount * 32);
  upload.indices.assign(indices, indices + indexCount);
  upload.tfrag = true;
  if (draws && drawCount) {
    upload.draws.assign(draws, draws + drawCount);
  }
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    _pendingMeshUploads.erase(
        std::remove_if(_pendingMeshUploads.begin(), _pendingMeshUploads.end(),
                       [&](const PendingMeshUpload& pending) { return pending.tfrag == upload.tfrag && pending.level == upload.level; }),
        _pendingMeshUploads.end());
    _pendingMeshUploads.push_back(std::move(upload));
  }
}

- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count level:(const char*)level {
  if (!rgba || !count) {
    return;
  }
  PendingColorUpload upload;
  upload.level = level ? level : "";
  upload.rgba.assign(rgba, rgba + count * 4);
  upload.tfrag = true;
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    _pendingColorUploads.erase(
        std::remove_if(_pendingColorUploads.begin(), _pendingColorUploads.end(),
                       [&](const PendingColorUpload& pending) { return pending.tfrag == upload.tfrag && pending.level == upload.level; }),
        _pendingColorUploads.end());
    _pendingColorUploads.push_back(std::move(upload));
  }
}

- (void)appendMercMesh:(const void*)vertices
          vertexCount:(NSUInteger)vertexCount
            litRGBA:(const float*)litRGBA
       triangleIndices:(const unsigned int*)indices
            indexCount:(NSUInteger)indexCount
                 draws:(const OttselMetalTieDraw*)draws
             drawCount:(NSUInteger)drawCount {
  if (!vertices || !vertexCount || !litRGBA || !indices || !indexCount || !draws || !drawCount) {
    return;
  }
  std::lock_guard<std::mutex> lock(_mercMutex);
  const unsigned int vertex_base = _pendingMercVertices.size() / 32;
  const unsigned int index_base = _pendingMercIndices.size();
  _pendingMercVertices.insert(_pendingMercVertices.end(), (const unsigned char*)vertices,
                              (const unsigned char*)vertices + vertexCount * 32);
  for (NSUInteger i = 0; i < indexCount; ++i) {
    _pendingMercIndices.push_back(indices[i] + vertex_base);
  }
  for (NSUInteger i = 0; i < drawCount; ++i) {
    auto draw = draws[i];
    draw.index_offset += index_base;
    _pendingMercDraws.push_back(draw);
  }
  _pendingMercColors.insert(_pendingMercColors.end(), (const unsigned char*)litRGBA,
                            (const unsigned char*)litRGBA + vertexCount * 16);
}

- (void)setMercActorMesh:(const void*)vertices
            vertexCount:(NSUInteger)vertexCount
            litRGBA:(const float*)litRGBA
         triangleIndices:(const unsigned int*)indices
              indexCount:(NSUInteger)indexCount
                  draws:(const OttselMetalTieDraw*)draws
              drawCount:(NSUInteger)drawCount {
  if (!vertices || !vertexCount || !litRGBA || !indices || !indexCount || !draws || !drawCount) {
    return;
  }
  std::lock_guard<std::mutex> lock(_mercMutex);
  _pendingMercActorVertices.assign((const unsigned char*)vertices,
                                   (const unsigned char*)vertices + vertexCount * 32);
  _pendingMercActorIndices.assign(indices, indices + indexCount);
  _pendingMercActorDraws.assign(draws, draws + drawCount);
  _pendingMercActorColors.assign((const unsigned char*)litRGBA,
                                 (const unsigned char*)litRGBA + vertexCount * 16);
}

- (void)setSpriteMesh:(const OttselMetalSpriteVertex*)vertices
                 rgba:(const unsigned char*)rgba
                width:(NSUInteger)width
                height:(NSUInteger)height
                blended:(BOOL)blended {
  if (!vertices || !rgba || !width || !height || !self.device || !self.spritePipeline) {
    return;
  }
  PendingSpriteUpload upload;
  upload.vertices.assign(vertices, vertices + 6);
  upload.vertex_count = 6;
  upload.rgba.assign(rgba, rgba + width * height * 4);
  upload.width = width;
  upload.height = height;
  upload.blended = blended;
  {
    std::lock_guard<std::mutex> lock(_spriteUploadMutex);
    _pendingSpriteUploads.push_back(std::move(upload));
  }
}

- (void)setSpriteMeshNow:(const OttselMetalSpriteVertex*)vertices
              vertexCount:(NSUInteger)vertexCount
                    rgba:(const unsigned char*)rgba
                   width:(NSUInteger)width
                  height:(NSUInteger)height
                 blended:(BOOL)blended {
  [self clearSpriteBatches];
  [self appendSpriteMeshNow:vertices
                 vertexCount:vertexCount
                        rgba:rgba
                       width:width
                      height:height
                     blended:blended];
  _spriteBatches.mutate_last([](NativeSpriteBatch& batch) { batch.persistent = true; });
}

- (void)appendSpriteMeshNow:(const OttselMetalSpriteVertex*)vertices
                vertexCount:(NSUInteger)vertexCount
                       rgba:(const unsigned char*)rgba
                      width:(NSUInteger)width
                     height:(NSUInteger)height
                    blended:(BOOL)blended {
  if (!vertices || !vertexCount || !rgba || !width || !height || !self.device ||
      !self.spritePipeline) {
    return;
  }
  MTLTextureDescriptor* desc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:width
                                  height:height
                               mipmapped:NO];
  desc.usage = MTLTextureUsageShaderRead;
  id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
  if (!texture) {
    return;
  }
  [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
             mipmapLevel:0
               withBytes:rgba
             bytesPerRow:width * 4];
  id<MTLBuffer> vertex_buffer = [self.device
      newBufferWithBytes:vertices
                   length:vertexCount * sizeof(OttselMetalSpriteVertex)
                  options:MTLResourceStorageModeShared];
  if (!vertex_buffer) {
    return;
  }
  _spriteBatches.append({vertex_buffer, texture, vertexCount, blended, 0, false});
  self.spriteTex = texture;
  self.spriteVertices = vertex_buffer;
  self.spriteVertexCount = vertexCount;
  self.spriteBlendEnabled = blended;
  self.spriteActive = YES;
  static std::atomic<bool> sprite_ready_written = false;
  if (self.spriteActive && !sprite_ready_written.exchange(true)) {
    const std::string ready_path = ottsel_ios_writable_dir() +
                                    "ottsel-native-sprite-ready";
    if (FILE* ready = fopen(ready_path.c_str(), "wb")) {
      fprintf(ready, "texture=%lux%lu\n", (unsigned long)width, (unsigned long)height);
      fclose(ready);
    }
  }
  float min_x = vertices[0].pos[0], max_x = vertices[0].pos[0];
  float min_y = vertices[0].pos[1], max_y = vertices[0].pos[1];
  for (NSUInteger i = 1; i < vertexCount; ++i) {
    min_x = std::min(min_x, vertices[i].pos[0]);
    max_x = std::max(max_x, vertices[i].pos[0]);
    min_y = std::min(min_y, vertices[i].pos[1]);
    max_y = std::max(max_y, vertices[i].pos[1]);
  }
  static unsigned int sprite_bounds_logs = 0;
  if (ottsel_mobile_log_within_budget(sprite_bounds_logs, 8)) {
    ++sprite_bounds_logs;
    NSLog(@"ottsel metal: Sprite3 native bounds=%.3f..%.3f,%.3f..%.3f vertices=%lu texture=%lux%lu",
          min_x, max_x, min_y, max_y, (unsigned long)vertexCount, (unsigned long)width,
          (unsigned long)height);
  }
}

- (id<MTLDepthStencilState>)depthStateForDirectBatch:(const NativeSpriteBatch&)batch {
  if (self.sceneNoDepthProbe || !batch.has_gs_depth) {
    return self.overlayDepthState;
  }
  const auto policy = ottsel_mobile_direct_depth_policy(batch.depth.test, batch.depth.zbuf);
  if (!policy.supported) {
    static std::atomic<unsigned int> unsupported_logs{0};
    if (unsupported_logs.fetch_add(1) < 8) {
      NSLog(@"ottsel metal: Direct depth unsupported TEST=0x%llx ZBUF=0x%llx; legacy overlay policy",
            batch.depth.test, batch.depth.zbuf);
    }
    return self.overlayDepthState;
  }
  return policy.write ? self.tieDepthStates[policy.compare]
                      : self.tieNoWriteDepthStates[policy.compare];
}

- (NSUInteger)spriteStoreSize {
  return _spriteBatches.snapshot().size();
}

- (void)clearSpriteBatches {
  // BOT49 probe: this is the only path that drops accumulated sprite groups.
  // A non-zero discard here means a single-mesh upload wiped groups a producer
  // (for example the HUD atlas) had already appended for this frame.
  static unsigned int ottsel_sprite_clear_logs = 0;
  const std::vector<NativeSpriteBatch> ottsel_sprite_clear_discarded = _spriteBatches.snapshot();
  if (!ottsel_sprite_clear_discarded.empty() &&
      ottsel_mobile_log_within_budget(ottsel_sprite_clear_logs, 400)) {
    ++ottsel_sprite_clear_logs;
    unsigned long ottsel_sprite_clear_atlas = 0;
    for (const NativeSpriteBatch& batch : ottsel_sprite_clear_discarded) {
      if (batch.texture && batch.texture.width == 512 && batch.texture.height == 512) {
        ++ottsel_sprite_clear_atlas;
      }
    }
    lg::info("OTTSEL SPRITE CLEAR: discarded={} hud_atlas={}",
             (unsigned long)ottsel_sprite_clear_discarded.size(), ottsel_sprite_clear_atlas);
  }
  _spriteBatches.clear();
  self.spriteVertices = nil;
  self.spriteTex = nil;
  self.spriteVertexCount = 0;
  self.spriteActive = NO;
}

- (void)clearTransientSpriteBatches {
  _spriteBatches.erase_if(
      [](const NativeSpriteBatch& batch) { return !batch.persistent; });
  _skyFrameStore.clear();
  _directFrameStore.clear();
}

- (void)drainSpriteUploads {
  constexpr unsigned int kUploadBudgetPerFrame = 1;
  for (unsigned int i = 0; i < kUploadBudgetPerFrame; ++i) {
    PendingSpriteUpload upload;
    {
      std::lock_guard<std::mutex> lock(_spriteUploadMutex);
      if (_pendingSpriteUploads.empty()) {
        return;
      }
      upload = std::move(_pendingSpriteUploads.front());
      _pendingSpriteUploads.pop_front();
    }
    [self setSpriteMeshNow:upload.vertices.data()
                vertexCount:upload.vertex_count
                       rgba:upload.rgba.data()
                      width:upload.width
                     height:upload.height
                    blended:upload.blended];
  }
}

- (void)setTouchOverlay:(const OttselMetalOverlayVertex*)vertices
                  count:(NSUInteger)count {
  if (!vertices || count == 0 || !self.device || !self.directBlendPipeline) {
    self.touchOverlayVertices = nil;
    self.touchOverlayTex = nil;
    self.touchOverlayVertexCount = 0;
    return;
  }
  if (!self.touchOverlayTex) {
    MTLTextureDescriptor* desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                     width:1
                                    height:1
                                 mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    self.touchOverlayTex = [self.device newTextureWithDescriptor:desc];
    const unsigned char white[4] = {255, 255, 255, 255};
    [self.touchOverlayTex replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                            mipmapLevel:0
                              withBytes:white
                            bytesPerRow:4];
  }
  self.touchOverlayVertices = [self.device newBufferWithBytes:vertices
                                                         length:count * sizeof(OttselMetalOverlayVertex)
                                                        options:MTLResourceStorageModeShared];
  self.touchOverlayVertexCount = self.touchOverlayVertices ? count : 0;
}

- (void)setStatusOverlay:(const unsigned char*)rgba
                   width:(NSUInteger)width
                  height:(NSUInteger)height {
  if (!rgba || !width || !height || !self.device || !self.directPipeline) {
    self.statusOverlayTex = nil;
    self.statusOverlayVertices = nil;
    self.statusOverlayVertexCount = 0;
    return;
  }
  MTLTextureDescriptor* desc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:width
                                  height:height
                               mipmapped:NO];
  desc.usage = MTLTextureUsageShaderRead;
  id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
  if (!texture) {
    return;
  }
  [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
             mipmapLevel:0
               withBytes:rgba
             bytesPerRow:width * 4];
  // direct_fs doubles rgb and alpha, so a half-intensity vertex colour makes the
  // pass reproduce the uploaded surface 1:1.  v=0 is the image top row.
  const OttselMetalSpriteVertex quad[6] = {
      {{-1.f, -1.f}, {0.f, 1.f}, {0.5f, 0.5f, 0.5f, 0.5f}},
      {{+1.f, -1.f}, {1.f, 1.f}, {0.5f, 0.5f, 0.5f, 0.5f}},
      {{+1.f, +1.f}, {1.f, 0.f}, {0.5f, 0.5f, 0.5f, 0.5f}},
      {{-1.f, -1.f}, {0.f, 1.f}, {0.5f, 0.5f, 0.5f, 0.5f}},
      {{+1.f, +1.f}, {1.f, 0.f}, {0.5f, 0.5f, 0.5f, 0.5f}},
      {{-1.f, +1.f}, {0.f, 0.f}, {0.5f, 0.5f, 0.5f, 0.5f}},
  };
  self.statusOverlayVertices = [self.device newBufferWithBytes:quad
                                                        length:sizeof(quad)
                                                       options:MTLResourceStorageModeShared];
  self.statusOverlayTex = texture;
  self.statusOverlayVertexCount = self.statusOverlayVertices ? 6 : 0;
  lg::info("OTTSEL STATUS OVERLAY: set {}x{} vertices={}", (unsigned long)width,
           (unsigned long)height, (unsigned long)self.statusOverlayVertexCount);
}

- (void)setDirectFixture:(const unsigned char*)rgba
                   width:(NSUInteger)width
                   height:(NSUInteger)height
              textureKey:(unsigned long long)textureKey
                       x:(float)x
                       y:(float)y
                       w:(float)w
                       h:(float)h
                      u0:(float)u0
                      v0:(float)v0
                      u1:(float)u1
                      v1:(float)v1
                    color:(const float*)color {
  if (!rgba || !width || !height || !self.directPipeline) {
    return;
  }
  [self uploadDirectTextureNow:rgba width:width height:height textureKey:textureKey];
  self.directTex = self.directTextures[@(textureKey)];
  const float left = x * 2.f - 1.f;
  const float right = (x + w) * 2.f - 1.f;
  const float top = 1.f - y * 2.f;
  const float bottom = 1.f - (y + h) * 2.f;
  const float default_color[4] = {1.f, 1.f, 1.f, 1.f};
  const float* vertex_color = color ? color : default_color;
  const DirectFixtureVertex vertices[6] = {
      {{left, bottom}, {u0, v1}, {vertex_color[0], vertex_color[1], vertex_color[2], vertex_color[3]}},
      {{right, bottom}, {u1, v1}, {vertex_color[0], vertex_color[1], vertex_color[2], vertex_color[3]}},
      {{right, top}, {u1, v0}, {vertex_color[0], vertex_color[1], vertex_color[2], vertex_color[3]}},
      {{left, bottom}, {u0, v1}, {vertex_color[0], vertex_color[1], vertex_color[2], vertex_color[3]}},
      {{right, top}, {u1, v0}, {vertex_color[0], vertex_color[1], vertex_color[2], vertex_color[3]}},
      {{left, top}, {u0, v0}, {vertex_color[0], vertex_color[1], vertex_color[2], vertex_color[3]}},
  };
  self.directVertices = [self.device newBufferWithBytes:vertices
                                                    length:sizeof(vertices)
                                                   options:MTLResourceStorageModeShared];
  self.directFixtureActive = self.directVertices != nil && self.directTex != nil;
  if (!self.directTextures) {
    self.directTextures = [[NSMutableDictionary alloc] init];
  }
  if (self.directTex) {
    self.directTextures[@(textureKey)] = self.directTex;
  }
  NSLog(@"ottsel metal: Direct fixture active=%d texture=%lux%lu rect=%.3f,%.3f %.3fx%.3f",
        self.directFixtureActive, (unsigned long)width, (unsigned long)height, x, y, w, h);
}

- (void)uploadDirectTextureNow:(const unsigned char*)rgba
                         width:(NSUInteger)width
                        height:(NSUInteger)height
                   textureKey:(unsigned long long)textureKey {
  if (!rgba || !width || !height || !self.device) {
    return;
  }
  if (!self.directTextures) {
    self.directTextures = [[NSMutableDictionary alloc] init];
  }
  MTLTextureDescriptor* desc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:width
                                  height:height
                               mipmapped:NO];
  desc.usage = MTLTextureUsageShaderRead;
  id<MTLTexture> texture = [self.device newTextureWithDescriptor:desc];
  if (!texture) {
    return;
  }
  [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
             mipmapLevel:0
               withBytes:rgba
             bytesPerRow:width * 4];
  self.directTextures[@(textureKey)] = texture;
  NSLog(@"ottsel metal: Direct texture upload key=0x%llx size=%lux%lu",
        textureKey, (unsigned long)width, (unsigned long)height);
}

- (void)uploadDirectTexture:(const unsigned char*)rgba
                      width:(NSUInteger)width
                     height:(NSUInteger)height
                textureKey:(unsigned long long)textureKey {
  if (!rgba || !width || !height || !self.device) {
    return;
  }
  PendingDirectUpload upload;
  upload.rgba.assign(rgba, rgba + width * height * 4);
  upload.width = width;
  upload.height = height;
  upload.texture_key = textureKey;
  {
    std::lock_guard<std::mutex> lock(_directUploadMutex);
    if (!_queuedDirectUploadKeys.insert(textureKey).second) {
      return;
    }
    _pendingDirectUploads.push_back(std::move(upload));
  }
}

- (void)drainDirectTextureUploads {
  constexpr unsigned int kUploadBudgetPerFrame = 8;
  for (unsigned int i = 0; i < kUploadBudgetPerFrame; ++i) {
    PendingDirectUpload upload;
    {
      std::lock_guard<std::mutex> lock(_directUploadMutex);
      if (_pendingDirectUploads.empty()) {
        return;
      }
      upload = std::move(_pendingDirectUploads.front());
      _pendingDirectUploads.pop_front();
    }
    [self uploadDirectTextureNow:upload.rgba.data()
                            width:upload.width
                           height:upload.height
                      textureKey:upload.texture_key];
  }
}

- (void)clearDirectFixture {
  self.directFixtureActive = NO;
  self.directFixtureIsolated = NO;
  self.directFixtureNoDepth = NO;
  self.directFixtureColorOnly = NO;
  self.directFixtureOffscreen = NO;
  self.directOffscreenTarget = nil;
  self.directTex = nil;
  self.directVertices = nil;
  self.directTextures = nil;
}

- (void)setDirectFixtureState:(unsigned long long)prim
                          tex0:(unsigned long long)tex0
                          tex1:(unsigned long long)tex1
                         clamp:(unsigned long long)clamp
                         frame:(unsigned long long)frame
                         alpha:(unsigned long long)alpha
                         test:(unsigned long long)test
                         zbuf:(unsigned long long)zbuf
                          texa:(unsigned long long)texa
                    scissorX0:(unsigned int)x0
                    scissorX1:(unsigned int)x1
                    scissorY0:(unsigned int)y0
                    scissorY1:(unsigned int)y1 {
  self.directPrim = prim;
  self.directTex0 = tex0;
  self.directFrame = frame;
  self.directBlendEnabled = (prim & (1ull << 6)) != 0;
  const bool linear = tex1 & (1ull << 5);
  const bool clamp_s = clamp & 1;
  const bool clamp_t = clamp & 4;
  MTLSamplerDescriptor* samplerDesc = [[MTLSamplerDescriptor alloc] init];
  samplerDesc.minFilter = linear ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
  samplerDesc.magFilter = linear ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
  samplerDesc.sAddressMode = clamp_s ? MTLSamplerAddressModeClampToEdge : MTLSamplerAddressModeRepeat;
  samplerDesc.tAddressMode = clamp_t ? MTLSamplerAddressModeClampToEdge : MTLSamplerAddressModeRepeat;
  self.directSampler = [self.device newSamplerStateWithDescriptor:samplerDesc];
  self.directAlpha = alpha;
  self.directTest = test;
  self.directZbuf = zbuf;
  self.directAlphaTestEnable = (unsigned int)(test & 1);
  self.directAlphaTest = (unsigned int)((test >> 1) & 7);
  self.directAlphaRef = (unsigned int)((test >> 4) & 0xff);
  self.directTcc = (unsigned int)((tex0 >> 34) & 1);
  self.directTfx = (unsigned int)((tex0 >> 35) & 3);
  self.directDrawCount = 0;
  self.directTriangleCount = 0;
  self.directScissorX0 = x0;
  self.directScissorX1 = x1;
  self.directScissorY0 = y0;
  self.directScissorY1 = y1;
  id<MTLTexture> selected = self.directTextures[@(tex0)];
  if (!selected) {
    const unsigned long long tbp = tex0 & 0x3fffull;
    const unsigned long long psm = (tex0 >> 20) & 0x3full;
    selected = self.directTextures[@((tbp << 8) | psm)];
  }
  const BOOL hit = selected != nil;
  if (hit) {
    self.directTex = selected;
  }
  self.directFixtureActive = self.directVertices != nil && self.directTex != nil && hit;
  NSLog(@"ottsel metal: Direct IR state prim=0x%llx tex0=0x%llx tex1=0x%llx "
        "clamp=0x%llx frame=0x%llx alpha=0x%llx test=0x%llx zbuf=0x%llx texa=0x%llx "
        "tcc=%u tfx=%u sampler=%s/%s texture-lookup=%s blend=%s alpha-test=%s/%u/%u "
        "scissor=%u..%u,%u..%u",
        prim, tex0, tex1, clamp, frame, alpha, test, zbuf, texa,
        self.directTcc, self.directTfx,
        linear ? "linear" : "nearest", (clamp_s || clamp_t) ? "clamp" : "repeat",
        hit ? "hit" : "miss", self.directBlendEnabled ? "enabled" : "disabled",
        self.directAlphaTestEnable ? "enabled" : "disabled",
        self.directAlphaTest, self.directAlphaRef, x0, x1, y0, y1);
}

@end

// P1 (2026-09-22): the shell's device class, asked of the platform.  A phone and a tablet want different
// touch layouts and different default region sizes, and the CAMetalLayer's drawable is a poor key for that
// (it is only known after layout and a device reports points x contentsScale).
bool ottsel_ios_shell_is_phone() {
#if TARGET_OS_IOS
  return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
#else
  return false;
#endif
}

// P1 (2026-09-22): the key window's safe-area insets as fractions of its own bounds, so the shell can keep
// its default touch regions out of the sensor housing and the home indicator without knowing the display
// scale.  Called from the shell's main thread.
int ottsel_ios_shell_safe_area(float* left, float* top, float* right, float* bottom) {
#if TARGET_OS_IOS
  __block UIEdgeInsets insets = UIEdgeInsetsZero;
  __block CGSize bounds = CGSizeZero;
  @autoreleasepool {
    UIWindow* key = nil;
    for (UIScene* scene in [UIApplication sharedApplication].connectedScenes) {
      if (![scene isKindOfClass:[UIWindowScene class]]) {
        continue;
      }
      for (UIWindow* window in ((UIWindowScene*)scene).windows) {
        if (window.isKeyWindow) {
          key = window;
          break;
        }
      }
      if (key) {
        break;
      }
    }
    if (!key) {
      return 0;
    }
    insets = key.safeAreaInsets;
    bounds = key.bounds.size;
  }
  if (bounds.width <= 0 || bounds.height <= 0) {
    return 0;
  }
  if (left) *left = (float)(insets.left / bounds.width);
  if (top) *top = (float)(insets.top / bounds.height);
  if (right) *right = (float)(insets.right / bounds.width);
  if (bottom) *bottom = (float)(insets.bottom / bounds.height);
  return 1;
#else
  (void)left; (void)top; (void)right; (void)bottom;
  return 0;
#endif
}

int ottsel_metal_drawable_size(OttselMetal* m, int* w, int* h) {
  if (!m || !w || !h) {
    return 0;
  }
  __block CGSize size = CGSizeZero;
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    if (!r.layer) {
      return 0;
    }
    size = r.layer.drawableSize;
  }
  if (size.width <= 0 || size.height <= 0) {
    return 0;
  }
  *w = (int)size.width;
  *h = (int)size.height;
  return 1;
}

OttselMetal* ottsel_metal_create(void* sdl_window) {
  @autoreleasepool {
    OttselMetalRenderer* r = [[OttselMetalRenderer alloc] init];
    if (![r setupWithWindow:(SDL_Window*)sdl_window width:1024 height:768]) {
      return nullptr;
    }
    return (__bridge_retained OttselMetal*)r;
  }
}

void ottsel_metal_present(OttselMetal* m,
                          const unsigned char* rgba,
                          int w,
                          int h) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r presentRGBA:rgba width:w height:h];
  }
}

void ottsel_metal_destroy(OttselMetal* m) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge_transfer OttselMetalRenderer*)m;
    r = nil;
  }
}

void ottsel_metal_set_tie_mesh(OttselMetal* m, const char* level,
                               const void* vertices,
                               unsigned int vertex_count,
                               const unsigned int* triangle_indices,
                               unsigned int index_count,
                               const OttselMetalTieDraw* draws,
                               unsigned int draw_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTieMesh:vertices
       vertexCount:vertex_count
    triangleIndices:triangle_indices
         indexCount:index_count
             draws:draws
         drawCount:draw_count level:level];
  }
}

void ottsel_metal_set_tie_texture(OttselMetal* m,
                                  unsigned int texture_index,
                                  const unsigned int* rgba,
                                  unsigned int width,
                                  unsigned int height) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTieTextureAtIndex:texture_index rgba:rgba width:width height:height];
  }
}

void ottsel_metal_set_tie_colors(OttselMetal* m, const char* level,
                                 const unsigned char* rgba,
                                 unsigned int color_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTieColors:rgba count:color_count level:level];
  }
}

void ottsel_metal_set_tie_camera(OttselMetal* m,
                                 const float pc_camera[16],
                                 const float merc_perspective[16],
                                 const float camera_trans[4],
                                 const float fog_params[4],
                                 const float fog_color[4],
                                 const float hvdf_offset[4],
                                 float fog_constant) {
  static int camera_wrapper_trace_count = 0;
  const bool trace_camera = camera_wrapper_trace_count++ < 8;
  if (trace_camera) {
    lg::info("OTTSEL CAMERA WRAPPER: enter m-nonnull=1");
  }
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTieCamera:pc_camera
         mercPerspective:merc_perspective
         cameraTrans:camera_trans
          fogParams:fog_params
           fogColor:fog_color
       hvdfOffset:hvdf_offset
       fogConstant:fog_constant];
    if (trace_camera) {
      lg::info("OTTSEL CAMERA WRAPPER: exit");
    }
}
}

void ottsel_metal_set_tfrag_mesh(OttselMetal* m, const char* level,
                                 const void* vertices,
                                 unsigned int vertex_count,
                                 const unsigned int* triangle_indices,
                                 unsigned int index_count,
                                 const OttselMetalTieDraw* draws,
                                 unsigned int draw_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTfragMesh:vertices
        vertexCount:vertex_count
     triangleIndices:triangle_indices
          indexCount:index_count
              draws:draws
          drawCount:draw_count level:level];
  }
}

void ottsel_metal_set_tfrag_colors(OttselMetal* m, const char* level,
                                   const unsigned char* rgba,
                                   unsigned int color_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTfragColors:rgba count:color_count level:level];
  }
}

void ottsel_metal_append_merc_mesh(OttselMetal* m,
                                   const void* vertices,
                                   unsigned int vertex_count,
                                   const float* lit_rgba,
                                   const unsigned int* triangle_indices,
                                   unsigned int index_count,
                                   const OttselMetalTieDraw* draws,
                                   unsigned int draw_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r appendMercMesh:vertices
          vertexCount:vertex_count
             litRGBA:lit_rgba
       triangleIndices:triangle_indices
            indexCount:index_count
             draws:draws
         drawCount:draw_count];
  }
}

void ottsel_metal_set_merc_actor_mesh(OttselMetal* m,
                                      const void* vertices,
                                      unsigned int vertex_count,
                                   const float* lit_rgba,
                                      const unsigned int* triangle_indices,
                                      unsigned int index_count,
                                      const OttselMetalTieDraw* draws,
                                      unsigned int draw_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setMercActorMesh:vertices
            vertexCount:vertex_count
             litRGBA:lit_rgba
         triangleIndices:triangle_indices
              indexCount:index_count
                  draws:draws
              drawCount:draw_count];
  }
}

void ottsel_metal_set_sprite_mesh(OttselMetal* m,
                                  const OttselMetalSpriteVertex vertices[6],
                                  const unsigned char* rgba,
                                  unsigned int width,
                                  unsigned int height,
                                  int blended) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setSpriteMesh:vertices
                rgba:rgba
               width:width
              height:height
             blended:blended != 0];
  }
}

void ottsel_metal_set_sprite_mesh_n(OttselMetal* m,
                                    const OttselMetalSpriteVertex* vertices,
                                    unsigned int vertex_count,
                                    const unsigned char* rgba,
                                    unsigned int width,
                                    unsigned int height,
                                    int blended) {
  if (!m || !vertices || vertex_count == 0) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setSpriteMeshNow:vertices
            vertexCount:vertex_count
                   rgba:rgba
                  width:width
                 height:height
                blended:blended != 0];
  }
}

void ottsel_metal_append_sprite_mesh_n(OttselMetal* m,
                                       const OttselMetalSpriteVertex* vertices,
                                       unsigned int vertex_count,
                                       const unsigned char* rgba,
                                       unsigned int width,
                                       unsigned int height,
                                       int blended) {
  if (!m || !vertices || vertex_count == 0) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r appendSpriteMeshNow:vertices
                vertexCount:vertex_count
                       rgba:rgba
                      width:width
                     height:height
                    blended:blended != 0];
  }
}

unsigned int ottsel_metal_sprite_store_size(OttselMetal* m) {
  if (!m) {
    return 0;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    return (unsigned int)r.spriteStoreSize;
  }
}

void ottsel_metal_begin_sky_bucket(OttselMetal* m) {
  if (m) [(__bridge OttselMetalRenderer*)m beginSkyBucket];
}
void ottsel_metal_arm_blend_ledger(OttselMetal* m) {
  if (m) [(__bridge OttselMetalRenderer*)m armBlendLedger];
}
int ottsel_metal_sky_draw_legacy(OttselMetal* m) {
  if (!m) return 0;
  return ((__bridge OttselMetalRenderer*)m).skyDrawLegacy ? 1 : 0;
}
int ottsel_metal_sky_skip_draw(OttselMetal* m) {
  if (!m) return 0;
  return ((__bridge OttselMetalRenderer*)m).skySkipDraw ? 1 : 0;
}
void ottsel_metal_finish_sky_bucket(OttselMetal* m, int complete) {
  if (m) [(__bridge OttselMetalRenderer*)m finishSkyBucket:complete != 0];
}

int ottsel_metal_append_sky_mesh_n(OttselMetal* m,
                                    const OttselMetalSpriteVertex* vertices,
                                    unsigned int vertex_count,
                                    const unsigned char* rgba,
                                    unsigned int width,
                                    unsigned int height,
                                    int blended,
                                    unsigned char ta0,
                                    const OttselMetalDirectDepthState* depth_state,
                                    unsigned long long diagnostic_alpha) {
  if (!m || !vertices || vertex_count == 0) {
    return 0;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    return [r appendSkyMeshNow:vertices
            vertexCount:vertex_count
                  rgba:rgba
                 width:width
                height:height
               blended:blended != 0
                   ta0:ta0
                 depth:depth_state diagnosticAlpha:diagnostic_alpha];
  }
}

void ottsel_metal_append_direct_mesh_n(OttselMetal* m,
                                       const OttselMetalSpriteVertex* vertices,
                                       unsigned int vertex_count,
                                       const unsigned char* rgba,
                                       unsigned int width,
                                       unsigned int height,
                                    int blended,
                                    unsigned char ta0,
                                    const OttselMetalDirectDepthState* depth_state,
                                    unsigned long long diagnostic_alpha) {
  if (!m || !vertices || vertex_count == 0) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = ((__bridge OttselMetalRenderer*)m);
    [r appendDirectMeshNow:vertices
               vertexCount:vertex_count
                     rgba:rgba
                    width:width
                   height:height
                  blended:blended != 0
                      ta0:ta0
                 depth:depth_state diagnosticAlpha:diagnostic_alpha];
  }
}

void ottsel_metal_set_touch_overlay(OttselMetal* m,
                                    const OttselMetalOverlayVertex* vertices,
                                    unsigned int vertex_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTouchOverlay:vertices count:vertex_count];
  }
}

void ottssel_metal_set_status_overlay(OttselMetal* m,
                                      const unsigned char* rgba,
                                      unsigned int width,
                                      unsigned int height) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setStatusOverlay:rgba width:width height:height];
  }
}

void ottssel_metal_set_accessibility_regions(OttselMetal* m,
                                             const OttselAccessibilityRegion* regions,
                                             unsigned int count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r.accessibilityContainer setRegions:regions count:count];
  }
}

void ottssel_metal_log_accessibility(OttselMetal* m) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r.accessibilityContainer logRegions];
  }
}

void ottssel_metal_set_render_scale(OttselMetal* m, unsigned int percent) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    r.renderScalePercent = percent ? percent : 100;
  }
}

void ottsel_metal_set_direct_fixture(OttselMetal* m,
                                     const unsigned char* rgba,
                                     unsigned int width,
                                     unsigned int height,
                                     unsigned long long texture_key,
                                     float x,
                                     float y,
                                     float w,
                                     float h,
                                     float u0,
                                     float v0,
                                     float u1,
                                     float v1,
                                     const float color[4]) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setDirectFixture:rgba
                  width:width
                 height:height
            textureKey:texture_key
                      x:x
                      y:y
                      w:w
                      h:h
                     u0:u0
                     v0:v0
                     u1:u1
                     v1:v1
                   color:color];
  }
}

void ottsel_metal_upload_direct_texture(OttselMetal* m,
                                        const unsigned char* rgba,
                                        unsigned int width,
                                        unsigned int height,
                                        unsigned long long texture_key) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r uploadDirectTexture:rgba width:width height:height textureKey:texture_key];
  }
}

void ottsel_metal_clear_direct_fixture(OttselMetal* m) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r clearDirectFixture];
  }
}

void ottsel_metal_set_direct_fixture_state(OttselMetal* m,
                                           unsigned long long prim,
                                           unsigned long long tex0,
                                           unsigned long long tex1,
                                           unsigned long long clamp,
                                           unsigned long long frame,
                                           unsigned long long alpha,
                                           unsigned long long test,
                                           unsigned long long zbuf,
                                           unsigned long long texa,
                                           unsigned int scissor_x0,
                                           unsigned int scissor_x1,
                                           unsigned int scissor_y0,
                                           unsigned int scissor_y1) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setDirectFixtureState:prim
                         tex0:tex0
                         tex1:tex1
                        clamp:clamp
                        frame:frame
                        alpha:alpha
                         test:test
                         zbuf:zbuf
                         texa:texa
                  scissorX0:scissor_x0
                  scissorX1:scissor_x1
                  scissorY0:scissor_y0
                  scissorY1:scissor_y1];
  }
}

void ottsel_metal_begin_scene_frame(OttselMetal* m) {
  if (m) [(__bridge OttselMetalRenderer*)m beginSceneFrame];
}

void ottsel_metal_publish_scene_frame(OttselMetal* m) {
  if (m) [(__bridge OttselMetalRenderer*)m publishSceneFrame];
}

void ottsel_metal_reference_scene(OttselMetal* m, const char* level, int tfrag) {
  if (m) [(__bridge OttselMetalRenderer*)m referenceScene:level tfrag:tfrag != 0];
}
