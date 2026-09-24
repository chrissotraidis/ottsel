# Ottsel project completion plan — 2026-09-14

## Authority and outcome

This is the end-to-end implementation guide for `RECOVERY_GOAL_LOOP.md`. Keep that file as the single execution prompt; do not create another numbered BOT queue. This plan supersedes older task ordering, not retained observations or the product requirements. `AGENTS.md` and current user instructions govern execution.

Deliver honestly playable native Jak 1 on iPad first, then iPhone parity and physical-device readiness: signed ARM64 AOT throughout, no runtime instruction generation or executable-memory creation, legal user-data import, coherent rendering, responsive controls, audio, persistence, lifecycle, and reproducible asset-free delivery. A successful research build or Training clip is an intermediate result.

The original PRD is reconstructed in `00-phase1-brief.md` and `jak1-researchloop.md`; `05-roadmap.md` and `BOT2_PROMPT.md` define execution gates. Full PS2 controls/settings and physical-device acceptance are later accepted requirements in `16-ipados-ios-goal-loop-2026-08-23.md`. Preserve both. Jak 2/3, multiplayer, a new engine, and App Store submission remain outside scope.

This document is a plan, not a newly proven gate. Historical test and runtime results below are reported from repository evidence; none was rerun during this documentation review.

## Reviewed state and why work stalled

Read the September 12 recovery review, delivery audit, signed-AOT guide, September 13 signed-export report, current recovery board, and the four recovery evidence documents linked below before source work. BOT37–67 are useful history, but their later numbers do not supersede the recovery results.

Review snapshot: outer HEAD `09b2672e07af619b809dbfc6f51c211516466145`; nested HEAD `49324a47ef8698a8839adbd9a20ac7479cc0e694`. Both source provenance and working changes matter; a commit hash alone does not identify this product. The documented reconstruction base is `641fb572e876750d8618434d9f7c1a531b43b366`; do not reset the nested tree to it.

On September 14, `df -h / | tail -1` reports 10 GiB available and the common `.git/objects/pack` contains zero `tmp_pack_*` files. Product work is blocked by the 40 GB minimum. This review performs documentation work only, with no build, Simulator launch, cleanup, or runtime claim. Historical disk overrides are not authority to bypass the instructions supplied for this run.

The recurring problems were competing handoffs, stale state identification, altered production shaders, uncontrolled image comparisons, and confusing a partial signed slice with full native execution. Recovery has corrected several of these; do not repeat its completed experiments merely to generate activity.

| Area | Best retained evidence | Remaining obligation |
|---|---|---|
| Named encoder/link crashes | `evidence/M1/recovery-crash-regressions-2026-09-12.md` records regression and narrow reconstruction checks | Revalidate current source before renderer work; recurrence reopens prerequisite |
| Normal route and controls | `evidence/I1/recovery-stale-terrain-2026-09-12.md` records Training, jump/forward/reverse/release | Cold-start reproducibility, real touch/controller, traversal and full progression |
| World and menus | Terrain retention, level ownership, MERC W/lighting, Direct/Sprite corrections recorded in that file and `evidence/I1/recovery-merc-menu-2026-09-12.md` | Sky additive blending, dynamic eyes, remaining materials/effects, pacing and residency |
| Audio | `evidence/AU1/recovery-audio-lifecycle-2026-09-12.md` records real banks, PCM and one Home/resume | Actual output, music/dialogue, interruption, held-input cancellation, persistence |
| Signed execution | `SIGNED_AOT_RECOVERY.md` records eight signed KERNEL tops, 279 exports, normal Training | GAME, all streamed code, no research fallback, physical-device execution |
| Delivery | `reports/2026-09-12-delivery-audit.md` finds mixed asset bundle and partial patch reconstruction | Whole-tree reconstruction, fresh asset-free packaging, actual user import and device tooling |

