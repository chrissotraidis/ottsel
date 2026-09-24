# BOT58 — run Gate I0's own acceptance route, then get Jak on screen

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT57_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`.

## Zoom-out — measured live at 15:45-15:52, not carried over

The build is real and the frame is nearly a game. A fresh capture shows a
recognizable, fully textured Village1: huts, palm fronds, a totem pole, the
red-shingled tower, a sloped grass shore. 41.4% of the frame is drawn geometry.
The world is not "almost blank" — the world is drawn.

What the last several rounds actually did is the problem. Four consecutive
rounds (BOT55-BOT57) went into the sky layer, a cosmetic band whose absence
does not stop anyone from playing. Meanwhile the two things that separate "a
renderer demo" from "a game" had not been measured this round: is the player
present and controllable, and is there sound. Sound turns out to already work.
The player does not.

Three corrections to the carried-over picture, all from this session's logs:

**1. Audio is not zero.** `OTTSEL AUDIO: PLAYER RPC loaded COMMON bank sounds=461`,
`VILLAGE1 bank sounds=43`, playing named sounds `fly7` and `bird-2` through the
game's own bank/index lookup, and `OTTSEL AUDIO: mixed 48000 frames (window 260),
pcm-peak=8113` — sustained 7000-10000 across 260 windows. The "zero PCM"
inherited from BOT35/BOT37 is stale. Gate I2's "nonzero game PCM" clause looks
satisfiable; the audible route, interruption, and persistence clauses do not.

**2. The player is submitted 4 times in Village1, not 13,168.** Live
`SUBMITSTAT` in `village1`: `eichar=4 eichar-attempts=4` at `chain=7380`, while
`merc-submits=92799` climbs. Three CROSS taps change nothing. In `training`
BOT57 measured `eichar-attempts=13168`. So this is level- or state-specific,
not a global submit failure, and it is the first thing standing between the
current build and "Jak is on screen".

**3. The sky is submitted 44 times per frame and never rasterizes.** `SKYFRAME
batches=44 tex1=8 tex32=4 tex64=32 alpha0=0 alphaHalf=44 amax=0.502`;
`SKYRGB 1x1=(0.000,0.000,0.000) 32=(0.502,0.502,0.502) 64=(0.078,0.078,0.118)`.
The sky band measures 0.0% non-clear. The pass clear colour is `(8,10,18)`
(`metal_shell.mm:1178`, `MTLClearColorMake(0.03,0.04,0.07,1.0)`), and the sky
pixels are that value exactly — nothing was painted there, so this is "no
fragments", not "black paint".

### Honest verdict on progress

Real: the engine loads its own FR3 data, captures the live camera packet with
zero level rejects, builds TFRAG/TIE/MERC meshes, draws a textured Village1 at
~15 chains/s, mixes real audio, and produces a 0-byte fault log. Not real: the
player is absent, the sky is absent, `raster-draws=0`, and the game's own
VIF->VU1->GIF path remains switched off by `metal_gfx.mm:6711` so every visible
pixel is still produced by the parallel shell renderer. Gate N1 is not passed.

The structural risk BOT57 named stands: the shell re-derives every GS/VU1
semantic itself, so defects arrive one at a time and there is no natural
stopping point. The answer is not to abandon it — it produced this frame. The
answer is to stop paying for cosmetic defects and start paying for the
playability spine.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone
parity, then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO
or extracted game data in Git, no RWX / `MAP_JIT` / trampoline code in the
product path, users supply their own data.

Gate ownership this round is **Gate I0** (its own never-run acceptance route),
**Gate I1** (player visibility), and the first honest slice of **Gate I2**.
Gates M0 / I3 / P1 / D1 are unchanged. Gate N1 is not passed.

A build, a log, a counter, a first frame, a title screen, a menu, a
Simulator-only success, or a route driven by hand is never playability proof.

## Measured start state for BOT58

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 13Gi 48% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator has authorized working below
  the repo's 40 GB rule ("theres space to work, just keep working"). Hard stop:
  any `tmp_pack_*`, or below 5 GiB free. Re-run `df -h / | tail -1` before
  every experiment.
- iPad Pro 11 M4 Simulator `08636791-2675-4675-8335-EF72EF954DCF`, bundle
  `com.ottsel.shell`, app pid 77163, `ottsel-fault.log` 0 bytes. Installed
  binary md5 `e0d148e022981a30275ced5db8c12c96` == build output md5.
- Data container
  `.../Data/Application/6DD7F5F6-D50D-4998-BD1F-47C5408D516A`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`.
  Re-resolve with `xcrun simctl get_app_container` after any reinstall; a stale
  path silently swallows every injected press.
- Never `simctl install` (it recreates the container and destroys ~1.5 GB of
  game data). Install = `cp` the binary into the installed bundle, then
  `codesign --force --sign -`, then `codesign --verify --deep --strict`.
- Input contract (`src/shell/main.cpp:983-1035`, polled every 30 frames, file
  unlinked after firing, writable dir first then bundle):
  `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE,
  `ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN,
  `ottsel-bg-village1` -> `(bg 'village1)`.
