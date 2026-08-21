# R1 particle AdGif output mapping — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/resource parity before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; GOAL patch `r1-particle-adgif-goal-source.patch`; MIPS2C patch `r1-particle-adgif-mips2c-output.patch`; signed executable SHA-256 `05e1554bef9824d40a09e2e9a41dba56d76f40d6b45c785a959d7f425c677033` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh validated external pack; normal Metal; container `87E0C592-90F0-4B35-8236-662D4DAE4A6F` |
| Before failure | Mobile’s first 3D `TBP=0x2b8d` was known, and particle IDs were known, but no producer-to-AdGif/TEX0 mapping proved whether the native consumer changed the resource. |
| Change | Added a bounded cache-copy trace that records packed texture ID, cache address, and resulting TEX0/TEX1/CLAMP/ALPHA words. It observes the existing cache copy only; it does not remap or alter data. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep codesign passed. `r1-particle-adgif-mips2c-output.patch` reverse-applied cleanly; source `git diff --check` passed. |
| Live proof | Current-boot route entered Village1 twice. The trigger completed after 32 samples with zero faults. Representative repeated pairs included: `raw=0x00200a00` (page `0x2`, index `0xa`) → `tex0=0x2005aa459930ab8d`, `tex1=0x120`, `clamp=0x1010001c0`, `alpha=0x44`; `raw=0x00201800` (index `0x18`) → `tex0=0x20059dc59930ad8c`; `raw=0x00201900` (index `0x19`) → `tex0=0x20059e459930ad7c`. The same-route native frame at VSYNC `2696` / chain `2695` began `MSCAL=211`, 48 sprites, `TBP=0x2b8d`, and first TEX0 `0x2005aa459930ab8d`; its aggregate contained `3d=64`, `world=512`. |
| Visual/fault result | The Simulator remained visibly corrupted/partially composed, not playable. `ottsel-fault.log` was 0 bytes. |
| Verdict | OPEN — the mobile native consumer is not inventing the `0x2b8d` resource: the selected producer ID maps to the exact first 3D TEX0. The remaining mismatch is upstream resource/phase selection against macOS’s first 3D ID/TEX0, not a TBP remap or shader/camera defect. |
| Next gate | Run the same trigger on the macOS reference at the corresponding Village1 transition and compare producer ID → AdGif TEX0 pairs. Then select the first shared source/data-family divergence. |

