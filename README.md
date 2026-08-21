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

The top section of [`docs/STATUS.md`](docs/STATUS.md) is the canonical
verified/unverified gate board. Read
[`docs/reports/2026-08-19-ipad-iphone-blocker-investigation.md`](docs/reports/2026-08-19-ipad-iphone-blocker-investigation.md)
for the source-rooted renderer decision and
[`docs/BOT33_PROMPT.md`](docs/BOT33_PROMPT.md) for the executable next-builder
loop. Older S1/S2 documents are retained as evidence history, not current
product status.

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
1. [`docs/STATUS.md`](docs/STATUS.md)
2. [`docs/reports/2026-08-19-ipad-iphone-blocker-investigation.md`](docs/reports/2026-08-19-ipad-iphone-blocker-investigation.md)
3. [`docs/BOT33_PROMPT.md`](docs/BOT33_PROMPT.md)
4. [`docs/15-macos-to-mobile-goal-loop.md`](docs/15-macos-to-mobile-goal-loop.md)
5. [`docs/13-current-state.md`](docs/13-current-state.md)

The Phase 1 research record remains in `docs/00`–`12`; implementation evidence
is under `docs/evidence/`.
