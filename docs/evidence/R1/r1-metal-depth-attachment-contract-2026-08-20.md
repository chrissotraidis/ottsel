# R1 Metal depth-attachment contract — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The native Direct/Sprite pipeline rendered into the same `Depth32Float` pass attachment as TIE/TFRAG, but its pipeline descriptor did not declare a depth-attachment pixel format. Earlier Simulator host reports showed `MTLSimulator_encountered_CPU_error` / `submitCommandBuffer` boundaries during native composition. |
| Change | Declared `directPd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float` to match the bound pass attachment and depth state. |
| Focused proof | `goalc-test --gtest_filter='Sprite3Native.*'` passed 4/4 after the change; `scripts/build-ios.sh` completed previously for this source; strict deep codesign verification passed for `out/jak-project/out/ios/app/OttselShell.app`. |
| Live proof | One bounded rebuilt Metal launch prepared the durable user-data root, loaded title and Village1 FR3 data, consumed the synthetic background trigger, and ended with a zero-byte app fault log. It did not emit a native Sprite3 draw. |
| Host result | Fresh `SimMetalHost` reports at 06:54 still show `EXC_BAD_ACCESS` in `MTLSimApplicationContext::deleteObject`; the depth-format change is therefore not a demonstrated host-stability fix. |
| Simulator boundary | The Simulator was blank and non-audible; no image, audio, or playability proof is claimed. It was shut down after the replay. |
| Verdict | OPEN — the pipeline/pass format contract is now explicit, but the remaining host/resource teardown boundary and native Sprite3 route are unresolved. |
| Next gate | Isolate the remaining invalid resource/command lifetime or capture a later native Sprite3 draw, then compare a stable native/desktop fixture or checksum. |

