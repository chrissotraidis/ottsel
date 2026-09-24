# Patches — canonical list

Target tree: `open-goal/jak-project` pinned at
`641fb572e876750d8618434d9f7c1a531b43b366`.

## Canonical patch (apply this one)

- **`h3-jak1-host-boot.patch`** — the full Ottsel diff vs the pin: ARM64
  goalc codegen (H1), no-emit runtime (H2), packaging shim (H2.5), and the
  Jak 1 host AOT boot to the GOAL kernel dispatcher loop (H3), plus the
  subsequent signed-native and S2.1 integration work, plus bounded macOS
  title-renderer forensics, macOS controls/audio acceptance, and the current
  iPad no-IOP stream, scene snapshot, and bounded DMA consumer work. 178 files.
  Verified: applies clean to a fresh pin worktree. The nested HEAD is one
  local commit ahead of the pin (`641fb572e` -> `49324a47e`, "Make macOS
  keyboard controls left-hand friendly"), so reconstruct against
  `641fb572e`. Files this patch creates fresh (for example
  `tools/ottsel_a1_1/*`) are untracked in the nested repo, so
  `git apply --check --reverse` is not a valid patch-health check; use an
  ordered forward replay from the pin.

- **`d0-normal-direct-attribution.patch`** — the narrow maintained-source
  probe for D0 glyph attribution, layered on the canonical patch. It records
  the Jak 1 14-qword Direct fingerprint and post-flush desktop draw state
  without changing rendering behavior. The D0 evidence is
  `docs/evidence/D0/d0-normal-direct-attribution-2026-08-19.md`.

- **`d1-generated-direct-fixture.patch`** — the ROM-safe generated Direct
  packet contract test, including the ordered state snapshot and malformed
  packet error regressions.

- **`d2-direct-ir-trace.patch`** — the outer-checkout iOS trace change that
  records the shared Direct IR event order when the real linked-bucket qwc14
  packet is observed. The live packet fingerprint, state snapshot, flush, and
  error-aware ordered sequence are now proven. Because D3 extends the same
  source seam, this refreshed snapshot includes the current D3 additions;
  use the D3 patch as the complete current outer delta.

- **`d3-native-metal-direct-fixture.patch`** — the opt-in native Metal fixture
  consumer and generated 2×2 texture trigger. It includes the current outer
  D2/D3 shell delta so it can be audited as one maintained source change; the
  D3 evidence proves both the generated fixture image and IR-derived geometry,
  not full live Direct texture/state parity.

- **`au1-ios-playback-substrate.patch`** — the upstream-side ownership cleanup
  needed when the maintained Apple SDL playback closure is compiled into the
  iOS runtime. The outer build/lifecycle additions live in the tracked shell
  sources and `scripts/build-ios.sh`; the AU1 evidence is
  `docs/evidence/AU1/au1-playback-substrate-2026-08-20.md`.

- **`r1-sprite3-alpha-fade.patch`** (malformed file — not applicable) — the
  maintained upstream-side shared
  Sprite3 projected-area alpha helper and its ROM-free regression. The outer
  native Metal upload consumes the helper; the source/build evidence is
  `docs/evidence/R1/r1-sprite3-alpha-fade-2026-08-20.md`.

- **`j2r1-sqrt-f32.patch`** — the isolated ARM64 `FSQRT` destination-field fix
  and executable different-register regression extracted from the supplemental
  Jak 2 research. It does not change Ottsel's signed-native product path; see
  `docs/evidence/J2R1/j2r1-sqrt-f32-2026-08-20.md`.

- **`i1-gamepad-remap.patch`** (malformed file — not applicable) —
  selected-instance remap ownership and stale/
  sentinel ID regression. The outer mobile shell routes remaps through
  neutralize/reselect; physical acceptance remains separate. See
  `docs/evidence/I1/i1-gamepad-remap-2026-08-20.md`.

- **`r1-sprite3-depth-policy.patch`** — Jak 1 Sprite3's GEQUAL/no-depth-write
  default is kept separate from the native Direct/TIE depth state, with a
  focused policy regression. This is a renderer-state correction only; see
  `docs/evidence/R1/r1-sprite3-depth-policy-2026-08-20.md`.

- **`f1-fr3-selected-root.patch`** — selected validated user-data root for
  mobile FR3 loading, with a fallback-root regression. This keeps clean
  installs bundle-backed while making imported FR3 data authoritative; see
  `docs/evidence/F1/f1-fr3-selected-root-2026-08-20.md`.

- **`r1-metal-depth-attachment.patch`** (malformed file — not applicable) —
  declares the native Direct/Sprite
  pipeline's `Depth32Float` attachment format explicitly to match the render
  pass; host stability and Sprite3 parity remain open. See
  `docs/evidence/R1/r1-metal-depth-attachment-contract-2026-08-20.md`.

- **`r1-sprite3-normalized-alpha.patch`** (malformed file — not applicable) —
  preserves the normalized Sprite3
  vector color domain during native projected-area fading, avoiding a second
  byte conversion. See
  `docs/evidence/R1/r1-sprite3-normalized-alpha-2026-08-20.md`.

- **`r1-sprite3-alpha-test-policy.patch`** (malformed file — not applicable) —
  wires Jak 1's primary Sprite3
  GEQUAL alpha-test policy into the native fragment state while retaining the
  existing blend/depth boundaries. See
  `docs/evidence/R1/r1-sprite3-alpha-test-policy-2026-08-20.md`.

- **`r1-sprite3-fragment-contract.patch`** (malformed file — not applicable) —
  adds ROM-free pass/reject and
  source-over blend contract tests for the native Sprite3 fragment boundary;
  GPU image proof remains open. See
  `docs/evidence/R1/r1-sprite3-fragment-contract-2026-08-20.md`.

- **Live binding follow-up** — the native upload producer now logs the exact
  alpha/blend contract at the live Sprite3 boundary. See
  `docs/evidence/R1/r1-native-fragment-state-live-2026-08-20.md`.

- **`r1-metal-drawable-readback.patch`** (malformed file — not applicable) —
  one-shot diagnostic drawable
  readback for GPU-pixel inspection; the current Simulator host crashes before
  completion. See
  `docs/evidence/R1/r1-metal-drawable-readback-boundary-2026-08-20.md`.

- **Live native-route follow-up** — normal Metal no longer runs the unconsumed
  CPU/VU1 diagnostic fallback by default; SDL-only and explicit opt-in runs
  retain it for bounded investigation. The route remains open after this
  liveness improvement. See
  `docs/evidence/R1/r1-native-metal-vu-policy-2026-08-20.md`.

- **Live readback follow-up** — resource/present markers now preserve a direct
  native Sprite3 GPU artifact; parity remains open. See
  `docs/evidence/R1/r1-native-sprite-gpu-readback-2026-08-20.md`.

- **Repeatability follow-up** — the selected native Sprite3 GPU artifact is
  byte-identical across two fresh replays; parity remains open. See
  `docs/evidence/R1/r1-native-sprite-gpu-repeatability-2026-08-20.md`.

- **macOS comparison follow-up** — the desktop 2304-sprite/multi-bucket
  reference is recorded against the current one-candidate iPad artifact;
  retained/batched parity remains open. See
  `docs/evidence/R1/r1-macos-sprite3-reference-comparison-2026-08-20.md`.

- **iPad candidate catalog follow-up** — the first 32 iPad candidates are
  recorded; their TBPs do not match the macOS reference phase, so batching is
  deferred. See
  `docs/evidence/R1/r1-ios-sprite-candidate-catalog-2026-08-20.md`.

- **`r1-sparticle-3d-ownership.patch`** — bounded GOAL-side producer
  instrumentation proving whether the 3D particle source is populated before
  Sprite3 DMA emission. It is diagnostic-only; phase ownership and renderer
  parity remain open. See
  `docs/evidence/R1/r1-sparticle-3d-producer-ownership-2026-08-21.md`.

- **`r1-particle-adgif-goal-source.patch`** and
  **`r1-particle-adgif-mips2c-output.patch`** — bounded GOAL/MIPS2C AdGif traces
  of particle texture-id page/index and lookup hit/miss before TEX0/TEX1
  setup. They are diagnostic-only and do not remap textures or alter
  rendering.

- **`r1-texture-lookup-trace.patch`** — bounded GOAL-side page-2
  `lookup-texture-by-id` tracing, retaining the resolved texture only for
  diagnostics. It does not change lookup behavior or rendering; the iOS-safe
  formatter uses float casts and explicit newlines. The printed `dest` field is
  not authoritative; correlate raw page/index with AdGif TEX0 and native
  `first-tex0`/TBP. The completed iPad capture diverges from macOS in ordered
  page/index membership. See
  `docs/evidence/R1/r1-texture-lookup-page-directory-trace-2026-08-21.md`.

- **`r1-macos-settings-menu.patch`** — macOS debug-toolbar `Settings → Ottsel`
  submenu with runtime 1x–4x internal upscaling and master-audio mute. It is
  layered after `49324a47` and does not change the mobile renderer path.

## Superseded / historical (do not apply)

- `h1-arm64-goal-function-codegen.patch` — H1 slice only (subset of the
  canonical patch).
- `h2-noemit-runtime-host.patch` — H2 slice only (superset of H1; subset
  of the canonical patch).
- `h3-jak1-kernel-arm64-compile.patch` — H3 compile slice only (superset
  of H1/H2; subset of the canonical patch).

## Patch-file health (2026-09-14 scan)

A `git apply --check` scan of all 62 files here — forward and reverse, against
both the nested `out/jak-project` tree and this outer tree — sorts them into
21 already-resident (reverse-applicable), 9 create-fresh (untracked, which is
exactly the known `--reverse` false negative described above under the
canonical patch), 16 overlays whose base has since moved (the ordered A1.1
chain, `au1-ios-playback-substrate`, and the superseded `r1-sparticle-*`/
`r1-particle-adgif-*`/trace diagnostics), 5 absent from the root under test,
and 11 malformed. Only the malformed group is a real defect.

### Malformed patch-file records (do not apply)

Eleven files in this directory are not valid unified diffs: `git apply` rejects
each one with `patch with only garbage` or `corrupt patch`, in the nested and
outer trees alike. Every one is a stale hand-authored snapshot of a change
already resident in the working tree, so leaving them unapplied loses nothing.

- Bare `@@` hunk header with no line numbers: `i1-gamepad-remap.patch`,
  `r1-level-login-owner-trace.patch`, `r1-native-digital-latch.patch`,
  `r1-sparticle-launch-texture-owner.patch`.
- Truncated or count-mismatched hunk body: `r1-ios-gfx-sync.patch`,
  `r1-metal-depth-attachment.patch`, `r1-metal-drawable-readback.patch`,
  `r1-sprite3-alpha-fade.patch`, `r1-sprite3-alpha-test-policy.patch`,
  `r1-sprite3-fragment-contract.patch`, `r1-sprite3-normalized-alpha.patch`.
- Found by the hunk-level checker (2026-09-23, `scripts/verify-overlay-hunks.py`):
  `a11-loader-fail-closed.patch` is rejected by `git apply` with `corrupt patch at line 39`
  even though the overlay list still carries it as live.  Its two target files are reproduced
  by other patches, so it is a stale snapshot and nothing is lost by dropping it:
  `game/kernel/jak1/kscheme.cpp` by `a11-host-cbridge-counters.patch` and
  `a11-signed-export-banks.patch`, and `game/kernel/common/ottsel_signed_gstate.cpp` by
  `a11-data-only-main-segment.patch`, `a11-kind2-method-counts.patch` and
  `a11-module-record-extensions.patch` (both named with the checker's `--file` mode).

Their recorded intent also survives elsewhere: the Sprite3 helpers and their
ROM-free tests are already carried by `h3-jak1-host-boot.patch`, the drawable
readback probe by `d3-native-metal-direct-fixture.patch`, and the remaining
sites (`src/shell/main.cpp`, `src/shell/metal_shell.mm`,
`game/sce/ottsel_platform_input.*`, `game/ios_stubs.cpp`,
`game/mips2c/jak1_functions/sparticle_launcher.cpp`) match the current working
tree. Regenerate any standalone record from a reviewed working-tree delta
rather than repairing these files.

For the current crash-boundary recovery, apply `h3-jak1-host-boot.patch`
followed by `jak1-link-begin-argument-regression.patch`. The latter preserves
the signed-size argument guard and its focused regression that previously
existed only in the nested checkout. The historical H1/H2/H3 slices above
remain for bisection; do not apply them on top of H3.

    git -C out/jak-project apply ../../patches/jak1-link-begin-argument-regression.patch
    python3 scripts/verify-link-begin-patch.py

The verification reconstructs only the three linker/test files from the pin
plus these two patches; it does not certify the entire dirty nested checkout.
The recovery also preserves the current platform regressions in
`mobile-platform-regressions.patch` (test source only, after H3):

    git -C out/jak-project apply ../../patches/mobile-platform-regressions.patch

This includes the camera-bearing terrain owners and the 69/70 bucket boundary;
the former negative expectations for buckets 12/68 contradicted the producer.

The delivery audit preserves two additional current-source deltas after H3:

- `jak1-soundbank-offset.patch`: `game/overlord/jak1/fake_iso.cpp` only;
  locates the soundbank payload by `SBlk`/`SBv2` signature instead of assuming
  COMMON's fixed offset. Signature false positives and missing-signature
  behavior still need focused validation; preservation is not audio acceptance.
- `jak1-loader-spool-recovery.patch`: `goal_src/jak1/engine/load/loader.gc`
  only; retains the locked-buffer recovery and its existing diagnostics.
  The eviction conditions and logging volume still need focused validation.

Current recovery order on a fresh pinned source tree is H3, linker argument
regression, mobile platform regressions, soundbank offset, loader recovery, A1.1 relocation validation, ARM64 vector preservation:

    git -C out/jak-project apply ../../patches/jak1-soundbank-offset.patch
    git -C out/jak-project apply ../../patches/jak1-loader-spool-recovery.patch
    git -C out/jak-project apply ../../patches/a11-relocation-validation.patch
    git -C out/jak-project apply ../../patches/arm64-goal-vector-preservation.patch

Both new overlays were checked by reconstructing just their source files from
pin `641fb572e876750d8618434d9f7c1a531b43b366`, applying H3 and the overlay in
a temporary directory, and comparing every byte with the current nested file.
They also reverse-apply cleanly to the current nested checkout. Regenerate
the affected GOAL artifacts and perform a full runtime build after application;
`--shell-only` cannot incorporate these changes. Remaining nested differences
are not certified by this patch stack. See
`docs/reports/2026-09-12-delivery-audit.md` for the product execution and asset boundary.

`a11-relocation-validation.patch` preserves the slice emitter and its shared bounded validator after H3. It rejects unsupported objects/relocations before writing assembly or maps; this is supported-slice validation, not a general AOT loader. Reconstruction of these two files was byte-identical. Run `bash scripts/test-a11-relocations.sh`, rebuild the emitter, and use the full iOS build to regenerate the linked slice. `--shell-only` retains old generated AOT.

`arm64-goal-vector-preservation.patch` corrects actual C-call helper Q-register restore ordering and preserves full vectors across mips2c calls. The four-slot ABI regression reproduced both faults and passes after the fix; bootstrap/common-window/static-export checks also pass. Apply after H3, run `bash scripts/test-a11-export-slots.sh`, then perform a full iOS build. A two-file signed-slice proof does not validate the rest of the runtime ABI.

## Sprite menu contracts and retained level aliases

Apply these narrow overlays after H3 and the existing nonoverlapping recovery overlays:

    git -C out/jak-project apply ../../patches/jak1-level-dgo-aliases.patch
    git -C out/jak-project apply ../../patches/sprite3-tcc-rgb.patch
    bash scripts/test-mobile-sprite-contract.sh

The alias overlay separately preserves the existing complete level-name mapping
and its tests. The TCC overlay changes only Sprite3's texture-presence contract
and its old color-only test: desktop samples texture RGB for both TCC values;
TCC=0 overrides sampled alpha. Mobile upload/atlas copies implement that alpha
policy without mutating cached pixels. The shell/gfx call-site changes live in
the outer repository, not in the nested overlay.

Reconstruction was verified from H3 plus these two overlays against all three
proposed nested files, byte for byte. Other preexisting nested deltas are not
certified by this check. The standalone source-derived contract regression
checks actual upload/index predicates and upload-color code plus the maintained
snapshot store; it does not compile Metal or prove a complete menu frame.
Run the normal iOS build and fresh menu-transition validation after applying.

## Regenerating

Preserve the existing H3 patch. Create each new overlay from an explicitly
reviewed set of files against the pinned source plus its prerequisite overlays.
Do not regenerate H3 from every local change: the active nested checkout contains
unrelated work that has not been certified for reconstruction.

Verify the full ordered overlay stack in a separate staging directory, compare
the affected files byte for byte with the intended source, and run the relevant
regressions. An application check alone does not prove the reconstructed build.

`a11-complete-module-emitter.patch` extends the existing emitter with complete-object `--module` mode; apply after `a11-relocation-validation.patch`. Run `bash scripts/test-a11-module.sh` and rebuild the actual emitter target. The test validates genuine Gstate code/data, all records, immutable tags, linked target/range/protection checks and malformed inputs. It does not execute GOAL or install a loader.

This mode requires a single common-window arena layout and an explicit allocator reservation for module data. The generated one-module layout reserves the measured data span from the global heap tail; the fixture derives its offset from current `memory_layout.h`. Production must shorten the signed configuration global heap, aggregate all module layouts, validate actual bootstrap Type identity and use the linked arena as `g_ee_main_mem` before activation. No production allocator or loader change is included. Ordinary `__TEXT`/`__DATA` addresses must not be converted to GOAL pointers.

`apple-audio-lifecycle-intent.patch` preserves pause intent across asynchronous SDL device opening in the existing Apple player. Run `python3 test/audio_output_lifecycle_test.py` (nine actual-method checks). Reconstruction from pinned player blob75187366e9777ad15ac6a76fdcae54070a3442af plus H3 and this overlay matches the applied file byte for byte; do not reapply AU1 over H3. Fresh app lifecycle validation remains pending.

`mobile-sound-command-ownership.patch` preserves the existing mobile player RPC plus reviewed GOAL sound-ID ownership and shared listener/falloff calculations. Pin641fb572 + H3 + overlay reconstructs srpc.cpp/ssound.cpp/ssound.h exactly. Run `bash scripts/test-mobile-sound-commands.sh` (28 actual-source checks). Apply `mobile-player-rpc-dispatch.patch` for the existing SIF PLAYER-channel route. The six affected files reconstruct byte-exactly from pin + H3 + both overlays, and33 extracted dispatch/command/spatial checks pass. Fresh full-build audio validation remains pending; bank loading/dialogue and automated native pitch are not implemented by this overlay.

`mobile-sound-iop-isolation.patch` applies after sound-command ownership. It excludes dormant IOP/SPU bootstrap and IOP music-volume functions from the mobile object, while keeping shared sound math/listener methods. The iOS build explicitly compiles common/ssound.cpp and jak1/ssound.cpp. Initial link failed before these dependencies were included; actual iOS object symbol inspection verifies no CreateSema/gVoice/gMusicTweak references after isolation. Full app relink is pending.

`a11-signed-gstate-loader.patch` adds the default-off mixed-runtime loader experiment; apply after A11 module emitter and current link/ABI overlays. Root host replay with actual link_and_exec and regenerated valid? passes for legacy Gstate and aggregate Gstring→Gstate. Mode1/2 Simulator prove exact signed registrations and normal Training controls; mode3bf7ac085 also proves signed Gcommon entry/return and controls, fault0. Maintained aggregate generator/allocator tests pass; see scripts/test-a11-aggregate-arena.py. Read `docs/SIGNED_AOT_RECOVERY.md`; do not run opt-in with stale gcommon/KERNEL objects.

`mobile-sound-bank-loading.patch` applies after sound-command ownership and PLAYER dispatch. It preserves the previous RPC_Player header declaration and adds synchronous loader-channel LOAD/UNLOAD through existing fake-ISO/bank registry. Compile common/sbank.cpp in the iOS target;42 extracted source checks pass. Native decoder integration, live Training bank playback and fresh full link remain pending.

`a11-scalar-float-module.patch` applies after complete-module emitter and adds only compiler-produced ADRP + unsigned LDR-S relocations into aligned static data. `test-a11-module.sh` verifies genuine Gstring167 targets plus existing Gstate controls. Signed Gstring activation and aggregate arena allocation pass separate host and mode2/3 app checks; see the signed recovery document.

`a11-signed-export-banks.patch` routes ordinary bootstrap and Mips2C exports through fixed signed banks under the default-off flag. Apply after current signed-module/ABI overlays. Actual host census279 and applied-bank vector/stack ABI tests pass; Simulator build02315601 proves all banks and normal Training controls with fault0. See `docs/reports/2026-09-13-signed-export-banks.md`.

`a11-release-debug-module.patch` applies after scalar-float module support. Explicit `--release-no-debug` preserves and validates the complete source while omitting debug from loaded layout and mapping its address references to GOAL zero. `python3 scripts/test-a11-module-release.py NEW_OUTPUT_DIRECTORY` passes genuine Gcommon372 and aggregate578 linked targets, malformed guards and exact128MiB arena layout. Actual signed Gcommon activation passes host/combined-bank checks and mode3bf7ac085 normal Training controls.

`a11-kernel-module-emitter.patch` applies after release-debug module support. It adds top-only/hyphenated modules with collision checks, kernel-context/state references and bounded RW pointer relocation support preserving low tags. See `scripts/test-a11-kernel-emission.py`; root all-eight emission/link/pointer-oracle replay passes; full-KERNEL host631/combined-bank657 and app9ea8a4ca normal Training/recorded controls now pass, fault0. Explicit app selection uses config/signed-kernel-full.json; GAME/levels remain research code.

`a11-module-record-extensions.patch` applies after `a11-kernel-module-emitter.patch` and before `a11-signed-export-banks.patch`. It promotes into maintained source the kind-5 code-target and distance32 SIMD-load support that had existed only as untracked nested edits, so a reconstruction from the other overlays alone would reintroduce the loader SIGABRT. It changes exactly three files: `tools/ottsel_a1_1/a11_module_emitter.h` (`ModulePointer.code`, the `target < seg.text` code branch with its 4-byte-aligned in-text bound, `(add & 0xffc00000) == 0x3dc00000` acceptance class with a 16-byte-aligned/in-bounds target, the `ldr q<n>, [x<n>, <ref>@PAGEOFF]` assembly case, and `"kind":"code"/"data"` plus `target_offset` manifest emission), `game/kernel/common/ottsel_signed_gstate.h` (`Pointer{value,code}`), and `game/kernel/common/ottsel_signed_gstate.cpp` (the `validate_module` data/code branch and the `link()` `pointer.code ? offset(segment.code) + pointer.value : pointer.value` value). The two outer generators `scripts/emit-signed-module-arena.py` and `scripts/emit-signed-gstate-manifest.py` already accept code records. The `0x3dc00000` class is SIMD&FP LDR Q (size=00, opc=11, a full 128-bit Q register whose section-relative `@PAGEOFF` the assembler scales by sixteen), not LDR D (`0xfd4...`, size=11/opc=01); the maintained text previously mis-labelled it, and emitting the wrong mnemonic silently perturbs the loaded address. Four more outer-repo working-tree files are not part of the nested overlay and are captured by no patch: `scripts/a11-corpus-census.py`, `test/a11_module_macho_check.py` and `test/a11_aggregate_macho_check.py` scale the distance-32 oracle by 16 for the LDR Q class, and `test/a11_module_test.cpp` keeps LDR D rejection as an unsupported class while adding 16-aligned genuine-LDR-Q acceptance plus unaligned and past-data rejections. Reconstruct from pin `641fb572e876750d8618434d9f7c1a531b43b366` plus the seven prerequisite overlays; the three files are byte-exact, and a clean ten-patch replay leaves 172/187 stack-touched files identical to the working tree. Run `bash scripts/test-a11-module.sh`, `python3 scripts/test-a11-kernel-emission.py NEWDIR`, `python3 scripts/test-a11-gstate-loader.py NEWDIR --module-list config/signed-kernel-full.json`, `python3 scripts/test-a11-module-release.py NEWDIR`, `python3 scripts/test-a11-gstate-activation.py NEWDIR`, and `python3 scripts/test-a11-aggregate-arena.py NEWDIR`. Runtime contract and the ldr-d to ldr-q attribution delta are in `docs/evidence/A1/a11-whole-corpus-census-2026-09-14.log`.

`a11-kind2-method-counts.patch` applies after `a11-module-record-extensions.patch`. It replaces the emitter's kind-2 type-name whitelist with the load-time `(name, methods)` identity the runtime already implements, so only the four bootstrap names (`function`, `string`, `kernel-context`, `state`) stay pinned at nine methods and every other data-side record carries the object's own count. Two nested files change: `tools/ottsel_a1_1/a11_module_emitter.h` (the `(name == "function" || ...) && methods != 9` guard) and `game/kernel/common/ottsel_signed_gstate.cpp` (the `validate_module` `SlotKind::TypePointer` branch, with a separate `require` pinning the three data-side bootstrap names to nine). Both are byte-exact after replaying pin `641fb572e876750d8618434d9f7c1a531b43b366` plus the eight prerequisite overlays. Two outer-repo working-tree files are not part of the nested overlay and are not captured by any patch: `scripts/emit-signed-module-arena.py` now mirrors the pin for `string`/`kernel-context`/`state` (text-side `function` records are `immutable_function_tag` there and never reach the `type_pointer` branch), and `test/a11_module_test.cpp` splits the old whitelist control into a text-side rejection plus a data-side acceptance case. Run `bash scripts/test-a11-module.sh`, `python3 scripts/test-a11-kernel-emission.py NEWDIR`, `python3 scripts/test-a11-gstate-loader.py NEWDIR --module-list config/signed-kernel-full.json`, `python3 scripts/test-a11-module-release.py NEWDIR`, `python3 scripts/test-a11-gstate-activation.py NEWDIR`, and `python3 scripts/test-a11-aggregate-arena.py NEWDIR`. The relaxation changes which GAME members can be emitted; it does not install a loader or prove whole-game activation. Runtime contract, measured corpus attribution and the before/after emitter evidence are in `docs/evidence/A1/a11-whole-corpus-census-2026-09-14.log`.


`a11-ordered-activation.patch` applies after `a11-kind2-method-counts.patch`. It removes the last KERNEL name pinning from the signed loader so any distinct non-empty ordered registry activates in generated array order. Two nested files change: `game/kernel/common/ottsel_signed_gstate.cpp` (the caller-sized `bool loaded[8]` becomes `std::vector<uint8_t> loaded` assigned `module_count` zeros in `prepare_arena`; `validate_module`'s `expected_release` KERNEL-name tuple is replaced by the object-derived `manifest.segments[1].source_text_size != 0`; `validate_layout` drops the bounded count plus the canonical-KERNEL/comparison name-order arrays, keeping `module_count >= 1` and the final-`gstate` check while adding empty- and duplicate-name rejection; the `link()` order-mismatch message loses its KERNEL wording) and `game/kernel/common/ottsel_signed_gstate.h` (the `modules[]` comment becomes "Generated ordered activation list, gstate last."). Both are byte-exact against the current nested files after replaying pin `641fb572e876750d8618434d9f7c1a531b43b366` plus the overlays that create and edit these two files in order — `a11-signed-gstate-loader.patch`, `a11-module-record-extensions.patch`, `a11-kind2-method-counts.patch` — and reverse-apply cleanly to the current nested checkout. Six outer-repo working-tree files are not part of the nested overlay and are captured by no patch: `config/signed-ordered-control.json` (a new schema-1 ordered control that drops `dgo-h` from the canonical eight), `config/signed-math-control.json` (the canonical chain plus the two GAME data members and the dependency-ordered GAME math prefix `math`, which emits under the object-derived release policy and activates through the ordered registry at 199 checks), the generalized `test/a11_kernel_manifest_test.py` (reads `MODULE_LIST`, asserts the list-derived `module_count`, gates the gkernel-specific cases on the aggregate `gkernel.json`, and renames `canonical-eight` to `accepted-registry-N`), the third-member ordered negative control in `test/a11_gstate_loader_test.cpp`, the `with_ordered` wiring in `scripts/test-a11-gstate-loader.py` that also runs the manifest guards, and the object-derived release policy plus widened generation loop in `scripts/build-ios.sh`. Run `bash scripts/test-a11-module.sh`, `python3 scripts/test-a11-kernel-emission.py NEWDIR`, `python3 scripts/test-a11-gstate-loader.py NEWDIR --module-list config/signed-kernel-full.json`, `python3 scripts/test-a11-module-release.py NEWDIR`, `python3 scripts/test-a11-gstate-activation.py NEWDIR`, and `python3 scripts/test-a11-aggregate-arena.py NEWDIR`. The loader's guard remains order-agnostic in the sense that it enforces the generated array order, which is the required load order; this overlay is necessary but not sufficient for GAME, since data-only GAME members are still rejected before activation.

`a11-data-only-main-segment.patch` applies after `a11-ordered-activation.patch` and removes the last corpus restriction: a GAME member whose main segment carries static data and no signed text (collision, texture and similar declaration-only helpers) previously aborted emission with `unsupported data-only main segment`. Two nested files change: `tools/ottsel_a1_1/a11_module_emitter.h` (the segment-0 guard becomes `result.segments[0].size && !result.segments[0].text && !result.segments[0].loaded` with the message `unsupported unloaded data-only main segment`, and the kind-4 distance32 branch gains `if (!seg.text) throw std::runtime_error("distance record in textless segment")`, because a distance record rewrites an ADRP/consumer instruction pair and can only live where signed text does) and `game/kernel/common/ottsel_signed_gstate.cpp` (the `validate_module` segment loop replaces the one-line textless rejection with `code = 0`, a `continue` for a zero-text zero-data segment that carries no writable records, and a `segment_index == 0 && data_size == source_size` requirement for a data-only one, moving the arena-overlap check and RX protection into the `else`). The record loop needs no change: `SlotKind::FunctionTag` already requires `text_size >= 8` and `pointer.code` already requires `pointer.value + 4 <= source_text_size`, so with `text_size == 0` every text-side record is structurally impossible while `protection(segment.data, ...)` still maps the whole template. Both files are byte-exact against the current nested checkout after replaying pin `641fb572e876750d8618434d9f7c1a531b43b366` plus the nine prerequisite overlays in order, and the patch reverse-applies cleanly. Six outer-repo working-tree files are not part of the nested overlay and are captured by no patch: `config/signed-data-only-control.json` (a new schema-1 control that keeps the canonical eight and inserts the data-only `merc-vu1` before the final `gstate`), `config/signed-gamedata-control.json` (the same chain with the code-bearing `ocean-vu0` added; a genuine GAME member's init calls `__pc-get-mips2c`, so the new `OTTSEL_SIGNED_GAMEDATA_TEST` lane in `scripts/test-a11-gstate-loader.py` and `test/a11_gstate_loader_test.cpp` calls `Mips2C::register_all_jak1()` first, mirroring `kboot.cpp:115`), `scripts/a11-corpus-census.py` mirrors the same guard and the same textless-distance rejection in its emitter port, `test/a11_module_test.cpp` adds positive `merc-vu1`/`ocean-vu0` cases (`data_type_records == 2` for ocean-vu0) plus a malformed-distance negative control, `test/a11_module_macho_check.py` checks the two data-only manifests (`data_size` 20 and 280, zero text, no distances, no pointers, no immutable function tags), and `scripts/test-a11-module.sh` runs both modules through the CLI and direct emission and requires byte equality. Run `bash scripts/test-a11-module.sh NEWDIR`, `python3 scripts/a11-corpus-census.py --relax-all`, `python3 scripts/test-a11-kernel-emission.py NEWDIR`, `python3 scripts/test-a11-module-release.py NEWDIR`, `python3 scripts/test-a11-gstate-activation.py NEWDIR` and `python3 scripts/test-a11-aggregate-arena.py NEWDIR`. This closes the last emission restriction (872/872 code members would emit, residual 0); it does not install a loader; the maintained fixture now carries the data-only member (`config/signed-data-only-control.json`, 181 checks all PASS) and the code-bearing `ocean-vu0` member (`config/signed-gamedata-control.json`, 190 checks all PASS), each entering and returning through the real `link_and_exec` after `Mips2C::register_all_jak1()` mirrors `kboot.cpp:115`.

`a11-loader-fail-closed.patch` applies after `a11-data-only-main-segment.patch`. Diagnostic slot capture is find-only; intern_from_c still creates relocation symbols and aborts if the symbol table is full. Find-only relocation slots are not used: they fail KERNEL at gcommon delete-car!. Host 2026-09-15: KERNEL 631, GAME deep 78/802 PASS; GAME full 315 SIGSEGV at gsound ENTER. See docs/evidence/A1/a11-loader-fail-closed-2026-09-14.md.

`a11-asm-ret-fail-safe.patch` is a pin-to-current snapshot of `goalc/compiler/IR.cpp` (the h1/h2/h3 compiler overlays do not compose for that file in any tested order, so this one overlay supersedes their hunks). It makes `IR_AsmRet::do_codegen_arm64` select the .ret target instead of branching into data. A1.1: `x16 = x30` (the lowering continuation), `x30 = [sp]` (the slot), keep the slot only when the value looks like an address this port executes, else fall back to x16. A1.6: the keep-mask must come from the slot (`mov x17, x30; lsr x17, x17, #32`), otherwise the mask came from whatever x17 held on entry and the fail-safe was inert exactly when the slot held an EE value. A1.8 (2026-09-22): the high-half-zero test was too weak - the strict lane died returning into 0x50ffffffff, a GOAL frame local at [sp] whose high half is 0x50, so the guard kept it and pc == lr == x30 left the image - so the slot is now kept only when its high half is in [1, 8] (this port executable window [0x1_00000000, 0x9_00000000)), otherwise the select falls back to the incoming x30. These bytes are baked into `out/jak1/obj/*.o` (byte-swapped, at a non-4-aligned file offset) and the slice emitter copies them, so shipping a change requires `goalc --game jak1 --isa arm64 -c (mi)` (546 targets, which also rewrites KERNEL/GAME/ENGINE.CGO - the signed preflight requires the loose objects and the containers to match) and then the app build; all 8 guarded sites (aligner 1, gkernel 6, gstate 1) then carry the new test. Regressions: `bash scripts/test-a11-asm-ret-guard.sh`, `python3 scripts/verify-asm-ret-guard-patch.py`, `bash scripts/test-a11-call-goal-asm-ret.sh`. Evidence: docs/evidence/A1/a11-asm-ret-window-2026-09-22.md.

`a11-goal-bridge-regfile.patch` applies after `a11-call-goal-synthetic-return.patch` (both are listed in
`scripts/verify-asm-synthetic-return-patch.py`, which reconstructs `game/kernel/asm_funcs_arm64.s` from the
pin plus the h3, vector-preservation and synthetic-return overlays).  It makes the two GOAL->C++ trampolines `_arg_call_arm64` and `_stack_call_arm64` preserve GOAL register file (x19-x28 plus v8-v15) as well as the two remaining C->GOAL
bridges, `_call_goal_asm_arm64` and `_call_goal8_asm_arm64`, save and restore GOAL register file
(x19-x28 plus v8-v15) the way `_call_goal_on_stack_asm_arm64` already did.  Without it a GOAL caller with a
live value in x19/x23-x28 loses it across a bridge call; measured on the strict signed-GAME lane that
destroyed display-loop disp in x19.  Regression: `scripts/test-goal-bridge-regfile.py`.

  A1.7c-fix (2026-09-22): the first revision of the `_stack_call_arm64` hunk pushed its GPR block after the
  vector block while the epilogue still popped the vectors first, so x19-x28 were restored from the vector
  save area (x19 came back 0) and v8-v15 from the GPR slots.  That is what made the strict lane store through
  a null rpc-buffer-pair at rpc-h seg0 +0x8b8.  The GPR block now sits immediately after `stp q15, q14` so the
  pop sequence is the exact reverse of the push sequence, and the regression simulates the stack offsets
  (a presence-only check missed it).  Evidence: `docs/evidence/A1/a11-stack-call-regfile-order-2026-09-22.md`.

## a11-kernel-continuation-slot.patch (2026-09-22)

`a11-kernel-continuation-slot.patch` is a pin-to-current snapshot of the nested checkout's
`goal_src/jak1/kernel/gkernel.gc` (it also carries the previously unpatched BOT30 S2.1 x30 hunks in
`set-to-run`, so it supersedes `h3-jak1-host-boot.patch`'s hunks for that file in the same way
`a11-asm-ret-fail-safe.patch` supersedes the h1/h2/h3 hunks for `goalc/compiler/IR.cpp`).

It fixes G1.18 - the strict signed-GAME lane losing `*display*` (x19) in `display-loop` - which was
root-caused with lldb hardware breakpoints plus Python breakpoint callbacks to the suspend return
path, not to a clobber inside `display-loop`: the loop-end `(suspend)` at `main+0xbf08` ran
`thread-suspend`, whose A1.8 guarded `.ret` read `0x00000050ffffffff` (a GOAL frame local) as its
return slot.  The window test correctly rejected it, and the fail-safe fell back to the incoming
`x30` - the caller's link register for an asm-func entered by a GOAL call - so `display-loop` was
resumed with the kernel's register file (`pp = 0`, x19 = a kernel-stack address) and `thread-resume`
never ran for that dispatch.

The patch makes `thread-resume` and `reset-and-call` push their incoming `x30` (the kernel's true
continuation; verified by lookup as `gkernel_s0_code + 23892`) as the first of the kernel-stack
slots, and makes `thread-suspend`, `return-from-thread` and `return-from-thread-dead` pop that sixth
slot into `x30` and then leave through the guarded `.ret` (A1.13).  The sixth pop is what keeps the
kernel stack balanced: with five pops plus the non-advancing `.ret` the kernel resumed with
`sp = *kernel-sp* + 0x50 = entry_sp - 0x10`, i.e. 0x10 low on every suspend/resume, and after a few
dispatches the kernel frames read each other's slots (`execute-process-tree`'s recursion was entered
with a rotated argument group).  The stash is also the `.ret`'s fallback when the caller's synthetic
slot is unreadable.

Operational: the change is GOAL source, so it only ships after
`goalc --game jak1 --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'` (which also rewrites
the CGOs the signed preflight matches) and then the app build.  The shipped `__GOAL,__text` then
carries the new prologue at exactly two sites: `reset-and-call` (file `0x108979dac`) and
`thread-resume` (`0x10897a0d4`).  Verified once in a fresh strict run: all 15 DGO objects served
(`title-vis` last), level linked, `OTTSEL TEX REMAP` reported, and 6131+ display frames at
`drawn=0`, where before the lane lost x19 inside four loop iterations.  A1.13 then balanced the
suspend side (see above) and - with the A1.14 kernel/activation stack separation below - the pp=0
data-target class is retired: two fresh strict runs fault 0, serve all 55 village1 objects and link
`oracle` (see `docs/evidence/A1/a11-kernel-stack-separation-2026-09-22.md`).  Regression:
`python3 /Users/chrissotraidis/GitHub/ottsel/scripts/verify-kernel-continuation-slot.py`
(reverse-applies this overlay and checks the six edit anchors).  Evidence:
`docs/evidence/A1/a11-kernel-continuation-slot-2026-09-22.md`.

### a11-asm-ret-fail-safe.patch - A1.11 update (2026-09-22)

The A1.8 window ("the slot's high half is in [1, 8]") still accepts *any* host address, and the strict
lane then died returning into a GOAL stack address: pc == lr == x30 == ee + 0x7fffe10, pp = 0,
x19 = the address of the string "village-cam" (measured live under lldb). The keep-test is now the port's
*module block*, [x22 + 0x8000000, x22 + 0x8c30000) - the only executable region here (x22 = ee; the emitted
modules are ~0xc205c0 bytes at that base). The GOAL heap (0x13fd20..0x3db0000), the module data
(ee + ~0x3xxxxxx), the app image and export-bank stubs, and every stack now fall back to the incoming link
register, which is what a C-entered, trampoline-entered or thread-start .ret wants. Measured in the shipped
objects: all 8 guarded sites (aligner 1, gkernel 6, gstate 1) carry the new constants and the old A1.8/A1.6
word forms are gone. Regression: test/a11_asm_ret_guard_test.cpp (14 cases, including the measured
ee + 0x7fffe10 stack escape and the data/heap/app/EE/frame words), run by
bash scripts/test-a11-asm-ret-guard.sh; the overlay is regenerated pin->current and
python3 scripts/verify-asm-ret-guard-patch.py PASSes. Evidence:
docs/evidence/A1/a11-ret-window-stack-2026-09-22.md.


## a11-kernel-stack-separation.patch (2026-09-22, A1.14)

`a11-kernel-stack-separation.patch` is a narrow overlay on `game/kernel/jak1/kboot.cpp` (the
pre-existing S2.1/OTTSEL_IOS work in that file belongs to `h3-jak1-host-boot.patch`, so this patch
carries only the A1.14 hunk and must be applied after it).

It closes the strict signed-GAME lane's pp=0 / data-call-target class.  The kernel runs on a stack
anchored at the top of EE memory (`goal_stack = ee + EE_MAIN_MEM_SIZE - 16`) and every C->GOAL
activation - kboot's listener entry, klink's `link_and_exec` and the signed loader's
`call_goal_on_stack` - anchors at that same address.  A deep activation (the signed villagep-obs
type/method install, measured ~0x1e0 bytes of frames) runs while the kernel is suspended inside a
dispatch, so its frames overwrite the kernel's saved slots: the suspend side popped a GOAL frame
local (`0x00000050ffffffff`) where the caller's synthetic return slot belonged and a stack address
where the A1.10 stash belonged, and the guarded `.ret` rejected the slot and followed its fallback
into the stack (`pc = lr = fault addr = ee + 0x7FFFE10`, SIGBUS, right after `served obj 1 (oracle)`).
The same clobber produced the earlier A1.7c/A1.10/A1.12 symptoms at shallower depths (a return into
the caller's continuation with the kernel register file; the rotated `execute-process-tree` argument
group).

The patch keeps the kernel 64 KiB below the top (`kActivationStackReserve = 0x10000`), so the
activations own the top of EE memory; the kernel's frames only ever grow into the free EE tail (the
heap ends at 0x3db0000).  Regression
`python3 /Users/chrissotraidis/GitHub/ottsel/scripts/verify-kernel-stack-separation.py` checks the
reserve expression, that the activation call sites still anchor at the top, and that this overlay
reverse-applies.  Verified: two fresh strict runs with a 0-byte fault log, all 55 village1 DGO
objects served, `LINKBEGIN: name=oracle` + `signed took oracle`, 346 ENTER = 346 RETURNED, and
`scene-level='village1'` with live draws; the host build shares this kboot change and has not been
re-run there.  Evidence: `docs/evidence/A1/a11-kernel-stack-separation-2026-09-22.md`.


## a11-diagnostic-traces.patch (2026-09-22, Stage 0 reconciliation)

`a11-diagnostic-traces.patch` is a narrow overlay over two GOAL files whose dirty deltas had no
overlay: the bounded BOT62 world-position trace in `goal_src/jak1/engine/gfx/shadow/shadow.gc`
(gated by `*ottsel-target-trace-left*`, so it prints one frame in sixteen for a bounded window) and
the title-screen option trace in `goal_src/jak1/engine/ui/progress/progress-draw.gc` (gated on
`display-state = title`).  Both print diagnostics only and change no gameplay behaviour; they are
captured so the nested checkout is reconstructible.

2026-09-22 (I1): the same overlay now also carries `OTTSEL TARGET VEL: v=(~f,~f,~f) t=(~f,~f,~f)` and
`OTTSEL TARGET GRAV: g-len=~f g-n=(~f,~f,~f)` in shadow.gc - the BOT62 window's second and third lines,
reporting `(-> self control transv)` and `(-> self control dynam)` next to `trans`.  The velocity line
prints on the one-in-sixteen cadence **and immediately whenever `|transv.y| > 1000`**, because a jump
impulse lasts about half a second and a fixed cadence simply misses it (that omission is what made an
earlier reading call a working jump broken).  Diagnostic-only: same counter, no gameplay change.  The
overlay is regenerated from `git -C out/jak-project diff` for both files, reverse-applies to the current
checkout and keeps `scripts/verify-overlay-coverage.py` passing; after the recompile (`(mi)`, 546 targets)
the 8 guarded `.ret` sites (`bash scripts/test-a11-asm-ret-guard.sh`) and all 90112 KERNEL code words
(`python3 scripts/validate-arm64-emission.py --cgo out/jak1/iso/KERNEL.CGO`) still validate.  Evidence:
`docs/evidence/A1/i1-jump-works-measured-arc-2026-09-22.md`.

2026-09-22 (I2): the null-name placeholder in this overlay's `progress-draw.gc` trace is now `<null-name>`
instead of the word `NONE`, because `NONE` was read as "the save slot is empty" while the row on screen
actually named the save.  `progress-draw.gc` is the desktop draw path; **the iOS lane's own
`OTTSEL G1:` lines are emitted from `goal_src/jak1/pc/progress-pc.gc`** (line ~3315 for the item fields and
~3322 for the `str=` line), which is inside the canonical `h3-jak1-host-boot.patch` rather than in this
overlay - so that file's identical `NONE` placeholder is left alone (editing it would drift the canonical
patch's hunks without a full h3 regeneration) and its `str="NONE"` must be read as "the option has no name
text", never as game state.  Overlay regenerated with
`git -C out/jak-project diff -- goal_src/jak1/engine/gfx/shadow/shadow.gc goal_src/jak1/engine/ui/progress/progress-draw.gc`,
reverse-applies clean, coverage guard PASS, and after a GOAL re-emit (`(mi)`, 546 targets) the 8 guarded
`.ret` sites and all 90112 KERNEL code words still validate.


## i2-audio-pcm-capture.patch (2026-09-22, I2)

`i2-audio-pcm-capture.patch` is a narrow overlay on `game/sound/989snd/player.cpp` - the Apple playback
callback the lane actually uses - layered after `apple-audio-lifecycle-intent.patch` (the lifecycle intent
work already in that file belongs to it, so this patch carries only the new hunks).  It adds a file-scope
`extern std::string ottsel_ios_writable_dir();` (external linkage: the definition lives in the shell), a
bounded `AudioDumpState`, and one call in `Player::sdl_sound_callback` after `Tick` fills the buffer.
With `OTTSEL_AUDIO_DUMP=<seconds>` the PCM handed to the SDL stream is written to
`<writable>ottsel-audio-dump.wav` (S16 stereo 48 kHz) and one peak/RMS line is logged per second of
captured audio; without the variable nothing is opened, written or logged, and the callback's behaviour is
otherwise unchanged (silence is captured too, which is the point).

Verified: the overlay reverse-applies to the current checkout, `pre + overlay` reconstructs the file
byte-for-byte, and `scripts/verify-overlay-coverage.py` passes; the file also passes a standalone
`-fsyntax-only` compile with the lane's flags (the first attempt failed twice: `s16Output` is a
`{s16 left; s16 right;}` frame rather than a scalar, and the `extern` had to sit outside the anonymous
namespace to keep external linkage).  Evidence:
`docs/evidence/A1/i2-audio-pcm-measured-device-open-blocks-2026-09-22.md`.

The Stage 0 reconciliation guard `python3 scripts/verify-overlay-coverage.py` now requires every
dirty nested delta to appear in some maintained overlay and fails on any new uncovered source file.
This pass: 180 dirty entries, 178 overlaid, 2 documented unreferenced strays (`--help/`, a stray
`ottsel-a11-slice` output directory, and the 0-byte `goal_src/jak1/kernel/aligner.gc`, which
`game.gp` does not reference - it builds `anim/aligner.gc`).  Evidence:
`docs/evidence/A1/stage0-baseline-inventory-2026-09-22.md`.


## a11-host-cbridge-counters.patch (2026-09-22, A1.15)

`a11-host-cbridge-counters.patch` is a narrow overlay on `game/kernel/jak1/kscheme.cpp`.  Without it the
macOS reference lane cannot be built: `game/kernel/asm_funcs_arm64.s` (patched by the A1.7b/A1.7c
overlays) writes eight `ottsel_cbridge_*` diagnostics around every GOAL->C++ call, and only the iOS
product shell (`src/shell/ios_boot.cpp`) and the assembly-only test harness
(`test/a11_call_goal_asm_ret_test.cpp`) defined them, so `ninja -C out/jak-project/build/h1 gk` failed at
link time with `Undefined symbols: _arg_call_arm64` and the checked-in `gk` stayed a stale Aug 23 binary.

The overlay defines the eight counters in the inner runtime for every non-iOS build under
`#ifndef OTTSEL_IOS`, so the iOS app keeps the shell copy and no symbol is duplicated.  Regression
`python3 /Users/chrissotraidis/GitHub/ottsel/scripts/verify-host-cbridge-counters.py` checks the guarded
definitions, every counter the assembly references, the iOS shell copy and that the overlay
reverse-applies.  Verified: `ninja -C build/h1 gk` links, and the rebuilt lane boots the kernel and links
216 top-levels (it then hits the pre-existing `IR_AsmRet` boot fault, which is L1 of the parity loop, not
this patch).  Evidence: `docs/evidence/A1/macos-ios-parity-review-2026-09-22.md`.


## i0-fake-iso-missing-root.patch (2026-09-22, I0)

`i0-fake-iso-missing-root.patch` is a narrow overlay on `game/overlord/common/fake_iso.cpp` (the
pre-existing `g_fake_iso_root` S2.1 work in that file belongs to `h3-jak1-host-boot.patch`, so this
patch carries only the new hunk and must be applied after it).

It closes the iPad lane's fresh-install abort.  With no imported user pack the sound root resolves to a
missing `<bundle>/iso_data/SBK`, and `fake_iso_FS_Init()`'s *throwing* `fs::directory_iterator(root)`
raised `ghc::filesystem::filesystem_error` out of a consumer that the GOAL asm bridges had reached
(they carry no unwind information), so `ottosel_ios_run_boot`'s `catch (const std::exception&)` never
saw it and the process died with `libc++abi: terminating ...` ~2 minutes into every fresh install.
The root is now tested with `fs::is_directory(root, ec)`, reported once by name
(`[FAKEISO] no readable root {}: {}; sound data is unavailable`; the sound loader retries its bank RPC,
so the message is one-shot) and returns `-1` - the failure contract `mobile_sound_banks_ready` and the
three `ios_boot.cpp` probe sites already check.

Verified: pin `641fb572e876750d8618434d9f7c1a531b43b366` + H3 + this overlay reconstructs
`game/overlord/common/fake_iso.cpp` byte-for-byte, the overlay reverse-applies to the current nested
checkout, and `python3 scripts/verify-overlay-coverage.py` still passes.  Two fresh-install runs (no
pack anywhere) report the F1 missing-family line plus exactly one named-root line, no
`terminating`/`uncaught exception`, 346 ENTER = 346 RETURNED and a 0-byte fault log while running the
full measurement window; with the pack imported the guard never fires and the lane reaches the title
unchanged.  Evidence: `docs/evidence/A1/i0-fresh-install-named-error-2026-09-22.md`.

## g2.2-sky-blend-and-ledger.patch (2026-09-22, G2.2)

Narrow overlay on the outer shell sources (`src/shell/mobile_blend_policy.h` (new),
`src/shell/mobile_direct_frame.h`, `src/shell/metal_shell.h`, `src/shell/metal_shell.mm`,
`src/shell/metal_gfx.mm`); the pre-existing dirty deltas in those files belong to the R1/D2/D3/L3
overlays and are not repeated here.  Generated against a reconstructed pre-G2.2 state and verified in
both directions (`git apply --check` on that pre-tree and `git apply --reverse --check` against the
current tree).  It supersedes the two probe-only overlays recorded earlier the same day.

1. `mobile_blend_policy.h` decodes the GS ALPHA register (`common/dma/gs.h`: a=bits0-1, b=bits2-3,
   c=bits4-5, d=bits6-7, `fix=data>>32`) into the six combinations the desktop DirectRenderer supports
   plus `Unsupported`; a zero register is `Unspecified` because both native capture paths reset the
   decoder's draw state before walking a bucket.  Regression: `bash scripts/test-mobile-blend-policy.sh`
   (`test/mobile_blend_policy_test.cpp`, host `clang++`, 12/12 PASS).
2. `metal_shell.mm` adds the additive pipeline state (rgb SrcAlpha/One/Add, alpha One/Zero) and selects
   it at the Sky site from the batch's own register, unconditionally, as upstream's DirectRenderer does.
   The Direct site now carries `diagnostic_alpha` (plumbing only; its selection is unchanged).
3. `metal_gfx.mm` skips the bucket-3 sky draw by default: upstream's `SkyRenderer` draws it from the
   64x96 sky texture its SkyBlend handlers composite (buckets 32/39), a composite this lane does not
   implement, and the port's own sky composite already draws the sky region - drawing the raw quads
   double-drew it with uncomposited data, which the live additive registers (32x32 cloud tiles 0x48)
   turned into a vivid rainbow over village1.
4. `metal_gfx.mm` also carries the bucket-54 MERC eye decoder (`submit_mobile_native_eye_bucket`):
   upstream's `EyeRenderer` chain (128-byte GS offset packet, 32-byte alpha setup, NEXT/NOP, then per eye
   slot an ADGIF + background + iris L/R + pupil L/R + lid L/R) is decoded and composed on the CPU into
   128x128 RGBA per slot with the oracle's mapping (GS 512..1024 at four units per texel) and blend rules
   (background/iris/lid copies, pupil SRC_ALPHA/ONE_MINUS_SRC_ALPHA); `ottsel-trace-eye-dump` writes PPMs
   of the composed slots and their source pages.  Nothing is bound yet, so the visible eyes are unchanged.
