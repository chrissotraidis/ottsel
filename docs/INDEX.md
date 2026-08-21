# Docs index

Current reading order: `STATUS.md`,
`reports/2026-08-19-ipad-iphone-blocker-investigation.md`, `BOT33_PROMPT.md`,
`15-macos-to-mobile-goal-loop.md`, `13-current-state.md`, then the linked I1
and M1 evidence.

`STATUS.md` begins with the canonical 2026-08-19 audited gate board. The dated
investigation report records the source-level renderer decision and its
falsifiers. `BOT33_PROMPT.md` is the executable goal loop for the next builder;
`15-macos-to-mobile-goal-loop.md` remains the cross-platform gate narrative.
`BOT32_PROMPT.md`, `BOT31_HANDOFF.md`, and prior BOT prompts are
historical handoffs: use them for their evidence and exact experiments, not as
the current definition of product stage. The table retains the Phase 1 and
completed-builder record.

The original plan-only question is retained at
[`reports/2026-08-19-ipad-iphone-blocker-investigation-brief.md`](reports/2026-08-19-ipad-iphone-blocker-investigation-brief.md).

| Doc | Purpose | Status |
|---|---|---|
| [00-phase1-brief.md](00-phase1-brief.md) | Reconstructed Phase 1 operator brief + gates | done |
| [00-loop-log.md](00-loop-log.md) | Research loop log | done |
| [STATUS.md](STATUS.md) | Canonical audited gate board / exit criteria | **current (2026-08-19)** |
| [01-opengoal-architecture.md](01-opengoal-architecture.md) | OpenGOAL architecture for Jak 1 / iOS implications | done (deepened) |
| [02-execution-model-verdict.md](02-execution-model-verdict.md) | **HARD GATE** AOT/no-RWX verdict | done — CONDITIONAL GO (reinforced) |
| [03-platform-surface.md](03-platform-surface.md) | iOS graphics/audio/input/files/lifecycle | done (deepened) |
| [04-adjacent-prior-art.md](04-adjacent-prior-art.md) | What transfers from other ports | done (deepened) |
| [05-roadmap.md](05-roadmap.md) | Gated implementation roadmap | done (added H2.5) |
| [06-risks.md](06-risks.md) | Risks / open questions | done (deepened) |
| [07-asset-safety.md](07-asset-safety.md) | ROM/asset boundaries | done |
| [08-emit-site-audit.md](08-emit-site-audit.md) | Exact runtime emit/link sites | done |
| [09-arm64-compiler-gap-analysis.md](09-arm64-compiler-gap-analysis.md) | ARM64 backend maturity / gaps | done |
| [10-code-packaging-and-signing.md](10-code-packaging-and-signing.md) | iOS code packaging options | done |
| [11-graphics-audio-input-deep-dive.md](11-graphics-audio-input-deep-dive.md) | Secondary platform systems detail | done |
| [12-research-confidence.md](12-research-confidence.md) | Confidence ratings + falsifiers | done |
| [13-current-state.md](13-current-state.md) | Detailed implementation snapshot | current (2026-08-18) |
| [15-macos-to-mobile-goal-loop.md](15-macos-to-mobile-goal-loop.md) | Cross-platform implementation gates and evidence discipline | **current** |
| [reports/2026-08-19-ipad-iphone-blocker-investigation.md](reports/2026-08-19-ipad-iphone-blocker-investigation.md) | Source-rooted renderer decision, proof design, risks, and completion definitions | **current decision** |
| [reports/2026-08-20-jak2-macos-arm64-transfer-research.md](reports/2026-08-20-jak2-macos-arm64-transfer-research.md) | Jak 2 Apple ARM64 implementation audit, Ottsel reuse matrix, exclusions, and bounded adoption gates | **current supplemental research** |
| [BOT33_PROMPT.md](BOT33_PROMPT.md) | Paste-ready goal loop from Direct attribution through device readiness | **current continuation prompt** |
| [14-progress-review.md](14-progress-review.md) | Progress review: why the loop stalled + S1 sub-gate plan | done |
| [15-progress-audit.md](15-progress-audit.md) | Historical signed-AOT/semantic-test realignment | done (2026-08-09) |
| [BOT2_PROMPT.md](BOT2_PROMPT.md) | Full build-agent goal loop | done (hardened) |
| [BOT3_HANDOFF.md](BOT3_HANDOFF.md) | Next-bot goal-based handoff prompt | done |
| [BOT4_HANDOFF.md](BOT4_HANDOFF.md) | Next-bot goal-based handoff prompt (H3 PASS → S1) | done (revised 2026-08-08 with S1.0–S1.4) |
| [BOT5_HANDOFF.md](BOT5_HANDOFF.md) | Next-bot goal-based handoff prompt (S1 PASS → S2) | done |
| [BOT5_PROMPT.md](BOT5_PROMPT.md) | Paste-able goal loop for the S2 build agent | done (2026-08-09) |
| [BOT6_PROMPT.md](BOT6_PROMPT.md) | Paste-able signed-AOT realignment loop | historical |
| [BOT32_PROMPT.md](BOT32_PROMPT.md) | Paste-able visible-playability handoff | historical; superseded by `15-macos-to-mobile-goal-loop.md` |
| [evidence/M1/m1-title-logo-forensics-2026-08-17.md](evidence/M1/m1-title-logo-forensics-2026-08-17.md) | User-visible title corruption and bounded renderer-trace evidence | historical investigation |

Also see repo brief copy at [`jak1-researchloop.md`](jak1-researchloop.md).
