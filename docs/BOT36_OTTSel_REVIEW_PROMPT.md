# Ottsel review prompt

You are reviewing the Ottsel native Jak 1 iPadOS/iOS work in `/Users/chrissotraidis/GitHub/ottsel`. Read `docs/reports/2026-09-03-ipad-village1-render-audit.md`, `AGENTS.md`, and `docs/BOT36_PROMPT.md` before investigating. Run the required disk/temp-pack check first.

The current build launches and loads Village1, but the rendered scene is unusable: Jak is not visibly rendered, depth ordering is suspect, large diagonal bands and black regions dominate the frame, controls/gameplay are not proven, and audio was previously silent. Recent work changed Metal depth to clear 0/GreaterEqual, retained the Merc raw-perspective fix, added level-ownership diagnostics, compiled Jak1 `srpc.cpp` into iOS and routed PLAYER RPC audio, and gated CPU VU/dump diagnostics. These are not accepted as fixes yet; fresh runtime evidence remains malformed.

Audit the source, diffs, logs, and retained evidence. Look specifically for mistakes in this approach, missing render paths/resources, incorrect TIE/TFRAG ownership or draw submission, shader/vertex/index mismatches, audio RPC assumptions, and pacing regressions. Do not modify camera matrix math, TBP/lookup, or strip-restart code; do not start touch or iPhone work. Reproduce only as needed with one runtime and one booted iPad Simulator, and keep the macOS-first/product evidence rules.

Write your findings and concrete next experiments to a new concise document under `docs/` (include file/line evidence, confidence, and what would falsify each finding). Do not claim playability. End the document with a short “continue” prompt for the primary agent: one smallest falsifiable next change, the regression to add first, and the evidence to capture. Then report the document path and wait for the primary agent to continue.
