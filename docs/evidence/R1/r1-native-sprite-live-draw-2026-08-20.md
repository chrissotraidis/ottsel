# R1 native Sprite3 live draw — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `83ddd5b1a97950b19db9aa4e89498de745000ba25a424c2e40cbc2d624ff255e`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | Earlier bounded Metal replays reached Village1 but emitted no native Sprite3 line, so the trigger-gated GPU path had not been live-proven. |
| Change | No product-source change in this slice. Preseeded the existing writable `ottsel-trace-mobile-sprite-metal` and `ottsel-bg-village1` diagnostic triggers to isolate the native Sprite3 route. |
| Focused proof | Existing `Sprite3Native.*` regression passed 4/4; current signed app installed successfully. |
| Live proof | Two fresh launches with `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` reached the title/Village1 route and repeated the same native result: `probe accepted`, candidate `index=0`, finite bounds `(0.438,0.484)..(0.617,0.788)`, visible size `(0.179,0.304)`, `usable=true`, `native group=0`, `texture=0x2bc1`, `64x64`, `blend=enabled`, and `cpu-raster=skipped-for-native-candidate`. |
| Fault scan | `ottsel-fault.log` was 0 bytes. No app `BOOT FAILED`, unsupported, placeholder, or bounds marker was observed in the bounded scan. The Simulator host remains an independent diagnostic boundary; no new host report was created during this replay. |
| Simulator boundary | The Simulator remained blank and non-audible. No screenshot, image parity, audio, or playability claim is made. The device was shut down after the run. |
| Verdict | OPEN — native Sprite3 buffer ownership and a repeatable live draw submission are now proven, but final image visibility and desktop/iPad parity remain unproven. |
| Next gate | R1 image fixture: capture a stable same-phase native Sprite3 frame/counter contract and compare it with the macOS reference before widening the native consumer. |
