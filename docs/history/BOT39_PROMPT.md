# BOT39 — iPad renderer completion to honest playability

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. It
supersedes `docs/BOT38_PROMPT.md` as the active queue while keeping the same
gate contract (I0-I3, P1, D1). Read `AGENTS.md` first, then this file, then
`docs/BOT38_PROMPT.md` for the still-valid I1 defect inventory,
`docs/STATUS.md` (tail), and the evidence under `docs/evidence/I1/`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Keep the app signed-native and
ROM-safe: no ISO or extracted game data in Git, no RWX/`MAP_JIT`/trampoline
code in the product path, and users supply their own legal game data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Platform order (unchanged)

1. macOS is the accepted behavioral/visual reference and stays frozen.
2. The active queue is the iPad Simulator renderer (Gate I1).
3. iPhone parity (P1) and physical-device readiness (D1) stay behind a
   coherent iPad route.

Frozen until I1 closes: camera matrix math (`set_mobile_tie_camera`),
TBP/lookup, strip-restart, the touch frontend, and all iPhone work.

## Disk precondition — user override in force

AGENTS.md rule 2 sets a 40 GB floor. On 2026-09-10 the user explicitly
overrode it for this continuation ("theres space to work, just keep working"),
and BOT39 runs under that authorization. Measured at session start:
`df -h /` Avail **15Gi**, `tmp_pack_*` **0**. Still run
`df -h / | tail -1` and count `.git/objects/pack/tmp_pack_*` before every
build, keep every worktree file below 100 MB, never `git add -A`, and report
exact paths and sizes if a temp pack appears or Avail drops below 8 GB. The
override covers working, not cleanup: no deletion of user files.

## Landed since BOT38 — verified in this checkout, do not re-litigate

- `e928f48` **I1.1a SKY_DRAW TRI_FAN (PASS).** Bucket 3's packed sky tags are
  `pre=1 prim=0x5d`; the low three bits are `GsPrim::Kind::TRI_FAN`
  (`ref/open-goal-jak-project/repo/common/dma/gs.h:239`). The native
  `push_vertex` switch handled only SPRITE/TRI/TRI_STRIP, so every fan
  accumulated to the 8-slot cap and produced `candidates=0`. Adding the case
  (vertex 0 stays the fan centre, only slot 1 refills) moves the packed
  population from `candidates=0 strips=0` to `candidates=34..40
  strips=34..40 rejected=0 unhandled-packed=0`. Upstream:
`DirectRenderer.cpp:1296`.
- **Bucket 3 is two populations**, not one: 5/8 sampled chains are the real
  packed `SKY_DRAW` list (`tex0` written), 3/8 are a REGLIST fill quad with
  `tex0-writes=0` (untextured by construction). Any future Sky claim must say
  which population it sampled.
- **Colored rectangles are the touch overlay**, not a render defect. Proof is
  the same-session A/B in `docs/evidence/I1/AB-a-cw.png` / `AB-b-cw.png` via
  the `ottsel-trace-metal-scene-no-overlay` probe.
- The BOT38 logging additions (`OTTSEL PACKED`, extended `OTTSEL SKY
  PRODUCT`) are retained observability and cost nothing at `native_capture`
  off.

## Gate I1 — scene correctness (ACTIVE)

### I1.1b — SkyBlend texture producer (immediate next step)

Every completed fan samples `tex0-last=0x198005fa0` -> `tbp0=0x1FA0`,
64x64 PSMCT32, which has no VRAM source, so all 34-40 fans are pruned as
texture misses; `unhandled-packed=0`, so nothing else is dropped. That
address is exact: `SKY_TEXTURE_VRAM_ADDRS = {8064, 8096}`
(`ref/.../texture/TexturePool.h:25`) and 8096 = `0x1FA0` is the
SkyBlend-generated 64x64 cloud buffer (`m_sizes = {32, 64}`,
`SkyBlendCPU.h:20`; 8064 = `0x1F80` is the 32x32 sky buffer).

The content is CPU-generated, not uploaded. Contract:
`SkyBlendHandler::render` (`SkyRenderer.cpp:20-30`) documents the sequence
`set-display 8qw -> copy-sky -> copy-cloud -> set-alpha -> reset-display`,
twice, once per level; `SkyBlendCPU::do_sky_blends` (`SkyBlendCPU.cpp:99-186`)
consumes it. Each copy is a `qwc == 6` pair: an ADGIF at `setup+16` carrying
the **source** texture's `tex0`, then a 6qw draw whose `data+16` holds the
intensity byte and whose `data+80` holds `0x200` (sky, 32x32) or `0x400`
(clouds, 64x64). First draw of each buffer overwrites
(`blend_sky_initial_fast`), later draws accumulate
(`out += min(255, in*intensity>>7)`).

Implementation shape on the native path, in this order:

1. **Observability first.** Add a bounded one-shot probe that walks the
   bucket-32 window (`ottstel_mobile_jak1_bucket_boundary(offset, 32)` to
   `(offset, 33)`) of real Village1 chains and logs, per transfer, the tag
   kind/qwc/size, any VIF unpack, and any `tex0`/ADGIF source it writes. The
   earlier 5-transfer/1-packed-tag reading came from a temporary probe that has
   since been reverted and did not decode ADGIF `tex0`; do not build on it.
   Falsifiable question: does bucket 32 in these chains carry the `qwc == 6`
   sky-copy pairs at all, and if so which source `tbp0`s and intensities do
   they name?
