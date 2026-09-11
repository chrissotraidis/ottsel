// Ottsel S2.0 — Metal shell surface (Objective-C++ implementation).
//
// Delivers the CPU-rendered log surface through a real Metal pipeline on
// the SDL window's CAMetalLayer: device, command queue, fullscreen
// textured-triangle pipeline, per-frame texture upload, present.

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_metal.h>

#include <vector>
#include <algorithm>
#include <atomic>
#include <deque>
#include <mutex>
#include <unordered_set>
#include <cstdio>
#include <string>

#include "metal_shell.h"
#include "mobile_scene_policy.h"
#include "mobile_snapshot_store.h"
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
"float4 color [[attribute(2)]]; };\n"
"struct DirectOut { float4 position [[position]]; float2 uv; float4 color; };\n"
"struct DirectState { uint alpha_test_enable; uint alpha_test; uint alpha_ref; "
"uint tcc; uint tfx; uint ta0; };\n"
"vertex DirectOut direct_vs(DirectIn in [[stage_in]]) {\n"
"  DirectOut out; out.position = float4(in.pos, 0.0, 1.0); out.uv = in.uv; "
"  out.color = float4(in.color.rgb, in.color.a * 2.0); return out;\n"
"}\n"
"fragment float4 direct_fs(DirectOut in [[stage_in]], texture2d<float> tex [[texture(0)]],\n"
"                           sampler s [[sampler(0)]],\n"
"                           constant DirectState& state [[buffer(1)]]) {\n"
"  float4 texel = tex.sample(s, in.uv);\n"
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
"  return float4(tex.sample(s, in.uv).rgb, 1.0);\n"
"}\n";

NSString* kTieShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct TieIn { float3 position [[attribute(0)]]; float2 uv [[attribute(1)]]; "
"ushort color_index [[attribute(2)]]; };\n"
"struct TieUniforms { float4 pc_camera[4]; float4 merc_perspective[4]; float4 camera_trans; float4 fog_params; "
"float4 fog_color; float4 hvdf_offset; float fog_constant; float camera_sign; uint projection_mode; };\n"
"struct TieMaterial { float alpha_min; float alpha_max; uint fog_enable; uint decal; };\n"
"struct TieOut { float4 position [[position]]; float2 uv; ushort color_index [[flat]]; "
"float fogginess; float3 fog_color; };\n"
"vertex TieOut tie_vs(TieIn in [[stage_in]], constant TieUniforms& u [[buffer(1)]]) {\n"
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
"    transformed += u.merc_perspective[3];\n"
"    original_w = transformed.w;\n"
"    float Q = u.fog_constant / transformed.w;\n"
"    transformed.xyz *= Q;\n"
"    transformed.xyz += u.hvdf_offset.xyz;\n"
"    transformed.xy -= float2(2048.0);\n"
"    transformed.z /= 8388608.0;\n"
"    transformed.z -= 1.0;\n"
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
"  TieOut out; out.position = transformed; out.uv = in.uv; out.color_index = in.color_index; "
"out.fogginess = 255.0 - clamp(-original_w + u.fog_params.x, u.fog_params.y, u.fog_params.z); "
"out.fog_color = u.fog_color.xyz; "
"return out;\n"
"}\n"
"fragment float4 tie_fs(TieOut in [[stage_in]], texture2d<float> tex [[texture(0)]], "
"constant uchar4* colors [[buffer(0)]], constant TieMaterial& material [[buffer(1)]], "
"sampler tex_sampler [[sampler(0)]]) {\n"
"  float4 texel = tex.sample(tex_sampler, in.uv);\n"
"  float4 tod = float4(colors[in.color_index]) / 255.0;\n"
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
};

struct TieMaterial {
  float alpha_min;
  float alpha_max;
  uint32_t fog_enable;
  uint32_t decal;
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
};

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
  std::vector<unsigned char> rgba;
  bool tfrag = false;
};

struct PendingMeshUpload {
  std::vector<unsigned char> vertices;
  std::vector<unsigned int> indices;
  std::vector<OttselMetalTieDraw> draws;
  bool tfrag = false;
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
};

