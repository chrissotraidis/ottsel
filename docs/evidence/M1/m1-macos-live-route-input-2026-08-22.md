# M1 macOS live route/input replay — 2026-08-22

## Verdict

**PARTIAL PASS.** The current checkout accepted the complete deterministic
route and a bounded movement/neutral transition in one native Windowed runtime.
This is not the final macOS stable/playable gate: human-audible acceptance,
physical-controller acceptance, background/resume neutrality, and longer soak
remain open.

## Ledger

| Field | Result |
|---|---|
| Gate | M1 macOS stable reference / native input |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; `gk` SHA-256 `53d23368d1871887bc6c3838ae02b35a0f86e15ac35a18c2d5e2349313cc33d7` |
| Environment | macOS 26.5.2, Apple M1 arm64, one Windowed `gk`; no booted Simulator and no second runtime |
| Before failure | The previous fresh cold-start proved title/audio liveness but did not deliver a live input edge in that replay. |
| Change | No product source change. Used the existing `/tmp/ottsel-press-start` and `/tmp/ottsel-press-button` route seam plus `/tmp/ottsel-hold-left-stick`. |
| Focused proof | `./build/h1/goalc-test --gtest_filter='Sprite3Native.*:PlatformInput.*:KeyboardEventEdge.*'` — 24/24 passed; `patches/r1-native-mouse-controls.patch` reverse-check passed. |
| Live input proof | The runtime logged `OTTSEL TITLE: start edge in title-wait`; Cross `0x4000` was accepted; Down `0x40` edges were accepted at progress indices 0–3; final Cross was accepted at index 4; `GAMEPLAY: enter village1` appeared twice. A `255 127 180` left-stick hold was accepted and later logged released to neutral. |
| Fresh artifacts | `artifacts-2026-08-22-macos-route/runtime.log` SHA-256 `4c185e43b5a2db7dd19491147c1f90410dc155e715656f1f20c40c6cb1355901`; `before-move.png` SHA-256 `7957dce413ebbdc7a70566a0a3edacfd7fbf616ea6845ac64cfc82c45487c866`; `after-move.png` SHA-256 `ad44d0ade1f98d344cd702245711f34f9d66e39f6b39ae77b1b6c2201741cd8e`. |
| Audio/fault | Output-only SDL audio callback was observed and PCM peaks were nonzero during the route. The retained log scan found no crash, signal, panic, Metal command-buffer, or runtime fault marker. |
| Screenshot boundary | Fresh full-desktop captures are retained, but the game window was not isolated and the visible frames are title/intro surfaces rather than proof of coherent Village1 composition. |
| Verdict | **PARTIAL PASS** — route/input/neutral liveness only. |
| Next gate | Close M1 human-audible, lifecycle, controller, and longer-soak clauses; then resume the paused iPad R1/native-composition queue. |

No Simulator was booted for this run. The iPad Simulator blank/partial warning
therefore remains unchanged and no iPad playability claim follows.
