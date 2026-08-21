# D1 generated Direct fixture — 2026-08-19

## Ledger

| Field | Result |
|---|---|
| Gate | D1 — commit a ROM-safe, before-failing Direct fixture |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; test binary rebuilt in `out/jak-project/build/h1` |
| Environment | Native arm64 macOS host; no protected game data is embedded in the fixture |
| Before failure | No repository test represented the D0 ordered Direct packet or asserted the missing mobile Direct consumer; existing mobile evidence remains diagnostic CPU/VU output rather than a native Direct image |
| Change | Added `test/test_direct_fixture.cpp` and registered it in `test/CMakeLists.txt`. The fixture generates the D0 packet structure and a tiny red/transparent texture in memory, then validates the ordered contract and malformed-packet boundary. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; `out/jak-project/build/h1/goalc-test --gtest_filter='DirectFixture.*'` — 2/2 PASS |
| Contract | `direct_qwc=14`, packed tags `1`, packed records `13`, vertices `4`, triangles `2`, texture lookups/hits `1/1`, placeholders `0`, unsupported `0`, out-of-range `0`, ordered-state hash `0x172c927c`, generated image checksum `1020` |
| Fault scan | `git -C out/jak-project diff --check` PASS; tracked-file audit found no protected game data |
| Verdict | **OPEN** — ROM-safe fixture contract passes; desktop renderer image proof and current Metal expected-failure integration are still missing |
| Next gate | D2 — separate Direct decoding from rendering; first experiment is to feed this fixture through the desktop Direct decoder and compare its ordered IR/counters against this contract before adding Metal draw code |

## Boundaries

The fixture deliberately does not copy retail texels, CLUTs, DGO/CGO/STR/VIS
data, saves, or build products. It is a generated test vector only. The current
mobile renderer is not called by this test, so the passing result is not a
Metal-renderer or iPad-playability claim.