5. Observability: the store ledger inside `OttselMobileDirectFrame` plus the bounded `SKYSTORE`,
   `SKYREG-MIX`, `TIEREG`, `DIRECTREG-MIX`, `SKYBLEND`, `SKYUV` and 1 Hz `SKY SHAPE` records, and two
   live A/B controls (`ottsel-trace-sky-skip-draw`, `ottsel-trace-sky-draw-legacy`).

Note for A/Bs: the sky store retains its last published population, so measure default-state behaviour
in a fresh process after using `ottsel-trace-sky-draw-legacy`.  Evidence:
`docs/evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md`,
`docs/evidence/A1/g2-live-blend-register-ledger-2026-09-22.md`,
`docs/evidence/A1/g2-sky-additive-blend-2026-09-22.md`,
`docs/evidence/A1/g2-sky-draw-source-2026-09-22.md`,
`docs/evidence/A1/g2-merc-eyes-bucket54-decode-2026-09-22.md`.

Note for A/Bs: the sky store retains its last published population, so measure default-state behaviour
in a fresh process after using `ottsel-trace-sky-draw-legacy`.  Evidence:
`docs/evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md`,
`docs/evidence/A1/g2-live-blend-register-ledger-2026-09-22.md`,
`docs/evidence/A1/g2-sky-additive-blend-2026-09-22.md`,
`docs/evidence/A1/g2-sky-draw-source-2026-09-22.md`.

