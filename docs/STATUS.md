# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-24

Current gate: **G1 - the whole game is signed and runtime code loading is fatal.**

- **The real IOP/OVERLORD now runs on iOS** and the whole intro plays to Geyser Rock with a 0-byte fault
  log ([evidence](evidence/G1/g1-real-iop-intro-plays-2026-09-24.md)). The no-IOP emulation and its GOAL
  workarounds (intro skip, moved art, forced spool evictions) are gone from the default build.
- Strict list `config/signed-game-strict.json` (372): 518 / 372 signed / 146 unsigned. Streamed modules
  reload. The intro route runs no unsigned code.
- Most visible defect now: particle/sprite effects render as rotated striped quads (custom Metal sprite
  path). Next rounds: sign the remaining levels in play order, then the sprite/particle renderer.
- Lane: iPad Pro 11-inch (M4) `08636791`; `/tmp/ottsel-tools/full.sh <tag>` rebuilds, repacks, imports,
  routes and summarizes (run it in a polled session; background jobs are killed).
- Device build stops at the intended `#error` until coverage is 0; no signing identity/device yet (G2).
- Disk: 47 GiB available, zero tmp packs.

## Log (last eight lines)

2026-09-23 G0: checkpoint commit, one-patch reconstruction verified, BOT/recovery docs archived to history/.
2026-09-23 G1: device build mode added; it confirmed 170 unsigned level modules; coverage meter landed.
2026-09-24 G1.1: Training signed (350); packs carry compiled DGOs; next MIS.DGO (22 modules now linked at runtime).
2026-09-24 G1.2: Misty signed (372); streamed levels exempt from list order; art twins declined; route runs no unsigned code.
2026-09-24 G1.3: real IOP on iOS; fake-IOP GOAL workarounds reverted; streamed reload; the full intro plays to Geyser Rock.
