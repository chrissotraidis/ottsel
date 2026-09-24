# BOT60 — the frame is frozen in the intro cutscene; unstick it

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT59_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`, then `docs/16-ipados-ios-goal-loop-2026-08-23.md`.

This loop is assigned to itself. Run it; do not hand it back for approval.

## Zoom-out — measured live this round

Two rounds of work were aimed at "why does input not move the player". Both
asked the wrong question. This round measured the frame itself and the answer
was one number.

**The 3D scene is frozen.** With the app sitting in Village1 gameplay, three
screenshots a second apart change **8 of 423,000 scene pixels (0.00%)** between
rows 90-560. Every pixel that moves is in the corrupted top strip or the status
bar. The frame is a still image. A longer 8 s pair behaves the same, and Jak's
silhouette is identical to 0.1 px across every capture.

**The game loop is not the constraint.** `chain` goes 44100 -> 45360 in 20 s,
`vsync` 44191 -> 45361, `iteration` 44200 -> 45400: the EE/GOAL loop runs at
**~60 Hz**. The renderer is fed the same scene 60 times a second.

So "input does not move the player" is not an input bug. There is no moving
player to observe. The app reaches the opening cutscene and stops there.

### The route does close end-to-end — that part is real

For the first time the game's own front end was driven into gameplay, proven in
`ottsel-runtime.log`: `PC PROGRESS: edge screen=27 index=0` -> `accept screen=27`
-> `edge screen=18 index=0..4` -> `accept screen=18 index=4` ->
`GAMEPLAY: enter village1` -> `CAMERA START: cp "intro-start"` ->
`INTRO: preloading misty before sequence A`. Title -> New Game -> save-file
screen -> Continue Without Saving -> Village1 is closed by real pad input.

### Two inherited readings are refuted

1. `edge index=N` is printed **before** the increment (`progress-pc.gc:2208`
   formats `option-index` at the top of `respond-common`), so the recorded value
   is *the option that was pressed*. The `0,1,2,3,4` staircase in this run is the
   correct reading, not a stuck cursor.
2. `eichar=4` does not mean the player is missing. The MERC name census shows
   `eichar-lod0 packets=4 sidekick-lod0 packets=8 distinct=38`; Daxter is a
   separate model. `merc-submits` frozen at 142043 is a **consequence** of the
   frozen scene, not an independent fact.

## Product goal (unchanged, from the PRD and the gate loop)

An honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe.

Gate ownership this round is **Gate I1** (a scene that actually advances) plus
the first honest slice of **Gate I2** (input -> movement). A log line, a
counter, a still frame, a menu, or a Simulator-only result is not playability.

## Measured start state for BOT60

- Disk: `/dev/disk3s3s1 460Gi 12Gi 13Gi 47% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator has authorized working below the
  repo's 40 GB rule. Hard stop: any `tmp_pack_*`, or below 5 GiB free. Re-run
  `df -h / | tail -1` before every experiment.
- iPad Pro 11 M4 Simulator `08636791-2675-4675-8335-EF72EF954DCF`, bundle
  `com.ottsel.shell`, PID 83987, ~60 fps, RSS 653 MB. `ottsel-fault.log` 0 bytes.
- Data container
  `.../Data/Application/6DD7F5F6-D50D-4998-BD1F-47C5408D516A`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`.
  Re-resolve with `xcrun simctl get_app_container` after any reinstall.
- Never `simctl install` (it recreates the container and destroys game data).
  Install = `cp` the binary in, `codesign --force --sign -`, `codesign --verify
  --deep --strict`. Rebuild with `/tmp/ottsel_relink5.sh` (~20 s).
- `ottsel-runtime.log` is the writable-dir file (44 MB, grows ~280 lines/s);
  its `[MM:SS]` stamps are minutes:seconds, not hours:minutes.
- Readouts: `raster-draws=0` (the game's own VIF->VU1->GIF path is still off at
  `metal_gfx.mm:6711`), `pcm-peak=0` right now, sky black, Jak unlit white.
- Outer HEAD `c66a139`, 16 ahead of `origin/main` (`5209405`). Working tree is
  dirty and must be preserved. Never `git add -A`; stage exact files.

## Q1 (primary, and the whole round) — is the cutscene stalled or is it a long cutscene?

This is the only term in the playability sentence that is currently false. A
frozen frame is a product defect regardless of which side of the boundary it
sits on, so the round does not close until it is classified.

The falsifiable question: **does the rendered scene change at all over 60 s of
wall time in the current state?** Measure with the region-resolved diff, not
with a counter. `chain`/`vsync`/`iteration` advance while the scene is frozen
and cannot answer it.

Outcomes and what each means:

- **Scene changes / new `CAMERA START: cp "..."` appears / a new `OTTSEL INTRO`
  sequence line appears** -> the cutscene is playing and simply long. Then the
  round's job is to drive it to a controllable state and only then re-run the
  movement test. Do not call input dead yet.
- **Scene stays frozen and no new camera or sequence line appears** -> the state
  machine is stalled after `preloading misty before sequence A`. Then find what
  the intro tick waits on: BOT58 proved the title spool (`LOLOOP.STR`) loops, so
  check whether sequence A waits on a stream chunk that never arrives, and
  whether `master-mode` ever leaves the intro. That is the bug to fix, and it is
  worth more than any cosmetic band.

Either way, a fresh app launch plus the verified menu route is the reproduction.

## Q2 (only after Q1 lands) — does input move a controllable player?

Do not restart this until the scene animates. When it does:

1. Confirm the state is not a cutscene.
2. Hold LEFT and hold RIGHT for **> 2 s** each via `ottsel-hold-left` /
   `ottsel-hold-right`, and capture 3 frames per phase.
3. Compare Jak's silhouette bounds `(n, minx, maxx, miny, maxy)` with
   `/tmp/ottsel-diag/jakcent.py`, and confirm the **scene** band moved with
   `banddiff.py` before trusting a stationary player.

The D-pad is the channel the menu already proved works. Separately,
`out/jak-project/game/sce/libpad.cpp` writes `cpad->leftx/lefty` from
`/tmp/ottsel-hold-left-stick` (`"x y frames"`, frames <= 1200) — that is the
analog stick channel Jak's movement actually reads, and it is the better handle
for movement once the scene is live.

## Loop rules

- One runtime at a time. Never launch the desktop oracle while the Simulator
  app runs (`docs/15` rule 1).
- Capture a sequence, never one frame, and always region-resolve it: a 3.5%
  whole-frame change in this build was 100% status-strip noise.
- Work back from the frame, not from the counters. A counter is evidence about
  the counter.
- The app stays signed-native, ROM-safe and non-JIT; `ottsel-fault.log` stays
  0 bytes.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines.

## Stop conditions

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in the
repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.
