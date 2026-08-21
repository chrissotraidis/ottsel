# R1 — macOS/native Sprite3 state mismatch is phase-attributed (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Sprite3 and renderer parity |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; macOS log `out/jak-project/log/jak1.2026-08-19T20-15-51.log` |
| Before failure | The retained iPad native readback was repeatable, but its candidate texture and state had not been tied to one macOS Sprite3 draw. |
| macOS reference | Frame 6 group 0 first draw: TBP `0x24f2`/9458, 23 sprites, `blend=2`, `ztest=2`, `zwrite=false`, `alpha-test=2`, `aref=0.000`; later groups include different TBPs and state (`zwrite=true`, `aref=0.299`). |
| iPad diagnostic candidate | The retained native candidate is TBP `0x2bc1`, `64x64`, from a different trigger/data phase; native logs apply `alpha-test=gequal/2`, `blend=source-over`, and the selected native path is not the macOS `0x24f2` group. |
| Comparison | The records are not same-phase or same-texture. The differing state is therefore not evidence of a native state bug; changing the hardcoded native state or widening the candidate batch now would be guesswork. |
| Focused proof | Existing Direct/Sprite3 fixture and focused input/compiler tests remain green; no source behavior changed in this comparison. |
| Verdict | OPEN — comparison completed as a phase mismatch, not a parity pass. |
| Next gate | Obtain one matching iPad Sprite3 bucket/texture phase after the normal-Metal startup boundary is isolated, then compare its full state tuple before changing native state mapping. |

The Simulator remains blank/non-audible. This is log/state comparison only,
not visual, audio, or playability proof. No external Jak 2 renderer, AOT,
MAP_JIT, runtime executable pages, or Metal shell was imported.
