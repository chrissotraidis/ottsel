# R1 prepared-route full Sprite3 phase mismatch — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/consumer parity |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one normal-Metal runtime; validated pack prepared before Metal; Simulator blank and non-audible |
| Route | Fresh app process `61490`; title marker reached, synthetic Start/Cross/Down/Cross route accepted through `/tmp/ottsel-press-button`, and `GAMEPLAY: enter village1` logged twice. |
| Mobile phase capture | Bucket 66 parser summary at chain `17358`: frame transfer 9 (`656` bytes, VIF `0x3d4`), matrix transfer 12 (`80` bytes, VIF `0x384`); headers 13–14 ran MSCAL `211` (3D) with `48+16` sprites; headers 15–21 ran MSCAL `3` (group-0) with `48+48+48+48+48+48+32 = 320` world sprites. First/last group-0 TBPs were `0x2c8d` and `0x2d7c`. |
| Bucket table probe | In the same live chain (`0x50c820`), bucket 66 had `addr=0xd02960`, bucket 67 `addr=0xd00f30`, and bucket 68 `addr=0xd01b40`. The bounded transfer dump for both bucket 66 and bucket 67 began with the same Sprite3 frame/matrix/group sequence, so the assumed bucket-67 standalone-Direct ownership is itself not yet proven on this mobile stream. |
| macOS oracle | Same-route Sprite3 trace frame 1 reports `group0 blocks=51 sprites=2432`, with first world draw TBP `9458` (`0x24f2`, 55 sprites); subsequent draws include `0x2525`, `0x25e6`, `0x24a6`, and other phase-owned groups. |
| Fault scan | Mobile `ottsel-fault.log` was `0` bytes. |
| Focused proof | `./out/jak-project/build/h1/goalc-test --gtest_filter='DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*'` passed all 18 tests. No product source behavior was changed for this capture. |
| Interpretation | The mobile capture is not a same-phase equivalent of the macOS group-0 stream. Mobile also sees a distinct MSCAL `211` 3D phase before group-0 but currently discards it for the group-0 renderer. The seven-group/320-sprite boundary is the first concrete traversal/ownership defect to isolate; no TBP remap or shader/state change is justified. |
| Verdict | OPEN — phase alignment is falsified; native Sprite3 parity remains open. |
| Next gate | Add a before-failing ROM-safe parser regression for the observed bucket table and sequence. First prove which DMA address is the Sprite3 bucket boundary and which address owns the standalone Direct stream; preserve MSCAL 211 versus MSCAL 3 ownership, then re-run the route and compare complete group counts/TBPs. |

No visual, audio, iPhone, physical-device, or playability claim is made. No
MAP_JIT, runtime executable page, dynamic trampoline, external Metal shell, or
protected game data was imported.
