# BOT50 — from ~9 chains/s to a playable frame, then Jak under input

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT49_PROMPT.md`. Read `AGENTS.md` first, then this file, then the tail of
`docs/STATUS.md`, then `docs/evidence/I1/BOT50-perf-baseline.md`, which carries the
measured proof for everything below.

## Product goal (unchanged, from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and controllable
under real input, a stable camera, nonzero game PCM, clean lifecycle, and sustained
frame pacing. Signed-native and ROM-safe: no ISO or extracted game data in Git, no
RWX/`MAP_JIT`/trampoline code in the product path, users supply their own data.

A build, log, counter, first frame, title screen, or Simulator-only success is never
playability proof.

## Where BOT50 starts (measured live this round)

- The frame is coherent and animated: a Village1 fly-through with correct textures
  and lighting (fresh screenshot sha256 `a78fa32e…`). The stray gray/yellow/cyan/
  pink rectangles are the app's own frozen touch overlay, not a renderer defect.
- **The rate baseline was wrong.** The engine advances ~9.3 chains/s, not ~1 fps;
  BOT49's "~1.01 s fixed wait per frame" is refuted. `SUBMITSTAT: chain` advances
  90 per ~9-10 s.
- Two renderer-side changes landed and were measured: pooled sky/Direct vertex
  buffers, then a strided mesh-texture key hash. ~9.3 -> ~12.0 chains/s (+28%).
- The limiter is the game thread inside `send_gfx_dma_chain` (99% of its samples).
  Top exclusive costs now `decode_texture_pixels_raw` 24%,
  `render_mobile_sprite_group0` 22%, `gfx_vsync`'s `__psynch_cvwait` 15%, and
  game-side `access()` 10%.
- The decode cache is genuinely ~99.5% hitting (`hits=1566571 misses=1638400-…`), so
  its ~169 misses/chain are real distinct textures, not a cache defect.
- Gate N1 is still unproven: Start -> Cross reaches the PC title menu, and Cross on
  the menu lands on loading `/100` at `9%`, not Village1 gameplay.

## The ladder (ranked; measure each before starting the next)

- **L1 — `render_mobile_sprite_group0` (22%, 504 samples).** Real per-vertex
  transform work at `metal_gfx.mm:4801`. First question: is the same bucket
  transformed more than once per frame, or does the appended vertex set duplicate
  across groups? Answer that before touching the math.
- **L2 — `decode_texture_pixels_raw` (24%).** Before changing
  `kOttselMobileDmaDecodeBudget` (512), prove whether the ~169 misses/chain are
  distinct textures or the same texture under keys that differ only by `clut_addr`
  or `w64`.
- **L3 — `gfx_vsync` `__psynch_cvwait` (15%, ~10 ms/chain).** Decide whether this
  is a real 60 Hz wait or a sleep we impose; compare against a `vsync`-free run.
- **L4 — gate N1, the route stall.** `ROUTE STATE` shows Start opening the menu and
  Cross starting a load that stops at `9%`. Find what the loader waits on. This is
  the gate that actually matters; L1-L3 only buy headroom.

## Gate contract

**Gate N1 (PRIMARY).** Drive `NEW GAME` through save-game-title into Village1
gameplay. Passes only when a fresh frame shows Village1 gameplay **with Jak present
and responding to a real input**, not a menu and not the intro camera.

**Gate G1 (mostly closed).** Screen-space text legibility. The mid-encode erase is
fixed. Remaining: all six title entries should appear in the same frame, and the
reason the fifth/sixth are still missing is unproven. Use the zero-rebuild matrix;
do not reopen the sprite/HUD upload path.

**Gate S3 (carried).** The sky reads as a flat dark field. Probe the GPU-side fetch,
not a CPU clamp, and check the sky draw's sampler, blend and the untextured 1x1
full-screen fans flagged in `metal_shell.mm:1360`.

**Gate A1 (carried, mostly closed).** Re-confirm `pcm-peak` only if it regresses.

## Zero-rebuild diagnostic matrix (use before writing any shader fix)

`metal_shell.mm` polls the writable dir each frame for trigger files that set a probe
flag and then unlink themselves. Create one and take a burst; nothing needs a rebuild.

- `ottsel-trace-metal-scene-no-sky` -> `sceneNoSkyProbe`
- `ottsel-trace-metal-scene-no-sprite` -> `sceneNoSpriteProbe`
- `ottsel-trace-metal-scene-no-merc` -> `sceneNoMercProbe`
- `ottsel-trace-metal-scene-no-tie` -> `sceneNoTieProbe`
- `ottsel-trace-metal-scene-no-tfrag` -> `sceneNoTfragProbe`
- `ottsel-trace-metal-scene-no-depth` -> `sceneNoDepthProbe`

One variable per run, same route, same wall-clock offset, burst of >= 6 frames.

## Input contract — unchanged from BOT49

`src/shell/main.cpp:983-1025` polls these paths every 30 frames and unlinks each after
firing, resolving against
`<data-container>/Library/Application Support/local.ottsel/OttselShell/` first, then
the read-only bundle: `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE,
`ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN, `ottsel-bg-village1` ->
`(bg 'village1)`. Inject with `: > "$W/ottsel-press-start"`. Wait for
`OTTSEL ROUTE STATE: title-wait-ready` before pressing. `simctl install` recreates
the data container, so re-resolve it with
`xcrun simctl get_app_container <udid> com.ottsel.shell data` afterwards; a stale
path silently swallows every injected press.

## Build, logs, and pack loop

- Shell-only relink: `bash /tmp/ottsel_relink5.sh` (~55 s; compiles `main.cpp`,
  `metal_shell.mm` and `metal_gfx.mm`, relinks, codesigns). Do **not** use
  `/tmp/ottsel_relink3.sh`: it skips `shell_main.o`, so `main.cpp` edits silently
  never land.
- The engine's real log is the data container's
  `…/Library/Application Support/local.ottsel/OttselShell/ottsel-runtime.log`.
  `lg::info` reaches it; `NSLog` from this process reaches neither `log stream` nor
  `log show` on the Simulator, so instrument with `lg::info`. The log is NUL-padded:
  always read it as `LC_ALL=C tr -d '\000' < f | LC_ALL=C grep -a …`.
- GC pack loop unchanged: `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64
  -c '(load-project "goal_src/jak1/game.gp") (mi)'` (~34 s), copy the regenerated
  DGOs into `out/ios/app/OttselShell.app/`, `codesign --force --sign -`,
  `xcrun simctl install`.

## Do not re-derive (refuted, with evidence)

BOT49's nine refutations all still stand. Add:

10. "The frame rate is ~1 fps and each frame waits ~1.01 s" — refuted; ~9.3
    chains/s at baseline, ~12.0 after the two BOT50 changes. The per-frame wait is
    `gfx_vsync`'s `__psynch_cvwait`, ~10 ms, not ~1 s.
11. "The CLUT-window split will collapse the decode misses" — the split is applied
    and correct, but the ~169 misses/chain are genuine; evicting 26.4 memos per
    changed page does not make those decodes unnecessary.
12. "`g_vram_decode_evicted` measures evictions" — until BOT50 the increment sat
    outside its loop, so it counted invalidations and always equalled `changed`.
13. "`cachedMeshTexture:` is dominated by `newTextureWithDescriptor:` XPC" —
    measured: it was dominated by the inlined FNV-1a over every tile byte; the
    uploads are rare (294 misses in 24576 calls).

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

