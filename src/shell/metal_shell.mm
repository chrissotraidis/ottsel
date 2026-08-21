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
#include <deque>
#include <mutex>
#include <unordered_set>
#include <cstdio>
#include <string>

#include "metal_shell.h"
#include "common/dma/ottsel_sprite_math.h"
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
"uint tcc; uint tfx; };\n"
"vertex DirectOut direct_vs(DirectIn in [[stage_in]]) {\n"
"  DirectOut out; out.position = float4(in.pos, 0.0, 1.0); out.uv = in.uv; "
"  out.color = float4(in.color.rgb, in.color.a * 2.0); return out;\n"
"}\n"
"fragment float4 direct_fs(DirectOut in [[stage_in]], texture2d<float> tex [[texture(0)]],\n"
"                           sampler s [[sampler(0)]],\n"
"                           constant DirectState& state [[buffer(1)]]) {\n"
"  float4 texel = tex.sample(s, in.uv);\n"
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
"}\n";

NSString* kTieShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct TieIn { float3 position [[attribute(0)]]; float2 uv [[attribute(1)]]; "
"ushort color_index [[attribute(2)]]; };\n"
"struct TieUniforms { float4 pc_camera[4]; float4 camera_trans; float4 fog_params; "
"float4 fog_color; };\n"
"struct TieMaterial { float alpha_min; };\n"
"struct TieOut { float4 position [[position]]; float2 uv; ushort color_index [[flat]]; "
"float fogginess; float3 fog_color; };\n"
"vertex TieOut tie_vs(TieIn in [[stage_in]], constant TieUniforms& u [[buffer(1)]]) {\n"
"  float3 vert = in.position - u.camera_trans.xyz;\n"
"  float4 transformed = -u.pc_camera[3];\n"
"  transformed.w = 0.0;\n"
"  transformed -= u.pc_camera[0] * vert.x;\n"
"  transformed -= u.pc_camera[1] * vert.y;\n"
"  transformed -= u.pc_camera[2] * vert.z;\n"
"  // The shared PC shader targets OpenGL's z range [-w,w]; Metal clips z\n"
"  // in [0,w]. Preserve x/y/w and remap only depth.\n"
"  transformed.z = (transformed.z + transformed.w) * 0.5;\n"
"  TieOut out; out.position = transformed; out.uv = in.uv; out.color_index = in.color_index; "
"out.fogginess = 255.0 - clamp(-transformed.w + u.fog_params.x, u.fog_params.y, u.fog_params.z); "
"out.fog_color = u.fog_color.xyz; "
"return out;\n"
"}\n"
"fragment float4 tie_fs(TieOut in [[stage_in]], texture2d<float> tex [[texture(0)]], "
"constant uchar4* colors [[buffer(0)]], constant TieMaterial& material [[buffer(1)]], "
"sampler tex_sampler [[sampler(0)]]) {\n"
"  float4 color = tex.sample(tex_sampler, in.uv) * (float4(colors[in.color_index]) / 255.0) * 2.0;\n"
"  if (color.a < material.alpha_min) discard_fragment();\n"
"  color.rgb = mix(color.rgb, in.fog_color, clamp(in.fogginess * 0.0039215686, 0.0, 1.0));\n"
"  return color;\n"
"}\n";

struct TieUniforms {
  float pc_camera[16];
  float camera_trans[4];
  float fog_params[4];
  float fog_color[4];
};

struct TieMaterial {
  float alpha_min;
};

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
  BOOL blended = NO;
};

}  // namespace

