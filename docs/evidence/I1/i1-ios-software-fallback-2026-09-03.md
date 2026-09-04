# I1 iOS software-renderer fallback — 2026-09-03

Question: can the existing CPU/GIF renderer replace or supplement the partial
native Metal scene on iPad?

Method: launched the signed app on the single iPad Pro M4 Simulator with
`OTTSEL_DISABLE_METAL=1` and `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1`, then
captured `/tmp/ottsel-video/bot36-software-fallback-village1-2026-09-03.png`.

Result: OPEN/REJECTED as a product fallback. The captured drawable was black
apart from the Simulator chrome and no usable game scene was visible. Audio
RPCs still executed, but the CPU/GIF path did not provide a complete frame.

The environment was restored to normal Metal operation afterward. The normal
Metal app reports `cpu-diagnostic-path=disabled` and its fault log remains
zero bytes.

Decision: continue with the native Metal renderer and upstream bucket-family
parity; do not divert effort into making the existing CPU/GIF fallback the
iPad product path.