2. **Then generate.** Replay the same blend on the CPU into 32x32 and 64x64
   RGBA buffers and register them where the existing fan lookup already looks:
`g_direct_relocated_textures[direct_texture_cache_key(8064, 0)]` and
`(8096, 0)` (`metal_gfx.mm:1941-1945, 2592-2598`), plus
`ottsel_metal_upload_direct_texture` for the GPU side. Source textures come
   from `g_direct_texture_metadata` / the existing VRAM decode; a missing
   source is a logged miss, not a fake fill.

Do **not** add a fake sky texture, gradient, or placeholder. If bucket 32 does
not carry the copies in Village1 frames, say so and re-anchor on where the
generated buffer is produced; do not synthesize.

Exit: `submitted>0` fans with a fresh inspected frame whose black sky region
gains ordered Sky geometry, no TFRAG/TIE/Merc regression, 0-byte fault log.

### I1.2 — TFRAG vs TIE vertex contracts

`tfrag3.vert` has no Q/HVDF block; the static-TIE shaders apply
`cam_no_persp` + `persp0`/`persp1` then the 2048/8388608/256/128 block.
`metal_shell.mm:135` gates that block on `camera_sign < 0`, but
`metal_shell.mm:1049` only sets `-1` under the one-shot
`sceneTieReferenceProjectionProbe`, and that probe feeds `pc_camera` instead
of `cam_no_persp`/`persp0`/`persp1`. Falsify with paired TFRAG-only vs
TIE-only frames at the same camera packet.

### I1.3 — Merc / Jak identity bone (H1)

`eichar-lod0` IS captured (chain 311, 2253 tris) but every retained Eichar
vertex sits outside the x frustum (`visible=0`, `clip-x=(0.4886, 1.3657)`
across 9942 verts and 32 packets), so capture coverage is refuted. The native
skinning already negates `-bones[].X * p`; the open candidate is the matrix
row/column layout (`m[0][0]*x + m[1][0]*y + ...` vs `emerc.vert`). Before
failing test: one-vertex identity-bone projection regression, then a live
clip-visible ledger and a Merc-only Village1 frame. This is independent of
I1.1b and may pay off faster; it is an allowed parallel lane, not a detour.

### I1.4 — aspect, TOD, and pacing

Aspect is ~9% wide (512/448 y-scale on the 2420x1668 drawable); apply the
upstream letterbox (`SCISSOR_ADJUST * HEIGHT_SCALE`) and compare to macOS.
Keep the 512-transfer decode plus 4096 PC_PORT tail scan. TOD alpha should be
`x4`. Review depth-mode mapping only over NEVER/ALWAYS/GEQUAL/GREATER.

### I1.5 — title `enter-state` fault

The title `enter-state` SIGSEGV (`x20=0`, fault `0x140`) recurs
intermittently. When it fires, stop renderer work, identify the null
process/state caller, regress the pointer contract, and rerun one cold launch.
AGENTS.md rule 3 bars a new R-round until this fault and the
`presentRGBA:`/`_MTLCommandEncoder` crash are each root-caused and
covered by a regression.

Every I1 change needs a focused regression, one fresh inspected iPad frame
with its SHA-256, the paired `scene-no-merc` / `scene-no-tie` controls, a
chain rate from `VU1STAT`, a 0-byte fault log, and one <=60-line evidence doc.

## Gate I2 — audio and lifecycle (evidence updated)

The compile-time half is done and the runtime half is now measured: a
2026-09-10 Village1 run logs sustained PLAYER RPC plays (`fly7`,
`yakow-1/2`) and `OTTSEL AUDIO: mixed 48000 frames (window 250),
pcm-peak=9413` — nonzero game PCM, ~29% of full scale. `fire-pop` still
reports `sound missing`, which is a data/variant gap, not a routing failure.

What remains is acceptance, not wiring: audible confirmation by the user on the
accepted route, correct interruption and background/foreground recovery,
neutral input on focus loss or controller disconnect, save persistence, and
termination/relaunch. Do not re-open this gate on the false premise that the
PLAYER RPC path is uncompiled, and do not claim audio acceptance from the peak
counter alone.

## Gate I3 — PS2 touch/controller frontend

Keep the BOT36 I3 contract: `ref/sunpad` is an interaction/menu/persistence
reference only. Both sticks, D-pad, four face buttons, L1/L2/R1/R2, L3/R3,
Start, Select, multitouch, pressed/held/neutral feedback, editable normalized
layouts, controller handoff, safe areas, separate iPad/iPhone defaults. The
persistent three-dot frontend owns Gameplay, Controls, Video, Audio, Data &
Saves, and Diagnostics. Capture three visual directions before implementing
one, then validate live with accessibility labels and lifecycle tests.

## Gate P1 — iPhone parity

Run the accepted iPad route on one iPhone Simulator after shutting the iPad one
down. Rework, not merely shrink, the layout for phone reachability and safe
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
failed gate instead of switching platforms as a workaround. Three repeated
runs against the same root blocker require a dated stop report, then an
independent gate.

## Evidence budget (AGENTS.md rule 3)

One <=60-line doc per proven gate, at most eight appended STATUS lines. Stop
appending new dated STATUS sections: replace the stale top board with current
truth instead of growing the file.
