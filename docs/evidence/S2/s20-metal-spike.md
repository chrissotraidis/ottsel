# S2.0 evidence — Metal spike: first frame through a CAMetalLayer pipeline

Date: 2026-08-09. Gate: **S2.0 PASS (sub-gate, declared)** — the iOS shell
now delivers its rendered surface through a real Metal pipeline on the iPad
Pro 11-inch (M4) Simulator (iOS 18.5). This is the Metal spike milestone of
Gate S2 (first frame). It is **not** yet a frame from Jak 1 game systems —
that remains S2.1/S2.2 and is stated as such in `docs/STATUS.md`.

## What was built

- `src/shell/metal_shell.mm` — minimal CAMetalLayer renderer: `MTLCreateSystemDefaultDevice`,
  command queue, a fullscreen textured-triangle pipeline (runtime-compiled
  Metal shaders), a per-frame `MTLTexture` upload of the CPU log surface, and
  `presentDrawable` via the SDL3 Metal view (`SDL_Metal_CreateView` +
  `SDL_Metal_GetLayer`, UIKit `CAMetalLayer` on iOS).
- `src/shell/metal_shell.h` — C interface so `main.cpp` stays plain C++.
- `src/shell/main.cpp` — renders the log surface into a CPU RGBA buffer
  sized to the CAMetalLayer drawable each frame (re-queried per frame; the
  pre-layout drawable size is 480x320 and the layer reports the same size
  for the app's windowed presentation on this simulator), then presents it
  through Metal. SDL software surface retained as fallback.
- `scripts/build-ios.sh` — compiles `metal_shell.mm` with `-fobjc-arc` and
  links it.

## Bugs found and fixed while proving the spike

1. **Pre-layout drawable size.** At creation the CAMetalLayer reported
   480x320; the final window keeps that size in this simulator's windowed
   presentation. The surface is re-queried every frame, so rotation or
   window resize is handled (no hard-coded size).
2. **Landscape buffer in a portrait layer stretched the frame** (vertical
   rain). Fixed by sizing the CPU surface to the actual drawable.
3. **The S1 log font was clipped all along**: `font5x7.h` rows use 7
   bit-columns (LSB = leftmost, bit 6 = rightmost; e.g. `'o'` =
   0x38/0x44/0x44/0x44/0x38 draws its sides at bits 2 and 6), but the draw
   loop used `kFontW = 5`, dropping bits 5-6 of every glyph. Every S1/S2
   log-surface character was subtly clipped. Fixed `kFontW` to 7.

## Pixel-level verification (prove, don't assert)

The presented CPU surface (`s20-metal-surface.ppm`, written by the app) was
compared pixel-for-pixel against an offline render of the same strings from
the same font table, at the same scale (3):

| Line | Expected pixels | Matched | Result |
|---|---|---|---|
| title `ottsel S2.0 - Metal` | 1746 | 1746 | 100% |
| `GPU path: Metal` | 1566 | 1566 | 100% |

The Simulator screenshot (`s20-metal-frame.png`) shows the app window
presenting this surface through Metal; the console confirms
`ottsel S2.0: Metal surface active (CAMetalLayer)` and
`drawable 480x320 font scale 3`. The runtime booted to the GOAL kernel
dispatcher loop as before (56,800+ iterations, zero faults;
`s20-runtime.log`).

## Evidence files

- `s20-metal-frame.png` — Simulator screenshot (device context).
- `s20-metal-surface.ppm` — exact presented CPU surface (RGBA PPM).
- `s20-metal-surface.png` / `s20-metal-surface-4x.png` — surface as PNG,
  and a 4x nearest-neighbor upscale for inspection.
- `s20-runtime.log` — boot + dispatcher iteration log for the run.

## Honest boundaries

- S2.0 proves the Metal pipeline in the shell, not game-renderer output.
- Simulator evidence is never device proof (physical-device validation and
  signing remain open).
- The app window is the simulator's default windowed presentation
  (~480x320 drawable); no `SDL_WINDOW_FULLSCREEN` is used anywhere.

## Files changed (this sub-gate)

- `src/shell/metal_shell.h` (new), `src/shell/metal_shell.mm` (new)
- `src/shell/main.cpp` (Metal presentation path, dynamic surface size,
  kFontW 5 -> 7 fix, surface PPM debug dump)
- `scripts/build-ios.sh` (compile/link the .mm renderer)
- `docs/evidence/S2/s20-*` (this evidence set)
- `docs/STATUS.md`, `docs/00-loop-log.md`, `docs/13-current-state.md`
