# G2.6 packaging: the bundle audit, and a stale 18 MB container removed - 2026-09-23

G2.6's second deliverable: audit the packaged app for asset-freedom and reproducible reconstruction.

**What the bundle contains (61 MB after the fix).**  `out/jak-project/out/ios/app/OttselShell.app` holds
exactly what `scripts/build-ios.sh` copies: `OttselShell` (22.8 MB), `GAME.CGO` (22.8 MB), `KERNEL.CGO`
(0.42 MB), `Info.plist`, `_CodeSignature/`, and `iso_data/` (17 MB: `DGO/TIT.DGO`, `DGO/VI1.DGO` and the
`TEXT/*` files).

**Asset-free check.**  None of the seven user-data families (`CGO`, `fr3`, `MUS`, `SBK`, `STR`, `VAG`,
`VIS`) appears anywhere in the bundle.  The only game-derived content is the build's own diagnostic
`iso_data`, and the packaging step documents that boundary rather than assuming it: "Local Simulator
research bundle only: the DGO/TEXT resources copied below include user-derived game assets. This is not a
data-free distribution package. The release path must separate generated code from assets supplied via F1
import."

**The defect the audit found, and the fix.**  The bundle carried a stale `ENGINE.CGO` (18.5 MB, dated
Sep 11) that the build step never copies and the runtime never loads: `src/shell` has no reference to it,
and the loader serves `KERNEL.CGO` and `GAME.CGO`.  It had ridden along in every bundle since it was
written.  `scripts/build-ios.sh` now clears `*.CGO` from the app before copying its own containers, so the
bundle is exactly the step's output.  Verified by rebuilding (79 MB -> 61 MB, file list above) and by
re-running the accepted route on the iPad profile with the leaner bundle: title -> NEW GAME -> CONTINUE
WITHOUT SAVING -> Training, `scene-level='village1'` then `'training'`, **346 SIGNED MODULE ENTER = 346
RETURNED**, 0-byte `ottsel-fault.log`.

**Reconstruction.**  `patches/README.md` documents the pin and the overlay order, and
`python3 scripts/verify-overlay-coverage.py` passes: every nested delta is overlaid or a documented stray.
The README also lists, per round, the outer-repo files that no patch captures, which makes the gap explicit
rather than hidden, so the documented reconstruction is intact at this revision.  Not claimed here: a
from-scratch rebuild of the engine and the app from the pin alone has not been run, which remains the open
half of this gate.
