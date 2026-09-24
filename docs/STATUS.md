# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-24

Current gate: **G1 - the whole game is signed and runtime code loading is fatal.**

- Strict list `config/signed-game-strict.json` (372). Coverage (body-matched): 518 / 372 / 146.
- Route title -> intro (Misty) -> Training now runs **no unsigned code** at runtime: 369 signed modules,
  fault log 0 ([round 2](evidence/G1/g1-misty-signed-streamed-order-2026-09-24.md),
  [round 1](evidence/G1/g1-training-signed-compiled-dgos-2026-09-24.md)).
- Next: module **reload** - `link()` aborts on a second load, so revisiting a level will abort. Test it
  with Training -> Sandover (warp gate) -> Training, then continue level by level (Sandover's
  neighbours: BEA, JUN, MIS already done).
- Lane: iPad Pro 11-inch (M4) `08636791`, pack `/tmp/ottsel-user-pack-g1-1790238445`. Capture loader
  rejections with `simctl launch --console-pty`.
- Device build stops at the intended `#error` until coverage is 0; no signing identity/device yet (G2).
- Tests: gstate loader PASS; `test-a11-gstate-activation.py` fails at its bare-`clang++` link (open).

## Log (last eight lines)

2026-09-23 G0: checkpoint commit, one-patch reconstruction verified, BOT/recovery docs archived to history/.
2026-09-23 G1: device build mode added; it confirmed 170 unsigned level modules; coverage meter landed.
2026-09-24 G1.1: Training signed (350); packs carry compiled DGOs; next MIS.DGO (22 modules now linked at runtime).
2026-09-24 G1.2: Misty signed (372); streamed levels exempt from list order; art twins declined; route runs no unsigned code.
