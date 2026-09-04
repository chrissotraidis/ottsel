# M1 native macOS mouse/keyboard controls — 2026-08-22

## Verdict

**OPEN, with a verified keyboard fix and an unverified mouse acceptance row.**
This is a control-path increment, not a macOS playable/stability pass and not
an iPad playability result.

## Ledger

| Field | Result |
|---|---|
| Gate | M1 / native desktop input |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; `gk` SHA-256 `53d23368d1871887bc6c3838ae02b35a0f86e15ac35a18c2d5e2349313cc33d7`; scoped patch `patches/r1-native-mouse-controls.patch` SHA-256 `438dc144639a581d7fec74ee415645e73c3a1d524cb1f1d1b25d113da68bd19f` |
| Before failure | The persisted profile had `keyboard_enabled=false`, `mouse-enabled? #f`, `mouse-camera? #f`; short mouse taps were only sampled during polling and had no event latch. |
| Change | Native keyboard is enabled by default with explicit `OTTSEL_ENABLE_KEYBOARD=0` opt-out; empty mouse maps receive left=Cross/right=Circle defaults; mouse buttons get an eight-poll edge latch; GOAL mouse defaults enable the existing camera path. |
| Focused proof | `build/h1/goalc-test --gtest_filter='KeyboardEventEdge.*:PlatformInput.*:Sprite3Native.*'` — 23/23 passed. ARM64 `(mi)` regenerated 1,068 targets before the Mac link. |
| Live keyboard proof | Fresh Windowed `gk` with no keyboard environment flag logged `native keyboard enabled`; Computer Use `Up` moved the menu selection from Load Game to New Game and produced a fresh visible menu frame. |
| Live mouse proof | The game logged `mouse options enabled=true camera=true movement=false`, but the Computer Use pointer action produced no SDL mouse event. Native System Events fallback was denied by macOS assistive-access policy (`-25211`). No human mouse acceptance is claimed. |
| Runtime/audio/fault | One Mac runtime only; fresh transcript `/tmp/ottsel-m1-mouse-trace.transcript.log`; title route reached `GAMEPLAY: enter title`; PCM peaks included `2547`; no new fault/assert/signal result was observed in the retained scan. |
| Verdict | OPEN: keyboard path verified; mouse product code changed and instrumented, but physical/native mouse acceptance still needs an allowed pointer event. |
| Next gate | Finish the remaining macOS M1 stability/lifecycle/controller evidence, then resume the paused iPad R1/native-composition queue. |

The booted Simulator remained the single iPad Pro 11-inch (M4) device, but no
iPad runtime was active during the Mac run. The Simulator's blank/partial
warning remains explicit and unchanged.
