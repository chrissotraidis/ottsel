# R1 — fresh SimMetalHost deletion crash (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal startup/drawable liveness |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; clean signed app SHA-256 `bc10f91b8e97b684d491313c31d1a57ac994af86443e07ec490770deb9ff128f` |
| Environment | iPad Pro 11-inch (M4) Simulator on MacBookAir10,1; macOS `26.5.2 (25F84)`; CoreSimulator `SimMetalHost` build `1051.55`; report `SimMetalHost-2026-08-20-092411.ips` |
| Before failure | A fresh normal-Metal validated-pack replay reached `GAMEPLAY: enter title` but stopped before `title-play received wait`; the app fault log remained empty. |
| External evidence | Apple’s `SimMetalHost` report has `EXC_BAD_ACCESS` / `SIGSEGV` at address 0 in `MTLSimApplicationContext::deleteObject(NSObject<OS_xpc_object>*)`, on the XPC connection thread. The report records `consecutiveCrashCount=5`; no Ottsel frame appears in the faulting stack. |
| Focused proof | Clean GOAL rebuild passed 338 targets; focused compiler/Direct/Sprite3/input slice passed 18/18; strict codesign passed. |
| Verdict | EXTERNALLY BLOCKED for this normal-Metal replay boundary, not for the full product goal. The evidence identifies a first-party Simulator rendering-service crash, not a proven Ottsel renderer defect. |
| Next gate | Run one minimal no-Sprite drawable/resource-lifetime replay and compare its host report before changing product Metal ownership or lifecycle code. |

The Simulator remained blank and non-audible. This report is host-crash
evidence only; it is not visual, audio, or playability proof. No MAP_JIT,
runtime executable pages, external AOT, Jak 2 source, or external Metal shell
was imported.
