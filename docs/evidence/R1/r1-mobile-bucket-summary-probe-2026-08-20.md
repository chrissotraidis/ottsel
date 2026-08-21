# R1 mobile Sprite3 bucket-summary probe — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 producer-side bucket/group ownership |
| Before failure | The macOS same-route trace proves group 0 has 51 blocks / 2,432 sprites, while the iPad ledger exposes 48-sprite groups and TBP `0x2c8d`; the mobile trace did not yet have a bounded whole-bucket total. |
| Change | Added diagnostic-only counters to `render_mobile_sprite_bucket`: valid MSCAL group count, sprite total, first/last TBP, and bucket offsets. The summary is emitted once when the parser trigger is armed and does not change rendering or ownership. Updated the canonical `h3-jak1-host-boot.patch`. |
| Focused proof | Fresh signed iPad build completed; focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18; strict codesign passed; product executable-marker scan was clean; canonical patch reverse-apply passed. |
| Live proof | Excluded. A fresh install remained at the title/progress boundary after the settled synthetic route and never logged `GAMEPLAY: enter village1`, so no parser summary or Sprite3 phase was interpreted. The Simulator was shut down. |
| Verdict | OPEN — no renderer or producer conclusion is drawn from this run. |
| Next gate | Reuse the known-good prepared-data route that already reached Village1, then arm the summary after that marker; compare total mobile groups/sprites and first/last TBP against the Mac 51-block / 2,432-sprite oracle. |

No visual, audio, playability, iPhone, or physical-device claim is made.