## Reconstruction: the working-tree source gap

`g2-working-tree-source-gap.patch` closes the file-level reconstruction.  A fresh pin worktree plus
`h3-jak1-host-boot.patch` reproduces 153 of the 178 files h3 touches byte-for-byte.  Applying every other
overlay in `patches/` that `git apply --check` accepts, in sorted order, repeating until no more apply (31
of them - the rest are superseded by h3, outer-tree-only, or corrupt, e.g. the documented
`a11-loader-fail-closed.patch`) brings that to 182 of 193 nested files.  The remaining 11 files (395 changed
lines) were working-tree diagnostic and experiment edits that no earlier overlay captured, so this patch is
that delta and nothing else:

  game/kernel/common/ottsel_signed_gstate.cpp, game/kernel/common/ottsel_signed_gstate.h,
  game/kernel/jak1/kscheme.cpp, game/sce/sif_ee.cpp, game/sound/989snd/player.cpp,
  goal_src/jak1/engine/camera/cam-update.gc, goal_src/jak1/engine/target/target-death.gc,
  goal_src/jak1/kernel/gkernel.gc, goal_src/jak1/levels/title/title-obs.gc,
  goal_src/jak1/pc/progress-pc.gc, goalc/compiler/IR.cpp

It applies after h3 and those 31 overlays (it was generated against exactly that state), and the recipe then
reproduces all 193 nested files byte-identically - verified end to end from a second fresh pin worktree.
This is a file-level proof only; the reconstructed build and application run remain open.