Do not reopen disproven general theories: blanket zero audio; missing MERC capture; extra Direct coordinate scale; zero VU1 counters implying missing native FR3 rendering; broken sampling for every Sky batch; or all black triangles being erroneous. A changed counter or camera pan never establishes controlled gameplay.

## Requirements and acceptance map

| Requirement | Existing gate names | Required final evidence |
|---|---|---|
| Real ARM64 codegen, ABI and host tools | H1/H3 | Maintained semantic tests and reproducible offline compiler outputs |
| Signed execution without runtime instruction writes | H2/H2.5/A1, expanded to whole game | All code inventories accounted for; immutable signed text; writable data only; unsupported code rejected; normal progression in strict configuration |
| Coherent normal launch and gameplay | I0/I1 (S1/S2 history) | Two fresh routes, sustained traversal, grounded animated Jak, occlusion/effects/HUD, meaningful input and observed pacing |
| Audio/lifecycle/persistence | I2 (S3 history) | Audible game output, interruption recovery, neutral cancellation, saves after relaunch and transitions |
| Complete frontend | I3 | Doc16 PS2 controls/settings, persistent layouts, multitouch, controller handoff, accessibility |
| iPhone parity | P1 | Same accepted gameplay/system checks on one phone profile after stopping iPad |
| Legal import and reproducible delivery | Original R1 packaging gate; D1 | Fresh asset-free bundle, validated local import, clean reconstruction instructions and physical iPad/iPhone proof |

Historical renderer R-rounds and the original R1 packaging gate are different concepts. Use descriptive gate labels in evidence to avoid mixing them. M0 remains the macOS behavioral reference; only a demonstrated shared regression reopens it as engineering work.

## Operating contract for every implementation loop

1. Read the current board and inspect actual outer/nested status, source and artifacts. Preserve existing changes. Assign one owner per source file; root alone owns builds, app launches, captures and input. Subagents may review or implement explicitly bounded independent pieces, with integration serialized.
2. Run disk preflight before each experiment. Resolve `git rev-parse --git-common-dir`, count its `objects/pack/tmp_pack_*`, and list exact paths/sizes if any exist. Below 40 GB available or any temporary pack: stop product work and report. Do not infer a deletion authorization or guess disk causes.
3. Inspect `xcrun simctl list devices --json` before runtime work. Use at most one booted Simulator. Resolve the intended device from current inventory, not just the historical UDID. Never disrupt an unidentified unrelated runtime. Stop the owned iPad session before iPhone. Build and reference captures are serialized too.
4. State one question, source mismatch, predicted failing observation, smallest proposed change, decisive test, and output budget. A test must exercise a production contract or independent oracle, not reproduce implementation arithmetic verbatim.
5. Add the failing regression when warranted, implement the smallest fix, rerun relevant tests, then do one bounded fresh runtime check when needed. One default-off probe per process. No diagnostic return in the default shader and no multiple-variable A/B comparison.
6. Capture source/profile/data identity, binary hash matched to installed executable, device/OS, flags, route state, successful GPU completion, fault result and actual inspected image/clip. Check viewport orientation before any region analysis. Missing or mismatched evidence means INCONCLUSIVE.
7. Update the current step and one concise evidence document per proven gate (maximum 60 lines); append at most eight STATUS lines. Raw bounded recordings belong only in `/tmp/ottsel-video/`; each worktree file must remain below 100 MB. Preserve useful evidence without copying game data into git. No `git add -A`, blanket reset, broad patch regeneration, or unsolicited log truncation.
8. Continue to the next dependency. After three unchanged failures, stop that experiment, reassess the observer and premise, and record the exact blocker plus falsifiable alternative. Do independent authorized work only when it does not bypass a hard gate. Never repeat a long build with identical inputs just to appear persistent.

Use the exact recorder lifecycle in `AGENTS.md`: H.264 background recording, bounded sleep at most 30 seconds, SIGINT and wait, file-size check, then SimRender movie-handle check. No new recording while any live movie handle remains. Long stability acceptance uses bounded clips within a longer observed session, not one enormous recording.

