# R1 iPad Sprite3 candidate catalog — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `2b72134f8e3a8fd76d49850b656c271b35decca9e8138fd8ae81193bfc13bb5e`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | macOS reference evidence records a broader Sprite3 route with 2304 world sprites and multiple texture/state buckets; the iPad native probe previously uploaded only the first eligible candidate, so the matching bucket was unknown. |
| Change | Extended the trigger-gated diagnostic catalog to continue decoding/logging the first 32 candidates after the first native upload, including candidate index, TBP, PSM, bounds, visibility, and usability. Only the first eligible candidate is still uploaded. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep codesign verification passed; `git diff --check` passed. |
| Live proof | Fresh iPad route catalogued 32 candidates. The records used only TBP `0x2bc1` and `0x2bd3` (PSM 19); candidates 0, 1, 6, 7, 12, 13, 18, 19, 24, 25, 30, and 31 were usable/visible. The first native upload remained candidate 0 at `0x2bc1`; fault log was 0 bytes. |
| Comparison | The macOS reference bucket is TBP `9458` (`0x24f2`) in the captured frame, absent from this iPad trigger/data phase. Therefore no batch expansion or parity claim is justified from this catalog. |
| Simulator boundary | Simulator remained blank/non-audible and was shut down. This is route/state diagnostics only, not playability proof. |
| Verdict | OPEN — the current trigger reaches a different Sprite3 texture set than the macOS reference phase. |
| Next gate | Reconcile the accepted title/Village1 route and data phase so one macOS-identified TBP/state bucket is emitted on iPad; then batch only that matched group. |

