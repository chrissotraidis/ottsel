# R1 trigger-gated particle AdGif / Village1 correlation — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/resource parity before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; GOAL source patch `r1-particle-adgif-goal-source.patch`; trigger-gated MIPS2C patch `r1-particle-adgif-mips2c-output.patch`; latest signed executable SHA-256 `f877d07d684c74cf6cd67cba722f7c0d5e56ae439992c9ec73c5a9e6f910ace9` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh imported validated pack; normal Metal; container `29ED21EA-EDF8-41A0-ABA2-DAE317138A20` |
| Before failure | The initial AdGif trace cap ended before the first current-boot Village1 `MSCAL=211` frame, so nearby source IDs could not be assigned to the retained 3D phase. |
| Change | Replaced the first-call-only MIPS2C trace with a bounded trigger at `/tmp/ottsel-trace-particle-adgif`. It arms on demand, records 32 packed texture IDs with decoded page/index, and now reads the resulting AdGif TEX0/TEX1/CLAMP/ALPHA words after `particle-setup-adgif` returns. No renderer or texture mapping changed. |
| Focused proof | The external pack was prepared and validated successfully. `scripts/build-ios.sh` completed; strict deep codesign passed. |
| Live proof | Current-boot route consumed Start, Cross, Down×4, and final Cross; `GAMEPLAY: enter village1` appeared twice. After arming the trigger in the active Village1 phase, the next producer calls logged IDs `0x00200a00` (page `0x2`, index `0xa`), `0x00201900` (index `0x19`), and `0x00201800` (index `0x18`), with 32 calls completing and no fault. The nearby frame aggregate at VSYNC `3323` / chain `3322` contained 64 3D sprites: `MSCAL=211`, 48 sprites at `TBP=0x2b8d`, then a 16-sprite tail at `0x2be0`, followed by world groups at `0x2c8d`/`0x2d8c`. |
| Visual/fault result | Screenshot [partial artifact](/Users/chrissotraidis/GitHub/ottsel/docs/evidence/R1/r1-particle-adgif-partial-artifact-2026-08-21.png) shows textured geometry and controls but severe composition corruption/missing regions. It is not playable evidence. `ottsel-fault.log` was 0 bytes. |
| Verdict | OPEN — the source IDs are now captured during the same active Village1 phase as the 3D producer, but the exact ID-to-AdGif/TBP mapping is not yet one-to-one because the MIPS2C calls and native frame aggregate are adjacent, not stamped with the same chain. |
| Next gate | Run the rebuilt trigger-gated probe and compare each selected ID/output word pair to the same-chain `MSCAL=211` record. Do not remap TBPs or change camera/shader policy. |