## Stage 0 — resume safely and establish reproducibility

Entry: disk gate clear. Current action: blocked; leave source and runtime untouched until it clears or the user explicitly changes that instruction.

Inventory tracked/untracked outer and nested changes, maintained overlays, generated objects, current module profile and existing evidence. Record only identities and scoped differences; avoid giant duplicate checkouts or assets. Treat missing `/tmp` artifacts as missing historical proof, not as evidence that a regression passed today.

Run these existing prerequisite commands sequentially after preflight:

```sh
bash scripts/test-metal-encoder-guard.sh
bash scripts/test-link-begin-args.sh
python3 scripts/verify-link-begin-patch.py
```

If a named crash recurs, fix and cover that boundary before renderer rounds. Audit `patches/README.md` against the actual nested tree: classify each delta as maintained feature, diagnostic, generated output, or unrelated user work. Add narrowly scoped missing overlays; prove ordered application against the documented pin and byte identity of required sources. Do not blindly apply patches to an already modified nested tree.

A full clean reconstruction command does not exist as a demonstrated complete workflow. Build a maintained manifest/driver for ordered patches and source identities only after this inventory; validate in bounded staging once capacity permits. Generated GOAL edits require affected objects/DGOs regenerated with the actual ARM64 compiler; shell-only compilation cannot validate changed runtime or AOT outputs.

Exit: named crash tests green for this source, exact reconstruction gaps enumerated, known product/research configuration and bounded build plan. Full clean-checkout verification is finalized in Stage 7.

## Stage 1 — finish signed code, the original architecture gate

This is the primary implementation priority after Stage 0. The later renderer plan must not consume another indefinite series of rounds while full-game signing remains open. Independent source review for Stage 2 may proceed; product acceptance waits for strict signed execution.

### 1A. Preserve and verify the existing KERNEL baseline

Use the canonical eight-module order in `config/signed-kernel-full.json`. Existing maintained commands include:

```sh
python3 scripts/test-a11-kernel-emission.py /tmp/ottsel-kernel-emission-new
python3 scripts/test-a11-gstate-loader.py /tmp/ottsel-kernel-review-new --module-list config/signed-kernel-full.json
python3 scripts/test-a11-signed-exports.py /tmp/ottsel-kernel-banks-new /tmp/ottsel-kernel-review-new
OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-kernel-full.json OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh
```

Choose unused output paths and verify script arguments before execution. Build once after relevant host checks. The command is a mixed-runtime Simulator baseline, not a full-game or physical-device build. Repeat the exact module/export environment for later shell-only work; changing a profile requires full regeneration and cache validation.

### 1B. Extend identity and emission to GAME

Inventory every genuine GAME member and actual load order from the local compiled artifacts and game manifests. Compare loose object hashes with container members. Identify code versus art objects even when names overlap. Record relocation kinds, initializer dependencies, export registrations, code size and RW reservation requirements before implementation.

The widened data-side type guard needs no ordering coordination with the runtime: across the whole corpus every one of the 117 type names is requested at a single `methods` count (117 pairs, none duplicated, none at 0 or 1), so `intern_type_from_c`'s `size_of_type(existing) < size_of_type(requested)` assert (`kscheme.cpp:1176`) is unreachable whatever order modules link in. `python3 scripts/a11-corpus-census.py --types` fails closed on that and on the pinned four bootstrap types staying at 9.