// Metal's Simulator serializer asserts if a render encoder is released while
// still open. Any Objective-C exception from a validation/resource call can
// unwind presentRGBA before its normal endEncoding line, so make the lifetime
// exception-safe as well as normally explicit.
class RenderEncoderEndGuard {
 public:
  explicit RenderEncoderEndGuard(id<MTLRenderCommandEncoder> encoder) : m_encoder(encoder) {}
  RenderEncoderEndGuard(const RenderEncoderEndGuard&) = delete;
  RenderEncoderEndGuard& operator=(const RenderEncoderEndGuard&) = delete;
  ~RenderEncoderEndGuard() {
    end();
  }
  void end() {
    if (m_encoder && !m_ended) {
      [m_encoder endEncoding];
      m_ended = true;
    }
  }

 private:
  id<MTLRenderCommandEncoder> m_encoder;
  bool m_ended = false;
};

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

@interface OttselMetalRenderer : NSObject
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directBlendPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directNoDepthPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directColorOnlyPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> tiePipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> tieBlendPipeline;
@property (nonatomic, strong) id<MTLDepthStencilState> tieNoWriteDepthState;
@property (nonatomic, strong) NSArray* tieDepthStates;
@property (nonatomic, strong) NSArray* tieNoWriteDepthStates;
@property (nonatomic, strong) CAMetalLayer* layer;
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
@property (nonatomic) BOOL directFixtureActive;
@property (nonatomic) BOOL directFixtureIsolated;
@property (nonatomic) BOOL directFixtureNoDepth;
@property (nonatomic) BOOL directFixtureColorOnly;
@property (nonatomic) BOOL directFixtureOffscreen;
@property (nonatomic) BOOL sceneNoDepthProbe;
@property (nonatomic) BOOL sceneSkyOpaqueProbe;
@property (nonatomic) BOOL sceneSkyDebugFillProbe;
@property (nonatomic) BOOL sceneSkyDebugFillAllProbe;
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
@property (nonatomic, strong) id<MTLDepthStencilState> overlayDepthState;
@property (nonatomic) NSUInteger tieIndexCount;
@property (nonatomic) NSUInteger tfragIndexCount;
@property (nonatomic) NSUInteger mercIndexCount;
@property (nonatomic) TieUniforms tieUniforms;
- (BOOL)setupWithWindow:(SDL_Window*)win width:(int)w height:(int)h;
- (void)presentRGBA:(const unsigned char*)rgba width:(int)w height:(int)h;
- (void)setTieMesh:(const void*)vertices
        vertexCount:(NSUInteger)vertexCount
     triangleIndices:(const unsigned int*)indices
          indexCount:(NSUInteger)indexCount
              draws:(const OttselMetalTieDraw*)draws
          drawCount:(NSUInteger)drawCount;
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
- (void)setColorsNow:(const unsigned char*)rgba count:(NSUInteger)count tfrag:(BOOL)tfrag;
- (void)drainColorUploads;
- (void)setMeshNow:(const void*)vertices
       vertexCount:(NSUInteger)vertexCount
    triangleIndices:(const unsigned int*)indices
         indexCount:(NSUInteger)indexCount
             draws:(const OttselMetalTieDraw*)draws
         drawCount:(NSUInteger)drawCount
            tfrag:(BOOL)tfrag;
- (void)drainMeshUploads;
- (void)drainMercUploads;
- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count;
- (void)setTfragMesh:(const void*)vertices
         vertexCount:(NSUInteger)vertexCount
      triangleIndices:(const unsigned int*)indices
           indexCount:(NSUInteger)indexCount
               draws:(const OttselMetalTieDraw*)draws
           drawCount:(NSUInteger)drawCount;
- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count;
- (void)appendMercMesh:(const void*)vertices
          vertexCount:(NSUInteger)vertexCount
       triangleIndices:(const unsigned int*)indices
            indexCount:(NSUInteger)indexCount
                draws:(const OttselMetalTieDraw*)draws
            drawCount:(NSUInteger)drawCount;
- (void)setMercActorMesh:(const void*)vertices
            vertexCount:(NSUInteger)vertexCount
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
- (void)recycleVertexBuffersAfter:(id<MTLCommandBuffer>)cb;
- (void)appendSkyMeshNow:(const OttselMetalSpriteVertex*)vertices
             vertexCount:(NSUInteger)vertexCount
                   rgba:(const unsigned char*)rgba
                  width:(NSUInteger)width
                 height:(NSUInteger)height
                blended:(BOOL)blended
                    ta0:(unsigned char)ta0;
