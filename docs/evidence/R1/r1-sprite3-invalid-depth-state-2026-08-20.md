# R1 — validated-pack Metal route exposes a broader command-buffer boundary (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; existing clean signed app SHA-256 `bc10f91b8e97b684d491313c31d1a57ac994af86443e07ec490770deb9ff128f` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; macOS `26.5.2 (25F84)`; one runtime at a time |
| Before failure | No-Sprite normal-Metal replay produced repeated drawable presents with a 0-byte fault log. The next bounded validated-pack/game-resource replay needed to determine whether the route reproduced the host boundary. |
| Change | No product source change. Reused the durable validated user pack, enabled pre-Metal preparation, and preseeded the existing Village1/Sprite3/readback diagnostic triggers. |
| Focused proof | Runtime logged validated-pack import, selected data root, and normal Metal startup. The app fault log remained 0 bytes; no Sprite3 candidate was emitted before the host abort. |
| Live proof | No screenshot, PPM, visual, audio-quality, or playability claim. The Simulator remained blank/non-audible. |
| Fault scan | Fresh `/Users/chrissotraidis/Library/Logs/DiagnosticReports/OttselShell-2026-08-20-094607.000.ips` is `EXC_CRASH`/`SIGABRT`, termination namespace `METAL`, code `102`, caused by the first-party host connection interruption. Matching `/Users/chrissotraidis/Library/Logs/DiagnosticReports/SimMetalHost-2026-08-20-094607.ips` reports `METAL` code `100`: `Invalid depth stencil state`, while submitting the command buffer from simulator process PID `75259`. |
| Verdict | OPEN / EXTERNALLY BLOCKED at the Metal command/resource or Simulator-host boundary. The earlier code-100 report is real, but the later Direct fixture independently reached a native `GEQUAL`/write draw contract before the command buffer aborted. The failure is therefore not isolated to Sprite3's no-write state, and it does not justify changing the maintained depth contract. |
| Next gate | Isolate command-buffer validation/resource lifetime with the generated Direct fixture and unified-log capture. Keep Sprite3's `GEQUAL`/no-write mapping unchanged unless a correctly adapted failing regression contradicts it. |

The maintained Jak 1 contract remains GEQUAL with Sprite3 depth writes
disabled. No MAP_JIT, runtime executable pages, external Metal shell, or Jak 2
game-specific source was imported.

The retained unified log adds the missing discriminator: the Direct fixture
submitted `draws=1`, `triangles=2`, `depth=gequal/write`, and
`final-target=same-pass` at `10:06:32.959`, then Metal aborted the command buffer
at `10:06:33.133` and the SimMetalHost connection was interrupted at
`10:06:34.195`. This proves native draw submission but no visual result, and
reclassifies the open failure as broader Metal command/resource or Simulator
host behavior rather than a Sprite3-only depth-write issue.