The manifest generator and the loader fixture currently accept specific KERNEL lists. A longer JSON list is insufficient. Extend their authenticated schema and guards to describe container/member identity and ordered activation; retain legacy KERNEL controls. First emit and activate the real dependency-ordered GAME math prefix, then extend by the first unsupported genuine object/relocation. Do not invent a parallel execution engine or one numeric mode per module. The existing KERNEL guard is already complete for both canonical lists: `preflight` exits 0 for `--list config/signed-kernel-full.json`, `--list config/signed-kernel-comparison.json` and legacy `--mode 3`, and all eight KERNEL.CGO members are byte-equal to their loose `out/jak1/obj/*.o` in canonical order. The profile-side sites are now general: `scripts/signed-module-build-profile.py` accepts any distinct non-empty schema-1 name list (:22), and `locate_member` scans KERNEL then GAME and requires the loose `name.o` body to equal one member body (:42-:44), so the duplicated `sidekick` code/art pair resolves to its 38758-byte code body; KERNEL.CGO keeps count 8 and canonical order (:33, :41) because the signed KERNEL baseline is preserved. `scripts/test-signed-module-build-profile.py` proves all of it (33 checks) while the legacy `--mode`/`--banks` controls still pass. The registry is now general at every site: `scripts/emit-signed-gstate-manifest.py --aggregate --module-list config/<list>.json` accepts any `{"schema":1,"modules":[...]}` with distinct non-empty names ending in `gstate` and emits `modules[]`/`module_count` in that array order; `scripts/test-a11-gstate-loader.py` derives its canonical/ordered lane from the selected names and the generalized `test/a11_kernel_manifest_test.py` asserts the list-derived count while gating the gkernel-specific cases on the aggregate `gkernel.json`; the runtime loader carries no KERNEL names (`validate_module` derives release-debug from `segments[1].source_text_size`, `validate_layout` requires only `module_count >= 1`, a final `gstate` entry and distinct names, and `link()` walks the generated array in load order). `config/signed-ordered-control.json` (canonical eight minus `dgo-h`) exercises that generalized path (canonical 631 PASS / ordered 162 PASS). The GAME blocker is now activation, not emission or the schema: data-only members now emit through `patches/a11-data-only-main-segment.patch` (emitter guard `a11_module_emitter.h:98-99` with the runtime placement `ottsel_signed_gstate.cpp:88-107`), so all four corpus restrictions pass the host verification set and the dependency-ordered GAME math prefix must extend the ordered registry before activation goes past KERNEL.

Require failure-before-mutation for wrong hash/member/container/order, unknown relocation, invalid range/type, stale cache, unsupported symbol and insufficient arena capacity. Preserve tagged pointers, genuine GOAL function/type identity and release debug semantics. Compute one aggregate arena layout with explicit allocation bounds rather than guessing free space. Test emitted linked instructions/targets plus real compiled operations and initializer side effects.

### 1C. Complete streamed code and reload semantics

Inventory the entire Jak 1 code corpus, not just code observed during Training. Account for KERNEL, GAME and every streamed level/object that can execute. Resolve executable relocations offline into signed Mach-O, using writable bindings/data templates for runtime state. Implement GOAL-side load, unload, reload and level transitions with authenticated module identity, explicit lifetime and rollback.

The current signed hook covers `link_and_exec`; actual GOAL streaming also calls `link-begin` and `link-resume` (`engine/load/load-dgo.gc`, `engine/level/level.gc`, and `game/kernel/jak1/klink.cpp` in the nested tree). Migrate and test all three entry paths; broadening only the existing hook leaves streamed execution on the ordinary linker.

Tests must include genuine level transition and return, repeated reload, retained cross-module references, stale generation rejection, export reuse/exhaustion, allocation failure, and no stale data pointers. Check every remaining C/GOAL bridge including nested reentry and relevant scalar/vector/stack returns. Extend existing ABI regressions only for uncovered contracts.

### 1D. Make strict product execution fail closed

Introduce a clearly separate strict signed-AOT build configuration. Remove its executable blob loader, instruction-writing trampoline fallback, runtime executable mapping changes and listener execution. A missing signed module must produce an actionable error before executing anything; it must never silently enter research mode.

Audit current emit/link sites against `08-emit-site-audit.md`, actual `klink.cpp`, `kscheme.cpp`, Mips2C registration and executable-memory helpers. Static inspection, linked-codeword verification, VM protections and runtime guards must agree: all executed game code belongs to signed executable segments, data stays writable/non-executable, text/tags stay unchanged through load/reload and gameplay.

