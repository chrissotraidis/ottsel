# R1 pre-armed iPad source parity replay — 2026-08-22

## Verdict

**SOURCE LOOKUP SUBGATE PASS; R1 COMPOSITION OPEN.** The fresh iPad replay
matches the macOS page/index and early raw particle/TEX0 family. It then
diverges at the later producer/native 3D family. This is not a playability
result.

## Ledger

| Field | Result |
|---|---|
| Gate | R1 source/resource parity |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; lookup patch SHA-256 `846ccf40bcb01cbb9f4d3da54e2314bf7c95bf40db721f3d21cbc407a479863a`; signed app executable SHA-256 `21f46d8161c36395cd2e9e562521f1df2aaa7f62c8ff5bd2b51256ea3623b4be` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, one running `com.ottsel.shell`, fresh validated durable pack, normal Metal |
| Before failure | The prior iPad lookup capture had the correct aligned prefix but did not pre-arm the raw MIPS2C particle/AdGif output trace before launch. |
| Change | No product behavior change. Rebuilt/sign-verified the app with the canonical lookup trace; pre-armed the existing diagnostic raw particle/AdGif trigger before relaunch. |
| Focused proof | `scripts/build-ios.sh` completed; `codesign --verify --deep --strict` passed; the native control suite remains 24/24. |
| Live route | Fresh title-wait → Start → Cross → Down×4 → Cross replay reached `GAMEPLAY: enter village1` twice. Route markers are in the retained runtime log. |
| Lookup/page proof | The aligned post-Start page-2 lookup prefix was `54,49,48,42,44` on iPad, matching the completed macOS phase. Directory length was `1610`; page-2 segment destinations remained `601152/632576/633664`, matching macOS. All sampled lookups were resident hits. |
| Raw particle → AdGif proof | Pre-armed raw pairs included `0x00203500 → 0x2004d0e59930a506`, `0x00200400 → 0x2004cfe55530a518`, `0x00201200 → 0x2004d0e59930a506`, and `0x00200f00 → 0x2004c8e55530a5d2`. These match the aligned macOS source families already recorded in `r1-phase-aligned-raw-parity-2026-08-21.md`. |
| Native family boundary | The same fresh iPad route first submitted `TBP=0x2506`, `TEX0=0x2004d0e59930a506` for the shared early family, then repeatedly submitted `TBP=0x24d2`, `TEX0=0x2004d2e59930a4d2`, and `TBP=0x2525`, `TEX0=0x2014cd655530a525`. The macOS world oracle is `TBP=0x24f2`, `TEX0=0x2004d1e59930a4f2`. |
| Artifacts | `artifacts-2026-08-22-ipad-r1-fresh-prearmed/ottsel-runtime.log` SHA-256 `4ddd7b452fba2f52bf11a725d126deaffb00bad1bddc282f96797f31d465878c`; `route.png` SHA-256 `58b56a851556d7cab6eff4fa7ff25a18253f7f577c58a83fcfbae48bf522be22`. |
| Fault/audio/visual | Fault log remained 0 bytes. Audio initialized and callback liveness was observed, but PCM remained `0` in the captured gameplay windows. The fresh frame is visibly partial/corrupted/blank after the route; it is not playable proof. |
| Verdict | **SOURCE LOOKUP SUBGATE PASS; R1 OPEN**. |
| Next gate | Trace the producer phase/DMA owner that changes the later texture/data family and compare the native composition consumer at the first `0x24d2/0x2525` group. Do not remap TBP or change camera, shader, or Metal policy. |

The Simulator blank/partial warning remains explicit. No macOS runtime or
second Simulator was opened during this replay.
