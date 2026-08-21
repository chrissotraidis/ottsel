# R1 macOS/mobile Sprite3 first-vector comparison — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 — Sprite3 producer/phase data before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; macOS `gk` rebuilt after the diagnostic trace |
| Environment | One Windowed macOS runtime, then stopped; no Simulator was running concurrently |
| Before failure | Mobile and macOS had matching setup-transfer order but different first Sprite3 phase/resource families; the mobile visibility result could not be interpreted without the desktop vector input. |
| Change | Added a trace-only first-vector record to the existing macOS `Sprite3::render_2d_group0` trace. It logs the first vector, texture tuple, camera translation, frame values, HVDF, and basis values for the same bounded reference frames. |
| Focused proof | `ninja -C out/jak-project/build/h1 gk` passed. The macOS route reached the existing `title-wait-ready` marker and `GAMEPLAY: enter village1`; the runtime was stopped after capture. |
| Live proof | macOS log `out/jak-project/log/jak1.2026-08-21T04-01-22.log`, frames 4–6: setup `pfog0=-0.036405455`, `inv-area=0.036767285`, camera `=(75438.49,15512.152,-4.737372e+09,-20.65182)`, basis-x `=(0.25105703,0,0,0)`, basis-y `=(0,0.14644994,0,0)`. First group was `MSCAL=211`, `TBP=9710` (32×32); its first vector was `xyz=(-398645.3,115862.33,296381.16,3686.4)`, followed by a second `MSCAL=211` group and then `MSCAL=3` world groups. |
| Mobile comparison | The validated mobile ledger records a first world group at `TBP=0x2c8d` (32×32) with representative first vector `xyz=(-4436985,-833232.25,3739648,493339.1)` and setup `pfog0=-0.2847222`, `inv-area=0.09339085`; the source-boundary capture also showed world-only `MSCAL=3` windows. |
| Fault scan | The macOS runtime reached the reference frames without a reported fault. This is behavioral/reference evidence, not a mobile visual or audio pass. |
| Verdict | OPEN. The first-vector and phase/resource inputs differ before native Metal. A clip eligibility, TBP remap, camera sign, shader, or native-consumer change is not justified by this comparison. |
| Next gate | Trace the producer-side handoff that creates the mobile first world vector/resource record, using the same frame/matrix and route markers; then add a falsifiable source-side regression before changing composition. |

The macOS `render_3d` path remains a TODO, so the observed leading `MSCAL=211`
records are recorded as phase ownership context, not as a requirement to add a
new generic VU or CPU renderer on mobile.