Exit: whole corpus covered and normal progression succeeds under strict mode with no runtime instruction writes or executable-memory creation. Simulator proof closes only the Simulator architecture boundary; Stage 7/8 still requires genuine device validation. If architectural extension fails three times without a new angle, write a bounded decision with concrete unsupported case; use the existing signed-code strategy before proposing a documented PRD-compatible pivot.

## Stage 2 — close demonstrated iPad scene defects

Reproduce on the accepted source/profile; preserve already fixed terrain, ownership, homogeneous W, TOD, UV, material and menu contracts. Fix the first demonstrated defect, not a visually tempting hypothesis.

**Sky cloud blending is the first current renderer change.** Retained immutable population evidence shows batches 4–34 request GS ALPHA `0x48`, equivalent to `Cs*As + Cd`, while the shell uses source-over. Carry the actual blend selector through decode, immutable batch and pipeline selection. Use SourceAlpha/One RGB and One/Zero alpha for this proven case. Do not globally change the shared Direct pipeline: HUD/Sprite source-over and opaque paths need controls.

Add a production GPU blend-equation regression with known source/destination/alpha and the recorded packet selector. Replay the same immutable real population if retained; otherwise recapture once under a confirmed route. Require matching successful GPU completion and default-path before/after imagery. Keep the last black triangles: retained evidence says they fill previously uncovered ground, not overwrite the colored sky. No new projection or blanket sampler sweep.

**Dynamic MERC eyes follow.** Real `eye_id` 0/1 currently select static FR3 slots; desktop bucket 54 produces persistent 128×128 composite eye textures. Trace that actual producer and implement its background/iris/pupil/lid composition. Publish immutable eye images atomically with the corresponding MERC geometry/camera. Verify pixels, packet selection, lifetime/allocation failure and repeated updates. Check hair/environment effects separately using actual per-effect flags; do not attribute every artifact to eyes.

**Then use a finite defect inventory.** Compare matched normal game state with M0 for terrain/TIE, animated MERC, sky, water/transparency, particles, sprites/HUD, shadows/occlusion and transitions. Record observed defect, source contract, regression and live exit for each. Unknown areas remain untested rather than implicitly green. Fix the largest demonstrated missing or incorrect contribution; do not rewrite the FR3 renderer because diagnostic VU counters are zero.

Existing relevant scripts: `test-mobile-level-ownership.sh`, `test-mobile-resource-retirement.sh`, `test-mobile-merc-frame.sh`, `test-mobile-merc-math.sh`, `test-mobile-direct-frame.sh`, `test-mobile-sprite-contract.sh`, `test-metal-tod-interpolation.sh`, `test-metal-direct-stq.sh`, `test-metal-direct-fst.sh`, `test-metal-direct-depth.sh`, `test-texture-relocation.sh`, `test-texture-upload-segments.sh` under `scripts/`. Select affected checks; do not rerun every suite after an unrelated small edit.

Exit: default strict build has coherent actor/world/menu/effect composition through the acceptance route with no known blocking visual defect. Passing an isolated GPU fixture alone cannot close this stage.

## Stage 3 — prove gameplay and finish progression coverage

Launch fresh with route tracing when needed and use `python3 scripts/replay-ios-normal-route.py <sole-booted-udid>`. This existing script checks accepted menu edges and neutral release but ends at Continue Without Saving. It does not assert intro completion or Training. Add a bounded maintained downstream state observer that distinguishes frontend, cutscene/camera, active target and actual control handoff; reject stale logs and old triggers.

Do not substitute `(bg 'village1)`, a scene residency string, a camera pan, or a debug skip for normal progress. The retained route uses an intro fallback for unavailable sequence B; classify and repair missing cinematic/spool behavior for final acceptance rather than silently accepting a debug bypass as the retail experience.

Run two independent cold starts through title, New Game, save choice, intro completion and Training, then demonstrate movement/stop/reverse, jump/landing, attack/action, camera follow and occlusion against fixed landmarks. Use real touch/controller paths for final acceptance; file triggers remain diagnostics. Cover death/retry, pause/menu return and save continuation.

