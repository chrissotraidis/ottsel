#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

// Generated verbatim from metal_shell.mm by the runner: actual shader and ABI.
#include "tie_shader_source.inc"

static void require(bool condition, NSString* message) {
  if (!condition) {
    std::fprintf(stderr, "ERROR: %s\n", message.UTF8String);
    std::exit(2);
  }
}

int main() {
  @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    require(device != nil, @"host Metal device unavailable");
    NSError* error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:kTieShaderSource options:nil error:&error];
    require(library != nil, [NSString stringWithFormat:@"actual shader compilation: %@", error]);

    MTLVertexDescriptor* layout = [MTLVertexDescriptor vertexDescriptor];
    const MTLVertexFormat formats[] = {MTLVertexFormatFloat3, MTLVertexFormatFloat2,
                                      MTLVertexFormatUShort, MTLVertexFormatUChar4,
                                      MTLVertexFormatFloat};
    const NSUInteger offsets[] = {offsetof(OttselTfragFixtureVertex, x),
                                  offsetof(OttselTfragFixtureVertex, s),
                                  offsetof(OttselTfragFixtureVertex, color_index),
                                  offsetof(OttselTfragFixtureVertex, rgba),
                                  offsetof(OttselTfragFixtureVertex, nor)};
    for (NSUInteger i = 0; i < 5; ++i) {
      layout.attributes[i].format = formats[i];
      layout.attributes[i].offset = offsets[i];
      layout.attributes[i].bufferIndex = 0;
    }
    layout.layouts[0].stride = sizeof(OttselTfragFixtureVertex);
    MTLRenderPipelineDescriptor* descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.vertexFunction = [library newFunctionWithName:@"tie_vs"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"tie_fs"];
    descriptor.vertexDescriptor = layout;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor
                                                                               error:&error];
    require(pipeline != nil, [NSString stringWithFormat:@"pipeline creation: %@", error]);

    MTLTextureDescriptor* target_descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                    width:33 height:33 mipmapped:NO];
    target_descriptor.storageMode = MTLStorageModeShared;
    target_descriptor.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> target = [device newTextureWithDescriptor:target_descriptor];
    MTLTextureDescriptor* white_descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                    width:1 height:1 mipmapped:NO];
    white_descriptor.storageMode = MTLStorageModeShared;
    white_descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> white = [device newTextureWithDescriptor:white_descriptor];
    require(target && white, @"texture allocation failed");
    const unsigned char white_pixel[] = {255, 255, 255, 255};
    [white replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
              withBytes:white_pixel bytesPerRow:4];
    MTLSamplerDescriptor* sampler_descriptor = [MTLSamplerDescriptor new];
    sampler_descriptor.minFilter = MTLSamplerMinMagFilterNearest;
    sampler_descriptor.magFilter = MTLSamplerMinMagFilterNearest;
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:sampler_descriptor];
    id<MTLCommandQueue> queue = [device newCommandQueue];
    require(queue && sampler, @"queue or sampler allocation failed");

    unsigned char palette[3][4] = {{64, 0, 0, 64}, {0, 64, 0, 64}, {0, 0, 64, 64}};
    OttselTfragFixtureVertex vertices[3] = {
        {-0.75f, -0.75f, 0.f, {64, 0, 0, 64}, 0.5f, 0.5f, 0, 0, 0},
        { 0.75f, -0.75f, 0.f, {0, 64, 0, 64}, 0.5f, 0.5f, 0, 0, 0},
        { 0.f,    0.75f, 0.f, {0, 0, 64, 64}, 0.5f, 0.5f, 0, 0, 0}};
    TieUniforms uniforms{};
    uniforms.projection_mode = 2;
    TieMaterial material{0.f, 2.f, 0u, 0u, 0u, 0u};
    float merc_lighting[3][4] = {{1.5f,0,0,.125f},{0,.5f,0,.125f},{0,0,.25f,.125f}};
    const uint32_t merc_order[3] = {2,0,1};
    id<MTLBuffer> merc_indices = [device newBufferWithBytes:merc_order length:sizeof(merc_order)
                                                  options:MTLResourceStorageModeShared];
    require(merc_indices != nil, @"index allocation failed");
    auto render_center = [&]() -> std::array<unsigned char, 4> {
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
      [enc setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
      // Reserved bindings also support resolution in the vertex stage.
      if (material.merc) [enc setVertexBytes:merc_lighting length:sizeof(merc_lighting) atIndex:2];
      else [enc setVertexBytes:palette length:sizeof(palette) atIndex:2];
      [enc setVertexBytes:&material length:sizeof(material) atIndex:3];
      [enc setFragmentBytes:palette length:sizeof(palette) atIndex:0];
      [enc setFragmentBytes:&material length:sizeof(material) atIndex:1];
      [enc setFragmentTexture:white atIndex:0];
      [enc setFragmentSamplerState:sampler atIndex:0];
      if (material.merc) [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:3
                  indexType:MTLIndexTypeUInt32 indexBuffer:merc_indices indexBufferOffset:0];
      else [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      [enc endEncoding];
      dispatch_semaphore_t finished = dispatch_semaphore_create(0);
      [cb addCompletedHandler:^(id<MTLCommandBuffer>) { dispatch_semaphore_signal(finished); }];
      [cb commit];
      require(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
              @"GPU completion timed out after 10 seconds");
      require(cb.status == MTLCommandBufferStatusCompleted && !cb.error,
              [NSString stringWithFormat:@"GPU completion failure: %@", cb.error]);
      std::array<unsigned char, 4> pixel{};
      [target getBytes:pixel.data() bytesPerRow:4 fromRegion:MTLRegionMake2D(16, 16, 1, 1)
          mipmapLevel:0];
      return pixel;
    };
    const auto control = render_center();
    require(std::abs(int(control[0]) - 128) <= 2 && control[1] <= 2 && control[2] <= 2 && control[3] >= 253,
            [NSString stringWithFormat:@"uniform palette control failed: %u,%u,%u,%u",
                                       control[0], control[1], control[2], control[3]]);
    vertices[1].color_index = 1;
    vertices[2].color_index = 2;
    const auto pixel = render_center();
    // Desktop tfrag3.vert resolves each vertex's table entry, then smoothly
    // interpolates RGBA. Center weights are 1/4, 1/4, 1/2; RGB *= 2, alpha *= 4.
    const int expected[] = {32, 32, 64, 255};
    bool matches = true;
    for (int i = 0; i < 4; ++i) matches &= std::abs(int(pixel[i]) - expected[i]) <= 2;
    std::printf("uniform-control=PASS; actual center RGBA=%u,%u,%u,%u; expected=32,32,64,255 tolerance=2\n",
                pixel[0], pixel[1], pixel[2], pixel[3]);
    std::puts(matches ? "PASS: actual shader interpolates resolved TOD colors"
                      : "FAIL: actual shader does not interpolate resolved TOD colors");
    if (!matches) return 1;

    palette[0][3] = 0;
    palette[1][3] = 32;
    palette[2][3] = 64;
    material.alpha_min = 0.5f;
    const auto alpha_pixel = render_center();
    require(std::abs(int(alpha_pixel[0]) - 32) <= 2 &&
                std::abs(int(alpha_pixel[1]) - 32) <= 2 &&
                std::abs(int(alpha_pixel[2]) - 64) <= 2 &&
                std::abs(int(alpha_pixel[3]) - 160) <= 2,
            @"interpolated alpha must pass 0.5 threshold and produce alpha 160");
    material.decal = 1;
    const auto decal_pixel = render_center();
    require(decal_pixel[0] >= 253 && decal_pixel[1] >= 253 && decal_pixel[2] >= 253 &&
                std::abs(int(decal_pixel[3]) - 160) <= 2,
            @"decal must preserve texture RGB and interpolated alpha");
    material.decal = 0;
    material.alpha_min = 0.75f;
    require(render_center() == std::array<unsigned char, 4>{0, 0, 0, 0},
            @"interpolated alpha must fail 0.75 minimum threshold");
    material.alpha_min = 0.f;
    material.alpha_max = 0.5f;
    require(render_center() == std::array<unsigned char, 4>{0, 0, 0, 0},
            @"interpolated alpha must fail 0.5 maximum threshold");

    // Actual MERC float stream uses physical vertex_id, including indexed draws.
    // Dark texture keeps the HDR red1.5 contribution below output saturation.
    const unsigned char dark_pixel[] = {64,64,64,255};
    [white replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:0
              withBytes:dark_pixel bytesPerRow:4];
    material.alpha_max = 2.f;
    material.merc = 1;
    const auto merc_pixel = render_center();
    const int merc_expected[] = {48,16,16,128};
    for (int i=0;i<4;++i) require(std::abs(int(merc_pixel[i])-merc_expected[i])<=2,
        [NSString stringWithFormat:@"indexed HDR lighting mismatch: %u,%u,%u,%u expected48,16,16,128",
         merc_pixel[0],merc_pixel[1],merc_pixel[2],merc_pixel[3]]);
    std::puts("PASS: terrain controls unchanged; MERC indexed HDR float lighting=48,16,16,128");
    int material_failures = 0;
    auto material_check = [&](bool ok, const char* label) {
      std::printf("%s: %s\n", ok ? "PASS" : "FAIL", label);
      material_failures += !ok;
    };
    // Independent merc2.frag oracle: decal alpha ignores lighting alpha.
    material.decal = 1;
    const unsigned char half_alpha_pixel[] = {64,64,64,128};
    [white replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:0
              withBytes:half_alpha_pixel bytesPerRow:4];
    const auto merc_decal = render_center();
    std::printf("MERC decal actual RGBA=%u,%u,%u,%u expected64,64,64,255\n",
                merc_decal[0],merc_decal[1],merc_decal[2],merc_decal[3]);
    material_check(std::abs(int(merc_decal[0])-64)<=2 && merc_decal[3]>=253,
            "MERC decal alpha independent of lighting");
    material.decal = 0;
    [white replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:0
              withBytes:dark_pixel bytesPerRow:4];
    for (auto& light : merc_lighting) light[3] = .03175f; // final alpha .127
    material.alpha_min = 0.f; material.alpha_max = 2.f;
    material_check(render_center()==std::array<unsigned char,4>{0,0,0,0},
            "MERC .127 rejected despite permissive background AREF");
    material.merc_ignore_alpha = 1;
    const auto ignored = render_center();
    material_check(std::abs(int(ignored[3])-32)<=2 && ignored[0]>0,
            "MERC mask retains .127 alpha");
    material.merc_ignore_alpha = 0;
    for (auto& light : merc_lighting) light[3] = .03225f; // final alpha .129
    material.alpha_min = .75f; material.alpha_max = .1f;
    material_check(std::abs(int(render_center()[3])-33)<=2,
            "MERC .129 passes despite rejecting background bounds");
    for (auto& light : merc_lighting) light[3] = .032f; // exact cutoff .128
    material_check(std::abs(int(render_center()[3])-33)<=2,
            "MERC .128 cutoff equality passes");
    // Terrain retains bounds even if a stray MERC mask bit is present.
    material.merc = 0; material.merc_ignore_alpha = 1;
    material.alpha_min = .75f; material.alpha_max = 2.f;
    require(render_center()==std::array<unsigned char,4>{0,0,0,0},
            @"terrain alpha handling must remain independent of MERC mask");
    std::printf("MERC material GPU failures=%d\n", material_failures);
    if (material_failures) return 1;
    std::puts("PASS: MERC decal/fixed cutoff/ignore-alpha and terrain isolation");

    return 0;
  }
}
