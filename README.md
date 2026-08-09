# Ottsel

Build-and-proof repository for a **native iPadOS/iOS port** of *Jak and
Daxter: The Precursor Legacy* on top of
[OpenGOAL](https://github.com/open-goal/jak-project).

## Status
**Audit verdict (2026-08-09): technically on track; execution order realigned.**

Host ARM64/no-emit gates and the iPad Simulator shell are proven. A Metal shell
spike passes, GAME.CGO compiles for ARM64, and Simulator linking reaches object
204 of 346. Before more renderer/touch work, the project must prove that a real
OpenGOAL artifact runs from signed Mach-O text with no runtime-created
executable code. See [`docs/15-progress-audit.md`](docs/15-progress-audit.md).

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
1. [`docs/15-progress-audit.md`](docs/15-progress-audit.md)
2. [`docs/13-current-state.md`](docs/13-current-state.md)
3. [`docs/STATUS.md`](docs/STATUS.md)
4. [`docs/10-code-packaging-and-signing.md`](docs/10-code-packaging-and-signing.md)
5. [`docs/BOT6_PROMPT.md`](docs/BOT6_PROMPT.md)

The Phase 1 research record remains in `docs/00`–`12`; implementation evidence
is under `docs/evidence/`.
