# BOT53 — measure why the title spool never reports `active` and get the route into gameplay

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT52_PROMPT.md` and the BOT52 handoff reasoning. Read `AGENTS.md`, then this
file, then the tail of `docs/STATUS.md`.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and controllable
under real input, a stable and correct camera, nonzero game PCM, clean lifecycle, and
sustained frame pacing. Signed-native and ROM-safe: no ISO or extracted game data in
Git, no RWX / `MAP_JIT` / trampoline code in the product path, users supply their own
data. Gates M0 / I0 / I1 / I2 / I3 / P1 / D1 are defined in
`docs/16-ipados-ios-goal-loop-2026-08-23.md` and are unchanged. Gate N1 is not passed.

A build, a log, a counter, a first frame, a title screen, a menu, or a
Simulator-only success is never playability proof.

## What is now measured and confirmed (this session, live)

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 8.6Gi 58% /`, zero `.git/objects/pack/tmp_pack_*`.
  The operator explicitly authorized working below the repo's 40 GB rule. Hard stop:
  any `tmp_pack_*` or below 5 GiB. Re-run `df -h / | tail -1` before every experiment.
- Device `08636791-2675-4675-8335-EF72EF954DCF` (iPad Pro 11-inch M4, iOS 18.5) is
  booted and the app is live (pid 50034, launched 10:58:46).
- **The screen is genuinely visible and the frame is live.** Captures at 11:20, 11:22,
  11:24 and 11:25 all match wall-clock in the status bar. Content is a correctly
  textured Village1 island (terraced grass, thatch huts, palms, torches, water).
  A 6-shot burst 1.2 s apart produced distinct md5s.
- **The progress menu is fully interactive, not wedged.** Pressing the cross trigger
  moved the menu through `screen=27 -> 18 -> 11 -> 18 -> 11`, logged as
  `OTTSEL PC PROGRESS: accept screen=... index=0 selected=#f`, with the
  `select-option` audio RPC firing. 11:25 shows the save-card screen
  `TO GEYSER ROCK 9/11/2026 07:21`.
- Main-loop update rate is roughly 30-38 iterations/s (91,766 loop iterations over
  ~40 minutes), so this is not a stalled process.

## The defect this round must root-cause

After Start opens the menu, the title logo's spooled animation of `logo-loop` sits at
part 5 forever. Measured on the running log:

```
grep -c 'loader stall on art'            -> 3450
grep -o 'loader stall on art .*' | sort -u -> 'loader stall on art "logo-loop" 5'
grep -c 'OTTSEL SPOOL: abort'            -> 0
grep -c 'OTTSEL ART-LINK'                -> 0
```

The three facts that matter:

1. **The stall text is emitted by the `file-status` wait loop, not the playback loop.**
   In [loader.gc](/Users/chrissotraidis/GitHub/ottsel/out/jak-project/goal_src/jak1/engine/load/loader.gc:692)
   the `while (!= (file-status *art-control* name part) 'active)` loop only guards the
   write of the next part. The 4-second abort conditions
   (`(and (<= sv-72 0) (time-elapsed? sv-40 (seconds 4)))`) live in the *position*
   loop further down and are never reached while this wait spins. **So the BOT52
   "the stream clock never reports stopped, so the timeout can never fire" theory is
   refuted**: the timeout is not the escape hatch for this loop and its absence proves
   nothing.
2. **`file-status` for `("logo-loop", 5)` is not `'active'`, and that value is the whole
   point of B53-A.** Be careful here and do not repeat the earlier mistake: the log
   never prints a buffer's status, because the only printer of it is the
   `debug-print` block at
   [loader.gc:501](/Users/chrissotraidis/GitHub/ottsel/out/jak-project/goal_src/jak1/engine/load/loader.gc:501)
   and it is gated on `*display-art-control*`, which
   [main-h.gc:157](/Users/chrissotraidis/GitHub/ottsel/out/jak-project/goal_src/jak1/engine/main-h.gc:157)
   defines as `#f`. So `'pending`, `'loading`, `'loaded`, `'locked`, `'error` and
   `#f` are all still live hypotheses. Measure it, do not infer it.
3. **The buffer never runs `link-file`, which is the only path that sets `'active'`.**
   Per [loader.gc:156](/Users/chrissotraidis/GitHub/ottsel/out/jak-project/goal_src/jak1/engine/load/loader.gc:156)
   a buffer reports its own `status`, so whatever the value is, it is the buffer's
   real state and not a reporting artifact.
   That runs in the `'locked'` branch and requires
   `(and (not (-> this locked?)) (handle->process (-> this load-file-owner)))`
   ([loader.gc:387](/Users/chrissotraidis/GitHub/ottsel/out/jak-project/goal_src/jak1/engine/load/loader.gc:387)).
   `OTTSEL ART-LINK` is 0 across the whole run, and that probe sits inside
   `link-art!`, so `link-file` provably never executes.

