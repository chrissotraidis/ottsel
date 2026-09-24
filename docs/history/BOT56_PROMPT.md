# BOT56 — get past the title menu, then make the game submit its own player

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT55_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`.

## Zoom-out — is this actually progress? (measured live at 12:58, not carried over)

Screen capture works. A fresh `simctl io screenshot` at 12:58 shows the Village1
hut scene, cliff, palms and sky, legible `NEW GAME`/`LOAD GAME`/`OPTIONS`/
`SECRETS`/`QUIT GAME`/`BACK` strings, and no yellow quad in that sample. The app
is pid 60757, ~23 min old, `ottsel-fault.log` 0 bytes.

Live counters, last `SUBMITSTAT` at `[58:31]`: `chain=12690` (~9.2 chains/s),
`cam-entries=105945`, `cam-level-rejects=0`, `scene-level='village1'`,
`tie-ready=true`, `tfrag-ready=true`, `merc-submits=130306`, `eichar=4`,
`eichar-attempts=4`, `raster-draws=0`; `VU1STAT` reports `vu1-runs=0`.

**Correction that reframes the last three rounds.** Screen 27 is
`(title 27)` in `out/jak-project/goal_src/jak1/engine/ui/progress/progress-h.gc:39`,
not a loading screen. The log sequence
`request screen=27 ... target-title-wait` -> `master=progress` ->
`entering screen=27 state=27` -> `incoming complete; entering normal` ->
`normal screen=27 state=27 in-out=0` is the game **successfully entering its title
menu**. The BOT55 handoff's claim that the progress screen's ART load never
completes and that the game is "stuck in the level-load path" is refuted. The app
is sitting on the title menu because nothing has pressed a button. The
`STALL-ART logo-loop 13` / `SPOOL RECOVER` loop (1165 occurrences) is the title
logo animation retrying, not a load deadlock. The repeated `OTTSEL G1` menu lines
are the same menu being redrawn every log window.

**Honest verdict.** The visual progress since BOT35 is real and hard-won: the
engine loads its own FR3 data and a scene renders from it under the live camera
packet. But two numbers say the method has stalled. First, `vu1-runs=0` and
`raster-draws=0` across 12,690 chains — the game's own GS/VU1 rasterizer has
never executed once; every visible pixel is `src/shell/metal_gfx.mm` (8763
lines), a parallel re-implementation of the bucket contract. Second,
`eichar-attempts=4` — across 12,690 chains the game submitted its player four
times, all before the title menu. The renderer is not the wall in front of us;
the game state machine is. `ottsel_metal_gfx_game_frame()`
(`src/shell/metal_gfx.mm:8754`) still returns 0, so the game has never once
produced a frame of its own.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone
parity, then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO
or extracted game data in Git, no RWX / `MAP_JIT` / trampoline code in the
product path, users supply their own data. Gate ownership for this round is
**Gate I1** ("stable and fluid scene parity") and **Gate I2** (audio and
lifecycle) from `docs/16-ipados-ios-goal-loop-2026-08-23.md`, against the macOS
reference of `docs/15-macos-to-mobile-goal-loop.md`. Gates M0 / I0 / I3 / P1 /
D1 are unchanged. Gate N1 is not passed.

A build, a log, a counter, a first frame, a title screen, a menu, a Simulator-only
success, or a route that was driven by hand is never playability proof.

## Measured start state for BOT56

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 7.7Gi 61% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator has authorized working below the
  repo's 40 GB rule. Hard stop: any `tmp_pack_*`, or below 5 GiB free. Re-run
  `df -h / | tail -1` before every experiment.
- App pid 60757, bundle `com.ottsel.shell`, UDID
  `08636791-2675-4675-8335-EF72EF954DCF`, `ottsel-fault.log` 0 bytes.
- Data container
  `.../Data/Application/D2887AF9-AA7B-472F-9926-226EDD6A7685`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`. Re-resolve
  with `xcrun simctl get_app_container` after every `simctl install`; a stale
  path silently swallows every injected press.
- Input contract (`src/shell/main.cpp:983-1025`, polled every 30 frames, file
  unlinked after firing, writable dir first then bundle):
  `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE,
  `ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN,
  `ottsel-bg-village1` -> `(bg 'village1)`.
- Outer HEAD `c66a139`; inner `out/jak-project` HEAD `49324a47e`; pin
  `641fb572e876750d8618434d9f7c1a531b43b366`.
