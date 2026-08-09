// Ottsel S2.0 — Metal shell surface (Objective-C++ implementation).
//
// Delivers the CPU-rendered log surface through a real Metal pipeline on
// the SDL window's CAMetalLayer: device, command queue, fullscreen
// textured-triangle pipeline, per-frame texture upload, present.

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_metal.h>

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

}  // namespace

@interface OttselMetalRenderer : NSObject
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) CAMetalLayer* layer;
@property (nonatomic, strong) id<MTLTexture> logTex;
- (BOOL)setupWithWindow:(SDL_Window*)win width:(int)w height:(int)h;
- (void)presentRGBA:(const unsigned char*)rgba width:(int)w height:(int)h;
@end

@implementation OttselMetalRenderer

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
  MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
  pass.colorAttachments[0].texture = drawable.texture;
  pass.colorAttachments[0].loadAction = MTLLoadActionClear;
  pass.colorAttachments[0].storeAction = MTLStoreActionStore;
  pass.colorAttachments[0].clearColor = MTLClearColorMake(0.03, 0.04, 0.07, 1.0);

  id<MTLCommandBuffer> cb = [self.queue commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
  [enc setRenderPipelineState:self.pipeline];
  [enc setFragmentTexture:self.logTex atIndex:0];
  [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
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
