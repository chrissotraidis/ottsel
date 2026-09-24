# BOT62 — prove Jak is CONTROLLABLE, then make the sky show

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT61_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`, then `docs/16-ipados-ios-goal-loop-2026-08-23.md`.

This loop is assigned to itself. Run it; do not hand it back for approval.

## Product goal (unchanged, from the PRD and the gate loop)

An honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible **and
controllable** under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe.

Gate ownership this round is Gate I1: the visible-correctness half plus the
first movement half. A log line, a counter, a still frame, a menu, or a
Simulator-only result is not playability.

## Zoom-out — what actually moved, and what did not

**The route is not broken and Village1 is not frozen.** BOT60 closed on "the
Village1 frame is FROZEN". Re-run end to end this round, the route is
continuous: `title -> New Game -> save screen(18) -> continue-without-saving ->
Village1 -> intro-start -> misty loaded -> sequence A -> fallback -> enter
training` with a `game-start` camera. BOT60's freeze reading came from a run
that never left the title screen, not from a stalled level.

**The title logo is not stuck to the world.** Frames that show the huge black
"JAK AND DAXTER" logo over village geometry are the title screen's own looping
flyover background. It disappears on New Game. Nothing to fix.

**The MERC shade fix is confirmed visually, not just in a ledger.** Training now
renders Jak *and* Daxter fully shaded: blonde hair, blue tunic, tan skin, brown
boots, on a wooden platform with palms, sandstone cliffs and a warp gate. The
`eichar-lod0` shade ledger reads `rgba-min=(0,0,0) rgba-max=(244,189,160)`, a
real tan range, and the TIE/TFRAG ground stayed correct after the shared
pipeline edit.

**Two instrument traps, both now understood — they wasted rounds.**
1. `MOBILE INPUT` logging stops after 12 events by design
   (`main.cpp` `trace()`, `first_events >= 12`). The absence of an input log
   line is *not* evidence that input is not arriving. Relaunch under
   `SIMCTL_CHILD_OTTSEL_TRACE_MOBILE_INPUT=1` for a full trace.
2. `tr -d '\\000'` aborts with `Illegal byte sequence` on this log, because the
   log carries raw binary. Every `tr | grep` pipeline silently returned nothing.
   Use `LC_ALL=C grep -a` directly on the file.

**The remaining wall is controllability, not visibility.** Jak 1 reads the LEFT
ANALOG STICK for movement. The trigger surface only had D-pad holds
(`ottsel-hold-left` -> `SDLK_LEFT` -> `DpadLeft`), which do not move Jak. So the
"controllable" half of the gate had no instrument able to drive it. This round
adds `ottsel-hold-stick-{left,right,up,down}` -> `A/D/W/S`, the same keys the
shell already derives the analog stick from, and uses them to test movement.

### Honest progress assessment

Verified visual advance this round: the route completes and the player renders
correctly. The leverage again came from reading the shell's own source and from
actually looking at frames, not from more counters. What has *not* advanced:
the sky is still black, the top strip is still wrong, the game's own VU1->GIF
rasteriser still never executes (`vu1-runs=0`, `raster-draws=0`), and no
movement has been demonstrated. No playability claim.

## Measured start state for BOT62

- Disk: `/dev/disk3s3s1 460Gi 12Gi 13Gi 48% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator authorized working below the
  repo's 40 GB rule. Hard stop: any `tmp_pack_*`, or below 5 GiB free. Re-run
  `df -h / | tail -1` before every experiment.
- iPad Pro 11 M4 Simulator `08636791-2675-4675-8335-EF72EF954DCF`, bundle
  `com.ottsel.shell`, `ottsel-fault.log` 0 bytes.
