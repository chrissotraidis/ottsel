# I1 scene-no-TIE isolation — 2026-09-03

## Question

Does disabling native TIE submission remove the malformed Village1 composition?

## Method

Current signed `out/jak-project/out/ios/app/OttselShell.app`, one booted iPad
Pro 11-inch (M4) Simulator, fresh launch, exact trigger
`ottsel-trace-metal-scene-no-tie`, then the retained title-wait → Start →
Cross → Down×4 → Cross route. The Simulator was terminated after capture.

## Result: OPEN

The frame remains visibly non-playable: geometry is oversized and rotated in
the encoded landscape capture, with large black regions and debug controls;
Jak is not visibly controllable. TIE was disabled by the consumed trigger,
yet the malformed composition remained. The fresh frame is
`/tmp/ottsel-video/bot36-tfrag-no-tie-2026-09-03.png` with SHA-256
`affce995b1a0af9983e897f4eeb21b715fbe90936e0e249c565c5759d3c58742`.

Runtime checks: the route stayed alive, the fault log was 0 bytes, and
`pcm-peak` reached 15,698. VU1STAT remained active, reaching
`chain=1800`, `vu1-runs=8709`, `capped=0`; container growth was approximately
3.28 GB for the run, so the audit's <1 MB growth criterion remains OPEN.

This narrows attribution: TIE is not the sole source of the composition
failure. Do not change camera math, TBP/lookup, or strip-restart from this
result; the next source-level change still requires a before-failing test.

## Follow-up: scene-no-MERC

The same route with the exact `ottsel-trace-metal-scene-no-merc` trigger was
also consumed (`scene no-MERC probe enabled`). Its fresh frame remained the
same oversized/rotated, black-gapped composition, SHA-256
`258c73be34e33a2ed30e82e33afcc28b5ffc4b43279ca7cccc369b7758773172`, while
the TFRAG/TIE scene still occupied the frame. This further narrows the defect:
neither TIE nor Merc alone explains it; TFRAG/composition/depth ownership
remains OPEN for the next falsifiable experiment.
## Combined TFRAG-only follow-up

Both exact triggers were armed in one fresh launch. The resulting frame still
contains the oversized, black-gapped composition while both TIE and Merc draw
submission are disabled; SHA-256
`ec94028d55b89e5cf5a9d6c9c7b68d41734f3975488c8e2b56156b7d0df04f5a`.
This makes TFRAG/composition the remaining live family in this isolation,
but it is not yet a root cause: the frame is still non-playable and no source
change was made. Keep the next change regression-first and preserve the
camera/TBP/strip-restart constraints.
## Rejected fixed-point experiment

The upstream OBJ exporter divides `pre_cam_trans_pos` by `65536`, but that is
an export-only unit conversion. `TfragTree::unpack()` reconstructs native
renderer coordinates in the same fixed world-unit domain as `cam_trans`.
Applying `/65536` only to TFRAG vertices made the scene disappear in the
signed build (`/tmp/ottsel-video/bot36-tfrag-fixed-point-only-2026-09-03.png`,
SHA-256 `d46691a38ce80e899d2f676fc4cd4ba4e0c2a17c4a868b298bedfcd75df52881`).
The helper, regression, and conversion were reverted; the hypothesis is
rejected and the source remains at the queue-liveness checkpoint.