Create one finite progression matrix from actual Jak 1 level/load manifests. Include hub-to-level transitions and return, streaming, collectibles/progress changes, representative traversal/combat, vehicle and boss mechanics where the game requires them, ending/credits, and resume from saved progress. Mark every entry untested/pass/fail with build/profile identity. As a new completion-verification requirement of this plan, rather than a quoted original PRD criterion, a full normal playthrough is the final functional coverage pass; targeted saved checkpoints may accelerate regression checks but cannot replace evidence that normal progression works.

Measure presented cadence and p50/p95/p99 intervals through a supported observation surface. Command-buffer completion rate, GPU duration and DMA chain rate are not displayed FPS. If Simulator cannot supply presentation timestamps, leave that metric explicitly open for a supported device/tool and use observed responsiveness only as bounded evidence.

Operational minimum proposed by this plan: two 20-minute interactive sessions spanning level transitions and a one-hour device soak after correctness stabilizes, with bounded clips and logs. These are new verification minima, not historical PRD numbers or proof that longer play is safe. Establish the intended frame-rate target from the existing game/reference and hardware before accepting performance; report misses, hitches, thermal effects, memory trend and residency after return to the same scene. Implement bounded asset eviction only when measured residency requires it, preserving in-flight ownership.

Exit: I0/I1 accepted on strict signed iPad, full progression matrix complete, no reproducible crash/softlock or accumulating resource growth, measured responsiveness/pacing with explicit hardware limits. Any shared failure reopens its originating gate.

## Stage 4 — audio, lifecycle and saves

Start from existing audio ownership, bank loading and pause/open fixes; nonzero PCM is already recorded. Use `bash scripts/test-audio-output-lifecycle.sh` and `bash scripts/test-mobile-sound-commands.sh` for affected changes, followed by actual default gameplay.

Verify audible ambient/effects, music and dialogue across title, intro and streamed levels. Associate heard output with real game events; callback/peak counters alone do not pass. Test bank eviction/reload, pause, Home/resume, interruption begin/end, route changes, controller disconnect, cancellation while sticks/buttons are held, and memory pressure. All inputs must return neutral without a stuck action; EE/IOP/audio must resume coherently.

Create a save, alter progress/settings, save again, terminate, relaunch and load. Test across a level transition, unsuccessful/cancelled save and interrupted import without corrupting the previous valid state. Keep saves separate from replaceable imported assets. Use native sandbox paths; no `/tmp` or developer-machine dependency. Verify persistence again on devices.

Exit: I2 accepted with actual audible output and persistence evidence. Human-only audibility or physical interruption checks remain explicit pending items when unavailable; do not invent observation.

## Stage 5 — complete the PS2 frontend

Use `ref/sunpad` for interaction/persistence reference and doc16 for scope. Keep current gameplay input working while implementing. Capture three design directions, choose a consistent Ottsel layout, then validate it live. This is scheduled after the engine gates, not an excuse for a redesign during rendering recovery.

Implement both sticks, D-pad, four face buttons, L1/L2/R1/R2, L3/R3, Start and Select; simultaneous input, pressed/neutral feedback, touch cancellation and controller handoff. Provide editable normalized layouts, persistent configuration, reset, separate iPad/iPhone defaults and accessibility labels.

The persistent three-dot settings entry owns Gameplay, Controls, Video, Audio, Data & Saves and Diagnostics. Implement useful settings only with working behavior and persistence; no decorative controls. Verify every rewired button and settings change during play, after relaunch and during lifecycle transitions. Keep implementation diagnostics out of ordinary user flows unless actionable.

Exit: I3 accepted with gameplay through touch and controller, saved layouts and accessible settings. Trigger-file input does not satisfy this gate.

## Stage 6 — iPhone parity

