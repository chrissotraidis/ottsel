# R1 particle AdGif producer trace — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/resource parity before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; `patches/r1-particle-adgif-producer.patch`; signed executable SHA-256 `051f8f26bbca37be52b372438e6b24de6da0f3a2be60aec292bd1185649fee16` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; normal Metal; fresh data container `DD2374A4-497B-4FE2-BDFC-1D60DFD92EA6` |
| Before failure | The mobile first `MSCAL=211` resource/state divergence was known, but the GOAL-side particle texture-id that led to the selected AdGif had not been observed. |
| Change | Added a 32-call bounded trace at `particle-setup-adgif` and the Jak 1 MIPS2C `particle-adgif` boundary. The MIPS2C trace logs the packed `texture-id` and decodes its page/index; no texture remap, renderer, or game behavior changed. |
| Focused proof | `goalc --isa arm64 ... make GAME.CGO` rebuilt all 338 targets. `scripts/build-ios.sh` completed and strict deep codesign passed. The maintained patch reverse-apply check and `git diff --check` passed. |
| Live proof | The fresh normal-Metal title boot logged `raw=0x00203500 page=0x2 index=0x35` and `raw=0x00200400 page=0x2 index=0x4`; the GOAL lookup trace reported `lookup="hit"`. The fault log was 0 bytes. |
| Limitation | This replay did not reach the intended Village1 marker because the fresh bundle had no imported validated user-data pack/FR3 root. The Simulator stayed blank and non-audible; this is producer trace evidence, not visual or playability proof. |
| Verdict | OPEN — the exact source-side IDs are now observable, but they are not yet tied to the same-transition Village1 first-3D frame or compared with the macOS producer input. |
| Next gate | Install the validated external user-data pack into the fresh app, replay title-wait → Start → Cross → Down×4 → Cross, and capture the first current-boot `particle-adgif` IDs alongside the `MSCAL=211` state. |

