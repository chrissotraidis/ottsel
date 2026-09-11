# BOT38 — iPad Simulator renderer completion to honest playability

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. It
supersedes `docs/BOT37_PROMPT.md` and `docs/BOT36_PROMPT.md` as the active
queue while keeping their gate contract (I0-I3, P1, D1).

Read in this order before changing renderer code: `AGENTS.md`, then
`docs/reports/2026-09-06-ipad-malformed-scene-audit.md` (newest read-only
audit), `docs/reports/2026-09-03-ipad-village1-render-audit.md` (source-rooted
defect list), `docs/13-current-state.md`, and `docs/STATUS.md`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent `title -> New Game ->
Village1 -> Training` route with Jak visible and controllable under real
input, a stable camera, nonzero game PCM, clean lifecycle, and sustained frame
pacing. Keep the app signed-native and ROM-safe: no ISO or extracted game data
in Git, no RWX/`MAP_JIT`/trampoline code in the product path, and users supply
their own legal game data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Platform order — resolved

`docs/STATUS.md` predates the resolution and still says mobile is paused;
BOT36 and `docs/16-ipados-ios-goal-loop-2026-08-23.md` made iPadOS active.
This prompt resolves the split:

1. macOS is the accepted behavioral/visual reference and is frozen. Its two
   remaining clauses (human audible acceptance, physical-controller soak) are
   user-owned, not agent-actionable. Reopen it only for a proven shared
   regression.
2. The active engineering queue is the iPad Simulator renderer.
3. iPhone parity and physical-device readiness stay behind a coherent iPad
   route.

Frozen until I1 closes: camera matrix math (`set_mobile_tie_camera`),
TBP/lookup, strip-restart, the touch frontend, and all iPhone work.

## Landed since BOT37 — verified in this checkout, do not re-litigate

- Depth parity: `src/shell/metal_shell.mm` clears depth to 0 and uses
  `MTLCompareFunctionGreaterEqual` with the `kOttselMobileDepth*` settings,
  matching upstream `glClearDepth(0)` + `GL_GEQUAL`.
- Level ownership is packet-level: the owner log moves `title` -> `village1`;
  the earlier misty-latch is falsified.
- Merc raw perspective: `metal_shell.mm` routes Merc meshes through
  `projection_mode != 0` (`merc_perspective`, not `pc_camera`); the giant
  panels are gone.
- Audio is no longer purely structural: `game/overlord/jak1/srpc.cpp` is
  compiled into the iOS app (`scripts/build-ios.sh:204-205`), `RPC_Player` is
  registered (`out/jak-project/game/overlord/jak1/srpc.cpp:40,142`), and mixed
  PLAYER windows reach `pcm-peak` logging
  (`out/jak-project/game/sound/sndshim.cpp:68`). BOT37's "srpc.cpp is not in
  build-ios.sh" note is wrong; correct it wherever it is repeated.
- CPU/VU diagnostics are gated behind `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS`; the
  container stayed flat (~1.6 GB) across the BOT36 runs.

## Preconditions — run before every build or run

1. `df -h / | tail -1`; count `.git/objects/pack/tmp_pack_*`. If Avail is
   below 40 GB or any temp pack exists, report exact paths and sizes and stop.
   **2026-09-10 status: FAILS.** Avail 20Gi on `/`, 0 temp packs. No build,
   boot, or recording may run until a user-approved, named cleanup restores
   the floor.
2. Boot exactly one iPad Simulator, launch exactly one runtime, and close the
   macOS `gk` process first. Use `simctl launch` or the Simulator host, never
   the Simulator binary directly.
3. Validate the user data pack with `scripts/validate-user-data-pack.sh`; keep
   all logs, recordings, and dumps under `/tmp`.
4. Recordings use only the AGENTS.md rule-1 bounded SIGINT form under
   `/tmp/ottsel-video/`.

## Gate I0 — visible iPad bootstrap

Build, ad-hoc sign, install, and visibly launch Ottsel on the one booted iPad
Pro Simulator. Retain the app hash, device UDID, raw logs, and a fresh
screenshot inspected directly. Stretched, duplicated, missing, rotated, or
debug-only composition fails this gate even while the process lives.

## Gate I1 — scene correctness (ACTIVE)

