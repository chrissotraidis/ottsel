# Ottsel

Build-and-proof repository for a **native iPadOS/iOS port** of *Jak and
Daxter: The Precursor Legacy* on top of
[OpenGOAL](https://github.com/open-goal/jak-project).

## Status
**2026-09-23: playable in the iOS Simulator; not yet run on a device.**

- **macOS:** native arm64 `gk` plays title → New Game → Training at 60 fps.
- **iPad/iPhone Simulator:** the strict signed-AOT build (no JIT, no runtime
  code writes) loads all 346 game modules and plays Training by touch, with
  sound and background/foreground recovery. The iPad Simulator runs at
  roughly 5–10 fps.
- **Physical devices:** not yet attempted. That is the current gate.
- Users supply their own game data; the repository contains no game assets.

## Start here
1. [`docs/GOAL_LOOP.md`](docs/GOAL_LOOP.md) — the single execution plan
2. [`docs/STATUS.md`](docs/STATUS.md) — the current board
3. [`jak1-researchloop.md`](jak1-researchloop.md) — the original requirement
4. [`patches/README.md`](patches/README.md) — rebuilding the OpenGOAL tree

## What this repo contains
- `docs/` — goal loop, status, Phase 1 research, evidence, reports, history
- `src/shell/` — the iOS app shell and Metal renderer
- `scripts/` — builds, route drivers, signed-AOT tools and regressions
- `patches/` — `ottsel-jak-project.patch`, the whole delta against the
  pinned OpenGOAL checkout
- `config/` — signed module lists for the build profiles
- `ref/` — local research corpus (ignored)
- `out/` — ignored local build/source/data worktree
- No game assets. Supply your own legal PS2 copy for local builds.

## Hard constraints
- No ISOs/extracted copyrighted assets in git
- No RWX/JIT or runtime-created executable-code product path on iOS
- Simulator RX-blob execution is research infrastructure, not product proof
- Simulator iteration: one device simulator at a time
- At most one runtime executable; no fullscreen test executable

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
