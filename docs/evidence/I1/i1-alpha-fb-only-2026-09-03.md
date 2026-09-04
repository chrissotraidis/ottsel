# I1 alpha FB_ONLY policy — 2026-09-03

Status: OPEN. The alpha policy correction is covered, but did not restore a
coherent Jak 1 scene or establish playability.

Question: does upstream-equivalent GEQUAL/FB_ONLY handling remove the malformed
transparent geometry without suppressing the depth-tested path?

Before-failing regression: `MobileAlphaFailFbOnlyWithoutDepthWriteAcceptsFromZero`
did not compile before `ottsel_mobile_alpha_min` existed. After the helper was
added, `goalc-test --gtest_filter='PlatformInput.*'` passed 26/26.

Change: alpha minimum is zero for GEQUAL + FB_ONLY when depth writes are off;
the depth-writing case retains the reference-derived threshold. No camera,
TBP/lookup, or strip-restart code changed.

Build: signed `out/jak-project/out/ios/app/OttselShell.app` completed.

Fresh route/frame: bounded title → New Game route with `scene-no-merc` and
`scene-no-tie`; `/tmp/ottsel-video/bot36-alpha-fb-only-2026-09-03.png`.
SHA-256: `89048436e4995bd63f6403962cef1921d4a8173a55a3fe59db20b6b71eaac089`.

Observed: frame remains black/sparse with debug rectangles and scattered
geometry; Jak is not visible or controllable. Alpha handling is not the sole
cause of the rendering failure.

Runtime: stable snapshots reported TFRAG 76,264 vertices/62,504 triangles and
TIE 511,138 vertices/359,812 triangles; VU1STAT chain 810; PCM peak 7146;
fault log 0 bytes. Post-install container size was 1,601,200 KiB, but a valid
same-container before/after delta was unavailable because reinstall replaced
the app container.

Next: proceed to the audit-required pacing experiment, first adding a focused
regression for diagnostic-gated dumps/VU copies and bucket-table selection.