- (void)appendDirectMeshNow:(const OttselMetalSpriteVertex*)vertices
                vertexCount:(NSUInteger)vertexCount
                      rgba:(const unsigned char*)rgba
                     width:(NSUInteger)width
                    height:(NSUInteger)height
                   blended:(BOOL)blended
                       ta0:(unsigned char)ta0;
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
  std::mutex _spriteUploadMutex;
  std::deque<PendingSpriteUpload> _pendingSpriteUploads;
  OttselMobileSnapshotStore<NativeSpriteBatch> _spriteBatches;
  OttselMobileSnapshotStore<NativeSpriteBatch> _skyBatches;
  // Foreground Direct/GIF geometry (title logo, "PRESS START", debug/menu
  // text).  The desktop draws these after the world and after sprites, so they
  // live in their own store with a later draw position rather than in the
  // pre-world sky batch list.
  OttselMobileSnapshotStore<NativeSpriteBatch> _directBatches;
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
  [self drainColorUploads];
  [self drainMeshUploads];
  [self drainMercUploads];
  [self drainSpriteUploads];
  // Keep the CAMetalLayer drawableSize in sync with the actual layer bounds
  // (the simulator's windowed presentation reports the pre-layout 480x320
  // value at creation; SDL also syncs it on layout, this covers late resizes).
  CGSize layer_bounds = self.layer.bounds.size;
  CGFloat layer_scale = self.layer.contentsScale;
  if (layer_bounds.width > 0 && layer_bounds.height > 0) {
    CGSize want = CGSizeMake(layer_bounds.width * layer_scale, layer_bounds.height * layer_scale);
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
  // Recreate the upload texture if the surface size changed (rotation or
  // first frame after the caller adopts the drawable size).
  if (!self.directFixtureActive && (!self.logTex || self.logTex.width != (NSUInteger)w ||
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
  if (!self.directFixtureActive) {
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
  RenderEncoderEndGuard encoder_guard(enc);
  // Camera updates arrive on the game thread. Snapshot the complete block
  // before encoding so no draw can observe a partially copied matrix/fog set.
  TieUniforms draw_uniforms;
  {
    std::lock_guard<std::mutex> lock(_tieUniformMutex);
    draw_uniforms = _tieUniforms;
  }
  if (!self.directFixtureIsolated &&
      ottsel_mobile_cpu_frame_should_draw(self.tfragIndexCount != 0, self.tieIndexCount != 0,
                                          self.sceneNoCpuFrameProbe)) {
    [enc setRenderPipelineState:self.pipeline];
    [enc setFragmentTexture:self.logTex atIndex:0];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  }
  const auto draw_mesh = ^(id<MTLBuffer> vertices, id<MTLBuffer> indices, id<MTLBuffer> colors,
                           NSUInteger index_count,
                           const std::vector<OttselMetalTieDraw>& draws,
                           bool tfrag_mesh,
                           bool merc_mesh) {
    if (!vertices || !indices || !colors || !index_count) {
      return;
    }
    [enc setVertexBuffer:vertices offset:0 atIndex:0];
    TieUniforms mesh_uniforms = draw_uniforms;
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
    [enc setVertexBytes:&mesh_uniforms length:sizeof(mesh_uniforms) atIndex:1];
    [enc setFragmentBuffer:colors offset:0 atIndex:0];
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
      TieMaterial material{alpha_min, 10.f, fog_enable ? 1u : 0u, decal ? 1u : 0u};
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
                                         decal ? 1u : 0u};
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
  const auto sky_batches = _skyBatches.snapshot();
  if (!sky_batches.empty() && !self.directFixtureIsolated && !self.sceneNoSkyProbe) {
    unsigned int sky_state[6] = {0, 0, 0, 1, 0, 0};
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
      // Diagnostic only: forcing replace blending separates "the sky geometry
      // never covers a pixel" from "the sky blends to nothing".
      [enc setRenderPipelineState:(self.sceneSkyOpaqueProbe || !sky.blended)
                                      ? self.directPipeline
                                      : self.directBlendPipeline];
      if (self.sceneSkyDebugFillProbe && self.skyDebugFillPipeline) {
        [enc setRenderPipelineState:self.skyDebugFillPipeline];
      }
      if (self.sceneSkyDebugTexProbe && self.skyDebugTexPipeline) {
        [enc setRenderPipelineState:self.skyDebugTexPipeline];
      }
      [enc setDepthStencilState:self.overlayDepthState];
      [enc setVertexBuffer:sky.vertices offset:0 atIndex:0];
      [enc setFragmentTexture:sky.texture atIndex:0];
      [enc setFragmentSamplerState:self.directSampler atIndex:0];
      [enc setFragmentBytes:sky_state length:sizeof(sky_state) atIndex:1];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:sky.vertex_count];
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
      for (const auto& sky : sky_batches) {
        const NSUInteger tw = sky.texture.width;
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
            "meshHits=%llu meshMisses=%llu",
            (unsigned long)sky_batches.size(), tex1, tex32, tex64, tex_other, alpha_zero,
            alpha_half, amax, _meshTexHits, _meshTexMisses);
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
      draw_mesh(fixture_v, fixture_i, fixture_c, 6, fixture_draws, true, false);
      self.tieTextures[0] = saved_texture ? (id)saved_texture : (id)[NSNull null];
      static bool fixture_logged = false;
      if (!fixture_logged) {
        fixture_logged = true;
        NSLog(@"ottsel metal: TFRAG pipeline fixture submitted clip-quad=(-.75,-.75)..(.75,.75)");
      }
    } else {
      draw_mesh(self.tfragVertices, self.tfragIndices, self.tfragColors, self.tfragIndexCount,
                _tfragDraws, true, false);
    }
  }
  if (!self.directFixtureIsolated && !self.sceneNoTieProbe) {
    draw_mesh(self.tieVertices, self.tieIndices, self.tieColors, self.tieIndexCount, _tieDraws,
              false, false);
  }
  if (!self.directFixtureIsolated && self.mercIndexCount && !self.sceneNoMercProbe) {
    draw_mesh(self.mercVertices, self.mercIndices, self.mercColors, self.mercIndexCount,
              _mercDraws, false, true);
  }
  if (!self.directFixtureIsolated && _mercActorIndexCount && !self.sceneNoMercProbe) {
    draw_mesh(_mercActorVertices, _mercActorIndices, _mercActorColors, _mercActorIndexCount,
              _mercActorDraws, false, true);
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
    for (const auto& sprite : sprite_batches) {
      sprite_state[5] = sprite.ta0;
      [enc setRenderPipelineState:sprite.blended ? self.directBlendPipeline
                                                 : self.directPipeline];
      [enc setDepthStencilState:self.sceneNoDepthProbe ? self.overlayDepthState
                                                       : self.spriteDepthState];
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
  }
  // Foreground Direct/GIF text: the desktop debug bucket draws after the world
  // and after sprites.  Always-pass depth (overlayDepthState) matches how the
  // sky batches are already composited, so text is never occluded by world
  // depth.  Only the touch overlay is suppressed by -scene-no-overlay.
  // Tagged snapshot for the same reason as sprites: Direct/GIF text packets
  // appended by the game thread while this command buffer is being built must
  // not be wiped by the terminal clear before they are ever encoded.  That
  // drop is what made the menu labels appear in fragments that changed every
  // frame.
  const auto direct_tagged = _directBatches.snapshot_tagged();
  std::vector<NativeSpriteBatch> direct_batches;
  std::vector<unsigned long long> ottsel_direct_drawn_tags;
  direct_batches.reserve(direct_tagged.size());
  ottsel_direct_drawn_tags.reserve(direct_tagged.size());
  for (const auto& tagged : direct_tagged) {
    direct_batches.push_back(tagged.second);
    if (!tagged.second.persistent) {
      ottsel_direct_drawn_tags.push_back(tagged.first);
    }
  }
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
      [enc setDepthStencilState:self.overlayDepthState];
      [enc setVertexBuffer:direct_batch.vertices offset:0 atIndex:0];
      [enc setFragmentTexture:direct_batch.texture atIndex:0];
      [enc setFragmentSamplerState:self.directSampler atIndex:0];
      [enc setFragmentBytes:direct_text_state length:sizeof(direct_text_state) atIndex:1];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
              vertexCount:direct_batch.vertex_count];
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
    const auto end_sky_batches = _skyBatches.snapshot();
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
    [self recycleVertexBuffersAfter:cb];
    [cb commit];
    return;
  }
  [cb presentDrawable:drawable];
  [self recycleVertexBuffersAfter:cb];
  [cb commit];
  static unsigned int ottsel_sprite_frame_logs = 0;
  const size_t ottsel_sprite_batches_late = _spriteBatches.snapshot().size();
  if (ottsel_mobile_log_within_budget(ottsel_sprite_frame_logs, 8000)) {
    ++ottsel_sprite_frame_logs;
    lg::info("OTTSEL SPRITE FRAME: n={} drawn={} appended-during-encode={}",
             ottsel_sprite_frame_logs, ottsel_sprite_batches_drawn,
             ottsel_sprite_batches_late);
  }
  // Erase only the groups encoded above. Sky and Direct keep their existing
  // whole-store clear: this change is scoped to the sprite/text path.
  _spriteBatches.erase_tags(ottsel_sprite_drawn_tags);
  _skyBatches.clear();
  _directBatches.erase_tags(ottsel_direct_drawn_tags);
}

