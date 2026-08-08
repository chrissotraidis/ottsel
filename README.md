# Ottsel

Research and planning repository for a **native iPadOS/iOS port** of *Jak and Daxter: The Precursor Legacy* on top of [OpenGOAL](https://github.com/open-goal/jak-project).

> Phase 1 (research) is complete in [`DOCS/`](DOCS/).  
> Build work starts from [`DOCS/BOT2_PROMPT.md`](DOCS/BOT2_PROMPT.md).

## Status
**Execution-model verdict: CONDITIONAL GO.**

OpenGOAL currently targets x86-64 and relies on runtime-linked executable code in a writable EE memory model. iOS requires ARM64 AOT with no runtime CPU code emission. That problem is gated first; see [`DOCS/02-execution-model-verdict.md`](DOCS/02-execution-model-verdict.md).

## What this repo contains
- `DOCS/` — plans, verdict, roadmap, Bot 2 prompt
- `ref/` — research corpus (upstream sparse checkout, docs, prior-art notes)
- No game assets. Supply your own legal PS2 copy when building later.

## Hard constraints
- No ISOs/extracted copyrighted assets in git
- No RWX/JIT product path on iOS
- Simulator iteration: one device simulator at a time

## Start here
1. [`DOCS/INDEX.md`](DOCS/INDEX.md)
2. [`DOCS/STATUS.md`](DOCS/STATUS.md)
3. [`DOCS/02-execution-model-verdict.md`](DOCS/02-execution-model-verdict.md)
4. [`DOCS/08-emit-site-audit.md`](DOCS/08-emit-site-audit.md)
5. [`DOCS/BOT2_PROMPT.md`](DOCS/BOT2_PROMPT.md)

Deep-pass research also covers ARM64 gaps, packaging/signing, and platform systems in `DOCS/09`–`12`.
