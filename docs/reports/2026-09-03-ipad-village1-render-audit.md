# iPad Village1 render audit — 2026-09-03

Scope: static review of `src/shell/metal_gfx.mm`, `metal_shell.mm`, `mobile_scene_policy.h`, the iOS `sif_ee`/sound path, upstream `background_common.cpp`, `tfrag3.vert`, `merc2.vert`, retained iPad logs (2026-08-22/23) and today's live container log. No build was run; nothing here claims playability.

## 1. Confirmed causes (code + logged evidence) vs hypotheses

Confirmed:
- **Scene latches to the last-loaded TIE level, not the camera's level.** `load_mobile_level` calls `build_mobile_tie_mesh(level)` for every non-GAME FR3, which sets `g_mobile_tie_level`; `capture_mobile_camera` then rebuilds TFRAG/TIE only for packets whose name equals that latch. Log r19: village1 snapshot, `GAMEPLAY: enter village1`, then `loaded 'misty'` and `TIE: normal batches level='misty'`, after which village1 packets are ignored and the misty mesh replaces village1. Upstream draws level0 and level1 buckets every frame; native draws one level.
- **Depth is inverted.** Upstream: `glClearDepth(0)` + `GL_GEQUAL`. Native `tie_vs` maps z to `(z+w)/2` (order-preserving) but `presentRGBA` clears depth to 1.0 with `MTLCompareFunctionLessEqual`. Logged clip samples prove the sense: distant misty verts land at ndc-z 0.0002–0.0005, near village1 verts up to 1+, so far fragments win. Draw-limit=1 looking "coherent" and full scenes looking layered/detached is exactly this symptom.
- **Merc geometry went through the world camera.** `capture_mobile_merc` skins with the packet's camera-space bone matrices and submitted through `pc_camera` + `camera_trans`; `merc2.vert` uses only `perspective_matrix` + HVDF. The uncommitted `projection_mode` change is the correct fix; today's frame confirms the giant panels were Merc.
- **"Rays" = double projection.** The `camera_sign<0` branch applies Q/HVDF/2048/256/128 on top of `pc_camera`, which already contains those scales; upstream `tfrag3.vert` at this pin has no such block. Today's `bot36-i1-reference-replay` frame is that probe, not the product path.
- **Black regions are the clear color.** No sky, ocean, TIE TRANS/WATER/envmap categories, shrub, or Direct/HUD are drawn natively (Direct product mode is trigger-gated off). Missing families, not a transform bug.
- **`pcm-peak=0` is structural.** iOS has no IOP thread and `game/overlord/jak1/srpc.cpp` is not in `build-ios.sh`; `sceSifCallRpc` handles only irx-version, PLAY clock, ramdisk, STR and DGO. Every `sound-play` command is dropped, so the mixer has no voices.
- **Product path does diagnostic I/O every frame.** `gfx_send_chain` unconditionally fopens and appends `tfrag-vif-replay.bin` (18.4 MB) and `tfrag-vu-data.bin` (8.3 MB) in the container, memcpys every UNPACK into VU memory, and CPU-decodes 512 transfers; today's log shows 13–18 chains/s.
- **TOD alpha is ×2 but upstream is ×4** (`fragment_color *= 2; .a *= 2`). R25 had this right; the current shader comment reverted it. Also `alpha_fail==FB_ONLY` without depth write should set `alpha_min=0` (upstream) but native keeps `aref/127`; `zt_enable` and depth-test kind are ignored.

Hypotheses (not yet proven):
- Jak's `eichar-lod0` packet is never captured although `LEVEL MARKER: target-trans` shows a live target. Candidates: MERC_PRIS bucket beyond the 4096 tail scan on long chains, or `capture_mobile_merc` rejecting the packet (slot terminator, `matrix_addr>0x10000000`, size<416).
- Residual "fragmented" TFRAG after the Merc fix is the depth inversion above; strips/indices are clean (no `flattened draw triangle mismatch` in any log; `outOfRange=0`).

