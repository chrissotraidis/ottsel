# BOT40 — iPad renderer: settle the sky draw path, then honest playability

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. It
supersedes `docs/BOT39_PROMPT.md` as the active queue while keeping the same
gate contract (I0-I3, P1, D1). Read `AGENTS.md` first, then this file, then
`docs/BOT39_PROMPT.md` and `docs/BOT38_PROMPT.md` for the still-valid I1
defect inventory, `docs/STATUS.md` (tail), and the evidence under
`docs/evidence/I1/`.

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

AGENTS.md rule 2 sets a 40 GB floor. The user has explicitly overridden it and
re-stated that override on 2026-09-11 ("theres space to work, just keep
working"), and BOT40 runs under that authorization. Measured at this session's
start: `df -h /` Avail **14Gi**, `tmp_pack_*` **0**. Still run
`df -h / | tail -1` and count `.git/objects/pack/tmp_pack_*` before every
build, keep every worktree file below 100 MB, never `git add -A`, and report
exact paths and sizes if a temp pack appears or Avail drops below 8 GB. The
override covers working, not cleanup: no deletion of user files.

## Landed since BOT39 — verified in this checkout, do not re-litigate

- `e928f48` **I1.1a SKY_DRAW TRI_FAN (PASS).** Packed sky tags are
  `pre=1 prim=0x5d` = `TRI_FAN`; the native `push_vertex` switch now handles
  it, moving the packed population to `candidates=34..40 strips=34..40
  rejected=0 unhandled-packed=0`.
- **I1.1b is implemented on the native path (uncommitted).** The SkyBlend
  bucket-32 replay now produces real 32x32 and 64x64 CPU buffers:
  `OTTSEL SKY BLEND` reports live rgb texels and `alpha-peak=240..253`, and
  `OTTSEL SKY PRODUCT` reports `submitted=40` with `texture-misses=0`. The
  generated texture is no longer the blocker.
- **Textured sky batches reach `drawPrimitives` with in-drawable vertex
  bounds.** The bounded `SKYBOUND` dump shows the tex32 fans at
  `ndc=(0.000,-0.009)..(4.000,3.991)` and 32 tex64 fans tiling
  `y=0.11..3.99` at `a=0.502`, and the buffer `contents` read back matches.
- `direct_vs` passes its input straight through as clip space
  (`out.position = float4(in.pos, 0, 1)`), and the pass clears to
  `(0.03, 0.04, 0.07)`.

## Retracted by this prompt — do not build on it

- **"The sky draw path is dead" (BOT39) is not accepted as settled.** The
  evidence for it was an in-loop magenta reference triangle, which is
  confounded: the sky is encoded *before* the opaque TFRAG/TIE/Merc/Sprite
  passes in the same encoder, so a probe drawn there can be overdrawn while the
  sky region still reads as clear colour elsewhere on screen.
- The earlier "forced-opaque floods cyan / debug magenta floods the screen"
  reading was produced with a **stale installed binary** and is refuted. Any
  BOT38/BOT39 claim resting on "sky geometry + encoder proven to reach pixels"
  must be re-derived, not quoted.

## Gate I1 — scene correctness (ACTIVE)

## BOT40 findings — measured 2026-09-11 in this checkout

Installed app SHA `b0b0ab11fa76a5b312d1b8dcfbfff18de9c9585d2de853d45d245354f4d5df8d`.

1. **The flat coloured rectangles are the PS2 touch frontend overlay, not the
   sky.** Their colour literals are in `src/shell/main.cpp:626-632`
   (`build_touch_overlay` -> `add_touch_rect`), the overlay samples a 1x1 white
   texture, and the rectangles are pixel-identical with the sky skipped and
   with Sprite3 skipped, and vanish only with `scene-no-overlay`. BOT39 had
   this right; it is confirmed here by an independent A/B.
2. **The scene is not deterministic frame-to-frame, and this invalidates every
   single-screenshot A/B recorded so far.** Two launches of the same installed
   binary, screenshotted at t=45 s, differ on 39.5% of pixels. Within one
   launch the camera is continuously in motion: five shots at t=40/44/48/52/56 s
   differ pairwise by 36-79%. Any conclusion resting on one screenshot per
   condition sits inside the noise floor and must be re-derived.
3. **The camera is live.** The renderer follows a moving game camera and
   `scePadRead` is polled continuously, so the native pipeline is running.
4. **`scene-no-depth` surfaces geometry the depth state currently rejects.**
   With depth forced to ALWAYS the frame shows textured geometry above and
   behind the island that the baseline does not, and the non-background pixel
   fraction rises from 0.248/0.265 (two baselines) to 0.312. Weak but
   consistent with a depth/composition fault rather than lost geometry.
5. **Merc/Jak is a stronger lead than the sky.** The Village1 Eichar clip
   ledger reports `visible=0` for all 9942 vertices with
   `clip-z=(-1.0543,-1.0405)` and `clip-x=(0.4886,1.3657)`. Two independent
   problems: every vertex fails the `z>=-1` test, so the Metal remap
   `z=(z+w)*0.5` makes it negative and it is hard-clipped; and the bundle
   spans 1.06 NDC in y, about twice the frame height. That is a
   projection/scale outlier, not a skinning failure.
6. **Sky vertex colour is not near-black.** `OTTSEL SKY RAW` reports
   `rgba=(128,128,128,128)` on the fans, i.e. 0.502 -> 1.0 after the `*2`, so
   the sky is drawn near-full-bright. Upstream `direct_basic_textured.frag`
   applies `color *= 2` to the whole colour, so the native `direct_fs` is
   faithful. Do not chase a vertex-colour gain.

## Next experiment (assigned)

Finding 2 invalidates pixel A/Bs, so the first task is a **camera-free
comparison harness**, not another probe: drive the accepted route, capture N
screenshots per condition across the same wall-clock window, and compare the
distributions (non-background fraction, and the per-pixel difference against a
same-condition baseline) instead of one frame. Then re-derive the depth
hypothesis from finding 4, and open the Merc projection outlier from finding 5
as the parallel lane.


### I1.1c — settle the sky draw path with one end-of-pass probe (immediate)

One falsifiable question: **can `skyDebugFillPipeline` (which is `direct_vs`
+ `directLayout` + the direct blend state, with a texture-free magenta
fragment) paint any pixel when drawn at the END of the pass, after every
opaque bucket, under the known-working `overlayDepthState`?**

- If it paints: pipeline, vertex layout and encoder are all fine, so the black
  sky is a *composition* problem, and the next questions are per-frame sky
  presence and draw order against the opaque buckets.
- If it does not paint: the fault is in the pipeline construction (descriptor
  copy, blend state, or vertex fetch) rather than in the decoded sky buffers.

Either answer retires a whole branch of the BOT39 investigation. Record the
answer before touching anything else.

### I1.1d — per-frame sky presence

`SKYFRAME` is throttled to 1 Hz and fires only on frames that carry sky
batches. Confirm the sky population is present on the frames that are actually
inspected, and not only on level-entry frames; if it is transient, say so
instead of calling a later black frame a draw failure.

### I1.1e — sky composition and ordering

Against the macOS reference
`docs/evidence/M1/artifacts-2026-08-21-macos-stability-gate/11-post-soak-neutral.png`
(blue-to-purple gradient sky, pink haze), establish where the sky sits in the
pass relative to the opaque background TFRAG. Do not add a fake sky texture,
gradient, or placeholder; if the real generated buffer cannot be composited,
say so.

### I1.2 - I1.5

Unchanged from `docs/BOT39_PROMPT.md`: TFRAG vs TIE vertex contracts, the Merc
/ Jak identity bone (H1, an allowed parallel lane), aspect/TOD/pacing, and the
title `enter-state` fault. AGENTS.md rule 3 still bars a new R-round until the
`presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT are each
root-caused and covered by a regression.

Every I1 change needs a focused regression, one fresh inspected iPad frame with
its SHA-256, the paired `scene-no-merc` / `scene-no-tie` controls, a chain
rate from `VU1STAT`, a 0-byte fault log, and one <=60-line evidence doc.

## Gate I2 — audio and lifecycle

Carried forward from BOT39: nonzero game PCM is measured (`pcm-peak=9413`,
`mixed 48000 frames`), and what remains is *acceptance* — audible confirmation
on the accepted route, interruption, background/foreground recovery, neutral
input on focus loss or controller disconnect, save persistence, and
termination/relaunch. Do not claim audio acceptance from the peak counter alone.

## Gate I3 — PS2 touch/controller frontend

Unchanged from `docs/BOT39_PROMPT.md`: `ref/sunpad` is an interaction/menu/
persistence reference only; both sticks, D-pad, four face buttons, L1/L2/R1/R2,
L3/R3, Start, Select, multitouch, pressed/held/neutral feedback, editable
normalized layouts, controller handoff, safe areas, separate iPad/iPhone
defaults, and the persistent three-dot frontend. Capture three visual directions
before implementing one.

## Gate P1 — iPhone parity

Run the accepted iPad route on one iPhone Simulator after shutting the iPad one
down. Rework, not merely shrink, the layout for phone reachability and safe
areas.

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
