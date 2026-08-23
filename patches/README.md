# Patches — canonical list

Target tree: `open-goal/jak-project` pinned at
`641fb572e876750d8618434d9f7c1a531b43b366`.

## Canonical patch (apply this one)

- **`h3-jak1-host-boot.patch`** — the full Ottsel diff vs the pin: ARM64
  goalc codegen (H1), no-emit runtime (H2), packaging shim (H2.5), and the
  Jak 1 host AOT boot to the GOAL kernel dispatcher loop (H3), plus the
  subsequent signed-native and S2.1 integration work, plus bounded macOS
  title-renderer forensics. 60 files.
  Verified: applies clean to a fresh pin worktree and reverse-applies
  cleanly against the working worktree (`git apply --check --reverse`).

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

- **`r1-sprite3-alpha-fade.patch`** — the maintained upstream-side shared
  Sprite3 projected-area alpha helper and its ROM-free regression. The outer
  native Metal upload consumes the helper; the source/build evidence is
  `docs/evidence/R1/r1-sprite3-alpha-fade-2026-08-20.md`.

- **`j2r1-sqrt-f32.patch`** — the isolated ARM64 `FSQRT` destination-field fix
  and executable different-register regression extracted from the supplemental
  Jak 2 research. It does not change Ottsel's signed-native product path; see
  `docs/evidence/J2R1/j2r1-sqrt-f32-2026-08-20.md`.

- **`i1-gamepad-remap.patch`** — selected-instance remap ownership and stale/
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

- **`r1-metal-depth-attachment.patch`** — declares the native Direct/Sprite
  pipeline's `Depth32Float` attachment format explicitly to match the render
  pass; host stability and Sprite3 parity remain open. See
  `docs/evidence/R1/r1-metal-depth-attachment-contract-2026-08-20.md`.

- **`r1-sprite3-normalized-alpha.patch`** — preserves the normalized Sprite3
  vector color domain during native projected-area fading, avoiding a second
  byte conversion. See
  `docs/evidence/R1/r1-sprite3-normalized-alpha-2026-08-20.md`.

- **`r1-sprite3-alpha-test-policy.patch`** — wires Jak 1's primary Sprite3
  GEQUAL alpha-test policy into the native fragment state while retaining the
  existing blend/depth boundaries. See
  `docs/evidence/R1/r1-sprite3-alpha-test-policy-2026-08-20.md`.

- **`r1-sprite3-fragment-contract.patch`** — adds ROM-free pass/reject and
  source-over blend contract tests for the native Sprite3 fragment boundary;
  GPU image proof remains open. See
  `docs/evidence/R1/r1-sprite3-fragment-contract-2026-08-20.md`.

- **Live binding follow-up** — the native upload producer now logs the exact
  alpha/blend contract at the live Sprite3 boundary. See
  `docs/evidence/R1/r1-native-fragment-state-live-2026-08-20.md`.

- **`r1-metal-drawable-readback.patch`** — one-shot diagnostic drawable
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

Apply only `h3-jak1-host-boot.patch`. The others are kept for bisection.

## Regenerating

From inside the pinned worktree with all local changes applied:

    git diff <pin> > ../patches/h3-jak1-host-boot.patch

Then verify on a fresh pin worktree with `git apply --check`.
