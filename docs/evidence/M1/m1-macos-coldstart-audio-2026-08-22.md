# M1 macOS cold-start/audio replay — 2026-08-22

## Verdict

**PARTIAL PASS.** This is a fresh cold-start and output-stream liveness
increment. It is not a macOS playability or stable-reference pass.

## Ledger

| Field | Result |
|---|---|
| Gate | M1 macOS stable reference |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; `gk` SHA-256 `53d23368d1871887bc6c3838ae02b35a0f86e15ac35a18c2d5e2349313cc33d7` |
| Environment | macOS 26.5.2, Apple M1 arm64, one Windowed `gk`, no booted Simulator |
| Before failure | The current M1 gate still lacked another fresh cold-start/audio artifact and a live input route in this replay. |
| Change | No product source change; one fresh run from the current checkout with `./build/h1/game/gk -v --game jak1 -- -boot -fakeiso`. |
| Focused proof | Existing native keyboard/mouse focused suite remains 23/23; no new source change was made in this replay. |
| Live proof | Runtime reached `OTTSEL TITLE: title-play received wait`, `OTTSEL ROUTE STATE: title-wait-ready`, and page-2 lookup hits. Audio opened SDL output-only device 37, observed its callback after 2048 frames, and recorded PCM peaks including 2547, 1045, 170, and 40. |
| Raw artifact | `out/jak-project/log/jak1.2026-08-22T05-47-49.log`, SHA-256 `f557b798663f13748e7cd06da48cbfc11e4412d9e5b3f931a47b09a97e91dd79`. |
| Fault scan | No `OTTSEL CRASH`, signal, Metal command-buffer, or runtime fault marker was found in the retained runtime log. |
| Input boundary | No live keyboard/mouse edge was delivered during this particular replay; prior keyboard proof and the native mouse implementation remain separately bounded. |
| Verdict | **PARTIAL PASS**: cold-start/title-wait/audio callback/log liveness only. |
| Next gate | Complete macOS live input, neutral background/resume, human-audible acceptance, and controller-led soak before resuming paused iPad R1 work. |

The Simulator GUI was closed and the iPad device was shut down before this
runtime started. The runtime was stopped cleanly after the bounded capture.
The iPad Simulator remains explicitly blank/partial/non-playable in prior
evidence; no mobile claim follows from this macOS run.
