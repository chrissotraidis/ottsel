# BOT49 — from a rendering title menu to Jak on the ground

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT48_PROMPT.md`. Read `AGENTS.md` first, then this file, then the tail of
`docs/STATUS.md`, then `docs/evidence/I1/BOT49-sprite-batch-forensics.md`, which
carries the file/line proof for the refutations below.

## Product goal (unchanged, from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and controllable
under real input, a stable camera, nonzero game PCM, clean lifecycle, and sustained
frame pacing. Signed-native and ROM-safe: no ISO or extracted game data in Git, no
RWX/`MAP_JIT`/trampoline code in the product path, users supply their own data.

A build, log, counter, first frame, title screen, or Simulator-only success is never
playability proof.

## Where BOT49 starts (all verified live this round)

- The iPad Simulator app boots, signs, installs and runs. Village1 renders as a
  coherent 3D frame: stone cliffs, tiled thatch roofs, palm trees, correct
  textures and lighting. The scene layer is no longer the weak link.
- Route is live: `title-wait-ready` -> `ottsel-press-start` opens the PC title menu
  (`*title-pc*`, six entries) over a live Village1 render.
- The screen-space text tearing is **fixed and measured**. `presentRGBA` used to end
  every frame by clearing all transient sprite and Direct/GIF groups, dropping any
  group the game thread appended while the command buffer was still being built;
  the HUD submits 3 groups per frame but only 1 survived. Batches are now tagged and
  the encoder erases exactly the tags it encoded. Retained Direct groups rose from 1
  to 18-22 per frame and `NEW GAME` renders complete and stable across consecutive
  frames. See `docs/evidence/I1/BOT49-direct-text-retention-fix.md`.
- Two earlier proposed mechanisms were **measured and refuted** (see "Do not
  re-derive"). Do not re-litigate them.
- Live measurable baseline: the HUD appends **3 atlas groups per frame**
  (`vertices=270 sprites=48 skipped=3`, `vertices=288 sprites=48 skipped=0`,
  `vertices=192 sprites=32 skipped=0`), and `presentRGBA` reports
  `drawn == appended-during-encode` in essentially every frame.

## Gate contract

**Gate N1 (PRIMARY this round).** Drive `NEW GAME` through save-game-title into
Village1 gameplay. Passes only when a fresh frame shows Village1 gameplay **with
Jak present and responding to a real input**, not a menu and not the intro camera.
Everything else is subordinate to this: a legible menu is not playability.

**Gate G1 (mostly closed, finish after N1).** Screen-space text legibility. The
mid-encode erase is fixed. Remaining: all six title entries should appear in the
same frame rather than one or two at a time, and the reason the fifth/sixth entries
are still missing is unproven. Use the zero-rebuild flag matrix below to isolate it;
do not reopen the sprite/HUD upload path.

**Gate S3 (carried).** The sky reads as a flat dark field and shows streaky garbage
in some frames. Probe the GPU-side fetch, not a CPU clamp
(`docs/evidence/I1/BOT45-sky-probe-misleading.md`), and check the sky draw's
sampler, blend and the untextured 1x1 full-screen fans flagged in
`metal_shell.mm:1360`.

**Gate A1 (carried, mostly closed).** Re-confirm `pcm-peak` only if it regresses.

## Zero-rebuild diagnostic matrix (do this before writing any shader fix)

`metal_shell.mm` polls the writable dir each frame for trigger files that set a
probe flag and then unlink themselves. Create one and take a burst; nothing needs
to be rebuilt. Re-resolve the writable dir first (see the input contract).

- `ottsel-trace-metal-scene-no-sky` -> `sceneNoSkyProbe` (sky batches skipped)
- `ottsel-trace-metal-scene-no-sprite` -> `sceneNoSpriteProbe` (HUD/sprite skipped)
- `ottsel-trace-metal-scene-no-merc` -> `sceneNoMercProbe`
- `ottsel-trace-metal-scene-no-tie` -> `sceneNoTieProbe`
- `ottsel-trace-metal-scene-no-tfrag` -> `sceneNoTfragProbe`
- `ottsel-trace-metal-scene-no-depth` -> `sceneNoDepthProbe`

One variable per run, same route, same wall-clock offset, burst of >= 6 frames.
The question each run answers: does the label set become complete and stable, or
does it fragment identically? A run that changes nothing is still a result.

## Input contract — use this, not the old one

`docs/BOT46_PROMPT.md` Gate N1 is wrong. There is no `/tmp/ottsel-press-button`.
`src/shell/main.cpp:983-1025` polls these paths every 30 frames and unlinks each
after firing, resolving against
`<data-container>/Library/Application Support/local.ottsel/OttselShell/` first,
then the read-only bundle:

- `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE (Cross/confirm),
  `ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN,
  `ottsel-bg-village1` -> `(bg 'village1)`.

Inject with `: > "$W/ottsel-press-start"`. Wait for
`OTTSEL ROUTE STATE: title-wait-ready` in `ottsel-runtime.log` before pressing.
`simctl install` recreates the data container, so re-resolve it with
`xcrun simctl get_app_container <udid> com.ottsel.shell data` afterwards; a stale
path silently swallows every injected press. Confirm only one `OttselShell`
process holds the app.

Logs are NUL-padded: always read them as
`LC_ALL=C tr -d '\000' < f | LC_ALL=C grep -a ...`.

Build/pack loop: `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c
'(load-project "goal_src/jak1/game.gp") (mi)'` (~34s, redirect stdout to a log),
then copy `out/jak1/iso/GAME.CGO` (and `ENGINE.CGO` when an engine file changed)
into `out/ios/app/OttselShell.app/`, `codesign --force --sign -`, and
`xcrun simctl install`. The shell-only relink is
`bash /tmp/ottsel_relink3.sh` (~40s).

## Do not re-derive (refuted, with evidence)

1. "The title prompt and menu draw no text" — refuted; both draw.
2. "Only OPTIONS of four entries renders" — refuted; all six submit at full alpha.
3. BOT45 Gate V2 (defer Start until the loader is idle) — withdrawn; the loader is
   busy for the whole ~54 s logo intro.
4. BOT43 "Sprite3 overlay is the defect" — the flat rectangles are the app's own
   touch overlay (`build_touch_overlay`, drawn at `metal_shell.mm:1678`).
5. BOT45 sky probe — it clamps uv on the CPU, so it cannot report GPU sampling.
6. Anything instrumented in `engine/ui/progress/*.gc`: shadowed by
   `pc/progress-pc.gc`. Instrument the PC file.
7. "The hardcoded `(count != 48 && count != 32)` gate in
   `append_mobile_sprite_hud_native` drops glyph groups" — refuted; every group
   reports `orig_pass=1`, and only 48/32 are ever seen.
8. "`clearSpriteBatches()` inside `setSpriteMeshNow` wipes HUD groups already
   appended this frame" — refuted; the discard path logged **zero** non-empty
   clears across a 4.6 MB runtime log.
9. "Groups appended during encode are lost to the snapshot/clear race" — refuted;
   `drawn == appended-during-encode` in ~4000/4000 samples.

## Operating rules for this loop

Before every experiment: `df -h / | tail -1` and count
`.git/objects/pack/tmp_pack_*`. The operator has explicitly authorized working in
whatever space exists, so a sub-40 GB reading is not by itself a stop; **any**
`tmp_pack_*` and a free-space drop below 5 GiB are hard stops to report. Keep every
worktree file below 100 MB, never `git add -A`, stage explicit paths, and never use
`rm` (truncate with `: > file`).

Record each experiment as current evidence, one falsifiable question, the smallest
change, the before-failing regression, the exact route, and the exit bar. Cap
evidence at one <=60-line doc per proven gate and at most eight appended STATUS
lines. Do not open a new R-round until the `presentRGBA:`/`_MTLCommandEncoder`
crash and the Jak 1 linker SIGABRT are each root-caused and regression-covered.

## Frozen

Camera matrix math (`set_mobile_tie_camera`), TBP/lookup, strip-restart, the touch
frontend, and all iPhone work. If the camera matrix turns out to be the fault, write
the finding instead of remapping it.
