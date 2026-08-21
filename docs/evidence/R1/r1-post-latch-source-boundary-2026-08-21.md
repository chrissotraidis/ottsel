# R1 post-latch Sprite3 source boundary — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/phase ownership |
| Source/build identity | Outer checkout `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `a3af1793efce65018e3829358bb49740e0805388079485167aa07bf39823da69` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `3C4B5E9C-3D88-4358-B60B-4911B4883D26`; normal Metal; Simulator shut down after capture |
| Before failure | The post-latch aggregate showed a variable 3D-bearing phase, but its producing chain and source ownership were not identified. |
| Change | No product-source change. Ran the marker-synchronized Start/Cross/Down×4/Cross route and armed `ottsel-trace-mobile-sprite-source-boundary` after current-boot Village1 entry. |
| Focused proof | Current boot logged `start edge in title-wait`, `GAMEPLAY: enter village1` twice, and a complete 8-item source-boundary trace. `ottsel-fault.log` was 0 bytes. |
| Live proof | Chains 1000–1003, VSYNC 1001–1004, each began at transfer 13 with `MSCAL=3`, 48 sprites, `TBP=0x2bc1`, PSM 19, 64x64, followed by a 16-sprite zero-texture tail at transfer 14. Frame transfer was 9, matrix transfer 12, and camera-source transfer 470 on each chain. |
| Verdict | OPEN — this valid window contains no `MSCAL=211`/mobile 3D family; together with the prior aggregate it demonstrates phase-window variability, not a justified remap. The Simulator remained blank/non-audible. |
| Next gate | Arm the same source-boundary trigger before route entry so the first eligible Village1 chain is captured, then compare its source chain/table against the macOS `MSCAL=211` → `MSCAL=3` sequence. |

This is producer/phase evidence only. It is not visual, audio, or playability
acceptance.
