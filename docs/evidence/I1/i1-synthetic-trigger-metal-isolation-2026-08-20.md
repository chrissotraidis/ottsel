# I1 synthetic-trigger and Metal-route isolation — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | I1 input route diagnostic; R1/F1 route dependency |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app from the current worktree; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | A writable `ottsel-press-start` file remained unconsumed during a Metal launch that stopped progressing at the drawable-host boundary, so that run could not distinguish input failure from renderer-host teardown. |
| SDL-only isolation | With `OTTSEL_DISABLE_METAL=1`, writable START and Cross files were consumed. `scePadRead` logged synthetic `button0=0x8` and `0x4000`; the title state logged `OTTSEL TITLE: start edge in title-wait`, followed by normal progress. Fault log remained empty, aside from pre-existing RAMDISK invalid-read diagnostics in the runtime log. |
| Metal preseed | With `ottsel-bg-village1` present before launch and Metal enabled, the shell consumed the trigger and logged the `(bg 'village1)` call/return plus `*artist-all-visible*`; no Sprite3 native line arrived before the bounded run ended. |
| Interpretation | The documented file-to-pad trigger seam is live in SDL-only mode. The unconsumed post-launch Metal trigger was a runtime/drawable-host liveness boundary, not evidence that synthetic input ownership is broken. |
| Simulator boundary | The Simulator remained blank and non-audible. No visual, audible, or playability claim is made. |
| Verdict | OPEN — input seam isolation is stronger, but physical controller acceptance, native Metal route completion, and R1 parity remain open. |
| Next gate | Resolve/diagnose the Metal drawable-host survival boundary or capture the native Sprite3 phase from a stable native run; preserve the SDL-only result as diagnostic evidence. |

