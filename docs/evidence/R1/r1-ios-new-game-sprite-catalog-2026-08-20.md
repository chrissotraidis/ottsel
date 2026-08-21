# R1 iPad title/New Game route catalog — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `2b72134f8e3a8fd76d49850b656c271b35decca9e8138fd8ae81193bfc13bb5e` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one fresh installed app; no macOS runtime concurrent |
| Before failure | The prior catalog used a direct `ottsel-bg-village1` shortcut and emitted TBPs `0x2bc1`/`0x2bd3`, not the macOS reference TBP `0x24f2`. The next falsifiable check was the real title/New Game trigger route without that shortcut. |
| Change | No product source change. Replayed `ottsel-press-start`, then Cross triggers, with the Sprite3 catalog enabled and pre-Metal data preparation active. |
| Focused proof | Existing signed app installed successfully; `ottsel-fault.log` was 0 bytes in the app's SDL preference directory. |
| Live proof | The runtime reached `Displaying level title [display]` and `GAMEPLAY: enter title`. The catalog emitted a usable native candidate at index 2, TBP `0x2506`, PSM 19, with a `64x64` texture and CPU raster skipped. The first 32 candidates contained `0x2506`, `0x2518`, and zero/invalid entries; no `0x24f2` appeared. No `GAMEPLAY: enter village1` or `Displaying level village1` line was observed, and the Cross trigger remained unconsumed at teardown. |
| Fault scan | Runtime fault log: 0 bytes. The Simulator system log separately recorded a Metal command-buffer abort/SimMetalHost interruption during the failed launch attempt; this prevents a clean product-renderer verdict for that attempt. |
| Simulator boundary | The Simulator was blank/non-audible. This is route/state diagnostics only, not title/menu, visual-playability, or audio proof. |
| Verdict | OPEN — the real route reached title and a different Sprite3 phase, but did not reach Village1 or emit the macOS-identified bucket. Do not broaden batching. |
| Next gate | Isolate the title-menu input/Metal-host failure and make the Cross trigger observable on the exact writable preference path, then repeat the real route before selecting any matched Sprite3 group. |

