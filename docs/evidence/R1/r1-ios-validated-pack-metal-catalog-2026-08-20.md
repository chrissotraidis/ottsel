# R1 iPad validated-pack Metal Sprite3 catalog — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `24f594362b81bad49da489fe8a67bb8470d40a74c6b24da834acf22d1adc70ea` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5; one normal-Metal runtime; host-sandbox delivery of a locally prepared validated pack; no macOS runtime concurrent |
| Before failure | Earlier R1 catalogs used bundle/fallback data and reached only a different phase. The missing legal-pack boundary had to be removed before interpreting a normal-Metal Sprite3 catalog. |
| Live proof | Runtime logged `OTTSEL F1: imported validated user pack`, then the diagnostic `(bg 'village1)` call returned. The native Sprite3 catalog logged 32 candidates using TBPs `0x2bc1` and `0x2bd3` (PSM 19); usable candidates included repeated `0x2bc1` groups. Native upload remained trigger-gated and CPU raster was skipped. |
| Comparison | The captured macOS reference bucket is TBP `9458` (`0x24f2`), absent from this validated-pack shortcut phase. No wider batch or parity claim is justified. |
| Fault scan | `ottsel-fault.log` was 0 bytes. This run produced no logged Metal command-buffer/SimMetalHost abort. |
| Route boundary | The separate real input replay consumed Start/Cross/Left and reached title-wait, but its PC progress transition stalled on invalid pending objects before `GAMEPLAY: enter village1`; this shortcut run is not New Game proof. |
| Simulator boundary | Simulator remained blank/non-audible; this is direct runtime/catalog diagnostics only, not visual playability, audio, or Files UI acceptance. |
| Verdict | OPEN — validated data makes the normal-Metal Sprite3 catalog stable, but the emitted phase still does not match macOS and the real menu route remains unresolved. |
| Next gate | Fix or isolate the title-menu pending-progress transition with the validated pack, then capture the same accepted New Game/Village1 phase before selecting a Sprite3 batch. |

