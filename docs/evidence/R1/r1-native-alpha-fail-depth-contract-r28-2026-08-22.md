# R1 native alpha-fail/depth-write contract experiment R28 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native material/depth composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed executable `c90ac542db555c2cc80b5544fb784232e5d1d33ee0c2b4706283fdea304d8f7a` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `92785` |
| Before failure | Live TFRAG mode ledger showed `0xf93e7e5d` and `0xf9bc005d` families with `FB_ONLY` alpha-fail semantics; Metal used one alpha-discard pass and retained depth-write state. |
| Change | Native material now carries `alpha_max`; `FB_ONLY` + GEQUAL + depth-write draws a second no-depth-write pass for failing alpha, and `NEVER + FB_ONLY` disables depth writes as OpenGL does. |
| Focused proof | `scripts/build-ios.sh` completed and strict bundle signing passed. The live TFRAG ledger confirmed the targeted modes during the exact route. |
| Live proof | Fresh validated pack reached `title-wait-ready`, accepted Start → Cross → Down×4 → Cross, reached Village1 twice, and consumed the no-CPU trigger. Fresh frame: `artifacts-2026-08-22-ipad-live-visual/ipad-alpha-fail-depth-no-cpu-2305.jpeg`. |
| Video/fault/audio | Fresh recording attempt was blocked by host `Resource busy` / `Host recording is already in progress`. Fault log was 0 bytes. Mobile audio remains unproven. |
| Verdict | OPEN / NO VISUAL IMPROVEMENT — the source contract is now closer to OpenGL, but the fresh frame remains the same close, detached/missing composition and is not playable proof. |
| Next gate | Implement the enabled TFRAG blend-factor modes or move to the first missing Direct/Sprite/sky/effect bucket, with fresh visual attribution. |

## Source basis

The maintained OpenGL renderer uses a first alpha-tested depth-writing draw
and, for `FB_ONLY`, a second draw with depth writes disabled and the inverse
alpha range. R28 reproduces that bounded behavior in the native Metal draw
loop. No TBP, lookup, camera, or global Metal policy was changed.

## Visual boundary

The screenshot was actively captured and inspected. It remains explicitly
partial/non-playable: close framing, detached upper surfaces, missing scene
composition, no player/HUD proof, and unaccepted audio. Build, counters,
route markers, and zero faults do not close playability.
