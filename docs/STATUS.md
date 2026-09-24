# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). Full log before 2026-09-23:
[history/STATUS-2026-08-07-to-2026-09-23.md](history/STATUS-2026-08-07-to-2026-09-23.md).

## Board - 2026-09-23

Current gate: **G1 - the whole game is signed and runtime code loading is fatal.**

- G0 done: work committed, nested delta is `patches/ottsel-jak-project.patch` (194 files; pin + patch ==
  live tree `21c6a2c7`), one authority, evidence media ignored, module-generation leak capped.
- Coverage: `scripts/signed-coverage.py` -> 518 code modules, 348 signed, 170 unsigned (every level
  except TIT/VI1; Training's `training-obs`/`training-part` included). Next: add TRA.DGO's two.
- Device build: `OTTSEL_PLATFORM=device` compiles the runtime for `iphoneos` and stops at the intended
  `#error` in `ottsel_signed_gstate.cpp` (log `/tmp/ottsel-device-build.log`). No signing identity,
  provisioning profile or attached device on this Mac yet (needed at G2).
- Simulator baseline: route to Training by touch on iPad and iPhone profiles, input + sound + lifecycle
  ([evidence](evidence/A1/g2-acceptance-run-with-audio-2026-09-23.md)); iPad Simulator ~5-10 fps.
- Tests: `test-a11-gstate-loader.py --module-list config/signed-kernel-full.json` PASS after the offset
  update; `test-a11-gstate-activation.py` fails at its bare-`clang++` link step (not investigated).
- Stale cache: ~13 GB of old `out/ios/app/signed-gstate/modules.*`; the next full simulator build keeps
  the newest three and removes the rest.
- Disk: 44 GiB available, zero tmp packs.

## Log (last eight lines)

2026-09-23 G0: checkpoint commit, one-patch reconstruction verified, BOT/recovery docs archived to history/.
2026-09-23 G1: device build mode added; it confirmed 170 unsigned level modules; coverage meter landed.
