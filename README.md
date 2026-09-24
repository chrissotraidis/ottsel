# Ottsel

Build-and-proof repository for a **native iPadOS/iOS port** of *Jak and
Daxter: The Precursor Legacy* on top of
[OpenGOAL](https://github.com/open-goal/jak-project).

## Status
**Self-audit (2026-08-19): partially playable on macOS; iPad is an active
renderer-integration prototype, not yet a playable mobile game.**

- **macOS:** a native arm64 `gk` has completed the retail title → New Game →
  Training path with rendered scenes, keyboard/mouse pad-state evidence, and a
  five-minute active soak. Physical-controller acceptance and a fresh audible
  output/route soak remain open.
- **iPad Simulator:** the signed no-emit runtime boots the game, the real New
  Game path reaches Village1, keyboard/touch-to-pad state and lifecycle-neutral
  handling are proven, and Metal displays partial full-screen Village1
  TIE/TFRAG geometry. Direct/Sprite composition, remaining renderer buckets,
  visible touch controls, mobile audio, and iPhone/device validation are open.
- **Not a release:** no physical iPhone/iPad acceptance, distributable build,
  or bundled game data is claimed. Users supply their own local game data; the
  repository contains no game assets.

The current execution plan is [`docs/RECOVERY_GOAL_LOOP.md`](docs/RECOVERY_GOAL_LOOP.md).
The [September 12 recovery review](docs/reports/2026-09-12-recovery-review.md)
separates verified progress from source defects and unsupported gameplay claims.
The top of [`docs/STATUS.md`](docs/STATUS.md) records the current step; older
boards and numbered BOT prompts remain evidence history.

## What this repo contains
- `docs/` — plans, gate board, evidence, audits, and continuation prompts
- `src/` — iOS Simulator shell and Metal spike
- `scripts/` — iOS build and ARM64 emission-validation tools
- `patches/` — maintained delta against the pinned OpenGOAL checkout
- `ref/` — research corpus (upstream sparse checkout, docs, prior-art notes)
- `out/` — ignored local build/source/data worktree
- No game assets. Supply your own legal PS2 copy for local builds.

## Hard constraints
- No ISOs/extracted copyrighted assets in git
- No RWX/JIT or runtime-created executable-code product path on iOS
- Simulator RX-blob execution is research infrastructure, not product proof
- Simulator iteration: one device simulator at a time
- At most one runtime executable; no fullscreen test executable

## Start here
1. [`docs/RECOVERY_GOAL_LOOP.md`](docs/RECOVERY_GOAL_LOOP.md)
2. [`docs/reports/2026-09-12-recovery-review.md`](docs/reports/2026-09-12-recovery-review.md)
3. [`docs/STATUS.md`](docs/STATUS.md)
4. [`docs/16-ipados-ios-goal-loop-2026-08-23.md`](docs/16-ipados-ios-goal-loop-2026-08-23.md)
5. [`docs/00-phase1-brief.md`](docs/00-phase1-brief.md) and [`docs/05-roadmap.md`](docs/05-roadmap.md)
6. [`docs/macos-settings-and-packaging.md`](docs/macos-settings-and-packaging.md)

### macOS test controls

The native Windowed build defaults to `W/A/S/D` movement, mouse motion camera
control, left/right mouse for Cross/Circle, `Space/E/F/R` for
Cross/Circle/Square/Triangle, `Return` or `Esc` for Start/pause, and `Tab` for
Select/map. `I/J/K/L` provide keyboard camera movement; release every key or
button to return to neutral. Press Left Alt for the debug toolbar, then use
`Settings → Ottsel` for runtime upscaling and mute controls.

Package a Finder-visible macOS app with `./scripts/package-macos.sh`.

The Phase 1 research record remains in `docs/00`–`12`; implementation evidence
is under `docs/evidence/`.
