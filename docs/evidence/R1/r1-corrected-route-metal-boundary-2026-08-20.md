# R1 — corrected title route normal-Metal boundary (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 renderer parity; corrected title/save/Village1 route |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; clean signed app SHA-256 `bc10f91b8e97b684d491313c31d1a57ac994af86443e07ec490770deb9ff128f` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one normal-Metal runtime; validated local user pack; audio probes disabled |
| Before failure | SDL-only proof reached Village1 after the required second Cross save-slot step; the next product discriminator was the same route with normal Metal. |
| Change | No product behavior change. Installed the clean signed app, copied the validated user pack, enabled `OTTSEL_PREPARE_DATA_BEFORE_METAL=1`, and replayed the route. |
| Focused proof | Clean GOAL rebuild passed 338 targets; focused compiler/Direct/Sprite3/input slice passed 18/18; strict codesign passed. |
| Live proof | Normal Metal reached `GAMEPLAY: enter title` after durable pack import and kernel/object linking, but did not reach `title-play received wait` during the bounded run. Therefore no input was accepted and no Village1/native Sprite3 parity claim is made for this run. |
| Fault scan | `ottsel-fault.log` remained 0 bytes. The Simulator was blank and non-audible; no screenshot, audio, or playability claim is made. |
| Verdict | OPEN — this reproduces the existing normal-Metal startup/drawable liveness boundary before the corrected gameplay route. |
| Next gate | R1 Metal startup discriminator: isolate the first post-`GAMEPLAY: enter title` stop with the existing pre-Metal/host diagnostics, then replay the corrected route only after `title-play received wait` is retained. |

This run did not import MAP_JIT, runtime executable pages, external AOT,
Jak 2 game changes, or the external Metal shell.
