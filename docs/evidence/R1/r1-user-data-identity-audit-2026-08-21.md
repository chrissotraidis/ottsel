# R1 active user-data identity audit — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 — producer/resource divergence before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; same signed iPad route as the synchronized source trace |
| Before failure | Generated DGO/CGO identity already matched macOS, but the active user-data pack remained a possible source of differing VI1 visibility/resource phase behavior. |
| Audit | Compared the durable iPad pack selected at runtime (`OttselUserData`) against macOS `out/jak1/iso` renderer inputs. `VI1.VIS` SHA-256 is `fe923425859fda3405f484bca695aeaebf030c3bb62dcc407160dd6bc722ec8` on both paths (617,696 bytes). `fr3/village1.fr3` SHA-256 is `2098e176a1a5d80b2e2b7e0a64ac3aa3d682aee48791feb7d63bfe0a36d17865` on both paths (11,346,604 bytes). |
| Runtime proof | The iPad log reports the selected durable root and loads `village1.fr3` (36,673,019 parsed bytes, 12 tie trees, 626 tie draws, 1,563,934 tie vertices) and `VI1.VIS` (617,696 bytes). |
| Verdict | OPEN. The active VI1 VIS/FR3 data root is not the cause of the first same-transition Sprite3 phase/resource divergence. No asset substitution, data-root change, TBP remap, or renderer widening is justified. |
| Next gate | Trace runtime execution/producer state at the first same-transition Sprite3 setup and compare the shared data identities with the macOS dispatch. |

This is identity evidence only. The Simulator remained blank/non-audible, so
no visual, audio, playability, iPhone, or device-readiness claim follows.
