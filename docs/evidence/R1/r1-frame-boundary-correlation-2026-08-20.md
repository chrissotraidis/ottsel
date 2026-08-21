# R1 frame-boundary correlation probe — 2026-08-20

## Why this gate exists

The macOS Sprite3 trace reports a complete renderer frame: 51 group-0
blocks / 2,432 sprites. The mobile bucket-66 logs reported individual DMA
submission summaries separated by seconds. Comparing those numbers directly
would therefore overstate a producer mismatch.

The runtime has a shared boundary seam: `Gfx::vsync()` invokes the active
renderer `vsync()` callback, while `send_gfx_dma_chain` independently submits
DMA chains. The iOS renderer previously returned `0` without recording that
relationship, so there was no honest way to assign a mobile Sprite3 fragment
to a frame epoch.

## Change

`src/shell/metal_gfx.mm` has a trigger-gated, eight-boundary diagnostic for
paths that reach the renderer module's `vsync()` callback. A fresh iPad route
falsified that as the mobile boundary: the trigger remained untouched even
while DMA chains arrived. The actual mobile implementation is the
`ios_stubs.cpp` `sceGsSyncV` stub, which already emits bounded
`OTTSEL IOS VSYNC` markers.

## Validation

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream worktree:
  `641fb572e876750d8618434d9f7c1a531b43b366`.
- Maintained patch SHA-256: `f0f8b907c26fce652899226055b83bc9f83176a8271b8d5e246ba2aef297cc14`.
- Rebuilt app executable SHA-256:
  `61102e7b72e5dbe998f967445b9b0cdfc5a530e37bb52158a6f76d860b7a1231`.
- `scripts/build-ios.sh` completed and produced the signed Simulator app.
- `codesign --verify --deep --strict` passed.
- The product executable scan found no `MAP_JIT`, runtime executable-page,
  or JIT-write markers.
- Focused native suite passed: 21/21 (`DirectFixture`, `Sprite3Native`,
  `PlatformInput`, `ARM64EmitterFloatMath`).
- The maintained patch regenerated and passed reverse-apply checking.
- A fresh Simulator title boot recorded `OTTSEL IOS VSYNC` calls 1–8 and 60;
  the log shows calls 2/3/4/6 interleaved with chain submissions 1/2/3/5.
  This proves the mobile frame seam exists and is ordered relative to DMA
  submission, but it does not yet provide a single numeric chain counter at
  the same call site.
- The rebuilt app then emitted the same-call-site record
  `OTTSEL SPRITE: chain=6 vsync=7 group-0 sprites=64`. This is a valid numeric
  join for a title-phase Sprite3 fragment; the replay did not reach Village1,
  so it is not a Village1 parity result.
- A subsequent title-marker-synchronized route reached
  `GAMEPLAY: enter village1` twice before the trace was armed. Four populated
  Village1 samples then stayed stable at 320 group-0 sprites, each with a
  one-count chain/vsync relationship:

  ```text
  chain=62812 vsync=62813 sprites=320
  chain=67036 vsync=67037 sprites=320
  chain=68420 vsync=68421 sprites=320
  chain=69657 vsync=69658 sprites=320
  ```

  The first three used the same bucket addresses (`debug=0x534960`,
  `next=0x532f30`); the fourth used the alternate buffer (`debug=0xd02960`,
  `next=0xd00f30`). The fault log was 0 bytes.
- The Simulator remains blank and non-audible.

## Next falsifiable slice

The numeric boundary is now sufficiently established for this route. The
next R1 slice is producer/consumer ownership: explain why a frame-aligned
mobile call stays at 320 world sprites while the same-route macOS complete
frame reports 2,432 group-0 sprites (51 blocks). Inspect the complete mobile
bucket/chain ownership and phase sequence; do not change camera, texture, or
shader semantics until that structural mismatch is falsified.

## Product interpretation

This keeps the platform split explicit. macOS has a broad renderer and a
bounded retail route, with audio stream/device/PCM liveness but no fresh human-
audible acceptance. iPadOS/iOS still has incomplete Metal composition and
mobile audio; iPhone parity and physical-device readiness remain open. The
Simulator provides route/liveness diagnostics only, not visual, audio, or
playability acceptance.
