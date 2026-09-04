# I1 — GS copy alpha-mode contract — 2026-09-03

## Question

Does the native Metal consumer incorrectly source-alpha blend GS mode
`SRC_SRC_SRC_SRC` (mode 6), which upstream treats as a copy/no-blend draw?

## Before-failing regression

`MobileSceneCopyAlphaModeDoesNotEnableBlend` was added before the production
change. It asserts that enabled mode 6 selects no blend, while mode 1 remains
blended. Rebuilt `out/jak-project/build/h1/goalc-test`; focused result: 2/2
tests passed, including the no-cull policy regression.

## Change

Added `ottsel_mobile_alpha_blend_enabled()` and used it in the Metal draw path.
Only mode 6 is corrected; camera math, TBP/lookup, strip restart, depth,
level ownership, and DMA policy were unchanged. The signed app was rebuilt by
`scripts/build-ios.sh` and installed on iPad Pro 11-inch (M4), UDID
`08636791-2675-4675-8335-EF72EF954DCF`.

## Runtime

The bounded title → New Game route reached the existing Village1 runtime. A
fresh screenshot was captured at
`/tmp/ottsel-video/bot36-alpha-copy-no-tie-no-merc-2026-09-03.png` (SHA-256
`5fc0f358e63a70d793a1078605a21e36abe367f4c98c74074343e323c9a5e6f9`). The
frame remains malformed/rotated-encoded with large black gaps. `ottsel-fault.log`
was 0 bytes and runtime audio remained nonzero.

The requested no-TIE/no-MERC trigger pair was not observed as consumed in this
launch, so this frame is not valid family-isolation evidence and cannot show
whether mode 6 improved composition.

## Verdict

OPEN. The source contract is covered and built; live visual benefit is not
proven. Next experiment should use a verified trigger-consumption marker or a
bounded draw-mode ledger before another material change.
