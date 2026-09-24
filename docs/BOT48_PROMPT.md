# BOT48 — make the title menu legible, then take the route into Village1

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT46_PROMPT.md` (and its BOT47 continuation). Read `AGENTS.md` first, then
this file, then the tail of `docs/STATUS.md`, then
`docs/evidence/I1/BOT48-g1-pc-progress-path.md`, which carries the file/line proof
for everything asserted below.

## Product goal (unchanged, from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and controllable
under real input, a stable camera, nonzero game PCM, clean lifecycle, and sustained
frame pacing. Signed-native and ROM-safe: no ISO or extracted game data in Git, no
RWX/`MAP_JIT`/trampoline code in the product path, users supply their own data.

A build, log, counter, first frame, title screen, or Simulator-only success is never
playability proof.

## Where BOT48 starts (all verified live this round)

- The iPad Simulator app boots, signs, installs and runs; the title prompt and the
  progress menu both draw real glyphs.
- The title menu is the **PC** menu `*title-pc*` (`pc/progress-pc.gc:747`), six
  entries: `NEW GAME, LOAD GAME, OPTIONS, SECRETS, QUIT GAME, BACK`. Not the
  four-entry `*title*`.
- All six entries resolve their string and are drawn every frame at full alpha
  (`tpi=1000 sa=1000 a=128`). The menu layer is healthy.
- `NEW GAME` + Cross advances to the save-game-title screen, fault log 0 bytes,
  `scene-level='village1'`. The route is live.
- Audio is live (`OTTSEL AUDIO: PLAYER RPC play`, `pcm-peak=5685`).

## Gate contract

**Gate G1 (decisive, in progress).** Menu and prompt glyphs are only legible in
fragments that change frame to frame on a static scene; the light glyph pass drops
intermittently, leaving the black drop shadow (and sometimes nothing). Start from
the sprite/text draw path — `print-game-text` (`engine/ui/text.gc`), the sprite
`TEX0`/alpha registers, and the two-pass shadow draw set up in
`pc/progress-pc.gc:3011` — and from the per-frame glyph counters. Do not chase menu
logic: it is proven correct. Passes when one screenshot shows a full label set
legible with stable glyphs across consecutive frames.

**Gate N1 (route, next after G1).** Drive `NEW GAME` through save-game-title into
Village1 gameplay. Passes only when a fresh frame shows Village1 gameplay **with Jak
present and responding to a real input**, not a menu and not the intro camera.

**Gate S3 (carried).** The sky reads as a flat dark field. Probe the GPU-side fetch,
not a CPU clamp (`docs/evidence/I1/BOT45-sky-probe-misleading.md`), and check the
sky draw's sampler and blend against the GS CLAMP/ALPHA registers.

**Gate A1 (carried, largely closed).** Re-confirm `pcm-peak` only if it regresses.

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
path silently swallows every injected press. Confirm only one
`OttselShell` process holds the app.

Build/pack loop: `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c
'(load-project "goal_src/jak1/game.gp") (mi)'` (~34s, redirect stdout to a log),
then copy `out/jak1/iso/GAME.CGO` (and `ENGINE.CGO` when an engine file changed)
into `out/ios/app/OttselShell.app/`, `codesign --force --sign -`, and
`xcrun simctl install`.

## Do not re-derive (refuted, with evidence)

1. "The title prompt and menu draw no text" — refuted; both draw.
2. "Only OPTIONS of four entries renders" — refuted; all six submit at full alpha.
3. BOT45 Gate V2 (defer Start until the loader is idle) — withdrawn; the loader is
   busy for the whole ~54 s logo intro, so the guard can never fire.
4. BOT43 "Sprite3 overlay is the defect" — the flat rectangles are the app's own
   touch overlay (`build_touch_overlay`, drawn at `metal_shell.mm:1678`).
5. BOT45 sky probe — it clamps uv on the CPU, so it cannot report GPU sampling.
6. Anything instrumented in `engine/ui/progress/*.gc` on this build: those paths are
   shadowed by `pc/progress-pc.gc` (see the evidence doc). Instrument the PC file.

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

