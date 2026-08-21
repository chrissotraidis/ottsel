# AU1 bounded VAG refill producer probe — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | AU1 |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app SHA-256 `9b17be01a6633174dd893cd51c32e95aa158087ad64e298fb0828313ae339edd` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF` |
| Input | Validated F1 user pack; long-form `SA3INTRO` in `VAGWAD.ENG`, 4,298,096 data bytes, 175 aligned `0x6000` chunks, 48 kHz |
| Change | Seed a bounded preallocated sample with 8 chunks, then refill the remaining 167 chunks from one WAD handle on a producer thread while the guarded `snd::Voice` consumes the shared buffer. This is an opt-in diagnostic probe, not the product streaming path. |
| Focused proof | iOS build, strict codesign, focused GOAL/audio tests, and patch/diff checks passed before launch. |
| Live proof | Runtime logged `VAG refill producer started ... initial-chunks=8 total-chunks=175`, then `producer finished ... chunks=175 bytes=4298096`. Nonzero mixed PCM was recorded at windows 8/10/20/30/40/50 with peaks `7684`, `5321`, `4466`, `7692`, `6396`, `6594`. |
| Fault scan | `ottsel-fault.log` was 0 bytes. Existing blank-Simulator VIS/RAMDISK diagnostics remain unrelated. |
| Simulator boundary | The Simulator is blank and provides no audible acceptance. This run proves only transport, guarded decode, producer completion, and nonzero mixed PCM; it does not prove rendered game content, speaker/headphone/Bluetooth routing, interruption behavior, or human playability. |
| Verdict | OPEN — bounded producer/refill behavior is demonstrated, but this diagnostic uses a preallocated shared buffer and is not yet product streaming/route/device proof. |
| Next gate | Integrate a product-owned bounded stream queue/consumer seam, then verify lifecycle, route, and physical-device behavior separately. |

The live runtime log was captured from the Simulator container during the run; the relevant lines are retained in the app's `ottsel-runtime.log`.