- Working tree is dirty and must be preserved: `M docs/STATUS.md`,
  `M src/shell/metal_gfx.mm` (diagnostic probes), `M src/shell/mobile_generic_policy.h`.
  Never `git add -A`; stage exact files.

## Q1 (primary) — does the title menu still accept injected input, and what does New Game reach?

Open question because the current run's log stops at `normal screen=27 state=27
in-out=0` with no further `OTTSEL PROGRESS` line, and because `in-out=0` is the
un-transitioned value. BOT51 proved the route once on an older run and found four
things worth re-checking rather than assuming.

### Falsifiable question

With the app on screen 27 and idle, does injecting `ottsel-press-cross` at menu
index 0 (`NEW GAME`) produce a `OTTSEL PROGRESS` transition out of screen 27,
and if so into which screen; and does the resulting route end in a level load
(`OTTSEL PCSETLEV` / `begin load`) or stall?

### Smallest change

No source change. Inject one trigger file and read the log.

### Exact route

1. `df -h / | tail -1` (gate).
2. Read the last `OTTSEL PROGRESS` and `OTTSEL PC PROGRESS` lines to fix the
   current screen and option index.
3. `: > "$W/ottsel-press-cross"` (confirm on `NEW GAME`), wait ~5 s.
4. Re-read the tail; if a list screen appears, walk it with
   `ottsel-press-down` and confirm with `ottsel-press-cross`.
5. Confirm with a screenshot that the frame is not the title menu any more.

### Exit bar — a binary fork, both branches actionable

- **Transition happens and a level load begins.** The title route is sound.
  Record the exact index sequence in one evidence doc and move to Q2.
- **No transition.** The menu is not receiving the confirm, so the defect is in
  the input path or the PC progress menu's option handling. Check first whether
  the trigger file was consumed (it must be unlinked) and whether
  `ottsel BOT22: latched Cross tap` appears in the log; then read
  `out/jak-project/goal_src/jak1/pc/progress-pc.gc` around the title screen's
  option table.

## Q2 (primary) — why does the game never submit its player?

`eichar-attempts=4` over 12,690 chains. BOT51 measured the same shape on an
older run: `eichar-submits=401` all inside the title/village1 phase, and zero in
training, while `scarecrow-a-lod0` (18540) and `crate-wood-lod0` (33529) were
submitted normally. The counter increments at `src/shell/metal_gfx.mm:1633`,
before any model lookup, so this is the game not submitting the player, not the
mobile renderer dropping him.

### Falsifiable question

In a live gameplay scene, is the `target` process still `suspended` after
`(start 'play (get-continue-by-name *game-info* "game-start"))`
(`out/jak-project/goal_src/jak1/levels/village1/sequence-a-village1.gc:277`), and
is that suspension the reason no `eichar-lod0` packet is ever pushed?

### Smallest change

Reuse the existing `ottsel-trace-merc-names` probe (proven, no rebuild) to get a
fresh `eichar-submits` count for a gameplay scene, and read the `OTTSEL PROGRESS:
request ... target=#<target ... :state ...>` line for the live target state. Only
if the counter reads zero again, add one log line at the `start` call site.

### Exit bar

- **Target reads `suspended` and eichar-submits is 0.** The defect is the
  resume path for the player actor; bisect `sequence-a-village1.gc` around line
  277 and the `target` state machine in `goal_src/jak1/engine/target/`.
- **Target reads running and eichar-submits is 0.** The player exists but the
  draw node is never enabled; that moves the work into the level's
  `draw-control`/`merc` init and is the first genuine renderer-side lead.

## Carried defects (do not start a new R-round until the two blockers below are root-caused)

- **B56-A, the two named blockers.** The `presentRGBA:` /
  `_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT each need a root cause
  and a covering regression before a new R-round opens.
- **B56-B, durability.** The B53 `loader.gc` STALL/RECOVER patch
  (`out/jak-project/goal_src/jak1/engine/load/loader.gc`, the
  `while (!= (file-status ...) 'active)` block) lives only in the gitignored inner
  tree. Land it as a canonical outer patch with
  `git -C out/jak-project diff 641fb572e876750d8618434d9f7c1a531b43b366 >
  ../patches/h3-jak1-host-boot.patch`, then `git apply --check` against a fresh
  worktree at the pin. Never `git add -A`.
- **B56-C, architecture (record, do not act this round).**
  `docs/11-graphics-audio-input-deep-dive.md` §1 says to implement the mobile
  backend "behind the existing renderer module boundary rather than inventing a
  second engine". `src/shell/metal_gfx.mm` + `metal_shell.mm` +
  `mobile_scene_policy.h` + `mobile_generic_policy.h` are a parallel
  re-implementation that imports data structures only. The module is registered
  at `metal_gfx.mm:8749` with `module.pipeline = GfxPipeline::OpenGL; // no Metal
  pipeline enum; value unused`. This is the structural reason the remaining
  defects are spread across every GS/VU1 semantic. Decide its fate once Q1 and Q2
  give a real gameplay frame to judge.
- **B56-D, yellow quad and sprite parser.** BOT53 isolated the intermittent
  full-screen yellow quad to the 2D sprite/HUD path by A/B on
  `ottsel-trace-metal-scene-no-sprite` (baseline 4 of 23 captures showed
  35.3-35.5% solid yellow; armed, 0 of 30). The 32 logged
  `OTTSEL SPRITE RECORDS` lines carry positions near 2.9e7 against
  `hvdf ~2048`, which reads as a wrong stride or wrong DMA transfer in the
  sprite vector parser, not a scale-clamp bug. The `std::clamp` /
  `std::max` HUD scale path is **refuted** as the cause: the desktop oracle
  `out/jak-project/game/graphics/opengl_renderer/shaders/sprite3_3d.vert:137`
  and `sprite_3d.vert:136` apply `max(scale, min_scale)` for HUD sprites too.
  Do not "fix" the clamp.
- **B56-E, `suspend called without enough stack` x22** on the `logo` process
  (560/512, `gkernel-h.gc:473`). This is a `KERNEL_DEBUG` diagnostic only; it
  does not abort the suspend. Treat as a stack-depth smell in `logo`, and only
  promote it if Q2 implicates it.
- **B56-F, black sky.** The presented frame's sky is the neutral base fill.
  Unchanged.

## Instruments (verified)

- Screenshot: `xcrun simctl io <udid> screenshot f.png`, then
  `sips -r -90 f.png --out r.png` and `sips -Z 900 -s format jpeg r.png --out r.jpg`.
  Write only under `/tmp/ottsel-video/`.
- Log: 22.8 MB and growing; read via
  `export LC_ALL=C; tr -d '\000' < "$W/ottsel-runtime.log" > /tmp/ottsel.log`.
  Timestamps are wall-clock `MM:SS`, not elapsed.
- Relink: `bash /tmp/ottsel_relink5.sh` (~55 s, shell-only; **never**
  `relink3/4.sh`).
- Build: `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c
  '(load_project "goal_src/jak1/game.gp") (mi)'` — `--isa arm64` is mandatory.
- Liveness: per-pixel diff via `/tmp/pngdiff.py`. Never frame SHA-256 (it moves
  with the status-bar clock).
- Recording, if needed, only per `AGENTS.md` rule 1: `recordVideo --codec=h264`,
  bounded sleep <= 30 s, `kill -INT`, `ls -lh`,
  `lsof -c SimRender | grep -E '\.mov|\.mp4'`. Never plain `kill`, never
  `set -e` around a recorder.
- Do not use `rm -f` (exec rejects it); overwrite with `: > file`. Never
  `rg -rn`.

## Hard rules

Gate N1 is unproven. Never claim playability from a build, log, counter, title
screen, menu, first frame, or a hand-driven route. Frozen without a proven source
mismatch: `set_mobile_tie_camera` math, TBP/lookup, strip-restart, the touch
frontend, and all iPhone work. Evidence is capped at one concise document per
proven gate (60 lines maximum) and at most eight appended `STATUS.md` lines.
Append-only. Keep every worktree file below 100 MB.

## Order of work

1. Q1 — inject the confirm and read the transition. Cheap, no build, unblocks
   everything else.
2. Q2 — measure the target state and the live `eichar-submits` in gameplay.
3. B56-B — land the loader patch durability fix while the tree is quiet.
4. B56-D — instrument the sprite parser stride against the DMA transfer.
5. Only then the renderer-family work: `eichar`, then the Merc skinned-bounds
   suspect at `src/shell/metal_gfx.mm:1740-1742` (`px -= tx * weight`;
   BOT51 measured skinned z negative while bone translations were positive).
