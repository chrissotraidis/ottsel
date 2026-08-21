# R1 pre-Metal user-data preflight — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity; F1 diagnostic dependency |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app from the current iOS build; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The preceding fresh Documents-pack Metal replay stopped after `OTTSEL BOOT PHASE: selecting iOS data root`, before later boot phases or Sprite3 evidence. The same pack reached Village1 in SDL-only mode. |
| Change | Added an opt-in `OTTSEL_PREPARE_DATA_BEFORE_METAL` seam. After bundle/writable paths and logging are initialized, it validates/promotes the user pack and caches the selected root before native Metal creation; normal launches remain unchanged. |
| Focused proof | `./scripts/build-ios.sh` completed; the app bundle was signed and strict codesign verification passed. |
| Live proof | One fresh launch with `SIMCTL_CHILD_OTTSEL_PREPARE_DATA_BEFORE_METAL=1` and optional audio probes disabled logged validated-pack import, pre-Metal preparation, selected root, optional sound probe completion, low-EE protection, kernel globals, save root, `GAMEPLAY: enter title`, and native Sprite3 candidate/ownership lines. |
| Fault scan | `ottsel-fault.log` was empty. The runtime log contains existing `FR3: missing level 'title'` and `'village1'` warnings from the current test-pack/bundle arrangement; those are not hidden or reclassified. |
| Simulator boundary | The Simulator remained blank and non-audible. This run is boot/liveness and native-candidate instrumentation only; it is not visual, audible, title/menu, or playability proof. |
| Verdict | OPEN — pre-Metal preparation removes the earlier early-stop observation for this run, but R1 native image parity and F1 legal Files delivery remain unproven. |
| Next gate | R1/D3: capture a correctly framed native Metal comparison or a falsifiable Sprite3/Direct image fixture with counters; preserve the blank-Simulator limitation. |

