# I1 Merc camera ordering — 2026-09-03

Status: OPEN. The targeted ordering change is safe but does not fix the
rendering failure.

Question:

- Does consuming a camera-sized PC_PORT packet before Merc on the same
  transfer prevent stale-camera clipping?

Change:

- `gfx_send_chain` now calls `capture_mobile_camera` before
  `capture_mobile_merc` for camera-sized PC_PORT transfers, in both the fast
  path and the bounded Jak 1 bucket path.
- This preserves the packet-level scene owner and cannot alter camera math.

Regression:

- Full goalc suite passed: 782 tests from 51 suites.
- Signed app executable SHA-256:
  `be42a7723a4b60e5be3bcfaaef65ff7749fc6b98585be7abd709d20c474b1e17`.

Fresh iPad Simulator run:

- Frame: `/tmp/ottsel-video/bot36-merc-camera-order-2026-09-03.png`.
- Frame SHA-256: `a1e4efe86ee9809a495c59a685f7eb3dca6c87ab5d4a48bee5fdf2f60a00d47e`.
- `eichar-lod0` was submitted (9942 vertices, 2253 triangles), but arrived
  before the first Village1 camera packet: `camera-level='title'`,
  `visible=0`; Village1 markers followed later.
- PCM became nonzero (peak 11068); no fault was reported.

Conclusion: same-transfer ordering is not the root cause. The actor packet
must be staged or bound to the later packet-level camera before composition.
The frame remains non-playable and the I1 gate is OPEN.
