#pragma once

#import <Metal/Metal.h>

// End an open encoder on both normal scope exit and exception unwinding.
// Explicit completion is idempotent so the destructor cannot end it twice.
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
