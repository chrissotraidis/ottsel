# R1 Sprite3 native probe — 2026-08-19

| Field | Result |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator binary SHA-256 `bfca912bc56db4bada366bc42ff9b3fb62d143374c1585471b9f39057104a65f` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5; one Simulator; no CPU frame publication |
| Before failure | Sprite3 records were only expanded through the diagnostic CPU raster path. A first native attempt used the first decoded group without a verified visible-space bound and altered the native composition unexpectedly. |
| Change | Added a bounded `OttselMetalSpriteVertex` six-vertex Metal upload and direct textured draw. It decodes one Sprite3 TEX0/CLUT page, preserves vertex color, and is enabled only by the explicit `ottsel-trace-mobile-sprite-metal` trigger. Degenerate/offscreen quads are skipped. |
| Focused proof | `scripts/build-ios.sh` — signed app PASS; `goalc-test --gtest_filter='DirectFixture.*'` — 6/6 PASS; `git diff --check` — PASS |
| Live proof | Triggered native probe logged `texture=hit`, `vertices=6`, and `64x64` texture. The first candidate was rejected as `x=1.000..1.000`; the next candidate was rejected by the bounded probe as a near-zero strip, observed as `x=-1.000..1.000,y=.991..1.000`. Native draw logging and zero-byte fault scan were clean. Screenshot: [probe frame](r1-first-sprite-metal-2026-08-19.png). |
| Fault scan | `ottsel-fault.log` was 0 bytes; no CPU `g_frame` publication path remains. |
| Verdict | **OPEN** — the native upload/draw seam exists, but the current Sprite3 coordinate expansion does not yet prove a correct visible image. The probe is trigger-gated and cannot affect normal product presentation. |
| Next gate | R1 continuation — reconcile Sprite3 transformed coordinates against the desktop Sprite3 consumer and prove one bounded visible quad before enabling broader Sprite3 draws. |

This is a failed discriminator, not a Sprite3 parity or playability claim.
