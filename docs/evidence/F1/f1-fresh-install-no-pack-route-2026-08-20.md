# F1 fresh-install data boundary — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | F1 — legal user-data import and save persistence |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app executable SHA-256 `2b72134f8e3a8fd76d49850b656c271b35decca9e8138fd8ae81193bfc13bb5e` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, one fresh uninstall/install; SDL-only diagnostic mode; no macOS runtime |
| Before failure | The real title/New Game route needs the user-owned sound/video data before `title-play received wait`; earlier route evidence had used a previously prepared container. |
| Live proof | After fresh install with `OTTSEL_PREPARE_DATA_BEFORE_METAL=1`, the app reached `GAMEPLAY: enter title` but repeatedly requested `ndi-intro` and logged `OTTSEL STR: chunked animation not found`. The bundle contained generated `TIT.DGO`/`VI1.DGO` and text fixtures, but no imported user pack. `title-play received wait` never appeared, so no input was injected. |
| Fault scan | `ottsel-fault.log` was 0 bytes. No protected data was copied, added, or committed. |
| Simulator boundary | The Simulator was blank/non-audible; this is data-route diagnostics only, not playability or audio proof. |
| Verdict | OPEN — the synchronized route cannot reach the input gate on a fresh no-pack install. This confirms the F1 legal user-data import dependency rather than a new renderer mismatch. |
| Next gate | Obtain/use a legal validated user-data pack through the existing Files/import path, then repeat the synchronized title → New Game route with Metal enabled and the Sprite3 catalog. |

