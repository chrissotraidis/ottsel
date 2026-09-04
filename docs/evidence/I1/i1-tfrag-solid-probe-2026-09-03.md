# I1 TFRAG solid-material probe — 2026-09-03

Status: OPEN. The probe was active, but it did not produce a coherent TFRAG
world or a recognizable solid-color replacement.

Question: is source texture alpha alone hiding otherwise valid TFRAG geometry?

Build under test: signed `out/jak-project/out/ios/app/OttselShell.app` with
the one-shot `ottsel-trace-metal-scene-tfrag-solid` trigger; focused
PlatformInput suite passed 27/27 before the run.

Fresh frame: `/tmp/ottsel-video/bot36-tfrag-solid-2026-09-03.png`.
SHA-256: `f471fd9179c425ee41260409f9cb443a541c6d3c0c7592d3d73c2579cb5c2fa6`.

Simulator system log confirms `scene TFRAG solid probe enabled`. The frame
still contains only sparse/debug rectangles, with no coherent world and no
solid-color TFRAG field. The same log also reports TFRAG texture indices
395–399 while the Metal table contains 395 entries; those draws are skipped
as out-of-range.

Conclusion: source alpha is not sufficient evidence for visibility. This
probe is not a renderer fix and does not justify changing camera, TBP/lookup,
or strip handling. The texture-index contract and per-draw depth semantics
remain OPEN for the next falsifiable investigation.
