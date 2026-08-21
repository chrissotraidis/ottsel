# R1 bucket-67 native world visibility retest — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 phase-specific native Sprite3 composition/readback |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `0a59e57670cc502cae179a6c3185db1dbad5344135bb78f6a8db30691b00a597` |
| Environment | One iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; resumed active Village1 state, not a fresh canonical title route; shut down after probe |
| Before failure | The existing bucket-67 native probe had previously uploaded no candidates on a valid Village1 phase and had no fresh readback artifact. |
| Change | No product code change. Triggered only `ottsel-trace-mobile-sprite-bucket67-world-metal` and `ottsel-dump-native-sprite-metal`; the current phase-specific fixture/visibility gate remained unchanged. |
| Focused proof | Current `Sprite3Native.*` suite passed 14/14; prior signed build verification passed. |
| Live proof | The runtime examined 320 bucket-67 world candidates at `chain=10007`, `vsync=10008`, all using the retained `TBP=0x2c8d` world tuple. Candidate bounds ranged from tiny in-view rectangles such as `(0.734,0.605)..(0.741,0.615)` to wholly out-of-clip records; all 320 failed `usable=false`. The final marker was `fixture-uploaded=false cpu-product-frame=0`. |
| Readback | No native mesh was uploaded, so no fresh Sprite3 readback was produced. The existing PPM remained unchanged at SHA-256 `ef30ac092987cd9ac9c7e074f930b14868e24996f86c7e24dc52dd17b05e9da1`. |
| Fault scan | `ottsel-fault.log` was 0 bytes; no Metal validation/crash/assert marker was observed. The Simulator surface remained blank/non-audible. |
| Verdict | OPEN. The current native seam correctly refuses an unattributable tiny/offscreen candidate; relaxing the visibility gate would be a speculative transform/phase change. This run is diagnostic evidence only and is not canonical route or playability proof. |
| Next gate | Compare the retained `0x2c8d` tuple’s stable mobile transformed bounds and frame timing against an explicitly captured macOS source tuple, then either add a proven producer/frame-state fix or define the smallest native fixture that can produce a same-phase image. |

The resumed-state qualification is intentional: the process was already at
active Village1 when the probe was armed. It must not be used as a replacement
for a fresh title-to-Village1 parity replay.
