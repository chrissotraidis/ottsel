# BOT34 handoff — macOS-first continuation (iPad/iPhone paused)

Date: 2026-08-21

## Fixed objective

The product target remains one honestly playable native Ottsel Jak 1 build
across Apple platforms, with iPhone parity and physical-device readiness after
iPadOS. The execution order is now explicitly:

1. Prove the **current checkout on macOS** stable and visibly playable first.
2. Resume iPadOS renderer/resource parity and playable interaction.
3. Then prove iPhone parity and physical-device readiness.

Preserve one runtime at a time, ROM-safe inputs, the canonical maintained-patch
mechanism, and the signed-native/no-runtime-executable-code boundary. Do not
shrink macOS work to “the Mac boots,” a title, counters, logs, or a static
build claim.

## Exact stop state

- Checkout: `/Users/chrissotraidis/GitHub/ottsel`
- Feature branch before handoff: `codex/r1-macos-adgif-output-mapping-2026-08-21`
- Last completed feature commit before this handoff: `5831f8d`
- Base: `main`/`origin/main` at `549508e`
- Maintained upstream pin: `641fb572e876750d8618434d9f7c1a531b43b366`
- `out/jak-project` is an intentionally dirty user-owned worktree. Preserve
  it; do not reset, clean, or import it wholesale.
- The latest iOS lookup-trace rebuild was intentionally stopped. Do not claim
  that the new `OTTSEL TEX LOOKUP` trace has been proven on iPad.

## What is actually proven

macOS has one fresh bounded stability increment on the current branch/build,
but is still not proven fully stable/playable. The fresh run showed title →
New Game → A/B/C/D1/D2 → Village1 → Training, visible held-W movement, ten
active interaction cycles, coherent post-soak play, and no matching fault
during a 22-minute process lifetime. Its boundaries are equally important:
keyboard-only input, no explicit background/resume proof, no retained raw
audio artifact, no human-audible acceptance, and only a short active soak.
Until those clauses close, macOS is the active queue and every mobile track is
paused for new product work.

iPad has a signed native app, validated imported user data, title/Village1
progress, visible controls, and partial/corrupted Metal output in some runs.
It is not playable. The blank-screen Simulator condition must remain explicit:
a title, counter, first frame, or boot log is not a pass. iPhone parity has not
started. Physical-device readiness is signing/device/acceptance-gated.

R1 proved that the mobile producer emits the 3D DMA phase and that the native
consumer preserves producer TEX0. The current matching macOS phase reaches
TBP `0x24f2`; the mobile phase has produced TBP `0x2b8d`/`0x2bc1` and a
partially corrupted frame. This is a source/resource/state parity problem,
not permission to remap textures.

## Critical traps

`adgif-shader.texture-id` overlays `prims[3]`. `particle-setup-adgif`
overwrites it with GS TEX1 register ID `0x14`; never call that value a logical
texture ID. The new GOAL lookup trace's `dest=0` output is also diagnostic-only
and must not be used as texture identity. Trust raw particle page/index,
AdGif TEX0, and native `first-tex0`/TBP output.

## First open dependency

Complete the remaining clauses of the honest macOS reproducibility/stability
gate on the exact local launch path. The completed increment proves only its
bounded visible-route/interaction subset. The required evidence still includes
cold-start reproducibility with retained raw logs/audio artifacts, human
audible-output acceptance, neutral background/resume/input lifecycle, a longer
controller-led soak, and zero faults. If any clause fails, diagnose the concrete
macOS defect; only after all pass may work resume at the R1 iPad
source/resource comparison below as paused diagnostic work.

R1 remains important, but it is **not** the active first dependency: its
completed iPad page/index trace diverged from macOS (`54,49,48,42,44,...`
versus `4,53,4,18,15,...`). Do not build another mobile trace while macOS is
failing or unproven.

## Exact next work

### Active macOS gate

1. Preserve the completed bounded increment in
   `docs/evidence/M1/m1-macos-bounded-stability-increment-2026-08-21.md`.
2. On macOS only, repeat the cold-start path with one Windowed `gk`, retaining
   raw stdout/stderr/audio-log artifacts this time.
3. Exercise explicit neutral/background-resume/foreground lifecycle and
   disconnect-or-neutral input behavior.
4. Obtain a human audible-output acceptance check through the selected speaker
   route, then record route-change/interruption behavior separately.
5. Run a longer bounded physical-controller soak through the same visible
   route; retain screenshots and fault scans. Keyboard parity may be retained
   as supplemental evidence, not controller acceptance.
6. If any requirement fails, stay on macOS and diagnose that concrete defect
   with the smallest falsifiable regression-first change.

### Paused iPad R1 gate (only after macOS passes)

When unblocked, compare raw `OTTSEL TEX LOOKUP` page/index sequence, particle
IDs, AdGif TEX0, and native `first-tex0`/TBP from the same boot. Trace
page-directory/FR3/DGO ordering/allocation when lookup differs, and texture
object/data-family state when it matches. Do not remap TBP or change camera,
shader, or Metal policy before a falsifiable source-side result.

## Remaining technical debt

- R1: page/index → texture object → AdGif/TEX0 parity between macOS and iPad;
  current Simulator composition remains blank/corrupt.
- P2/I1: finish live Direct/Sprite, transparent and remaining TFRAG/Merc
  material contracts and prove a stable scene-bearing iPad frame.
- P0: external keyboard/controller parity, touch-to-pad behavior, and neutral
  state across disconnect/background/resume.
- AU1/P1: audible output proof, route/interruption coverage, and the supplied
  SDL audio teardown crash.
- P3: fresh iPhone build/run and visual/input/audio/lifecycle parity.
- DVC: physical iPad/iPhone signing, install, launch, input, audio, suspend/
  resume, and performance evidence on real hardware.
- Release: reproducible package, legal user data boundary, no ROM/assets in
  Git, and honest proof labels.
- J2 research: only focused ARM64 emitter/ABI/IR/bridge/controller tests may
  be reused; no MAP_JIT, runtime executable pages, dynamic trampolines,
  game-specific Jak 2 changes, or external Metal shell.

## Stop rules

Do not mark iPad/iPhone playable from a blank Simulator, static counters,
build success, or a title screen. If the same root blocker repeats three
times, write a dated evidence stop report and move to an independent gate;
preserve this objective and handoff rather than silently shrinking scope.
