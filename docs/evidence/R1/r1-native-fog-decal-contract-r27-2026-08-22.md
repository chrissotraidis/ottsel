# R1 corrected native fog/decal contract rerun R27 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native material composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; corrected signed executable `9e23548fd77b136cad9f81a06a257991c1391ae8de6fa9f403c5df76104a765a` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `89546` |
| Before failure | R26 was contaminated by a duplicated alpha/RGB multiplier in the newly combined shader expression and is explicitly superseded. |
| Change | Removed the duplicate multiplier. The native shader now applies exactly one source-equivalent RGB `*2` and alpha `*4`, plus per-draw fog/decal flags. |
| Focused proof | `scripts/build-ios.sh` completed and strict bundle signing passed. |
| Live proof | Fresh pack import reached `title-wait-ready`; the exact Start → Cross → Down×4 → Cross route reached Village1 twice, consumed the no-CPU trigger, and produced `artifacts-2026-08-22-ipad-live-visual/ipad-fog-decal-corrected-0910.jpeg`. |
| Video/fault/audio | A fresh video attempt returned host `Resource busy` / `Host recording is already in progress`. Fault log was 0 bytes. Mobile audio remains unproven. |
| Verdict | OPEN / NO PLAYABILITY IMPROVEMENT — the corrected frame is still a close ground view with detached/missing composition. The per-draw fog/decal change is retained as source-aligned code, but no visual parity or playable proof passed. |
| Next gate | Implement source alpha-fail/depth-write behavior and enabled blend modes, then Direct/Sprite/sky/effect composition. |

## Visual boundary

The corrected frame was actively captured and inspected. It remains visibly
partial and non-playable. The prior R26 frame/video are not evidence because
of the duplicate scaling bug; this R27 frame is the authoritative rerun.
