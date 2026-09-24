# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-24

Current gate: **G2 - runs on a physical iPad** (G1 met in the Simulator).

- Renderer: OpenGOAL's own OpenGL renderer is the only renderer (GLES 3.0). Title matches macOS, 0 GL
  errors, and the whole intro plays to Geyser Rock with the touch overlay drawn over it
  ([evidence](evidence/G3/upstream-gl-renderer-title-2026-09-24.md)). The Metal renderer is deleted (last: `df31425`).
- G1: all 518 code modules signed; `OTTSEL_STRICT_EXEC` makes runtime code loading fatal; the whole intro
  plays to Geyser Rock in strict mode with 0 aborts ([evidence](evidence/G1/g1-all-code-signed-strict-2026-09-24.md)).
- Device: waiting on the user. Sign in to Xcode with an Apple ID (Personal Team), connect and trust the
  iPad, enable Developer Mode, then run `scripts/install-ios-device.sh /tmp/ottsel-user-pack-strict1`.
- Touch: SunPad's controller design, ported to UIKit (`src/shell/touch_controls.mm`): stick views with
  thumbs, PlayStation face buttons, grouped D-pad, L1/R1/START, three-dot menu, drag-to-edit layout.
  `scripts/test-ios-touch.sh <udid>` plays title -> LOAD GAME -> Training -> walk with real touches.
- The `iphoneos` build links OpenGLES with all 92 translated shaders. Next: a level transition.
- Lane: iPad Pro 11-inch (M4) `08636791`; `/tmp/ottsel-tools/full.sh <tag>` (polled session).

## Log (last eight lines)

2026-09-24 G1.1: Training signed (350); packs carry compiled DGOs; next MIS.DGO (22 modules now linked at runtime).
2026-09-24 G1.2: Misty signed (372); streamed levels exempt from list order; art twins declined; route runs no unsigned code.
2026-09-24 G1.3: real IOP on iOS; fake-IOP GOAL workarounds reverted; streamed reload; the full intro plays to Geyser Rock.
2026-09-24 G1 met: 518/518 signed, strict exec on, intro to Geyser Rock with 0 aborts; fake IOP and overlays deleted.
2026-09-24 Renderer: upstream OpenGL renderer on GLES 3.0 (shaders cross-compiled); title matches macOS, 0 GL errors.
2026-09-24 Metal renderer deleted (71 files); GL is the only path; intro plays to Geyser Rock on it, 0-byte fault log.
2026-09-24 G2 prep: install-ios-device.sh (sign/provision/install/pack/launch); last GL ES error fixed; load -> Training, 0 GL errors.
2026-09-24 Touch: SunPad-style UIKit controller replaces the GL-drawn regions; XCUITest plays to Training by touch.
