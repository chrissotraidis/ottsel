# D3 native Metal Direct fixture — 2026-08-19

## Ledger

| Field | Result |
|---|---|
| Gate | D3 — minimum native-Metal Direct draw |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; latest signed Simulator binary SHA-256 `c5084e4d85e072e1b25bd9ffe995fe82fe90dba73b602edcc5c331cefd0444c6` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, one booted Simulator |
| Before failure | The D1 generated Direct contract had no native Metal consumer; current presentation began with the CPU-composed frame upload |
| Change | Added an opt-in Metal Direct fixture pipeline in `metal_shell.mm`, keyed native texture retention for decoded texture pages, and the missing PC_PORT font texture relocation seam in `metal_gfx.mm`. The fixture bypasses the CPU frame upload and draws a six-vertex normalized quad through a Metal texture/sampler. |
| Focused proof | `scripts/build-ios.sh` — signed app build PASS; `goalc-test --gtest_filter='DirectFixture.*'` — 6/6 PASS |
| Live proof | The static fixture trigger produced the centered checkerboard: [fixture screenshot](d3-native-metal-fixture-2026-08-19.png). A fresh replay uploaded real decoded page textures into the keyed Metal cache (`id=0x1cf:122`, `0x2:48`, `0x370:1`, `0x100:3`, `0x4fe:4`, `0x3e:12`, `0x5fc:10`), then the maintained PC_PORT font relocation callback retained all four source/format variants: `0x2786→0x3800` (PSMT4HL), `0x2746→0x3800` (PSMT4HH), `0x28c6→0x3980` (PSMT4HL), and `0x27c6→0x3980` (PSMT4HH). The D0 `0x3980/0x24` Direct replay logged `texture upload source=relocated-vram size=256x512 image-checksum=32990107`; runtime observed the real glyph geometry `IR geometry accepted x=31104 y=33856 right=31488 bottom=34112 st=(0.379,0.377)..(0.469,0.438) rgba=(0,0,0,128) cpu-raster=0`. Metal received `prim=0x5c`, `tex0=0x2004280662413980`, `tex1=0`, `clamp=0`, `frame=0`, `alpha=0`, `test=0`, `zbuf=0`, `texa=0`, and `texture-lookup=hit`; it selected `sampler=nearest/repeat`, `blend=enabled` from `PRIM.ABE`, applied `scissor-emitted=false`, drew 2 triangles in 1 draw, and appended the Direct primitive in the same final render pass while preserving the existing TFRAG/TIE scene: [same-pass screenshot](d3-live-ir-metal-2026-08-19.png). |
| Fault scan | `ottsel-fault.log` was 0 bytes; no crash/assert/validation marker was observed in the runtime log |
| Packed RGBAQ boundary | Confirmed against the maintained desktop `DirectRenderer`: packed R/G/B/A are read from byte offsets 0/4/8/12, not contiguous bytes 0/1/2/3. |
| Verdict | **OPEN** — native Metal now retains real decoded texture pages by GS key, performs the PC_PORT font relocation into the D0 `0x3980` key, consumes real D2 glyph geometry and RGBA, performs a TEX0-keyed lookup, derives the D0 nearest/repeat sampler and TCC=1/TFX=MODULATE texture combine, resets stale linked state, explicitly owns the D0 GEQUAL/depth-write state, selects the D0 ABE-enabled blend pipeline, matches the D0 alpha/test/zbuf/frame defaults for a 1-draw/2-triangle result, and appends to the existing final composition with zero CPU-raster contribution. Non-default alpha-fail/depth/color-mask/fog semantics, broader primitive semantics, and final image parity remain before D3 can pass. |
| Next gate | R1 continuation — expand retained Sprite3 records into Metal GPU buffers and remove CPU-frame presentation before any D4 claim |

The fixture is deliberately opt-in and generated entirely in memory; it does
not alter the normal TIE/TFRAG scene or add protected game data.

Raw replay lines are preserved in
[`d3-live-ir-metal-2026-08-19.log`](d3-live-ir-metal-2026-08-19.log).