Fix one falsifiable native family at a time against the macOS reference. Black
regions are structural, not one bug: sky, ocean, TIE TRANS/WATER, envmap,
shrub, and Direct/HUD product paths are missing or trigger-gated. Work order:

### I1.1 — Sky: the SKY_DRAW quad plus the missing sky-blend texture

Bucket identities are verified against upstream: `jak1::BucketId::SKY_DRAW = 3`
(`ref/open-goal-jak-project/repo/game/graphics/opengl_renderer/buckets.h:10`),
rendered by `SkyRenderer` (`OpenGLRenderer.cpp:671-672`), and
`TFRAG_TRANS0_AND_SKY_BLEND_LEVEL0 = 32`, rendered by `SkyBlendHandler`
(`OpenGLRenderer.cpp:759`). There are two independent structural gaps, not one:

1. `SKY_DRAW` (bucket 3) reaches `submit_mobile_native_sky_bucket`
   (`src/shell/metal_gfx.mm:3260`) with 11 transfers (6 DIRECT, 24 GIF tags)
   but logs `prim-starts=0 vertex-words=0 candidates=0 submitted=0`, so no quad
   is encoded. Upstream's contract for this bucket is exact and comparable
   (`SkyRenderer.cpp:133-200`): a leading NEXT with two NOPs, a 64-byte
   (`16*4`) setup GIF packet, then when `current_tag().qwc == 5` a draw-setup
   packet followed by CNT/DIRECT GIF packets, closing CALL/RET with
   `current_tag_offset() == next_bucket`. An 11-transfer walk carrying 24 tags
   is consistent with that `qwc == 5` branch, so the walk targets the right
   bucket; the defect is downstream of bucket selection.
2. `TFRAG_TRANS0_AND_SKY_BLEND_LEVEL0` (bucket 32) has **no handling anywhere
   in `src/`**: `grep -rn -i 'sky_blend' src/` returns nothing. That bucket
   generates the sky texture via `SkyBlendHandler`, and `sky.frag` samples it
   as `tex_T0`. `sky.vert` is a pure screen-space quad
   (`gl_Position = vec4((x-0.5)*16, -(y-0.5)*32, z*2-1, 1)`), so the texture
   carries the entire content; a correct quad still renders nothing without
   it. The same bucket also owns the TFRAG TRANS trees (its `qwc != 8` branch),
   which matches the missing transparent and water regions.

Ordering therefore matters: implement the `SKY_BLEND` texture contract before
chasing the `SKY_DRAW` quad.

Evidence so far: `docs/evidence/I1/i1-sky-native-capture-boundary-2026-09-04.md`,
`i1-native-sky-batch-2026-09-04.md`, `i1-sky-direct-ir-2026-09-03.md`.

Falsifiable question: do the `SKY_DRAW` GIF tags carry a PRIM register write at
all, or does the quad arrive in a form the native walk skips? Note that a
screen-space sky quad legitimately needs no per-vertex texture lookup, so the
texture-required drop inside `capture_native_primitive` (`metal_gfx.mm:2561`,
`if (!texture) return;`) is itself a candidate defect for this specific bucket.
`on_prim_start` (`metal_gfx.mm:2707`) is the only place `native_prim_starts`
increments.

Probe: extend the `OTTSEL SKY PRODUCT` log at `metal_gfx.mm:3299` with the
already-counted `g_mobile_direct_trace.packed_tags`, `reglist_tags`, and
`image_tags` (declared `metal_gfx.mm:138-140`, incremented at `2940-2949`).
The counter set is the whole experiment: no renderer behavior changes.

Exit: either the tag mix proves Sky has no PRIM (then re-anchor the search on
the Direct/texture-copy contract) or a PRIM appears and the walk can be fixed.
Either way `submitted>0` with a fresh inspected frame whose black regions gain
ordered Sky geometry and no TFRAG/TIE/Merc regression. Do not add a fake sky
texture, gradient, or placeholder fill.

### I1.2 — TFRAG/TIE vertex contracts

The native path uses one `tie_vs` for both families, but upstream splits them:
`tfrag3.vert` has no Q/HVDF block, while the static-TIE shaders
(`etie_base.vert`, `etie.vert`) apply `cam_no_persp` + `persp0`/`persp1` and
then the 2048/8388608/256/128 block. Source-provable native defect:
`metal_shell.mm:135` gates that block on `camera_sign < 0`, but
`metal_shell.mm:1049` only sets `-1` under the one-shot
`sceneTieReferenceProjectionProbe`, so the shipping TIE path never applies the
block, and the probe itself feeds `pc_camera` instead of
`cam_no_persp`/`persp0`/`persp1`. Falsify with paired TFRAG-only vs TIE-only
frames at the same camera packet.

