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
- Device (G2): runs on a physical iPad Pro 12.9-inch (M2), iPadOS 27.0.1, at 2732x2048 and 60 fps, by
  touch and with an Xbox Series X controller, 0 faults ([evidence](evidence/G2/g2-first-ipad-hardware-run-2026-10-10.md)).
  Open: iPhone hardware, long sessions (heat, battery), a full play-through on device.
- Touch: SunPad's controller and three-dot menu in UIKit (`src/shell/touch_controls.mm`): sticks with
  dead zone, slide-between face buttons and D-pad diagonals, haptics, SunPad's Touch Control Settings
  panel and move/resize editor; menu: Display, FPS counter, Controls, Game Data (import), Diagnostics.
  `scripts/test-ios-touch.sh <udid>` plays title -> LOAD GAME -> Training -> walk -> jump+attack by touch.
- The `iphoneos` build links OpenGLES with all 92 translated shaders. Next: a level transition.
- Lane: iPad Pro 11-inch (M4) `08636791`; `/tmp/ottsel-tools/full.sh <tag>` (polled session).

## Log (last eight lines)

2026-09-26 Metal pass breaks: sky + time-of-day palettes rotate, palettes upload in one call, unchanged eyes not redrawn. Swamp 34 -> 44 fps.
2026-09-26 Texture packs proven: extractor fixed (tcc assert); apply-texture-pack.sh builds a modded pack and restores the original.
2026-09-26 Crash on quit fixed (audio pause after static teardown); iPhone 16 Pro Simulator boots to title with the full touch layout.
2026-09-26 Sprite/shadow buffers updated in place (no Metal buffer per flush). Sweep: 16 levels 47-59 fps, 0 faults.
2026-09-26 Audio dump clean (menu silence is the game pausing sound); TV cold/unplug/replug re-checked; README in the KartPad style with Discord.
2026-09-26 Sprites no longer stall on ANGLE restart scans; one 60 Hz pacer; palettes upload only when time of day moves. 12 of 16 levels at 60 fps; the rest are Simulator-GPU bound (51-57). 0 faults.
2026-10-10 First physical iPad run (iPad Pro 12.9 M2): intro, Geyser Rock, Sandover at 60 fps, 0 faults; controller hides/shows the touch controls; START drags in the editor; ••• menu in BlueWake order; new ottsel icon.
2026-10-11 Voice hints silenced all audio (heard on iPad): the iOS boot skipped goal_main's masterConfig.volume = 100, so scf-get-volume gave 0 and every hint ducked music, effects and dialogue to 0. Fixed in ios_boot.cpp; the same Geyser Rock hint now plays at full level (Simulator, per-second PCM peaks 4900-5700 vs 0).
