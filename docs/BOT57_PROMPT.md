# BOT57 — make the game's own VU1 path run, or prove it cannot

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT56_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`.

## Zoom-out — measured live at 13:30, not carried over

Screen capture works. A fresh `simctl io screenshot` at 13:30 shows the same
frame shape as the 13:26 capture: a terrain band across the top third with palms
and a rock wall, the lower two thirds solid black, an oversized tree trunk
filling the right quarter, and the Village1 hut/shield at the right edge. The app
is pid 60757, ~55 min old, `ottsel-fault.log` 0 bytes, runtime log 37 MB.

Live counters, last `SUBMITSTAT` at `[30:31]`: `chain=27720` (~9 chains/s),
`cam-entries=186944`, `cam-level-rejects=0`, `scene-level='training'`,
`tie-ready=true`, `tfrag-ready=true`, `merc-submits=680544`, `eichar=13168`,
`eichar-attempts=13168`, `raster-draws=0`; `VU1STAT` reports
`vu1-runs=0 capped=0 xgkicks=0 last-pc=0 nonzero-gif=0 gif-words=0 draws=0`.

### Two corrections that change the priority order

**1. `eichar-attempts=13168`, not 4.** BOT56's Q2 premise — "the game never
submits its player" — is refuted. In `training` the game submits `eichar-lod0`
continuously: 13,168 by `[30:31]`, against 4 when BOT56 was written. The game
is past submission and into skinning. Close BOT56 Q2 as refuted; do not spend
another round proving the player is submitted.

**2. `vu1-runs=0` is the shell's own switch, not a game failure.** This is the
round's key reframing. `src/shell/metal_gfx.mm:6711`:

```cpp
const bool run_cpu_vu_diagnostics =
    !g_metal || std::getenv("OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS") != nullptr;
```

Every call into `ottsel_handle_vif` — the only path that increments
`g_vu1_runs_period` and drives the VU interpreter — sits behind that flag
(`metal_gfx.mm:7223-7224`, `7255-7256`). In the Simulator product path
`g_metal` is true and the env var is unset, so the VIF/VU path is never
entered. Confirmed live at `[35:07]`: `OTTSEL VU1: cpu-diagnostic-path=disabled`,
with zero `OTTSEL VU1: run#` lines in the whole 37 MB log. The DMA chain itself
is healthy — the same loop captures the camera packet (`cam-entries=186944`)
and walks the buckets.

BOT56's line "the game's own GS/VU1 rasterizer has never executed once" is true
but was misread as a symptom. It is a deliberate BOT21e decision: a 50k
instruction cap keeps the microcode from eating the game thread on an empty frag
list. The consequence is the real story. Every visible pixel is produced by
`src/shell/metal_gfx.mm` + `metal_shell.mm`, a parallel re-implementation that
imports data structures and re-derives every GS/VU1 semantic itself. That is the
structural reason the remaining defects are spread across every semantic and
arrive one at a time.

### Honest verdict on progress

Real: the engine loads its own FR3 data, the live camera packet is captured with
zero level rejects, TFRAG/TIE/MERC/Sprite meshes are built and drawn, the scene
is `training` with the player submitted, and the frame advances at ~9 chains/s.
Not real: the presented frame is visibly wrong (the lower two thirds are the
neutral base fill), and `raster-draws=0`. Twelve rounds have produced ~50
trigger probes and 8,800 lines of parallel renderer while the two decisive
numbers stayed zero *by construction*. This round challenges the method, not the
defect count.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone
parity, then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO
or extracted game data in Git, no RWX / `MAP_JIT` / trampoline code in the
product path, users supply their own data. Gate ownership for this round is
**Gate I1** ("stable and fluid scene parity") and **Gate I2** (audio and
lifecycle) from `docs/16-ipados-ios-goal-loop-2026-08-23.md`, against the macOS
reference of `docs/15-macos-to-mobile-goal-loop.md`. Gates M0 / I0 / I3 / P1 /
D1 are unchanged. Gate N1 is not passed.

