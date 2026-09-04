# R1 unique-owner trace — 2026-08-23

| Field | Result |
|---|---|
| Gate | R1 producer/resource parity; OPEN |
| Source/build | Ottsel `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `4e10db5503838b0dbd96b0b70637d17e8b7fd99748f0ed89af40691d258a19b6` |
| Environment | One booted iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`, one runtime PID 74820 |
| Before failure | The owner/AdGif traces stopped after repeated raw `0x00200f00` records, preventing correlation with later owners. |
| Change | Diagnostic-only unique-raw bookkeeping in `sparticle_launcher.cpp`; input and AdGif-output sets are independent. No lookup, allocation, TEX0, TBP, camera, shader, or Metal policy changed. |
| Focused proof | `goalc-test --gtest_filter='PlatformInput.*'`: 5/5; source diff check passed; signed iOS build completed and deep codesign passed. |
| Live route | Fresh validated pack; title-wait → Start → Cross → Down×4 → Cross; Village1 entered twice. |
| Lookup | Post-title page-2 sequence: `54,49,48,42,44,24,25,10,41,30,34,9`, all logged as resident hits. |
| Correlation | Unique raw `0x00201e00` (page 2/index `0x1e`) and `0x00202200` resolve to AdGif TEX0 `0x2014cd655530a525`, matching native secondary `TBP=0x2525`. The first native group remains `TBP=0x24d2`, TEX0 `0x2004d2e59930a4d2`; no owner record yet ties that first native group to the later macOS `0x24f2` family. |
| Fault/audio | `ottsel-fault.log` was 0 bytes; callback/mix logs were present but `pcm-peak=0`, so audio is not accepted. |
| Visual proof | Fresh screenshot: `/tmp/ottsel-video/r1-unique-owner-route-20260823.png`; the scene is rotated/dislocated with oversized foreground geometry and missing regions. It is diagnostic/non-playable. |
| Verdict | OPEN. The trace-cap defect is closed; first-family producer/DMA ownership remains the next source-side discriminator. |
| Next | Trace the exact raw owner/AdGif/native first-group handoff for `0x24d2` versus macOS `0x24f2`; do not remap TBP or alter camera/shader/Metal policy. |
