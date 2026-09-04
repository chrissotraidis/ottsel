# R1 live iPad visual/control evidence — 2026-08-22

This is fresh visual evidence from the single booted iPad Pro 11-inch (M4)
Simulator (`08636791-2675-4675-8335-EF72EF954DCF`) with one `OttselShell`
runtime (PID 76277). No macOS `gk` runtime was open.

## What the screenshots show

- `artifacts-2026-08-22-ipad-live-visual/ipad-village-live-104842.jpeg` is a
  fresh Village frame before keyboard input. The scene is partially
  recognizable, but large black/missing regions and several flat colored
  rectangles are visibly wrong.
- `.../ipad-village-after-wasdw-105003.jpeg` follows two native `W` key
  presses. The camera/scene visibly changes and the earlier colored rectangles
  are no longer in the frame.
- `.../ipad-village-after-wasdd-105012.jpeg` follows two native `D` key
  presses. The camera/scene visibly changes again.

These frames demonstrate that keyboard events reach the native runtime and
affect the rendered view. They do **not** demonstrate playability: the scene
remains materially incomplete and the title-wait → Start → Cross → Down×4 →
Cross route has not passed the visual/playability gate.

## Video limitation

A fresh `xcrun simctl io ... recordVideo --codec=h264` attempt was made on the
same Simulator. It failed before producing a file:

`Host recording is already in progress` (`NSPOSIXErrorDomain Code=16`).

This is recorded as an environment limitation, not as video evidence.

## Next source boundary

The screenshots confirm the requested visual inspection and the native WASD
path, while the remaining defect is renderer composition/material/depth state,
not a blank app or untested input path. Continue from the R1 source-side
trace; do not promote this frame to a playable-build claim or change camera,
TBP, shader, or Metal policy without a falsifiable source comparison.