## G2.3 dialogue: the iOS VAG voice-line player

`g23-ios-vag-dialogue.patch` (nested) and `g23-ios-vag-dialogue-shell.patch` (outer) are the two halves of one
change: the iOS sound path had no VAG dialogue player, so a voicebox hint - which plays a sound named
`spool-<line>` - fell through the mobile `RPC_Player` to the bank lookup and was dropped.

- nested `game/overlord/jak1/srpc.cpp`: a `spool-` branch in the `#ifdef OTTSEL_IOS` handler that calls the
  shell bridge instead of the bank lookup, with the bridge declared at file scope like `ottsel_ios_writable_dir`.
- outer `src/shell/ios_boot.cpp`: `ottsel_ios_play_vag_dialogue(name8)` - parses `VAG/VAGDIR.AYB` once
  (807 entries, 8-character name + u32 offset **in 2048-byte sectors**), reads the line from `VAG/VAGWAD.ENG`,
  and starts it with the engine's own VAG voice, keeping the last four sample buffers alive because the voice
  holds a raw pointer into them.

Both apply to the current tree (the guard reverse-applies them cleanly) and are the delta the reconstruction
needs on top of h3 + the overlays + `g2-working-tree-source-gap.patch`.  Evidence:
`docs/evidence/A1/g23-dialogue-ios-vag-player-2026-09-23.md`.

