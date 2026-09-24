# BOT44 - make the probes orthogonal, then attribute what is left

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT43_PROMPT.md`. Read `AGENTS.md` first, then this file, then
`docs/STATUS.md` (tail) and `docs/evidence/I1/BOT44-touch-overlay-not-sprite3.md`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO or
extracted game data in Git, no RWX/`MAP_JIT`/trampoline code in the product
path, users supply their own legal data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Why BOT44 exists

BOT43's headline - "the visible defect is the Sprite3 layer" - is withdrawn. The
flat rectangles are the app's own touch-control overlay
(`src/shell/main.cpp` `build_touch_overlay()`, drawn at `metal_shell.mm:1678`).
Full measurement in `docs/evidence/I1/BOT44-touch-overlay-not-sprite3.md`.

The reason BOT43 got there is a probe defect that BOT44 must fix first:
`metal_shell.mm:1592` gates sprite batches on `!sceneNoOverlayProbe &&
!sceneNoSpriteProbe`. `-scene-no-overlay` therefore disables sprites as well, so
no arms in the existing matrix can separate the two layers. The previous
conclusion was produced by a confounded arm.

## Disk override

`df -h / | tail -1` at the start of this round gave Avail 14Gi with no
`tmp_pack_*`. That is below the 40 GB floor in `AGENTS.md` rule 2, which is a
stop condition. The user explicitly authorized continuing with the space that
exists ("theres space to work, just keep working"), so the floor is reported
here and work proceeds. Re-run the gate before every build; if `tmp_pack_*`
appears, stop.

## Gate contract

**Gate V1 (next, decisive).** Make the layer probes orthogonal. Remove
`sceneNoOverlayProbe` from the sprite condition at `metal_shell.mm:1592` so
`-scene-no-overlay` suppresses only the touch overlay, and `-scene-no-sprite`
suppresses only sprite batches. Then re-run the four-arm matrix with one fresh
launch. Passes when: with `no-overlay` alone the flat rectangles vanish and
sprite geometry is still submitted; with `no-sprite` alone the rectangles
remain; the per-frame flat-colour detection agrees with those readings.

**Gate S1 (carried, re-scoped).** Attribute whatever flat rectangles remain once
the overlay is suppressed by design. Expected answer: none. If any remain, log
per accepted group its `count`, `tex0`, `tbp`, decoded alpha stats and
clip-space bbox, and map each rectangle to a group id.

**Gate S2 (carried).** Drive `title -> New Game -> village1 -> training`. START
is proven to work: `OTTSEL TITLE: start edge in title-wait` fires and
`activate-progress` runs to `master-mode='progress'`. What is missing is that
nothing is visibly drawn and PC progress never accepts. Exit is
`GAMEPLAY: enter village1` then `enter training` in one launch, reproduced twice,
with the player mesh in the frame.

**Gate Sky.** The sky is nondeterministic across launches: black with glints in
one instance, flat cyan in another, and degrading into white/blue streaks within
about a minute. Prior note suspects `g_direct_texture_metadata` keyed by `dest`
alone. Not started this round.

**Gate A (carried).** Audio: mixer runs in real time and produces silence
(`pcm-peak=0`). Never investigated.

**Frozen.** Camera matrix math (`set_mobile_tie_camera`), TBP/lookup,
strip-restart, the touch frontend, and all iPhone work. If the camera matrix
turns out to be the fault, write the finding instead of remapping it.

## Two log defects to be aware of

1. `format` `~D`/`~X` emit nothing in this build (verified by raw `od -c`), while
   `~A`/`~S` work. Every numeric field in an OTTSEL print is unreliable until
   this is fixed. Do not conclude anything from an "empty" field.
2. `OTTSEL_metal_gfx_game_frame` is a permanent stub returning 0 at
   `src/shell/metal_gfx.mm:8113`, so `main.cpp:1078` always takes the else
   branch and `presentRGBA` redraws the same GPU state. By design.

## Next falsifiable experiment

One launch, one edit: drop `sceneNoOverlayProbe` from `metal_shell.mm:1592`,
`bash /tmp/ottsel_relink.sh` (~26 s), relaunch with all trigger files cleared,
then screenshot arms (a) baseline, (b) `no-overlay`, (c) `no-sprite`, (d) both,
and run the flat-colour detector on each. Question: does removing the touch
overlay leave a correct scene with sprites intact, and does `no-sprite` alone
leave the rectangles? Either answer is decisive for Gate V1.

## Cheapest cross-check available

The Mac reference binary `out/jak-project/build/h1/game/gk` (wrapper
`out/Ottsel.app/Contents/MacOS/Ottsel` -> `gk -v --game jak1 -- -boot -fakeiso`)
has still never been run. It settles "what should this look like" for the title
screen, the sprite/HUD layer and the sky, and is the correct reference for
`sprite3_3d.vert`/`.frag` behaviour.
