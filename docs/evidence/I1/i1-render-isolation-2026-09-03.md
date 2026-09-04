# I1 render isolation — 2026-09-03

Status: OPEN; diagnostic only, not playability evidence.

Question: does disabling one native scene family remove the malformed geometry?

Method: one existing signed build, one iPad Pro Simulator, no source change. The
`ottsel-trace-metal-scene-no-tie` trigger was consumed during a Village1 frame.
Fresh frame: `/tmp/ottsel-no-tie.png`.

Observation: with TIE disabled, the frame still contains large distorted Village1
environment geometry, black regions, and debug/control overlays. Therefore TIE is
not the sole source of the malformed scene; TFRAG or shared camera/vertex handling
remains implicated. Jak is not visible or controllable.

The subsequent no-MERC attempt relaunched into title/debug state before a matching
Village1 frame was obtained. It is inconclusive and must not be used to attribute
the defect to or away from Merc.

Next experiment: reproduce both probes after New Game reaches Village1, retain the
same-state frames/log markers, and compare TFRAG-only, TIE-only, and Merc-only
families before changing code. Keep camera math, TBP/lookup, and strip-restart
code unchanged.