`g23-ios-vag-cutscene.patch` (nested) is the cutscene half of the same work: the iOS PLAY-STR channel was only
clock-emulated in `game/sce/sif_ee.cpp`, so cutscenes advanced without audio.  The branch now resolves the name the
way the desktop `RPC_PLAY` does (`$`-prefixed is already a VAG name, otherwise `ISONameFromAnimationName`) and calls
the shell player.  Landing it also fixed a `char[48]` name copied into a 17-byte local (`__stack_chk_fail` -> SIGABRT
in `sceSifCallRpc`) and a sample buffer freed while a long cutscene line was still decoding; `g23-ios-vag-dialogue-shell.patch`
was regenerated for the second fix.  Evidence: `docs/evidence/A1/g23-dialogue-cutscene-vag-2026-09-23.md`.

`g23-ios-vag-stop-shim.patch` and `g23-ios-vag-stop-shim-header.patch` add `snd_StopVAGProbeShared` to the sound
shim, called from the iOS stream-stop branch through the shell so a skipped cutscene does not keep talking;
`g23-ios-vag-cutscene.patch` and `g23-ios-vag-dialogue-shell.patch` were regenerated to include it.  Evidence:
`docs/evidence/A1/g23-dialogue-cutscene-vag-2026-09-23.md`.

