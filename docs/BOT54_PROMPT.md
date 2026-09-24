# BOT54 — root-cause the giant HUD sprite quad, then get Jak visible and controlled

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT53_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone
parity, then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO
or extracted game data in Git, no RWX / `MAP_JIT` / trampoline code in the
product path, users supply their own data. Gates M0 / I0 / I1 / I2 / I3 / P1 / D1
are defined in `docs/16-ipados-ios-goal-loop-2026-08-23.md` and are unchanged.
Gate N1 is not passed.

A build, a log, a counter, a first frame, a title screen, a menu, or a
Simulator-only success is never playability proof.

## Measured state at the start of BOT54 (live, 2026-09-11 12:00-12:25)

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 7.4Gi 62% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator explicitly authorized working
  below the repo's 40 GB rule. Hard stop: any `tmp_pack_*` or below 5 GiB.
  Re-run `df -h / | tail -1` before every experiment.
- Screen visibility works. Captures carry the live status-bar clock matching
  wall time, so the Simulator is being read correctly.
- The engine is live, not frozen. `chain` 8730 -> 9270 in 51 s (~7 chains/s);
  `scePadRead` #34001 -> #35001 in 33 s (~30/s); `eichar=6285` and climbing.
  Last `SUBMITSTAT` (`chain=8190`) reported `scene-level='training'`,
  `tie-ready=true`, `tfrag-ready=true`, `cam-accepted=53675`,
  `cam-level-rejects=0`. Informative lines stop after ~[10:48] because a log
  budget ran out, not because the loop stopped.
- `OTTSEL SPRITE FRAME AGG` measures 256 sprites per frame in 7 groups:
  3d 48@0x24d2 + 16@0x2525, world 48@0x2506 + 16@0x24d1, hud 48@0x2517 +
  48@0x252d + 32@0x21fd.
- `VU1STAT` still reports `vu1-runs=0 draws=0`; the world mesh is drawn by the
  shell's own Metal path, not VU1.

## Defect B54-A (primary, now isolated)

The full-screen yellow quad is emitted by the mobile 2D sprite/HUD path. Proven
by A/B on `ottsel-trace-metal-scene-no-sprite`: baseline 4 of 23 captures showed
35.3-35.5% solid yellow spanning the whole drawable; with the probe armed, 0 of
30 captures did. See `docs/evidence/I1/i1-hud-sprite-giant-quad-2026-09-11.md`.

This also retires the "the frame is frozen" reading. The presented content is a
mostly-static HUD pose, so consecutive captures are often bit-identical even
though the renderer advances every chain.

### Falsifiable question for this round

Which sprite record produces a drawable-sized quad — is a single record
degenerate, or is the group's inherited `MobileSpriteFrameJak1`
(`basis_x`/`basis_y`, `hmge_scale`, `min_scale`/`max_scale`) wrong?

### Smallest change

Add a bounded, trigger-armed per-record ledger for the HUD phase groups
(`metal_gfx.mm:5440 append_mobile_sprite_hud_native`, `5587
render_mobile_sprite_hud`) that prints, for the widest few records only, the
camera-transformed w, `q`, `sx`, `sy`, and the four device-space clip
vertices. Cap it at one frame per arm, mirroring the existing
`ottsel-trace-mobile-sprite-frame-aggregate` pattern. Then A/B the same
`no-sprite` probe against the ledger's own frame.

### Exit bar

Either (a) one named record with an extent on the order of the drawable is
named and fixed under a focused regression, or (b) every record is bounded and
the defect is the group frame, in which case fix the group frame. The exit
evidence is one inspected clean frame plus the ledger showing the offending
extent before and after.

## Defects still open, in order after B54-A

1. **B54-B** — Jak is not visible in the training view. `first-tmat-translation`
   is ~(-4637,-9821,37014) and the merc `projection_mode=1` row0 is
   `-0.400123` against vertices of x~45010 (`metal_shell.mm:1217`). Compare
   against the TIE/TFRAG derived `pc_camera` path that draws the terrain.
2. **B54-C** — the `FIND THE CELL ON THE PATH` / `GEYSER ROCK` / `OPTIONS` /`0%`
   text is drawn at the wrong scale and the banner plate is unfilled. Likely the
   same group-frame defect as B54-A; re-test after B54-A lands.
3. **B54-D** — `suspend called without enough stack` x22 on the `logo` process
   (`560/512`, `gkernel-h.gc:473`). ARM64 frame inflation; bounded.
4. **B54-E** — `ART-LINK` miss for `evilsis`/`evilbro` because `training` is not
   resident in the spool. Cosmetic/cutscene only; do not treat as a freeze.
5. **Durability** — the `loader.gc` STALL/RECOVER fix exists only in the
   gitignored `out/jak-project` worktree (`patches/h3-jak1-host-boot.patch` has
   0 occurrences, the working-tree diff has 1). Land it via
   `git -C out/jak-project diff 641fb572e876750d8618434d9f7c1a531b43b366 >
   ../patches/h3-jak1-host-boot.patch`, then `git apply --check` on a fresh pin
   worktree.

## Do not reopen without a proven source mismatch

`set_mobile_tie_camera` camera math, TBP/lookup, strip-restart, the touch
frontend, and all iPhone work stay frozen. Do not start a new R-round until the
`presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT are each
root-caused and regression-covered.

## Non-negotiable instruments

- Liveness is measured by a per-pixel diff, never by frame SHA: the status-bar
  clock alone makes every SHA distinct. Use `/tmp/pngdiff.py`.
- Bundle ID is `com.ottsel.shell`; `xcrun simctl get_app_container <udid>
  com.ottsel.shell data` and re-resolve after every install.
- The runtime log is NUL-padded: `tr -d '\000' < "$L"`.
- Recording follows AGENTS.md rule 1 exactly: `recordVideo --codec=h264`, a
  bounded sleep of at most 30 s, `kill -INT`, then `ls -lh` and an
  `lsof -c SimRender` check. Only under `/tmp/ottsel-video/`.
- Build is `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c
  '(load-project "goal_src/jak1/game.gp") (mi)'`. `--isa arm64` is mandatory.
  After a GOAL change, remove stale objects and regenerate affected DGOs.
- Deploy copies `out/jak1/iso/*.CGO` and all 25 `*.DGO` into the installed
  bundle, then `codesign --force --sign -`, `terminate`, `install`, `launch`.
  Shell-only relink is `bash /tmp/ottsel_relink5.sh`; never `relink3/4.sh`.

## Evidence discipline

One concise document per proven gate, 60 lines maximum, at most eight appended
`STATUS` lines, append-only. Never `git add -A`; never commit BOT46 or BOT48
artifacts. Keep every worktree file below 100 MB. Stage exact files.