Stop the owned iPad Simulator first; verify only one iPhone profile is booted. Reuse the same strict code and data contract. Adapt layout/reachability, safe areas and orientation without changing game semantics. Repeat the accepted normal route, meaningful gameplay, audio/lifecycle/save/input matrix and performance observations. Test the smaller touch surface and controller attach/detach explicitly.

Exit: P1 accepted. An iPad pass or universal device-family declaration is not phone evidence. Shared regressions must also be rechecked on iPad, sequentially.

## Stage 7 — reproducible build, import and asset-free package

Finish the Stage 0 reconstruction manifest and document actual dependency/toolchain/pin/patch order, GOAL regeneration, strict build and validation commands in a maintained build guide. Reconstruct from clean source staging and compare required files/generated identities. Avoid depending on an intentionally dirty nested checkout or scripts located only under `/tmp`.

Current `build-ios.sh` hardcodes the Simulator SDK/target and reuses a research app directory while copying mixed TIT/VI1/TEXT resources. Implement a separate explicit device build selection and fresh staging package path; do not present the existing command as device or release ready. No complete iOS packaging/safety driver is currently demonstrated; implement and document it as a deliverable.

Package with an allowlist of engine resources and signed generated code. Inspect container members, not just filenames: a DGO can contain copyrighted art and textures. Reject stale ENGINE.CGO, embedded game resources, logs, diagnostic artifacts and user saves from distribution. Keep engine/license notices and reproducible provenance. Run the same asset-safety policy on git, CI outputs and the final distributable. Do not upload private game content or generated local user packs.

Reuse `scripts/prepare-user-data-pack.sh <local-extracted-root> <new-outside-repo-pack> [fr3-root]` and `scripts/validate-user-data-pack.sh <pack>` as existing local helpers, after reviewing their current validation limits. The private pack contains game assets and is never an asset-free release artifact.

Finish first-launch ownership copy and Files import into durable app storage. Validate manifest, content/version identity, paths and hashes before activation; handle missing/wrong/corrupt packs, cancellation, insufficient space and interrupted replacement without losing a working install or saves. No downloading copyrighted assets. Prove a fresh asset-free app fails helpfully without data, imports the user's local pack and reaches accepted gameplay with no developer path fallback.

Exit: another bot can reconstruct the product from the documented pin/patches and build instructions; a fresh app imports local data and resumes saves; the inspected release bundle is asset-free. Commit only explicitly owned files when appropriate; do not publish or merge unrelated existing work. Remote delivery claims require actual remote verification if publication is requested.

## Stage 8 — physical-device acceptance and closure

Build/sign the device target with available provisioning and install on physical iPad first, then iPhone. Inspect actual architecture, signed executable segments, entitlements and runtime code policy; Simulator signing does not establish this. Repeat normal launch/import/gameplay, audio/interruption, held-input cancellation, background/resume, save/relaunch, device pacing/memory and sustained-play checks.

If device access or provisioning is missing, record the exact missing resource and commands ready to run. Continue independent packaging/host work but leave D1 open. A package that merely signs is not an installed playable product.

Final closure requires all requirement-map rows green, full progression evidence, fresh strict builds and real device proof. Record exact versions, remaining hardware limitations, reproducible build/import instructions and evidence links. Do not claim completion with outstanding rendering, missing content, research RX fallback, untested phone/device behavior or human-only checks.

## Resume handoff

Read `AGENTS.md`, this plan, `RECOVERY_GOAL_LOOP.md` and the top STATUS board. Current first action is disk preflight; September 14 product execution is blocked at 10 GiB, zero temporary packs. Once clear, do Stage 0, then the authenticated GAME extension in Stage 1. The first bounded renderer task remains ALPHA0x48 cloud blending, followed by dynamic eyes. Preserve the eight-module KERNEL baseline and proven recovery fixes.

For each handoff record only: current stage, precise last result/source identity, failing test or missing proof, next command/change, files owned, live runtime/recorder state and external blockers. Keep this plan and the existing recovery loop current rather than generating another chain of prompts.