### I1.3 — Merc / Jak identity bone (H1)

`eichar-lod0` IS captured (chain 311, 2253 tris), yet retained Eichar verts sit
behind the near plane (clip-z ≈ -1.05, `visible=0` across 32 packets), so
capture coverage is refuted. The native skinning near the Merc path in
`metal_gfx.mm` already negates `-bones[].X * p`; the open candidate is the
matrix row/column layout (`m[0][0]*x + m[1][0]*y + ...` vs `emerc.vert`).
Before-failing test: one-vertex identity-bone projection regression, then a
live clip-visible ledger and a Merc-only Village1 frame.

### I1.4 — aspect, TOD, and pacing follow-ups

Aspect is ~9% wide (512/448 y-scale on the full 2420x1668 drawable); apply the
upstream letterbox (`SCISSOR_ADJUST * HEIGHT_SCALE`) and compare against macOS.
Keep the 512-transfer decode plus 4096 PC_PORT tail scan. TOD alpha should be
`x4`. Review depth-mode mapping only over NEVER/ALWAYS/GEQUAL/GREATER.

### I1.5 — title `enter-state` fault

The title `enter-state` SIGSEGV (`x20=0`, fault `0x140`) recurs
intermittently. When it fires, stop renderer work, identify the null
process/state caller, regress the pointer contract, and rerun one cold launch.
AGENTS.md rule 3 bars a new R-round until this fault and the
`presentRGBA:`/`_MTLCommandEncoder` crash are each root-caused and
regression-covered.

Every I1 change needs a focused regression, one fresh inspected iPad frame
with its SHA-256, the paired `scene-no-merc` / `scene-no-tie` controls, a chain
rate from `VU1STAT`, a 0-byte fault log, and one <=60-line evidence doc.

## Gate I2 — audio and lifecycle (corrected from BOT37)

The compile-time half is done: `jak1/srpc.cpp` is in the iOS build and
PLAYER-channel buffers reach `pcm-peak`. What remains is acceptance: require
`pcm-peak>0` after New Game on the accepted route, audible acceptance by the
user, correct handling of interruption and background/foreground recovery,
neutral input on focus loss or controller disconnect, save persistence, and
termination/relaunch. Do not re-open this gate on the false premise that the
PLAYER RPC path is uncompiled.

## Gate I3 — PS2 touch/controller frontend

Keep the BOT36 I3 contract: `ref/sunpad` is an interaction/menu/persistence
reference only. Both sticks, D-pad, four face buttons, L1/L2/R1/R2, L3/R3,
Start, Select, multitouch, pressed/held/neutral feedback, editable normalized
layouts, controller handoff, safe areas, and separate iPad/iPhone defaults.
The persistent three-dot frontend owns Gameplay, Controls, Video, Audio, Data
& Saves, and Diagnostics. Capture three visual directions before implementing
one, then validate live with accessibility labels and lifecycle tests.

## Gate P1 — iPhone parity

Run the accepted iPad route on one iPhone Simulator after shutting the iPad
one down. Rework, not merely shrink, the layout for phone reachability and safe
areas; match scene correctness, controls, audio, lifecycle, persistence, and
frame pacing.

## Gate D1 — physical-device readiness

Verify signing/provisioning, legal user-data import, save persistence, install,
launch, input, audio, interruption, background/resume, and relaunch on a
physical iPad and iPhone. Simulator evidence alone never closes this gate.

## Operating loop

For each experiment: state the current evidence, ask one falsifiable question,
make the smallest change, add the before-failing regression, run one visible
route, inspect the screen, and record PASS or OPEN honestly. Stop at the first
failed gate instead of switching platforms as a workaround. Three repeated runs
against the same root blocker require a dated stop report, then an independent
gate.

## Evidence budget (AGENTS.md rule 3)

One <=60-line doc per proven gate, at most eight appended STATUS lines. Stop
appending new dated STATUS sections: replace the stale top board with current
truth instead of growing the file.
