# R1 generated DGO identity audit — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 — producer/resource divergence before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed iPad app built from the current checkout |
| Before failure | Same-transition macOS and iPad runs had matching Village1 target position but different first Sprite3 phase/resource records. A packaging or generated-DGO mismatch remained a possible upstream explanation. |
| Audit | Compared SHA-256 identities of the signed app bundle’s generated files against the macOS `out/jak1/iso` route used by `gk -fakeiso`. `VI1.DGO` is `8910a4fcc117e966f30f76c357b68299d60024e2cf98361cd6b0763c76fe75e0`; `TIT.DGO` is `f6a941106e26c3d55f03c98ce8367a5fab98b7e1cb321d77b72ee4aecaa0ea6c`; `GAME.CGO` is `abc06dfd848e6773c62c173b367843ab987296c75e904f760d74ceb8a0cc749b` on both paths. |
| Control | The older ignored `iso_data/jak1` retail copies differ (`VI1.DGO` `9300242a...`, `GAME.CGO` `0960b6...`), but `scripts/build-ios.sh` explicitly copies `out/jak1/iso` and the signed bundle contains the matching generated hashes. |
| Verdict | OPEN. Bundle/codegen identity mismatch is ruled out for this comparison. The remaining divergence is runtime producer/phase state or handoff before native Metal; no DGO replacement, TBP remap, or renderer change is justified. |
| Next gate | Trace the first same-transition producer record against the shared generated DGO/CGO route state and compare runtime camera/phase ownership. |

This audit does not claim visual, audio, playability, iPhone, or device
readiness. The Simulator remains a blank diagnostic surface in the current
evidence set.
