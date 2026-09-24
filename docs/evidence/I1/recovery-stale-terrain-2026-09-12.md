# Stale terrain snapshot — 2026-09-12

Question: does Training retain terrain selected during the intro camera instead of the settled gameplay camera?
Source: `metal_gfx.mm` builds visible groups once; `mobile_scene_policy.h` explicitly ignores later plane changes. TIE and TFRAG can settle at different times.
Build/installed SHA256: `3a9e3062f93c6bfd07162f9bb10c9567eb1d09d9149cb0e5beccd750311bb08f`.
One iPad Simulator `08636791-2675-4675-8335-EF72EF954DCF`, PID50191, normal menu route through intro fallback to Training/game-start. No camera/input change between comparison screenshots.
At chain1099, one explicit `ottsel-refresh-tfrag-once` reran only TFRAG snapshot selection/upload using the current finite camera packet.
Observed: level remained training; groups9→208; vertices35996→35996; triangles504→19956; planes-changed=true; queued=true.
Before: `/tmp/ottsel-video/recovery-refresh-before.png` has a large black ground region.
After: `/tmp/ottsel-video/recovery-refresh-after.png` restores textured ground in that region. Actor attachments and other scene defects remain open.
Logs: `/tmp/ottsel-recovery-2026-09-12/refresh/ottsel-runtime.log`; fault log zero bytes at termination.
Conclusion: initial-camera visibility selection causes missing Training terrain. This is stronger evidence than earlier unisolated no-cull screenshots from different routes/builds.
Limit: builder reuploads vertices and indices, so this is not an index-only buffer experiment. It does not prove complete visibility, performance, actor correctness, sky, or multi-level composition.
Durable fix implemented: retain every valid visibility group in immutable TFRAG/TIE level geometry and let GPU clipping handle the view; keep camera motion uniform-only. Reintroduce CPU draw culling only with dynamic per-draw selection and measured need, never by permanently deleting initially hidden geometry.
Durable build/install SHA256 `c98bc778faa94605dde653437a44a2833e54a1f62ee4de13c966688f1b15afcb`, PID51240: fresh default normal route restores ground without trigger (`/tmp/ottsel-video/recovery-retention-training.png`).
Training retains373/373 groups,35996 vertices,28296 triangles; TIE1994/1994 groups,420700 vertices,289104 triangles. Settled refresh chain1208 and post-movement refresh chain3854 both keep these TFRAG counts unchanged despite changed planes.
Synchronized20-second `/tmp/ottsel-video/recovery-retention-controls.mp4` captures jump, forward and reverse movement with continuous ground; recorder closed cleanly. Frame6 shows Jak away from the spawn ring, frame12 returning; the ring remains a world object, refuting the earlier belt-deformation interpretation.
Typed control log `/tmp/ottsel-recovery-2026-09-12/retention-controls.log`: Cross sampled; targetY33864.50 then28345.16 with stableXZ during jump; forward/reverse displacement and neutral release follow. Fault log remained zero. App terminated; logs retained in `.../retention/`.
This closes the demonstrated stale-ground defect in one fresh run, not complete I0/I1 acceptance. Remaining: second run, broader traversal/camera/occlusion, sky/HUD/materials, actual frame-time/resource measurement, audio/lifecycle, signed-code delivery.

Multilevel follow-up: global family ownership rebuilt alternating resident levels and kept only the last family's mesh/palette. Actual-source regression first failed five ownership cases.
Fix: retain CPU/GPU geometry and TOD per level/family; capture the emitting bucket's camera; atomically promote completed frame refs and uploads. Allocation failure/incomplete textures keep the previous complete frame; unfinished future uploads cannot replace its palette.
`bash scripts/test-mobile-level-ownership.sh` passes resident reuse, pending/installed retention, superseded uploads, palette identity, allocation failures and frame-publication race controls.
Build/install SHA256 `650a9865a4b96a977e9c560ee1749a6261073df84d524bc670f36ae511f067aa`, PID67930, fresh normal route reached Training; snapshot count stayed7 through controls, versus209 in the earlier captured route (not a frame-rate comparison).
`/tmp/ottsel-video/recovery-multilevel-controls.mp4` is a closed20-second62MiB recording. Inspected frames6/12 show Jak moving away from and back toward the fixed spawn structure on continuous terrain. Input log confirms Cross/up/down and neutral releases.
Runtime logs preserved in `/tmp/ottsel-recovery-2026-09-12/multilevel-runtime/`; fault bytes0 at stop. Lighting differs from earlier captures and requires matched reference comparison; sky/materials remain visibly incomplete. Resident asset eviction/memory cap and presented-frame pacing remain open.

Sprite producer follow-up: build/install73efa0f18668770d9ea92e5bd54599beb3279308bceb130ed66155316cefe5dd, normal Training, focused World2D/3D depth/color/coverage/fade/rotation tests pass. Closed38MiB `/tmp/ottsel-video/recovery-sprite-consolidated-controls.mp4` shows movement away from and back to spawn ring at inspected seconds2/6/10; Cross and neutral releases logged. Fault bytes0 at stop; logs `sprite-consolidated-product-runtime/`, input `sprite-consolidated-input.log`. World/actor material and sky defects persist; these frames do not isolate visible benefit of each Sprite correction.

MERC lighting (2026-09-13): native capture now follows desktop weighted normal rotation/normalization and112-byte packet lights, carrying float4 pervertex without clamping HDR or overwriting skinW. Actual capture/queue/merge tests and six allocation-failure cases pass; both channels/camera replace only after complete allocation. Actual GPU indexed/HDR red8,8,16,255→green48,16,16,128; terrain alpha/decal/TOD controls unchanged. Root applied checks: `/tmp/ottsel-recovery-2026-09-12/merc-lighting-applied/verification.log`. Hash-matched builde1a35a24 reaches normal Training, recorded Cross/forward4s/reverse4s/release, fault0 at stop. Closed39MiB clip `/tmp/ottsel-video/recovery-merc-lighting-controls.mp4`; inspected2s/6s frames show Jak leaving spawn and reaching the adjacent sandy area. Hair/eye material artifacts and Sky remain open; this is lighting correctness, not full visual/pacing acceptance.

