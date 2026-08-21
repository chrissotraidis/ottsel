# R1 supplied iPad Simulator crash attribution — 2026-08-21

| Field | Result |
|---|---|
| Gate | Mobile runtime/link boundary before renderer acceptance |
| Source/build identity | Supplied report incident `9F989F66-E385-4913-B1BA-EFC00A6C5EAD`; app UUID `e92ddf2f-05eb-3c2f-985c-c1b57895d6a9`; bundle app container UUID `2130616C-C61C-4E58-9A4A-246FF65E27ED`; report timestamp 2026-08-20 22:00:59 -0500. This predates the current signed diagnostic executable. |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`, macOS 26.5.2 Simulator runtime, native arm64 |
| Observation | `EXC_CRASH (SIGABRT)` / abort trap 6. The crashing thread was thread 10 during boot. |
| Attribution | The crashing stack is `private_assert_failed` → `link_control::jak1_jak2_begin` → `jak1::link_begin` → `ottsel_ios_run_boot`. This is the existing GOAL object-header/version assertion boundary, not a Metal validation or Sprite3 renderer fault. The main thread separately appears in `MTLSimTexture replaceRegion` → `OttselMetalRenderer presentRGBA`, but it is not the triggered thread. |
| Related evidence | This matches the previously recorded blank/zero `beach-vis` linker diagnostic at `klink.cpp:77/81`, where the object name and version header were blank/zero. It does not establish a new renderer or camera defect. |
| Audio context | The report shows SDL audio threads, but no audible-output acceptance can be inferred from a crash report. |
| Verdict | OPEN at the linker/data boundary for that older run; not a new renderer regression. Preserve the assertion and continue attributing the missing/invalid object provenance before any GOAL-content workaround. |
| Next gate | Complete the current matrix-vsync correlation on the newly rebuilt app, then return to the producer phase-pair regression. |

The report was read in full. It does not prove playability, visual parity, audio, iPhone parity, or device readiness.
