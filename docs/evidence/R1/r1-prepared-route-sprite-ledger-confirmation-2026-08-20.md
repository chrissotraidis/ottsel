# R1 prepared-pack route Sprite3 ledger confirmation — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity; prepared user-data route |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one signed normal-Metal runtime; Simulator blank and non-audible |
| Data boundary | `/tmp/ottsel-user-pack-real.HGuXcA`; manifest/family/space validation passed; staged into `Documents/OttselUserData`; `SIMCTL_CHILD_OTTSEL_PREPARE_DATA_BEFORE_METAL=1` |
| Route proof | Runtime logged validated-pack import, `GAMEPLAY: enter title`, `title-play received wait`, Village1 FR3 load (`36,673,019` bytes), and `Displaying level village1 [display-self]` |
| Sprite proof | Triggered after the Village1/display-self phase from the app writable root. Bucket 66 ledger armed at chain `14596` and completed `64` records. The captured records used `TBP=0x2c8d`, PSM 19, `32x32`, `TEX0=0x2005a0455530ac8d`, `TEX1=0x120`, `CLAMP=0x1010001c0`, `ALPHA=0x48`. |
| Fault scan | `ottsel-fault.log` was `0` bytes. |
| Interpretation | This confirms the earlier mobile ledger on the correctly prepared route. It does not establish visual parity or playability. The mobile resource phase still differs from the same-route macOS Sprite3 oracle (`TBP=0x24f2`, `64x64`), while camera rows and compatible state fields remain non-discriminating. |
| Next gate | Add a bounded producer-side bucket/group ownership comparison for the identified mobile and macOS phases, then make the smallest test-first adaptation only if ownership/phase attribution identifies a concrete defect. |

No MAP_JIT, runtime executable page, dynamic trampoline, external Metal shell, or protected game data was imported. The Simulator remained blank and non-audible; no screenshot, audio, visual-parity, or mobile-playability claim is made.