@interface OttselMetalRenderer : NSObject
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directBlendPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directNoDepthPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> directColorOnlyPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> tiePipeline;
@property (nonatomic, strong) CAMetalLayer* layer;
@property (nonatomic, strong) id<MTLTexture> logTex;
@property (nonatomic, strong) id<MTLTexture> directTex;
@property (nonatomic, strong) id<MTLSamplerState> directSampler;
@property (nonatomic, strong) NSMutableDictionary* directTextures;
@property (nonatomic, strong) id<MTLBuffer> directVertices;
@property (nonatomic, strong) id<MTLBuffer> spriteVertices;
@property (nonatomic, strong) id<MTLTexture> spriteTex;
@property (nonatomic) BOOL spriteActive;
@property (nonatomic) BOOL spriteBlendEnabled;
@property (nonatomic, strong) id<MTLBuffer> touchOverlayVertices;
@property (nonatomic, strong) id<MTLTexture> touchOverlayTex;
@property (nonatomic) NSUInteger touchOverlayVertexCount;
@property (nonatomic) BOOL directFixtureActive;
@property (nonatomic) BOOL directFixtureIsolated;
@property (nonatomic) BOOL directFixtureNoDepth;
@property (nonatomic) BOOL directFixtureColorOnly;
@property (nonatomic) BOOL directFixtureOffscreen;
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
@property (nonatomic, strong) NSMutableArray* tieTextures;
@property (nonatomic, strong) NSArray* tieSamplers;
@property (nonatomic, strong) id<MTLTexture> tieDepth;
@property (nonatomic, strong) id<MTLDepthStencilState> tieDepthState;
@property (nonatomic, strong) id<MTLDepthStencilState> directDepthState;
@property (nonatomic, strong) id<MTLDepthStencilState> spriteDepthState;
@property (nonatomic, strong) id<MTLDepthStencilState> overlayDepthState;
@property (nonatomic) NSUInteger tieIndexCount;
@property (nonatomic) NSUInteger tfragIndexCount;
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
          cameraTrans:(const float*)cameraTrans
           fogParams:(const float*)fogParams
            fogColor:(const float*)fogColor;
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
- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count;
- (void)setTfragMesh:(const void*)vertices
         vertexCount:(NSUInteger)vertexCount
      triangleIndices:(const unsigned int*)indices
           indexCount:(NSUInteger)indexCount
               draws:(const OttselMetalTieDraw*)draws
           drawCount:(NSUInteger)drawCount;
- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count;
- (void)setSpriteMesh:(const OttselMetalSpriteVertex*)vertices
                 rgba:(const unsigned char*)rgba
                width:(NSUInteger)width
                height:(NSUInteger)height
                blended:(BOOL)blended;
- (void)setSpriteMeshNow:(const OttselMetalSpriteVertex*)vertices
                    rgba:(const unsigned char*)rgba
                   width:(NSUInteger)width
                  height:(NSUInteger)height
                 blended:(BOOL)blended;
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
  std::deque<PendingTieUpload> _pendingTieUploads;
  std::deque<PendingColorUpload> _pendingColorUploads;
  std::deque<PendingMeshUpload> _pendingMeshUploads;
  std::mutex _spriteUploadMutex;
  std::deque<PendingSpriteUpload> _pendingSpriteUploads;
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
  MTLDepthStencilDescriptor* depthDesc = [[MTLDepthStencilDescriptor alloc] init];
  // PC/OpenGL's depth value is remapped to Metal's [0,1] range in tie_vs;
  // normal TIE DrawModes use GEQUAL and clear to zero.
  depthDesc.depthCompareFunction = MTLCompareFunctionGreaterEqual;
  depthDesc.depthWriteEnabled = YES;
  self.tieDepthState = [device newDepthStencilStateWithDescriptor:depthDesc];
  self.directDepthState = self.tieDepthState;
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
  return YES;
}

