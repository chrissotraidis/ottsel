# BOT59 — the player is on screen; make him playable

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT57_PROMPT.md` and `docs/BOT58_PROMPT.md`. Read `AGENTS.md`, then this
file, then the tail of `docs/STATUS.md`, then `docs/16-ipados-ios-goal-loop-2026-08-23.md`.

This loop is assigned to itself. Run it; do not hand it back for approval.

## Zoom-out — measured live this round

The single question that mattered for six rounds was "why is the player not in
the frame". It was answered in one session, and the answer was one line of
arithmetic.

**Jak and Daxter now render, and the cause is proven.** The MERC vertex path
applied `transformed.z -= 1.0` after the `hvdf_offset` that the
pc_camera-derived path had already normalised. That double-count shifts every
MERC vertex to depth 1.0+ near/1.0+far — behind the near plane — so the GEQUAL
depth test rejected the whole model and Jak produced zero fragments. Dropping
the extra shift puts MERC at the world's depth.

Controlled evidence, one frozen camera, one variable: with the shift
(mode 0, the shipping formula) no player is drawn; without it (modes 1-4) the
player is drawn. See `docs/evidence/I1/BOT59-merc-z-near-plane.md`. The
`eichar` submit counter also unclogged: 4 frozen for the whole route becomes
382 -> 472 and climbing.

**Do not let this round's success hide what is still false.** The build is not
playable. The frame shows Jak, but he is unlit (white), a debug HUD banner
covers the top third, the sky is still black, and `raster-draws=0` means the
game's own VIF->VU1->GIF path is still switched off at `metal_gfx.mm:6711` so
every visible pixel is produced by the parallel shell renderer. No input has
been shown to move the player. No camera stability has been shown over time.

### Honest verdict on progress

Real this round: a proven near-plane fix, the player on screen in a fresh
Simulator launch, a real game save-file dialog that renders its own text
(`A JAK AND DAXTER SAVE GAME ALREADY EXISTS...`), audio still mixing
(`pcm-peak=8113`), `ottsel-fault.log` 0 bytes, no `tmp_pack_*`.

Not real: playability. Six of the last eight rounds paid for cosmetic bands
(sky, HUD) while the one defect that actually stopped a human from playing sat
in a shader line nobody had read against the data. The lesson to carry forward
is procedural: when a gate stalls, spend the round on the term in the
playability sentence that is false, not on the term that is merely ugly.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone
parity, then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO
or extracted game data in Git, no RWX / `MAP_JIT` / trampoline code in the
product path, users supply their own data.

Gate ownership this round is **Gate I1** (player visibility, now provably
passed for Village1) and the first honest slice of **Gate I2** (input ->
movement -> lifecycle). Gates M0 / I0 / I3 / P1 / D1 are unchanged. Gate N1 is
not passed.

A build, a log, a counter, a first frame, a title screen, a menu, a
Simulator-only success, or a route driven by hand is never playability proof.

## Measured start state for BOT59

- Disk: `/dev/disk3s3s1 460Gi 12Gi 14Gi 47% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator has authorized working below
  the repo's 40 GB rule. Hard stop: any `tmp_pack_*`, or below 5 GiB free.
  Re-run `df -h / | tail -1` before every experiment.
- iPad Pro 11 M4 Simulator `08636791-2675-4675-8335-EF72EF954DCF`, bundle
  `com.ottsel.shell`. Installed binary md5 `7580b030c1c839549743379c0bbea494`
  == build output md5. `ottsel-fault.log` 0 bytes.
- Data container
  `.../Data/Application/6DD7F5F6-D50D-4998-BD1F-47C5408D516A`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`.
  Re-resolve with `xcrun simctl get_app_container` after any reinstall; a stale
  path silently swallows every injected press.
- Never `simctl install` (it recreates the container and destroys ~1.5 GB of
  game data). Install = `cp` the binary into the installed bundle, then
  `codesign --force --sign -`, then `codesign --verify --deep --strict`.
- Rebuild with `/tmp/ottsel_relink5.sh` (~20 s; never relink3/4). It compiles
  `main.cpp`, `metal_shell.mm`, `metal_gfx.mm` and relinks.
- Input contract (`src/shell/main.cpp:983-1035`, polled every 30 frames, file
  unlinked after firing): `ottsel-press-start` -> RETURN,
  `ottsel-press-cross` -> SPACE, `ottsel-press-left` -> LEFT,
  `ottsel-press-down` -> DOWN, `ottsel-bg-village1` -> `(bg 'village1)`.
- `ottsel-merc-zmode` in the writable dir overrides the MERC z formula at
  runtime: 0 = with the (wrong) `-1.0` shift, 1 = identity (shipping default),
  2 = negate, 3 = `-z-1`, 4 = `z*0.5+0.5`. Keep it as the A/B handle.
- Outer HEAD `c66a139`, 16 ahead of `origin/main` (`5209405`). Working tree is
  dirty and must be preserved. Never `git add -A`; stage exact files.

## Q1 (primary) — does real input move the player?

This is the next falsifiable term in the playability sentence and nothing so
far has tested it. Press `left` and `down` on a frozen Village1 launch and
measure whether Jak's skinned bounds or camera-relative position change across
frames. The `OTTSEL MERC MATRIX LEDGER` line already prints
`skinned-bounds` and `first-tmat-translation` per frame, so no new probe is
needed: capture the ledger before and after each press.

Outcomes: either the bounds translate in the pressed direction (input reaches
the player; move to Q2), or they do not, and we learn whether the pad state or
the actor's own movement code is the gap. Do not call a stage playable on the
strength of a press being accepted.

## Q2 (bounded) — the player is unlit

Jak renders white. `merc2.vert` computes `vtx_color = rgba * light_color`
from `light_dir0_fade` / `light_dir1_fade_en` / `light_dir2` /
`light_col0..2` / `light_ambient`, which come from the model's `VuLights`
`m_low_memory`. The Metal path binds none of them, so the shader is running on
defaults. Read `Merc2.cpp`'s uniform upload next to our merc uniform struct,
then wire exactly the missing vectors. One falsifiable check: with the uniforms
bound, the same vertex produces a non-white colour.

## Q3 (bounded) — the frame is still not a clean scene

Two known non-playability defects, one doc each, no round each:

1. A debug HUD banner quad covers the top third of every frame
   (`docs/evidence/I1/i1-hud-sprite-giant-quad-2026-09-11.md`). It also
   invalidates any "sky painted" metric, because it is pure yellow and the old
   classifier counted it as sky.
2. The sky band is still black. The outcome matrix in `BOT58_PROMPT.md`
   Q3 is unrun; run it once and close the thread either way.

## Loop rules

- One runtime at a time. Never launch the desktop oracle while the Simulator
  app is running (`docs/15` rule 1).
- Capture a sequence, never one frame: four captures seconds apart in one run
  have measured 44.9 / 100.0 / 19.8 / 17.7 drawn percent.
- The app stays signed-native, ROM-safe and non-JIT; `ottsel-fault.log` stays
  0 bytes.
- `AGENTS.md` rule 3 asks the `presentRGBA:`/`_MTLCommandEncoder` crash and
  the Jak 1 linker `SIGABRT` be root-caused before a new round. The operator has
  directed continued work past that clause; do not treat it as an authorization
  stop, but do not claim those two are closed either.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines.

## Stop conditions

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in
the repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.

