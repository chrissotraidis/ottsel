# F1 no-data remediation boundary — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | F1 — legal user-data import and save persistence |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `24f594362b81bad49da489fe8a67bb8470d40a74c6b24da834acf22d1adc70ea` |
| Before failure | A clean install fell back to diagnostic bundle data and logged missing `ndi-intro`, but had no explicit remediation state for the user to import a pack. |
| Change | Added an iOS boot status flag, `ottsel_ios_has_user_data()`, and a shell remediation line, `DATA: import OttselUserData in Files`, shown whenever no validated durable/imported pack is selected. Validated durable/import success sets the flag; every bundle fallback resets it. No data-selection or renderer fallback behavior changed. |
| Focused proof | `bash -n scripts/validate-user-data-pack.sh`; `scripts/build-ios.sh` completed through assemble/sign; `codesign --verify --deep --strict` passed; `git diff --check` passed. |
| Live proof | Not run with a user pack because no legal validated pack is available in the environment. |
| Simulator boundary | No visual or audio claim; the Simulator remains blank/non-audible, and this change is a product-state boundary only. |
| Verdict | PARTIAL — the clean-install remediation state is implemented and signed, but F1 import, title-to-Village1 streaming, save/reload, and Files UI acceptance remain open. |
| Next gate | Deliver a legal validated pack through Files/import, confirm the remediation state clears, then repeat the real route and R1 Metal comparison. |

