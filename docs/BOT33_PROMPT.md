# BOT33 Goal Loop — finish Ottsel mobile playability without guessing

Date written: 2026-08-19
Starting checkpoint: `dc60af38433879ccf65ac30d0c16a5f155e9541e`
(`main` = `origin/main` when this prompt was written)

This is the current paste-ready builder prompt. It authorizes scoped
implementation, regression, evidence, and documentation work needed to advance
the goal. It does not authorize protected-asset commits, a signing-account
change, destructive cleanup, a release claim, or rewriting unrelated systems.

## Fixed goal

Deliver an honestly playable native Ottsel build on iPad first, then prove
iPhone parity and physical-device readiness. Preserve signed native/no-runtime-
executable-code execution and the ROM-safe repository boundary. Use the macOS
renderer as the behavioral reference, close one falsifiable mobile gate at a
time, and keep going until the completion definitions below pass or a genuine
external dependency is documented.

Do not reduce the goal to “the app launches,” “packets arrive,” “Metal draws
something,” or “the compiler passes.” Do not stop after writing another plan;
this file is the plan.

## Read before acting

Read completely, in this order:

1. `docs/STATUS.md`
2. `docs/reports/2026-08-19-ipad-iphone-blocker-investigation.md`
3. `docs/15-macos-to-mobile-goal-loop.md`
4. `docs/13-current-state.md`
5. `docs/evidence/I1/i1-fullscreen-composed-frame-2026-08-18.md`
6. `docs/evidence/I1/i1-new-game-sequence-a-2026-08-18.md`
7. `docs/evidence/I1/i1-platform-input-shell-2026-08-18.md`
8. `docs/evidence/M1/m1-retail-single-runtime-retest-2026-08-18.md`
9. `docs/07-asset-safety.md`
10. `docs/10-code-packaging-and-signing.md`

The similarly named
`docs/reports/2026-08-19-ipad-iphone-blocker-investigation-brief.md` is the
question that prompted the investigation. The report above is the resulting
decision and corrects its unproven offscreen-target assumption. BOT32 and older
prompts are evidence history, not the live queue.

## Non-negotiable operating rules

- Start every work period with `git status --short`, `git rev-parse HEAD`, and
  the equivalent status/identity check for `out/jak-project`. Existing dirty
  changes are user-owned. Preserve them and never reset or overwrite them.
- `out/jak-project` is an ignored local upstream worktree. Inspect it freely.
  Change it only for the selected implementation gate, keep the change narrow,
  and carry maintained upstream changes in the repository's canonical patch
  mechanism before claiming completion.
- Never commit an ISO, extracted retail data, DGO/CGO/STR/VIS/TEXT/audio banks,
  saves, DerivedData, build products, IPA, certificate, profile, or secret.
- Product execution remains signed native Mach-O code. Never add JIT, RWX,
  runtime-created executable pages, or copied executable blobs as a product
  shortcut.
- Use one Windowed runtime and at most one booted Simulator. Never run macOS
  `gk` and the Simulator concurrently. Stop the first platform before starting
  the second.
- Make one bounded change at a time. Add a regression or trace that fails
  before the fix. Record the exact build/run identity and result.
- Never treat a compile, link, packet counter, decoded texture, nonzero target,
  partial bucket, shell log, first launch, or Simulator-only result as
  playability/device proof.
- Do not extend the CPU rasterizer as a product renderer. Do not add a second
  generic VU interpreter. Do not pivot to a broad ANGLE port without passing
  the explicit fallback discriminator below.
- Do not patch GOAL/game content around compiler/runtime defects. Reproduce and
  regress the shared defect at its actual layer.
- Keep `docs/STATUS.md` and one dated evidence file current after each proven
  gate. Leave failed experiments documented when they change the next decision.

## The loop

Repeat these six actions until the fixed goal passes or a stop condition is
met:

1. **Audit:** reconcile source, current dirty state, latest evidence, running
   processes, booted Simulator, and the first open gate below.
2. **Select:** choose exactly one missing behavior and write its before-failing
   observation, intended change, and falsifiable exit bar.
3. **Act:** add the smallest discriminator/regression, then the smallest fix.
4. **Prove:** run focused tests first, then exactly the live platform path the
   gate requires. Capture counters, visible evidence, and fault scans.
5. **Record:** add a dated evidence note; update current status only to what the
   proof establishes; remove or bound temporary probes.
6. **Continue:** select the next dependency. A handoff or partial milestone is
   not completion.

Use this compact ledger in each evidence note:

