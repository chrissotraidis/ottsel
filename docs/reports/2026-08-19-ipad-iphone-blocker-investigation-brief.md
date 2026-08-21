# Investigation brief — are Ottsel's iPad/iPhone blockers resolvable?

Date: 2026-08-19  
Checkpoint: `dc60af38433879ccf65ac30d0c16a5f155e9541e` (`main` = `origin/main`)  
Task for the investigating bot: **do a read-first technical investigation and
return an evidence-backed implementation plan. Do not implement or claim a
new platform pass.**

## Executive verdict

There is no demonstrated iPadOS or iPhoneOS platform prohibition in the active
path. The project already proves signed native/no-emit execution on an iPad
Simulator, real game bootstrap to Village1, a shared pad-state seam, and a
partial full-screen Metal scene. The main blockage is unfinished renderer
feature work: the mobile renderer does not yet reproduce the desktop
Direct/Sprite offscreen-target/composition behavior.

That makes the current issue **technically resolvable but substantial**, not a
hard blocker. The uncertain part is implementation cost and visual/performance
parity, not whether iOS permits the needed primitives. Physical-device
acceptance, signing, route/interruption behavior, and the legal user-data flow
remain real external gates, but they are later product-validation gates rather
than explanations for the missing scene composition.

## What is actually working

| Area | Verified boundary | Evidence |
|---|---|---|
| Native execution | OpenGOAL runs through the signed native/no-emit model; no runtime-created executable code is the product path. | `docs/evidence/A1/` and `docs/STATUS.md` |
| macOS reference | Native arm64 `gk` reaches real title → New Game → A/B/C/D1/D2 → Training, renders, accepts keyboard/mouse pad state, and has a five-minute active soak. | `docs/evidence/M1/m1-retail-single-runtime-retest-2026-08-18.md` |
| iPad bootstrap | Fresh Simulator path reaches Village1 by the real New Game flow and links the generated VI1/TIT payloads. | `docs/evidence/I1/i1-new-game-sequence-a-2026-08-18.md` |
| iPad input transport | Keyboard and touch produce canonical Cross + pressure then neutral; background/resume also returns neutral. | `docs/evidence/I1/i1-platform-input-shell-2026-08-18.md` and `i1-fullscreen-composed-frame-2026-08-18.md` |
| iPad scene baseline | Metal presents full-screen textured/fogged normal-TIE and one opaque-TFRAG Village1 pass. | `docs/evidence/I1/i1-fullscreen-composed-frame-2026-08-18.md` |

None of these is a claim that iPad is playable. In particular, input transport
is not a visible, customizable touch UI; a partial scene is not title/menu or
gameplay visual parity; and Simulator proof is not device acceptance.

## The active technical blockage: Direct/Sprite composition

### Observed failure, not a theory

The iPad receives real Direct data: the bounded trace saw 5,149 transfers,
24,883 packed GIF tags, and title/progress 14-qword packets. The decoded
geometry targets a GS offscreen rectangle (`SCISSOR 0..127`; positions roughly
`2430,4040`), so forcing it into the final 640×448-like CPU diagnostic surface
produced a wrong white bar rather than the intended foreground. The generic VU
fallback also produced zero output within its 50,000-instruction guard.

The desktop renderer has an explicit solution: `out/jak-project/game/graphics/
opengl_renderer/DirectRenderer.{h,cpp}` tracks GS state, including offscreen
mode, frame/scissor/XY offset, texture state, alpha/test, and final draw
semantics. Its Direct path is a correct behavioral reference. The local
mobile implementation has a useful decoder and a diagnostic CPU rasterizer in
`src/shell/metal_gfx.mm`, but it does not own equivalent Metal render targets
or a final composition pass. Existing TIE support is in
`src/shell/metal_shell.mm`.

### Why this appears resolvable

- Metal supports render-target textures, scissor rectangles, blending, and
  final composition. No iOS policy forbids this.
- The input packet and much GS state already reach `metal_gfx.mm`; the missing
  boundary is a renderer consumer, not game data or an ARM64 crash.
- The desktop `DirectRenderer` supplies source-level semantics to compare
  against, avoiding blind reverse engineering.

### Why it is not a small fix

The first offscreen draw alone will not establish the title or gameplay frame.
Correctness depends on GS `FRAME`, `SCISSOR`, `XYOFFSET`, texture/CLUT uploads,
alpha/test/depth behavior, presentation order, and composition with the live
TIE/TFRAG target. The wider renderer still lacks remaining normal-TIE material
semantics, transparent/dirt/ice TFRAG, Merc, Direct/Sprite effects, and
per-frame desktop parity instrumentation. The first focused target should be
one deterministic title/menu packet, not the entire Direct stream.

## Other open issues, classified

