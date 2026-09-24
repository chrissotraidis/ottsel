# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-23

Current gate: **G1 - runs on a physical iPad.**

- G0 done: outer work committed (`6fbb535`), nested delta is `patches/ottsel-jak-project.patch`
  (194 files; pin + patch == live tree `21c6a2c7`), one authority, evidence media ignored.
- Simulator baseline (strict lane): 346/346 signed modules, 0-byte fault log, touch route to Training on
  iPad and iPhone profiles, input + sound events + lifecycle in one run
  ([evidence](evidence/A1/g2-acceptance-run-with-audio-2026-09-23.md)). iPad Simulator ~5-10 fps.
- G1 blockers: no Apple Development identity or provisioning profile on this Mac, no device attached.
- Open, carried: intro cutscene spool stall (stale spool-owner handle) - G3 if it blocks the playtest.
- Disk: 44 GiB available, zero tmp packs.

## Log (last eight lines)

2026-09-23 G0: checkpoint commit, one-patch reconstruction verified, BOT/recovery docs archived to history/.