`g23-audio-master-volume-label.patch` relabels the AUDIO row to `MASTER VOLUME`: it drives
`snd_SetMasterVolume(16, ...)`, and setting it to 0 silences the whole mix (level ambience and dialogue included),
which the earlier `MUSIC VOLUME` label misdescribed.  `g23-ios-vag-dialogue-shell.patch` was regenerated for the
bounded `ottsel-trace-vag-off` diagnostic.  Evidence:
`docs/evidence/A1/g23-audio-master-volume-and-dialogue-audibility-2026-09-23.md`.

`g23-ios-vag-cutscene.patch` and `g23-ios-vag-dialogue-shell.patch` were regenerated for the per-stream stop: one
shared `ottsel_play_token` resolves the PLAY-STR command's name for both play and stop, and the shell stops only
the line the engine is playing.  Evidence:
`docs/evidence/A1/g23-dialogue-voice-works-and-stream-stop-2026-09-23.md`.

`g23-audio-master-volume-label.patch` now carries the fix rather than the label: `apply_music_volume` scales the
music handler's own groups (1 and 2, see `ssound.cpp` `SetMusicVol`) instead of group 16, the synth master, which
muted the whole mix; the row keeps its `MUSIC VOLUME` name, with a comment recording the brief `MASTER VOLUME`
relabel.  Evidence: `docs/evidence/A1/g23-music-volume-and-dialogue-in-mix-2026-09-23.md`.

`g26-status-screen-flag.patch` fixes a display bug the bounded `OTTSEL DATA: status` diagnostic found: only the
fallback path in `select_ios_iso_data_dir()` clears `g_has_user_data`, so a mid-run re-import can no longer make a
frame raise the status screen - which then stuck over the game because its clear sits in a branch that is skipped
once the scene is live.  Evidence: `docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.

It also hoists `status_overlay_active` and clears the overlay after the branch that uploads it, so a status screen
raised while the scene is already live cannot stick over the game.

`g23-spool-owner-alive-trace.patch` (nested `loader.gc`) adds an `owner-alive` field to the `STALL-ART` spool trace
and a dead-owner branch to the port's `OTTSEL SPOOL RECOVER`.  The trace is what found the real cause of the
cutscene stall - the spool owner resolves to an invalid object rather than `#f`, so the game's 'locked -> 'active
promotion never runs - and the branch is inert for that shape.  Evidence:
`docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.
