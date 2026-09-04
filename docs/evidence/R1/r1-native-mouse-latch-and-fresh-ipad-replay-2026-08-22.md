# R1 native mouse latch and fresh signed iPad replay — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Environment | Exactly one booted Simulator: iPad Pro 11-inch (M4), `08636791-2675-4675-8335-EF72EF954DCF`; only `com.ottsel.shell` active on it; no host `gk` runtime. |
| Build | Signed iPad build from the dirty user-owned checkout; executable SHA-256 `aed5a6cca79e9b2cd9701824cf1b0959cd5cf3b1d49849aab3c23b74c2bf4102`. |
| Route | Fresh title-wait-ready → Start → Cross → Down×4 → Cross; logs contain keyboard edges and `GAMEPLAY: enter village1` at lines 44607 and 44666. |
| Input change | WASD now uses physical SDL scancodes; mouse left/right map to Cross/Circle; relative mouse motion is retained across the event-loop/`scePadRead` seam by `MouseMotionLatch`. |
| Regression | Focused `Sprite3Native.*:PlatformInput.*:KeyboardEventEdge.*` suite passed 24/24, including `MouseMotionSurvivesEventLoopUntilPadRead`; canonical patch reverse-check passes. |
| Fault/audio | Fault log 0 bytes; fresh route remains non-audible (`pcm-peak=0`). |
| Visual result | Fresh screenshot is still severely corrupted/partial: oversized/dislocated geometry and incomplete composition. It is explicitly not playability proof. |

## Evidence

- Screenshot: `artifacts-2026-08-22-ipad-mouse-latch-replay/post-route.png`
  - SHA-256 `08072ffb330bca420a9ae81cefb873d938bac7d894eb1d8121ac8ff826424839`
- Runtime log: `artifacts-2026-08-22-ipad-mouse-latch-replay/ottsel-runtime.log`
- Fault log: `artifacts-2026-08-22-ipad-mouse-latch-replay/ottsel-fault.log`
- Reproducible source patch: `patches/r1-native-mouse-controls.patch`

## Boundary

This proves the signed build consumes the scripted native keyboard route and
that the mouse-motion lifetime bug has a focused regression. It does not prove
human mouse acceptance, coherent iPad rendering, audible playback, lifecycle
recovery, iPhone parity, or physical-device readiness. Those gates remain open.
