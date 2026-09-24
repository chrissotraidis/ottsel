# Docs index

Current reading order: [`PROJECT_COMPLETION_PLAN.md`](PROJECT_COMPLETION_PLAN.md),
[`RECOVERY_GOAL_LOOP.md`](RECOVERY_GOAL_LOOP.md),
[`reports/2026-09-12-recovery-review.md`](reports/2026-09-12-recovery-review.md),
[`reports/2026-09-12-delivery-audit.md`](reports/2026-09-12-delivery-audit.md),
then the top recovery board in [`STATUS.md`](STATUS.md) and the gate definitions
in [`16-ipados-ios-goal-loop-2026-08-23.md`](16-ipados-ios-goal-loop-2026-08-23.md).
The original scope remains [`00-phase1-brief.md`](00-phase1-brief.md) and
[`05-roadmap.md`](05-roadmap.md). Numbered BOT prompts and earlier dated boards
are historical evidence, not competing execution authorities.

| Doc | Purpose | Status |
|---|---|---|
| [00-phase1-brief.md](00-phase1-brief.md) | Reconstructed Phase 1 operator brief + gates | done |
| [00-loop-log.md](00-loop-log.md) | Research loop log | done |
| [STATUS.md](STATUS.md) | Current recovery board followed by historical evidence | **current top board** |
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
| [13-current-state.md](13-current-state.md) | Detailed implementation snapshot | historical (2026-08-18) |
| [15-macos-to-mobile-goal-loop.md](15-macos-to-mobile-goal-loop.md) | Cross-platform implementation gates and evidence discipline | historical |
| [reports/2026-08-19-ipad-iphone-blocker-investigation.md](reports/2026-08-19-ipad-iphone-blocker-investigation.md) | Source-rooted renderer decision, proof design, risks, and completion definitions | historical decision |
| [reports/2026-09-03-ipad-village1-render-audit.md](reports/2026-09-03-ipad-village1-render-audit.md) | iPad Village1 render audit: confirmed causes (level latch, inverted depth, Merc camera, missing sky/HUD, dropped sound RPC), falsified assumptions, next experiments | historical audit (2026-09-03) |
| [reports/2026-08-20-jak2-macos-arm64-transfer-research.md](reports/2026-08-20-jak2-macos-arm64-transfer-research.md) | Jak 2 Apple ARM64 implementation audit, Ottsel reuse matrix, exclusions, and bounded adoption gates | **current supplemental research** |
| [PROJECT_COMPLETION_PLAN.md](PROJECT_COMPLETION_PLAN.md) | End-to-end PRD recovery, implementation stages, proof commands and final acceptance | **current completion guide (2026-09-14)** |
| [RECOVERY_GOAL_LOOP.md](RECOVERY_GOAL_LOOP.md) | Recovery through full iPad/iPhone acceptance and delivery | **current execution loop** |
| [reports/2026-09-12-recovery-review.md](reports/2026-09-12-recovery-review.md) | Source-backed progress review and redirections | **current review** |
| [BOT33_PROMPT.md](BOT33_PROMPT.md) | Earlier Direct attribution queue | historical |
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
| [evidence/A1/a11-signed-game-dispatch-fault-2026-09-21.md](evidence/A1/a11-signed-game-dispatch-fault-2026-09-21.md) | Stage 0 reconciliation, the `.ret` fail-safe and the signed-GAME dispatch fault reading | historical investigation |
| [evidence/A1/a11-recursive-dispatch-kernel-context-2026-09-22.md](evidence/A1/a11-recursive-dispatch-kernel-context-2026-09-22.md) | Strict dispatch crash localized: the process walk reaches the static kernel-context; heap/arena overlap and `*active-pool*` refuted | current investigation |
| [evidence/A1/a11-walk-link-owner-2026-09-22.md](evidence/A1/a11-walk-link-owner-2026-09-22.md) | Which EE words hold the bad `this` and where the walk was fed; dispatcher argument group correct one frame up | current investigation |
| [evidence/A1/a11-asm-ret-guard-mask-2026-09-22.md](evidence/A1/a11-asm-ret-guard-mask-2026-09-22.md) | `.ret` fail-safe mask fix: proof, regression, and the move of the crash into the village/font phase | current investigation |
| [evidence/A1/a11-signed-game-vs-legacy-ab-2026-09-22.md](evidence/A1/a11-signed-game-vs-legacy-ab-2026-09-22.md) | Control run: the surviving village/font fault needs arena-executed GAME code | current investigation |
| [evidence/A1/a11-font-work-buf-null-2026-09-22.md](evidence/A1/a11-font-work-buf-null-2026-09-22.md) | The null field is `font-work.buf`: a static structure in font-h data that no source or initializer fills | current investigation |
| [evidence/A1/a11-font-buffer-caller-named-2026-09-22.md](evidence/A1/a11-font-buffer-caller-named-2026-09-22.md) | The null dma-buffer's caller (`display-loop`, main.gc:513), its null argument, the callee and the corrected SIGBUS trap | current investigation |
| [evidence/A1/a11-goal-bridge-regfile-2026-09-22.md](evidence/A1/a11-goal-bridge-regfile-2026-09-22.md) | All four GOAL<->C++ boundaries (two C->GOAL bridges + two GOAL->C++ trampolines) now preserve x19-x28/v8-v15 (regression + overlay), and the font/draw-string SIGBUS is closed (two runs, regression + overlay) and the run now dies deterministically in rpc-h +0x8B8 | current investigation |
| [evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md](evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md) | G2.2 item 1 answered: the Sky batch store publishes and the pass consumes every strip (`empty-replace=0`), and the "the block never runs" premise was an `NSLog`-versus-`lg::info` log-channel artifact | current investigation |
| [evidence/A1/g2-live-blend-register-ledger-2026-09-22.md](evidence/A1/g2-live-blend-register-ledger-2026-09-22.md) | G2.2 item 2 ledger: over a routed run the live Sky batches carry GS ALPHA 0x44 and 199 of 200 TIE draws request preset 1 - no live site asks for the additive equation | current investigation |
| [evidence/A1/g2-sky-additive-blend-2026-09-22.md](evidence/A1/g2-sky-additive-blend-2026-09-22.md) | G2.2 item 2 landed: the GS ALPHA decode (12/12 host regression) and the additive Sky pipeline, register-driven but gated because the village1/title sky tiles decode to garbage colour data | current investigation |
| [evidence/A1/g2-sky-draw-source-2026-09-22.md](evidence/A1/g2-sky-draw-source-2026-09-22.md) | G2.2 root cause: bucket 3 is upstream's `SKY_DRAW` and samples the SkyBlend-composited texture this lane lacks, so the raw draw is skipped by default; the register-driven additive selection is now unconditional | current investigation |
| [evidence/A1/g2-merc-eyes-bucket54-decode-2026-09-22.md](evidence/A1/g2-merc-eyes-bucket54-decode-2026-09-22.md) | G2.2 item 3 stage 1: bucket 54's eye chain decodes (validated ADGIF layout, oracle mapping) and composes 128x128 RGBA per slot; nothing is bound yet, so the visible eyes are unchanged | current investigation |
| [evidence/A1/g2-merc-eyes-bind-2026-09-23.md](evidence/A1/g2-merc-eyes-bind-2026-09-23.md) | G2.2 item 3 stage 2: the composed eye slots are bound into the MERC eye draws (the level page it replaces is a 4x4 flat blue-grey); Jak's eye now shows iris, pupil and lid, with the iris page's rim texels still open | current investigation |
| [evidence/A1/g2-hud-material-decode-2026-09-23.md](evidence/A1/g2-hud-material-decode-2026-09-23.md) | G2.2 HUD/menu material: the HUD decodes, submits and is encoded, yet nothing paints - a gated overlay-depth control makes live sprite geometry paint (thin World2D strips), so the GEQUAL depth test is rejecting sprites; the HUD fixture result is unresolved | current investigation |

Also see repo brief copy at [`jak1-researchloop.md`](jak1-researchloop.md).
