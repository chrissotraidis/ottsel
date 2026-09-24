#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <cstddef>
#include <cstdio>
#include "sky_isolation_source.inc"
int main() {
  @autoreleasepool {
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();
    if(!device){std::fprintf(stderr,"No host Metal device\n");return 1;}
    #include "sky_isolation_extra.inc"
    NSError* error=nil;
    auto library=[device newLibraryWithSource:[kDirectFixtureShaderSource stringByAppendingString:extra] options:nil error:&error];
    if(!library){std::fprintf(stderr,"Shader compile failed: %s\n",error.description.UTF8String);return 1;}
    auto directLib=library;
    #include "sky_isolation_descriptors.inc"
    #include "sky_isolation_names.inc"
    unsigned compiled=0;
    for(unsigned blended=0;blended<2;++blended)for(NSString* name in names){
      MTLRenderPipelineDescriptor* pd=[(blended?directBlendPd:directPd) copy];
      pd.fragmentFunction=[library newFunctionWithName:name];
      auto pipeline=[device newRenderPipelineStateWithDescriptor:pd error:&error];
      if(!pipeline){std::fprintf(stderr,"Pipeline %s blend=%u failed: %s\n",name.UTF8String,blended,error.description.UTF8String);return 1;}
      ++compiled;
    }
    std::printf("PASS %u actual Sky isolation pipelines: full shader, layout, BGRA8/depth32 and both product blend states; no frame rendered\n",compiled);
  }
}