## 2. Incorrect assumptions and risky changes
- R18/R19 "restart after every group" was a no-op: extractor sets `num_inds = verts+1` including the restart, so upstream's contiguous multidraw and native concatenation are equivalent. The perceived improvement was noise.
- "Rotated/dislocated" frames: `simctl` screenshots are portrait-encoded for a landscape device (status bar on the right). Rotation is not a render defect.
- R24 (draw all geometry slots) overlaid LODs; correctly reverted. R16's Q/HVDF TIE path was a double projection; do not resurrect it.
- The 512/4096 transfer budgets make coverage depend on chain length; the bucket table at `offset + bucket*16` (already used for 65–68) gives O(1) access to TFRAG/TIE/MERC buckets without walking.
- Camera matrix math (`set_mobile_tie_camera`) matches `make_new_cam_mat` exactly; do not change it again.
- Aspect: the 512/448 y-scale assumes a 4:3 viewport, but the full 2420×1668 drawable is used, so the image is ~9% wide; letterbox like upstream.

## 3. Smallest next experiments (one at a time, each with no-Merc/no-TIE controls)
1. Depth: `clearDepth = 0.0`, `tieDepthState`/`tieNoWriteDepthState` → `GreaterEqual`. Expect near-over-far ordering; compare a Village1 frame at the same camera packet.
2. Level ownership: stop calling `build_mobile_tie_mesh` from `load_mobile_level`; key snapshots by the packet's `level_name` and keep one mesh per loaded level, drawing all levels in the current want list.
3. Merc: keep the uncommitted `projection_mode` fix; add a `MERC PC_PORT` name ledger from the bucket table (buckets 10/11/49/50/56) to prove whether `eichar-lod0` is emitted and where `capture_mobile_merc` rejects it.
4. Audio: compile `game/overlord/jak1/srpc.cpp` and dispatch PLAYER-channel buffers from `sceSifCallRpc` straight into `RPC_Player` on the caller thread; require `pcm-peak>0` after New Game.
5. Pacing: gate both dump files and the VU memcpy behind `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS`; replace the linear scan with bucket-table jumps. Then restore TOD alpha ×4.

## 4. Proof required before any gate moves
- Unit tests: depth mapping (`(z+w)/2` with GreaterEqual/clear 0 keeps a logged near/far pair ordered); snapshot follows packet level (village1 packet after misty load must not rebuild); Merc identity-bone projection equals `merc2.vert` for one vertex; `goalc-test` still 750/750.
- Runtime: fresh title-wait → Start → Cross → Down×4 → Cross frames with and without `scene-no-merc`, `scene-no-tie`; chain rate ≥ 30/s logged from `VU1STAT`; `eichar-lod0` in the Merc ledger; `pcm-peak>0`; container `Application Support/local.ottsel` growth < 1 MB per run; fault log 0 bytes; a 30 s SIGINT-bounded recording with Jak visibly moving under WASD.

## Paste-ready prompt for the main bot
Continue the Ottsel iPad Village1 investigation from `docs/reports/2026-09-03-ipad-village1-render-audit.md`. Keep the uncommitted Merc `projection_mode` change. Run the experiments in section 3 in order, one change per signed build on the single booted iPad Pro Simulator: (1) flip Metal depth to clear 0 + GreaterEqual; (2) key TFRAG/TIE snapshots to the PC_PORT packet level and keep every loaded level resident; (3) add a bucket-table Merc name ledger and explain why `eichar-lod0` is not captured while `target-trans` is live; (4) route PLAYER RPC buffers into `RPC_Player` and prove `pcm-peak>0`; (5) gate the VIF dump files and VU memcpy behind the diagnostics env var. For each, add the regression in section 4 first, capture one fresh frame with the no-Merc and no-TIE controls, record chain rate from `VU1STAT`, and write PASS/OPEN honestly in one ≤60-line evidence doc. Do not touch the camera matrix math, TBP/lookup, or strip-restart code, and do not claim playability until Jak is visible and controllable with stable depth ordering.
