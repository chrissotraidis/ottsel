# R1 native per-draw fog/decal contract experiment R26 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native material composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed executable `f1611e10401919f5f28c2412adf8f98d5466a56755a6baeae6cd3cd6100e2587` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `86769` |
| Before failure | OpenGL carries per-draw fog and decal bits in `DrawMode`; Metal applied fog unconditionally and did not implement decal color selection. |
| Change | `src/shell/metal_shell.mm`: `TieMaterial` now carries per-draw fog/decal flags. Metal only applies fog when source fog is enabled and uses decal texture-color behavior when source decal is enabled. Alpha and all geometry-slot fixes remain retained. |
| Focused proof | `scripts/build-ios.sh` completed and strict bundle signing passed. |
| Live proof | Fresh F1-imported validated pack reached `title-wait-ready`, accepted Start → Cross → Down×4 → Cross, reached Village1 twice, and consumed the no-CPU-frame trigger. Fresh inspected frame: `artifacts-2026-08-22-ipad-live-visual/ipad-fog-decal-no-cpu-0316.jpeg`. |
| Video | Fresh 4-second Simulator recording succeeded: `artifacts-2026-08-22-ipad-live-visual/ipad-fog-decal-no-cpu-0316.mov`. |
| Fault/audio | `ottsel-fault.log` was 0 bytes. Mobile audio remains unaccepted/unproven. |
| Verdict | OPEN — the frame is material-bearing but still a close ground view with detached/missing geometry; no playable iPad parity is established. |
| Next gate | Implement and compare the remaining live material state: source alpha-fail/depth-write behavior and enabled blend modes, then Direct/Sprite/sky/effect composition. |

## Source basis

OpenGL `setup_opengl_from_draw_mode` and `tfrag3.vert` make fog and decal
per-draw state. The native consumer now carries those bits alongside the
alpha threshold instead of treating the entire TFRAG/TIE stream as one global
material. No TBP, lookup, camera, or global Metal policy was changed.

## Visual boundary

The screenshot and video were actively captured from the Simulator. The
scene remains explicitly partial/non-playable: close framing, detached upper
surfaces, missing world composition, no accepted audio, and no player/HUD
proof. Build success, route markers, and nonzero native geometry remain
diagnostic evidence only.

## Supersession note

R26 is not an accepted material result. The first implementation retained an
old alpha-scale fragment after introducing the combined material expression,
so that binary applied the alpha/RGB multiplier twice. R27 removed the
duplicate and is the authoritative fog/decal rerun; do not use the R26 frame
or video for parity or playability claims.
