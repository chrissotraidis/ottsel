# Retained MERC menu logo — 2026-09-12

Source finding: the title logo is a skeleton model (`title-obs.gc`); the shared native MERC aggregate retains old geometry when its pending queue is empty and renders with the newest camera. It cannot distinguish an absent completed frame from a completed frame containing no MERC.
Build/install SHA256 `0a3ef88137a68c50d0da53fe6f32bde3e72656c3722d6a1d0db42d752ad9996d`, PID70051, sole iPad Simulator `08636791-2675-4675-8335-EF72EF954DCF`.
Normal title→Start route stopped at main menu using `scripts/replay-ios-normal-route.py --stop-at main-menu`; no input between comparison captures.
Before: `/tmp/ottsel-video/recovery-menu-merc-settled.png` contains giant logo over the menu.
Intervention: existing `ottsel-trace-metal-scene-no-merc` trigger consumed; wait2 seconds, same process and menu.
After: `/tmp/ottsel-video/recovery-menu-merc-disabled.png` has no logo and all six menu entries visible. This identifies the MERC contribution; earlier claims of omitted text batches are unproven because retained geometry can occlude them.
Yellow/black large geometry and absent circular backdrop remain. The diagnostic disables all MERC, so it is not a product fix or general actor acceptance.
Required fix/test: publish completed MERC frames including explicit empty, freeze their camera, preserve only while awaiting a new completed frame, and exclude in-progress future uploads. Verify title→menu→game transitions and regressions before accepting a new default run.
Logs preserved in `/tmp/ottsel-recovery-2026-09-12/menu-merc-control-runtime/`; fault bytes0 when the diagnostic process stopped.
Default fix verified: build/install774fd946fd9b5c67097e86e4703ad543556fa73b34ddd07f90df8cf13707d878, PID71564, fresh normal route without no-MERC probe. Main-menu screenshot shows no logo and all six entries; save menu also has no retained logo (`recovery-merc-frame-{main-menu,save-menu}.png`).
Actual-source `bash scripts/test-mobile-merc-frame.sh` passes10 checks including explicit empty, late producer writes, supersession, abandoned chains and frozen camera. The default run reached Training with fault bytes0 at stop.
Closed20-second61MiB `/tmp/ottsel-video/recovery-merc-frame-controls.mp4`: inspected frames6/12 show Jak moving away from and back to the spawn structure; input sequence also includes Cross and neutral releases. This closes demonstrated stale-logo ownership, not complete animation/material/pacing acceptance.
Runtime logs preserved in `/tmp/ottsel-recovery-2026-09-12/merc-frame-runtime/`. Remaining backdrop defect has a distinct source cause: real HUD textures exceed the atlas64×64 limit; its fix is undergoing a separate full build.

Registered Sprite image follow-up: build/install774a568ec15a63dcc88272e4480018c33c70e4a39b957d4f883e3613b1ed2bba, PID77034, exact right and selector FR3 comparisons now0/131072 and0/16384. Left slot0 metadata instead names charHOLD (4×4/PSM2), so the128×512/PSM19 request falls back to incorrect raw pixels. Fresh settled menu still lacks the circular backdrop and several entries; identity success does not close composition/material/depth. Log `/tmp/ottsel-recovery-2026-09-12/sprite-registry-measurement.log`; screenshot `/tmp/ottsel-video/recovery-sprite-registry-settled-menu.png`. App stopped with zero fault bytes; runtime evidence preserved under `sprite-registry-runtime/`.

Unchanged-page residency correction verified in full build/install47f46dbbf9a2b60a61f844c3e0a8a69e4abaedd5aae779479cd475fe46c89210, PID83702: left now exact408/0, right408/3, selector408/4, all registered-image and0 differing pixels. Actual A→B→A PC_PORT/registration regressions pass. Fresh menu remains malformed; broad scene-no-depth ablation does not restore it and is not HUD-isolated. App stopped with zero fault bytes; evidence `residency-audio-{measurement.log,runtime/}` and `/tmp/ottsel-video/recovery-residency-audio-{settled-menu,no-depth}.png`. HUD-specific depth fix is the next source-proven test, not a claimed cause of all remaining artifacts.

HUD composition follow-up: depth2cddd1d0 exposes the panel; packed-Y matrix selectionb34ad619 restores placement; raw-byte color30c97113 removes yellow saturation; triangle coverage1b81b902 removes overlap/holes. Independent whole-producer regressions cover matrix, color and analytic coverage rather than mirroring old corner order.
Latest build/install SHA2561b81b902b79ab0359770ea2fdf54835e67e9234431b744c9617686a0c0edf012, PID89079, normal route to settled menu: intact circular frame and all six entries in `/tmp/ottsel-video/recovery-hud-coverage-settled-menu.png`; exact left/right/selector FR3 identities have zero differing pixels. Stopped with zero fault bytes; logs `hud-coverage-runtime/`. Direct completed-frame retention is still staged; this capture does not prove stable presentation or gameplay acceptance.