- Data container
  `.../Data/Application/6DD7F5F6-D50D-4998-BD1F-47C5408D516A`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`.
- Never `simctl install` (it recreates the container and destroys game data).
  Install = `cp` the binary in, `codesign --force --sign -`, `codesign --verify
  --deep --strict`. Rebuild: `scripts/build-ios.sh` (~4 min).
- Screenshots: `xcrun simctl io <udid> screenshot f.png`, then
  `sips -r -90 -Z 1000 f.png --out f-r.png`. Every diff input must be the
  rotated PNG. There is no PIL on this box; decode with `sips -s format bmp`
  plus a small pure-Python BMP reader, or use `/tmp/ottsel-diag/*.py`.
- Route to gameplay (verified): launch, wait ~45 s, `ottsel-press-start`, wait
  15 s, `ottsel-press-cross` (NEW GAME), wait 15 s, then exactly **4**
  `ottsel-press-down` at 5 s spacing, then `ottsel-press-cross`. A 5th DOWN
  wraps to index 0 and opens the overwrite dialog.
- Outer HEAD `c66a139`, 16 ahead of `origin/main` (`5209405`). Never
  `git add -A`; stage exact files.

## Q1 (primary) — does held analog-stick input move Jak?

### Falsifiable question

With the freed camera holding on training, does holding
`ottsel-hold-stick-left` (or `-up`) for >= 5 s change Jak's on-screen position
by a large, unambiguous amount, and does releasing it stop him?

### Method

Track Jak by colour, not by eye: his hair is a saturated blonde
(`r>195, g>170, b<130`) and his tunic is saturated blue (`b>110, b-r>45`).
Compute both centroids per frame in the character window and require a
movement far larger than the ~5 px of idle sway measured this round.

### Exit bar

- **Centroid moves >25 px and stops on release.** Movement works; record the
  frame pair and move to Q2. This is the first "controllable" evidence.
- **Centroid static while the stick is provably held.** Instrument first:
  relaunch under `SIMCTL_CHILD_OTTSEL_TRACE_MOBILE_INPUT=1` and confirm the
  trace shows `left=(0,127)` (or `(127,0)`). If the pad state is right and Jak
  still does not move, the defect is in the GOAL target's movement state — check
  `target-state` / the `target` process state line, and whether the game is
  actually in `training` with control handed over rather than still in the
  sequence-A fallback.

## Q2 — why is the sky black when its geometry is correct?

`sky-debug-fill` paints the background magenta in 33.4% of the frame, so
geometry, buffer and encoder are right. `sky-debug-tex` samples `(0,0,0)`.
`SKYRGB` is stable at `1x1=(0.000,0.000,0.000)  32=(0.502,..)  64=(0.078,..)`.

Desktop reference: `sky.vert` sets
`fragment_color = vec4(rgba.x, rgba.y, rgba.z, rgba.a*2)` and `sky.frag` does
`color = fragment_color * T0 * 1.0`; `direct_fs` mirrors this, so the sky is
**vertex-coloured with no colour table** — the same class of bug as MERC.

The full-screen 1x1 fans carry vertex RGB exactly 0 and paint over everything,
so they blacken the sky even if every textured fan is correct.

1. Dump the raw GIF vertex-colour words for the 1x1 and 64x64 sky draws and
   compare against `0x80808080`. The decoded `OTTSEL SKY RAW` `rgba=` field and
   the raw `ottsel-sky-raw-*.bin` / `ottsel-sky-clut-*.bin` dumps in the
   trigger dir are the inputs; they are already on disk for sizes 1/2/3.
2. Decode error -> fix the colour source offset in `metal_gfx.mm`.
   Decode correct -> those layer colours are not what upstream assigns, so find
   what upstream writes there before touching the fragment path.
3. Only then judge the 64x64 texture content (currently grey speckle, not sky).

## Q3 (only if Q1 and Q2 land) — the corrupted top strip

Measure the constant y-band in rotated frames, then check whether the single
`setScissorRect` at `metal_shell.mm:1945` (Direct path) maps the 512x448 game
surface scissor onto the drawable without clipping it to the game viewport.

## Loop rules

- One runtime at a time. Never launch the desktop oracle while the Simulator app
  runs.
- Read the desktop reference renderer and the shell source before hypothesising.
- Capture a sequence, never one frame, and always region-resolve it.
- The app stays signed-native, ROM-safe and non-JIT; `ottsel-fault.log` stays
  0 bytes. Frozen without a proven source mismatch: `set_mobile_tie_camera`
  math, TBP/lookup, strip-restart, the touch frontend, and all iPhone work.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines. Append-only.
- Never `git add -A`. Keep every worktree file below 100 MB. Do not use
  `rm -f`; overwrite with `: > file`.

## Stop conditions

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in the
repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.

