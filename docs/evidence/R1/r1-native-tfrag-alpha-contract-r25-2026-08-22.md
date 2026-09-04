# R1 native TFRAG/TIE alpha-contract experiment R25 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native material composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed executable `80bbb978b098f9e087a6018ec68daf6b18aab781ab73c5d8b5f0f27527d70c74` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `85220` |
| Before failure | OpenGL `tfrag3.vert` doubles the time-of-day color and doubles alpha a second time. Native `tie_fs` multiplied both channels only once, while native TOD uploads cap alpha at 128; source alpha-tested DrawMode families could therefore discard valid fragments. |
| Change | `src/shell/metal_shell.mm`: native TIE/TFRAG material now applies RGB `*2` and alpha `*4`, matching the maintained OpenGL shader. Projection, texture identity, TBP, lookup, geometry-slot traversal, and blend policy were unchanged. |
| Focused proof | `scripts/build-ios.sh` completed and strict bundle signing passed. |
| Live proof | Fresh validated-pack boot reached `title-wait-ready`, accepted the route's Start/Cross/Down×4/Cross sequence, reached Village1 markers, armed the no-CPU-frame diagnostic, and produced fresh frame `artifacts-2026-08-22-ipad-live-visual/ipad-alpha-contract-no-cpu-1154.jpeg`. |
| Fault/audio | `ottsel-fault.log` was 0 bytes. Mobile audio remains unaccepted/unproven. |
| Video | Fresh `simctl io recordVideo` attempt again returned host `Resource busy` / `Host recording is already in progress`; prior bounded video remains preserved. |
| Verdict | OPEN / PARTIAL SIGNAL — the fresh frame shows substantially more visible terrain/material detail than the prior no-CPU baseline, consistent with the corrected alpha-test path, but it remains an incorrect close-up with missing/detached scene composition and is not playable proof. |
| Next gate | Complete the remaining native material contract: per-draw alpha/blend/decal behavior and Direct/Sprite/sky/effect composition, with the current alpha correction retained for the next comparison. |

## Source basis

The maintained OpenGL shader performs:

```text
fragment_color *= 2
fragment_color.a *= 2
```

The native color upload caps the time-of-day alpha channel at 128, so the
native shader must reproduce the second alpha scale to reach the same
alpha-test domain. This is a source-defined material correction, not a TBP,
camera, shader-policy, or resource remap.

## Visual boundary

The fresh Simulator frame was actively captured and inspected. It is more
material-bearing than the R24 no-CPU frame, but the camera is still a close
ground view with detached upper geometry and no complete playable Village
scene. Keep the blank/partial Simulator warning explicit.
