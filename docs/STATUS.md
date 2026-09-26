# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). The log below keeps its last eight lines.

## Board - 2026-09-24

Current gate: **G2 - runs on a physical iPad** (G1 met in the Simulator).

- Renderer: OpenGOAL's own OpenGL renderer on OpenGL ES 3.0 from ANGLE on Metal (kivy/angle-builder
  chromium-7151, fetched by build-ios.sh). Simulator: title and Training both ~58 fps at full 2420x1668
  (merc skinning bones come from a texture, so ANGLE no longer re-encodes a Metal argument buffer per
  draw). `OTTSEL PERF` logs the frame split. Title matches macOS, 0 GL
  errors, and the whole intro plays to Geyser Rock with the touch overlay drawn over it
  ([evidence](evidence/G3/upstream-gl-renderer-title-2026-09-24.md)). The Metal renderer is deleted (last: `df31425`).
- G1: all 518 code modules signed; `OTTSEL_STRICT_EXEC` makes runtime code loading fatal; the whole intro
  plays to Geyser Rock in strict mode with 0 aborts ([evidence](evidence/G1/g1-all-code-signed-strict-2026-09-24.md)).
- Device: waiting on the user. Sign in to Xcode with an Apple ID (Personal Team), connect and trust the
  iPad, enable Developer Mode, then run `scripts/install-ios-device.sh /tmp/ottsel-user-pack-strict1`.
- Touch: SunPad's controller and three-dot menu in UIKit (`src/shell/touch_controls.mm`): sticks with
  dead zone, slide-between face buttons and D-pad diagonals, haptics, SunPad's Touch Control Settings
  panel and move/resize editor; menu: Display, FPS counter, Controls, Game Data (import), Diagnostics.
  `scripts/test-ios-touch.sh <udid>` plays title -> LOAD GAME -> Training -> walk -> jump+attack by touch.
- The `iphoneos` build links OpenGLES with all 92 translated shaders. Next: a level transition.
- Lane: iPad Pro 11-inch (M4) `08636791`; `/tmp/ottsel-tools/full.sh <tag>` (polled session).

## Log (last eight lines)

2026-09-24 ANGLE: GLES on Metal; Simulator Training 1-2 -> 23-25 fps full-res; unsigned vertex inputs fixed for Metal.
2026-09-24 Title streaks: Sprite3 strip+restart joined sprites on ANGLE/Metal; quads now drawn as triangles. Clean title/menu.
2026-09-25 Speed: merc bones in a texture (Training 25 -> 58 fps, draw 36 -> 8 ms); per-frame menu trace removed (log flood).
2026-09-25 Floating move stick; bone textures rotate (no Merc pass breaks); trace-file polls throttled (game thread -12%); ninja build 25 -> 12 min, rebuild ~4.
2026-09-26 Public prep: ISC LICENSE, notices, issue forms, icon; internal archive (1,031 files) out of the tree; host regressions green again.
2026-09-26 TV output (external scene, hot-plug); Jump to Level; stack save 256->512 fixes the jungle hopper fault; all 16 levels load, 0 faults.
2026-09-26 Sandover pause-menu save -> cold relaunch -> Load resumes village1-hut; leaving the app now returns to the pause menu; audio mixing (peak ~2500).
2026-09-26 L2/R2 touch buttons (button cheat codes now possible by touch); ••• → Cheats toggles OpenGOAL's 14 cheats, checked live.
