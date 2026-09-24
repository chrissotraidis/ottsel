# BOT42 — Route first: leave the intro, deliver input, then make Jak visible

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. It
supersedes `docs/BOT41_PROMPT.md` as the active queue and keeps the same gate
contract (I2, I3, P1, D1). Read `AGENTS.md` first, then this file, then
`docs/BOT41_PROMPT.md`, `docs/BOT40_PROMPT.md`, `docs/BOT39_PROMPT.md` for the
still-valid defect inventory, `docs/STATUS.md` (tail), and `docs/evidence/`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with **Jak visible and
controllable under real input**, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO or
extracted game data in Git, no RWX/`MAP_JIT`/trampoline code in the product
path, users supply their own legal data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Why BOT42 exists — the BOT41 L1 premise is refuted

BOT41 made the Village1 Eichar `clip-z = (-1.0543, -1.0405)` the primary
question. Measurement on 2026-09-11 (iPad Pro 11-inch M4, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, `com.ottsel.shell`) refutes that
framing and moves the blocking lane:

1. **The clip ledger is a bounded transition probe, not a per-frame trace.**
   `capture_mobile_camera` gates it on
   `level == "village1" && g_mobile_eichar_village_clip_logs < 32`
   (`src/shell/metal_gfx.mm:1482`). It fires only during the ~6 s
   title->Village1 window, then stops forever. A frozen ledger is the sample
   cap, not a frozen camera.
2. **Those samples used the title perspective.** Applying the title persp
   (`p00=-0.40012324, p22=-8184.262, p32=1.676095e7, p23=-3.5552202e-05,
   hvdf2=8380365.5, fog0=-0.036405455`) to the skinned eichar bounds
   reproduces the recorded x/y/z analytically. Benign transition artifact.
3. **The real fact: the player mesh stops being submitted.** The
   `OTTSEL MERC NAMES` cumulative histogram (re-touchable trigger
   `ottsel-trace-merc-names`) reads `eichar-lod0 packets=313` at `[54:36]`
   and **still 313** at `[54:42]`, while `logo-english-lod0` climbs
   484 -> 532 and `submits` 4862 -> 4910. Over a ~10 min launch the player
   mesh is submitted 313 times, entirely inside the transition window. The
   renderer is not dropping Jak; there is no player mesh to draw.
4. **The mercs that are submitted are the intro/title set.**
   `logo-english / logo-black / logo-volumes-english / ndi / ndi-cam /
   ndi-volumes` all resolve to level `title` (`levels/title/title-obs.gc`,
   `dgos/tit.gd`), alongside `eichar-lod0` and `sidekick-lod0` from
   `GAME`. The app is still running the intro/attract sequence.
5. **The app has never left the intro.** `OTTSEL STR: loaded LOLOOP.STR
   chunk=N` streams an endless 17-chunk cycle every ~65 s. `LOLOOP` is the
   intro-camera logo loop (`out/jak-project/goal_src/jak1/game.gp:381`, group
   `;; intro camera` with `NDINTRO/LOINTRO/LOI2`).
6. **No host input has ever reached the shell.** `OTTSEL MOBILE INPUT` fired
   exactly once in a 10 min run, `source=lifecycle`. Synthesized Simulator
   clicks and `System Events` keystrokes produced no SDL events.
7. **The hermetic file trigger does work.** `ottsel-press-start` is consumed
   by the frame loop (`src/shell/main.cpp:980-1040`), so the route can be
   driven headlessly without a working host input path.
8. **Diagnostics are unbounded.** `ottsel-runtime.log` reached 545 MB in
   ~1 h, growing ~1.2 MB/s (18 MB per 15 s), with no rotation and no
   default-off guard. Per-frame and per-primitive `lg::info` dumps dominate.

Village1 itself renders well (textured grass, cliffs, waterfall, huts, roof
tiles, palms, barrels). Scene correctness is not the blocker. **Route,
input, and observability are.**

## Platform order (unchanged)

1. macOS stays frozen as the accepted behavioral/visual reference.
2. The active queue is the iPad Simulator (Gate I1).
3. iPhone parity (P1) and physical-device readiness (D1) stay behind a coherent
   iPad route.

Frozen until Gate C passes: camera matrix math (`set_mobile_tie_camera`),
TBP/lookup, strip-restart, the touch frontend, and all iPhone work. If the
camera matrix turns out to be the fault, write the finding instead of remapping
it.