A build, a log, a counter, a first frame, a title screen, a menu, a
Simulator-only success, or a route driven by hand is never playability proof.

## Measured start state for BOT57

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 18Gi 40% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator has authorized working below the
  repo's 40 GB rule ("theres space to work, just keep working"). Hard stop: any
  `tmp_pack_*`, or below 5 GiB free. Re-run `df -h / | tail -1` before every
  experiment.
- App pid 60757, bundle `com.ottsel.shell`, UDID
  `08636791-2675-4675-8335-EF72EF954DCF`, `ottsel-fault.log` 0 bytes.
- Data container
  `.../Data/Application/D2887AF9-AA7B-472F-9926-226EDD6A7685`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`.
  Re-resolve with `xcrun simctl get_app_container` after every `simctl install`;
  a stale path silently swallows every injected press.
- Input contract (`src/shell/main.cpp:983-1025`, polled every 30 frames, file
  unlinked after firing, writable dir first then bundle):
  `ottsel-press-start` -> RETURN, `ottsel-press-cross` -> SPACE,
  `ottsel-press-left` -> LEFT, `ottsel-press-down` -> DOWN,
  `ottsel-bg-village1` -> `(bg 'village1)`.
- Outer HEAD `c66a139`, 16 ahead of origin/main; inner `out/jak-project` pin
  `641fb572e876750d8618434d9f7c1a531b43b366`.
- Working tree is dirty and must be preserved: `M docs/STATUS.md`,
  `M src/shell/metal_gfx.mm` (diagnostic probes),
  `M src/shell/mobile_generic_policy.h` (BOT52 `bucket_id < 70u` PC_PORT
  walker). Never `git add -A`; stage exact files.
- Desktop oracle exists and ran today: `out/jak-project/build/h1/game/gk`
  (Mach-O arm64, 5,248,800 bytes) and `out/Ottsel.app/Contents/MacOS/Ottsel`
  (launcher that execs it). `/tmp/ottsel-wrapper-current.log` shows a real
  desktop session from 05:28 today. **Do not launch it while the Simulator app
  is running** (`docs/15` rule 1: one runtime at a time).

## Q1 (primary) — is the game's own VIF -> VU1 -> GIF path viable for the current scene?

This is the cheapest decisive experiment available and no recent round has run
it against the current build. It answers the architectural question B56-C
deferred: keep extending the parallel renderer, or route through the game's own
path.

### Falsifiable question

With `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1` set for one bounded run, in
`scene-level='training'`, does `VU1STAT` report `vu1-runs > 0` with
`nonzero-gif > 0` and `gif-words > 0`, and does the decoded GIF output carry a
plausible vertex count for the submitted TFRAG/TIE/MERC buckets — or does it
report `capped > 0` / zero GIF words (i.e. the frag list it is handed is empty
or malformed)?

### Smallest change

No source change, no rebuild. One env var on launch:
`SIMCTL_CHILD_OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1 xcrun simctl launch ...`.

### Exact route

1. `df -h / | tail -1` (gate).
2. `xcrun simctl terminate <udid> com.ottsel.shell`.
3. `SIMCTL_CHILD_OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1 xcrun simctl launch <udid>
   com.ottsel.shell`; re-resolve the container path.
4. Let it reach a live scene (~40 s), then inject `ottsel-press-cross` to get
   past the title if needed, and read `VU1STAT` plus the first `OTTSEL VU1:
   run#` lines and `OTTSEL VU1DRAW` result lines.
5. Capture one screenshot; kill the run; relaunch **without** the env var to
   restore the known product path.

### Exit bar — a binary fork, both branches actionable

- **`vu1-runs > 0` and `gif-words > 0` with a plausible vertex count.** The
  game's own path is viable. Record the numbers in one evidence doc and make the
  next round about the bucket/frag-list handoff into it, which is the route
  `docs/11-graphics-audio-input-deep-dive.md` §1 prescribes.
- **`cap* > 0` or `gif-words = 0`.** The tail is empty. The defect is upstream
  of the interpreter — the SPR->VIF1 handoff or the frag-list base — and that
  becomes the primary investigation, with the parallel renderer explicitly
  provisional until it is fixed.

### Q1 result — answered 2026-09-11 (branch A). Do not re-run it.

`OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1` gives
`cpu-diagnostic-path=enabled` and, over three 90-chain periods,
`vu1-runs` 3485/10206/8538 with `gif-words` 433564/496580/190744,
`xgkicks` up to 124145, and `last-pc` reaching 1694 — the
strip-output phase. The interpreter is fine. The early `run#1..#6` lines
are `mscal imm=0x0 top=0x0 pc=79 gif_out=0`, the zero-entry TFRAG setup
pass with an empty frag list, which spins to the cap by design.

The zoom-out line "the game's own GS/VU1 rasterizer has never executed once"
should therefore read: it executes when the gate is lifted, and its output is
not wired to the renderer. That is a wiring gap, not an interpreter defect.

**Refutation to carry:** lifting the gate does **not** change the presented
frame. Matched boot-window black fraction, product 23.2/19.2/42.3/42.3% vs
diagnostic 55.2/13.7/24.6/24.2%. The ranges overlap; an earlier unmatched set
that looked like a fix was camera position. The black lower two thirds (B56-F)
is untouched by this switch.

Full evidence: `docs/evidence/I1/BOT57-q1-vu1-path-viable-unwired.md`.

## Q2 — make the ledgers trustworthy before trusting them again

Do this before any further geometry claim, because two current ledgers cannot
support the conclusions drawn from them.

- The draw-probe at `metal_shell.mm:1236-1276` reads
  `vertex_data + first_index*8`, but `sizeof(tfrag3::PreloadedVertex)` is
  8 floats + 4 u8 + 2 floats + u32 + u16, so the assumed stride is wrong and the
  probe is reading misaligned bytes.
- The clip ledger's `visible` test checks only `clip_x/y/z in [-1,1]` and
  ignores the sign of `w` and the Metal remap `z=(z+w)*0.5`
  (`metal_shell.mm:158-159`). As written, `visible=0` is uninformative.
- `append_merc_mesh` merges models, so `draws.front().index_offset` need not
  index `eichar-lod0`.

Falsifiable question: after fixing the stride and adding the `w` sign and the
remap to the visibility test, does the player's projected quad actually land
inside the drawable for the live training pose?

## New merc finding carried into this round (do not regress it)

Armed `ottsel-trace-merc-clip-ledger` on a live `training` frame shows the
skinned vertex `z` near `-30,000..-42,500` while the bone translation is near
`+37,000` — a sign disagreement between the skinned vertex and the bone
translation. For the logged sample `p=(2381.16, 9077.38, -36451.09)` the clip
ledger reads `rawclipz=-1.0562`; the Metal remap gives `-0.1308`. The general
form reduces to `clip_z = -1 - cz/hvdf_z` for negative `cz`, so any vertex with
`cz > 0` lands outside the near plane.

**Prior sign-flip claim is refuted — do not run a naive merc sign flip.** The
oracle's own `merc2.vert` negates the bone product exactly as the shell's
`px -= tx * weight` (`metal_gfx.mm:1740-1742`) does, and negating `p` leaves
clip-z at `-0.0235` because the `w` denominator flips too. The open question is
the **pre-negation sign of the skeleton**, and it must be measured against the
oracle rather than asserted. Predict the expected `clip_z` before any rebuild;
only rebuild if the prediction is falsifiable and the change is small.

## Carried defects

- **B56-A, the two named blockers.** `presentRGBA:` / `_MTLCommandEncoder`
  crash and the Jak 1 linker SIGABRT each need a root cause and a covering
  regression before a new R-round opens.
- **B56-B, durability.** The B53 `loader.gc` STALL/RECOVER patch lives only in
  the gitignored inner tree. Land it:
  `git -C out/jak-project diff 641fb572e876750d8618434d9f7c1a531b43b366 >
  ../patches/h3-jak1-host-boot.patch`, then `git apply --check` in a fresh
  worktree at the pin. Never `git add -A`.
- **B56-C, architecture.** Now escalated from "record" to Q1. The parallel
  renderer is registered at `metal_gfx.mm:8747` with
  `module.pipeline = GfxPipeline::OpenGL; // no Metal pipeline enum`.
- **B56-D, yellow quad.** Isolated to the 2D sprite/HUD path by A/B on
  `ottsel-trace-metal-scene-no-sprite` (baseline 4 of 23 captures yellow;
  armed, 0 of 30). The sprite records carry positions near 2.9e7 against
  `hvdf ~2048`, which reads as a wrong stride or DMA transfer. The
  `std::clamp` scale path is **refuted**; do not "fix" the clamp.
- **B56-E, `suspend called without enough stack` x22** on `logo`
  (`KERNEL_DEBUG` only, does not abort). Stack-depth smell; promote only if Q2
  implicates it.
- **B56-F, black sky — now the visually dominant defect.** The lower two thirds
  of the presented frame are the neutral base fill. Unchanged.

## Instruments (verified)

- Screenshot: `xcrun simctl io <udid> screenshot f.png`, then
  `sips -r -90 f.png --out r.png` and
  `sips -Z 1000 -s format jpeg r.png --out r.jpg`. Only under `/tmp/ottsel-video/`.
- Log: `LC_ALL=C tr -d '\000' < "$W/ottsel-runtime.log" > /tmp/ottsel.log` — plain
  `tr` fails with `Illegal byte sequence` without `LC_ALL=C`. Read deltas by byte
  offset: `OFF=$(wc -c < "$W/ottsel-runtime.log")`, then
  `tail -c +$((OFF+1)) ... | rg '<pattern>'` in a second call.
- Trigger files are polled every 30 frames and unlinked on fire (`main.cpp:983-1025`).
- Relink: `bash /tmp/ottsel_relink5.sh` (~55 s; **never** `relink3/4.sh`).
  It honors the exit bar: `codesign --verify --deep --strict "$APP"`.
- GOAL build: `cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c
  '(load_project "goal_src/jak1/game.gp") (mi)'` — `--isa arm64` is mandatory;
  after GOAL changes remove stale objects and regenerate affected DGOs.
- Liveness: per-pixel diff via `/tmp/pngdiff.py`. Never frame SHA-256 (it moves
  with the status-bar clock).
- Recording, only per `AGENTS.md` rule 1: `recordVideo --codec=h264`, bounded
  sleep <= 30 s, `kill -INT`, `ls -lh`,
  `lsof -c SimRender | grep -E '\.mov|\.mp4'`. Never plain `kill`, never
  `set -e` around a recorder.
- Do not use `rm -f` (exec rejects it); overwrite with `: > file`. Never
  `rg -rn`.

## Hard rules

Gate N1 is unproven. Never claim playability from a build, log, counter, title
screen, menu, first frame, or a hand-driven route. Frozen without a proven source
mismatch: `set_mobile_tie_camera` math, TBP/lookup, strip-restart, the touch
frontend, and all iPhone work. Evidence is capped at one concise document per
proven gate (60 lines maximum) and at most eight appended `STATUS.md` lines.
Append-only. Keep every worktree file below 100 MB. Do not over-engineer
(`AGENTS.md`).

## Order of work

1. **Q1 answered 2026-09-11: branch A, and the flag does not change the frame.**
   The path executes but is unwired. New top item: wire `g_vu.gif_out` into
   the mobile renderer behind a real product switch, or prove the bucket /
   frag-list handoff is the only missing link.
2. Q2 — fix the stride and the `w`/remap visibility test so the merc and draw
   ledgers can be trusted.
3. B56-B — land the loader patch durability fix while the tree is quiet.
4. B56-F — the black lower two thirds, now the dominant visible defect.
5. B56-D — sprite parser stride against the DMA transfer.
6. Only then the renderer family: `eichar` skinned sign, then B56-A's two
   root causes.
