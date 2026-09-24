# BOT51 — the player is suspended: resume the target, then draw Jak

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT50_PROMPT.md`. Read `AGENTS.md` first, then this file, then the tail of
`docs/STATUS.md`, then `docs/evidence/I1/BOT51-route-and-target.md`.

## Product goal (unchanged, from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and controllable
under real input, a stable camera, nonzero game PCM, clean lifecycle, and sustained
frame pacing. Signed-native and ROM-safe: no ISO or extracted game data in Git, no
RWX/`MAP_JIT`/trampoline code in the product path, users supply their own data.

A build, log, counter, first frame, title screen, or Simulator-only success is never
playability proof.

## Where BOT51 starts (measured live this round)

The menu route now completes into gameplay, and the blocker has moved from "the route
stalls" to "the player actor is never drawn".

- The route runs end to end under injected input: `ottsel-press-start` -> PC title
  menu (screen 27); `ottsel-press-cross` -> `save-game-title` list (screen 18);
  `down` x3 -> cursor `index=0 -> 1 -> 2 -> 3`; `cross` at index 3 -> two
  `****** CALL TO kopen() ******`, then `OTTSEL PCSETLEV: levels -> 'none'
  'village1'`, `'misty'`, `'training'`, `begin load training-vis [tra.DGO]`, and
  `GAMEPLAY: enter training`.
- **Gameplay HUD text renders.** A fresh frame shows `FIND THE CELL ON THE PATH` and
  `GEYSER ROCK` over the training level. BOT46 only ever proved menu text; this is
  the gameplay objective HUD.
- **The player is not drawn.** Whole-run `OTTSEL MERC NAMES`:
  `distinct=29 submits=132397 eichar-submits=401`, and `eichar-lod0 packets=401`.
  All 401 eichar packets belong to the title/village1 phase. The training phase sends
  `scarecrow-a-lod0` (18540), `scarecrow-b-lod0` (7416), `money-lod0` (33689),
  `crate-wood-lod0` (33529) and never sends eichar.
- **The target process reads suspended.**
  `OTTSEL PROGRESS: request screen=0 allowed=#t target=#<target target suspended
  :state target-stance :stack 224/1024 :heap 34832/49152 @ #x1f6434> existing=#f`.
- The intro fallback fires: `OTTSEL INTRO: sequence B unavailable; entering normal
  play` from `out/jak-project/goal_src/jak1/levels/village1/sequence-a-village1.gc:277`,
  which calls `(start 'play (get-continue-by-name *game-info* "game-start"))`.
- Frame pacing is roughly flat: `SUBMITSTAT` chain advanced 13860 -> 16470 between
  `[28:28]` and `[33:52]`, about 8.1 chains/s in training (village1 measured ~9.5).
  `raster-draws=0` in most SUBMITSTAT lines.
- The presented frame does animate: spaced screenshots 3 s apart differ, two
  back-to-back bursts produced 13 distinct images. The "frozen frame" read is an
  artifact of sampling inside a sub-second window.

## The ladder (ranked; measure each before starting the next)

- **N1-A — resume the target (PRIMARY).** One falsifiable question: why is `*target*`
  still `suspended` after the sequence-B fallback issues
  `(start 'play (get-continue-by-name *game-info* "game-start"))`? Instrument the
  target's process status at the point `OTTSEL PROGRESS: request screen=0` is logged,
  and trace the `suspend`/`resume` pair around the `sequence-a-village1` `:exit`
  fallback. Do not edit the fallback before the suspend/resume ledger exists.
- **N1-B — eichar returns (exit bar for A).** Passes only when `eichar-lod0
  packets` climbs while `scene-level='training'`, measured with the
  `ottsel-trace-merc-names` probe before and after the fix.
- **N1-C — character transform.** `OTTSEL MERC MATRIX LEDGER: model=eichar-lod0
  slots=79 valid=79 source-bounds=(-7127.006,-1893.693,-5243.745)..(7099.166,13293.536,5202.778)
  skinned-bounds=(10166.861,-11565.121,-50536.234)..(24067.197,7414.107,-37709.477)`
  with `first-tmat-translation=(-15882.562500,-5357.578125,47290.937500,1.000000)`.
  The skinned z is about -37709..-50536 while the bone translations are about +47290;
  the accumulation at `src/shell/metal_gfx.mm:1740-1742` is `px -= tx * weight`, so the
  sign convention is the first suspect. Compare against the maintained PC Merc2 path
  before changing it.
- **N1-D — the PC_PORT trace is not trustworthy.** `ottsel-trace-native-merc` prints
  `bounded PC_PORT ledger armed` and then logs no `VALID` and no `ignored` line even
  though merc packets keep flowing. Explain that before using the probe as evidence.

## Gate contract

**Gate N1 (PRIMARY).** Passes only when a fresh frame shows Village1 or training
gameplay **with Jak present and responding to a real input**, not a menu, not the
intro camera, and not a screenshot whose only player evidence is a HUD string.

**Gate G1 (mostly closed).** Screen-space text legibility. Gameplay HUD text now
joins menu text as proven. Remaining: all six title entries should appear in one frame.

**Gate S3 (carried).** The sky reads as a flat dark field in some frames; the training
frames show a correct dark sky, so re-measure before probing the GPU-side fetch.