Direct completed-frame retention verified: build/installcdd3765856d5b8d6ce378de58eb92715b8f69daab54191357b21b8b4a76ed656. Three settled captures retain all six entries; all232 sampled presentations draw176 Direct batches (no empty presentation in that window). Normal route then reaches Training with no retained menu text in `/tmp/ottsel-video/recovery-direct-frame-training.png`; stopped with fault bytes0. Logs `direct-frame-product-runtime/`, sample `direct-frame-measurement.log`.
Actual source regression passes13 frame/pool-lifetime checks plus integration checks, independently reviewed. First app compile caught an Objective-C property-name collision; store renamed `_directFrameStore`, tests/build pass. This closes observed transient Direct text loss and stale-text transition; cross-layer atomicity, Sprite presentation/materials and whole-scene acceptance remain open.

Sprite homogeneous follow-up: build/installb9abdf49510cc30c78e11c18fd2b59b03fbad337f3b32469866cd51a321c46c7 passes13 actual producer regressions and reaches normal Training with fault0. Immediate transition screenshot lacks backdrop; repeated same-binary settled menu shows full circular frame/all six labels (`recovery-sprite-homogeneous-settled-settled-2.png`), refuting a regression claim based only on that transition image. Both runs stopped fault0; logs `sprite-homogeneous-{product-runtime,settled-runtime}/`. Raw homogeneous coordinates, Metal shader and queue/layout checks pass; material/sky acceptance remains open.
Dynamic eye parity audit (2026-09-14, host-only read-only; gate closed, no build).
Captured runtime rows (`/tmp/ottsel-recovery-2026-09-12/merc-material-census.log`) pin the native binding: eichar-lod0
emits 11 draws with `eye-id=0xff` (tree-tex 315-327, native-slot==tree-tex) and exactly two eye draws,
`eye-id=0x0 tree-tex=323` and `eye-id=0x1 tree-tex=324`, both `ignore-alpha=true`, `mode=0xf90e265d`
(alpha-test bit18 set; (mode>>24)&7 = 1 = SRC_DST_SRC_DST).
Producer: `extract_merc.cpp:1762` sets tree_tex_id from `find_or_add_texture_to_level(..., &pc_draw->eye_id, ...)`;
on the Jak1 eye page (eye_tpage 0x1cf) with tidx == left 0x6f / right 0x70 it sets `*eye_out = eye_ctrl->eye_slot*2 (+1)`
and still returns the ordinary level-texture index, so eye_id 0xff means 'not an eye' and both fields are always present.
Desktop prefers the eye id: `Merc2.cpp:1175` `draw->texture = eye_id == 0xff ? tree_tex_id : (0xefffff00 | eye_id)`,
resolved at `Merc2.cpp:1332` by `eye_renderer->lookup_eye_texture(draw.texture & 0xff)`.
Oracle composer: `EyeRenderer` is free bucket 54 `BucketId::MERC_EYES_AFTER_PRIS` (`OpenGLRenderer.cpp:822-823`);
slot = `pair*2 + lr` over `NUM_EYE_PAIRS=20`; `GpuEyeTex` is a 128x128 framebuffer (`EyeRenderer.h:60-62`). `run_gpu`
clears each slot then draws background (samples 0,0 of the eye-page texture for a flat colour, `:235`), iris, pupil
(SRC_ALPHA/ONE_MINUS_SRC_ALPHA) and lid (`EyeRenderer.cpp:542-576`), then `move_existing_to_vram` publishes the
composed image into VRAM so the tpage id resolves to it; `lookup_eye_texture` indexes `eye_id % 40`.
Native gap: `metal_gfx.mm:2117-2118` prints `d.eye_id` for observability only; the actual bind is
`ottsel_mobile_scene_texture_slot(texture_base, source_draw.tree_tex_id)` (`:2149-2151`), and only buckets 3 (sky,
`submit_mobile_native_sky_bucket` :4232) and 67 (direct, :4358) have native consumers. No native draw struct carries
eye_id and no eye consumer exists, so the eyes are uncomposed rather than mis-textured: the level texture at 323/324 is
exactly the desktop background base (`iris_tex = tex0` from the eye adgif), so binding it alone cannot add iris/pupil/lid.
Consequence for the fix: a new bucket-54 GS consumer that composes the four quads into a 128x128 texture and publishes it
atomically with MERC geometry/camera, not a texture-id swap. Decisive check: composed-image pixel parity against the
desktop oracle plus a settled-Training capture showing iris/pupil/lid. Build-gated.
Bucket map (T5, host-read): jak1 `(eyes 54)`, `pris-tex0 = 48`, `pris-tex1 = 51`. `update-eyes`
(`eye.gc:679-724`) routes level-eye render DMA to 48/51 - buckets the native path already sniffs as texture uploads -
and common-eye DMA to 54; `render-eyes` copies the level `iris-shader` adgif into every packet (`eye.gc:74`), so
the bucket-54 DMA is self-describing (tpage/clut/tex0 inline) and no new serialized eye field is needed.
Native windows are pure arithmetic - `ottsel_mobile_jak1_bucket_boundary(off,id) = off + 16*(id+1)` (`mobile_generic_policy.h:71-74`) -
so 54/55 is directly addressable and the generic 0..69 `DmaFollower` loop (`metal_gfx.mm:8376-8390`) already walks it.
Producer: `merc-eye-anim` (`eye.gc:905`) fills `*eye-control-array*[eye-slot]` with the actor process, the 3-shader inline
array, the level index and lerped left/right `eye` data; `update-eyes` runs once per frame (`drawable.gc:901`) across 11 slots,
gated on a live process plus `eye-done` and `was-drawn`. Fix shape unchanged (build-gated, parity check as above).
