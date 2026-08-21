# R1 normal-Metal Cross route boundary — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 / I1 real title-to-New-Game route prerequisite |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app from current `out/jak-project/out/ios/app/OttselShell.app` |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one normal-Metal runtime; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1`; `MTL_DEBUG_LAYER=1`; validated pack fully staged before launch |
| Before failure | Earlier real-route attempts left Cross unconsumed or ended before title progress, so the input path and the Metal route could not be separated. |
| Change | No product source change. Started with no trigger files, waited for `title-play received wait; entering title-wait`, then injected `ottsel-press-start`; after `incoming complete; entering normal`, injected `ottsel-press-cross` twice and `ottsel-press-left` once at the writable preference root. |
| Focused proof | Existing Direct/Sprite/input/compiler filter passed 18/18; strict codesign and `git diff --check` passed. |
| Live proof | `OTTSEL PAD: synthetic pad0 button0=0x8` followed the Start trigger; later logs recorded `button0=0x4000` twice and `button0=0x80` for Cross/Left. Normal Metal stayed alive and submitted large TIE/TFRAG meshes (`319546/253196`, `75960/53304`, `511138/252888`) with no command-buffer error in the bounded current-process system log. |
| Fault scan | `ottsel-fault.log` was 0 bytes; all trigger files were consumed. No `GAMEPLAY: enter village1`, New Game, or Sequence A transition followed the Cross presses. The Simulator remained blank/non-audible. |
| Verdict | OPEN — the writable trigger bridge is proven live, but the normal-Metal title/progress route does not advance after Cross in this clean replay. This is route/state progress evidence, not iPad playability, visual, audio, or device proof. |
| Next gate | Compare the same trigger sequence in SDL-only mode and inspect the progress/title state transition at the first divergence; then fix only the shared input/state boundary if SDL-only advances and Metal does not. |

No protected data, external renderer, MAP_JIT, or runtime executable-code path was used.