| Issue | Classification | Why it is not a present hard iOS blocker | Investigation required |
|---|---|---|---|
| Remaining Metal bucket parity | Engineering risk | The first native Metal TIE/TFRAG work is visible; desktop source has bucket implementations. | Decide whether incremental native Metal is cheaper/safer than bringing up the desktop C++ OpenGL renderer through a supported iOS backend. Compare dependencies, shader portability, and perf before committing to a broad rewrite. |
| Visible touch controls | Bounded product work | The pad-state transport and lifecycle-neutral behavior already work. | Specify a landscape touch overlay, layout persistence/customization, gestures, active/neutral snapshots, and accessibility/touch-target acceptance. Do not confuse a temporary touch bridge with this deliverable. |
| Mobile audio/streaming | Engineering + host validation | The game boots and streams enough local data for the current evidence; it is not the source of black composition. | Audit the iOS IOP/audio route and local user-data bundle requirements. Separate “audio starts” from audible output, route change, interruption, and no-microphone proof. |
| macOS NULL process-spawn history | Shared-runtime risk | It is historical and needs a fresh retail reproduction; it did not explain the current iPad Direct failure. | Define a bounded retail/new-game/ambient reproduction before changing `run-function-in-process` or `set-to-run`. If it recurs, capture PC/LR/GOAL stack/spawn args and add a regression first. |
| iPhone layout/performance | Unmeasured product risk | The bundle declares iPhone support, but no iPhone Simulator pass exists. | Defer until iPad has a repeatable rendered, controllable path; then measure drawable size, frame time, memory, touch ergonomics, thermal/device behavior. |
| Signing and physical hardware | External acceptance gate | Simulator success cannot answer device signing, GPU behavior, real controllers, audio routes, or performance. | State exact required hardware/account access and a device test matrix. Do not label this an engineering impossibility. |
| Game assets/licensing | Product/legal boundary | Local user-supplied data works for development and remains ignored. | Plan a ROM-safe user-data import/extraction workflow; never commit protected assets. |

## Questions the investigating bot must answer

1. **Renderer route:** Is continuing the incremental native-Metal renderer the
   shortest credible route to an iPad playable frame, or is porting the desktop
   `OpenGLRenderer` through ANGLE/GLES-on-Metal lower risk? Give a concrete
   dependency/build/shader/feature comparison rooted in this checkout, not a
   generic recommendation.
2. **Direct minimum slice:** Trace one deterministic title/menu Direct packet
   through desktop `DirectRenderer::render_vif`, `render_gif`, state handlers,
   `flush_pending`, and shaders. List the exact state fields and ordering the
   iOS Metal slice must preserve to yield a nonzero offscreen target and a
   visibly composed final frame.
3. **Reuse versus replacement:** Identify which parts of the existing
   `OttselGifDecoder`, texture/VIF path, and `OttselMetal` interface can be
   retained, and which diagnostic CPU-raster path should be retired after it
   supplies a bounded fixture. Do not propose a second generic VU interpreter.
4. **Proof design:** Specify the smallest regression/fixture that fails before
   the Direct fix, the exact one-Simulator run, required counters, screenshot,
   macOS comparison, fault scan, and pass/fail conditions.
5. **Post-renderer dependencies:** Provide a dependency-ordered plan for
   visible touch controls, GameController acceptance, audio/streaming, iPhone
   parity, and physical-device acceptance. Identify which require external
   hardware or signing authority.
6. **Risk decision:** Give explicit confidence and a falsifier for each claim.
   If the Direct packet cannot be made to compose using desktop semantics,
   identify the next discriminating experiment instead of broadening scope.

## Investigation constraints

- Read first: `docs/STATUS.md`, `docs/13-current-state.md`,
  `docs/15-macos-to-mobile-goal-loop.md`, and the two I1 evidence documents
  above.
- Treat `out/jak-project` as a user-owned, ignored local worktree. Inspect it
  read-only unless explicitly asked to change it.
- No implementation, patch regeneration, asset import, signing change, or
  release claim belongs to this investigation task.
- Use one Windowed runtime and at most one booted Simulator; do not run macOS
  `gk` and the Simulator concurrently.
- Do not treat a compiler pass, packet counter, texture page, one partial
  bucket, shell log, or first app launch as a playability pass.
- Preserve the signed-native/no-runtime-executable-code constraint and the
  ROM-safe repository boundary.

## Required response format from the investigating bot

Return a report with:

1. a one-paragraph feasibility verdict (resolvable engineering work versus
   genuine hard blockers);
2. a source/evidence map with exact files and functions;
3. a recommended renderer decision with alternatives rejected and why;
4. a numbered implementation plan, each step with its falsifiable exit bar;
5. a risk table: confidence, unknown, discriminator, and external dependency;
6. an explicit definition of iPad playable, iPhone parity, and device-ready;
7. no code changes unless separately authorized.