- Outer HEAD `c66a139`, 16 ahead of `origin/main` (`5209405`). Working tree is
  dirty and must be preserved: `M docs/STATUS.md`, `M src/shell/metal_gfx.mm`,
  `M src/shell/metal_shell.mm`, `M src/shell/mobile_generic_policy.h`, plus
  untracked `docs/BOT*_PROMPT.md` and `docs/evidence/I1/*.md`. Never
  `git add -A`; stage exact files.
- The already-coded BOT58 diagnostics are **in the live binary** (`SKYTOPREF`,
`SKYCOPY`, `SKYFRAME`, `SKYRGB` all present via `strings`), so no rebuild is
  needed to run Q2.
- `SKYFRAME`/`SKYRGB` are `NSLog`, not `lg::info`. Read them with
  `xcrun simctl spawn <udid> log show --last 4m --style compact --predicate
  'eventMessage CONTAINS "ottsel metal"'`. They will never appear in
  `ottsel-runtime.log`.

## Q1 (primary) — run Gate I0's own acceptance route end to end

`docs/16-ipados-ios-goal-loop-2026-08-23.md` already defines the exit condition
for Gate I0: *"the app accepts a real `title-wait -> Start -> Cross -> Down x4 ->
Cross` replay."* That route has never been run. Every prior round pressed at
most Start plus one Cross.

Run it on a fresh launch with the file triggers, capturing one frame after each
step and one `SUBMITSTAT` alongside each capture. The deliverable is a
stage-by-stage table: what the frame shows, `scene-level`, `chain`, and
`eichar` after each input.

This is falsifiable in one direction that matters: either the route reaches a
state where the player is submitted and the frame is coherent, or it stalls at a
named stage and we finally know which one. Both outcomes are progress. Do not
call any stage playable on the strength of a menu or a loading counter.

## Q2 — why is `eichar` 4 in Village1 and 13,168 in Training?

Follows directly from Q1. `ottsel-metal-merc-draw.log` proves Jak's mesh *is*
decoded for this scene: 14244 indices, 38 draws, `first=(45010.852,-160.674,
-22078.443)`, `raw-row0=(-0.400123,0.000000,0.000000,0.000000)`. So the data
reaches the Merc path; the submit is what is missing.

Separate the two candidate causes with one measurement each:

- **State gate:** the level is in an intro/cutscene state that legitimately
  does not draw the player yet. Tests as: `eichar` starts climbing once the
  route of Q1 reaches gameplay.
- **Path gate:** the level's own Merc submission for `eichar-lod0` never
  happens. Tests as: `eichar-attempts` stays at 4 across the whole route while
  `training` submits the same name thousands of times.

Do not touch `set_mobile_tie_camera`, TBP / lookup-texture-by-id, strip
restart, or the touch frontend. They stay frozen without a proven source
mismatch.

## Q3 (bounded) — settle the sky with the one-batch fixture, then stop

The decisive probe is already compiled in. Arm `-sky-debug-fill` together with
`-sky-debug-all`; that run encodes, in one pass:

1. a known-good reference triangle at the **top** of the pass (`sky_top_ref_buffer`,
   NDC right half), before the sky loop;
2. each sky batch through the opaque magenta debug-fill pipeline;
3. a byte-identical fresh copy of the first textured batch (`SKYCOPY`);
4. the same copy with its first triangle's positions replaced by a known-good
   NDC triangle (`sky_ndc_buffer`);
5. a known-good reference triangle at the **end** of the pass (`sky_ref_buffer`,
   NDC lower-left half).

Outcome matrix, which is what makes this final:

| top ref | end ref | sky batches | reading |
|---|---|---|---|
| painted | painted | not painted | pass position, pipeline and layout exonerated; the batch's own buffer or draw verb is the defect |
| painted | painted | painted (copy paints, pooled does not) | the pooled vertex buffer lifetime is the defect |
| painted | painted | painted only with replaced positions | the submitted clip-space positions are the defect |
| not painted | painted | not painted | the top-of-pass slot itself is the defect (viewport/scissor/ordering) |

Run this once. Whichever row it lands on, close the sky thread with an evidence
document and move the round to Q1/Q2. Twelve rounds on a cosmetic band is
already too many.

## Loop rules

- One runtime at a time. Never launch the desktop oracle while the Simulator
  app is running (`docs/15` rule 1).
- Capture with `/tmp/ottsel-diag/runprobe.sh <probe> <tag> <n> <iv>` and
  classify with `stats.py`. A single screenshot is worthless here: four
  captures two seconds apart in one run measured drawn% of 44.9 / 100.0 / 19.8 /
  17.7. Report the distribution, never one frame.
- The app must stay signed-native, ROM-safe and non-JIT, and the fault log must
  stay 0 bytes.
- `AGENTS.md` rule 3 asks that the `presentRGBA:`/`_MTLCommandEncoder` crash and
  the Jak 1 linker `SIGABRT` be root-caused before a new round. The operator has
  directed continued work, and BOT38-BOT57 already proceeded past that clause;
  do not treat it as an authorization stop, but do not claim those two are
  closed either.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines.

## Stop conditions

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in
the repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.
