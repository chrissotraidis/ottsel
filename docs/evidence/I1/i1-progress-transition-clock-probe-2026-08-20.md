# I1 — progress transition clock probe (2026-08-20)

| Field | Result |
|---|---|
| Gate | I1 input/lifecycle; first open dependency on the accepted route |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; canonical patch `patches/h3-jak1-host-boot.patch`; signed app SHA-256 `bc10f91b8e97b684d491313c31d1a57ac994af86443e07ec490770deb9ff128f` |
| Environment | iPad Pro 11-inch (M4) Simulator UDID `08636791-2675-4675-8335-EF72EF954DCF`; Simulator shut down after the diagnostic attempt |
| Before failure | The validated-pack title route appeared to stall after the first Cross, but the route had not yet accepted the save-slot step. The missing discriminator was whether the transition clock or the next save-title input was responsible. |
| Change | Added a bounded diagnostic-only probe in `out/jak-project/goal_src/jak1/pc/progress-pc.gc` and the canonical maintained patch. It recorded display/next state, transition offset, frame counter, autosave handle, and threshold entry; the probe was retired after the run. No state-machine behavior changed. |
| Focused proof | The GOAL rebuild passed all 338 targets after correcting an initial probe-only parameter-count error; the focused platform/renderer/compiler slice passed 18/18; the fresh signed app passed strict codesign verification. |
| Live proof | One fresh validated-pack SDL-only runtime consumed Start, Cross to `save-game-title`, then a second Cross for the save slot. The transition advanced by `0x2d` per tick, entered state `0x12`, then state `0xd`; the log reached `GAMEPLAY: enter village1` twice. `autosave=#f` throughout the sampled transitions. |
| Fault scan | `ottsel-fault.log` was 0 bytes. The Simulator remained blank and non-audible; no screenshot, audio, or playability claim is made. |
| Verdict | PASS for the SDL-only title -> save-title -> Village1 route discriminator; OPEN for I1 product acceptance and P2. The apparent clock stall was an input-sequence misunderstanding, not a zero clock or autosave blocker. |
| Next gate | R1: repeat the corrected title -> save-title -> Village1 route with normal Metal and capture the same-phase native bucket/image evidence; then continue T1 visible touch and AU1 audible/device work. |

The probe deliberately did not import the external Jak 2 renderer, AOT, MAP_JIT,
runtime executable-page, or Metal-shell work, and was removed after capture. The
Simulator's blank/non-audible state remains an explicit limitation of this
evidence.