| Field | Required value |
|---|---|
| Gate | One ID below |
| Source/build identity | Ottsel SHA, upstream SHA, patch hash, app/runtime hash |
| Environment | macOS or exact Simulator/device model and OS |
| Before failure | Exact assertion, screenshot defect, counter, or fault |
| Change | Files/functions and why this is the smallest boundary |
| Focused proof | Command and result |
| Live proof | One runtime, input route, duration, screenshot/frame |
| Fault scan | Crash/assert/fault/validation/placeholder/unsupported markers |
| Verdict | PASS, OPEN, or EXTERNALLY BLOCKED; never inferred |
| Next gate | One gate ID and its first experiment |

## Gate D0 — attribute the Jak 1 glyph on desktop

This gate comes first. Do not implement an offscreen Metal target before it
passes.

Fingerprint the source-defined glyph packet:

- DMA `qwc=14`
- VIF `DIRECT 14`
- GIF `nloop=1`, `eop=1`, `pre=1`, `prim=0x5c`, `nreg=13`
- records: `A+D(TEX0)`, then four `ST`, `RGBAQ`, `XYZF2` triplets

Instrument the desktop consumer narrowly. For the matching packet record:

- bucket ID, renderer class and renderer name;
- `FRAME.fbp`, bound FBO, viewport/target dimensions, `m_offscreen_mode`;
- `SCISSOR`, `XYOFFSET`, complete TEX0/TEX1/CLAMP/TEXA;
- PRIM, ALPHA, TEST, ZBUF and write masks;
- pre-shader and post-shader vertex bounds;
- texture address/identity and hit/miss;
- state-change flush count, draw count, triangle count;
- the first later draw or composition step that makes those pixels visible.

Capture from the last relevant bucket reset/flush through visibility, not only
the 224-byte glyph payload.

**Exit bar:** a dated macOS trace and same-phase screenshot unambiguously prove
one of these branches:

- **D0-NORMAL:** Jak 1 plain Direct draws the glyph to the final target; or
- **D0-TARGET:** a specific FBP/FBO target is stored, aliased to a texture, and
  sampled by a specific later draw.

If neither is proven, stop renderer implementation and improve only this
trace. Positions near `(2430,4040)` and `SCISSOR 0..127` are not sufficient.

## Gate D1 — commit a ROM-safe, before-failing Direct fixture

Build the smallest complete fixture from the D0 trace:

- retain the open-source-generated packet structure, state prefix, and order;
- replace protected glyph texels and CLUT with a tiny generated pattern;
- include the target switch and consuming draw only if D0-TARGET proves them;
- record expected ordered-state hash, image hash/tolerance, and counters.

Required core counters for one unsplit glyph:

- 1 VIF `DIRECT` transfer
- 1 PACKED GIF tag
- 13 packed records
- 4 vertices
- 2 triangles
- 1 texture lookup and 1 hit
- normally 1 draw call
- 0 placeholder textures
- 0 unsupported registers
- 0 out-of-range reads

**Exit bar:** desktop passes the synthetic fixture; current Metal fails for the
expected missing Direct consumer; the repository/package audit finds no
protected data. A fixture that already passes before the renderer change is
not a valid regression.

## Gate D2 — separate Direct decoding from rendering

Keep and harden the existing `DmaFollower`, VIF `DIRECT` walk, GIF
PACKED/REGLIST parser, A+D decoding, texture/CLUT decode, and
`OttselDrawState`/`OttselVertex`. Produce an ordered intermediate stream with:

- state changes and complete state snapshots;
- vertices and primitive boundaries;
- explicit flush reasons and bucket reset/end boundaries;
- target identity/alias records only when D0 proves them;
- explicit errors for unsupported registers and out-of-bounds data.

Resolve ADC behavior against desktop. Do not let one static decoder silently
carry state across unrelated chains/buckets.

**Exit bar:** fixture IR matches the desktop trace field-for-field and in order;
all expected counters pass; corruption/unsupported fixture variants fail
locally; no rendering is required for this gate.

## Gate D3 — implement the minimum native-Metal Direct draw

Use `OttselMetal`'s existing Metal device, queue, layer, texture/sampler, depth,
and one-present ownership. Implement only the state exercised by the fixture,
while retaining full values in the IR:

- GS-to-Metal position/scissor/XY offset behavior;
- textured and untextured primitive selection as needed;
- texture/CLUT upload and keyed lookup;
- blend, alpha test, depth test/write, color mask, fog, clamp/filter behavior;
- state-change flush order and desktop bucket position.

For D0-NORMAL, draw to the proven final target and do not invent an offscreen
cache. For D0-TARGET, key one Metal target by the observed GS framebuffer
identity, store it before sampling, and implement only the proven consuming
draw/lifetime.

The product result must not read from `OttselRaster`, `OttselTexCache`,
`g_frame`, `g_frame_pending`, largest-texture selection, coordinate guesses, or
periodic CPU-frame publication.