- (void)presentRGBA:(const unsigned char*)rgba width:(int)w height:(int)h {
  if (!rgba && !self.directFixtureActive) {
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
    pass.depthAttachment.clearDepth = 0.0;
  }

  id<MTLCommandBuffer> cb = [self.queue commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
  if (!self.directFixtureIsolated) {
    [enc setRenderPipelineState:self.pipeline];
    [enc setFragmentTexture:self.logTex atIndex:0];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  }
  const auto draw_mesh = ^(id<MTLBuffer> vertices, id<MTLBuffer> indices, id<MTLBuffer> colors,
                           NSUInteger index_count,
                           const std::vector<OttselMetalTieDraw>& draws) {
    if (!vertices || !indices || !colors || !index_count) {
      return;
    }
    [enc setRenderPipelineState:self.tiePipeline];
    [enc setDepthStencilState:self.tieDepthState];
    [enc setVertexBuffer:vertices offset:0 atIndex:0];
    [enc setVertexBytes:&_tieUniforms length:sizeof(_tieUniforms) atIndex:1];
    [enc setFragmentBuffer:colors offset:0 atIndex:0];
    for (const auto& draw : draws) {
      if (draw.texture_index < 0 || (NSUInteger)draw.texture_index >= self.tieTextures.count) {
        continue;
      }
      id texture = self.tieTextures[(NSUInteger)draw.texture_index];
      if (![texture conformsToProtocol:@protocol(MTLTexture)]) {
        continue;
      }
      const bool clamp_s = draw.mode & (1u << 5);
      const bool clamp_t = draw.mode & (1u << 23);
      const NSUInteger sampler_idx = (clamp_t ? 2 : 0) + (clamp_s ? 1 : 0);
      const bool alpha_test = draw.mode & (1u << 18);
      const unsigned int alpha_test_kind = (draw.mode >> 16) & 3;
      const float alpha_min = alpha_test && alpha_test_kind == 2
                                  ? ((draw.mode >> 8) & 0xff) / 127.f
                                  : 0.f;
      TieMaterial material{alpha_min};
      [enc setFragmentTexture:texture atIndex:0];
      [enc setFragmentSamplerState:self.tieSamplers[sampler_idx] atIndex:0];
      [enc setFragmentBytes:&material length:sizeof(material) atIndex:1];
      [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                      indexCount:draw.index_count
                       indexType:MTLIndexTypeUInt32
                      indexBuffer:indices
               indexBufferOffset:draw.index_offset * sizeof(unsigned int)];
    }
  };
  // Desktop bucket order draws opaque background TFRAG before normal TIE.
  // They share the exact camera/material shader but have separate meshes and
  // time-of-day color tables.
  if (!self.directFixtureIsolated) {
    draw_mesh(self.tfragVertices, self.tfragIndices, self.tfragColors, self.tfragIndexCount,
              _tfragDraws);
    draw_mesh(self.tieVertices, self.tieIndices, self.tieColors, self.tieIndexCount, _tieDraws);
  }
  if (self.spriteActive && !self.directFixtureIsolated) {
    [enc setRenderPipelineState:self.spriteBlendEnabled ? self.directBlendPipeline
                                                        : self.directPipeline];
    [enc setDepthStencilState:self.spriteDepthState];
    [enc setVertexBuffer:self.spriteVertices offset:0 atIndex:0];
    [enc setFragmentTexture:self.spriteTex atIndex:0];
    [enc setFragmentSamplerState:self.directSampler atIndex:0];
    const unsigned int sprite_state[5] = {ottsel::sprite3_alpha_test_enabled(),
                                          ottsel::sprite3_alpha_test_gequal(),
                                          ottsel::sprite3_primary_alpha_ref(), 1, 0};
    [enc setFragmentBytes:sprite_state length:sizeof(sprite_state) atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    NSLog(@"ottsel metal: Sprite3 native draw vertices=6 blend=%s depth=gequal/no-write "
          "alpha-test=gequal/%u/%u tcc=1 tfx=0 texture=hit",
          self.spriteBlendEnabled ? "enabled" : "disabled",
          ottsel::sprite3_alpha_test_gequal(), ottsel::sprite3_primary_alpha_ref());
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
    const unsigned int direct_state[5] = {self.directAlphaTestEnable, self.directAlphaTest,
                                          self.directAlphaRef, self.directTcc, self.directTfx};
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
  if (!self.directFixtureIsolated && self.touchOverlayVertices && self.touchOverlayTex &&
      self.touchOverlayVertexCount) {
    [enc setRenderPipelineState:self.directBlendPipeline];
    [enc setDepthStencilState:self.overlayDepthState];
    [enc setVertexBuffer:self.touchOverlayVertices offset:0 atIndex:0];
    [enc setFragmentTexture:self.touchOverlayTex atIndex:0];
    [enc setFragmentSamplerState:self.directSampler atIndex:0];
    const unsigned int overlay_state[5] = {0, 0, 0, 0, 0};
    [enc setFragmentBytes:overlay_state length:sizeof(overlay_state) atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
            vertexCount:self.touchOverlayVertexCount];
  }
  [enc endEncoding];
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
    [cb commit];
    return;
  }
  [cb presentDrawable:drawable];
  [cb commit];
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
    _pendingMeshUploads.push_back(std::move(upload));
  }
}

- (void)setTieCamera:(const float*)pcCamera
          cameraTrans:(const float*)cameraTrans
           fogParams:(const float*)fogParams
            fogColor:(const float*)fogColor {
  if (!pcCamera || !cameraTrans || !fogParams || !fogColor) {
    return;
  }
  memcpy(_tieUniforms.pc_camera, pcCamera, sizeof(_tieUniforms.pc_camera));
  memcpy(_tieUniforms.camera_trans, cameraTrans, sizeof(_tieUniforms.camera_trans));
  memcpy(_tieUniforms.fog_params, fogParams, sizeof(_tieUniforms.fog_params));
  memcpy(_tieUniforms.fog_color, fogColor, sizeof(_tieUniforms.fog_color));
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
    _pendingColorUploads.push_back(std::move(upload));
  }
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
                    rgba:(const unsigned char*)rgba
                   width:(NSUInteger)width
                  height:(NSUInteger)height
                 blended:(BOOL)blended {
  if (!vertices || !rgba || !width || !height || !self.device || !self.directPipeline) {
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
  self.spriteTex = texture;
  self.spriteVertices = [self.device newBufferWithBytes:vertices
                                                   length:6 * sizeof(OttselMetalSpriteVertex)
                                                  options:MTLResourceStorageModeShared];
  self.spriteBlendEnabled = blended;
  self.spriteActive = self.spriteVertices != nil;
  if (self.spriteActive) {
    const std::string ready_path = ottsel_ios_writable_dir() +
                                    "ottsel-native-sprite-ready";
    if (FILE* ready = fopen(ready_path.c_str(), "wb")) {
      fprintf(ready, "texture=%lux%lu\n", (unsigned long)width, (unsigned long)height);
      fclose(ready);
    }
  }
  float min_x = vertices[0].pos[0], max_x = vertices[0].pos[0];
  float min_y = vertices[0].pos[1], max_y = vertices[0].pos[1];
  for (NSUInteger i = 1; i < 6; ++i) {
    min_x = std::min(min_x, vertices[i].pos[0]);
    max_x = std::max(max_x, vertices[i].pos[0]);
    min_y = std::min(min_y, vertices[i].pos[1]);
    max_y = std::max(max_y, vertices[i].pos[1]);
  }
  NSLog(@"ottsel metal: Sprite3 native bounds=%.3f..%.3f,%.3f..%.3f texture=%lux%lu",
        min_x, max_x, min_y, max_y, (unsigned long)width, (unsigned long)height);
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
                                 const float camera_trans[4],
                                 const float fog_params[4],
                                 const float fog_color[4]) {
  if (!m) {
    return;
  }
  @autoreleasepool {
    OttselMetalRenderer* r = (__bridge OttselMetalRenderer*)m;
    [r setTieCamera:pc_camera
         cameraTrans:camera_trans
          fogParams:fog_params
           fogColor:fog_color];
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
