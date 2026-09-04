# R1 native all-geometry-slot composition experiment R24 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native TFRAG/TIE composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed executable `9eed3a665a139903f450eefd291099581f5dc91fd8dc5f5291129d55aa4cad2d` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `83786` |
| Before failure | Native visibility builders hard-coded `geo = 0`, while maintained OpenGL TFRAG/TIE rendering iterates all `GEOM_MAX` geometry slots. The no-CPU frame remained partial, with detached/missing world regions. |
| Change | `src/shell/metal_gfx.mm`: native visible TFRAG and TIE snapshots now iterate every loaded geometry slot, preserving source tree/category/DrawMode/material/camera behavior. No TBP, lookup, camera, shader, or Metal policy remap was added. |
| Focused proof | `scripts/build-ios.sh` completed; strict bundle signing passed. The native logs reported `TFRAG geos=3 trees=9` and `TIE geos=4 trees=12` on the full Village snapshot. |
| Live proof | Fresh clean relaunch and file-driven title-wait → Start → Cross → Down×4 → Cross route on the one runtime. Fresh frames: `artifacts-2026-08-22-ipad-live-visual/ipad-all-geometry-clean-route-1147.jpeg` and settled `.../ipad-all-geometry-clean-settled-1148.jpeg`; no-CPU trigger was consumed. |
| Fault/audio | `ottsel-fault.log` was 0 bytes. No accepted mobile audio evidence; the route remains non-audible/unproven. |
| Video | A fresh second recording attempt was blocked by host `Resource busy` / `Host recording is already in progress`. The previously captured bounded video remains `.../ipad-clean-default-current-1131-attempt.mov`. |
| Verdict | OPEN — expanding geometry-slot coverage is source-aligned and increases native submissions, but the fresh route still shows detached/missing geometry and incorrect close framing. It does not establish playability or parity. |
| Next gate | Isolate the first missing native material/depth/composition state from this all-slot baseline; keep the all-slot source fix for the next comparison. |

## Source basis

The maintained OpenGL renderer loops `geom = 0 .. GEOM_MAX - 1` when loading
and rendering TFRAG/TIE trees. The native mobile builders previously selected
only slot zero. R24 closes that direct source-coverage mismatch without
changing resource identity or projection policy.

## Visual boundary

The full-snapshot frame was visibly more source geometry-bearing but still not
a playable game view. The exact-route settled frame moved into a close-up with
large detached surfaces and missing upper/scene content. The result therefore
does not justify removing the explicit blank/partial Simulator warning or
promoting any native composition gate.
