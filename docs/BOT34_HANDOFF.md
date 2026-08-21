# BOT34 handoff — Ottsel iPad/iPhone continuation

Date: 2026-08-21

## Fixed objective

Deliver an honestly playable native Ottsel Jak 1 build on iPad first, then
prove iPhone parity and physical-device readiness. Preserve one runtime, one
booted Simulator, ROM-safe inputs, the canonical maintained-patch mechanism,
and the signed-native/no-runtime-executable-code boundary. Do not shrink this
to “the Mac version boots” or to a static build claim.

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

macOS is a partial behavioral reference: title → New Game → A/B/C/D1 →
Training, visible world rendering, keyboard/mouse actions, bounded five-minute
soak, and nonzero PCM/device health. Audio audibility, route changes, and
interruption behavior are still open.

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

Complete the same raw page/index lookup trace on iPad and compare it with the
completed macOS sequence. This is the next gate; do not reopen signed-native
foundation or jump to iPhone while the first iPad world frame is still blank
or corrupted.

## Exact next work

1. Apply/verify `patches/h3-jak1-host-boot.patch`, then apply the diagnostic
   `patches/r1-texture-lookup-trace.patch` to the pinned maintained tree.
2. Run `(mi)` for all affected GOAL payloads, then `scripts/build-ios.sh`.
   Verify strict deep codesign and record the executable hash.
3. Use exactly one booted iPad Simulator and one fresh validated user pack.
   Replay title-wait → Start → Cross → Down×4 → Cross.
4. Capture `OTTSEL TEX LOOKUP`, producer AdGif, `MSCAL=211`, and native
   `first-tex0`/TBP records from the same boot. Save screenshot, fault scan,
   input/lifecycle result, and exact commands under `docs/evidence/R1/`.
5. If lookup sequences differ, trace page-directory/FR3/DGO ordering and
   allocation/login state. If they match, trace texture object fields and
   data-family selection. Do not change TBP, camera, shader, or renderer
   policy until this comparison falsifies the source-side hypothesis.
6. After R1 closes, resume Direct/Sprite/material composition, then shared
   input/audio/lifecycle gates, then iPhone size/parity, then physical-device
   proof.

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
