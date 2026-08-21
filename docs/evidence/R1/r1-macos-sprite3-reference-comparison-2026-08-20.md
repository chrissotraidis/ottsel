# R1 macOS Sprite3 reference comparison — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | macOS reference log `out/jak-project/log/jak1.2026-08-19T20-15-51.log`, compiled OpenGOAL `641fb572e`; native iPad artifact from signed executable `bad297dc54d8ddb99e53c4acf04e5da60bf5c74f1fb8b027ed8d578eafaad845` |
| macOS reference | Frame 6 records Sprite3 group 0 with 48 blocks / 2304 world sprites, then multiple draws: 23 sprites at TBP 9458, 125 at TBP 9509, 17 at 9513, 6 at 9505, 16 at 9710, and further 2D draws. The reference also records 24 sampled item/state records and GEQUAL/depth/blend modes. |
| iPad evidence | The deterministic native GPU readback submits one selected candidate at texture `0x2bc1` (`64x64`), six native vertices, normalized alpha `0.8448`, and CPU-raster skip; its artifact is byte-stable across two fresh replays. |
| Comparison | These are not the same identified texture/bucket or a same-phase full-route capture. The iPad artifact proves the native GPU seam and one visible Sprite3 result; it does not prove the desktop 2304-sprite route, bucket ordering, or visual parity. |
| Screenshot context | Existing desktop reference image: [bucket-66 scene](r1-bucket66-sprite-metal-2026-08-19.png). It is supporting macOS context, not an A/B match for the selected iPad flare. |
| Fault scan | The macOS runtime was stopped after the bounded reference run; no Simulator was booted concurrently. Existing reference warnings and the separate Simulator crash dialog are not reclassified as product passes. |
| Verdict | OPEN — macOS reference coverage is materially broader than the current one-candidate iPad diagnostic consumer. |
| Next gate | Retain and batch the deterministic Sprite3 records by bucket/texture/state, then compare one identified macOS TBP/draw group against the native readback before widening normal product presentation. |

