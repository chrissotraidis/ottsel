# R1 — generated Direct fixture activation on validated route (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer/depth-state discriminator |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; clean signed app artifact |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; retained validated user pack |
| Before failure | Earlier fixture attempts ended before the renderer chain or left the trigger unconsumed, so the depth-state comparison had no attributable activation point. |
| Change | No product source change. Preseeded the existing START, Cross, and generated Direct-fixture triggers in the durable validated-pack container. |
| Focused proof | Runtime logged `OTTSEL METAL DIRECT: fixture accepted image=2x2 rect=0.375,0.375,0.25,0.25 cpu-raster=0` at `CHAIN 0`. The retained Simulator unified log then captured `2026-08-20 10:06:32.959`: `Direct draw contract draws=1 triangles=2 ... depth=gequal/write ... final-target=same-pass`. This is the generated in-memory fixture, not protected game texel data. |
| Live proof | The native Direct draw was submitted, but no visible result was established. At `10:06:33.133` Metal reported `MTLCommandBufferErrorDomain error 1` and at `10:06:34.195` the `SimMetalHost` XPC connection was interrupted. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Fault scan | `ottsel-fault.log` was 0 bytes. The unified log recovered the command-buffer abort and host interruption even though the app fault log and fresh diagnostic-report scan were empty. The Simulator was shut down afterward. |
| Verdict | OPEN / EXTERNALLY BLOCKED at the Metal command/resource or Simulator-host boundary — the ROM-free Direct fixture reaches the native draw contract with GEQUAL/write, so the earlier failure is not isolated to Sprite3's no-write state. R1 remains open. |
| Next gate | Isolate command-buffer validation/resource lifetime with this generated Direct fixture before changing Sprite3 depth semantics; retain the maintained GEQUAL/no-write contract unless a correctly adapted failing regression contradicts it. |

The Simulator remained blank/non-audible. No MAP_JIT, runtime executable
pages, external Metal shell, or Jak 2 game-specific source was imported.
