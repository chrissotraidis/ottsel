# R1 TFRAG strip-run boundary correction R18 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native TFRAG composition |
| Source change | In `src/shell/metal_gfx.mm`, preserve a `UINT32_MAX` strip restart after every visible TFRAG visibility group. |
| Before failure | The OpenGL reference submits each contiguous visible group run as a separate triangle-strip multi-draw; the native flattening concatenated adjacent visible groups, allowing cross-group triangles. Earlier frames showed valid-index, oversized/dislocated geometry. |
| Build | `scripts/build-ios.sh` passed; signed app passed `codesign --verify --deep --strict`. |
| Environment | One booted iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; one `com.ottsel.shell` runtime. |
| Route | Durable validated pack; synchronized title-wait-ready → Start → Cross → Down×4 → Cross; Village1 entered twice. |
| Fault/audio | Fault log 0 bytes; audio mix remained non-audible (`pcm-peak=0`). |
| Verdict | OPEN — visual composition improved in the fresh live frame, but large missing/black regions remain and playability is not proven. |

## Fresh visual evidence

- [direct Simulator Village1 frame](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/fresh-village1-after-w.jpeg)
- [simctl screenshot](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/fresh-village1-simctl.png)
- [runtime log](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/ottsel-runtime.log)
- [fault log](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/ottsel-fault.log)
- [TFRAG-isolated frame](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/isolation-no-tfrag.jpeg)
- [TIE-isolated frame](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/isolation-no-tie.jpeg)
- [no-depth probe frame](artifacts-2026-08-22-ipad-r1-tfrag-strip-restart-r18/isolation-no-depth.jpeg)

The fresh direct Simulator frame shows a textured ground and bounded scene
surfaces without the prior long cross-group strip stretching across the
scene. It still has major blue/black missing regions and is not an honestly
playable frame. The route and runtime counters therefore remain diagnostic
evidence only.

The isolation captures are attribution evidence, not product frames: the
TFRAG-disabled view retains thin stretched bands, while the TIE-disabled view
is effectively blank. The no-depth trigger did not produce a usable scene
comparison in this live window. This keeps the next source boundary at TIE /
depth/material composition rather than authorizing another camera or texture
remap.

## Decision

Retain this narrow strip-run correction for the next composition experiment.
It changes no lookup, TBP, camera, resource allocation, or TFRAG camera sign.
The next boundary is remaining TFRAG/TIE material/depth ordering and missing
Direct/Sprite composition; do not call R1 or P2 complete.
