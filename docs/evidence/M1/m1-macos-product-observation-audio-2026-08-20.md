# M1 macOS product observation and audio check — 2026-08-20

| Field | Result |
|---|---|
| Scope | macOS reference health, stability, and audio status; not a mobile gate pass |
| User observation | The current macOS version looks decent in the running title/world scene, while stability remains uncertain. This is recorded as a product observation, not substituted for a soak result. |
| Environment | Native arm64 `gk`, upstream `641fb572e`, Jak 1 `-boot -fakeiso`, one Windowed runtime, no Simulator concurrent, audio enabled, selector `MacBook Air Speakers` |
| Fresh run | `out/jak-project/log/jak1.2026-08-20T12-00-25.log`; ran roughly 1:02, reached title and repeated `Displaying level village1 [display-self]` lines, then was stopped intentionally. No `OTTSEL CRASH`, signal, exception, or fault marker was found in the retained log. This is not the five-minute soak. |
| Audio evidence | SDL enumerated `Jump Desktop Audio` and `MacBook Air Speakers`, selected `MacBook Air Speakers`, started output-only device 37, and observed the callback after 1,024 frames. The real `ndi-intro` VAG path logged `nosound=false selected=real` and a mixed window with `pcm-peak=2621`; a later title stream used the fake fallback and logged `pcm-peak=190`. |
| Audio verdict | OPEN. The stream/device/PCM path is live, but no human-audible acceptance, route/interruption behavior, or physical-speaker verification was performed. |
| Platform split | macOS has a broad OpenGL renderer and a bounded retail title-to-Village1 path; its remaining uncertainty is stability, controller coverage, and audible/route acceptance. iPadOS/iOS still lacks full native Metal bucket composition and clean title/New Game progression, and separately has touch/lifecycle, mobile audio, iPhone parity, signing/device, and Simulator-host boundaries. A Mac visual or audio milestone cannot close those mobile gates. |
| Next gate | Continue R1 on iPad: make the real New Game/Cross route observable and clean, then match one identified Sprite3 texture/state tuple to the macOS trace before widening native batching. |

No release, playability, audible, iPhone, or physical-device claim is made by this note.
