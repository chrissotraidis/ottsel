#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include "../src/shell/metal_shell.h"
#include "../src/shell/mobile_direct_depth_policy.h"
using u8 = uint8_t;
using u32 = uint32_t;

#include "direct_depth_source.inc"

static void require(bool condition, NSString* message) {
  if (!condition) {
    std::fprintf(stderr, "ERROR: %s\n", message.UTF8String);
    std::exit(2);
  }
}

int main() {
  @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    require(device != nil, @"host Metal unavailable");
    NSError* error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:kDirectFixtureShaderSource
                                                options:nil error:&error];
    require(library != nil, [NSString stringWithFormat:@"actual shader: %@", error]);
#include "direct_depth_layout.inc"
    MTLRenderPipelineDescriptor* descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.vertexFunction = [library newFunctionWithName:@"direct_vs"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"direct_fs"];
    descriptor.vertexDescriptor = directLayout;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    require(pipeline != nil, [NSString stringWithFormat:@"pipeline: %@", error]);
    MTLTextureDescriptor* target_desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:33 height:33 mipmapped:NO];
    target_desc.storageMode = MTLStorageModeShared;
    target_desc.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> target = [device newTextureWithDescriptor:target_desc];
    MTLTextureDescriptor* depth_desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:33 height:33 mipmapped:NO];
    depth_desc.storageMode = MTLStorageModePrivate;
    depth_desc.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> depth = [device newTextureWithDescriptor:depth_desc];
    MTLTextureDescriptor* white_desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
    white_desc.storageMode = MTLStorageModeShared;
    white_desc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> white = [device newTextureWithDescriptor:white_desc];
    require(target && depth && white, @"texture allocation failed");
    const u8 white_pixel[] = {255, 255, 255, 255};
    [white replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0 withBytes:white_pixel bytesPerRow:4];
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:[MTLSamplerDescriptor new]];
    id<MTLCommandQueue> queue = [device newCommandQueue];
    require(queue && sampler, @"queue or sampler unavailable");

    OttselVertex near_vertex;
    near_vertex.z = 0xc00000;
    near_vertex.r = 128; near_vertex.g = near_vertex.b = 0;
    OttselVertex far_vertex;
    far_vertex.z = 0x400000;
    far_vertex.g = 128; far_vertex.r = far_vertex.b = 0;
    auto render = [&](const OttselVertex& first, const OttselVertex& second,
                      bool use_depth) -> std::array<u8, 4> {
      MTLDepthStencilDescriptor* state_desc = [MTLDepthStencilDescriptor new];
      const OttselMetalDirectDepthState captured_state{
          (1ull << 16) | ((use_depth ? 2ull : 1ull) << 17), use_depth ? 0ull : (1ull << 32)};
      const auto policy = ottsel_mobile_direct_depth_policy(captured_state.test, captured_state.zbuf);
      require(policy.supported, @"fixture GS depth state must be supported");
      const MTLCompareFunction comparisons[] = {MTLCompareFunctionNever, MTLCompareFunctionAlways,
          MTLCompareFunctionGreaterEqual, MTLCompareFunctionGreater};
      state_desc.depthCompareFunction = comparisons[policy.compare];
      state_desc.depthWriteEnabled = policy.write;
      id<MTLDepthStencilState> state = [device newDepthStencilStateWithDescriptor:state_desc];
      require(state != nil, @"depth state unavailable");
      MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
      pass.colorAttachments[0].texture = target;
      pass.colorAttachments[0].loadAction = MTLLoadActionClear;
      pass.colorAttachments[0].storeAction = MTLStoreActionStore;
      pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
      pass.depthAttachment.texture = depth;
      pass.depthAttachment.loadAction = MTLLoadActionClear;
      pass.depthAttachment.storeAction = MTLStoreActionDontCare;
      pass.depthAttachment.clearDepth = 0;
      id<MTLCommandBuffer> cb = [queue commandBuffer];
      id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
      require(cb && enc, @"command encoding unavailable");
      [enc setRenderPipelineState:pipeline];
      [enc setDepthStencilState:state];
      [enc setFragmentTexture:white atIndex:0];
      [enc setFragmentSamplerState:sampler atIndex:0];
      const u32 material[] = {0, 0, 0, 1, 0, 0};
      [enc setFragmentBytes:material length:sizeof(material) atIndex:1];
      for (const OttselVertex* source : {&first, &second}) {
        const OttselMetalSpriteVertex vertices[] = {
            capture_vertex(*source, -0.75f, -0.75f),
            capture_vertex(*source,  0.75f, -0.75f),
            capture_vertex(*source,  0.f,    0.75f)};
        [enc setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      }
      [enc endEncoding];
      dispatch_semaphore_t finished = dispatch_semaphore_create(0);
      [cb addCompletedHandler:^(id<MTLCommandBuffer>) { dispatch_semaphore_signal(finished); }];
      [cb commit];
      require(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
              @"GPU completion timed out after 10 seconds");
      require(cb.status == MTLCommandBufferStatusCompleted && !cb.error,
              [NSString stringWithFormat:@"GPU failure: %@", cb.error]);
      std::array<u8, 4> pixel{};
      [target getBytes:pixel.data() bytesPerRow:4 fromRegion:MTLRegionMake2D(16, 16, 1, 1) mipmapLevel:0];
      return pixel;
    };
    const std::array<u8, 4> red{255, 0, 0, 255}, green{0, 255, 0, 255};
    require(render(near_vertex, far_vertex, false) == green,
            @"ALWAYS/no-write control must show the later green draw");
    require(render(far_vertex, near_vertex, true) == red,
            @"far-then-near GEQUAL control must show red");
    const auto pixel = render(near_vertex, far_vertex, true);
    const bool correct = pixel == red;
    std::printf("ALWAYS/no-write and far-then-near controls PASS; near-then-far GEQUAL RGBA=%u,%u,%u,%u "
                "expected255,0,0,255 %s\n", pixel[0], pixel[1], pixel[2], pixel[3], correct ? "PASS" : "FAIL");
    std::puts("Depth transport uses source.z / 0xffffff and the staged GS TEST/ZBUF policy helper.");
    return correct ? 0 : 1;
  }
}
