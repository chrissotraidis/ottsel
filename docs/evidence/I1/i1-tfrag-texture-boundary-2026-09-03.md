# I1 TFRAG texture, residency, and visibility correction — 2026-09-03

Status: OPEN. TFRAG texture ownership and snapshot-time BVH frustum culling
are exercised, but scene correctness, orientation, and playability remain
unproven.

Before-fix regressions: `MobileTfragRejectsOutOfRangePositiveTextureIds`,
`MobileMeshWaitsForTextureResidency`, and
`MobileTfragUsesRemappedBvhVisibilityGroups` failed before their helpers or
guards existed. The rebuilt `PlatformInput.*` suite passes 31/31.

Texture change: `build_visible_mobile_tfrag_mesh` drops positive IDs outside
the level-owned texture vector. Metal mesh promotion waits for pending texture
uploads; negative animated IDs and camera/TBP/lookup/strip code are unchanged.

Residency evidence: signed build/codesign passed. Live logs recorded promotion
waits at 16, 32, 48, and 64 pending uploads, followed by a stable Village1
snapshot. This proves ordering-guard execution, not a complete fix.

Earlier synchronized route reached Village1 and produced large diagonal/white
bands. Valid root-level no-TIE/no-MERC isolation retained the same bands, and
a draw-limit=1 run stayed corrupted, implicating individual TFRAG submission.

Position ledger: tree 0 draw 0 had finite XYZ `(-801984,-65474,-657473)` to
`(811775,212736,901374)`, with no invalid indices or triangle-count mismatch.
Decoded position storage is not proven wrong.

Visibility change: upstream culls each group through its remapped BVH parent;
native previously used `const bool is_visible = true`. The native pass now
tests each BVH sphere against the packet frustum before flattening groups.

Signed build: `out/jak-project/out/ios/app/OttselShell.app`.
Fresh frame: `/tmp/ottsel-video/bot36-tfrag-bvh-cull-2026-09-03.png`.
SHA-256: `1d02eb08e405e8aa0f47942a04ebe83c846780d27c86aa05371dcce47407b084`.

Live result: Village1 changed from 84 batches/62,504 triangles to 81
batches/53,924 triangles. The inspected frame contains recognizable huts,
palms, rocks, and platforms; giant banding largely collapsed. Black gaps,
incorrect orientation/composition, debug rectangles, and Jak control proof
remain open. The snapshot reports 138/256 visible nodes and 712/837 groups.

Camera-rebuild experiment: regression failed before the change, suite passed
31/31, and codesign passed. Rebuilds produced 56–78 batches and `pcm-peak=10791`,
but the frame regressed to sparse rectangles; SHA-256
`a3099751f7a13ebcccb47a49e505031b657d7706eb4744cab6383d44afa7a743`.
Reject this policy. After moving stale scene triggers, clean normal and
no-CPU-frame routes still showed sparse rectangles, so CPU fallback is not yet
the demonstrated cause. Retain packet-frustum culling; I1 remains OPEN.
Per-draw visibility was rejected: group splits destroyed strip continuity, and
conservative original-draw masks still left sparse fragments. Frames:
`/tmp/ottsel-video/bot36-tfrag-perdraw-2026-09-03.png` (SHA-256
`209f32803006290a35b2ae4348bec7f012cf35efaba6ba4baf5cacdda10490f3`) and
`/tmp/ottsel-video/bot36-tfrag-conservative-perdraw-2026-09-03.png`
(SHA-256 `af836ec1139c525bc42b97485e0e386b3ace567431e59051f8e0bef3a96438fa`).
Both implementations were reverted; preserve upstream contiguous visible runs.
Queue-liveness: before the fix only the title mesh reached Metal; after
deduplicating static texture-slot enqueueing, Village1 TFRAG (76,264
vertices/53,924 triangles) and TIE (511,138/359,812) uploaded. Fresh frame:
`/tmp/ottsel-video/bot36-tfrag-upload-dedupe-2026-09-03.png`; SHA-256
`984fdaa604facc0d6524dbff2dd34e9556fadc61c9f347eb032a85e3a5f8cb37`.
