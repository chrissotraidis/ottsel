# R1 native Sprite3 GPU readback — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `bad297dc54d8ddb99e53c4acf04e5da60bf5c74f1fb8b027ed8d578eafaad845`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The Simulator surface is blank and earlier Sprite3-gated readback attempts produced no fresh artifact, leaving native pixels uninspected. |
| Change | Added trigger-scoped present/resource markers to distinguish queued, drained, and ready Sprite3 resources. The existing one-shot drawable readback remained diagnostic-only. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep codesign verification passed; `git diff --check` passed. |
| Live proof | The producer reached candidate 0 with bounds `(0.438,0.484)..(0.617,0.788)`. The ready marker recorded `texture=64x64`; the present marker recorded `spriteActive=0 pendingSprite=1` before the bounded drain. A fresh `1210x834` PPM was then produced from the actual drawable. Converted artifact inspection shows the yellow native Sprite3 flare over the shell text. |
| Fault scan | `ottsel-fault.log` was 0 bytes. No `BOOT FAILED` marker appeared in the bounded scan. Temporary marker/trigger files were removed after capture. |
| Artifact | [GPU readback image](r1-native-sprite-gpu-readback-2026-08-20.png), SHA-256 `8255efdb30078193fafeed9dea4d762eb86d25d1c5e08e45c202e7a09ce0bdc1`. |
| Simulator boundary | The Simulator UI remained blank and non-audible. This is direct GPU drawable evidence, not Simulator screenshot evidence, audio proof, or playability proof. |
| Verdict | OPEN / PARTIAL R1 — native Sprite3 pixels are now directly observed in the drawable, but desktop comparison, title/menu/Village1/Training bucket parity, and normal untoggled product behavior remain open. |
| Next gate | Compare this native readback against a same-phase macOS/fixture image and extend the bounded GPU consumer only after the state/order differences are recorded. |