Meanwhile `level-update` at
[level.gc:1194](/Users/chrissotraidis/GitHub/ottsel/out/jak-project/goal_src/jak1/engine/level/level.gc:1194)
does call `(update *art-control* #t)` and `(clear-rec *art-control*)` every frame, driven
from `main.gc:554`. So the updater is not missing; it is running and still not
advancing this buffer.

The remaining candidates, in order:

- (a) the `'loaded'` branch takes the `link` failure path and the failure is silently
  swallowed for part 5 (the `ERROR: art-group ... is not a valid file` message would
  have to be suppressed);
- (b) `load-file-owner` is a dead handle because the requesting process is the title
  logo, so `(handle->process ...)` returns `#f` and `'locked' -> 'active'` can never run;
- (c) the buffer keeps being re-seeded back to `'loaded'` because `spool-push` at
  `-20.0` re-registers the rec every iteration of the wait loop and something in
  `update` resets it.

## Round plan (cheapest falsifier first, no product change until one is proven)

- **B53-A (do first).** Add a bounded probe that dumps, once per second, both buffers'
  `load-file` / `load-file-part` / `pending-load-file` / `pending-load-file-part` /
  `status` / `locked?` / `index`, plus whether `(handle->process load-file-owner)` is
  live, and the `rec` contents. Emit the same dump during a *successful* part 0-4
  load as the known-good reference, then again after Start. A differential against
  the working path in the same process is the decisive measurement.
- **B53-B.** Only after A, decide between (a)/(b)/(c). If the cause is the dangling
  owner, the fix belongs in the spool lifecycle, not in the renderer.
- **B53-C.** Re-verify `eichar` once gameplay is genuinely reached. The frozen
  `eichar=660` is title-phase data and must not be treated as an independent defect
  until the route reaches a playable level.
- **B53-D (separate, queued).** A malformed frame was captured at 11:24: a giant
  yellow wedge with an oversized sprite and a black wedge on the right. It is
  intermittent. Record it as an I1-class frame-integrity bug; do not fold it into
  the loader work.
- **B53-E (separate, queued).** Menu text still alternates between drawn and absent
  across consecutive frames (md5 alternation in a burst at the same moment).
  BOT49 fixed the erase path, so this is a different retention bug.

## Operating contract

- Never claim playability from a log, a counter, a menu, a HUD line, or a single frame.
  The exit bar for N1 is fresh, inspected, animated gameplay with real input.
- Frozen without a proven source mismatch: `set_mobile_tie_camera` camera math,
  TBP/lookup, strip-restart, the touch frontend, all iPhone work.
- Input contract: file triggers polled every 30 main-loop iterations at
  `src/shell/main.cpp:993`, armed with `: > "$W/ottsel-press-<name>"`:
  `ottsel-press-start` (RETURN), `ottsel-press-cross` (SPACE), `ottsel-press-down`,
  `ottsel-press-left`, `ottsel-bg-village1`. There is no `up` and no `circle`
  trigger; CROSS/SPACE is the only confirm trigger.
- Build and deploy: `bash /tmp/ottsel_relink5.sh` (~55 s), never `relink3.sh` or
  `relink4.sh` (they silently skip `shell_main.o`). Deploy is
  `terminate -> install -> launch`, then **re-resolve the data container** because the
  UUID changes on every install:
  `xcrun simctl get_app_container $UDID com.ottsel.shell data`.
- GOAL source is edited under `out/jak-project/goal_src/...` and C++ under
  `out/jak-project/game/sce/...`; both are gitignored, so durable fixes go in
  `patches/*.patch` per `patches/README.md`.
- The runtime log is NUL-padded. Read it as
  `export LC_ALL=C; tr -d '\000' < "$LOG" | grep -a ...`. `rm` is blocked by policy;
  the app unlinks its own press-trigger files.
- Evidence caps from `AGENTS.md` rule 3: one concise document per proven gate, 60
  lines maximum, at most eight appended `STATUS` lines, append-only.
- `OTTSEL STREAM CLOCK` logging is capped at exactly 16 events, which makes the
  stream-clock stream look like it stops early. Treat that cap as a diagnostic bug.

## Exit bars for this round

1. A differential buffer dump that names the exact condition blocking
   `'loaded' -> 'locked' -> 'active'` for `logo-loop` part 5 after Start.
2. After the fix, zero `loader stall on art` lines following a Start press.
3. The route reaches a playable level with `eichar` climbing, confirmed by a fresh
   inspected frame burst, not by counters alone.
