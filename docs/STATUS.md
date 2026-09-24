# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-24

Current gate: **G1 - the whole game is signed and runtime code loading is fatal.**

- Strict list: `config/signed-game-strict.json` (350). Coverage 518 / 350 signed / 168 unsigned.
- Round 1 done ([evidence](evidence/G1/g1-training-signed-compiled-dgos-2026-09-24.md)): Training's two
  modules run signed; the pack now carries compiled level DGOs (before, level code was skipped).
- Next: `MIS.DGO` - the intro now runs 22 unsigned Misty modules through the runtime linker.
- Lane: iPad Pro 11-inch (M4) `08636791`, pack `/tmp/ottsel-user-pack-g1-1790238445` imported.
- Device build: `OTTSEL_PLATFORM=device` stops at the intended `#error` until coverage is 0. No signing
  identity, profile or attached device yet (G2).
- Tests: gstate loader PASS; `test-a11-gstate-activation.py` fails at its bare-`clang++` link (open).
- Disk: 58 GiB available, zero tmp packs.

## Log (last eight lines)

2026-09-23 G0: checkpoint commit, one-patch reconstruction verified, BOT/recovery docs archived to history/.
2026-09-23 G1: device build mode added; it confirmed 170 unsigned level modules; coverage meter landed.
2026-09-24 G1.1: Training signed (350); packs carry compiled DGOs; next MIS.DGO (22 modules now linked at runtime).
