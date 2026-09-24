# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-24

Current gate: **G2 - runs on a physical iPad** (G1 met in the Simulator).

- Renderer: OpenGOAL's own OpenGL renderer runs on iOS over GLES 3.0 (`OTTSEL_RENDERER=gl`); the title
  screen matches macOS with 0 GL errors ([evidence](evidence/G3/upstream-gl-renderer-title-2026-09-24.md)).
  Next: touch overlay on the GL path, intro run, then GL becomes the default and `metal_gfx.mm` is deleted.
- G1: all 518 code modules signed; `OTTSEL_STRICT_EXEC` makes runtime code loading fatal; the whole intro
  plays to Geyser Rock in strict mode with 0 aborts ([evidence](evidence/G1/g1-all-code-signed-strict-2026-09-24.md)).
- Device build: `OTTSEL_PLATFORM=device` builds strict. To install: sign in to Xcode with an Apple ID
  (Personal Team), connect the iPad, then set `OTTSEL_SIGN_IDENTITY`/`OTTSEL_PROVISIONING_PROFILE`.
- Lane: iPad Pro 11-inch (M4) `08636791`; `/tmp/ottsel-tools/full.sh <tag>` (polled session);
  GL lane: build with `OTTSEL_RENDERER=gl`, install `out/jak-project/out/ios-gl/app/OttselShell.app`.

## Log (last eight lines)

2026-09-23 G0: checkpoint commit, one-patch reconstruction verified, BOT/recovery docs archived to history/.
2026-09-23 G1: device build mode added; it confirmed 170 unsigned level modules; coverage meter landed.
2026-09-24 G1.1: Training signed (350); packs carry compiled DGOs; next MIS.DGO (22 modules now linked at runtime).
2026-09-24 G1.2: Misty signed (372); streamed levels exempt from list order; art twins declined; route runs no unsigned code.
2026-09-24 G1.3: real IOP on iOS; fake-IOP GOAL workarounds reverted; streamed reload; the full intro plays to Geyser Rock.
2026-09-24 G1 met: 518/518 signed, strict exec on, intro to Geyser Rock with 0 aborts; fake IOP and overlays deleted.
2026-09-24 Renderer: upstream OpenGL renderer on GLES 3.0 (shaders cross-compiled); title matches macOS, 0 GL errors.
