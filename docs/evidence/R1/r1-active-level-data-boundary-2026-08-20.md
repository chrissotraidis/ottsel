# R1 active-level capture — data boundary remains open — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity / active Village1 producer comparison |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `f224fcacc6615e588f9e178e5e776ccef4cd058df222f1d1943a245b9f640a99` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; app PID `25940`; Simulator shut down after capture |
| Before failure | The prior `0x2bc1` phase sample was recorded while `slot1=loading`, so it was not accepted as an active Village1 comparison. |
| Change | No source change. Relaunched the signed app, waited for F1 import, and issued the existing `ottsel-bg-village1` file trigger from the authoritative writable root. |
| Focused proof | F1 imported the validated pack into Application Support. Its `DGO/` contained `VI1.DGO`, but the route requested lowercase `village1.DGO`; the runtime logged `file village1.DGO not found`. The retry then requested `beach.DGO`, also absent. |
| Live proof | The runtime remained at `slot0=loading slot1=loading`, with no `Displaying level village1 [display-self]` and no valid active-level Sprite3 interval. The Simulator surface remained blank. |
| Fault scan | No new crash or Metal validation proof was produced. This run is invalid for renderer parity because the level never became active. |
| Verdict | OPEN — the current iPad route is blocked at the validated-pack/runtime DGO-name boundary before active producer comparison. This is not a renderer verdict and not a playability pass. |
| Next gate | Reconcile the user-pack DGO naming contract against the runtime request using the maintained data-root mechanism, then repeat the same active-level capture. Do not remap Sprite3 textures or alter camera/shader behavior until that comparison is valid. |

The capture also confirms the platform split: macOS can reach a visually plausible native scene, while iPadOS currently fails earlier in data import/level activation and therefore cannot yet be compared on the same producer phase. Audio remains partly wired on macOS but lacks human-audible acceptance; the iPad Simulator was blank and non-audible here.