Sky retention/timing (2026-09-13): independent completed-bucket store passes replay, pending isolation, decode/texture/allocation rollback, replacement retirement, verified CALL empty and phase-exit checks (`sky-retention-applied/verification.log`). Hash-matched build6cd52f8b normal Training/PID9328 stops fault0. Three fresh Training captures remain black in the sky; retention does not close composition. A bounded Simulator probe receives300/300 successful CB callbacks, capped/missing/error/invalid counts0: CPU completion54.176Hz, GPU duration p50.216ms/p953.708ms, GPU start-interval p9528.392ms. These are command-buffer measurements, NOT display FPS. Raw evidence `/tmp/ottsel-recovery-2026-09-12/sky-retention-command-pacing.log` came from `simctl spawn <udid> log show`; host log store was empty. Actual Simulator drawable presentation timestamps remain unavailable.

Sky isolation75d25504/PID14775: normal Training, batch0 frozen vertices/32x32 texture/state; five successful CB completions. All five variants cover273906 pixels, including production direct_fs with the real colorful texture. Actual target1210x834; screenshot1668x2420. Captured z=0; this batch is visibly clipped into the viewport. Blanket sampler/off-screen hypothesis is refuted for this batch, not all Sky or normal composition. Raw vertices/texture/five PPMs/log preserved at `/tmp/ottsel-recovery-2026-09-12/sky-isolation-product-capture/`; process stopped, fault0. Next inspect normal depth/order and batch population.

Sky population1f1d78e1/PID19106:41 immutable batches; exact ordered prefixes4/35/36/37/41 with six successful readbacks, fault0. Prefix4 covers333960 pixels, meanRGB160.436; clouds through prefix35 preserve coverage but reduce mean to28.835. Last six black triangles alter ZERO covered sky pixels; they fill all675180 previously gray pixels below the horizon. Batches4–34 request GS ALPHA0x48 (Cs*As+Cd), while native uses source-over; desktop DirectRenderer.cpp509–517 explicitly uses source-alpha/ONE RGB and ONE/ZERO alpha. This supports an additive cloud-blend regression, not deleting black geometry or changing projection. Raw packet-derived batches/PPMs/state/CB log: `/tmp/ottsel-recovery-2026-09-12/sky-population-product-capture/`. Fix/GPU parity/live visual validation pending.

Sky blend parity table verified at source (2026-09-14, host-only read-only; gate closed, no build).
GS ALPHA decode: `GsAlpha::BlendMode` {SOURCE=0, DEST=1, ZERO_OR_FIXED=2}, a=bits0-1, b=bits2-3, c=bits4-5,
d=bits6-7, `fix()=data>>32` (common/dma/gs.h:205-220). ALPHA 0x48 -> a=SOURCE, b=ZERO_OR_FIXED, c=SOURCE,
d=DEST -> (Cs-0)*As+Cd, the additive case, confirming the population paragraph above independently.
Desktop oracle DirectRenderer.cpp:495-560 handles exactly six combos, else logs 'unsupported blend (direct)':
  S/D/S/D -> SRC_ALPHA,ONE_MINUS_SRC_ALPHA,ADD ; S/Z/S/D -> SRC_ALPHA,ONE,ADD (0x48) ;
  Z/S/S/D -> SRC_ALPHA,ONE,REVERSE_SUBTRACT ; S/D/Z/D -> CONSTANT_ALPHA,ONE_MINUS_CONSTANT_ALPHA,ADD,
  blendColor fix/127 ; S/S/S/S -> disable blend ; S/Z/D/D -> DST_ALPHA,ONE,ADD, color_mult 0.5.
Native gap: no GsAlpha decode reaches policy. metal_gfx.mm:3387 `primitive.blended = gp.abe()`; :3388
`primitive.diagnostic_alpha = st.alpha` under 'Observability only; no blend policy change'; both blend pipelines
are hardcoded Add + SourceAlpha/OneMinusSourceAlpha (metal_shell.mm:925-930 direct, 1039-1044 tie), and no
a/b/c/d/fix field of GsAlpha is read anywhere in src/. Correction to the earlier reading: TIE does consult the
extracted 3-bit `DrawMode::AlphaBlend` ((mode>>24)&7; gs.h:419-451) via `ottsel_mobile_alpha_blend_enabled`
(mobile_scene_policy.h:120-123, called metal_shell.mm:1752), which maps additive enum 2 SRC_0_SRC_DST to
source-over as well; only 0 and 6 are excluded. So the cloud prefix is Direct branch 2 and both decoders are needed.
Fix site is already plumbed: `NativeSpriteBatch.diagnostic_alpha` (metal_shell.mm:334) carries each batch's ALPHA_1
value to the draw loop (set :2803, `append_sky_mesh_n` :3925, appended :4397), so no new per-batch field is needed.
Bounded fix: decode a/b/c/d(+fix) from the per-batch diagnostic_alpha already carried to the draw loop into a
blend-state key and choose the matching pipeline per branch - branch 2 is sourceRGB=SourceAlpha, destRGB=One, Add
with alpha ONE/ZERO. No projection, geometry or batch-filter change. Decisive test remains the 41-batch prefix
capture: mean RGB of the 333960 cloud pixels must return to the prefix-4 value (160.436) instead of 28.835. Build-gated.