**Exit bar:** the synthetic target/image and counter contract passes with a
stable nonzero region within stated tolerance, zero CPU-raster contribution,
and zero validation/fault/unsupported/bounds/placeholder markers.

If the packet cannot compose:

- If the first mismatch is in the ordered trace, fix only decoder/state/ADC.
- If the target is zero, compare transform, scissor, test, texture, and write
  state against the D0 trace.
- If a proven target is nonzero but the final frame is blank, inspect only its
  alias/store lifetime and the first consuming draw.
- If native Metal still cannot pass while desktop does, run the ANGLE
  discriminator below; do not broaden the fixture or implement more buckets.

## Gate D4 — one live iPad Direct proof

Stop macOS. Build a fresh iPad app, boot one Windowed iPad Simulator, and replay
the real title/menu route that emits the fingerprinted packet.

Record:

- Ottsel/upstream/patch/app identities, PID, Simulator model/OS, drawable size;
- packet fingerprint, state hash, target ID/size, texture hit, flushes, vertices,
  triangles, draws, placeholder/unsupported/bounds counters;
- one screenshot with the expected title/menu element visibly composed without
  hiding or regressing the existing TIE/TFRAG scene;
- one same-phase macOS screenshot;
- fault, crash, assert, Metal validation, unsupported, placeholder, and bounds
  scans.

**Exit bar:** two fresh replays produce the same visible element and bounded
counter contract, same-phase Mac/iPad comparison supports the intended result,
and all fault scans are clean. Mark this “Direct slice PASS,” not “iPad
playable.”

## Gate AGL — ANGLE fallback discriminator, not a default route

Run this only if D3 cannot pass after the first observed divergence has been
isolated, or if later bucket-parity cost invalidates the native-Metal estimate.

1. Pin one ANGLE dependency without changing game/runtime semantics.
2. Prove an iOS EGL window surface/context.
3. Compile only the Direct renderer closure and required shader equivalents.
4. Replay the D1 fixture.
5. Inventory every GL, shader, texture, FBO, build, and lifecycle shim.

**Exit bar for reconsideration:** the fixture produces the same nonzero target,
final image, and counters with a small localized compatibility layer. Reject
ANGLE for this milestone if it first requires renderer-wide ShaderLibrary,
TexturePool/FBO, 92-shader, or desktop-GL API rewrites.

## Gate R1 — Sprite3 and renderer parity

Feed the retained Sprite3 record expansion into Metal GPU buffers and remove
its CPU consumer. Then close remaining visual work in screenshot-diff order,
not by source-file count:

1. normal TIE material semantics;
2. transparent/dirt/ice TFRAG;
3. Merc;
4. remaining Sprite3/Direct effects;
5. other buckets observed missing on the deterministic retail route.

For each bucket, add one before-failing fixture, compare the ordered desktop
state, pass the Metal fixture, then prove the same live phase on macOS and iPad.

**Exit bar:** title, menu, Village1, and Training comparison frames have no
missing gameplay-critical bucket on the accepted route; no CPU/generic-VU
fallback contributes; frame time and memory are recorded. Do not hide defects
with a screenshot-specific hack.

## Gate I1 — input ownership and lifecycle

The shared `PadState` seam is real, but the mobile shell currently consumes
gamepad events without enumerating/opening/retaining SDL gamepads or handling
add/remove. Add explicit ownership, one selected controller for pad 0,
disconnect neutralization, and reconnect. Extend lifecycle from input-only
neutralization to one coordinated runtime/render/audio pause/resume seam before
audio lands.

Add focused regressions for simultaneous stick/buttons, finger cancellation,
controller disconnect, editor/menu cancellation, background/resume, and
latched-edge clearing.

**Exit bar:** active input reaches `scePadRead`; every cancellation/disconnect/
lifecycle route produces buttons/pressure zero and sticks `(127,127)`; the
visible scene resumes; reconnect works without relaunch. Final controller
acceptance requires a real DualSense, Xbox, or MFi controller.

## Gate T1 — visible customizable touch controls

Replace the invisible split-screen touch bridge with one landscape overlay
above the Metal view, still driving the shared `PadState`. Include left stick,
camera/right-stick gesture, face actions, shoulders/triggers as required,
Start/map, safe-area handling, opacity/scale/position editing, separate tablet
and phone layouts, persistence, and accessibility labels/touch targets.

**Exit bar:** visible controls support simultaneous movement + action + camera;
layout changes survive termination/relaunch; finger cancel, editor/menu,
background, and overlay dismissal all return neutral; tablet ergonomics and
accessibility checks are documented. A temporary invisible bridge does not
count.