## Disk precondition — user override in force

AGENTS.md rule 2 sets a 40 GB floor. The user explicitly overrode it and
re-stated the override on 2026-09-11 ("theres space to work, just keep
working"). BOT42 runs under that authorization. Measured at BOT42 start:
`df -h /` Avail **15Gi**, `tmp_pack_*` **0**. Still run `df -h / | tail -1`
and count `.git/objects/pack/tmp_pack_*` before every build; keep every
worktree file below 100 MB; never `git add -A`. The override covers working,
not cleanup — no deletion of user files.

## AGENTS.md rule 3 — both preconditions remain satisfied

The `presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT
were both root-caused and covered (`docs/STATUS.md:2879`,
`docs/STATUS.md:1782`, guard in `link_and_exec` plus the GOAL
`link-begin` wrapper, focused suite 21/21, `docs/STATUS.md:2892`). BOT42 may
open a new round; re-derive if either reappears in a fresh fault log.

## Gate A — loop health and observability (blocking, new)

Everything downstream needs a trustworthy frame-rate number and a log that
does not grow without bound.

- Make per-frame and per-primitive diagnostics **default-off** and
  trigger-file gated, matching the existing `$W/ottsel-trace-*` convention.
- Bound the runtime log (rotate, or cap per-launch bytes) so a long run cannot
  fill the device.
- Land one cheap, bounded frame-rate and frame-time probe so every later
  PASS/FAIL cites a measured number instead of an inferred one.

Exit: a measured sustained frame rate, `ottsel-fault.log` at 0 bytes, and log
growth bounded by policy rather than by runtime length.

## Gate B — input delivery (blocking, new)

- Prove the hermetic `ottsel-press-start` / `ottsel-press-cross` triggers
  change observable game state, twice in a row.
- Re-attempt host input (Simulator keyboard and pointer) and record whether SDL
  receives events at all, using the `OTTSEL MOBILE INPUT` trace.

Exit: one press produces a state change in the game, reproduced twice.

## Gate C — route (primary, replaces BOT41 L1)

One falsifiable question: **why does `eichar-lod0` stop being submitted after
the title->Village1 transition, and can the app reach gameplay?**

Note that `sidekick-lod0` also stops, so the cause is more likely a
start-level / NDI path leaving actors unloaded than a per-model packet scan
limit. Rank the candidates: the `kOttselMobilePcPortScanBudget` bucket scan
truncating (`src/shell/metal_gfx.mm:~7180`), the texture-upload swallow
(`handle_mobile_pc_port_texture_upload` returning true), actor naming per
level, and the intro never completing.

Drive the route with the file triggers, not host input. Then measure.

Exit: a fresh inspected Simulator frame with its SHA-256 plus input showing Jak
visible and moving.

## Gate D — sky compositing (parallel, cosmetic)

Unchanged from BOT41 L2 except that the `dest`-aliasing item is closed:
`OTTSEL SKY REGISTRY` reports `meta-same-dest=1` for all three sky tbps, so
the sky dests do not alias. Pursue **address provenance** (which upload last
wrote that VRAM range, with which tbp). Never synthesise a sky texture,
gradient, or placeholder.

## Gates I2, I3, P1, D1

Unchanged from `docs/BOT41_PROMPT.md`. I2 opens only after Gate C passes. The
bright flat rectangles are the PS2 touch overlay
(`src/shell/main.cpp:626-632`), which belongs to I3, not to the sky.

## Operating loop

For each experiment: state the current evidence, ask one falsifiable question,
make the smallest change, add the before-failing regression, run one visible
route, inspect the screen, and record PASS or OPEN honestly. Stop at the first
failed gate instead of switching platforms as a workaround. Three repeated runs
against the same root blocker require a dated stop report, then an independent
gate.

Housekeeping owed before any product commit: the four modified `src/shell/*`
files carry ~1268 insertions of diagnostic scaffolding alongside the landed
I1.1f registry fix. Separate the product change from the probes, commit with
explicit paths, and never `git add -A`. Do not push without asking.

## Evidence budget (AGENTS.md rule 3)

One <=60-line doc per proven gate, at most eight appended STATUS lines. Replace
the stale top board in `docs/STATUS.md` with current truth instead of growing
that file further.
