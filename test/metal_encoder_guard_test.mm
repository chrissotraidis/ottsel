#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstdlib>

#include "../src/shell/metal_encoder_guard.h"

// Only endEncoding is exercised: no device, GPU, or Simulator is needed.
@interface GuardTestEncoder : NSObject
@property(nonatomic) NSUInteger endCount;
- (void)endEncoding;
@end

@implementation GuardTestEncoder
- (void)endEncoding {
  self.endCount += 1;
}
@end

static void expect_count(GuardTestEncoder* encoder, NSUInteger expected, const char* phase) {
  if (encoder.endCount != expected) {
    std::fprintf(stderr, "%s: expected %lu endings, got %lu\n", phase,
                 (unsigned long)expected, (unsigned long)encoder.endCount);
    std::exit(1);
  }
}

int main() {
  @autoreleasepool {
    GuardTestEncoder* normal = [GuardTestEncoder new];
    {
      RenderEncoderEndGuard guard((id<MTLRenderCommandEncoder>)normal);
      expect_count(normal, 0, "open scope");
    }
    expect_count(normal, 1, "normal scope exit");

    GuardTestEncoder* explicit_end = [GuardTestEncoder new];
    {
      RenderEncoderEndGuard guard((id<MTLRenderCommandEncoder>)explicit_end);
      guard.end();
      guard.end();
      expect_count(explicit_end, 1, "repeated explicit end");
    }
    expect_count(explicit_end, 1, "destructor after explicit end");

    GuardTestEncoder* objc_unwind = [GuardTestEncoder new];
    bool caught_objc = false;
    @try {
      RenderEncoderEndGuard guard((id<MTLRenderCommandEncoder>)objc_unwind);
      @throw [NSException exceptionWithName:@"GuardRegression" reason:@"injected" userInfo:nil];
    } @catch (NSException* exception) {
      caught_objc = [exception.name isEqualToString:@"GuardRegression"];
    }
    if (!caught_objc) return 1;
    expect_count(objc_unwind, 1, "Objective-C exception unwind");

    GuardTestEncoder* cpp_unwind = [GuardTestEncoder new];
    bool caught_cpp = false;
    try {
      RenderEncoderEndGuard guard((id<MTLRenderCommandEncoder>)cpp_unwind);
      throw 42;
    } catch (int value) {
      caught_cpp = value == 42;
    }
    if (!caught_cpp) return 1;
    expect_count(cpp_unwind, 1, "C++ exception unwind");

    GuardTestEncoder* ended_unwind = [GuardTestEncoder new];
    @try {
      RenderEncoderEndGuard guard((id<MTLRenderCommandEncoder>)ended_unwind);
      guard.end();
      @throw [NSException exceptionWithName:@"GuardRegression" reason:@"after end" userInfo:nil];
    } @catch (NSException* exception) {
      (void)exception;
    }
    expect_count(ended_unwind, 1, "Objective-C unwind after explicit end");

    {
      RenderEncoderEndGuard nil_guard(nil);
      nil_guard.end();
      nil_guard.end();
    }
    std::puts("PASS: encoder scope, explicit end, Objective-C/C++ unwind, exactly-once, nil");
  }
}
