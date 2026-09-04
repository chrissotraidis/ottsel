# I1 TFRAG clip ledger — 2026-09-03

## Question

Does the malformed native frame come from every Village1 vertex being outside
Metal clip space, or from a later composition/visibility mismatch?

## Method

Fresh signed current-source app on the single booted iPad Pro 11-inch (M4)
Simulator, title-wait → Start → Cross → Down×4 → Cross. No source probe or
camera/TBP/strip-restart change was enabled. The app was terminated after the
fresh screenshot.

## Result: OPEN

The existing CPU clip ledger for the Village1 snapshot reports
`finite=4097/4097`, `gl-clip-visible=1876`, and
`metal-clip-visible=1876`. The native path therefore has a substantial set of
vertices inside clip space; the malformed output is not explained by a total
clip rejection. The retained frame is
`/tmp/ottsel-video/bot36-current-source-normal-2026-09-03.png`, SHA-256
`3cc755965765e9ba68aebda7a0383ac19af27db5ef4620e6f9595c3d919a9c54`.

The ledger also shows the sampled native range is broad:
`ndc-x=(-422.4563,438.0270)`, `ndc-y=(-851.0743,1606.2456)`, and
`ndc-z=(-3.9074,2.6576)`. This supports a partial visibility/composition
problem, but does not authorize changing `set_mobile_tie_camera`; the audit
and upstream comparison keep that math frozen. Playability remains OPEN.

Next experiment: use a regression-first TFRAG visibility/composition change
that can reduce the out-of-range contribution without altering camera math.
