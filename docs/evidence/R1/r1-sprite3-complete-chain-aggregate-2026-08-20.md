# R1 Sprite3 complete-chain aggregate separation — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 complete mobile/macOS DMA phase alignment |
| Route | Fresh prepared-pack process `68670`; title marker and real Start/Cross/Down/Cross route reached `GAMEPLAY: enter village1` twice. |
| Probe | Existing bounded `ottsel-trace-mobile-direct` accounting window, armed after Village1, ran for 900 chains. |
| Bucket-67 aggregate | `34,200` transfers / `20,548,800` bytes; Sprite3 MSCAL counts: init `5,400`, world `0`, HUD `0`, 3D `0`, other `86,400`; no sprites, triangles, strips, or raster draws. First other entries included `2,4,73,46`. |
| Fault scan | `ottsel-fault.log` was `0` bytes. |
| Interpretation | Bucket 67's established Direct walk is not a Sprite3 phase oracle. The mobile Sprite3 comparison must remain on bucket 66; the earlier bucket-67-shaped transfer dump does not justify merging the consumers or changing Direct ownership. |
| Verdict | OPEN — bucket ownership is separated; bucket-66 producer/content parity remains unresolved. |
| Next gate | Add a bucket-66-only aggregate that records per-chain group counts/TBPs and DMA return transitions, then compare its complete window to the macOS Sprite3 group/HUD ledger. |

The Simulator was blank and non-audible. No visual, audio, playability,
iPhone, or physical-device claim is made. No protected data or runtime
executable-code generation was introduced.
