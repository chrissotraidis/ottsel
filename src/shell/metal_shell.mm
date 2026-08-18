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

#include "metal_shell.h"

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

}  // namespace

@interface OttselMetalRenderer : NSObject
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> tiePipeline;
@property (nonatomic, strong) CAMetalLayer* layer;
@property (nonatomic, strong) id<MTLTexture> logTex;
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
- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count;
- (void)setTfragMesh:(const void*)vertices
         vertexCount:(NSUInteger)vertexCount
      triangleIndices:(const unsigned int*)indices
           indexCount:(NSUInteger)indexCount
               draws:(const OttselMetalTieDraw*)draws
           drawCount:(NSUInteger)drawCount;
- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count;
@end

@implementation OttselMetalRenderer

{
  std::vector<OttselMetalTieDraw> _tieDraws;
  std::vector<OttselMetalTieDraw> _tfragDraws;
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
  self.layer.framebufferOnly = YES;

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
  id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:pd error:&err];
  if (!pipeline) {
    NSLog(@"ottsel metal: pipeline error %@", err);
    return NO;
  }
  self.pipeline = pipeline;

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
  if (!rgba) {
    return;
  }
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
  if (ottsel_present_logged++ < 8) {
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
  if (!self.logTex || self.logTex.width != (NSUInteger)w ||
      self.logTex.height != (NSUInteger)h) {
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
  [self.logTex replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)w, (NSUInteger)h)
                 mipmapLevel:0
                   withBytes:rgba
                 bytesPerRow:(NSUInteger)w * 4];

  id<CAMetalDrawable> drawable = [self.layer nextDrawable];
  if (!drawable) {
    return;
  }
  if (!self.tieDepth || self.tieDepth.width != drawable.texture.width ||
      self.tieDepth.height != drawable.texture.height) {
    MTLTextureDescriptor* depthDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                     width:drawable.texture.width
                                    height:drawable.texture.height
                                 mipmapped:NO];
    depthDesc.usage = MTLTextureUsageRenderTarget;
    depthDesc.storageMode = MTLStorageModePrivate;
    self.tieDepth = [self.device newTextureWithDescriptor:depthDesc];
  }
  MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
  pass.colorAttachments[0].texture = drawable.texture;
  pass.colorAttachments[0].loadAction = MTLLoadActionClear;
  pass.colorAttachments[0].storeAction = MTLStoreActionStore;
  pass.colorAttachments[0].clearColor = MTLClearColorMake(0.03, 0.04, 0.07, 1.0);
  pass.depthAttachment.texture = self.tieDepth;
  pass.depthAttachment.loadAction = MTLLoadActionClear;
  pass.depthAttachment.storeAction = MTLStoreActionDontCare;
  pass.depthAttachment.clearDepth = 0.0;

  id<MTLCommandBuffer> cb = [self.queue commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
  [enc setRenderPipelineState:self.pipeline];
  [enc setFragmentTexture:self.logTex atIndex:0];
  [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
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
  draw_mesh(self.tfragVertices, self.tfragIndices, self.tfragColors, self.tfragIndexCount,
            _tfragDraws);
  draw_mesh(self.tieVertices, self.tieIndices, self.tieColors, self.tieIndexCount, _tieDraws);
  [enc endEncoding];
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
  self.tieVertices = [self.device newBufferWithBytes:vertices
                                                length:vertexCount * 32
                                               options:MTLResourceStorageModeShared];
  self.tieIndices = [self.device newBufferWithBytes:indices
                                               length:indexCount * sizeof(unsigned int)
                                              options:MTLResourceStorageModeShared];
  self.tieIndexCount = indexCount;
  _tieDraws.assign(draws, draws + drawCount);
  NSLog(@"ottsel metal: TIE mesh vertices=%lu triangles=%lu", (unsigned long)vertexCount,
        (unsigned long)(indexCount / 3));
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

- (void)setTieTextureAtIndex:(NSUInteger)index
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

- (void)setTieColors:(const unsigned char*)rgba count:(NSUInteger)count {
  if (!rgba || !count) {
    return;
  }
  self.tieColors = [self.device newBufferWithBytes:rgba
                                              length:count * 4
                                             options:MTLResourceStorageModeShared];
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
  self.tfragVertices = [self.device newBufferWithBytes:vertices
                                                  length:vertexCount * 32
                                                 options:MTLResourceStorageModeShared];
  self.tfragIndices = [self.device newBufferWithBytes:indices
                                                 length:indexCount * sizeof(unsigned int)
                                                options:MTLResourceStorageModeShared];
  self.tfragIndexCount = indexCount;
  _tfragDraws.assign(draws, draws + drawCount);
  NSLog(@"ottsel metal: TFRAG mesh vertices=%lu triangles=%lu", (unsigned long)vertexCount,
        (unsigned long)(indexCount / 3));
}

- (void)setTfragColors:(const unsigned char*)rgba count:(NSUInteger)count {
  if (!rgba || !count) {
    return;
  }
  self.tfragColors = [self.device newBufferWithBytes:rgba
                                                length:count * 4
                                               options:MTLResourceStorageModeShared];
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
