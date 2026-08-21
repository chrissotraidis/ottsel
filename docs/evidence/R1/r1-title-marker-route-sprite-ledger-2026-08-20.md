# R1 fresh title marker route and Sprite3 ledger — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 / I1 route synchronization prerequisite |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; canonical patch `patches/h3-jak1-host-boot.patch`; signed executable SHA-256 `8c59c6a31167c3e938cdc527bdb4c64f98f5ab1bad0c3d4b61e458203e5ab575`; generated `TIT.DGO` SHA-256 `f6a941106e26c3d55f03c98ce8367a5fab98b7e1cb321d77b72ee4aecaa0ea6c` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; normal Metal; Simulator shut down after capture |
| Before failure | Persisted log ordering made synthetic Start appear before `title-wait`; route attempts could not prove that Sprite3 records belonged to the intended current boot. |
| Change | Added a diagnostic-only GOAL entry marker in `goal_src/jak1/levels/title/title-obs.gc`, regenerated `TIT.DGO`, and carried the source change in the canonical patch. The marker writes only on actual `target-title-wait` entry; it does not alter input or gameplay state. |
| Focused proof | `goalc-test --gtest_filter='DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*'` passed 18/18; strict deep codesign passed; product executable-marker scan found no JIT/executable-page strings; reverse apply of the canonical patch passed. |
| Live proof | Fresh `OTTSEL ROUTE STATE: title-wait-ready` marker preceded Start; the runtime logged `start edge in title-wait`, consumed Cross and four settled Down/Cross input edges through `/tmp/ottsel-press-button`, and logged `GAMEPLAY: enter village1` twice. The trigger-gated Sprite3 ledger then armed at bucket 66/chain 54830 and completed 64 records. |
| Resource result | First populated Sprite3 records remain `tbp=0x2c8d`, PSM 19, 32×32, `TEX0=0x2005a0455530ac8d`, `TEX1=0x120`, `CLAMP=0x1010001c0`, `ALPHA=0x48`; the macOS Village1 reference remains `tbp=0x24f2`, 64×64, `TEX0=0x2004d1e59930a4f2`. Camera rows were captured in the same chain. |
| Fault scan | `ottsel-fault.log` was 0 bytes; no JIT/executable-page markers; Simulator remained blank and non-audible. |
| Verdict | OPEN — route synchronization is now proven for this fresh replay, but R1 visual/resource parity and product playability remain open. |
| Next gate | Compare the same-phase Sprite3 packet/resource ownership and macOS reference state; do not change camera or shader semantics without a specific mismatch. |

This is route and renderer attribution evidence only. It is not visual,
audio, playability, iPhone, or physical-device acceptance proof.
