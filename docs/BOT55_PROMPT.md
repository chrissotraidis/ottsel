# BOT55 — put the player on screen, then land the one sprite-frame fix

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT54_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`.

## Zoom-out — is this actually progress?

Measured fresh at 2026-09-11 12:26 on the live app, not carried over from a
handoff.

**Real, and re-verified:** screen capture works and the captured status-bar clock
matches host wall time. The engine is live and has moved a long way —
`chain=13680` (BOT54 opened at 8730-9270), `scePadRead` ~30/s, `eichar=10335`,
`merc-submits=477782`, `cam-accepted=81125` with `cam-level-rejects=0`,
`scene-level='training'`, `tie-ready=true`, `tfrag-ready=true`, fault log
0 bytes. The presented frame is a real textured Jak 1 scene — palm trees, rocks,
the big tree trunk, the banner — drawn through Metal from the loaded FR3 data
under the live camera packet.

**Missing, and this is the honest bar:** Jak is not on screen. `raster-draws=0`
and `vu1-runs=0`, so the game's own GS/VU1 rasterizer never executes; everything
visible is a handwritten Metal reimplementation of the bucket contract. Audio is
silent (`pcm-peak=0`), input is still trigger-file driven, and the frame carries
an intermittent full-screen yellow quad plus wrong-scale Direct/HUD text.

**Verdict.** The progress is real, and the method is sound: every bucket that
landed was gated by an A/B probe instead of by inspection. But it is breadth-first
— roughly twenty rounds have produced a renderer that draws most of the world and
none of the game. The structural risk is that the product renderer is a
*re-implementation* of the PS2 pipeline, so the remaining defects are modelling
errors spread across every GS/VU1 semantic rather than a finite bug list. The
cheapest way to test whether that architecture can converge is to spend this
round on the thing Gate I1 actually names — the player — instead of on the next
bucket.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone
parity, then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO
or extracted game data in Git, no RWX / `MAP_JIT` / trampoline code in the
product path, users supply their own data.

Gate ownership: this round executes **Gate I1** ("stable and fluid scene parity
— close native TFRAG, TIE, MERC/Jak, Sprite3, Direct/HUD, material, depth, and
composition defects one at a time against macOS") from
`docs/16-ipados-ios-goal-loop-2026-08-23.md`, against the macOS reference of
`docs/15-macos-to-mobile-goal-loop.md`. Gates M0/I0/I2/I3/P1/D1 are unchanged.
Gate N1 is not passed. A build, a log, a counter, a first frame, a title screen,
a menu, or a Simulator-only success is never playability proof.

## Measured start state for BOT55

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 7.4Gi 62% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator explicitly authorized working
  below the repo's 40 GB rule. Hard stop: any `tmp_pack_*` or below 5 GiB.
  Re-run `df -h / | tail -1` before every experiment.
- App pid 55405, bundle `com.ottsel.shell`, UDID
  `08636791-2675-4675-8335-EF72EF954DCF`, `ottsel-fault.log` 0 bytes.
- Outer HEAD `c66a139`; inner `out/jak-project` HEAD `49324a47e`; pin
  `641fb572e876750d8618434d9f7c1a531b43b366`.

## Defect B55-A (primary) — the player is outside the near plane, or the bug is downstream

The one instrument that answers "where is Jak" already exists:
`ottsel-trace-merc-clip-ledger`, which evaluates the Merc vertices through the
exact raw-perspective path the Metal Merc shader uses
(`metal_gfx.mm:1821`, body to ~1950) and reports clip-space bounds plus a
`visible` count. It is **mis-aimed**: the committed arming condition is
`name == "eichar-lod0"` (the player, 20,763 submits this session), but the
uncommitted working tree had redirected it to `name == "ndi-lod0"`, which
submits once, on the title screen. That revert is the first change of this round
and is already applied.

The single reading we do have is from the title phase and is decisive-looking:
at `chain=62`, `vertices=9942 finite=9942 visible=0`,
`clip-x=(0.521, 1.119)`, `clip-y=(-0.377, 0.554)`,
`clip-z=(-1.048, -1.037)`. Every vertex sits **below** the near plane, and the
whole model spans 0.011 of a 2.0 clip-z range. Title-phase only, so it does not
yet speak for the training view.

### Falsifiable question

On the live `training` scene, is `eichar-lod0`'s clip box inside
`[-1,1]^3`, i.e. is the player actually in the frustum, or is he rejected by
the vertex transform?

### Smallest change

Already made: revert the arming condition to `eichar-lod0` so the enriched
ledger (`model`/`level` plus the numeric `OTTSEL MERC PROBE` block) fires for
the player on the current scene. No new instrument, no renderer change.

### Exact route

1. `bash /tmp/ottsel_relink5.sh` (shell-only; never `relink3/4.sh`).
2. Terminate, `simctl install`, relaunch; re-resolve the data container.
3. `: > "<container>/Library/Application Support/local.ottsel/OttselShell/ottsel-trace-merc-clip-ledger"`.
4. Wait one frame, then read the ledger and the `OTTSEL MERC PROBE` lines.

### Exit bar — a binary fork, both branches actionable

- **Outside `[-1,1]^3`** (or `visible=0`): the defect is in the transform or the
  camera pairing for the player, most likely `g_mobile_camera` being the scene
  packet while Merc uses the setup-DMA camera — `capture_mobile_merc_setup`
  already caches the two so `setup-delta-persp`/`setup-delta-hvdf` can be read
  directly. Fix the pairing under a focused regression.
- **Inside `[-1,1]^3`**: the player is submitted but not composited, so the
  defect is downstream — the dedicated `ottsel_metal_set_merc_actor_mesh`
  presentation slot (`metal_gfx.mm:2013`), depth state, winding/cull, blend, or
  draw order. Fix that boundary instead.

Either way the round closes with one inspected frame where Jak is legible, or
with a named downstream stage and a regression that isolates it.

## Defect B55-B — one root cause behind the yellow quad and the wrong-scale text

BOT53 proved by A/B on `ottsel-trace-metal-scene-no-sprite` that the
intermittent full-screen yellow quad comes from the mobile 2D sprite/HUD path
(4 of 23 baseline captures at 35.3-35.5% solid yellow; 0 of 30 with the probe
armed). B54-C reports the same path drawing `FIND THE CELL ON THE PATH` /
`GEYSER ROCK` / `OPTIONS` / `0%` at the wrong scale with an unfilled banner
plate. One `MobileSpriteFrameJak1` group frame (`basis_x`/`basis_y`,
`hmge_scale`, `min_scale`/`max_scale`) explains both. The leading asymmetry:
`sx = max(vector.xyz_sx.w * q, min_scale)` bounds the scale from below but never
from above, so a small `transformed.w` inflates `q`/`base`/`sx`/`sy`
without limit. Do this **after** B55-A, since a working player changes what is on
screen.

## Still open, unchanged

1. **B54-D** — `suspend called without enough stack` x22 on `logo`
   (`560/512`, `gkernel-h.gc:473`). Bounded ARM64 frame inflation.
2. **B54-E** — `ART-LINK` miss for `evilsis`/`evilbro` because `training` is
   not resident in the spool. Cosmetic/cutscene only; not a freeze.
3. **Durability** — the `loader.gc` STALL/RECOVER fix lives only in the
   gitignored `out/jak-project`. Land it via
   `git -C out/jak-project diff 641fb572e876750d8618434d9f7c1a531b43b366 >
   ../patches/h3-jak1-host-boot.patch`, then `git apply --check` on a fresh pin
   worktree.
4. Audio (`pcm-peak=0`), real touch input, and lifecycle are Gate I2/I3 and stay
   behind I1.

## Do not reopen without a proven source mismatch

`set_mobile_tie_camera` camera math, TBP/lookup, strip-restart, the touch
frontend, and all iPhone work stay frozen. Do not start a new R-round until the
`presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT are each
root-caused and regression-covered.

## Non-negotiable instruments

- Liveness is a per-pixel diff, never a frame SHA — the status-bar clock alone
  makes every SHA distinct. Use `/tmp/pngdiff.py`; count yellow with
  `/tmp/yellowstat.py`.
- Bundle ID is `com.ottsel.shell`; re-resolve the data container after every
  install.
- The runtime log is NUL-padded: `tr -d '\000' < "$L"`.
- Recording follows AGENTS.md rule 1 exactly: `recordVideo --codec=h264`, a
  bounded sleep of at most 30 s, `kill -INT`, then `ls -lh` and an
  `lsof -c SimRender` check. Only under `/tmp/ottsel-video/`.
- Build is `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c
  '(load-project "goal_src/jak1/game.gp") (mi)'`. `--isa arm64` is mandatory.
- Deploy copies `out/jak1/iso/*.CGO` and all 25 `*.DGO` into the installed
  bundle, then `codesign --force --sign -`, `terminate`, `install`,
  `launch`.

## Evidence discipline

One concise document per proven gate, 60 lines maximum, at most eight appended
`STATUS` lines, append-only. Never `git add -A`; never commit BOT46 or BOT48
artifacts. Keep every worktree file below 100 MB. Stage exact files.