**Gate A1 (carried, mostly closed).** `pcm-peak=16383` was observed again this run;
re-confirm only if it regresses.

## Zero-rebuild diagnostic matrix (use before writing any shader fix)

`metal_shell.mm` polls the writable dir each frame for trigger files that set a probe
flag and then unlink themselves. Create one and take a burst; nothing needs a rebuild.

- `ottsel-trace-metal-scene-no-sky` -> `sceneNoSkyProbe`
- `ottsel-trace-metal-scene-no-sprite` -> `sceneNoSpriteProbe`
- `ottsel-trace-metal-scene-no-merc` -> `sceneNoMercProbe`
- `ottsel-trace-metal-scene-no-tie` -> `sceneNoTieProbe`
- `ottsel-trace-metal-scene-no-tfrag` -> `sceneNoTfragProbe`
- `ottsel-trace-metal-scene-no-depth` -> `sceneNoDepthProbe`
- `ottsel-trace-merc-names` -> dumps the whole merc name histogram plus
  `distinct/submits/eichar-submits`. This is the ground truth for N1-B.
- `ottsel-trace-native-merc` -> arms a bounded 32-entry PC_PORT merc ledger. Suspect
  until N1-D is explained.

One variable per run, same route, same wall-clock offset, burst of >= 6 frames.

## Input contract

`src/shell/main.cpp:983-1033` polls these paths every 30 main-loop iterations and
unlinks each after firing, resolving against
`<data-container>/Library/Application Support/local.ottsel/OttselShell/` first, then
the read-only bundle: `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE,
`ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN, `ottsel-bg-village1` ->
`(bg 'village1)` (dead end; nothing consumes the flag). Inject with
`: > "$W/ottsel-press-start"`. `simctl install` recreates the data container, so
re-resolve it with `xcrun simctl get_app_container <udid> com.ottsel.shell data`
afterwards; a stale path silently swallows every injected press.

## Build, logs, and pack loop

- Shell-only relink: `bash /tmp/ottsel_relink5.sh` (~55 s; compiles `main.cpp`,
  `metal_shell.mm` and `metal_gfx.mm`, relinks, codesigns). Do **not** use
  `/tmp/ottsel_relink3.sh` or `/tmp/ottsel_relink4.sh`: they skip `shell_main.o`, so
  `main.cpp` edits silently never land.
- The engine's real log is the data container's
  `.../Library/Application Support/local.ottsel/OttselShell/ottsel-runtime.log`.
  `lg::info` reaches it; `NSLog` from this process reaches neither `log stream` nor
  `log show` on the Simulator, so instrument with `lg::info`.
- The log is NUL-padded: always read it as
  `LC_ALL=C tr -d '\000' < f | LC_ALL=C grep -a ...`, otherwise `tr`/`grep` abort
  with "Illegal byte sequence".
- GC pack loop unchanged: `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64
  -c '(load-project "goal_src/jak1/game.gp") (mi)'` (~34 s), copy the regenerated
  DGOs into `out/ios/app/OttselShell.app/`, `codesign --force --sign -`,
  `xcrun simctl install`.

## Noise filter for the runtime log

The log is dominated by per-chain debug spam. Filter with
`grep -vE 'MOBILE DIRECT: qwc14|OTTSELVRAM |OTTSELMESHTEX |OTTSEL AUDIO: PLAYER RPC|decoded texture|OTTSEL LINKSTAT:|link finish:|loader stall|OTTSEL G1:'`
before reading a tail, and prefer narrow `grep -E 'OTTSEL (PC PROGRESS|PCSETLEV|MERC|LEVEL|SUBMITSTAT):'`
over wide tails.

## Do not re-derive (refuted, with evidence)

1-13. All BOT49 and BOT50 refutations stand. Add:
14. "The Simulator frame is frozen." Refuted: spaced screenshots differ, and two
    back-to-back bursts produced 13 distinct images in about 2.5 s. Sampling twice
    inside one presented-frame window is what made it look frozen.
15. "The mobile renderer is dropping the eichar merc packet." Refuted:
    `g_mobile_merc_name_counts[name]` increments before any model lookup, and it reads
    401. The game itself stops submitting eichar during gameplay.

## Operating rules for this loop

Before every experiment: `df -h / | tail -1` and count
`.git/objects/pack/tmp_pack_*`. The operator has explicitly authorized working in
whatever space exists, so a sub-40 GB reading is not by itself a stop; **any**
`tmp_pack_*` and a free-space drop below 5 GiB are hard stops to report. Keep every
worktree file below 100 MB, never `git add -A`, stage explicit paths, and never use
`rm` (truncate with `: > file`).

Record each experiment as current evidence, one falsifiable question, the smallest
change, the before-failing regression, the exact route, and the exit bar. Cap evidence
at one <=60-line doc per proven gate and at most eight appended STATUS lines. Do not
open a new R-round until the `presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1
linker SIGABRT are each root-caused and regression-covered.

## Frozen

Camera matrix math (`set_mobile_tie_camera`), TBP/lookup, strip-restart, the touch
frontend (`build_touch_overlay`, `main.cpp:629-641`), and all iPhone work. If the
camera matrix turns out to be the fault, write the finding instead of remapping it.