- (void)setTieMesh:(const void*)vertices
        vertexCount:(NSUInteger)vertexCount
     triangleIndices:(const unsigned int*)indices
          indexCount:(NSUInteger)indexCount
              draws:(const OttselMetalTieDraw*)draws
          drawCount:(NSUInteger)drawCount {
  if (!vertices || !vertexCount || !indices || !indexCount) {
    return;
  }
  PendingMeshUpload upload;
  upload.vertices.assign((const unsigned char*)vertices,
                         (const unsigned char*)vertices + vertexCount * 32);
  upload.indices.assign(indices, indices + indexCount);
  if (draws && drawCount) {
    upload.draws.assign(draws, draws + drawCount);
  }
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    // A newer camera snapshot supersedes stale TIE geometry still waiting for
    // the presentation thread; retain only the newest snapshot for this family.
    _pendingMeshUploads.erase(
        std::remove_if(_pendingMeshUploads.begin(), _pendingMeshUploads.end(),
                       [](const PendingMeshUpload& pending) { return !pending.tfrag; }),
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
- (void)appendSkyMeshNow:(const OttselMetalSpriteVertex*)vertices
             vertexCount:(NSUInteger)vertexCount
                   rgba:(const unsigned char*)rgba
                  width:(NSUInteger)width
                 height:(NSUInteger)height
                blended:(BOOL)blended
                    ta0:(unsigned char)ta0 {
  if (!vertices || !vertexCount || !rgba || !width || !height || !self.device ||
      !self.directPipeline) {
    return;
  }
  id<MTLTexture> texture = [self cachedMeshTexture:rgba width:width height:height];
  const NSUInteger vertex_bytes = vertexCount * sizeof(OttselMetalSpriteVertex);
  id<MTLBuffer> vertex_buffer = [self borrowVertexBufferBytes:vertex_bytes];
  if (!texture || !vertex_buffer) {
    return;
  }
  memcpy(vertex_buffer.contents, vertices, vertex_bytes);
  _skyBatches.append({vertex_buffer, texture, vertexCount, blended, ta0, false});
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

// Hand every buffer borrowed since the last call back to the free list, but
// only after the command buffer that consumed them has completed.  A nil
// command buffer returns them immediately.
- (void)recycleVertexBuffersAfter:(id<MTLCommandBuffer>)cb {
  std::vector<id<MTLBuffer>> done;
  {
    std::lock_guard<std::mutex> lock(_vertexPoolMutex);
    if (_vertexPoolInFlight.empty()) {
      return;
    }
    done.swap(_vertexPoolInFlight);
  }
  if (!cb) {
    std::lock_guard<std::mutex> lock(_vertexPoolMutex);
    for (const id<MTLBuffer>& buffer : done) {
      _vertexPool.push_back(buffer);
    }
    return;
  }
  [cb addCompletedHandler:^(id<MTLCommandBuffer> completed) {
    (void)completed;
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
                       ta0:(unsigned char)ta0 {
  if (!vertices || !vertexCount || !rgba || !width || !height || !self.device ||
      !self.directPipeline) {
    return;
  }
  id<MTLTexture> texture = [self cachedMeshTexture:rgba width:width height:height];
  const NSUInteger vertex_bytes = vertexCount * sizeof(OttselMetalSpriteVertex);
  id<MTLBuffer> vertex_buffer = [self borrowVertexBufferBytes:vertex_bytes];
  if (!texture || !vertex_buffer) {
    return;
  }
  memcpy(vertex_buffer.contents, vertices, vertex_bytes);
  _directBatches.append({vertex_buffer, texture, vertexCount, blended, ta0, false});
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

- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count {
  if (!rgba || !count) {
    return;
  }
  PendingColorUpload upload;
  upload.rgba.assign(rgba, rgba + count * 4);
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    _pendingColorUploads.erase(
        std::remove_if(_pendingColorUploads.begin(), _pendingColorUploads.end(),
                       [](const PendingColorUpload& pending) { return !pending.tfrag; }),
        _pendingColorUploads.end());
    _pendingColorUploads.push_back(std::move(upload));
  }
}

- (void)setColorsNow:(const unsigned char*)rgba count:(NSUInteger)count tfrag:(BOOL)tfrag {
  if (!rgba || !count) {
    return;
  }
  id<MTLBuffer> buffer = [self.device newBufferWithBytes:rgba
                                                   length:count
                                                  options:MTLResourceStorageModeShared];
  if (tfrag) {
    self.tfragColors = buffer;
  } else {
    self.tieColors = buffer;
  }
}

- (void)drainColorUploads {
  constexpr unsigned int kUploadBudgetPerFrame = 4;
  for (unsigned int i = 0; i < kUploadBudgetPerFrame; ++i) {
    PendingColorUpload upload;
    {
      std::lock_guard<std::mutex> lock(_tieUploadMutex);
      if (_pendingColorUploads.empty()) {
        return;
      }
      upload = std::move(_pendingColorUploads.front());
      _pendingColorUploads.pop_front();
    }
    [self setColorsNow:upload.rgba.data() count:upload.rgba.size() tfrag:upload.tfrag];
  }
}

- (void)setMeshNow:(const void*)vertices
       vertexCount:(NSUInteger)vertexCount
    triangleIndices:(const unsigned int*)indices
         indexCount:(NSUInteger)indexCount
             draws:(const OttselMetalTieDraw*)draws
         drawCount:(NSUInteger)drawCount
            tfrag:(BOOL)tfrag {
  if (!vertices || !vertexCount || !indices || !indexCount) {
    return;
  }
  id<MTLBuffer> vertex_buffer = [self.device newBufferWithBytes:vertices
                                                            length:vertexCount * 32
                                                           options:MTLResourceStorageModeShared];
  id<MTLBuffer> index_buffer = [self.device newBufferWithBytes:indices
                                                           length:indexCount * sizeof(unsigned int)
                                                          options:MTLResourceStorageModeShared];
  if (tfrag) {
    self.tfragVertices = vertex_buffer;
    self.tfragIndices = index_buffer;
    self.tfragIndexCount = indexCount;
    _tfragDraws.clear();
    if (draws && drawCount) {
      _tfragDraws.assign(draws, draws + drawCount);
    }
  } else {
    self.tieVertices = vertex_buffer;
    self.tieIndices = index_buffer;
    self.tieIndexCount = indexCount;
    _tieDraws.clear();
    if (draws && drawCount) {
      _tieDraws.assign(draws, draws + drawCount);
    }
  }
  NSLog(@"ottsel metal: %@ mesh vertices=%lu triangles=%lu", tfrag ? @"TFRAG" : @"TIE",
        (unsigned long)vertexCount, (unsigned long)(indexCount / 3));
}

- (void)drainMeshUploads {
  constexpr unsigned int kUploadBudgetPerFrame = 2;
  for (unsigned int i = 0; i < kUploadBudgetPerFrame; ++i) {
    PendingMeshUpload upload;
    {
      std::lock_guard<std::mutex> lock(_tieUploadMutex);
      // Mesh draw indices are global slots shared with the FIFO texture cache.
      // Do not promote a snapshot while an earlier level's texture uploads can
      // still leave its slots absent from tieTextures.
      if (!ottsel_mobile_mesh_upload_ready((unsigned int)_pendingTieUploads.size())) {
        static unsigned int residency_wait_logs = 0;
        if (residency_wait_logs++ < 4) {
          NSLog(@"ottsel metal: delaying mesh promotion for %lu pending texture uploads",
                (unsigned long)_pendingTieUploads.size());
        }
        return;
      }
      if (_pendingMeshUploads.empty()) {
        return;
      }
      upload = std::move(_pendingMeshUploads.front());
      _pendingMeshUploads.pop_front();
    }
    [self setMeshNow:upload.vertices.data()
         vertexCount:upload.vertices.size() / 32
      triangleIndices:upload.indices.data()
           indexCount:upload.indices.size()
               draws:upload.draws.data()
           drawCount:upload.draws.size()
              tfrag:upload.tfrag];
  }
}

- (void)drainMercUploads {
  std::vector<unsigned char> vertices;
  std::vector<unsigned int> indices;
  std::vector<OttselMetalTieDraw> draws;
  std::vector<unsigned char> colors;
  std::vector<unsigned char> actor_vertices;
  std::vector<unsigned int> actor_indices;
  std::vector<OttselMetalTieDraw> actor_draws;
  std::vector<unsigned char> actor_colors;
  {
    std::lock_guard<std::mutex> lock(_mercMutex);
    vertices = std::move(_pendingMercVertices);
    indices = std::move(_pendingMercIndices);
    draws = std::move(_pendingMercDraws);
    colors = std::move(_pendingMercColors);
    _pendingMercVertices.clear();
    _pendingMercIndices.clear();
    _pendingMercDraws.clear();
    _pendingMercColors.clear();
    actor_vertices = std::move(_pendingMercActorVertices);
    actor_indices = std::move(_pendingMercActorIndices);
    actor_draws = std::move(_pendingMercActorDraws);
    actor_colors = std::move(_pendingMercActorColors);
    _pendingMercActorVertices.clear();
    _pendingMercActorIndices.clear();
    _pendingMercActorDraws.clear();
    _pendingMercActorColors.clear();
  }
  if (!actor_vertices.empty() && !actor_indices.empty() && !actor_draws.empty()) {
    static const unsigned char kWhite[4] = {255, 255, 255, 255};
    if (actor_colors.empty()) {
      actor_colors.assign(kWhite, kWhite + 4);
    }
    _mercActorVertices = [self.device newBufferWithBytes:actor_vertices.data()
                                                    length:actor_vertices.size()
                                                   options:MTLResourceStorageModeShared];
    _mercActorIndices = [self.device newBufferWithBytes:actor_indices.data()
                                                   length:actor_indices.size() * sizeof(unsigned int)
                                                  options:MTLResourceStorageModeShared];
    _mercActorColors = [self.device newBufferWithBytes:actor_colors.data()
                                                  length:actor_colors.size()
                                                 options:MTLResourceStorageModeShared];
    _mercActorIndexCount = actor_indices.size();
    _mercActorDraws = std::move(actor_draws);
    NSLog(@"ottsel metal: MERC actor snapshot vertices=%lu triangles=%lu draws=%lu",
          (unsigned long)(actor_vertices.size() / 32),
          (unsigned long)(actor_indices.size() / 3), (unsigned long)_mercActorDraws.size());
  }
  if (vertices.empty() || indices.empty() || draws.empty()) {
    if (!ottsel_mobile_merc_snapshot_should_retain(
            true, self.mercVertices && self.mercIndices && self.mercIndexCount && !_mercDraws.empty())) {
      self.mercVertices = nil;
      self.mercIndices = nil;
      self.mercColors = nil;
      self.mercIndexCount = 0;
      _mercDraws.clear();
    }
    return;
  }
  if (colors.empty()) {
    colors = {255, 255, 255, 255};
  }
  self.mercVertices = [self.device newBufferWithBytes:vertices.data()
                                                  length:vertices.size()
                                                 options:MTLResourceStorageModeShared];
  self.mercIndices = [self.device newBufferWithBytes:indices.data()
                                                 length:indices.size() * sizeof(unsigned int)
                                                options:MTLResourceStorageModeShared];
  self.mercColors = [self.device newBufferWithBytes:colors.data()
                                                length:colors.size()
                                               options:MTLResourceStorageModeShared];
  self.mercIndexCount = indices.size();
  _mercDraws = std::move(draws);
  NSLog(@"ottsel metal: MERC mesh vertices=%lu triangles=%lu draws=%lu",
        (unsigned long)(vertices.size() / 32), (unsigned long)(indices.size() / 3),
        (unsigned long)_mercDraws.size());
}

- (void)setTfragMesh:(const void*)vertices
         vertexCount:(NSUInteger)vertexCount
      triangleIndices:(const unsigned int*)indices
           indexCount:(NSUInteger)indexCount
               draws:(const OttselMetalTieDraw*)draws
           drawCount:(NSUInteger)drawCount {
  if (!vertices || !vertexCount || !indices || !indexCount) {
    return;
  }
  PendingMeshUpload upload;
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
                       [](const PendingMeshUpload& pending) { return pending.tfrag; }),
        _pendingMeshUploads.end());
    _pendingMeshUploads.push_back(std::move(upload));
  }
}

- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count {
  if (!rgba || !count) {
    return;
  }
  PendingColorUpload upload;
  upload.rgba.assign(rgba, rgba + count * 4);
  upload.tfrag = true;
  {
    std::lock_guard<std::mutex> lock(_tieUploadMutex);
    _pendingColorUploads.erase(
        std::remove_if(_pendingColorUploads.begin(), _pendingColorUploads.end(),
                       [](const PendingColorUpload& pending) { return pending.tfrag; }),
        _pendingColorUploads.end());
    _pendingColorUploads.push_back(std::move(upload));
  }
}

- (void)appendMercMesh:(const void*)vertices
          vertexCount:(NSUInteger)vertexCount
       triangleIndices:(const unsigned int*)indices
            indexCount:(NSUInteger)indexCount
                 draws:(const OttselMetalTieDraw*)draws
             drawCount:(NSUInteger)drawCount {
  if (!vertices || !vertexCount || !indices || !indexCount || !draws || !drawCount) {
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
  if (_pendingMercColors.empty()) {
    _pendingMercColors = {255, 255, 255, 255};
  }
}

- (void)setMercActorMesh:(const void*)vertices
            vertexCount:(NSUInteger)vertexCount
         triangleIndices:(const unsigned int*)indices
              indexCount:(NSUInteger)indexCount
                  draws:(const OttselMetalTieDraw*)draws
              drawCount:(NSUInteger)drawCount {
  if (!vertices || !vertexCount || !indices || !indexCount || !draws || !drawCount) {
    return;
  }
  std::lock_guard<std::mutex> lock(_mercMutex);
  _pendingMercActorVertices.assign((const unsigned char*)vertices,
                                   (const unsigned char*)vertices + vertexCount * 32);
  _pendingMercActorIndices.assign(indices, indices + indexCount);
  _pendingMercActorDraws.assign(draws, draws + drawCount);
  _pendingMercActorColors = {255, 255, 255, 255};
}

- (void)setSpriteMesh:(const OttselMetalSpriteVertex*)vertices
                 rgba:(const unsigned char*)rgba
                width:(NSUInteger)width
                height:(NSUInteger)height
                blended:(BOOL)blended {
  if (!vertices || !rgba || !width || !height || !self.device || !self.directPipeline) {
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
      !self.directPipeline) {
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
  _skyBatches.clear();
  _directBatches.clear();
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

void ottsel_metal_set_tie_mesh(OttselMetal* m,
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
         drawCount:draw_count];
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

void ottsel_metal_set_tie_colors(OttselMetal* m,
                                 const unsigned char* rgba,
                                 unsigned int color_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTieColors:rgba count:color_count];
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

void ottsel_metal_set_tfrag_mesh(OttselMetal* m,
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
          drawCount:draw_count];
  }
}

void ottsel_metal_set_tfrag_colors(OttselMetal* m,
                                   const unsigned char* rgba,
                                   unsigned int color_count) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTfragColors:rgba count:color_count];
  }
}

void ottsel_metal_append_merc_mesh(OttselMetal* m,
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
    [r appendMercMesh:vertices
          vertexCount:vertex_count
       triangleIndices:triangle_indices
            indexCount:index_count
             draws:draws
         drawCount:draw_count];
  }
}

void ottsel_metal_set_merc_actor_mesh(OttselMetal* m,
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
    [r setMercActorMesh:vertices
            vertexCount:vertex_count
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

void ottsel_metal_append_sky_mesh_n(OttselMetal* m,
                                    const OttselMetalSpriteVertex* vertices,
                                    unsigned int vertex_count,
                                    const unsigned char* rgba,
                                    unsigned int width,
                                    unsigned int height,
                                    int blended,
                                    unsigned char ta0) {
  if (!m || !vertices || vertex_count == 0) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r appendSkyMeshNow:vertices
            vertexCount:vertex_count
                  rgba:rgba
                 width:width
                height:height
               blended:blended != 0
                   ta0:ta0];
  }
}

void ottsel_metal_append_direct_mesh_n(OttselMetal* m,
                                       const OttselMetalSpriteVertex* vertices,
                                       unsigned int vertex_count,
                                       const unsigned char* rgba,
                                       unsigned int width,
                                       unsigned int height,
                                       int blended,
                                       unsigned char ta0) {
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
                      ta0:ta0];
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
