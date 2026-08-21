# R1 Sprite3 frame-boundary measurement caveat — 2026-08-20

The repeated bucket-66 summaries are valid per-call observations, but they
must not be compared numerically to the macOS frame ledger without a shared
frame boundary.

| Measurement | Evidence |
|---|---|
| Mobile | Five populated summaries at chains `18143`, `21003`, `21816`, `22794`, and `23062`, separated by seconds, each reporting 7 world groups / 320 sprites and 64 3D sprites. |
| macOS | `Sprite3::render_jak1` frame 1 reports one complete dispatch: 51 world blocks / 2,432 sprites and 3 HUD blocks / 128 sprites. |
| Consequence | The mobile summaries are not proven to represent one complete renderer frame. The stable 7-group fragment may be one DMA call within a larger frame, so the earlier numerical “320 versus 2,432” comparison is a producer/partition hypothesis, not a final mismatch proof. |

## Decision

Keep the phase classifier and per-call evidence. Do not widen the native
consumer or alter bucket boundaries based on the raw count comparison. The
next falsifiable slice is a shared frame-boundary ledger: correlate mobile
`gfx_send_chain` calls to one display/render frame, sum bucket-66 phases within
that window, and compare that aggregate to one macOS Sprite3 dispatch frame.

The Simulator was blank and non-audible; no visual, audio, playability,
iPhone, or physical-device claim is made.
