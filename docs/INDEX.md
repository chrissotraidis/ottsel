# Docs index

Start with [GOAL_LOOP.md](GOAL_LOOP.md) (the only execution authority) and [STATUS.md](STATUS.md) (current
board). The product requirement is [../jak1-researchloop.md](../jak1-researchloop.md).

## Research and design (Phase 1, still valid)

| Doc | Purpose |
|---|---|
| [00-phase1-brief.md](00-phase1-brief.md) | Reconstructed Phase 1 brief and gates |
| [01-opengoal-architecture.md](01-opengoal-architecture.md) | OpenGOAL architecture and iOS implications |
| [02-execution-model-verdict.md](02-execution-model-verdict.md) | AOT / no-RWX verdict (conditional go) |
| [03-platform-surface.md](03-platform-surface.md) | Graphics, audio, input, files, lifecycle on iOS |
| [04-adjacent-prior-art.md](04-adjacent-prior-art.md) | What transfers from other ports |
| [05-roadmap.md](05-roadmap.md) | Original gated roadmap |
| [06-risks.md](06-risks.md) | Risks and open questions |
| [07-asset-safety.md](07-asset-safety.md) | ROM and asset boundaries |
| [08-emit-site-audit.md](08-emit-site-audit.md) | Runtime emit/link sites |
| [09-arm64-compiler-gap-analysis.md](09-arm64-compiler-gap-analysis.md) | ARM64 backend gaps |
| [10-code-packaging-and-signing.md](10-code-packaging-and-signing.md) | iOS code packaging options |
| [11-graphics-audio-input-deep-dive.md](11-graphics-audio-input-deep-dive.md) | Secondary platform systems |
| [12-research-confidence.md](12-research-confidence.md) | Confidence ratings and falsifiers |
| [SIGNED_AOT_RECOVERY.md](SIGNED_AOT_RECOVERY.md) | How the signed module loader works |
| [macos-settings-and-packaging.md](macos-settings-and-packaging.md) | macOS build, settings and packaging |
| [MODS.md](MODS.md) | Cheats, Play as Mario, texture packs, model replacements and code mods |

## Evidence

- [evidence/](evidence/) - one concise record per proven gate (media stays local). `evidence/H2.5/`
  holds the small ARM64 fixtures the loader regressions read.
