# I1 TIE BVH culling — 2026-09-03

Status: OPEN. The TIE producer now honors its own visibility BVH, but the
native scene is not yet coherent or playable.

Source mismatch corrected:

- TFRAG used packet frustum planes plus `vis_idx_in_pc_bvh` group ownership.
- TIE hard-coded `const bool is_visible = true`, submitting every group in the
  selected LOD. The implementation now computes node visibility from the same
  packet planes and applies the shared visibility helper.

Verification:

- Signed app executable SHA-256:
  `b1d4fdadb3a999dbdda9d1048f48a6c1c2979ca882757234d6c83980faf188df`.
- Full goalc suite passed: 782 tests from 51 suites.
- Village1 ledger changed from 3386/3386 groups to 2586/3386 selected groups;
  the mesh remained 511138 vertices and 253504 emitted triangles.
- Fresh frame: `/tmp/ottsel-video/bot36-tie-bvh-cull-2026-09-03.png`; SHA-256
  `278c33b7c0ed40adb825a147b9a5161346af25f96bcd88c748ccee9ab67d034e`.

Result: culling removes demonstrably out-of-view groups, but the frame still
has giant/edge geometry, missing actor/HUD/sky composition, and no playability.
The TIE camera/projection contract remains the next source-side comparison;
camera math in `set_mobile_tie_camera` stays unchanged. I1 remains OPEN.