## Gate F1 — legal user-data import and save persistence

Replace build-time dependence on bundled ignored extracts with a versioned,
host-prepared user-data pack imported through Files into durable app storage.
Validate manifest, data version, hashes, available space, and completeness,
including all renderer and audio families. Keep the app functional as a clean
no-data install and give the user a clear remediation path.

**Exit bar:** a fresh app contains no protected data; a user-owned pack imports;
the app terminates/relaunches and boots from durable storage; the real
title-to-Village1 route streams; a save is created, the app terminates, and the
save reloads; repo and package audits remain ROM-safe.

## Gate AU1 — mobile IOP, streaming, and playback-only audio

Do not mistake current boot shims for audio completion. Mobile initializes only
video/gamepad, `ios_stubs.cpp` leaves IOP/sound inert, and the current bundle
copy omits MUS/SBK/VAG families. Bring up the host-proven IOP/overlord/989snd
path or retain a shim only after fixture-backed behavioral parity. Initialize
playback audio, add mixed-PCM counters, and handle pause/resume, route changes,
and interruptions without requesting microphone permission.

**Exit bar:** required DGO/VIS/STR and sound-bank/music/VAG requests complete;
callback and mixed-PCM counters are nonzero; title/gameplay audio is audibly
correct; background/interruption pauses without duplicate streams or clock
drift; speaker/headphone/Bluetooth route changes recover. Audible route and
interruption acceptance requires physical hardware and a human listener.

## Gate P2 — iPad playable

From a fresh validated user-data install, one Windowed iPad run must:

- show a coherent macOS-comparable title and menu;
- complete real New Game through Village1/Training with required buckets;
- support visible customizable touch controls;
- support canonical external-controller input and disconnect neutralization;
- stream required data, produce audible playback-only audio, and save/reload;
- background/resume with neutral input and coordinated subsystem recovery;
- complete a bounded active soak with no crash/fault/assert/Metal-validation
  markers and with frame-time/memory counters recorded.

**Exit bar:** every clause has a dated artifact. If one is missing, iPad remains
IN PROGRESS.

## Gate P3 — iPhone parity

Start only after P2. Run one landscape iPhone Simulator using the same fresh
install and deterministic route. Validate safe areas, drawable size, compact
touch layout and persistence, renderer parity, input active/neutral states,
streaming/audio, save/reload, lifecycle, frame time, and memory.

**Exit bar:** the full P2 route passes at iPhone size with phone-specific layout
evidence and no new faults. Simulator parity does not prove signing, thermal,
route, or physical ergonomics.

## Gate DVC — physical-device readiness

Add a reproducible `iphoneos` arm64 build/archive/sign/install path without
shipping protected data or signing material. Audit that executable GOAL code is
signed Mach-O text and no runtime executable generation is present.

Run cold installs on one supported iPad and one iPhone. Test user-data import,
touch ergonomics, controller connect/disconnect/reconnect, speaker/headphone/
Bluetooth routes, interruptions, background/resume, save persistence, sustained
performance/memory/thermal behavior, and absence of a microphone prompt.

**Exit bar:** every device-matrix row passes on both devices and the final
signed/ROM-safe package audit passes.

**External requirements:** Apple Developer Team/certificate/profile and unique
bundle ID, physical iPad and iPhone, compatible controller, audio accessories,
and a legal user-owned game copy. If unavailable, mark only DVC externally
blocked and leave exact required access plus commands/checklist; do not call the
engineering path impossible.

## Stop conditions

Stop and write a dated blocker report only when one of these is true:

- the same precisely stated blocker has repeated for three consecutive loops,
  including the first occurrence, and no new discriminating experiment remains;
- completion requires signing authority, physical hardware, legal user data, or
  another external permission not available in the environment;
- proceeding would overwrite user-owned dirty work or require a materially
  broader architecture choice not authorized by this loop;
- a source/evidence contradiction makes the selected gate unsafe to implement.

The blocker report must include the first failing command/action, exact error,
three experiments and what each ruled out, current source/build identities,
dirty state, preserved artifacts, the smallest next experiment, and the exact
external access required. “Hard,” “slow,” and “needs more work” are not stop
conditions.

## Final completion definitions

- **iPad playable:** Gate P2 passes every clause from a fresh validated local
  data install.
- **iPhone parity:** Gate P3 passes after P2, with iPhone layout/performance
  evidence; this is still Simulator scope.
- **Device-ready:** Gate DVC passes on physical iPad and iPhone with signed-
  native and ROM-safe audits.
- **Project complete for this loop:** all three definitions pass, or only the
  explicitly itemized physical/signing/legal rows remain externally blocked
  after all non-device engineering and Simulator proofs are complete.
