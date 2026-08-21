# D2 ordered Direct IR contract — 2026-08-19

## Ledger

| Field | Result |
|---|---|
| Gate | D2 — separate Direct decoding from rendering |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; `goalc-test` rebuilt in `out/jak-project/build/h1` |
| Before failure | The existing mobile decoder and CPU diagnostic consumer are coupled in `metal_gfx.mm`; no checked-in ordered IR contract covered the D0 packet before rendering |
| Change | Extended the generated fixture test with an ordered IR contract: `PRIM:0x5c`, `A+D`, `ST/RGBAQ/XYZF2 ×4`, and `FLUSH:bucket-end`, while retaining the D0-proven final-target snapshot |
| Focused proof | `out/jak-project/build/h1/goalc-test --gtest_filter='DirectFixture.*'` — 6/6 PASS, including state snapshot, malformed-tag, truncation, and stable error-code regressions; `scripts/build-ios.sh` — iPad Simulator app build/sign PASS |
| IR/target result | Ordered state hash `0x172c927c`; `fbp=0`, FBO 65, viewport `1280x960`, `offscreen=false`; no rendering invoked |
| Live integration | A fresh iPad Pro 11-inch (M4) Simulator title-wait replay reached the linked title Direct stream. The bounded 64-transfer bucket probe observed 22 D0-shaped glyph packets; the first logged qwc14 tag was `d02e400000008001/000412412412412e` and the shared decoder emitted `PRIM,TEX0,ST,RGBAQ,XYZ ×4`, followed by `STATE,FLUSH,TRANSFER-END`, matching the hardened ordered contract. The replay remained fault-free with `ottsel-fault.log` at 0 bytes; installed replay binary hash was `2fbcfa94b5910cfd50693f78d4e373ac85be0aa7e2f9a0fd93a25b1914d297fe`. |
| Fault scan | `git diff --check`, upstream diff check, and D0/D1 reverse-apply checks pass; iPad `ottsel-fault.log` remained 0 bytes |
| Verdict | **PASS** — the generated fixture and live decoder now share the ordered packet/state/flush contract; malformed/truncated variants fail with explicit error events, and the fresh iPad replay is fault-free. This is a decoder/IR pass only, not a renderer or playability pass |
| Next gate | D3 — replay the generated fixture through the minimum native-Metal Direct draw, retaining the proven D0-NORMAL final-target identity |

This is deliberately not a D3 renderer result. It proves only that the
ROM-safe generated packet has a deterministic decode/state sequence and a
proven normal final-target identity.
