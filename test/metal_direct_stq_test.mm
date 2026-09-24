#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "../src/shell/metal_shell.h"

// Both includes are extracted verbatim from product source by the runner.
#include "direct_shader_source.inc"

struct SourceCoordinates {
  bool has_uv;
  bool has_st;
  uint32_t uv_u;
  uint32_t uv_v;
  float s;
  float t;
  float q;
  bool fst = false;
};

static OttselMetalSpriteVertex convert(const SourceCoordinates& source) {
  constexpr unsigned int texture_width = 256, texture_height = 1;
  struct TestPrim {
    bool fixed_uv;
    bool fst() const { return fixed_uv; }
  };
  const TestPrim gp{source.fst};
  (void)gp;
  OttselMetalSpriteVertex vertex{};
#include "direct_uv_mapping.inc"
  vertex.color[0] = vertex.color[1] = vertex.color[2] = vertex.color[3] = 1.f;
  return vertex;
}

static void require(bool condition, NSString* message) {
  if (!condition) {
    std::fprintf(stderr, "ERROR: %s\n", message.UTF8String);
    std::exit(2);
  }
}

int main(int argc, char** argv) {
  const bool check_fst = argc == 2 && std::strcmp(argv[1], "--fst") == 0;
  @autoreleasepool {
    require(OttselMetalSpriteVertex{}.q == 1.f && OttselMetalOverlayVertex{}.q == 1.f &&
                DirectFixtureVertex{}.q == 1.f,
            @"Sprite, overlay, and fixture defaults must retain identity Q");
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    require(device != nil, @"host Metal unavailable");
    NSError* error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:kDirectFixtureShaderSource
                                                options:nil error:&error];
    require(library != nil, [NSString stringWithFormat:@"actual Direct shader: %@", error]);
#include "direct_vertex_layout.inc"
    MTLRenderPipelineDescriptor* descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.vertexFunction = [library newFunctionWithName:@"direct_vs"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"direct_fs"];
    descriptor.vertexDescriptor = directLayout;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor
                                                                               error:&error];
    require(pipeline != nil, [NSString stringWithFormat:@"pipeline: %@", error]);
    MTLTextureDescriptor* target_descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                    width:33 height:33 mipmapped:NO];
    target_descriptor.storageMode = MTLStorageModeShared;
    target_descriptor.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> target = [device newTextureWithDescriptor:target_descriptor];
    MTLTextureDescriptor* gradient_descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                    width:256 height:1 mipmapped:NO];
    gradient_descriptor.storageMode = MTLStorageModeShared;
    gradient_descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> gradient = [device newTextureWithDescriptor:gradient_descriptor];
    require(target && gradient, @"texture allocation failed");
    unsigned char pixels[256][4];
    for (unsigned int x = 0; x < 256; ++x) {
      pixels[x][0] = x;
      pixels[x][1] = pixels[x][2] = 0;
      pixels[x][3] = 255;
    }
    [gradient replaceRegion:MTLRegionMake2D(0, 0, 256, 1) mipmapLevel:0
                  withBytes:pixels bytesPerRow:sizeof(pixels)];
    MTLSamplerDescriptor* sampler_descriptor = [MTLSamplerDescriptor new];
    sampler_descriptor.minFilter = sampler_descriptor.magFilter = MTLSamplerMinMagFilterLinear;
    sampler_descriptor.sAddressMode = sampler_descriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:sampler_descriptor];
    id<MTLCommandQueue> queue = [device newCommandQueue];
    require(queue && sampler, @"queue or sampler unavailable");

    auto center_red = [&](SourceCoordinates a, SourceCoordinates b) -> unsigned int {
      OttselMetalSpriteVertex vertices[3] = {convert(a), convert(a), convert(b)};
      vertices[0].pos[0] = -0.75f; vertices[0].pos[1] = -0.75f;
      vertices[1].pos[0] =  0.75f; vertices[1].pos[1] = -0.75f;
      vertices[2].pos[0] =  0.f;   vertices[2].pos[1] =  0.75f;
      MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
      pass.colorAttachments[0].texture = target;
      pass.colorAttachments[0].loadAction = MTLLoadActionClear;
      pass.colorAttachments[0].storeAction = MTLStoreActionStore;
      pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
      id<MTLCommandBuffer> cb = [queue commandBuffer];
      id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
      require(cb && enc, @"command encoding unavailable");
      [enc setRenderPipelineState:pipeline];
      [enc setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
      [enc setFragmentTexture:gradient atIndex:0];
      [enc setFragmentSamplerState:sampler atIndex:0];
      // Alpha test off, TCC on, decal: sampled RGB survives modulation exactly.
      const uint32_t state[] = {0, 0, 0, 1, 1, 0};
      [enc setFragmentBytes:state length:sizeof(state) atIndex:1];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      [enc endEncoding];
      dispatch_semaphore_t finished = dispatch_semaphore_create(0);
      [cb addCompletedHandler:^(id<MTLCommandBuffer>) { dispatch_semaphore_signal(finished); }];
      [cb commit];
      require(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
              @"GPU completion timed out after 10 seconds");
      require(cb.status == MTLCommandBufferStatusCompleted && !cb.error,
              [NSString stringWithFormat:@"GPU error: %@", cb.error]);
      std::array<unsigned char, 4> pixel{};
      [target getBytes:pixel.data() bytesPerRow:4 fromRegion:MTLRegionMake2D(16, 16, 1, 1)
          mipmapLevel:0];
      require(pixel[3] == 255, @"center pixel was not rasterized");
      return pixel[0];
    };
    const auto fst = center_red({true, false, 0, 0, 0.f, 0.f, 1.f, true},
                               {true, false, 256 * 16, 0, 0.f, 0.f, 1.f, true});
    const auto constant_q = center_red({false, true, 0, 0, 0.f, 0.5f, 1.f},
                                      {false, true, 0, 0, 1.f, 0.5f, 1.f});
    const auto zero_q = center_red({false, true, 0, 0, 0.f, 0.5f, 0.f},
                                  {false, true, 0, 0, 1.f, 0.5f, 0.f});
    const auto negative_q = center_red({false, true, 0, 0, 0.f, -0.5f, -1.f},
                                      {false, true, 0, 0, -1.f, -0.5f, -1.f});
    require(std::abs(int(fst) - 128) <= 2 && std::abs(int(constant_q) - 128) <= 2,
            [NSString stringWithFormat:@"FST/constant-Q controls failed: %u/%u", fst, constant_q]);
    require(std::abs(int(zero_q) - 128) <= 2 && std::abs(int(negative_q) - 128) <= 2,
            @"zero-Q fallback and negative-Q controls must retain existing endpoint semantics");
    const auto varying_q = center_red({false, true, 0, 0, 0.f, 0.5f, 1.f},
                                     {false, true, 0, 0, 2.f, 1.f, 2.f});
    // Desktop interpolates (s,t,q), then divides in direct_basic_textured.frag:
    // center s/q = (0+2)/(1+2) = 2/3, not average(0/1,2/2) = 1/2.
    const bool matches = std::abs(int(varying_q) - 170) <= 2;
    std::printf("FST-control=%u constant-Q-control=%u PASS; varying-Q center red=%u expected=170 tolerance=2\n",
                fst, constant_q, varying_q);
    std::puts(matches ? "PASS: actual Direct CPU/shader path preserves STQ interpolation"
                      : "FAIL: actual Direct CPU/shader path divides STQ before interpolation");
    std::printf("identity-Q defaults PASS; zero-Q fallback=%u negative-Q=%u PASS\n", zero_q, negative_q);
    if (check_fst && matches) {
      // A steeper gradient distinguishes 1.5 texels (red16) from the truncated
      // 1.0 texel (red8). Linear filtering and texture state stay unchanged.
      for (unsigned int x = 0; x < 256; ++x) pixels[x][0] = x < 16 ? x * 16 : 255;
      [gradient replaceRegion:MTLRegionMake2D(0, 0, 256, 1) mipmapLevel:0
                    withBytes:pixels bytesPerRow:sizeof(pixels)];
      const SourceCoordinates integer_uv{true, false, 16, 8, 0.f, 0.f, 1.f, true};
      const SourceCoordinates fractional_uv{true, false, 24, 8, 0.f, 0.f, 1.f, true};
      // Desktop packed ST writes the same common coord register as packed UV.
      // PRIM.FST=1 interprets its 24,8 as 1.5,0.5 texels and ignores Q=4.
      const SourceCoordinates st_fixed_uv{false, true, 0, 0, 24.f, 8.f, 4.f, true};
      const unsigned int integer_red = center_red(integer_uv, integer_uv);
      const unsigned int fractional_red = center_red(fractional_uv, fractional_uv);
      const unsigned int st_fixed_red = center_red(st_fixed_uv, st_fixed_uv);
      require(std::abs(int(integer_red) - 8) <= 2, @"integer fixed-UV control failed");
      const bool fractional_ok = std::abs(int(fractional_red) - 16) <= 2;
      const bool st_fixed_ok = std::abs(int(st_fixed_red) - 16) <= 2;
      std::printf("FST1 integerUV red=%u expected8 PASS; fractionalUV red=%u expected16 %s; "
                  "ST-carriedUV red=%u expected16 %s\n", integer_red, fractional_red,
                  fractional_ok ? "PASS" : "FAIL", st_fixed_red, st_fixed_ok ? "PASS" : "FAIL");
      return fractional_ok && st_fixed_ok ? 0 : 1;
    }
    return matches ? 0 : 1;
  }
}
